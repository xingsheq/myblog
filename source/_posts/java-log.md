---
title: java日志体系
date: 2018-02-08 13:05:28
tags: [java日志]
category: 3rd party jars
---

java有很多种第三方日志实现，目前常用的是slf4j，要使用slf4j需要3个jar

- 日志框架：sfl4j-api
- 日志实现：log4j,logback,log4j2,jul,jcl等
- 桥接器：每种日志实现有一个对应的sfl4j桥接器

# java日志体系

## log框架

框架只提供接口，并不提供具体实现，常用框架有：

- java commons-logging（JCL）：动态适配器模式，class.forName(adapterClassName)

  Commons logging是通过动态查找机制，在程序运行时，使用自己的ClassLoader寻找和载入本地具体的实现。由于OSGi不同的插件使用独立的ClassLoader，OSGI的这种机制保证了插件互相独立, 其机制限制了commons logging在OSGi中的正常使用。

- slf4j：简单日志门面，桥接模式

## log具体实现

- log4j:依赖disruptor并发编程
- log4j2
- logback
- jul：java.util.logging
- jcl：java commons-logging内部有个简单的实现，不常用

## slf4j桥接器

桥接slf4j与具体实现

- log4j：slf4j-log4j12
- log4j2：log4j-slf4j-impl
- logback：logback-classic
- jul：slf4j-jdk
- jcl：slf4j-jcl：桥接jcl，jcl适配log4j，如果没有引入log4j，适配jul

## slf4j替换器

用于整合统一日志框架，替代老的对应的框架，如jcl-over-slf4j.jar，类名和jcl一样，使用时删除jcl的jar，则日志框架被替换为slf4j

- jcl-over-slf4j
- jul-over-slf4j
- log4j-over-slf4j

# 问题痛点

- osgi中存在问题，由于OSGi不同的插件使用独立的ClassLoader，OSGI的这种机制保证了插件互相独立, 但限制了commons logging在OSGi中的正常使用。因为commons logging使用自己的ClassLoader寻找和载入本地具体的实现。
- 框架和应用使用不同实现

## 需求

spring采用jcl+log4j，应用使用slf4j+log4j2，整合到一个日志文件，现状：

- app:slf4j+log4j2-日志1
- 框架：jcl+log4j-日志2
- 容器：jul（java.util.logging）-日志2

## 方案

- 方案1：slf4j桥接log4j，app不使用log4j2
- 方案2：jcl连到slf4j，jcl-over-slf4j，删除jcl+log4j

jcl-over-slf4j：替换器，替代jcl，类名和jcl一样，类似狸猫换太子，类似的有jul-over-slf4j，log4j-over-slf4j

# log4j2配置文件样例

log4j2+slf4j配置方案：logger-appender-file

```
<Configuration status=info> slf4j自身状态日志
    <appenders>
        <Console/>
        <file/>
        <rollingFile>
    </appenders>

	<loggers>
      <root level=> 所有
          <appender ref=console>
          <appender ref=file>
      </root>
      <logger name="com.xx"></logger>
      <sysnRoot>
	</loggers>
</Configuration>

```

