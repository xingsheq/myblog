---
title: 多线程并发模式
date: 2018-02-08 11:20:06
tags: [并发模式,Future,Master-Worker]
category: theory
---

# Future模式

​	异步非阻塞返回请求，直接返回的是包装过的请求结果，实际在获取结果时阻塞，比如：汇总多个存储过程的结果。

1. 先返回包装的对象，包装对象{set（实际对象） synchronized get{ 实际对象.get()} } 有点像适配器模式
2. 调用存储过程时，直接返回包装对象，同时启动计算线程，把计算结果set到包装对象
3. 调用包装对象get获得结果时，判断是否已set实际对象，否则阻塞

```
//伪代码
public class FutureData implements Data {  

    protected RealData realData =null;  
    protected boolean isReady = false;  

    public synchronized void setRealData(RealData realData){ 
        isReady=true;
        notifyAll(); 
    }

    public  synchronized  String getResult() {
      	while(!isReady){  
            try{  
                wait();  
            }catch (Exception e){                    
            }  
        }  
        return realData.result;        
    }    

} 

```

```
public class Client {  

    public Data request(final String queryStr){  
        final FutureData future = new FutureData();  
        //开启一个新的线程来构造真实数据  
        new Thread(){  
            public void run(){  
                RealData realData = new RealData(queryStr);  
                future.setRealData(realData);           
            }  
        }.start();  
        return future;  
    }  
} 

```

# MasterWorker模式

​	并行计算，master负责接收和分配任务，worker负责执行任务，执行完成返回结果到master，master进行汇总计算。

​	适用于大任务分解，并行进行，提高吞吐量。

- Master：


- - - concurrentLinkedQueue **存job**，
    - HashMap<String,Thread> **存woker线程**，
    - concurrentHashMap<String,Object>**存worker处理结果**


- Worker：


- - - Runnable，
    - 持有concurrentLinkedQueue的引用，取job
    - 持有concurrentHashMap<String,Object>的引用，存结果

```
//伪代码
Master{

Master(Worker,workerCount){
  worker.setQueue()
  worker.setConcurrentHashMap()
  for（workerCount）{
  	HashMap.put(xx,Thread(worker))//初始化worker线程
  }
}
//接收任务，放入队列
submit(Task){ queue.add(task)}

execute(){
   HashMap.for {
      map.value.start//启动worker线程
  }
}

  isComplete(){遍历worker，查看进程状态，都中断则完成}

  getResult(){获得计算结果}

}

```

```
//伪代码
worker impl Runnable{

  	run(){
      while(true){
          task=q.poll//取任务
          if(task==null) break;
          out=handle(task)
          concurrentHashMap.put(xx,out)//存结果
  	  }
	//处理任务
	out handle(task){}
}

```

# Guarded Suspension

## 定义

​	将并行转为串行式并行。Guarded Suspension:意为保护暂停。如字面意思一样。比如当服务器同时处理大量用户请求时，这时丢弃用户请求会影响用户体验。这时可以采让客户端请求排队等候，等前面的处理完之后再来处理后面的用户。这样既不会使得用户请求丢失，也避免了大量请求造成服务器崩溃。感觉有点像消费者生产者模式。

```
public class Queue {
    private List queue = new LinkedList();

    public synchronized Request getRequest() {
        while(queue.size()==0) {
            try {
                this.wait();
            }
            catch(InterruptedException ie) {
                return null;
            }
        }
        return (Request)queue.remove(0);
    }

    public synchronized void putRequest(Request request) {
        queue.add(request);
        this.notifyAll();
    }
```



# 不变模式

## 定义

​	在没有同步的多线程环境中，有些对象自创建便不需要被改变，这个时候，我们可以采用不变模式。平常我们见到的元数据的包装类，String、Boolean、Byte、Character、Double、Float、Integer、Long、Short都是使用的是不变模式。

## 使用方法

1. 将类定义为final类型，以保证其没有子类继承
2. 将所有属性定义为private私有属性，也用final修饰，使其无法被更改。
3. 拥有至少一个构造函数。
4. 去除所有的setter方法。

# 消费者-生产者模式

## 定义

​	生产者用于提交用户请求，消费者用于解决问题请求。

## 优点

- 将生产者和消费者进行解耦
- 通过内存缓冲区，可以消除了生产者和消费者之间的性能差异。