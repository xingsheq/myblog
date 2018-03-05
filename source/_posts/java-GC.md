---
title: java-GC
date: 2018-02-08 10:23:46
tags: [java,gc,垃圾回收]
category: jdk
---

# 如何判断是否可以回收

1. 引用计数，相互引用，无法释放

2. 可达性算法，从GC Root向下搜索引用链，不在链上的可以回收，实际是找链上的存活对象，其他的可回收

   可作为gc root的对象：
   （1）**栈**中局部变量的引用对象
   （2）**方法区**类**静态**属性的引用对象
   （3）**方法区常量**引用对象
   （4）本地方法**栈**中引用对象

# 回收算法

1. 标记清除：老年代，效率不高，空间碎片；

   **CMS**

2. 复制算法：新生代Eden，Survivor from ,Survivor to,在对象存活率高的情况下，效率低

   **Serial，Parallel New，Parallel Scavenge**

3. 标记整理：老年代，存活对象移向一端；

   **Serail Old，Parallel Old，G1**

4. 分代收集：新生代，老年代，永久代(java类，方法，使用动态代理生产class，jdk8移除，改为native Memory)，
   - 新生代Eden满->minorGC
   - 老年代满->FullGC

# 垃圾收集器

1. 新生代:

   {0}. Serial（单线程）、
   {0}. Parallel New（多线程）、
   {0}. Parallel Scavenge（吞吐优先，吞吐量=用户CPU时长/（用户CPU时长+GC时长））
   {0}. G1：Garbage First 第一时间处理垃圾最多的区域，1.7出现，计划替代cms
      - 新老代都回收，作用于Java堆
      - 可设置停顿比例，可预测停顿
      - 堆被划分成 许多个连续的区域(region)，并行
      - 并发
      - G1划分了一个Humongous区，它用来专门存放巨型对象。如果一个H区装不下一个巨型对象，那么G1会寻找连续的H分区来存储。为了能找到连续的H区，有时候不得不启动Full GC。

2. 老年代:

   {0}. Serial Old（单线程）、
   {0}. Parallel Old（吞吐优先）、
   {0}. CMS（时间优先，最短回收停顿，并发）
      {0}. 回收过程：初始标记->并发标记->再次标记->并发清除
      {0}. 只有Serial/Parallel New可以配合CMS使用
      {0}. 有碎片	
   {0}. G1

## 串行/并行/并发

- 串行：gc单线程

  ​	Serial、Serial old

- 并行：gc多线程

  ​	除Serial、Serial old外都是并行

- 并发：多cpu时，用户线程和gc线程同时执行，

  ​	cms、G1

## 垃圾收集器组合

![](http://oulmk4pq1.bkt.clouddn.com/java/gc组合.png)

Hotspot JVM实现中几种GC算法组合包含：

- Serial GC算法：Serial+Serial Old
- Parallel GC算法：Parallel New+串行PS MarkSweep GC(实际是Serail Old的壳)/并行Parallel Old，选PS MarkSweep GC 还是 Parallel Old GC 由参数UseParallelOldGC来控制；
- CMS GC算法：Parallel New+CMS+ Full GC for CMS算法（应对核心的CMS GC某些时候的不赶趟，开销很大）；
- G1 GC算法：Young GC + mixed GC（新生代，再加上部分老生代）＋ Full GC for G1 GC算法（应对G1 GC算法某些时候的不赶趟，开销很大）

## 触发条件

- young GC（minorGC）：Eden满了
- Serial Old GC／PS MarkSweep GC／Parallel Old GC的触发则是：在要执行Young GC时候预测其promote的object的总size超过老生代剩余size；
- CMS GC的initial marking的触发条件是老生代使用比率超过某值；
- G1 GC的initial marking的触发条件是Heap使用比率超过某值，跟CMS GC触发条件类似；
- Full GC for CMS算法和Full GC for G1 GC算法的触发原因很明显，就是CMS GC和G1 GC的算法不赶趟了，只能全局范围大搞一次GC了（这很慢）；

## jdk默认垃圾收集器（不确定是否对）

- 1.6：ParNew+Serail Old/Parallel Old(需设置参数指定)
- 1.7-1.8：Parallel Scavenge+Parallel Old
- 1.9：G1

# 对象内存分配过程

## 新生代内存分配

1. 优先分配到线程本地缓冲区TLAB(Thread Local Allocation Buffer)，TLAB属于Eden一部分；

2. 如果TLAB不能分配，在Eden分配：释放Eden不活跃对象，仍空间不足时，触发MinorGC；空间分配担保：MinorGC之前，会评估老年代的连续空间是否大于新生代对象总大小或者历次晋升的平均大小，是的话就会进行Minor GC，否则将进行Full GC。

   MinorGC过程：

   {0}. Eden->To：存活对象
   {0}. From->To：存活对象
   {0}. From->Old：长存活对象：15次
   {0}. To->Old：Minor GC时，当Survivor To放不下时，进入老年代

## OldGen内存分配

1. 大对象直接进老年代：长字符串及数组
2. 长期存活对象进老年代，15次
3. 空间分配担保：Minor GC时，当Survivor To放不下时，进入老年代
4. 动态年龄判断，不是所有都需要15次，同一age对象大小>50%Survivor，>age的对象进入老年代

# 引用

当内存空间还足够时，则能保留在内存之中；如果内存在进行垃圾收集后还是非常紧张，则可以抛弃这些对象，Java对引用的概念进行了扩充，将引用分为四种，这四种引用强度依次逐渐减弱。

1. 强引用（Strong Reference）：
2. 软引用（Soft Reference）：溢出前回收
3. 弱引用（Weak Reference）：gc时回收
4. 虚引用（Phantom Reference）：为一个对象设置虚引用关联的唯一目的就是希望能在这个对象被收集器回收时收到一个系统通知

# 方法区的回收

- 常量池回收：无引用
- 类型卸载：实例已回收，且加载该类的classLoader已回收，无任何引用

