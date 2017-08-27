---
title: Managing Hexo Website With Github
date: 2017-08-27 21:43:59
tags: [hexo github,github,hexo]
category: Github
---

# create hexo project at PC

```
mkdir myblog
cd myblog
hexo init
//启动测试
hexo s
```

# create repository

## create repository at github.com

Head over to [GitHub](https://github.com/) and [create a new repository](https://github.com/new) named *username*.github.io, where *username* is your username (or organization name) on GitHub.

我有自己的VPS主机，不需要通过github访问，创建的是普通的repository,仓库名为myblog，如果需要通过github page访问，就要求创建的仓库名为： *username*.github.io

<!-- more -->

## create master branch

在myblog文件夹右键，选择Git Bash Here

```
cd myblog
git init
touch README.md
git add README.md
git commit -m "first commit"
git remote add origin git@github.com:xingsheq/myblog.git
git push origin master
```

## create hexo branch

```
git branch hexo
//切换到hexo分支
git checkout hexo
git push origin hexo
```

## login in github.com,set hexo branch as default branch

# commit hexo source to hexo branch

现在hexo分支，只有一个README.md文件，可以把需要上传的文件上传到hexo分支，.gitignore文件配置不需要上传的文件或文件夹，默认内容如下：

```
.DS_Store
Thumbs.db
db.json
*.log
node_modules/
public/
.deploy*/
```

提交文件

```
git add .
git commit -m “add hexo source"
git push origin hexo
```



# deploy to master branch

发布前需安装发布模块

```
npm install hexo-deployer-git --save
```

修改_config.yml

```
deploy:
  type: git  
  repo: git@github.com:xingsheq/myblog.git
  branch: master
```

部署

```
hexo g -d
```

现在在github的myblog仓库的master分支，可以看到生成的public目录的网站文件。

# develop theme as submodule

如果有自己定制的theme，希望也通过github来管理代码，可以作为myblog的子模块来管理，可以fork别人的主题后，再上面修改，也可以把已经修改过的主题先加入到repository,已上传已修改的为例。

## create your theme repository or fork from github

在github创建主题repository后，上传theme代码

```
mkdir hexo-theme-next-xingsheq
cd hexo-theme-next-xingsheq
git init
git add .
git commit -m "add my theme"
git remote add origin git@github.com:xingsheq/hexo-theme-next-xingsheq.git
git push origin master
```

## create submodule and link to theme repository

themes/next-xingsheq目录下回clone git@github.com:xingsheq/hexo-theme-next-xingsheq.git

```
git submodule add git@github.com:xingsheq/hexo-theme-next-xingsheq.git themes/next-xingsheq
```

## modify theme and commit

```
cd theme/next-xingsheq 
git add
git commit
git push origin master
```

## commit theme modify to hexo

- 现在myblog工程目录下有一个记录子模块的文件.gitmodules，需要提交更新后，主版本库才变成包含子模块的版本库。

```
cd myblog
git status
git add themes/next-xingsheq
git commit -m "add theme update to hexo"
git push origin hexo
```

- 每次next-xingsheq提交后，主版本库myblog指向的是上次主版本提交后指向的next-xingsheq版本，需要再次提交同步

```
cd myblog
git status
git add themes/next-xingsheq
git commit -m "add theme update to hexo"
git push origin hexo
```

# get repository and develop at another PC

- 克隆带子模组的git库，并不能自动将子模组的版本库克隆出来，需要执行 git submodule init，
  git submodule update
- git submodule update后，HEAD处于游离状态，需要切换到master，再做修改，提交

```
git clone -b hexo git@github.com:xingsheq/myblog.git
cd myblog
cd themes/next-xingsheq/
git submodule init
git submodule update
git checkout master
```