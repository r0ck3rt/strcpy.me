---
id: 657
layout: post
title: '开源的 OnlineJudge'
date: 2016-02-04 01:07:00
author: virusdefender
tags: 其他
---

qduoj 是 青岛大学开源的一个 OnlineJudge，GitHub 地址 https://github.com/QingdaoU/OnlineJudge

acmer 常用的 oj 是 hduoj 、 poj 等等，但是有些不是很满意的地方。

首先是界面，国内的前辈 oj 大多数都很丑很丑， 10 多年前的风格，可能因为 oj 就是 10 多年前写的吧。

用起来也有些不是很方便的地方，比如提交题目要新开页面，要再选择题号，再手动刷新看结果。自己内部比赛有些规则也没办法去设置，自己没法去添加题目去查看测试用例等等。

当然，qduoj 的定位不仅仅是 ACM 训练，还有学校平时教学的作业考试等也可以在上面进行。 老师作为普通管理员可以创建小组，相当于一个班级，内部举办比赛，创建修改题目，外人不可见，超级管理员才可以管理公开的题目和比赛。

oj 后端涉及到的技术有 Python 、 Django 、 Docker 、 MySQL 、 Redis 、 Celery 等，后台的前端是一个 SPA 页面，使用 avalon js 。

欢迎感兴趣的小伙伴搭建试用~
