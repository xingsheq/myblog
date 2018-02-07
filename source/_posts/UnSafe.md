

```
title: UnSafe类功能学习
date: 2017-08-27 22:00:05
tags: [java,UnSafe]
category: jdk
```

# Unsafe

## 创建UnSafe实例

默认必须是启动类才能getUnsafe()获得实例

    public static Unsafe getUnsafe() {
        Class var0 = Reflection.getCallerClass();
        //判断是否是JDK内部专属的类，是则可以使用，否者抛出异常。
        //JDK内部专属的类使用系统类加载器加载(系统类加载器为null)
        if(!VM.isSystemDomainLoader(var0.getClassLoader())) {
            throw new SecurityException("Unsafe");
        } else {
            return theUnsafe;
        }
    }
如果是非JDK内部类，可以通过反射获得Unsafe对象，theUnsafe是Unsafe的Field

```
static {
        try {
            PrivilegedExceptionAction e = new PrivilegedExceptionAction() {
                public Unsafe run() throws Exception {
                    Field theUnsafe = Unsafe.class.getDeclaredField("theUnsafe");
                    theUnsafe.setAccessible(true);
                    return (Unsafe)theUnsafe.get((Object)null);
                }
            };
            THE_UNSAFE = (Unsafe) AccessController.doPrivileged(e);
        } catch (Exception var1) {
            throw new RuntimeException("Unable to load unsafe", var1);
        }
    }
```

## 对象内元素offSet

    //获得对象（包含数组）中偏移量offset的int值，当为数组时，意思为指定数组元素指向的内存或值
    public native int getInt(Object obj, long offSet);
    
    //设置对象中偏移量offSet的值为value
    public native void putInt(Object obj, long offSet, int value);
    
    其他类似
    Object/Boolean/Byte/Short/Char/Long/Float/Double

## 堆外内存

```
//获得堆外offSet位置的byte值
public native byte getByte(long position);

//在堆外offSet位置,设置内容value
public native void putByte(long position, byte value);

其他类似
/Short/Char/Long/Float/Double
```

## 内存分配/复制/释放

```
//获得var1指向的内存地址
public native long getAddress(long var1);

//设置var1指向var3
public native void putAddress(long var1, long var3);

//分配var1字节大小的内存，返回起始地址偏移量
public native long allocateMemory(long var1);

//重新给var1起始地址的内存分配长度为var3字节大小的内存，返回新的内存起始地址偏移量
public native long reallocateMemory(long var1, long var3);

//给定的内存块设置value
public native void setMemory(Object obj, long offSet, long bytes, byte value);

//给定的内存块设置value
public void setMemory(long offSet, long bytes, byte value) {
        this.setMemory((Object)null, var1, var3, var5);
}
//从srcObj对象的srcOffset位置开始复制bytes个字节到destObj（从destOffset开始）
public native void copyMemory(Object srcObj, long srcOffset, Object destObj, long destOffset, long bytes);

//从srcOffset复制bytes个字节到destOffset开始的内存块
public void copyMemory(long srcOffset, long destOffset, long bytes) {
        this.copyMemory((Object)null, var1, (Object)null, var3, var5);
}
//释放起始地址为var1的内存
public native void freeMemory(long var1);
```

```
//获取本机内存的页数，这个值永远都是2的幂次方
public native int pageSize();

public native int addressSize();
```

## 数组

```
//获取数组中第一个元素的偏移量(get offset of a first element in the array)  
public native int arrayBaseOffset(java.lang.Class aClass);

//获取数组中一个元素的大小(get size of an element in the array)  
public native int arrayIndexScale(java.lang.Class aClass);  
```

## 对象Field

```
//获取字节对象中非静态方法的偏移量,不管这个字段是private，public还是保护类型
public native long objectFieldOffset(java.lang.reflect.Field field);  

//获取静态变量所属的类在方法区的首地址
public native long staticFieldOffset(Field var1);

//获取一个给定静态Field所在的Class对象
public native Object staticFieldBase(Field f);
```

## 类

```
//告诉虚拟机定义了一个没有安全检查的类，默认情况下这个类加载器和保护域来着调用者类
public native Class<?> defineClass(String var1, byte[] classContent, int begin, int classContentLength, ClassLoader var5, ProtectionDomain var6);

//定义一个类，但是不让它知道类加载器和系统字典
public native Class<?> defineAnonymousClass(Class<?> var1, byte[] classContent, Object[] cpPatches);

//实例化对象，不调用构造函数
public native Object allocateInstance(Class<?> var1) throws InstantiationException;

//给定class是否应被初始化
public native boolean shouldBeInitialized(Class<?> var1);

//确保给定class被初始化，这往往需要结合基类的静态域（field）
public native void ensureClassInitialized(Class c);
```

## 异常

```
//包装异常为运行时异常
public native void throwException(Throwable var1);
```

## CAS

```
public final native boolean compareAndSwapObject(Object obj, long address, Object oldValue, Object newValue);

public final native boolean compareAndSwapInt(Object obj, long address, int oldValue, int newValue);

public final native boolean compareAndSwapLong(Object obj, long address, long oldValue, long newValue);
```

## get/putXXVolatile

内存屏障+立即可见，写操作使用较慢的存储-加载(store-load) barrier

```
//获得对象offSet的值，支持volatile load语义
public native Object getObjectVolatile(Object obj, long offSet);

//设置对象offSet的值，支持volatile load语义，
public native void putObjectVolatile(Object obj, long offSet, Object value);

其他类似
Int/Boolean/Byte/Short/Char/Long/Float/Double
```

## putOrderedObject/Int/Long

是putObjectVolatile的内存屏障非立即可见版本，使用的是快速的存储-存储(store-store) barrier

```
public native void putOrderedObject(Object var1, long var2, Object var4);

public native void putOrderedInt(Object var1, long var2, int var4);

public native void putOrderedLong(Object var1, long var2, long var4);
```

## 线程park/unpark

```
//解除阻塞线程
public native void unpark(Object thread);
//阻塞当前线程，boolean:true,绝对时间毫秒，false:相对时间，纳秒
public native void park(boolean var1, long var2);
```

将一个线程进行挂起是通过park方法实现的，调用 park后，线程将一直阻塞直到超时或者中断等条件出现。unpark可以终止一个挂起的线程，使其恢复正常。整个并发框架中对线程的挂起操作被封装在 LockSupport类中，LockSupport类中有各种版本pack方法，但最终都调用了Unsafe.park()方法。

## 获取负载

```
//获取系统在不同时间系统的负载情况
public native int getLoadAverage(double[] loadavg, int nelems);
```

## getAndAddXX

```
public final int getAndAddInt(Object var1, long var2, int var4) {
        int var5;
        do {
            var5 = this.getIntVolatile(var1, var2);
        } while(!this.compareAndSwapInt(var1, var2, var5, var5 + var4));
        return var5;
    }
public final long getAndAddLong(Object var1, long var2, long var4) {}
   
public final int getAndSetInt(Object var1, long var2, int var4) {
        int var5;
        do {
            var5 = this.getIntVolatile(var1, var2);
        } while(!this.compareAndSwapInt(var1, var2, var5, var4));
        return var5;
}

public final long getAndSetLong(Object var1, long var2, long var4) {}

public final Object getAndSetObject(Object var1, long var2, Object var4) {}
```

## 内存屏障

```
public native void loadFence();
public native void storeFence();
public native void fullFence();
```

# 使用案例

## 非常规的对象实例化

```
public native Object allocateInstance(Class<?> var1) throws InstantiationException;
```

- allocateInstance()方法提供了另一种创建实例的途径。通常我们可以用new或者反射来实例化对象，使用allocateInstance()方法可以直接生成对象实例，且无需调用构造方法和其它初始化方法。
- 这在对象反序列化的时候会很有用，能够重建和设置final字段，而不需要调用构造方法。

## 修改对象属性

```
public class TrapEntity {
    int id;
    String alarmName;
    public int getId() {
        return id;
    }
    public void setId(int id) {
        this.id = id;
    }
    public String getAlarmName() {
        return alarmName;
    }
    public void setAlarmName(String alarmName) {
        this.alarmName = alarmName;
    }
}
```

```
//通过offSet修改对象属性
    private static void changeValueByOffSetTest() {
        TrapEntity entity = new TrapEntity();
        entity.setId(1);
        entity.setAlarmName("alarm1");
        try {
            long alarmNameOffSet = 	UNSAFE.objectFieldOffset(entity.getClass().getDeclaredField("alarmName"));
            long idOffSet = UNSAFE.objectFieldOffset(entity.getClass().getDeclaredField("id"));
            System.out.println(alarmNameOffSet);
            UNSAFE.putObject(entity, alarmNameOffSet, "alarmName2");
            System.out.println(entity.getAlarmName());
            System.out.println(idOffSet);
            UNSAFE.putInt(entity, idOffSet, 2);
            System.out.println(entity.getId());

        } catch (NoSuchFieldException e) {
            e.printStackTrace();
        }
    }
        
    //通过内存位置修改对象属性
    private static void changeValueByPositionTest() {
        TrapEntity entity = new TrapEntity();
        entity.setId(1);
        entity.setAlarmName("alarm1");
        Long pos = getObjectPos(entity);
        System.out.println("getObjectPos = " + pos);

        try {
            long idOffSet = UNSAFE.objectFieldOffset(entity.getClass().getDeclaredField("id"));
            long idPos = pos + idOffSet;
            System.out.println("old value = " + UNSAFE.getInt(idPos));
            UNSAFE.putInt(idPos, 2);
            System.out.println("new value = " + entity.getId());

        } catch (NoSuchFieldException e) {
            e.printStackTrace();
        }
    }
```

## 计算对象大小

| 数据类型    | 所占空间（byte） |
| ------- | ---------- |
| byte    | 1          |
| short   | 2          |
| int     | 4          |
| long    | 8          |
| float   | 4          |
| double  | 8          |
| char    | 2          |
| boolean | 1          |
| Object  | 对象引用4/8    |

| 对象类型    | 内存布局构成                                   |
| ------- | ---------------------------------------- |
| 一般非数组对象 | 8个字节对象头(mark) + 4/8字节对象指针 + 数据区 + padding内存对齐(按照8的倍数对齐) |
| 数组对象    | 8个字节对象头(mark) + 4/8字节对象指针 + 4字节数组长度 + 数据区 + padding内存对齐(按照8的倍数对齐) |

对象指针究竟是4字节还是8字节要看是否开启指针压缩。Oracle JDK从6 update 23开始在64位系统上会默认开启压缩指针，基础数据包装类及对象引用会变为4字节。

计算原理：获得所有Field（包括父类Field）的偏移量，取最大偏移量对应的属性最大4（开启压缩）/8字节，object对象大小是8的倍数，不足时做对齐填充，所以对象大小为：(maxOffSet/8+1)*8

```
public class ObjectA {
    String str;   // 4
    int int1;       // 4
    Integer Int2;
    byte byte1;      // 1
    Byte Byte2;
    char char1; //2
    Character Char2;
    boolean boolean1;//1
    Boolean BooLean2;
    long long1;//4
    Long Long2;
    float float1;//4
    Float Float2;
    double double1;//
    Double Double2;
    ObjectB obj;  //4
    int[] intArray;
    volatile ObjectB[] objs;
    volatile ObjectB[] objs2;
}
```

```
public class ObjectB {
}
```

```
  //**获得对象大小
    public static long sizeOf(Object obj) {
        Class clazz = obj.getClass();
        //为了观察每个field大小，对field的offSet进行了排序，后者-前者=前者大小
        TreeSet<Field> hashSet = new TreeSet(new Comparator() {
            @Override
            public int compare(Object o1, Object o2) {
                Field f1=(Field)o1;
                Field f2=(Field)o2;
                long offSet1 = UNSAFE.objectFieldOffset(f1);
                long offSet2 = UNSAFE.objectFieldOffset(f2);
                return Integer.parseInt((offSet1 - offSet2)+"");
            }
        });

        while (clazz != Object.class) {
            Field[] fields = clazz.getDeclaredFields();
            for (Field field : fields) {
                if (!Modifier.isStatic(field.getModifiers())) {
                    hashSet.add(field);
                }
            }
            clazz = clazz.getSuperclass();
        }
        long maxOffSet=0;
        for (Field field : hashSet) {
            long offSet = UNSAFE.objectFieldOffset(field);
            System.out.println(field.getName() + " offSet = " + offSet);
            if(offSet>maxOffSet){
                maxOffSet=offSet;
            }
        }
        System.out.println("maxOffSet = "+maxOffSet);

        return (maxOffSet/8+1)*8;
    }
}
```

开启指针压缩结果：

```
int1 offSet = 12
long1 offSet = 16
double1 offSet = 24
float1 offSet = 32
char1 offSet = 36
byte1 offSet = 38
boolean1 offSet = 39
str offSet = 40
Int2 offSet = 44
Byte2 offSet = 48
Char2 offSet = 52
BooLean2 offSet = 56
Long2 offSet = 60
Float2 offSet = 64
Double2 offSet = 68
obj offSet = 72
intArray offSet = 76
objs offSet = 80
objs2 offSet = 84
maxOffSet = 84
88
```

未开启指针压缩结果：

```
long1 offSet = 16
double1 offSet = 24
int1 offSet = 32
float1 offSet = 36
char1 offSet = 40
byte1 offSet = 42
boolean1 offSet = 43
str offSet = 48
Int2 offSet = 56
Byte2 offSet = 64
Char2 offSet = 72
BooLean2 offSet = 80
Long2 offSet = 88
Float2 offSet = 96
Double2 offSet = 104
obj offSet = 112
intArray offSet = 120
objs offSet = 128
objs2 offSet = 136
maxOffSet = 136
144
```

根据打印的结果可知：

开启了指针压缩，基础数据包装类及对象引用被压缩为4字节，最小属性起始为为12=8个字节对象头(mark) + 4字节对象指针，属性实际数据应该是在13，所以根据maxOffSet=84得出对象实际大小范围在maxOffSet+1=85到maxOffSet+4=88之间，padding后size=88，与公式(maxOffSet/8+1)*8计算一致

未开启了指针压缩，基础数据包装类及对象引用为8字节，最小属性起始为为16=8个字节对象头(mark) + 8字节对象指针，属性实际数据应该是在17，所以根据maxOffSet=136得出对象大小范围在maxOffSet+1=137到maxOffSet+8=144之间，padding后size=155，与公式(maxOffSet/8+1)*8计算一致

## 浅拷贝 

通过复制内存数据的方式实现浅拷贝。

浅拷贝：只复制值对象，不复制引用对象，引用对象指向同一对象

```
public static void shallowCopyTest() {
        ObjectA objectA=new ObjectA();
        objectA.setStr("I'm ObjectA");
        objectA.setInt1(1);
        long size = sizeOf(objectA);//获得对象大小
        long start = getObjectPos(objectA);//获得obj起始内存地址
        System.out.println("getObjectPos = "+start);
        long address = UNSAFE.allocateMemory(size);//分配size大小的内存空间，返回内存起始地址
        System.out.println("allocateMemory address = "+address);
        UNSAFE.copyMemory(start, address, size); //从start位copy size个大小的内存内容到目标地址address
        ObjectA ObjectACopy= (ObjectA) createObjByPointer(address);
        ObjectACopy.setInt1(11);
        //浅复制只能修改基本数据类型，修改对象引用运行会报error
//        ObjectACopy.setStr("I'm ObjectA Copy");//A fatal error has been detected by the Java Runtime Environment
        System.out.println(objectA.getInt1());
        System.out.println(ObjectACopy.getInt1());
        UNSAFE.freeMemory(address);
    }
```



```
 public static Object shallowCopy(Object obj) {
        long size = sizeOf(obj);//获得对象大小
        long start = getObjectPos(obj);//获得obj起始内存地址
        long address = UNSAFE.allocateMemory(size);//分配size大小的内存空间，返回内存起始地址
        UNSAFE.copyMemory(start, address, size); //从start位copy size个大小的内存内容到目标地址address
        return createObjByPointer(address);
    }
```

### 获取对象内存地址

```
//获得对象内存位置
public static Long getObjectPos(Object obj) {
        Object[] array = new Object[]{obj};
        return UNSAFE.getLong(array, Long.valueOf(UNSAFE.ARRAY_OBJECT_BASE_OFFSET));//获得baseOffset位置内存地址
    }
```

### 创建对象：指定内存地址的方式

```
//通过制定内存指针位置的方式创建对象
public static Object createObjByPointer(long address) {
        Object[] array = new Object[] {null};
        long baseOffset = UNSAFE.arrayBaseOffset(Object[].class);
        UNSAFE.putLong(array, baseOffset, address);//baseOffset指向address
        return array[0];
}
```

## 动态加载类defineClass

```
byte[] classContents = getClassContent();
Class c = getUnsafe().defineClass(
              null, classContents, 0, classContents.length);
    c.getMethod("a").invoke(c.newInstance(), null); // 1
getClassContent()方法，将一个class文件，读取到一个byte数组。
 
private static byte[] getClassContent() throws Exception {
    File f = new File("/tmp/A.class");
    FileInputStream input = new FileInputStream(f);
    byte[] content = new byte[(int)f.length()];
    input.read(content);
    input.close();
    return content;
}
```

## 包装受检异常为运行时异常(不建议使用)

```
getUnsafe().throwException(new IOException());
```

## 堆外分配内存

```
address = getUnsafe().allocateMemory(size);
```

## 无锁并发CAS

```
class CASCounter implements Counter {
    private volatile long counter = 0;
    private Unsafe unsafe;
    private long offset;

    public CASCounter() throws Exception {
        unsafe = getUnsafe();
        offset = unsafe.objectFieldOffset(CASCounter.class.getDeclaredField("counter"));
    }

    @Override
    public void increment() {
        long before = counter;
        while (!unsafe.compareAndSwapLong(this, offset, before, before + 1)) {
            before = counter;
        }
    }

    @Override
    public long getCounter() {
        return counter;
    }
}
```

# 测试代码

## UnSafeUtils

```
package rocky.com.util;

import sun.misc.Unsafe;

import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.security.AccessController;
import java.security.PrivilegedExceptionAction;
import java.util.Comparator;
import java.util.TreeSet;

public class UnSafeUtils {
    private static final Unsafe UNSAFE;
    static {
        try {
            PrivilegedExceptionAction e = new PrivilegedExceptionAction() {
                public Unsafe run() throws Exception {
                    Field theUnsafe = Unsafe.class.getDeclaredField("theUnsafe");
                    theUnsafe.setAccessible(true);
                    return (Unsafe)theUnsafe.get((Object)null);
                }
            };
            UNSAFE = (Unsafe) AccessController.doPrivileged(e);
        } catch (Exception var1) {
            throw new RuntimeException("Unable to load unsafe", var1);
        }
    }

    public static Unsafe getUnsafe() {
        return UNSAFE;
    }


    //**获得对象大小
    public static long sizeOf(Object obj) {
        Class clazz = obj.getClass();
        //为了观察每个field大小，对field的offSet进行了排序，后者-前者=前者大小
        TreeSet<Field> hashSet = new TreeSet(new Comparator() {
            @Override
            public int compare(Object o1, Object o2) {
                Field f1=(Field)o1;
                Field f2=(Field)o2;
                long offSet1 = UNSAFE.objectFieldOffset(f1);
                long offSet2 = UNSAFE.objectFieldOffset(f2);
                return Integer.parseInt((offSet1 - offSet2)+"");
            }
        });

        while (clazz != Object.class) {
            Field[] fields = clazz.getDeclaredFields();
            for (Field field : fields) {
                if (!Modifier.isStatic(field.getModifiers())) {
                    hashSet.add(field);
                }
            }
            clazz = clazz.getSuperclass();
        }
        long maxOffSet=0;
        for (Field field : hashSet) {
            long offSet = UNSAFE.objectFieldOffset(field);
            System.out.println(field.getName() + " offSet = " + offSet);
            if(offSet>maxOffSet){
                maxOffSet=offSet;
            }
        }
        System.out.println("maxOffSet = "+maxOffSet);

        return (maxOffSet/8+1)*8;
    }

    //浅拷贝
    public static Object shallowCopy(Object obj) {
        long size = sizeOf(obj);//获得对象大小
        long start = getObjectPos(obj);//获得obj起始内存地址
        long address = UNSAFE.allocateMemory(size);//分配size大小的内存空间，返回内存起始地址
        UNSAFE.copyMemory(start, address, size); //从start位copy size个大小的内存内容到目标地址address
        return createObjByPointer(address);
    }

    //获得对象内存位置
    public static Long getObjectPos(Object obj) {
        Object[] array = new Object[]{obj};
        return UNSAFE.getLong(array, Long.valueOf(UNSAFE.ARRAY_OBJECT_BASE_OFFSET));//获得baseOffset位置内存地址
    }
    //通过制定内存指针位置的方式创建对象
    public static Object createObjByPointer(long address) {
        Object[] array = new Object[] {null};
        long baseOffset = UNSAFE.arrayBaseOffset(Object[].class);
        UNSAFE.putLong(array, baseOffset, address);//baseOffset指向address
        return array[0];
    }

}

```

## POJO

```
public class TrapEntity {
    int id;
    String alarmName;

    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public String getAlarmName() {
        return alarmName;
    }

    public void setAlarmName(String alarmName) {
        this.alarmName = alarmName;
    }
}
```

```
public class ObjectA {
    String str;   // 4
    int int1;       // 4
    Integer Int2;
    byte byte1;      // 1
    Byte Byte2;
    char char1; //2
    Character Char2;
    boolean boolean1;//1
    Boolean BooLean2;
    long long1;//4
    Long Long2;
    float float1;//4
    Float Float2;
    double double1;//8
    Double Double2;
    ObjectB obj;  //4
    int[] intArray;
    volatile ObjectB[] objs;
    volatile ObjectB[] objs2;

//get/set 省略
}
```

```
public class ObjectB {
}
```

## UnSafeTest

```
package rocky.com;

import rocky.com.pojo.TrapEntity;
import rocky.com.util.UnSafeUtils;
import sun.misc.Unsafe;


public class UnSafeTest {


    private static final Unsafe UNSAFE = UnSafeUtils.getUnsafe();

    public static void main(String[] args) {
//        changeValueByOffSetTest();
//        printConstant();
//        changeValueByPositionTest();
       long size= UnSafeUtils.sizeOf(new ObjectA());
       System.out.println(size);
//        shallowCopyTest();
        System.exit(0);
    }



    //通过内存位置修改对象属性
    private static void changeValueByPositionTest() {
        TrapEntity entity = new TrapEntity();
        entity.setId(1);
        entity.setAlarmName("alarm1");
        Long pos = UnSafeUtils.getObjectPos(entity);
        System.out.println("getObjectPos = " + pos);

        try {
            long idOffSet = UNSAFE.objectFieldOffset(entity.getClass().getDeclaredField("id"));
            long idPos = pos + idOffSet;
            System.out.println("old value = " + UNSAFE.getInt(idPos));
//            System.out.println("byte = "+b);
            UNSAFE.putInt(idPos, 2);
            System.out.println("new value = " + entity.getId());

        } catch (NoSuchFieldException e) {
            e.printStackTrace();
        }
    }

    public static void printConstant() {
        System.out.println("ADDRESS_SIZE = "+UNSAFE.ADDRESS_SIZE);
        System.out.println("ARRAY_OBJECT_BASE_OFFSET = "+UNSAFE.ARRAY_OBJECT_BASE_OFFSET);
        System.out.println("ARRAY_OBJECT_INDEX_SCALE = "+UNSAFE.ARRAY_OBJECT_INDEX_SCALE);

    }
    public static void shallowCopyTest() {
        ObjectA objectA=new ObjectA();
        objectA.setStr("I'm ObjectA");
        objectA.setInt1(1);
        long size = UnSafeUtils.sizeOf(objectA);//获得对象大小
        long start = UnSafeUtils.getObjectPos(objectA);//获得obj起始内存地址
        System.out.println("getObjectPos = "+start);
        long address = UNSAFE.allocateMemory(size);//分配size大小的内存空间，返回内存起始地址
        System.out.println("allocateMemory address = "+address);
        UNSAFE.copyMemory(start, address, size); //从start位copy size个大小的内存内容到目标地址address
        ObjectA ObjectACopy= (ObjectA) UnSafeUtils.createObjByPointer(address);
        ObjectACopy.setInt1(11);
        //浅复制只能修改基本数据类型，修改对象引用运行会报error
//        ObjectACopy.setStr("I'm ObjectA Copy");//A fatal error has been detected by the Java Runtime Environment
        System.out.println(objectA.getInt1());
        System.out.println(ObjectACopy.getInt1());
        UNSAFE.freeMemory(address);
    }


    //通过offSet修改对象属性
    private static void changeValueByOffSetTest() {
        TrapEntity entity = new TrapEntity();
        entity.setId(1);
        entity.setAlarmName("alarm1");
        try {
            long alarmNameOffSet = UNSAFE.objectFieldOffset(entity.getClass().getDeclaredField("alarmName"));
            long idOffSet = UNSAFE.objectFieldOffset(entity.getClass().getDeclaredField("id"));
            System.out.println(alarmNameOffSet);
            UNSAFE.putObject(entity, alarmNameOffSet, "alarmName2");
            System.out.println(entity.getAlarmName());
            System.out.println(idOffSet);
            UNSAFE.putInt(entity, idOffSet, 2);
            System.out.println(entity.getId());

        } catch (NoSuchFieldException e) {
            e.printStackTrace();
        }
    }
}
```

