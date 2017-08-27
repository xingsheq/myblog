---
title: Deploying Hexo to Github and VPS with Travis
date: 2017-08-27 21:49:11
tags: [travis,deploy hexo,github,vps]
category: Travis
---

看到有文章推荐travis ci来自动部署hexo，折腾了几天，终于实现了，但只是一知半解，对个人理解做下记录。

环境：

- 通过github同时备份hexo源代码（hexo分支）和网页文件（master分支）在一个仓库；
- hexo工程通过子模块引用自己修改过的的next-xingsheq主题工程。

目的：

- 在push了hexo分支后，自动生成网页文件并自动部署到mater，同时部署到VPS。

难点：

- travis需要获得github和VPS的读写权限，通过SSH公钥认证实现，本例中travis访问github和VPS使用一套公钥和私钥。

# travis简介

## travis原理

- 可理解为是一个根据.travis.yml预设环境变量，提供的虚拟linux；
- 会自动克隆.travis.yml所在的仓库到这个虚拟linux；
- 可在linux上执行各种命令。

<!-- more -->

## travis部署到github

目的：提交hexo原代码后，自动生成网页文件，部署方式有2种方式：

一、travis clone源代码仓库后，执行hexo g，然后强制推送生成的网页文件到仓库。

1. 在github创建Personal access tokens；
2. 在travis网站添加这个变量GH_TOKEN=Personal access tokens；
3. 在.travis.yml中引用变量，如强制推送：git push --force --quiet "https://{GH_TOKEN}@{GH_REF}" master:master。

二、travis clone源代码仓库后，执行hexo g -d，直接发布，需配置SSH免密登录读，获得github写权限。

## travis部署到VPS

SSH免密登录后通过rsync把public内容同步到网站

## SSH公钥认证

travis与第三方服务器交互，一般通过SSH公钥认证，实现免密登录。

### ssh公钥认证原理

假设 A 为客户机器，B为目标机，为实现从A到B的免密认证，步骤如下：

- A上执行ssh-keygen生成公钥和私钥
- 将 .pub 文件复制到B机器的 .ssh 目录， 并 cat id_dsa.pub >> ~/.ssh/authorized_keys
- 确保A客户机持有私钥，在~/.ssh/id_rsa
- 设置authorized_keys权限$ chmod 600 authorized_keys 
- 设置.ssh目录权限$ chmod 700 -R .ssh

这样A就可以免密SSH访问B，即客户机持有私钥，目标机持有公钥。

### 多私钥管理

1. 新增ssh的配置文件，并修改权限

```
touch ~/.ssh/config
chmod 600 ~/.ssh/config
```

1. 添加config内容

```
Host *.workdomain.com  
    IdentityFile ~/.ssh/id_rsa.work  
    User lee  
 
Host github.com
  User git
  StrictHostKeyChecking no
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
```

## travis加密步骤

相对于travis来说，.travis.yml脚本暴露在外面，所以需对私钥进行加密，使用的时候进行解密，具体步骤：

1. 由于事先不能获得travis虚拟机，可以在任意一个机器上生成公钥和私钥；
2. 然后对私钥加密，获得加密后的秘钥文件id_rsa.enc及解密的命令行；
3. 再把加密后的私钥文件传到travis（通过.travis.yml实现）；
4. 在.travis.yml中使用步骤2获得的解密命令进行解密，生成id_rsa，放到~/.ssh/下面；
5. 公钥上传至需要访问的对方机器：

- 对github来说，就是放到repository的deploy key；
- 对于VPS来说，复制在~/.ssh/authorized_keys

# VPS设置

以下操作都在VPS中操作

## VPS开启SSH公钥认证

vi /etc/ssh/sshd_config

```
RSAAuthentication yes //开启RSA认证
PubkeyAuthentication yes //开启公钥认证
```

## git 安装

travis加密时依赖git命令

```
yum -y install git 
```

## ruby安装

为了使用gem安装travis

http://www.ruby-lang.org/en/downloads/下载你需要的版本

```
wget https://cache.ruby-lang.org/pub/ruby/2.4/ruby-2.4.1.tar.gz
tar-xvzf ruby-2.4.1
cd ruby-2.4.1
./configure
make
make & install
```

## travis安装

```
gem install travis
```

## 生成公钥和私钥

以centos的root用户为例，用户目录为/root

```
ssh-keygen
cd .ssh
cat id_rsa.pub >> authorized_keys
```

在~/.ssh/下生成 id_rsa（私钥）,id_rsa.pub（公钥）,authorized_keys文件

注意，本例中github和VPS共用一套公私钥：

- VPS为目标机，保存公钥到authorized_keys
- github也为目标机，保存公钥到repository的deploy keys（复制id_rsa.pub内容）

## 加密私钥

1. 以centos的root用户为例，用户目录为/root

```
cp .ssh/id_rsa .
travis login //使用github账号登录
travis encrypt-file id_rsa -r xingsheq/blog // -r 为要访问的仓库
```

1. 生成加密文件id_rsa.enc，同时在控制台输出解密命令，如下：

```
openssl aes-256-cbc -K encrypted_1fc90f464345_key -iv encrypted1fc90f464345iv -in id_rsa.enc -out id_rsa -d
```

1. 下载id_rsa.enc，放到本地仓库根目录下，同时创建.travis.yml

# travis配置

主要是解密私钥，并放到~/.ssh/id_rsa，如果有多个私钥，需新增~/.ssh/config配置文件，指定要访问的机器使用哪个私钥。

```
- openssl aes-256-cbc -K $encrypted_1fc90f464345_key -iv $encrypted_1fc90f464345_iv -in id_rsa.enc -out id_rsa -d
- chmod 600 id_rsa
- mv id_rsa ~/.ssh/id_rsa
```

# 常见问题

## 子模块同步问题

如果项目包含git子模块，会报无权限，解决方法：

- clone工程时，先不同步子模块；
- 修改.gitmodules文件，把子模块的同步从SSH方式改为HTTPS，然后再执行同步命令。

```
git:
  submodules: false
  
before_install:  
- sed -i 's/git@github.com:/https:\/\/github.com\//' .gitmodules
- git submodule update --init --recursive
```

## VPS访问权限问题

travis默认ssh_known_hosts只添加了github相关的服务器，如果访问其他服务器，需把服务器加到ssh_known_hosts。

```
addons:
  ssh_known_hosts:
  - 45.62.102.9:xxx
```

