---
title: Create a Blog with Hexo
date: 2017-08-27 22:00:05
tags: [hexo,blog,git,github,travis]
---

记录使用hexo搭建个人博客的过程，及对使用的技术的学习

# hexo

静态网页博客系统，依赖nodejs，具体安装过程省略。

# next

hexo主题，本站在此基础上进行修改，并上传到github进行代码托管，在myblog中作为子模块引用，具体修改内容参考笔记：[Optimizing Hexo with Next Theme](http://rockynote.com/2017/08/22/Optimizing-Hexo-with-Next-Theme)

<!-- more -->

# git

版本管理工具，参考笔记：[Git Learning](http://rockynote.com/2017/08/27/Git-Learning)

# github

支持git的代码托管平台，

- 使用github托管自己的hexo源代码及生成的网页文件在一个仓库myblog；
- 使用github托管自己修改的next主题；
- myblog仓库使用子模块引用自己修改的next主题。

参考笔记：[Managing Hexo Website With Github](http://rockynote.com/2017/08/27/Managing-Hexo-Website-With-Github)

# travis ci

持续集成平台，使用它实现hexo的自动部署到VPS，参考笔记：[Deploying Hexo to Github and VPS with Travis](http://rockynote.com/2017/08/27/Deploying-Hexo-to-Github-and-VPS-with-Travis/)