---
title: Optimizing Hexo with Next Theme
date: 2017-08-22 21:30:28
tags: [hexo optimize,hexo优化]
category: Hexo
---

## CSS优化

css修改原则：尽量不修改原css代码，而是写在custom.styl，主要修改的custom.styl文件有：

- 全局css文件：\themes\next\source\css\_custom\custom.styl
- 定义变量的css文件：\themes\next\source\css\_variables\custom.styl

### 修改网站标题栏背景颜色

在next/source/css/_custom目录下面专门提供了custom.styl供我们自定义样式的

```
.site-meta {
  background: $blue; //修改为自己喜欢的颜色
 }
```

显示效果：

![显示效果](http://oulmk4pq1.bkt.clouddn.com/logo.png)

<!-- more -->

### 侧栏社交链接设置居中显示

```
.links-of-author-item {
  text-align: center;
  }
```

显示效果：

![](http://oulmk4pq1.bkt.clouddn.com/socialLink.png)

### 友情链接居左

```
.links-of-blogroll-title {
  text-align: left;
}
```

### 修改文章内链接文本样式

将链接文本设置为蓝色，鼠标划过时文字颜色加深，并显示下划线

```
.post-body p a{
  color: #0593d3;
  border-bottom: none;
  &:hover {
    color: #0477ab;
    text-decoration: underline;
  }
}
```

### 修改友情链接样式

```
.links-of-blogroll-item a{
  color: #0593d3;
  border-bottom: none;
  &:hover {
    color: #0477ab;
    text-decoration: underline;
  }
}
```

### 修改上一篇，下一篇链接文本样式

```
.post-nav-item a{
  color: #0593d3;
  border-bottom: none;
  &:hover {
    color: #0477ab;
    text-decoration: underline;
  }
}
```

### 修改标签云样式

```
.tag-cloud {
  text-align: center;
  a {
    display: inline-block;
    margin: 15px;
//	border-bottom: none;
	&:hover {
    color: #000;
	font-weight: bold;
    border-bottom: 2px solid #000;}
  }
}
```

### 修改字体大小

修改：themes\next\source\css\_variables\custom.styl

```
$font-family-headings = Monda, "PingFang SC", "Microsoft YaHei", sans-serif//标题字体族，修改成你期望的字体族
$font-size-headings-base = 28px //是各级标题大小
$font-size-headings-step  = 2px
 
$font-family-base = Monda, "PingFang SC", "Microsoft YaHei", sans-serif //正文字体族，修改成你期望的字体族
$font-size-base = 16px // 正文字体的大小

$code-font-family = "Input Mono", "PT Mono", Consolas, Monaco, Menlo, monospace // 代码字体
$code-font-size = 14px // 代码字体的大小
```

### 调整页面宽度，减少左右侧留白

- 在Mist和Muse风格可以用下面的方法

修改成你期望的宽度

```
$content-desktop = 700px
```

当视窗超过 1600px 后的宽度

```
$content-desktop-large = 900px
```

- Pisces风格时可以用下面的方法

1. 修改修改：themes/next/source/css/_variables/custom.styl

```
$main-desktop = 80% //可设置其他值
```

1. 修改themes/next/source/css/_schemes/Pisces/_layout.styl找到.content-wrap，修改为如下内容

```
.content-wrap { width: calc(100% - 260px); }
```

注意：网上其他方式，在custom.styl或者_layout.styl直接添加内容，移动端会错位

## 主题_config.yml配置

### 修改主题样式

```
scheme: Pisces
#scheme: Muse
#scheme: Mist
#scheme: Pisces
#scheme: Gemini
```

### 文章结尾显示微信二维码

```
wechat_subscriber:
  enabled: true
  qcode: http://oulmk4pq1.bkt.clouddn.com/rockynote.png
  description: 扫一扫，用手机访问本站
```

### 侧边栏显示友情链接

```
links_title: 友情链接
links_layout: inline
links_icon: link  # 设置图标
links:
  祁较瘦: http://qijiaoshou.com
```

### 侧边栏显示社交媒体链接

```
social:
  GitHub: https://github.com/xingsheq
  Weibo: http://weibo.com/iterator
```



### 修改Donate为中文打赏

1. 修改\themes\next\layout\_macro\reward.swig设置为可配置变量
   ![](http://oulmk4pq1.bkt.clouddn.com/donate_modify.png)
2. 修改_config.xml

```
reward_comment:
reward_text: 打赏
wechatpay: http://xx.png
wechatpay_text: 微信打赏
alipay: http://xx.png
alipay_text: 支付宝打赏
```

### 添加分享

```
jiathis:
	uid: xxxx
```

## 其他优化

### 使用more控制摘要

在文章中插入\<!-- more -->