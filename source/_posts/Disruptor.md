```
title: disruptor源码解析
date: 2018-02-07 15:31:05
tags: [disruptor,cas]
category: disruptor
```

# 基础知识

- 缓存伪共享+缓存行填充
- UNSAFE类方法功能


- 乐观锁CAS原子操作

- Volatile+内存屏障

# 交互图

![](http://oulmk4pq1.bkt.clouddn.com/disruptor/disruptor.png)

说明：

- 箭头表示持有或等于引用对象，无箭头表示持有的变量
- 源码并不是官网提供的源码，而是开发工具反编译出来的


- dependentSequence：前置消费者消费到的seq，有多个时使用FixedSequenceGroup，取最小的，若没有前置消费者，则为生产者cursor
- Sequence[] gatingSequence：消费者链上最后一个消费者组消费到的seqs
- 核心代码：
  - Sequencer.next()：生产者获得可用seq，发布事件
  - Processor.run()-->sequenceBarrier.waitFor()-->waitStrategy.waitFor()：消费者获得最大可用seq，读事件

## 生产者

- 生产者持有RingBuffer的引用，调用ringBuffer.publish方法---->sequencer.next(); sequencer.publish()
- Sequencer持有消费者链上最后一个消费者（组）消费到的seq（s），及cursor（当前生产者生产到的seq）
  - next()方法判断生产者请求的seq的覆盖点是否覆盖了(>)最慢消费者的seq，是则唤醒消费者并休眠，直到不覆盖返回请求的seq
  - publish()方法懒更新cursor：set并不立即可见，

## 消费者

Processor是消费者线程类，持有EventHandler做具体事件处理工作，记录当前消费到的seq，主要逻辑在run()方法：

- 循环请求next=seq+1


- 调用sequenceBarrier.waitFor(next) 获得当前可消费的publishedSequence（小于等于cursor和dependentSequence，且发布了时间）
  - 内部实际是调用waitStrategy.waitFor(next)获得最慢消费者消费到的seq，称为availableSequence
    - dependentSequence.get()>next?return availableSequence=dependentSequence.get():继续循环判断
    - 有些waitStrategy会先判断next和生产者cursor大小，直到next<=cursor，再判断dependentSequence与next
  - 若此时availableSequence>=next（可能存在批量消费，未被生产者再次写入事件），获得已写入事件的最大seq：sequencer.getHighestPublishedSequence(sequence, availableSequence);
  - 若availableSequence<next,返回seq//根据waitStrategy.waitFor的代码，貌似不会出现这种情况
- publishedSequence>=next：处理next->publishedSequence之间的事件
- publishedSequence<next：更新cursor=publishedSequence

# source

## Sequence

- 缓存行填充,填充14个long
- protected volatile long value
- set：延迟可见，UNSAFE.putOrderedLong(this, VALUE_OFFSET, value);
- setVolatile：理解可见，UNSAFE.putLongVolatile(this, VALUE_OFFSET, value);
- compareAndSet：

### FixedSequenceGroup

- extends Sequence
- private final Sequence[] sequences

- 重新get方法

```
public long get() {
        return Util.getMinimumSequence(this.sequences);
}
```

用于设置消费者的前置消费者seq，当消费者有多个前置消费者时使用

new ProcessingSequenceBarrier(){

​	//当dependentSequences.length>1时

​	dependentSequence =new FixedSequenceGroup

}

## Sequencer

生产者与消费者的桥梁,生成消费者屏障barrier：

（1）消费者屏障barrier持有Sequencer及Sequencer的cursor；

（2）Sequencer持有消费者链上最后一个消费者组消费到的seqs，当生产者申请写入的seq覆盖了最慢消费者的seq时，阻塞等待；

（3）发布时事件时更新cursor，并通知消费者线程

（4）生产者先获得next()，再发布事件，next()方法判断nextSeq是否覆盖最慢消费者的seqs，如果是，则阻塞等待。

（5）next()时，this.cursor.setVolatile(nextValue)更新生产者cursor=上次请求成功的seq，其他线程立即看到变更，pulish()时，this.cursor.set(sequence);//set方法不保证其他线程立即看到变更，所以发布事件后，并不保证消费者可以立即知道并消费，只有在请求下一个槽位时，消费者可立即看到已发布事件的上一槽位。这部分不知道理解是否有误

重要属性及方法：

- protected final Sequence cursor = new Sequence(-1L)生产者生产到的最大seq
- protected volatile Sequence[] gatingSequences//消费者链上最后一个消费者组消费到的seqs
- next()
- newBarrier()->new ProcessingSequenceBarrier(this, this.waitStrategy, this.cursor, sequencesToTrack);

### AbstractSequencer

    public abstract class AbstractSequencer implements Sequencer {
        private static final AtomicReferenceFieldUpdater<AbstractSequencer, Sequence[]> SEQUENCE_UPDATER = AtomicReferenceFieldUpdater.newUpdater(AbstractSequencer.class, Sequence[].class, "gatingSequences");//原子更新需要跟踪的消费者seq,gatingSequences
        protected final int bufferSize;//ringbuffer大小
        protected final WaitStrategy waitStrategy;//等待策略
        protected final Sequence cursor = new Sequence(-1L);//生产者生产到的seq
        protected volatile Sequence[] gatingSequences = new Sequence[0];//需跟踪的消费者组消费到的seqs
    
        public AbstractSequencer(int bufferSize, WaitStrategy waitStrategy) {
            if(bufferSize < 1) {
                throw new IllegalArgumentException("bufferSize must not be less than 1");
            } else if(Integer.bitCount(bufferSize) != 1) {//size必须是2的次方
                throw new IllegalArgumentException("bufferSize must be a power of 2");
            } else {
                this.bufferSize = bufferSize;
                this.waitStrategy = waitStrategy;
            }
        }
    
        public final long getCursor() {
            return this.cursor.get();
        }
    
        public final int getBufferSize() {
            return this.bufferSize;
        }
        //原子添加需跟踪的前置消费者seq到数组
        public final void addGatingSequences(Sequence... gatingSequences) {
            SequenceGroups.addSequences(this, SEQUENCE_UPDATER, this, gatingSequences);
        }
        //原子删除需跟踪的前置消费者seq
        public boolean removeGatingSequence(Sequence sequence) {
            return SequenceGroups.removeSequence(this, SEQUENCE_UPDATER, sequence);
        }
        //获得前置消费者中消费最慢的seq
        public long getMinimumSequence() {
            return Util.getMinimumSequence(this.gatingSequences, this.cursor.get());
        }
        //生成消费者屏障，指定前置消费者seq
        public SequenceBarrier newBarrier(Sequence... sequencesToTrack) {
            return new ProcessingSequenceBarrier(this, this.waitStrategy, this.cursor, sequencesToTrack);
        }
        //不建议使用
        public <T> EventPoller<T> newPoller(DataProvider<T> dataProvider, Sequence... gatingSequences) {
            return EventPoller.newInstance(dataProvider, this, new Sequence(), this.cursor, gatingSequences);
        }
    
        public String toString() {
            return "AbstractSequencer{waitStrategy=" + this.waitStrategy + ", cursor=" + this.cursor + ", gatingSequences=" + Arrays.toString(this.gatingSequences) + '}';
        }
     }
### SingleProducerSequencer

单线程写数据时使用

    public final class SingleProducerSequencer extends SingleProducerSequencerFields {
        protected long p1;//缓存行填充
        protected long p2;
        protected long p3;
        protected long p4;
        protected long p5;
        protected long p6;
        protected long p7;
    
        public SingleProducerSequencer(int bufferSize, WaitStrategy waitStrategy) {
            super(bufferSize, waitStrategy);
        }
    
        public boolean hasAvailableCapacity(int requiredCapacity) {
            return this.hasAvailableCapacity(requiredCapacity, false);
        }
    
        private boolean hasAvailableCapacity(int requiredCapacity, boolean doStore) {
            long nextValue = this.nextValue;//上次请求成功的seq
            //覆盖点：请求的个数+当前位置，超过一圈时，减去bufferSize=需要覆盖的上一圈位置
            long wrapPoint = nextValue + (long)requiredCapacity - (long)this.bufferSize;
            long cachedGatingSequence = this.cachedValue;//上次请求时，缓存记录的最慢消费者seq，只有在覆盖点要覆盖他时，才再次计算，计算完后，再次判断是否覆盖
            //覆盖了消费者未消费的位置
            if(wrapPoint > cachedGatingSequence || cachedGatingSequence > nextValue) {
                if(doStore) {//是否要写事件
                    this.cursor.setVolatile(nextValue);//更新生产者cursor=上次请求成功的seq，其他线程立即看到变更
                }
                //获得最慢消费者的seq
                long minSequence = Util.getMinimumSequence(this.gatingSequences, nextValue);
                this.cachedValue = minSequence;
                if(wrapPoint > minSequence) {
                    return false;
                }
            }
    
            return true;
        }
    
        public long next() {
            return this.next(1);
        }
    
        public long next(int n) {//请求几个位置
            if(n < 1) {
                throw new IllegalArgumentException("n must be > 0");
            } else {
                long nextValue = this.nextValue;//上次next()成功的seq
                long nextSequence = nextValue + (long)n;//本次请求到的seq
                long wrapPoint = nextSequence - (long)this.bufferSize;//覆盖点
                long cachedGatingSequence = this.cachedValue;//上次请求时，缓存记录的最慢消费者seq，只有在覆盖点要覆盖他时，才再次计算，计算完后，再次判断是否覆盖
                if(wrapPoint > cachedGatingSequence || cachedGatingSequence > nextValue) {
                    this.cursor.setVolatile(nextValue);//设置cursor=上次请求成功的seq，其他线程立即看到变更
    
                    long minSequence;
                    while(wrapPoint > (minSequence = Util.getMinimumSequence(this.gatingSequences, nextValue))) {
                        this.waitStrategy.signalAllWhenBlocking();
                        LockSupport.parkNanos(1L);
                    }
    
                    this.cachedValue = minSequence;
                }
    
                this.nextValue = nextSequence;//更新生产到的seq
                return nextSequence;
            }
        }
    
        public long tryNext() throws InsufficientCapacityException {
            return this.tryNext(1);
        }
    
        public long tryNext(int n) throws InsufficientCapacityException {
            if(n < 1) {
                throw new IllegalArgumentException("n must be > 0");
            } else if(!this.hasAvailableCapacity(n, true)) {
                throw InsufficientCapacityException.INSTANCE;
            } else {
                long nextSequence = this.nextValue += (long)n;
                return nextSequence;
            }
        }
    
        public long remainingCapacity() {
            long nextValue = this.nextValue;
            long consumed = Util.getMinimumSequence(this.gatingSequences, nextValue);
            return (long)this.getBufferSize() - (nextValue - consumed);
        }
    
        public void claim(long sequence) {
            this.nextValue = sequence;
        }
    
        public void publish(long sequence) {
            this.cursor.set(sequence);//set方法不保证其他线程立即看到变更
            this.waitStrategy.signalAllWhenBlocking();
        }
    
        public void publish(long lo, long hi) {
            this.publish(hi);
        }
    
        public boolean isAvailable(long sequence) {
            return sequence <= this.cursor.get();
        }
    
        public long getHighestPublishedSequence(long lowerBound, long availableSequence) {
            return availableSequence;
        }
    }
### MultiProducerSequencer

多线程写数据时使用，与单线程不同处：

1. 由于是多线程，需对共享变量使用原子操作
   - next()时，未覆盖消费者seq时，尝试set Cursor，使用原子操作：cursor.compareAndSet(current, next)
   - 如果失败，获得当前cursor位置，使用原子操作：current = this.cursor.get();计算覆盖点
   - 获得cachedGatingSequence，使用原子操作：this.gatingSequenceCache.get();
   - 设置cachedGatingSequence，使用原子操作： this.gatingSequenceCache.set(Util.getMinimumSequence(this.gatingSequences, current));
2. 新增int[] availableBuffer记录ringbuffer的槽位是否已写入事件，作为map使用，key=槽位内存地址，value=圈数，如果请求的seq对应圈数和int[]存的一样，则表示已写入事件

    public final class MultiProducerSequencer extends AbstractSequencer {
        private static final Unsafe UNSAFE = Util.getUnsafe();
        private static final long BASE;//数组第一个元素的偏移量（内存位置）
        private static final long SCALE;//数组每个元素大小
        private final Sequence gatingSequenceCache = new Sequence(-1L);//最慢消费者seq缓存，不是每次都计算,只有覆盖点>最慢消费者seq时，再次请求计算最新的最慢消费者seq
        private final int[] availableBuffer;
        private final int indexMask;//bufferSize-1,用于取模求圈数
        private final int indexShift;//
        
        public MultiProducerSequencer(int bufferSize, WaitStrategy waitStrategy) {
            super(bufferSize, waitStrategy);
            this.availableBuffer = new int[bufferSize];
            this.indexMask = bufferSize - 1;
            this.indexShift = Util.log2(bufferSize);//8->3,为了后面>>>运算，m>>>n = m除以2的n次方
            this.initialiseAvailableBuffer();
        }
        
        public boolean hasAvailableCapacity(int requiredCapacity) {
            return this.hasAvailableCapacity(this.gatingSequences, requiredCapacity, this.cursor.get());
        }
        
        private boolean hasAvailableCapacity(Sequence[] gatingSequences, int requiredCapacity, long cursorValue) {
            //覆盖点
            long wrapPoint = cursorValue + (long)requiredCapacity - (long)this.bufferSize;
            //最慢消费者的消费到的seq
            long cachedGatingSequence = this.gatingSequenceCache.get();
            //覆盖点过了最慢消费者的seq，
            或者cursorValue=Long.maxValue+1位负数，最慢消费者的seq大于cursorValue（不知是否理解有误）
            if(wrapPoint > cachedGatingSequence || cachedGatingSequence > cursorValue) {
                //重新计算获得最慢消费者的seq
                long minSequence = Util.getMinimumSequence(gatingSequences, cursorValue);
                this.gatingSequenceCache.set(minSequence);
                //如果仍然覆盖，则返回false
                if(wrapPoint > minSequence) {
                    return false;
                }
            }
            return true;
        }
        
        public void claim(long sequence) {
            this.cursor.set(sequence);
        }
        //阻塞获取可生产填充的下一seq
        public long next() {
            return this.next(1);
        }
        //阻塞获取可生产填充的下seq
        public long next(int n) {
            if(n < 1) {
                throw new IllegalArgumentException("n must be > 0");
            } else {
                long current;
                long next;
                do {
                    while(true) {
                        current = this.cursor.get();
                        next = current + (long)n;
                        long wrapPoint = next - (long)this.bufferSize;
                        long cachedGatingSequence = this.gatingSequenceCache.get();
                        if(wrapPoint <= cachedGatingSequence && cachedGatingSequence <= current) {
                            break;//不覆盖时，退出循环
                        }
                        //重新计算
                        long gatingSequence = Util.getMinimumSequence(this.gatingSequences, current);
                        if(wrapPoint > gatingSequence) {//如果仍然覆盖，则唤醒消费者进行消费，生产者阻塞
                            this.waitStrategy.signalAllWhenBlocking();
                            LockSupport.parkNanos(1L);
                        } else {否则更新最慢消费者的seq，进行下一循环，重新判断（可能是cursor已经变了）
                            this.gatingSequenceCache.set(gatingSequence);
                        }
                    }
                } while(!this.cursor.compareAndSet(current, next));//不覆盖时，尝试设置cursor为next失败
        
                return next;
            }
        }
        //不阻塞，获取失败，抛异常
        public long tryNext() throws InsufficientCapacityException {
            return this.tryNext(1);
        }
        //不阻塞，获取失败，抛异常
        public long tryNext(int n) throws InsufficientCapacityException {
            if(n < 1) {
                throw new IllegalArgumentException("n must be > 0");
            } else {
                long current;
                long next;
                do {
                    current = this.cursor.get();
                    next = current + (long)n;
                    if(!this.hasAvailableCapacity(this.gatingSequences, n, current)) {
                        throw InsufficientCapacityException.INSTANCE;
                    }
                } while(!this.cursor.compareAndSet(current, next));
        
                return next;
            }
        }
        
        public long remainingCapacity() {
            long consumed = Util.getMinimumSequence(this.gatingSequences, this.cursor.get());
            long produced = this.cursor.get();
            return (long)this.getBufferSize() - (produced - consumed);
        }
        //初始化int[]值为-1，代表圈数
        private void initialiseAvailableBuffer() {
            for(int i = this.availableBuffer.length - 1; i != 0; --i) {
                this.setAvailableBufferValue(i, -1);
            }
        
            this.setAvailableBufferValue(0, -1);
        }
        
        public void publish(long sequence) {
            this.setAvailable(sequence);//记录seq所在槽的圈数
            this.waitStrategy.signalAllWhenBlocking();
        }
        
        public void publish(long lo, long hi) {
            for(long l = lo; l <= hi; ++l) {
                this.setAvailable(l);
            }
        
            this.waitStrategy.signalAllWhenBlocking();
        }
        
        private void setAvailable(long sequence) {
            this.setAvailableBufferValue(this.calculateIndex(sequence), this.calculateAvailabilityFlag(sequence));
        }
        //按内存地址位置指定int[]元素的值，值为圈数
        index：槽位，flag：圈数
        private void setAvailableBufferValue(int index, int flag) {
            //计算槽位对应的内存地址
            long bufferAddress = (long)index * SCALE + BASE; 
            //设置availableBuffer中偏移量（内存地址）为bufferAddress的值
            UNSAFE.putOrderedInt(this.availableBuffer, bufferAddress, flag);
        }
        //是否可用：seq计算出的圈数是否已被设置到availableBuffer
        public boolean isAvailable(long sequence) {
            int index = this.calculateIndex(sequence);
            int flag = this.calculateAvailabilityFlag(sequence);
            long bufferAddress = (long)index * SCALE + BASE;
            return UNSAFE.getIntVolatile(this.availableBuffer, bufferAddress) == flag;
        }
        //lowerBound 到 availableSequence之间 最大可用seq
        public long getHighestPublishedSequence(long lowerBound, long availableSequence) {
            for(long sequence = lowerBound; sequence <= availableSequence; ++sequence) {
                if(!this.isAvailable(sequence)) {
                    return sequence - 1L;
                }
            }
        
            return availableSequence;
        }
        
        private int calculateAvailabilityFlag(long sequence) {
            return (int)(sequence >>> this.indexShift);//圈数
        }
        
        private int calculateIndex(long sequence) {
            return (int)sequence & this.indexMask;//槽位
        }
        
        static {
            BASE = (long)UNSAFE.arrayBaseOffset(int[].class);//数组第一个元素的偏移量（内存位置）
            SCALE = (long)UNSAFE.arrayIndexScale(int[].class);//数组一个元素的大小
        }
    }
## SequenceBarrier

一个消费者组对应一个barrier

1、waitFor获得最大可用seq（前置消费者已消费，且已写入事件）

- 实际调用等待策略的waitFor()，获得前置消费者消费到的位置，availableSequence = dependentSequence.get()，可能存在批量消费的情况，所以availableSequence 可能会大于请求的seq
- 然后调用sequencer.getHighestPublishedSequence(sequence, availableSequence);获得最大已写入事件的seq

2、alert唤醒阻塞的消费者,实际调用等待策略的signalAllWhenBlocking()

### ProcessingSequenceBarrier

    final class ProcessingSequenceBarrier implements SequenceBarrier{
        //等待策略。  
        private final WaitStrategy waitStrategy;  
        前置消费者的Sequence，如果没有，则等于生产者的Sequence  
        private final Sequence dependentSequence; 
        是否已通知
        private volatile boolean alerted = false;  
        生产者的Sequence
        private final Sequence cursorSequence;  
        生产者seq管理器，获得最大可用long，MultiProducerSequencer 或 SingleProducerSequencer
        private final Sequencer sequencer;  
        public ProcessingSequenceBarrier(final Sequencer sequencer,  
                                         final WaitStrategy waitStrategy,  
                                         final Sequence cursorSequence,  
                                         final Sequence[] dependentSequences){  
            this.sequencer = sequencer;  
            this.waitStrategy = waitStrategy;  
            this.cursorSequence = cursorSequence;  
            if (0 == dependentSequences.length){  
                dependentSequence = cursorSequence;  
            }else{  
                dependentSequence = new FixedSequenceGroup(dependentSequences);  
            }  
        }  
        @Override  
        public long waitFor(final long sequence)  
            throws AlertException, InterruptedException, TimeoutException{  
            //先检测是否已通知生产者，通知过则发异常
            checkAlert();  
            //然后根据等待策略来等待可用的序列值，消费者批量消费到的seq，可能未发布事件
            long availableSequence = waitStrategy.waitFor(sequence, cursorSequence, dependentSequence, this);  
            if (availableSequence < sequence){  
                return availableSequence; //如果可用的序列值小于请求的序列，那么直接返回可用的序列。  
            }  
            //否则，返回能使用（已发布事件）的最大的序列值，
            return sequencer.getHighestPublishedSequence(sequence, availableSequence);  
        }  
        @Override  
        public long getCursor(){  
            return dependentSequence.get();  
        }  
        @Override  
        public boolean isAlerted(){  
            return alerted;  
        }  
        @Override  
        public void alert(){  
            alerted = true; //设置通知标记  
            waitStrategy.signalAllWhenBlocking();//如果有线程以阻塞的方式等待序列，将其唤醒。  
        }  
        @Override  
        public void clearAlert(){  
            alerted = false;  
        }  
        @Override  
        public void checkAlert() throws AlertException{  
            if (alerted){  
                throw AlertException.INSTANCE;  
            }  
        }  
    }  
### BlockingWaitStrategy

    public final class BlockingWaitStrategy implements WaitStrategy {
        private final Lock lock = new ReentrantLock();
        private final Condition processorNotifyCondition;
    
        public BlockingWaitStrategy() {
            this.processorNotifyCondition = this.lock.newCondition();
        }
        //等待最大可用序列号
        public long waitFor(long sequence, Sequence cursorSequence, Sequence dependentSequence, SequenceBarrier barrier) throws AlertException, InterruptedException {
            if(cursorSequence.get() < sequence) {请求的seq>生产者seq：进入可重入锁并等待 
                this.lock.lock();
    
                try {
                    while(cursorSequence.get() < sequence) {
                        barrier.checkAlert();//循环检查是否请求的seq>生产者seq，是的话检查是否已解除屏障，是则抛异常，终止循环，否则等待。
                        this.processorNotifyCondition.await();
                    }
                } finally {
                    this.lock.unlock();
                }
            }
    
            long availableSequence;
            //当请求的seq<=生产者seq，检查是否请求的seq>前置消费者消费到的seq,是的话自旋（并循环检查是否有其他线程已唤醒消费者，是的话则抛异常,等同于是否已解除屏障，这块不知道理解对否）
            while((availableSequence = dependentSequence.get()) < sequence) {
                barrier.checkAlert();
            }
            return availableSequence;
        }
        //通知所有等待的消费者
        public void signalAllWhenBlocking() {
            this.lock.lock();
    
            try {
                this.processorNotifyCondition.signalAll();
            } finally {
                this.lock.unlock();
            }
    
        }
    
        public String toString() {
            return "BlockingWaitStrategy{processorNotifyCondition=" + this.processorNotifyCondition + '}';
        }
    }
## RingBuffer

1. RingBuffer对象做了缓存行填充，前后各填充了56个字节，
2. entries[]本身也根据引用大小进行了填充，数组前后各增加了128字节的数组对象，每个对象引用大小=4或8（大小与32位与64位系统及指针压缩有关），则前后各填充32或16个空数组位
3. 所以实际的数组长度比bufferSize要大。所以根据序列从entries中取元素的方法elementAt内部做了一些调整，而不是单纯取模，seq内存地址为=槽位（seq&（buffersize-1））*对象大小+起始偏移量
4. RingBuffer对象的创建是静态方法，需指定Sequencer类型，传递EventFactory
5. 序列管理相关的方法实际是通过调用sequencer的相关方法实现的，如next(),addGatingSequences()
6. 可发布EventTranslator：publishEvent(EventTranslator)，也可先获得next seq，再获得预初始化的Event对象，修改Event对象，再发布seq。
7. SingleProducer模式下，使用多线程发布，会有数据被覆盖的情况，所以需根据情况选择合理的模式
8. 重要属性及方法说明：

    public final class RingBuffer<E> extends RingBufferFields<E> implements Cursored, EventSequencer<E>, EventSink<E> {
      private final long indexMask = (long)(this.bufferSize - 1);//用于计算seq槽位=seq&indexMask
      private final Object[] entries;//事件
      protected final int bufferSize;//大小
      protected final Sequencer sequencer; //序列管理
      RingBuffer(EventFactory<E> eventFactory, Sequencer sequencer)//私有构造方法
      public static <E> RingBuffer<E> createMultiProducer(EventFactory<E> factory, int bufferSize, WaitStrategy waitStrategy)//创建多生产者的ringbuffer
      public static <E> RingBuffer<E> createSingleProducer(EventFactory<E> factory, int bufferSize, WaitStrategy waitStrategy)//创建单一生产者的ringbuffer
      public static <E> RingBuffer<E> create(ProducerType producerType, EventFactory<E> factory, int bufferSize, WaitStrategy waitStrategy) //根据producerType创建ringbuffer
      //添加gatingSequences
      public void addGatingSequences(Sequence... gatingSequences) {
            this.sequencer.addGatingSequences(gatingSequences);
      }
- RingBufferFields<E> 填充

- Cursored, 获得当前指针序号

- EventSequencer<E>, 序号管理

  ```
  1、DataProvider<T>提供获取Event对象的方法: T get(long var1);
  2、Sequenced序号管理: next(long var1),tryNext(long var1)
  public interface EventSequencer<T> extends DataProvider<T>, Sequenced
  ```

- EventSink<E> 事件发布

## EventProcessor 

- 一个线程EventProcessor 一个线程，对应一个EventHandler，
- 包含一个Sequence，记录当前消费到的seq，这个seq会被加入到Sequencer作为gatingSequence

    public interface EventProcessor extends Runnable{  
        /** 
         * 获取一个事件处理器使用的序列引用。 
         */  
        Sequence getSequence();  
        void halt();  
        boolean isRunning();  
    } 
### BatchEventProcessor

- 每个BatchEventProcessor都会处理一遍RingBuffer中的事件
- 默认异常了，调用默认的exceptionHandler仍继续处理，默认exceptionHandler直接抛了异常出去，消费者会阻塞，可能会影响业务，需自定义异常。

```
public final class BatchEventProcessor<T> implements EventProcessor {
    private final AtomicBoolean running = new AtomicBoolean(false);//运行状态
    private ExceptionHandler<? super T> exceptionHandler = new FatalExceptionHandler();
    private final DataProvider<T> dataProvider;
    private final SequenceBarrier sequenceBarrier;
    private final EventHandler<? super T> eventHandler;
    private final Sequence sequence = new Sequence(-1L);//当前处理到的seq
    private final TimeoutHandler timeoutHandler;
    private final BatchStartAware batchStartAware;
    
    public BatchEventProcessor(DataProvider<T> dataProvider, SequenceBarrier sequenceBarrier, EventHandler<? super T> eventHandler) {
        this.dataProvider = dataProvider;
        this.sequenceBarrier = sequenceBarrier;
        this.eventHandler = eventHandler;
        if(eventHandler instanceof SequenceReportingEventHandler) {
            ((SequenceReportingEventHandler)eventHandler).setSequenceCallback(this.sequence);
        }
    
        this.batchStartAware = eventHandler instanceof BatchStartAware?(BatchStartAware)eventHandler:null;
        this.timeoutHandler = eventHandler instanceof TimeoutHandler?(TimeoutHandler)eventHandler:null;
    }
    
    public Sequence getSequence() {
        return this.sequence;
    }
    
    public void halt() {
        this.running.set(false);
        this.sequenceBarrier.alert();
    }
    
    public boolean isRunning() {
        return this.running.get();
    }
    
    public void setExceptionHandler(ExceptionHandler<? super T> exceptionHandler) {
        if(null == exceptionHandler) {
            throw new NullPointerException();
        } else {
            this.exceptionHandler = exceptionHandler;
        }
    }
    
    public void run() {
        if(!this.running.compareAndSet(false, true)) {//原子设置运行状态为true，如果已经为true则正在运行，否则启动运行。
            throw new IllegalStateException("Thread is already running");
        } else {
            this.sequenceBarrier.clearAlert();//清除消费者屏障
            this.notifyStart();//如果eventHandler继承LifecycleAware，通知调用onStart方法
            Object event = null;
            long nextSequence = this.sequence.get() + 1L;//当前处理到的seq+1
    
            try {
                while(true) {
                    try {
                        long ex = this.sequenceBarrier.waitFor(nextSequence);//使用屏障获得最大可用seq
                        if(this.batchStartAware != null) {//批量启动通知
                            this.batchStartAware.onBatchStart(ex - nextSequence + 1L);
                        }
    
                        while(nextSequence <= ex) {如果请求的seq小于最大可用seq，则遍历处理这些可用seq
                            event = this.dataProvider.get(nextSequence);
                            this.eventHandler.onEvent(event, nextSequence, nextSequence == ex);
                            ++nextSequence;
                        }
    
                        this.sequence.set(ex);//设置处理到的seq为最大可用seq
                    } catch (TimeoutException var11) {
                        this.notifyTimeout(this.sequence.get());
                    } catch (AlertException var12) {
                        if(!this.running.get()) {//执行halt()后，running=false
                            return;//终止线程
                        }
                    } catch (Throwable var13) {//异常仍然继续处理
                        this.exceptionHandler.handleEventException(var13, nextSequence, event);
                        this.sequence.set(nextSequence);
                        ++nextSequence;
                    }
                }
            } finally {
                this.notifyShutdown();//eventhandler如果实现了LifecycleAware，通知调用onShutdown方法
                this.running.set(false);
            }
        }
    }
    
    private void notifyTimeout(long availableSequence) {
        try {
            if(this.timeoutHandler != null) {
                this.timeoutHandler.onTimeout(availableSequence);
            }
        } catch (Throwable var4) {
            this.exceptionHandler.handleEventException(var4, availableSequence, (Object)null);
        }
    
    }
    
    private void notifyStart() {
        if(this.eventHandler instanceof LifecycleAware) {
            try {
                ((LifecycleAware)this.eventHandler).onStart();
            } catch (Throwable var2) {
                this.exceptionHandler.handleOnStartException(var2);
            }
        }
    
    }
    
    private void notifyShutdown() {
        if(this.eventHandler instanceof LifecycleAware) {
            try {
                ((LifecycleAware)this.eventHandler).onShutdown();
            } catch (Throwable var2) {
                this.exceptionHandler.handleOnShutdownException(var2);
            }
        }
    
    }
    }

```
#### EventHandler

具体事件处理逻辑

    public interface EventHandler<T>{
    	void onEvent(T event, long sequence, boolean endOfBatch) throws Exception; 
    }
### WorkProcessor

多个同类的workProcessor线程，竞争消费RingBuffer（通过workSequence.CAS），一个线程消费过的，其他线程不再消费

- 传递workHandler，workSequence（多线程共享，上一次被处理的事件的seq，各线程尝试cas为workSequence+1，则表示获得可处理的seq）
- 持有eventReleaser 
- halt()方法终止线程，
  1. halt()方法会调用barrier.alert()-设置alert=true
  2. run方法中barrier.waitFor()会调用checkAlert(),如果alert=ture会抛AlertException异常
  3. run()捕获AlertException异常，终止线程

    public final class WorkProcessor<T> implements EventProcessor {
        private final AtomicBoolean running = new AtomicBoolean(false);
        private final Sequence sequence = new Sequence(-1L);当前处理到的seq
        private final RingBuffer<T> ringBuffer;
        private final SequenceBarrier sequenceBarrier;
        private final WorkHandler<? super T> workHandler;
        private final ExceptionHandler<? super T> exceptionHandler;
        private final Sequence workSequence;//多线程共享，上一次处理的事件的seq
        private final EventReleaser eventReleaser = new EventReleaser() {
        public void release() {
            WorkProcessor.this.sequence.set(9223372036854775807L);
        }
    };
    private final TimeoutHandler timeoutHandler;

    public WorkProcessor(RingBuffer<T> ringBuffer, SequenceBarrier sequenceBarrier, WorkHandler<? super T> workHandler, ExceptionHandler<? super T> exceptionHandler, Sequence workSequence) {
        this.ringBuffer = ringBuffer;
        this.sequenceBarrier = sequenceBarrier;
        this.workHandler = workHandler;
        this.exceptionHandler = exceptionHandler;
        this.workSequence = workSequence;
        if(this.workHandler instanceof EventReleaseAware) {
            ((EventReleaseAware)this.workHandler).setEventReleaser(this.eventReleaser);
        }
        
        this.timeoutHandler = workHandler instanceof TimeoutHandler?(TimeoutHandler)workHandler:null;
    }

    public Sequence getSequence() {
        return this.sequence;
    }

    public void halt() {
        this.running.set(false);
        this.sequenceBarrier.alert();//通知阻塞等待的消费者，sequenceBarrier.waitFor中checkAlert会抛异常，中断线程
    }

    public boolean isRunning() {
        return this.running.get();
    }

    public void run() {
        if(!this.running.compareAndSet(false, true)) {
            throw new IllegalStateException("Thread is already running");
        } else {
            this.sequenceBarrier.clearAlert();
            this.notifyStart();
            boolean processedSequence = true;
            long cachedAvailableSequence = -9223372036854775808L;
            long nextSequence = this.sequence.get();
            Object event = null;
        
            while(true) {
                while(true) {
                    try {
                        if(processedSequence) {//上一事件是否处理完成，是的话，进入新事件处理流程
                            processedSequence = false;
        
                            do {
                                nextSequence = this.workSequence.get() + 1L;//获得下一要处理的seq
                                this.sequence.set(nextSequence - 1L);//更新当前已处理到的seq为请求的seq-1
                            } while(!this.workSequence.compareAndSet(nextSequence - 1L, nextSequence));//尝试cas下一workSequence = workSequence+1直到成功
                        }
        
                        if(cachedAvailableSequence >= nextSequence) {请求的seq是否小于缓存的最大可用seq，是的话获得请求的事件，进行处理，处理完成后，processedSequence标记为true
                            event = this.ringBuffer.get(nextSequence);
                            this.workHandler.onEvent(event);
                            processedSequence = true;
                        } else {//否则，阻塞等待当前可用的最大seq，并更新cache，继续下一循环
                            cachedAvailableSequence = this.sequenceBarrier.waitFor(nextSequence);
                        }
                    } catch (TimeoutException var8) {
                        this.notifyTimeout(this.sequence.get());
                    } catch (AlertException var9) {
                        if(!this.running.get()) {
                            this.notifyShutdown();
                            this.running.set(false);
                            return;//终止线程
                        }
                    } catch (Throwable var10) {
                        this.exceptionHandler.handleEventException(var10, nextSequence, event);
                        processedSequence = true;
                    }
                }
            }
        }
    }

    private void notifyTimeout(long availableSequence) {
        try {
            if(this.timeoutHandler != null) {
                this.timeoutHandler.onTimeout(availableSequence);
            }
        } catch (Throwable var4) {
            this.exceptionHandler.handleEventException(var4, availableSequence, (Object)null);
        }

    }

    private void notifyStart() {
        if(this.workHandler instanceof LifecycleAware) {
            try {
                ((LifecycleAware)this.workHandler).onStart();
            } catch (Throwable var2) {
                this.exceptionHandler.handleOnStartException(var2);
            }
        }

    }

    private void notifyShutdown() {
        if(this.workHandler instanceof LifecycleAware) {
            try {
                ((LifecycleAware)this.workHandler).onShutdown();
            } catch (Throwable var2) {
                this.exceptionHandler.handleOnShutdownException(var2);
            }
        }

    }
    }
#### WorkerPool

多个WorkProcessor<?>[]线程

    public final class WorkerPool<T> {
        private final AtomicBoolean started = new AtomicBoolean(false);//运行状态
        private final Sequence workSequence = new Sequence(-1L);//多个Processor共用一个处理的seq
        private final RingBuffer<T> ringBuffer;
        private final WorkProcessor<?>[] workProcessors;//处理线程组
    
    public WorkerPool(RingBuffer<T> ringBuffer, SequenceBarrier sequenceBarrier, ExceptionHandler<? super T> exceptionHandler, WorkHandler... workHandlers) {
        this.ringBuffer = ringBuffer;
        int numWorkers = workHandlers.length;
        this.workProcessors = new WorkProcessor[numWorkers];//一个handler一个线程
    
        for(int i = 0; i < numWorkers; ++i) {
            this.workProcessors[i] = new WorkProcessor(ringBuffer, sequenceBarrier, workHandlers[i], exceptionHandler, this.workSequence);
        }
    
    }
    
    public WorkerPool(EventFactory<T> eventFactory, ExceptionHandler<? super T> exceptionHandler, WorkHandler... workHandlers) {
        this.ringBuffer = RingBuffer.createMultiProducer(eventFactory, 1024, new BlockingWaitStrategy());
        SequenceBarrier barrier = this.ringBuffer.newBarrier(new Sequence[0]);
        int numWorkers = workHandlers.length;
        this.workProcessors = new WorkProcessor[numWorkers];
    
        for(int i = 0; i < numWorkers; ++i) {
            this.workProcessors[i] = new WorkProcessor(this.ringBuffer, barrier, workHandlers[i], exceptionHandler, this.workSequence);
        }
        this.ringBuffer.addGatingSequences(this.getWorkerSequences());//添加消费者seq
    }
    
    public Sequence[] getWorkerSequences() {//每个Processor消费到的Sequence加上workSequence，共同作为消费者seq
        Sequence[] sequences = new Sequence[this.workProcessors.length + 1];
        int i = 0;
    
        for(int size = this.workProcessors.length; i < size; ++i) {
            sequences[i] = this.workProcessors[i].getSequence();
        }
    
        sequences[sequences.length - 1] = this.workSequence;
        return sequences;
    }
    
    public RingBuffer<T> start(Executor executor) {
        if(!this.started.compareAndSet(false, true)) {//检查是否已启动
            throw new IllegalStateException("WorkerPool has already been started and cannot be restarted until halted.");
        } else {
            long cursor = this.ringBuffer.getCursor();//生产者当前生产到的seq
            this.workSequence.set(cursor);//从生产者当前生产到的seq开始消费，作为workSeq
            WorkProcessor[] var4 = this.workProcessors;
            int var5 = var4.length;
    
            for(int var6 = 0; var6 < var5; ++var6) {
                WorkProcessor processor = var4[var6];
                processor.getSequence().set(cursor);//遍历processor，设置workSeq
                executor.execute(processor);//放入线程池
            }
    
            return this.ringBuffer;
        }
    }
    
    public void drainAndHalt() {//等待消费者处理完，然后暂停
        Sequence[] workerSequences = this.getWorkerSequences();//获得消费者消费到的seq
    
        while(this.ringBuffer.getCursor() > Util.getMinimumSequence(workerSequences)) {
            Thread.yield();//如果生产者覆盖了消费者未消费的seq，则等待
        }
    
        WorkProcessor[] var2 = this.workProcessors;
        int var3 = var2.length;
    
        for(int var4 = 0; var4 < var3; ++var4) {
            WorkProcessor processor = var2[var4];
            processor.halt();//消费者中断阻塞
        }
    
        this.started.set(false);
    }
    
    public void halt() {
        WorkProcessor[] var1 = this.workProcessors;
        int var2 = var1.length;
    
        for(int var3 = 0; var3 < var2; ++var3) {
            WorkProcessor processor = var1[var3];
            processor.halt();//消费者中断阻塞
        }
    
        this.started.set(false);//停止线程池
    }
    
    public boolean isRunning() {
        return this.started.get();
    }
    }
#### WorkHandler

具体事件处理

    public interface WorkHandler<T> {
    	void onEvent(T var1) throws Exception;
    }
# DSL

## Disruptor

- Disruptor.handleEventsWith会调用updateGatingSequencesForNextInChain：更新Sequencer监听的消费者链上最后一个消费者组的seqs，同时删除前置消费者的seq，不再监听，修改前置消费者seq不为链上最后消费者seq
- EventHandlerGroup.then()方法时间调用的也是Disruptor.handleEventsWith

    public class Disruptor<T> {
        private final RingBuffer<T> ringBuffer;
        private final Executor executor;//线程池
        private final ConsumerRepository<T> consumerRepository;//消费者仓库
        private final AtomicBoolean started;//是否启动
        private ExceptionHandler<? super T> exceptionHandler;

    /** @deprecated */
    @Deprecated
    public Disruptor(EventFactory<T> eventFactory, int ringBufferSize, Executor executor) {
        this(RingBuffer.createMultiProducer(eventFactory, ringBufferSize), executor);
    }

    /** @deprecated */
    @Deprecated
    public Disruptor(EventFactory<T> eventFactory, int ringBufferSize, Executor executor, ProducerType producerType, WaitStrategy waitStrategy) {
        this(RingBuffer.create(producerType, eventFactory, ringBufferSize, waitStrategy), executor);
    }

    public Disruptor(EventFactory<T> eventFactory, int ringBufferSize, ThreadFactory threadFactory) {
        this(RingBuffer.createMultiProducer(eventFactory, ringBufferSize), new BasicExecutor(threadFactory));
    }

    public Disruptor(EventFactory<T> eventFactory, int ringBufferSize, ThreadFactory threadFactory, ProducerType producerType, WaitStrategy waitStrategy) {
        this(RingBuffer.create(producerType, eventFactory, ringBufferSize, waitStrategy), new BasicExecutor(threadFactory));
    }

    private Disruptor(RingBuffer<T> ringBuffer, Executor executor) {
        this.consumerRepository = new ConsumerRepository();
        this.started = new AtomicBoolean(false);
        this.exceptionHandler = new ExceptionHandlerWrapper();
        this.ringBuffer = ringBuffer;
        this.executor = executor;
    }
    //添加消费者，前置消费者默认为空=生产者cursor
    public EventHandlerGroup<T> handleEventsWith(EventHandler... handlers) {
        return this.createEventProcessors(new Sequence[0], handlers);
    }
    //添加消费者，前置消费者默认为空=生产者cursor
    public EventHandlerGroup<T> handleEventsWith(EventProcessorFactory... eventProcessorFactories) {
        Sequence[] barrierSequences = new Sequence[0];
        return this.createEventProcessors(barrierSequences, eventProcessorFactories);
    }
    //添加消费者，前置消费者默认为空=生产者cursor
    public EventHandlerGroup<T> handleEventsWith(EventProcessor... processors) {
        EventProcessor[] sequences = processors;
        int i = processors.length;
        
        for(int var4 = 0; var4 < i; ++var4) {
            EventProcessor processor = sequences[var4];
            this.consumerRepository.add(processor);
        }
        
        Sequence[] var6 = new Sequence[processors.length];
        
        for(i = 0; i < processors.length; ++i) {
            var6[i] = processors[i].getSequence();
        }
        
        this.ringBuffer.addGatingSequences(var6);
        return new EventHandlerGroup(this, this.consumerRepository, Util.getSequencesFor(processors));
    }

    //创建多线程消费者
    public EventHandlerGroup<T> handleEventsWithWorkerPool(WorkHandler... workHandlers) {
        return this.createWorkerPool(new Sequence[0], workHandlers);
    }

    /** @deprecated */
    public void handleExceptionsWith(ExceptionHandler<? super T> exceptionHandler) {
        this.exceptionHandler = exceptionHandler;
    }

    public void setDefaultExceptionHandler(ExceptionHandler<? super T> exceptionHandler) {
        this.checkNotStarted();
        if(!(this.exceptionHandler instanceof ExceptionHandlerWrapper)) {
            throw new IllegalStateException("setDefaultExceptionHandler can not be used after handleExceptionsWith");
        } else {
            ((ExceptionHandlerWrapper)this.exceptionHandler).switchTo(exceptionHandler);
        }
    }

    public ExceptionHandlerSetting<T> handleExceptionsFor(EventHandler<T> eventHandler) {
        return new ExceptionHandlerSetting(eventHandler, this.consumerRepository);
    }

    public EventHandlerGroup<T> after(EventHandler... handlers) {
        Sequence[] sequences = new Sequence[handlers.length];
        int i = 0;
        
        for(int handlersLength = handlers.length; i < handlersLength; ++i) {
            sequences[i] = this.consumerRepository.getSequenceFor(handlers[i]);
        }
        
        return new EventHandlerGroup(this, this.consumerRepository, sequences);
    }

    public EventHandlerGroup<T> after(EventProcessor... processors) {
        EventProcessor[] var2 = processors;
        int var3 = processors.length;
        
        for(int var4 = 0; var4 < var3; ++var4) {
            EventProcessor processor = var2[var4];
            this.consumerRepository.add(processor);
        }
        
        return new EventHandlerGroup(this, this.consumerRepository, Util.getSequencesFor(processors));
    }

    public void publishEvent(EventTranslator<T> eventTranslator) {
        this.ringBuffer.publishEvent(eventTranslator);
    }

    public <A> void publishEvent(EventTranslatorOneArg<T, A> eventTranslator, A arg) {
        this.ringBuffer.publishEvent(eventTranslator, arg);
    }

    public <A> void publishEvents(EventTranslatorOneArg<T, A> eventTranslator, A[] arg) {
        this.ringBuffer.publishEvents(eventTranslator, arg);
    }

    public <A, B> void publishEvent(EventTranslatorTwoArg<T, A, B> eventTranslator, A arg0, B arg1) {
        this.ringBuffer.publishEvent(eventTranslator, arg0, arg1);
    }

    public <A, B, C> void publishEvent(EventTranslatorThreeArg<T, A, B, C> eventTranslator, A arg0, B arg1, C arg2) {
        this.ringBuffer.publishEvent(eventTranslator, arg0, arg1, arg2);
    }

    public RingBuffer<T> start() {//遍历消费者，启动消费者线程
        this.checkOnlyStartedOnce();
        Iterator var1 = this.consumerRepository.iterator();
        
        while(var1.hasNext()) {
            ConsumerInfo consumerInfo = (ConsumerInfo)var1.next();
            consumerInfo.start(this.executor);
        }
        
        return this.ringBuffer;
    }

    public void halt() {
        Iterator var1 = this.consumerRepository.iterator();

        while(var1.hasNext()) {
            ConsumerInfo consumerInfo = (ConsumerInfo)var1.next();
            consumerInfo.halt();
        }

    }

    public void shutdown() {
        try {
            this.shutdown(-1L, TimeUnit.MILLISECONDS);
        } catch (TimeoutException var2) {
            this.exceptionHandler.handleOnShutdownException(var2);
        }

    }

    public void shutdown(long timeout, TimeUnit timeUnit) throws TimeoutException {
        long timeOutAt = System.currentTimeMillis() + timeUnit.toMillis(timeout);

        do {
            if(!this.hasBacklog()) {
                this.halt();
                return;
            }
        } while(timeout < 0L || System.currentTimeMillis() <= timeOutAt);
        
        throw TimeoutException.INSTANCE;
    }

    public RingBuffer<T> getRingBuffer() {
        return this.ringBuffer;
    }

    public long getCursor() {
        return this.ringBuffer.getCursor();
    }

    public long getBufferSize() {
        return (long)this.ringBuffer.getBufferSize();
    }

    public T get(long sequence) {
        return this.ringBuffer.get(sequence);
    }

    public SequenceBarrier getBarrierFor(EventHandler<T> handler) {
        return this.consumerRepository.getBarrierFor(handler);
    }

    public long getSequenceValueFor(EventHandler<T> b1) {
        return this.consumerRepository.getSequenceFor(b1).get();
    }

    private boolean hasBacklog() {
        long cursor = this.ringBuffer.getCursor();
        Sequence[] var3 = this.consumerRepository.getLastSequenceInChain(false);
        int var4 = var3.length;
        
        for(int var5 = 0; var5 < var4; ++var5) {
            Sequence consumer = var3[var5];
            if(cursor > consumer.get()) {
                return true;
            }
        }
        
        return false;
    }
    //1、创建BatchEventProcessor
    //2、更新gatingSequence：取消跟踪barrierSequences，添加跟踪每个BatchEventProcessor(eventHandler).getSequence
    //3、new EventHandlerGroup(consumerRepository.add(batchEventProcessor),Processor.getSequence())
    EventHandlerGroup<T> createEventProcessors(Sequence[] barrierSequences, EventHandler<? super T>[] eventHandlers) {
        this.checkNotStarted();//检查是否已启动，启动后不能添加handler，抛异常
        Sequence[] processorSequences = new Sequence[eventHandlers.length];
        SequenceBarrier barrier = this.ringBuffer.newBarrier(barrierSequences);//一组handler共用一个序列屏障
        int i = 0;
        
        for(int eventHandlersLength = eventHandlers.length; i < eventHandlersLength; ++i) {
            EventHandler eventHandler = eventHandlers[i];
            BatchEventProcessor batchEventProcessor = new BatchEventProcessor(this.ringBuffer, barrier, eventHandler);//创建processor
            if(this.exceptionHandler != null) {
                batchEventProcessor.setExceptionHandler(this.exceptionHandler);
            }
        	//添加到消费者仓库
            this.consumerRepository.add(batchEventProcessor, eventHandler, barrier);
            //获得processor记录的消费到的seq对象
            processorSequences[i] = batchEventProcessor.getSequence();
        }
        //更新Sequencer监听的消费者seq为最后一个消费者的seq，同时删除前置消费者的seq不再监听，修改前置消费者seq不为链上最后消费者seq
        this.updateGatingSequencesForNextInChain(barrierSequences, processorSequences);
        return new EventHandlerGroup(this, this.consumerRepository, processorSequences);
    }
    //只需保证最慢的消费者seq不被生产者覆盖，前置消费者的seq不需要监听
    private void updateGatingSequencesForNextInChain(Sequence[] barrierSequences, Sequence[] processorSequences) {
        if(processorSequences.length > 0) {
            this.ringBuffer.addGatingSequences(processorSequences);//seq晚于barrierSequences，只需保证最慢的消费者seq不被生产者覆盖
            Sequence[] var3 = barrierSequences;
            int var4 = barrierSequences.length;
        
            for(int var5 = 0; var5 < var4; ++var5) {
                Sequence barrierSequence = var3[var5];
                this.ringBuffer.removeGatingSequence(barrierSequence);//只需保证最慢的消费者seq不被生产者覆盖
            }
        	//设置前置消费者seq不是链上最后一个消费者seq
            this.consumerRepository.unMarkEventProcessorsAsEndOfChain(barrierSequences);
        }

    }

    EventHandlerGroup<T> createEventProcessors(Sequence[] barrierSequences, EventProcessorFactory<T>[] processorFactories) {
        EventProcessor[] eventProcessors = new EventProcessor[processorFactories.length];

        for(int i = 0; i < processorFactories.length; ++i) {
            eventProcessors[i] = processorFactories[i].createEventProcessor(this.ringBuffer, barrierSequences);
        }
        
        return this.handleEventsWith(eventProcessors);
    }

    EventHandlerGroup<T> createWorkerPool(Sequence[] barrierSequences, WorkHandler<? super T>[] workHandlers) {
        SequenceBarrier sequenceBarrier = this.ringBuffer.newBarrier(barrierSequences);
        WorkerPool workerPool = new WorkerPool(this.ringBuffer, sequenceBarrier, this.exceptionHandler, workHandlers);
        this.consumerRepository.add(workerPool, sequenceBarrier);
        Sequence[] workerSequences = workerPool.getWorkerSequences();
        this.updateGatingSequencesForNextInChain(barrierSequences, workerSequences);
        return new EventHandlerGroup(this, this.consumerRepository, workerSequences);
    }

    private void checkNotStarted() {
        if(this.started.get()) {
            throw new IllegalStateException("All event handlers must be added before calling starts.");
        }
    }

    private void checkOnlyStartedOnce() {
        if(!this.started.compareAndSet(false, true)) {
            throw new IllegalStateException("Disruptor.start() must only be called once.");
        }
    }

    public String toString() {
        return "Disruptor{ringBuffer=" + this.ringBuffer + ", started=" + this.started + ", executor=" + this.executor + '}';
    }
    }
## ConsumerInfo

    interface ConsumerInfo {
        Sequence[] getSequences();
        SequenceBarrier getBarrier();
        boolean isEndOfChain();
        void start(Executor var1);
        void halt();
        void markAsUsedInBarrier();
        boolean isRunning();
    }
### EventProcessorInfo<T>

 有点像适配器模式，或者代理模式，代理EventProcessor

    class EventProcessorInfo<T> implements ConsumerInfo {
        private final EventProcessor eventprocessor;//事件处理线程
        private final EventHandler<? super T> handler;//handler
        private final SequenceBarrier barrier;
        private boolean endOfChain = true;
    
    EventProcessorInfo(EventProcessor eventprocessor, EventHandler<? super T> handler, SequenceBarrier barrier) {
        this.eventprocessor = eventprocessor;
        this.handler = handler;
        this.barrier = barrier;
    }
    
    public EventProcessor getEventProcessor() {
        return this.eventprocessor;
    }
    
    public Sequence[] getSequences() {
        return new Sequence[]{this.eventprocessor.getSequence()};
    }
    
    public EventHandler<? super T> getHandler() {
        return this.handler;
    }
    
    public SequenceBarrier getBarrier() {
        return this.barrier;
    }
    
    public boolean isEndOfChain() {
        return this.endOfChain;
    }
    
    public void start(Executor executor) {
        executor.execute(this.eventprocessor);
    }
    
    public void halt() {
        this.eventprocessor.halt();
    }
    
    public void markAsUsedInBarrier() {
        this.endOfChain = false;
    }
    
    public boolean isRunning() {
        return this.eventprocessor.isRunning();
    }
}
### WorkerPoolInfo<T>

 有点像适配器模式，或者代理模式，代理workerPool

    class WorkerPoolInfo<T> implements ConsumerInfo {
        private final WorkerPool<T> workerPool;
        private final SequenceBarrier sequenceBarrier;
        private boolean endOfChain = true;
    
    WorkerPoolInfo(WorkerPool<T> workerPool, SequenceBarrier sequenceBarrier) {
        this.workerPool = workerPool;
        this.sequenceBarrier = sequenceBarrier;
    }
    
    public Sequence[] getSequences() {
        return this.workerPool.getWorkerSequences();
    }
    
    public SequenceBarrier getBarrier() {
        return this.sequenceBarrier;
    }
    
    public boolean isEndOfChain() {
        return this.endOfChain;
    }
    
    public void start(Executor executor) {
        this.workerPool.start(executor);
    }
    
    public void halt() {
        this.workerPool.halt();
    }
    
    public void markAsUsedInBarrier() {
        this.endOfChain = false;
    }
    
    public boolean isRunning() {
        return this.workerPool.isRunning();
    }
}
## ConsumerRepository<T>



    class ConsumerRepository<T> implements Iterable<ConsumerInfo> {
        private final Map<EventHandler<?>, EventProcessorInfo<T>> eventProcessorInfoByEventHandler = new IdentityHashMap();//handler与Processor的一对一map
        private final Map<Sequence, ConsumerInfo> eventProcessorInfoBySequence = new IdentityHashMap();//seq与processor的一对一map
        private final Collection<ConsumerInfo> consumerInfos = new ArrayList();//processor
    
    ConsumerRepository() {
    }
    //添加processor
    public void add(EventProcessor eventprocessor, EventHandler<? super T> handler, SequenceBarrier barrier) {
        EventProcessorInfo consumerInfo = new EventProcessorInfo(eventprocessor, handler, barrier);
        this.eventProcessorInfoByEventHandler.put(handler, consumerInfo);
        this.eventProcessorInfoBySequence.put(eventprocessor.getSequence(), consumerInfo);
        this.consumerInfos.add(consumerInfo);
    }
    //添加processor
    public void add(EventProcessor processor) {
        EventProcessorInfo consumerInfo = new EventProcessorInfo(processor, (EventHandler)null, (SequenceBarrier)null);
        this.eventProcessorInfoBySequence.put(processor.getSequence(), consumerInfo);
        this.consumerInfos.add(consumerInfo);
    }
    //添加WorkerPool
    public void add(WorkerPool<T> workerPool, SequenceBarrier sequenceBarrier) {
        WorkerPoolInfo workerPoolInfo = new WorkerPoolInfo(workerPool, sequenceBarrier);
        this.consumerInfos.add(workerPoolInfo);
        Sequence[] var4 = workerPool.getWorkerSequences();//每个processor的seq及公共workSeq
        int var5 = var4.length;
    
        for(int var6 = 0; var6 < var5; ++var6) {
            Sequence sequence = var4[var6];
            this.eventProcessorInfoBySequence.put(sequence, workerPoolInfo);//processor的Seq及workSeq都指向workerPoolInfo
        }
    
    }
    //获得处理链上的最后一个消费者消费到的Seqs
    public Sequence[] getLastSequenceInChain(boolean includeStopped) {//是否包含已停止的消费者
        ArrayList lastSequence = new ArrayList();
        Iterator var3 = this.consumerInfos.iterator();
    
        while(true) {
            ConsumerInfo consumerInfo;
            do {
                if(!var3.hasNext()) {//消费者为空，遍历完成
                    return (Sequence[])lastSequence.toArray(new Sequence[lastSequence.size()]);
                }
    
                consumerInfo = (ConsumerInfo)var3.next();//不为空则取出消费者
            } while(!includeStopped && !consumerInfo.isRunning());//如不包含已停止的，且已停止，继续遍历直到碰到未停止的，判断是否是最后一个消费者，如果包含已停止的，则继续下面的代码
    
            if(consumerInfo.isEndOfChain()) {//是否是最后一个消费者
                Sequence[] sequences = consumerInfo.getSequences();//获得当前处理到的seq，如果是BatchEventProcess数量为1，如果是WorkerPool则为多个：每个Processor的Seq+workSeq
                Collections.addAll(lastSequence, sequences);
            }
        }
    }
    
    public EventProcessor getEventProcessorFor(EventHandler<T> handler) {
        EventProcessorInfo eventprocessorInfo = this.getEventProcessorInfo(handler);
        if(eventprocessorInfo == null) {
            throw new IllegalArgumentException("The event handler " + handler + " is not processing events.");
        } else {
            return eventprocessorInfo.getEventProcessor();
        }
    }
    
    public Sequence getSequenceFor(EventHandler<T> handler) {
        return this.getEventProcessorFor(handler).getSequence();
    }
    //设置这些Processor不为最后一个Processor
    public void unMarkEventProcessorsAsEndOfChain(Sequence... barrierEventProcessors) {
        Sequence[] var2 = barrierEventProcessors;
        int var3 = barrierEventProcessors.length;
    
        for(int var4 = 0; var4 < var3; ++var4) {
            Sequence barrierEventProcessor = var2[var4];
            this.getEventProcessorInfo(barrierEventProcessor).markAsUsedInBarrier();
        }
    
    }
    
    public Iterator<ConsumerInfo> iterator() {
        return this.consumerInfos.iterator();
    }
    
    public SequenceBarrier getBarrierFor(EventHandler<T> handler) {
        EventProcessorInfo consumerInfo = this.getEventProcessorInfo(handler);
        return consumerInfo != null?consumerInfo.getBarrier():null;
    }
    
    private EventProcessorInfo<T> getEventProcessorInfo(EventHandler<T> handler) {
        return (EventProcessorInfo)this.eventProcessorInfoByEventHandler.get(handler);
    }
    
    private ConsumerInfo getEventProcessorInfo(Sequence barrierEventProcessor) {
        return (ConsumerInfo)this.eventProcessorInfoBySequence.get(barrierEventProcessor);
    }
    }
## EventHandlerGroup<T>

消费者组，维护consumerRepository与Sequence[]（每个消费者（Processor）处理到的seq） 

1. 必须先通过Disruptor.handleEventsWith等方法实例化EventHandlerGroup，再调用其相应的方法
2. handleEventsWith()：添加handler，实际是调用disruptor.createEventProcessors创建BatchEventProcessor或disruptor.createWorkerPool创建WorkPool，更新是否为EndChain及gatingSequence
3. and()：合并EventHandlerGroup / 添加EventProcessor，更新consumerRepository及Sequence[]
4. then()：添加后置消费者，实际调用handleEventsWith()
5. 创建Barrier，调用disruptor.getRingBuffer().newBarrier(this.sequences);

    public class EventHandlerGroup<T> {	
        private final Disruptor<T> disruptor;
        private final ConsumerRepository<T> consumerRepository;
        private final Sequence[] sequences;
        
        EventHandlerGroup(Disruptor<T> disruptor, ConsumerRepository<T> consumerRepository, Sequence[] sequences) {
            this.disruptor = disruptor;
            this.consumerRepository = consumerRepository;
            this.sequences = (Sequence[])Arrays.copyOf(sequences, sequences.length);
        }
        
        public EventHandlerGroup<T> and(EventHandlerGroup<T> otherHandlerGroup) {
            Sequence[] combinedSequences = new Sequence[this.sequences.length + otherHandlerGroup.sequences.length];
            System.arraycopy(this.sequences, 0, combinedSequences, 0, this.sequences.length);
            System.arraycopy(otherHandlerGroup.sequences, 0, combinedSequences, this.sequences.length, otherHandlerGroup.sequences.length);
            return new EventHandlerGroup(this.disruptor, this.consumerRepository, combinedSequences);
        }
        
        public EventHandlerGroup<T> and(EventProcessor... processors) {
            Sequence[] combinedSequences = new Sequence[this.sequences.length + processors.length];
        
            for(int i = 0; i < processors.length; ++i) {
                this.consumerRepository.add(processors[i]);
                combinedSequences[i] = processors[i].getSequence();
            }
        
            System.arraycopy(this.sequences, 0, combinedSequences, processors.length, this.sequences.length);
            return new EventHandlerGroup(this.disruptor, this.consumerRepository, combinedSequences);
        }
        
        public EventHandlerGroup<T> then(EventHandler... handlers) {
            return this.handleEventsWith(handlers);
        }
        
        public EventHandlerGroup<T> then(EventProcessorFactory... eventProcessorFactories) {
            return this.handleEventsWith(eventProcessorFactories);
        }
        
        public EventHandlerGroup<T> thenHandleEventsWithWorkerPool(WorkHandler... handlers) {
            return this.handleEventsWithWorkerPool(handlers);
        }
        //添加handler
        public EventHandlerGroup<T> handleEventsWith(EventHandler... handlers) {
            return this.disruptor.createEventProcessors(this.sequences, handlers);
        }
        
        public EventHandlerGroup<T> handleEventsWith(EventProcessorFactory... eventProcessorFactories) {
            return this.disruptor.createEventProcessors(this.sequences, eventProcessorFactories);
        }
        
        public EventHandlerGroup<T> handleEventsWithWorkerPool(WorkHandler... handlers) {
            return this.disruptor.createWorkerPool(this.sequences, handlers);
        }
        
        public SequenceBarrier asSequenceBarrier() {
            return this.disruptor.getRingBuffer().newBarrier(this.sequences);
        }
    }
# 使用样例

```
public static void main(String[] args) {
        ThreadFactory threadFactory=Executors.defaultThreadFactory();
        int bufferSize = 1024;
        Disruptor<EventEntity> disruptor=new Disruptor<EventEntity>(new TrapEventFactory(),bufferSize,threadFactory);
        Disruptor<EventEntity> disruptor2=new Disruptor<EventEntity>(new TrapEventFactory(),bufferSize,threadFactory);
		//接收disruptor的消息进行过滤后，让如disruptor2
        FlitHandler flitHandler=new FlitHandler(disruptor2);
        ConversionHandler conversionHandler=new ConversionHandler();
        EnrichHandler enrichHandler=new EnrichHandler();
        SendHandler sendHandler=new SendHandler();
        disruptor.handleEventsWith(flitHandler);
        //先执行conversionHandler,enrichHandler，最后执行sendHandler
        disruptor2.handleEventsWith(conversionHandler,enrichHandler).then(sendHandler);
        disruptor.start();
        disruptor2.start();
        log.info("disruptor start");
        //生产者
        Executor executor = Executors.newFixedThreadPool(10);
        EventProducer producer = new EventProducer(disruptor);
        executor.execute(producer);
    }
```

