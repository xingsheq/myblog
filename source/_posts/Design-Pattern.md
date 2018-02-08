---
title: Design-Pattern
date: 2018-02-08 10:25:59
tags: [设计模式,design pattern]
category: theory
---

# 设计模式的六大原则SOLID

- Single单一职责
- Open Close Principle：开闭原则，对扩展开放，对修改关闭
- Liskov Substitution Principle：里氏替换原则，派生类可以替换掉基类
- Dependence Inversion Principle：依赖倒置，针对对接口编程，依赖于抽象而不依赖于具体，是开闭原则的基础
- Interface Segregation Principle：接口隔离原则，最小接口，使用多个隔离的接口，比使用单个接口要好
- Demeter/Least Knowledge Principle：迪米特法则，不和陌生人说话，尽量少地与其他实体之间发生相互作用
- Composite Reuse Principle：尽量使用合成/聚合的方式，而不是使用继承

# 设计模式分类

- 创建型：抽工建原单，
- 结构型：适代外享组装桥。 
- 行为型：访问者观察迭代策略，备忘录模板记录状态，命令中介解释责任链

![](http://oulmk4pq1.bkt.clouddn.com/pattern/pattern_category.jpg)

# 设计模式类图

类与类之间的关系：**鸡湿衣冠剧组**(继承，实现，依赖，关联，聚合，组合)

- 继承/泛化：Generalization 实线+空三角
- 实现：Realization 虚线+空三角
- 依赖：Dependency 虚线+箭头  不持有引用，比如局部变量，函数参数， 返回值
- 关联：Association 实线+箭头 持有引用，比如成员变量
- 聚合：Aggregation 实线+空菱形（整体）+箭头（局部），整体与局部，比如成员变量
- 组合：Composition 实线+实菱形（整体）+箭头（局部），整体与局部，共生死

![](http://oulmk4pq1.bkt.clouddn.com/pattern/pattern.jpg)

# 1.  创建型模式

## 1.1.  简单工厂Factory

简单工厂模式**不属于**23种设计模式

### 1.1.1.  普通工厂

创建工厂类，一个创建对象的方法，根据参数类型不同，返回子类对象，如：邮件和短信

```
factory.getProduct(int type){}
```

### 1.1.2.  多方法工厂

不同方法返回不同子类对象

```
factory.getProductA(){}
factory.getProductB(){}
```

### 1.1.3.  静态工厂

方法是静态的，不需要实例工厂，最常用

```
Factory.getProduct(int type){}

Factory.getProduct()

Factory.getProductA(){}
Factory.getProductB(){}
```

## 1.2.  工厂方法FactoryMethod

简单工厂模式有一个问题就是，类的创建依赖工厂类，也就是说，如果想要拓展程序，必须对工厂类进行修改，这违背了闭包原则。

工厂方法模式，**抽象出工厂接口**，有多个工厂类实现（每个对象一个工厂，工厂实现同一接口）

## 1.3.  抽象工厂AbstractFactory

抽象工厂是应对**产品族**概念的。比如说，每个汽车公司可能要同时生产轿车，货车，客车，那么每一个工厂都要有创建轿车，货车和客车的方法。又比如每个工厂可能同时生成鼠标和键盘。

与工厂方法类似，不同的是每个工厂类可以生产不同类别的产品，如即可以生产鼠标也可以生成键盘。

与工厂方法的区别

- 工厂方法只能生产一种产品类，抽象工厂方法能生产不同产品族的多个产品类(多个抽象产品类)
- 在只有一个产品族的情况下，抽象工厂模式实际上退化到工厂方法模式。

## 1.4.  单例Singleton

- 私有静态实例；

- 私有构造方法；

- synchronized getInstance()(每次调用都加锁，性能下降)，

  - 可以使用**静态内部类**getInstance(){new出对象}，静态内部类只有在使用的时候才装载类，可以看做是普通的静态类，和放在哪了没有关系。

    ```
    public class Singleton {  
        private static class SingletonHolder {  
            private static final Singleton INSTANCE = new Singleton();  
        }  
        private Singleton (){}  
        public static final Singleton getInstance() {  
            return SingletonHolder.INSTANCE; 
        }  
    }
    ```

  - 也可以使用双重判断，if(s==null){ synchronized(Class){ return new s}}，new s()不是原子性的，s需要volatile声明

- 使用枚举创建单例

  ```
  public emun Singleton {  
  	INSTANCE;
  	private Singleton (){}
  	public dosth(){      
  	}
  }

  Singleton.INSTANCE.dosth()
  ```

## 1.5.  建造者Builder

创建复合对象，多部件制造和组装分开，构建与表示分离，同样的构建过程可以创建不同的表示，如：生成电脑包括生产CPU，显示器，内存，不同厂商生产出的不一样。

角色：

- 建造者（包含建造各部件的方法）、
- 产品、
- 指挥者（**指挥者类Director**，其拥有一个建造者对象和建造PC产品的方法construct（组装产品），该方法通过具体建造者对象，依次执行每个步骤，最后返回建造完成的产品对象）

样例：参数较多的类的构造(属于builder模式的变形)：如struts的ActionConfig 

```
Student{
	private Student(Student orig){
  		this.name=orig.name
 	 	......
	}
	public static class Builder {
        private Student target;
        public Builder() {
            target = new Student();
        }
         public Builder name(String name) {
            target.name = name;
            return this;
        }
        .......
}
```

```
tudent s=new Student.Builder().name("CC").age(11).address(xx);
```

建造者模式与工厂模式区别

- 建造者模式可以说是对工厂模式的扩展；
- 工厂类提供了生产**单个**产品的功能，而建造者模式则可以将**各种**产品集中起来进行统一管理；
- 工厂模式关注的是**整个**产品，建造者模式关注的是产品各组成**部分**的创建过程。

建造者模式与模板模式区别

- 建造者模式是**创建型**模式，模板模式是**行为型**模式；
- 建造者模式使用**组合**，模板模式使用**继承**；
- 建造者模式中的指挥者生产产品的方法construct类似模板模式的算法步骤。

## 1.6.  原型Prototype

分2种：

- 普通原型模式：实现Cloneable接口及**clone**方法，
- 带原型管理器：除实现clone方法外，增加原型管理器角色，该角色保持一个**聚集**（如Map），作为对所有原型对象的登记，这个角色提供必要的方法，供外界增加新的原型对象和取得已经登记过的原型对象。

如果需要创建的原型对象数目较少而且比较固定的话，可以采取普通原型模式，如果要创建的原型对象数目不固定的话，采用原型管理器

使用场景：当直接创建对象的代价比较大时，则采用这种模式。例如，一个对象需要在一个高代价的数据库操作之后被创建。

# 2.  结构型模式

## 2.1.  适配器Adapter

将一个类的接口转换成客户希望的另外一个接口。Adapter模式使得原本由于接口不**兼容**而不能一起工作的那些类可以在一起工作。

### 2.1.1.  类适配

继承旧类+实现新接口

### 2.1.2.  对象适配

持有旧类+实现新接口 

### 2.1.3.  接口适配（缺省适配模式）

**适配器模式的用意**是要改变源的接口，以便于目标接口相容。**缺省适配的用意稍有不同**，它是为了方便建立一个不平庸的适配器类而提供的一种平庸实现。

方法：创建抽象类实现接口所有方法（适配器类），然后继承抽象类，实现部分方法。

适用于当不希望实现一个接口中所有的方法，例如鲁智深是和尚，但只习武。

```
interface 和尚{吃斋，念佛，习武}，

Abstract 天星{吃斋，念佛，习武}，

鲁智 extend 天星{习武}
```

## 2.2.  装饰Decorator

实现**同一接口**,持有原对象的**引用**（通过传参的方式），调用原对象同名方法内前后**增加功能**。

例如：Spring 切面 在所有方法被调用时，记录日志。

## 2.3.  代理Proxy

类似装饰模式，代理持有且**实例化**原对象（比如：在代理构造方法中new原对象）

代理模式的目的是：使用代理对象来**控制**对原有对象的访问

## 2.4.  外观Facade

外观模式**不涉及接口**，解决类与类之间依赖关系，将依赖关系放到一个**外观类**中，类似spring，将类之间的关系写在配置文件中，如：电脑启动（CPU 内存硬盘），电脑是外观类，持有并实例化其他类。

外观模式为系统提供一个**统一的调用接口**，使子系统更加容易使用。

## 2.5.  桥接Bridge

桥（多维的其中一维抽象）持有原始类的接口（另外一维）的引用，通过调用桥的方法，调用原始类，桥接模式可以使多维度中各维度变化分离，使用组合将多维度联系起来，如：车（轿车，公交车）、路（公路，高速公路）；同一个游戏中不同型号的对象，在不同平台（PC，手机）画面的展现。适用于**多维组合解耦**。

```
AbstractRoad{ 
	Vehicle v  
	run(){
		v.run()
	}
}
Highway extend AbstractRoad{}
Freeway extend AbstractRoad{}

interface Vehicle{ run()}
Car impl Vehicle{run()}
Bus impl Vehicle{run()} 
```

与适配器模式区别：

- 适配器模式：改变已有的两个接口，使相容。先有两边的东西，再有适配器
- 桥模式：分离抽象与实现，解决多维的变化问题。先有桥，再有两边的东西。

## 2.6.  组合Composite

又称部分-整体模式，处理树形结构问题，将多个对象组合在一起进行操作，**父子同类型**，**父持有子节点的集合**。

使得用户对单个对象和组合对象的使用具有一致性（同一结构）

样例：文件系统：文件+目录

## 2.7.  享元Flyweight

实现对象的共享，即共享池，实现面向大量对象请求时，对象复用，如：数据库连接池，可以减少内存的开销，通常与工厂模式一起使用，池持有对象的数组，当一个客户端请求时，工厂需要检查当前对象池中是否有符合条件的对象。

- 享元对象包含共享的内部状态，又可以通过方法传参的方式传入外部状态。
- **享元工厂**负责创建和管理享元对象，持有享元的集合

```
ChessFlyWeight{
	String Color;//共享的内部状态,
	FlyweightImpl(String Color){      
	}
	display(Coordinate c){//传入外部状态
	}
}
```

使用享元模式的条件： 

1. 系统中有大量的对象，他们使系统的效率降低。 
2. 这些对象的状态可以分离出所需要的内外两部分。

例子：String类的设计就是享元模式，当两个String 对象所包含的内容相同的时候，JVM 只创建一个String 对象对应这两个不同的对象引用。

围棋的棋子，颜色一样，位置不一样，位置为外部对象Coordinate

```
ChessFlyWeight{
	String Color;//共享的内部状态,
	FlyweightImpl(String Color){      
	}
	display(Coordinate c){//传入外部状态
	}
}
public class Coordinate {
    private int x,y;
}
public static void main(String[] args) {
        ChessFlyWeight chess1=ChessFlyWeightFactory.getChess("黑色");
        ChessFlyWeight chess2=ChessFlyWeightFactory.getChess("黑色");
        System.out.println(chess1);
        System.out.println(chess2);
        chess1.display(new Coordinate(10,10));
        chess2.display(new Coordinate(20,20));
}
```



# 3.  行为型模式

## 3.1.  父与子

### 3.1.1.  策略Strategy(表驱动模式)

多用在算法决策系统，对算法封装，**用户决定使用哪种算法**，如：加减乘除实现同一接口、复杂的if else分支，可以把各种情况定义为字典-实现的映射，根据输入的字典，决定使用哪种算法。

context:环境角色持有一个策略的引用

```
Content{
  Strategy stgy;
  Content(Strategy stgy){
    this.stgy=stgy;
  }
  todo(){
    stgy.todo();
  }
}
```

### 3.1.2.  模板方法Template methed

**抽象类****定义算法结构**，子类实现算法步骤

```
AbstractClass{
  abstract step1();
  abstract step2();
  abstract step3();
  templateMethed(){
   step1();
   step2();
   step3(); 
  }
}
```

## 3.2.  两类之间

### 3.2.1.  观察者Observer

被观察者持有观察者**集合**，提供register，delete，notify（当对象变化时，可以遍历集合，调用观察者的方法）

### 3.2.2.  迭代器Iterator

迭代器模式是与集合**共生共死**的，迭代器对集合对象进行遍历操作，迭代器持有集合对象,集合对象提供返回迭代器的方法（return new 迭代器(this集合对象)），或迭代器是集合的内部成员类，可以直接访问集合对象数据

```
interface Iterator {
     public boolean hasNext();
     public Object next();
}

ConcreteIterator implements Iterator {
     private List list = null;
     private int index; 
     public ConcreteIterator(List list) {//持有集合对象
         super();
         this.list = list;
     }
      public boolean hasNext(){
      	return index < list.getSize()
      }
     public Object next(){
       		Object object = list.get(index);
         index++;
         return object;
     }
} 

 ArrayList impl List {
      public void add(Object obj);  
      public Object get(int index);
      public Iterator iterator(){//返回迭代器
      		return new ConcreteIterator(this);
      } 
      public int getSize();
}
```

样例：java Collection 返回Iterator 方法Iterator()

### 3.2.3.  责任链Chain of responsibility

使多个对象都有机会处理请求，从而避免请求的发送者和接受者之间的耦合关系。**处理者持有下一处理者的引用**形成链，请求在这个链上传递，直到某一对象决定处理该请求。但是发出者并不清楚到底最终那个对象会处理该请求，责任链模式可以实现，在隐瞒客户端的情况下，对系统进行动态的调整。

- 链表中每一个对象都可能而且可以成为入口，而不是必须从链头开始。
- 如果是if else的分支，通常使用策略模式（表驱动模式）
- 如果处理者有上下级关系时，可以考虑使用责任链，如：打牌出牌，流程审批，java异常机制catch顺序，Struts2连接器，tomcat的Filter

```
Handler{
  Handler nextHandler //持有下一处理者的引用
  handleRequest(){
  	//todo or not todo something
    nextHandler.handleRequest();
  }
}
```

### 3.2.4.  命令Command

将一个请求封装成一个对象，实现对命令请求者（Invoker）和命令实现者（Receiver）的**解耦**。

**调用者->命令->执行者**，调用者持有命令的引用，调用命令执行方法，命令持有执行者的引用，命令执行方法调用执行者的执行方法，例如：司令-->命令-->兵

 使用场景：

- 需要记录命令的日志
- 请求者和实现者解耦，不交互

## 3.3.  类状态

### 3.3.1.  备忘录Memento

用于备份恢复对象原先的状态，**对象有创建备忘录，恢复备忘录的方法**，备忘录包含需记录的对象的属性（多属性用Map） ，**备忘录管理类**持有备忘录的引用（多备忘录用MAP），提供和保存备忘录，样例：JDBC事务回滚，Ctrl+Z

```
Object{
state
createMemento(){
 		return new Memento(this.state);  
	}
restoreMemento(Memento memento){
 		this.state=memento.getState();
	}
}

class Memento {  
    private String state = "";  
    public Memento(String state){  
        this.state = state;  
    }  
    public String getState() {  
        return state;  
    }  
    public void setState(String state) {  
        this.state = state;  
    }  
}  
MemoMgr{
    private Memento memento;  
    public Memento getMemento(){  
        return memento;  
    }  
    public void setMemento(Memento memento){  
        this.memento = memento;  
    }
}
```

### 3.3.2.  状态State

当一个对象有多个状态切换时，可以把状态抽象成类，不同状态执行不同操作，IF ELSE

- 状态类：状态名+**行为**，
- 环境类：定义客户感兴趣的接口。维护一个State子类的实例，这个实例定义当前状态。

环境类和状态类之间存在一种**双向关联**关系，

谁定义状态转换？

1. 如果下一个状态跟当前状态有关，各个具体的状态类对象负责状态的转换，
2. 如果下一个状态跟当前状态无关，就可以选择由上下文来决定状态转换

例子：门开关状态，酒店房间状态

与策略模式区别：

- 策略封装多个平行的多变的实现方式
- 状态封装内部变化，以外部行为表现出来

## 3.4.  中间类

### 3.4.1.  访问者Visitor

可以在不改变对象结构的情况下给对象增加新的操作（即访问者的方法）。被访问的元素有accept方法，以访问者为参数，调用访问者的访问方法，访问者的访问方法以被访问对象为参数，**双重分派**（一个方法根据两个宗量（方法接收者和入参）的类型来决定执行不同的代码）

```
Element：accept(Visitor v){  
	v.visit(this);  
}

Visitor: visit(Elemente){
	dosth  
}
```

即在不改变Element的情况下，为Element增加了dosth的操作。

**接收访问者的同时，调用访问者访问方法**：accept->visit

### 3.4.2.  中介者Mediator

用于多个类之间相互交互，网状变星状，中介者使各个对象不需要显示地相互引用，从而使其耦合性松散，而且可以独立地改变他们之间的交互。

- 中介持有所有对象的引用；
- 对象持有中介的引用；
- 中介用来封装**行为**。

```
Mediator{ 
	ColleagueA a;
	ColleagueBb;
	AaffectB();
	BaffectA();
}

ColleagueA
	Mediator m
	dosth(){
		m. AaffectB();
	}
}
```

缺点：中介类易变上帝类

与Façade区别

- Façade为一组内聚的对象，**提供一个统一的外部接口**，
- Mediator为在一组互相协作的对象内部起**协调**作用。

样例：QQ群

### 3.4.3.  解释器Interpreter

对算法进行最小化拆分，用于编译器开发，解释器模式根据问题将算法和参与运算的值组合成一个树型结构，非叶子节点（NonterminalExpression）为算法，叶子节点（TerminalExpression）为参与运算的值，最后通过遍历这颗树求得问题的解。

# Summary

method factory：interface+multiple factory

Abstract factory：multiple method create multiple product

builder：build part，director { builder b, construct(){ b.A(); b.B(); b.C(); }  }

singleton：private instance and constructor

prototype：clone / clone+collection 



adapter：extend / hold reference

decorator：hold reference

proxy：new instance

facade：new all instance

bridge：multi-dimension decoupling，one dimension hold another's reference

composite：one structure，parent  can get child

flyweight：factory（create、get） + collection



strategy：strategy interface + context chose one  strategy reference

template method：abstract class contain abstract step method，define structure of step sequence

observer：subject hold collection of reference of observer，register，delete，notify(call observer‘s method)

iterator：collection.iterator(this)，iterator hold reference of collection 

chain of responsibility：handler-->next handler

command：invoker.do-->command.do--> receiver.do()

memento：create + restore，mementoMgr-->memento

state：state effect handler，context->state

visitor：Subject.accept(visitor){ visitor.visit(this) }

mediator：encapsulate how a set of objects interact   A<-->mediator<-->B

interpret：TerminalExpress，NonTerminalExpress