---
id: 45
layout: post
title: '两个非常隐蔽的bug导致的Python xss filter绕过'
date: 2014-11-14 18:49:00
author: virusdefender
tags: 其他
---

最近在搜索Python的xss filter的时候看到这样一篇文章 http://www.tuicool.com/articles/RjyqYn (时间有点久远了，原文不知道为什么删掉了)。
代码如下
```python
#coding=utf-8
import re
from BeautifulSoup import BeautifulSoup
regex_cache = {}
 
def search(text, regex):
    regexcmp = regex_cache.get(regex)
    if not regexcmp:
        regexcmp = re.compile(regex)
        regex_cache[regex] = regexcmp
    return regexcmp.search(text)
 
# XSS白名单
VALID_TAGS = {'h1':{}, 'h2':{}, 'h3':{}, 'h4':{}, 'strong':{}, 'em':{}, 
              'p':{}, 'ul':{}, 'li':{}, 'br':{}, 'a':{'href':'^http://', 'title':'.*'}, 
              'img':{'src':'^http://', 'alt':'.*'}}
 
def parsehtml(html):
    soup = BeautifulSoup(html)
    for tag in soup.findAll(True):
        if tag.name not in VALID_TAGS:
            tag.hidden = True
        else:
            attr_rules = VALID_TAGS[tag.name]
            print tag.attrs, len(tag.attrs)
            for item in tag.attrs:
                #print item
                attr_name = item[0]
                attr_value = item[1]
                #print attr_name, attr_value
                #检查属性类型
                if attr_name not in attr_rules:
                    del tag[attr_name]
                    print tag.attrs, "----"
                    #print "del", attr_name
                    continue
                    
                #检查属性值格式
                if not search(attr_value, attr_rules[attr_name]):
                    del tag[attr_name]
                
                        
    return soup.renderContents()
 
text = '''
    <script>alert(1)</script>
    '''
print parsehtml(text)
```
备份：https://gist.github.com/virusdefender/5ec5e1be9738d87122e0

文中的思路看似不错，简单的找了几个测试也都没问题。但是过了几天我也忘了那里来的思路，就构造了一个这样的payload，有两个相同的事件`<img src="http://baidu.com" onerror="alert(1)" onerror="alert(1)">`结果成功绕过了，过滤之后还剩下一个onerror，这样就出现了xss。

我对此很是疑惑，为什么会漏掉一个呢？

将代码里面的那几个print取消注释，然后把测试代码改成我上面两个onerror的，你就能发现，其实一开始是获取到的所有的属性的。

```python
[(u'src', u'http://baidu.com'), (u'onerror', u'alert(1)'), (u'onerror', u'alert(1)')] 3
```
开始`tag.attrs`就是三个，这个是正确的。但是到了`print item`这里就只遍历了两遍
```python
(u'src', u'http://baidu.com')
(u'onerror', u'alert(1)')
```

调试了好久，然后再一次认真的读了一边代码后发现，问题出在这里
```python
if attr_name not in attr_rules:
        del tag[attr_name]
```
这个列表在循环过程中被删除了元素

python文档中有这么一段
http://docs.python.org/tutorial/controlflow.html
```
It is not safe to modify the sequence being iterated over in the loop (this can only happen for mutable sequence types, such as lists). If you need to modify the list you are iterating over (for example, to duplicate selected items) you must iterate over a copy.
```
大致的意思就是说在循环列表的时候同时去改变列表是一种不安全的行为，如果确实需要，你可以去循环一个列表的拷贝。这是一种`undefined behavior`，和`i += i++ + ++i`差不多。

这个时候大家应该知道解决办法了吧，就是将原先的tags做一个备份为new_tags，`new_tags = tags`，然后按照下标遍历new_tags，如果不符合规则，就按照下标去删除tags里面元素的属性。

代码大致是这样的了
```python
def parsehtml(html):
    soup = BeautifulSoup(html)
    tags = soup.findAll(True)
    new_tags = tags
    for i in range(0, len(new_tags)):
        if new_tags[i].name not in VALID_TAGS:
            tags[i].hidden = True
        else:
            attr_rules = VALID_TAGS[new_tags[i].name]
            for attr_name, attr_value in new_tags[i].attrs:
                #检查属性类型
                if attr_name not in attr_rules:
                    del tags[i][attr_name]
                    continue

                #检查属性值格式
                if not search(attr_value, attr_rules[attr_name]):
                    del tags[i][attr_name]


    return soup.renderContents()
```
但是你会惊奇的发现，输出结果还是一样的，还有一个`onerror`!!!

你又掉到python的坑里面了，如果你使用`new_tags = tags`的话，两个变量名是指向的同一个对象，你`del tags[i][attr_name]`的时候`new_tags`也变成一样的了。不信做一个实验。
```python
>>> a = [1, 2]
>>> b = a
>>> del a[0]
>>> b
[2]
>>> a
[2]

>>> a = []
>>> b = a
>>> a.append(1)
>>> a
[1]
>>> b
[1]

```
因为列表是可变对象，所以相当于传引用，能改变原先的值。

所以，如果需要拷贝对象，需要使用标准库中的copy模块。
1. copy.copy 浅拷贝 只拷贝父对象，不会拷贝对象的内部的子对象。
2. copy.deepcopy 深拷贝 拷贝对象及其子对象

把原先的赋值语句修改成`new_tags = copy.deepcopy(tags)`问题就解决了。

![4a8e2688jw1em8ehdvvsuj20jq10o0y4.jpg][1]


  [1]: http://storage.virusdefender.net/blog/images/45/1.jpg
