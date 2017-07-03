---
id: 681
layout: post
title: 'jQuery选择器导致的xss问题'
date: 2016-03-08 13:56:00
author: virusdefender
tags: 
---

小伙伴发了某站的一个链接，xss payload在url的hash后面，然后页面弹框了，但是查看页面源代码，就只有`jquery.js`和`jquery.fullpage.js`，猜测是`fullpage.js`的问题，因为记得自己用`fullpage.js`的时候，hash部分会是`#first`、`#second`，然后切换页面的时候会变，可能是fullpage.js处理不当导致的。使用Chrome的调试工具发现还并不是这样的。

![QQ20160308-0@2x.png][1]

js经过压缩，这里的d就是jQuery的`$`，也就是说`$("<img src=# onerror=alert(1)")`就是可以弹框的，使用页面上的js发现确实是这样的。

![QQ20160308-1@2x.png][2]

觉得这个问题在哪见过，后来在[evi1m0的博客][3]找到了，确实是jQuery的问题，在[fullpage.js的GitHub里面][4]也有提到，jQuery的bug ticket是 https://bugs.jquery.com/ticket/9521 。

开发者的建议就是

> I agree that developers need to be aware of any case where they are
> passing untrusted input to methods that can create HTML, such as $()
> or $().html() or the DOM's .innerHTML property for that matter. We
> cannot solve the problem inside jQuery because we cannot judge the
> trustworthiness of the string being passed.

`innerHTML`可能会产生xss，这个好理解，主要是很多人并不知道`$()`也可能创建HTML。


  [1]: http://storage.virusdefender.net/blog/images/681/1.png
  [2]: http://storage.virusdefender.net/blog/images/681/2.png
  [3]: http://linux.im/2015/05/07/jQuery-1113-DomXSS-Vulnerability.html
  [4]: https://github.com/alvarotrigo/fullPage.js/pull/1705/files