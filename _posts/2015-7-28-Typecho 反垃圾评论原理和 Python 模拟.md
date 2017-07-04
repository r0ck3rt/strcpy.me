---
id: 438
layout: post
title: 'Typecho 反垃圾评论原理和 Python 模拟'
date: 2015-07-28 08:57:00
author: virusdefender
tags: 安全
---

最近在看 Typecho 的时候，在页面中发现了这样一段奇怪的代码
```js
var _FKbCJ = //'l'
'l'+//'h'
'df'+'f'//'pga'
+'6a4'//'ZR'
+'ff0'//'fwM'
+'b21'//'exn'
+'fe'//'vl'
+//'K'
'1'+''///*'7d1'*/'7d1'
+'4a'//'XI'
+//'erP'
'dbe'+//'9'
'f'+'ab'//'3U'
+'6'//'e'
+''///*'hjW'*/'hjW'
+//'Jb'
'f'+//'0UM'
'5'+//'MNp'
'MNp'+''///*'Zd'*/'Zd'
+//'gt'
'gt'+'uOV'//'uOV'
+//'1uK'
'76'+'8f9'//'K'
+''///*'o'*/'o'
+//'5'
'5'+/* 'db1'//'db1' */''+'e'//'CN'
, _cYDj = [[0,1],[26,29],[26,28],[26,29],[31,32]];
    
    for (var i = 0; i < _cYDj.length; i ++) {
        _FKbCJ = _FKbCJ.substring(0, _cYDj[i][0]) + _FKbCJ.substring(_cYDj[i][1]);
    }

    return _FKbCJ;
```
猜测和反垃圾评论有关，因为机器人直接评论的话，一般都是直接 post 评论数据，如果在评论之前需要先运行一段 js，然后带上这段 js 生成的值再 post 的话，就能挡住一大批低级的机器人了。现在很多地方用到了这个，比如一些云 WAF，在可疑请求的时候也是返回一段 js 要运行的，更高级点的可以检测浏览器环境，鼠标手势等等。相对于验证码，对真实用户更友好一些。

看 Typecho 的[源码][2]也确实是这样的。

我用 Python 写了一个，主要是通过各种注释和换行来混淆 js，虽然不运行 js，直接进行字符串分析肯定也能得到结果，但是相比直接 post 数据，难度大大增大了，而且我们可以随时更换混淆规则，我们的目的也就达到了。


<!--more-->


```python
# coding=utf-8
import time
import random
import hashlib
import json
 
 
def split_str(string):
    result = []
    length = len(string)
    start = 0
    while True:
        r = random.randint(0, 3)
        if start + r < length:
            result.append(string[start:start + r])
            start += r
        else:
            result.append(string[start:])
            break
    return result
 
 
def rand_str(length=32):
    string = hashlib.md5(str(time.time()) + str(random.randrange(1, 9999999900))).hexdigest()
    return string[0:length]
 
 
def confuse_string():
    s = rand_str()
    str_list = split_str(s)
    str_len = len(s)
    js_var1 = "v" + rand_str(3)
    js_string = "function check(){var " + js_var1 + " = "
    for item in str_list:
        js_string += ("'" + item + "'+" + random.randint(0, 2) * ' ')
        r = random.randint(0, 3)
        if r:
            js_string += ("//" + random.randint(0, 1) * "/*" + rand_str(random.randint(1, 5)) + random.randint(0, 1) * "*/" + "\n")
        else:
            js_string += ("/*" + "/" * random.randint(0, 2) + rand_str(random.randint(2, 4)) + "*/")
    js_var2 = "l" + rand_str(3)
    js_string += ("'';var " + js_var2 + " = ")
    l = []
    result = ""
    for i in range(random.randint(10, 25)):
        l.append(random.randint(0, str_len))
    js_string += (json.dumps(l) + ";" + "\n")
    js_var3 = ("r" + rand_str(3))
    js_string += ("for(var i = 0;i < " + js_var2 + ".length;i++){var " + js_var3 + "= ")
    for i in range(0, len(l)):
        if random.randint(0, 1):
            result += s[0:l[i]]
            js_string += (js_var1 + "." + "/*" + random.randint(0, 2) * "/" +
                       rand_str(random.randint(3, 5))+ "*/" + "substr(0, " +
                       str(l[i]) + ") +" + random.randint(0, 2) * " ")
        else:
            r = random.randint(-100, 30)
            result += str(l[i] + r)
            js_string += ("'" + str(l[i] + r) + "' +" + random.randint(0, 3) * " ")
        if random.randint(0, 1):
            js_string += "\n"
    js_string += ("'';}return " + js_var3 + ";}")
    return js_string, result
 
 
s = confuse_string()
print s[0], s[1]
```
生成这样的一段 js
```js
function check(){var v1fa = '44f'+  ///*7661*/
'2d6'+ ///*4f2
'02'+  //07
'90f'+ /*/00*/'f4'+ ///*7
'22'+/*8c8b*/'c2e'+ ///*c*/
'b'+  //77f4
'd'+  ///*2*/
'b'+/*/4360*/'d'+  ///*72*/
'7'+  //d0*/
''+///*b*/
'be'+  //dd*/
'7b'+  /*deea*/'82'+  ///*c3eaf*/
'9b'+//7*/
''+//142e*/
'd'+  ///*ba*/
'';var lfdd = [10, 4, 11, 24, 28, 5, 7, 21, 32, 2, 28, 22, 32, 18, 1, 6, 11, 4, 19];
for(var i = 0;i < lfdd.length;i++){var r45a= '0' +'-39' +
v1fa./*fc6*/substr(0, 11) + '-36' +  '24' +  
'-23' +   '-34' + 
v1fa./*//eada*/substr(0, 21) +'37' +  '29' +
'-60' + 
v1fa./*/d71b*/substr(0, 22) + 
v1fa./*//dd759*/substr(0, 32) +  v1fa./*/67ec*/substr(0, 18) +  '-30' +   
v1fa./*a98e*/substr(0, 6) +  '-77' +   
v1fa./*5de*/substr(0, 4) +  
v1fa./*//bf2d*/substr(0, 19) +
'';}return r45a;}
```

js 的运行结果是`0-3944f2d60290f-3624-23-3444f2d60290ff422c2ebdb3729-6044f2d60290ff422c2ebdbd44f2d60290ff422c2ebdbd7be7b829bd44f2d60290ff422c2e-3044f2d6-7744f244f2d60290ff422c2eb`，而这个结果在生成 js 的时候就确定了，只要拿到评论数据和 session 中的值比较一下就好了~


  [1]: https://github.com/typecho/typecho/blob/3d4b7babb4451857815bcbc2b1f92d37ac4a40da/var/Typecho/Common.php#L963
  [2]: https://github.com/typecho/typecho/blob/3d4b7babb4451857815bcbc2b1f92d37ac4a40da/var/Typecho/Common.php#L963
  [3]: https://dn-virusdefender-blog-cdn.qbox.me/usr/plugins/SyntaxHighlighter/scripts/shBrushPython4.js
  [4]: http://storage.virusdefender.net/blog/images/438/4.png
