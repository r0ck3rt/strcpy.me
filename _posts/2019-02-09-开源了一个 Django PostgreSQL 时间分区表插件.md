---
id: 794
layout: post
title: '开源了一个 Django PostgreSQL 时间分区表插件'
date: 2019-02-09 00:00:01
author: virusdefender
tags: 后端
---

## 什么是分区表，有什么优点

分区表就是将逻辑上的一个大表分成一些物理上的小表，是数据库系统为大型表的数据组织和管理提供的一种实用的功能特性。

表分区有很多好处，比如：

 - 子表可以按照时间等特征去划分，如果一个查询带有时间范围，那么某些子表可以直接跳过。这样就减少了索引和数据文件的 IO 量，而且这些数据更可能被缓存在内存中了。
 - 一个子表可以被归档，也就是数据库会忽略它的存在，实现老数据不再查询的特性。
 - 如果磁盘空间不足，可以快速删除不想要的数据。被归档的表的删除和 vacuum 会比较容易，因为需要锁，一直写数据的情况下不容易操作。
 - 如果加一块磁盘扩容，之后创建的新的子表可以单独调整 tablespace 放在新的磁盘上，先不移动已有的数据。

## 我们为什么要开发这个插件

这里需要先插播一个广告

> 雷池（SafeLine）是全球首个基于智能语义分析算法的 WAF产品。雷池从计算机语言的角度进行攻击检测，区别于传统的基于特征库和黑白名单机制的拦截原理，极大地降低了误报率和漏报率，提升了 WAF 拦截的准确度。面对云端变化，雷池（SafeLine）云端解决方案无论应对私有云、公有云、混合云都有灵活应变的部署防护模式，帮助用户灵活配置网络环境。

雷池需要不间断地将包括海量攻击检测、行为审计等各类日志入库持久化，给数据库带来了极大的压力。

当然表分区不是存储和处理大数据的最优办法，引入分布式数据库和分布式文件系统才能更好的分离查询和存储压力。但是在某些特定的场景下下面（比如你的产品是卖给客户一台硬件机器）是无法引入分布式系统的。

雷池的后端管理平台基于 Django 框架，而数据库主要使用 PostgreSQL。雷池 S20 系列使用的数据库主版本号为 11，该主版本更新的一大特性便是对表分区进行了若干增强，详情参见 https://www.postgresql.org/about/news/1894/ 。

由于 Django ORM 当前不支持声明分区表，所以在此之前也有如 architect (https://github.com/maxtepkeev/architect) 这样的 插件，但是它是基于表继承来实现的，并不支持 PostgreSQL 10 之后的原生分区表功能，而原生分区表功能在性能和易用性上都远远好于表继承。

所以我们开源了基于时间进行原生分区和管理的 Django 插件 django-pg-timepart (https://github.com/chaitin/django-pg-timepart)，它支持最新的 PostgreSQL 11，使 Django 能够在业务层对像文章、评论和日志这样的时序数据按一定时间间隔（如年、月、周等）来建立分区。


## 如何使用

在 Django 中，数据的核心是 model，所以只要给 model 加上我们的 decorator 就可以在 migrate 的时候声明为分区表了。

```python
@TimeRangePartitioningSupport("timestamp", default_interval=6)
class AttackLog(models.Model):
    timestamp = models.DateTimeField()
rule_id = models.TextField()
……
```

但是这个时候只有主表没有子表，需要再去扫描所有的 model 然后创建或者归档子表。

```python
model.partitioning.create_partition()
model.partitioning.detach_partition()
```

雷池的分区自动创建和归档是通过后端的定时器来触发上面的 API 实现的。

当然我们的归档周期等配置也是可以调整的，而且归档历史和子表信息也可以查询，它们都在 PartitionConfig 和 PartitionLog 中。

## 最后

django-pg-timepart 虽然是一个从我们实际业务中分离出来的，代码不过千行，功能单一的小插件，但是我们认为，当开源一个项目的同时，我们其实也在开源我们对于某些问题的一些想法，并愿意在开源社区中就我们使用 Django 构建 Web 应用时的所遇到的问题参与讨论，这才是我们的初衷。因此，我们欢迎大家为这一萌芽项目提供更多的建议、指出不足或对功能进行扩展使其更加通用化，Thanks！

