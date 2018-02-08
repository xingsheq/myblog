---
title: Quartz
date: 2018-02-08 10:04:16
tags: quartz
category: 3rd party jars
---

# 概念

![](http://oulmk4pq1.bkt.clouddn.com/quartz/quartz1.png)



![](http://oulmk4pq1.bkt.clouddn.com/quartz/quartz2.png)

## Job

是一个接口，只有一个方法void execute(JobExecutionContext context)，开发者实现该接口定义运行任务，JobExecutionContext类提供了调度上下文的各种信息。Job运行时的信息保存在JobDataMap实例中；

### Job并发

Job是有可能并发执行的，比如一个任务要执行10秒中，而调度算法是每秒中触发1次，那么就有可能多个任务被并发执行。

有时候我们并不想任务并发执行，比如这个任务要去&quot;获得数据库中所有未发送邮件的名单&quot;，如果是并发执行，就需要一个数据库锁去避免一个数据被多次处理。这个时候一个@DisallowConcurrentExecution解决这个问题。

就是这样

```
public class DoNothingJob implements Job {

    @DisallowConcurrentExecution
    public void execute ( JobExecutionContext context ) throws JobExecutionException {

    }
}
```

注意，@**DisallowConcurrentExecution**是对JobDetail实例生效，也就是如果你定义两个JobDetail，引用同一个Job类，是可以并发执行的。

**@PersistJobDataAfterExecution** ：此注解表示当这个Job的execute方法执行成功后，更新并存储它所持有的JobDetail属性中JobDataMap。如果使用这个注解，强烈建议也使用@DisallowConcurrentExecution，因为并发执行过程中，JobDataMap有可能会发生冲突

## JobDetail

​	Quartz在每次执行Job时，都重新创建一个Job实例，所以它不直接接受一个Job的实例，相反它接收一个Job实现类，以便运行时通过newInstance()的反射机制实例化Job。因此需要通过一个类来描述Job的实现类及其它相关的静态信息，如Job名字、描述、关联监听器等信息，JobDetail承担了这一角色。jobDetail.getJobDataMap().put()可以传递参数给Job。

JobDetail有两个boolean属性：

- isDurable：如果设为false，则对应的Job一旦没有关联的触发器，就会被Scheduler自动删除。
- requestsRecovery：如果设为true，当Job执行中遇到硬中断（例如运行崩溃、机器断电等），Scheduler会重新执行。这种情况下，JobExecutionContext.isRecovering()会返回ture。

## Trigger

是一个类，描述触发Job执行的时间触发规则。主要有SimpleTrigger和CronTrigger这两个子类。

### SimpleTrigger

当仅需触发一次或者以固定时间间隔周期执行，SimpleTrigger是最适合的选择；

### CronTrigger

CronTrigger则可以通过Cron表达式定义出各种复杂时间规则的调度方案：如每早晨9:00执行，周一、周三、周五下午5:00执行等；

### CalendarIntervalTrigger

类似于SimpleTrigger，指定从某一个时间开始，以一定的时间间隔执行的任务。 但是不同的是SimpleTrigger指定的时间间隔为毫秒，没办法指定每隔一个月执行一次（每月的时间间隔不是固定值），而CalendarIntervalTrigger支持的间隔单位有秒，分钟，小时，天，月，年，星期。

相较于SimpleTrigger有两个优势：

1. 更方便，比如每隔1小时执行，你不用自己去计算1小时等于多少毫秒。
2. 支持不是固定长度的间隔，比如间隔为月和年。但劣势是精度只能到秒。

它适合的任务类似于：9:00 开始执行，并且以后每周 9:00 执行一次

它的属性有:

- interval 执行间隔
- intervalUnit 执行间隔的单位（秒，分钟，小时，天，月，年，星期）

### DailyTimeIntervalTrigger

指定每天的某个时间段内，以一定的时间间隔执行任务。并且它可以支持指定星期。

它适合的任务类似于：指定每天9:00 至 18:00 ，每隔70秒执行一次，并且只要周一至周五执行。

它的属性有:

- startTimeOfDay 每天开始时间
- endTimeOfDay 每天结束时间
- daysOfWeek 需要执行的星期
- interval 执行间隔
- intervalUnit 执行间隔的单位（秒，分钟，小时，天，月，年，星期）
- repeatCount 重复次数

TriggerUtils ：创建Trigger的工具类

## Calendar

​	org.quartz.Calendar和java.util.Calendar不同，它是一些日历特定时间点的集合（可以简单地将org.quartz.Calendar看作java.util.Calendar的集合——java.util.Calendar代表一个日历时间点，无特殊说明后面的Calendar即指org.quartz.Calendar）。**一个Trigger可以和多个Calendar关联**，以便排除或包含某些时间点。假设，我们安排每周星期一早上10:00执行任务，但是如果碰到法定的节日，任务则不执行，这时就需要在Trigger触发机制的基础上使用Calendar进行定点排除。

## Scheduler

​	代表一个Quartz的独立运行容器，Trigger和JobDetail可以注册到Scheduler中，两者在Scheduler中拥有各自的组及名称，组及名称是Scheduler查找定位容器中某一对象的依据，Trigger的组及名称必须唯一，JobDetail的组和名称也必须唯一（但可以和Trigger的组和名称相同，因为它们是不同类型的）。Scheduler定义了多个接口方法，允许外部通过组及名称访问和控制容器中Trigger和JobDetail。

​	Scheduler就是Quartz的大脑，所有任务都是由它来设施。Schduelr包含一个两个重要组件: JobStore和ThreadPool。

### JobStore

是用来存储运行时信息的，包括Trigger,Schduler,JobDetail，业务锁等。它有多种实现

- RAMJob(内存实现)，
- JobStoreTX(JDBC，事务由Quartz管理），
- JobStoreCMT(JDBC，使用容器事务)，
- ClusteredJobStore(集群实现)、
- TerracottaJobStore。

### ThreadPool

​	就是线程池，Scheduler使用一个线程池作为任务运行的基础设施，任务通过共享线程池中的线程提高运行效率。Quartz有自己的线程池实现。所有任务的都会由线程池执行。Scheduler 调度线程主要有两个： 执行常规调度的线程，和执行 misfired trigger 的线程。常规调度线程轮询存储的所有 trigger，如果有需要触发的 trigger，即到达了下一次触发的时间，则从任务执行线程池获取一个空闲线程，执行与该 trigger 关联的任务。Misfire 线程是扫描所有的 trigger，查看是否有 misfired trigger，如果有的话根据 misfire 的策略分别处理。下图描述了这两个线程的基本流程

图4

![](http://oulmk4pq1.bkt.clouddn.com/quartz/quartz4.png)

图5

![](http://oulmk4pq1.bkt.clouddn.com/quartz/quartz5.png) 				 

​	Scheduler可以将Trigger绑定到某一JobDetail中，这样当Trigger触发时，对应的Job就被执行。一个Job可以对应多个Trigger，但一个Trigger只能对应一个Job。可以通过SchedulerFactory创建一个Scheduler实例。Scheduler拥有一个SchedulerContext，它类似于ServletContext，保存着Scheduler上下文信息，Job和Trigger都可以访问SchedulerContext内的信息。SchedulerContext内部通过一个Map，以键值对的方式维护这些上下文数据，SchedulerContext为保存和获取数据提供了多个put()和getXxx()的方法。可以通过Scheduler# getContext()获取对应的SchedulerContext实例。

# 开发步骤

## 标准开发步骤

1. 开发job，实现Job接口

2. new JobDetail

   JobDetail jobDetail = **new** JobDetail(jobName, _JOB\_GROUP\_NAME_, cls);

3. 传递/获得参数

   - 传递参数:jobDetail.getJobDataMap().put()
   - 获得参数content.getJobDetail().getJobDataMap()

   ```
   public class QuartzJob implements Job {
       @Override
       public void execute(JobExecutionContext content) throws JobExecutionException {
           System.out.println(new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date())+ "★★★★★★★★★★★");
           String jobName = content.getJobDetail().getName();
           JobDataMap dataMap = content.getJobDetail().getJobDataMap();
           String param = dataMap.getString("param");
           System.out.println("传递的参数是="+param +"任务名字是="+jobName);
       }
   }
   ```

4. new Trigger,指定周期

5. 实例化Scheduler

   ```
   SchedulerFactory_gSchedulerFactory_ = new StdSchedulerFactory();
   Scheduler sched = gSchedulerFactory.getScheduler();
   ```

6. 加入schedule容器

   sched.scheduleJob(jobDetail, trigger);

7. 启动schedule

   sched.start();

## spring+quartz集成

配置以下bean：

- Job bean,不用实现Job类
- MethodInvokingJobDetailFactoryBean
- CronTriggerBean or SimpleTriggerBean
- SchedulerFactoryBean

# 总结

1. JobDetail负责Job的实例化，可传参给Job

2. Scheduler类似容器，Trigger和JobDetail注册在其中，可以根据名字和组获得Trigger和JobDetail

3. Job实现类通过JobExecutionContext可以获得JobDetail里的参数

4. SimpleTrigger 必须设置repeatCount，否则只执行一次

5. 除SimpleTrigger和CronTrigger外的Trigger：

   CalendarIntervalTrigger：每隔XX秒，分钟，小时，天，月，年，星期执行一次

   DailyTimeIntervalTrigger: 每天9:00 至 18:00 ，每隔70秒执行一次，并且只要周一至周五执行

## Crontab通配符

![](http://oulmk4pq1.bkt.clouddn.com/quartz/quartz6.png)

**通配符\***：表示所有值。例如:在分的字段上设置 "\*",表示每一分钟都会触发
**通配符?**：表示不指定值。使用的场景为不需要关心当前设置这个字段的值。例如:要在每月的10号触发一个操作，但不关心是周几，所以需要周位置的那个字段设置为"?" 具体设置为 0 0 0 10 * ?
**通配符-**：表示区间。例如在小时上设置 "10-12",表示 10,11,12点都会触发。
**通配符,**：表示指定多个值。例如在周字段上设置 "MON,WED,FRI" 表示周一，周三和周五触发
**通配符/**：用于递增触发。如在秒上面设置"5/15" 表示从5秒开始，每增15秒触发(5,20,35,50)。在月字段上设置'1/3'所示每月1号开始，每隔三天触发一次。
**通配符L**：表示最后的意思。例如在日字段设置上，表示当月的最后一天(依据当前月份，如果是二月还会依据是否是润年[leap]), 在周字段上表示星期六，相当于"7"或"SAT"。如果在"L"前加上数字，则表示该数据的最后一个。例如在周字段上设置"6L"这样的格式，则表示“本月最后一个星期五"
**通配符W**：表示离指定日期的最近那个工作日(周一至周五)。例如在日字段上设置"15W"，表示离每月15号最近的那个工作日触发。如果15号正好是周六，则找最近的周五(14号)触发, 如果15号是周未，则找最近的下周一(16号)触发。如果15号正好在工作日(周一至周五)，则就在该天触发。如果指定格式为 "1W",它则表示每月1号往后最近的工作日触发。如果1号正是周六，则将在3号下周一触发。(注，"W"前只能设置具体的数字,不允许区间"-")。
**小提示**：'L'和 'W'可以一组合使用。如果在日字段上设置"LW",则表示在本月的最后一个工作日触发；周字段的设置，若使用英文字母是不区分大小写的，即MON与mon相同。
**通配符#**：表示每月的第几个周几。例如在周字段上设置"6#3"表示在每月的第三个周六。注意如果指定"#5"，正好第五周没有周六，则不会触发该配置(用在母亲节和父亲节再合适不过了)。
**注**：表中月份一行的JAN-DEC，是指一月到十二月的英文缩写；星期一行的SUN-SAT，是指星期天到星期六的英文缩写

## Crontab案例

![](http://oulmk4pq1.bkt.clouddn.com/quartz/quartz7.png)