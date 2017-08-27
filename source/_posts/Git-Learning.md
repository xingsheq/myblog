---
title: Git Learning
date: 2017-08-27 21:27:55
tags: [git,git submodule,git tags]
category: Git
---

# git原理

参考：http://www.jianshu.com/p/8f424c40da82

## 基本概念

snap快照 ：保存文件结构tree和文件内容clob

commit对象：指向snap，每个commit都有唯一的id

![](http://oulmk4pq1.bkt.clouddn.com/git/snap.png)

branch：指向commit对象，也可以认为是一种游标，用于版本控制，每个开发人员都可以创建分支，做自己想做的事，而不妨碍其他工作成员。只要不合并及提交到主要版本库。

<!-- more -->

HEAD：指向branch，HEAD是当前工作区域的引用，可以认为是一种游标。使用git checkeout master切换分支实际是修改HEAD的指向

![](http://oulmk4pq1.bkt.clouddn.com/git/branch.png)

Merge：分支合并到另外一个分支上，分为Fast Forward和No Fast Forward

- Fast Forward：主分支没有新的提交，merge时，只是master指针的移动，如果合并和删除了分支topic，就不知道之前有进行过分支合并。

![](http://oulmk4pq1.bkt.clouddn.com/git/git_merger_ff.png)

- No Fast Forward：主分支和分支有冲突，代码需要合并，这时会根据共同的祖先E和每个分支最后一个提交（C，G）进行比较合并，生成一个新的提交H，即使删除了topic,通过查看分支合并图（git log --graph --pretty=oneline），也会看到有分支合并进来。

![](http://oulmk4pq1.bkt.clouddn.com/git/merge_no_ff.png)

- 可以强制使用No Fast Forward，这时，即使可以Fast Forward，也会生成一个新的提交

![](http://oulmk4pq1.bkt.clouddn.com/git/git_merge_no_ff.png)

## 使用场景

### 协同开发及版本管理

master：稳定版本，发布版本使用，不在上面开发，与远程仓库同步

dev：开发工作在这个分支进行，开发完成，合并到master，与远程仓库同步

bob/michael：每个码农的分支，基于dev，开发完成后合并到dev，自己控制是否与远程仓库同步



![](http://oulmk4pq1.bkt.clouddn.com/git/branch_work.png)

### 紧急bug修复（hotfix）

新来紧急修复工作，当前分支未完成，可以先储藏工作现场

```
git stash
```

再建bug分支，**以master为基础**，做修复工作

```
git checkout master
git checkout -b issue-101
git add .
git commit -m '修复完成'
```

修复完成后，**合并到master和dev**，并在master上**打标签**，删除bug分支

```
git checkout master
git merge --no-ff -m '修复完成-合并' issue-101
git tag -a 1.2.1 #tag操作

git checkout dev
git merge --no-ff -m '修复完成-合并' issue-101

git branch -d issue-101
```

完成后恢复之前储藏的工作现场

```
git checkout dev
git stash pop
```

### feature新需求开发

类似bug修复，**以dev为基础**，合并到dev，合并前如果取消该功能，可强制删除分支

```
git checkout -b feature-vulcan
git add vulcan.php
git commit -m 'add vulcan Function'
git checkout dev
git merge --no-ff -m '修复完成-合并' feature-vulcan

git branch -d feature-vulcan //警告：没有合并的分支不能删除
git branch -D feature-vulcan //强行删除
```

## 最佳实践

除了上面介绍的使用场景，增加发布分支Release Branch，使用发布分支的好处是，当从develop分支中创建发布分支以后，develop分支便可以进行新版本之后需求的研发工作，从而既不会影响到最新的研发进度，也不会影响到新版本的发布。

使用方法：以**dev为基础**创建发布分支，可以认为是一个里程碑，交付分支前的功能，对分支前的功能进行bug的修复，并合并到dev，最终完成后**合并到dev和master**，并**打标签**。

![](http://oulmk4pq1.bkt.clouddn.com/git/git all.png)

# git使用

## git基础操作

参考 http://www.jianshu.com/p/6b35841c873a

### commit

1. 本地目录加入版本控制

```
git init
```

1. 添加文件

```
git add -A   保存所有的修改
git add .     保存新的添加和修改，但是不包括删除
git add -u   保存修改和删除，但是不包括新建文件。
```

1. 提交

```
git commit -m "comment"
```

1. 本地目录建立与远端仓库的联系

```
git remote add origin urlxxx
```

1. 推送到远程库

```
git push origin master 同步到远端仓库master分支
```

### delete

```
git rm readme.txt 从当前跟踪列表移除文件，并完全删除
git rm –cached readme.txt 仅在暂存区删除，保留文件在当前目录，不再跟踪
```

### clone/fetch/pull

克隆远端仓库到本地目录，clone来的代码，已自动建立与远端仓库的联系

```
git clone (-b branch) urlxxx
```

下载最新代码，但不merge

```
git fetch
```

下载最新代码，自动merge

```
git pull
```

git fetch更安全一些，在merge前，可以查看更新情况，然后再决定是否合并

### view

- git log 查看日志

```
git log 查看日志
git log //查看所有日志
git reflog //查看所有的版本号
git log --pretty=oneline //将信息显示到一行
git log --graph //查看分支合并图
git log --graph --pretty=oneline //以简要信息显示分支合并图
git log --pretty=oneline --abbrev-commit //参考所有提交
```

- git status 查看本地文件状态


- git remote -v 查看远端仓库,显示可以fetch和pull的仓库url

## branch

### create

```
git branch dev
git checkout dev
等同于
git branch -b dev
```

### delete

```
git branch -d xx //警告：没有合并的分支不能删除
git branch -D xx //强行删除
```

### view

```
git branch -v
```

### merge

```
git checkout master //切换到要合并到的分支
方式一:Fast forward模式，这种模式下，分支与master无冲突，直接移动指针，删除分支后，会丢掉分支信息
git merge dev
//方式二:禁用Fast forward模式，Git就会在merge时生成一个新的commit（即使无冲突），这样，从分支历史上就可以看出分支信息。--no-ff参数，表示禁用Fast forward
git merge --no-ff -m "merge with no-ff" dev
```

## submodule

作用：子模块用于一个工程引用了另外一个工程，如hexo工程引用next主题工程。

添加子模块后，主模块记录的是添加子模块时的子模块的最后一次提交，如果子模块做了修改，再次提交到版本库后，主模块需要更新子模块指向的最后一次提交，分2种情况：

- 本地对子模块进行了修改提交推送（自己维护子模块代码），git status会显示主模块有修改，直接提交主模块到版本库即可。
- 子模块是引用的别人的工程，别人做了提交，主模块需要先pull子模块，然后主模块到版本库。

子模块才再次指向最新的提交，这样才能协同工作。

### create

```
git submodule add 仓库地址 本地路径
```

### commit

```
cd 子模块本地路径
git add .
git commit -m "modify submodule"
git push
```

这时，子模块的仓库更新了，但主模块，指向的还是老的子模块版本，这是因为Git 在顶级项目中记录了一个子模块的提交日志的指针，用于保存子模块的提交日志所处的位置，以保证无论子模块是否有新的提交，在任何一个地方克隆下顶级项目时，各个子模块的记录是一致的。避免因为所引用的子模块不一致导致的潜在问题。如果我们更新了子模块，我们需要把这个最近的记录提交到版本库中，以方便和其他人协同。

### update

进入本地子模块目录执行

```
git pull origin master
```

进入主模块目录

```
git add .
git commit -m "xx"
git push origin master
```

clone主模块后，子模块代码并不会自动clone，需要执行如下命令

```
git submodule init
git submodule update
```

## tag

作用：标记某个时刻，如发布版本的时刻，以后任何时候都可以获得这个时刻的历史版本。

### create

```
git checkout branch 切换到要打标签的分支
git tag <name> 新建一个标签，默认为HEAD，也可以指定一个commit id；
git tag -a <tagname> -m "blablabla..." 可以指定标签信息；
git tag -s <tagname> -m "blablabla..." 可以用PGP签名标签；

git tag v0.9 //默认打到最后一次提交
git tag v0.9 6224937 //打到commit id那一时刻
git tag -a v0.1 -m "version 0.9 released" 6224937
```

### view

```
git tag
git show <tagname>
```

### delete

```
git tag -d v0.9
git push origin :refs/tags/<tagname> 可以删除一个远程标签。
```

### push

```
git push origin v0.9
git push origin --tags 推送所有未推送的标签
```

