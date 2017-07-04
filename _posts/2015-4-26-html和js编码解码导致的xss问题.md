---
id: 251
layout: post
title: 'html和js编码解码导致的xss问题'
date: 2015-04-26 19:17:00
author: virusdefender
tags: 安全
---

在js中对特殊字符进行转义我们可以使用下面的函数，
```js
    function _html_encode(str) {
        if (!str.length) {
            return "";
        }
        var result = "";
        result = str.replace(/&/g, "&amp;");
        result = result.replace(/</g, "&lt;");
        result = result.replace(/>/g, "&gt;");
        result = result.replace(/\"/g, "&quot;");
        return result;
    }
```
然后可以将转义之后的代码写入页面，但是这样不一定是安全的，比如
```html
<button onclick="document.write(_html_encode('<script>alert(1)</script>'))">click me 1</button>
<button onclick="document.write('&lt;script&gt;alert(1)&lt;/script&gt;')">click me 2</button>
```
第一个点击之后页面上显示`<script>alert(1)</script>`，而第二个确实弹窗了。

这是因为这段js是出现在html中的，在执行的时候会先对字符串进行html的解码(html的编码除了这个还有一个是`&#`的形式)，第二句里面被转义的内容又被转义回来了，导致xss。而第一句没有解码过程，将转义后的内容写入页面。

而在js上下文中，是不会对html编码进行自动解码的，比如把上面的代码放入script标签中
```javascript
    function click1(){
        document.write(_html_encode("<img src=# onerror=alert(1)>"));
    }
    function click2(){
        document.write("&lt;img src=# onerror=alert(1)&gt;");
    }
```
都不会弹框的。
在js环境中，会对js编码进行解码，比如\u的unicode，\x的十六进制形式，`\'` `\<` `\>`等等。

比如说用户的输入被转义为`\<img src\=# onerror\=alert(1)\>`，在执行的时候也会被再次转义回来的，可以自己写个函数测试一下。

还有一个就是textarea标签是自带html encode功能的，比如
```html
<textarea id="t"><script>alert(1)</script></textarea>
```
在`document.getElementById("t").innerHTML`的时候返回的是`"&lt;script&gt;alert(1)&lt;/script&gt;"`。有相同功能的还有title，noscript等。
