---
id: 504
layout: post
title: 'winnowing 算法'
date: 2015-10-02 17:35:00
author: virusdefender
tags: 其他
---

最近尝试将 winnowing 算法应用于抄袭检测中，这是一种字符串指纹算法，详细的内容见下面这篇论文。

[Winnowing Local Algorithms for Document Fingerprinting.pdf][1]

k-grams 是最常见的指纹算法了，它将一个大字符串分为很多小字符串，而每个小字符串仅仅差一个字符，是一种错位的排列。比如 `adorunrunrunadorunrun`，进行 5-grams 之后就是

```
adoru dorun orunr runru 
unrun nrunr runru unrun 
nruna runad unado nador 
adoru dorun orunr runru 
unrun
```

k 就是每个小字符串的长度。

然后对这个小字符串组计算 hash，并抽样得到大字符串的特征值。抽样的算法有很多，不同的算法可能会影响最后的精确度，比如    hash 结果都是数字，就取出 hash % p = 0的，但是缺点就是特征中可能遗漏大段的内容，造成结果不准确。其余的算法也是有自己的缺点，比如取最小值。

winnowing 就是要结果对 hash 取样的时候遇到的问题，它将 hash 类似 k-grams 一样进行分组，比如 hash 值是
```
77 72 42 17 98 50 17 98 8 88 67 39 77 72 42 17 98
```
假设我们希望任意t个字符之内（不包含t）的重复都能被查出来，那么我们就设置一个窗口 w = t - k + 1。举个例子，比如在上面 5-grams 的例子中我们希望 t = 8 ，那么我们就设置 w = 8 - 5 + 1 = 4，于是，得到了以下14个hash值的窗口：

```
(77, 74, 42, 17) (74, 42, 17, 98) (42, 17, 98, 50)
(17, 98, 50, 17) (98, 50, 17, 98) (50, 17, 98,  8)
(17, 98,  8, 88) (98,  8, 88, 67) ( 8, 88, 67, 39)
(88, 67, 39, 77) (67, 39, 77, 74) (39, 77, 74, 42)
(77, 74, 42, 17) (74, 42, 17, 98)
```

我们选出每个窗口中的最小值，因为相连几个窗口的最小值可能指的是文档中同一个 hash，这个时候我们只需要在这个 hash 第一次出现的那个窗口选择它就可以了，其它的窗口就不再需要选择最小值了。比如在这个例子中，前三个窗口的最小值都是17，而且指向的是同一个 hash ，所以我们只需要选择第一个就可以了，另外两个窗口都不需要选择，直到第四个窗口又出现了另外一个17。通过这个算法我们就可以选出以下5个 hash 值：
```
17 17 8 39 17
```
这个就是这整个文档的fingerprint。如果需要字符串出现的位置不影响结果的话，将 hash 值去重就好了。

下面是我使用 Python 简单的实现

```python
# coding=utf-8
import hashlib


class Winnowing(object):
    def __init__(self, text, k=5, w=10):
        """
        :param text:
        :param k: 字符串分组长度
        :param w: 窗口长度
        :return:
        """
        self.text = text
        self.k = k
        self.w = w

    def _kgrams(self, l, size):
        """
        将 l 分组，每组大小是size，每组错位一个元素
        :param l: 
        :param size: 分组大小
        :return:
        """
        n = len(l)

        if n < size:
            yield l
        else:
            for i in xrange(n - size + 1):
                yield l[i:i+size]

    def _hash(self, string):
        return int(hashlib.md5(string).hexdigest()[:8], 16)

    def fingerprint(self):
        cur = 0
        result = []
        for item in self._kgrams(map(lambda x: self._hash(x), self._kgrams(self.text, self.k)), self.w):
            # 对于hash分组，每组都是找到最右边的最小值
            min_num = item[0]
            for i in range(len(item)):
                if item[i] <= min_num:
                    min_num = item[i]
            result.append(min_num)
            cur += 1
        return set(result)
print Winnowing("abcdefghijklmnopqrstuvwxyz").fingerprint()
```

参考 http://ytliu.info/blog/2013/12/16/fingerprintsuan-fa-cha-chao-xi/

  [1]: https://dn-virusdefender-blog.qbox.me/2015/787632366.pdf
