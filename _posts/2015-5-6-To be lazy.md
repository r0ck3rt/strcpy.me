---
id: 256
layout: post
title: 'To be lazy'
date: 2015-05-06 16:00:00
author: virusdefender
tags: Python
---

平时人们做事的时候谁说lazy也是不好的，但是在程序设计的时候，lazy是一种有效的提供性能的方法，大致的思想就是需要的时候再计算，尽量的缓存计算结果。

copy on write
-------------
linux上传统的fork()函数直接把父进程所有的资源复制给新创建的进程。这种实现过于简单并且效率低下，因为它拷贝的数据也许并不共享，更糟的情况是，如果新进程打算立即执行一个新的映像，那么所有的拷贝都将前功尽弃。

Linux的fork()使用写时拷贝（copy-on-write）页实现。写时拷贝是一种可以推迟甚至免除拷贝数据的技术。内核此时并不复制整个进程地址空间，而是让父进程和子进程共享同一个拷贝。只有在需要写入的时候，数据才会被复制，从而使各个进程拥有各自的拷贝。也就是说，资源的复制只有在需要写入的时候才进行，在此之前，只是以只读方式共享。这种技术使地址空间上的页的拷贝被推迟到实际发生写入的时候。在页根本不会被写入的情况下。举例来说，fork()后立即调用exec()，它们就无需复制了。

fork()的实际开销就是复制父进程的页表以及给子进程创建惟一的进程描述符。在一般情况下，进程创建后都会马上运行一个可执行的文件，这种优化可以避免拷贝大量根本就不会被使用的数据（地址空间里常常包含数十兆的数据）。这样就大大提高了性能。

Django的queryset
---------------

Django的文档说了，一个类似`users = User.objects.filter(name="jack")`的语句并不会立即去查询数据库，而是在以下操作的时候才回去查询数据库

 - 迭代
 - 切片，比如`users[0:10]`
 - 序列化(pickling)和缓存(caching)
 - repr
 - len() 返回数据条数，建议使用count()替代
 - list() 转换为列表
 - bool() 建议使用exists()替代

上面的uers变量，如果你没有对它进行这些操作，也就说那个查询数据库的操作永远不会进行。

而且queryset是支持链式调用的，比如说
```python
>>> q = Entry.objects.filter(headline__startswith="What")
>>> q = q.filter(pub_date__lte=datetime.date.today())
>>> q = q.exclude(body_text__icontains="food")
>>> print(q)
```
最终只会执行一条sql语句，而不是三条。

Python的生成器
----------
```python
def generator():                      
    l = [1, 2, 3, 4]                  
    for i in l:                       
        print "in generator", i
        yield i * i                   
```
yield 是一个类似 return 的关键字，只是这个函数返回的是个生成器。

为了理解yield，你必须要理解：当你调用这个函数的时候，函数内部的代码并不立马执行，这个函数只是返回一个生成器对象。当你使用for进行迭代的时候，才会执行真正的代码。

第一次迭代中你的函数会执行，从开始到达 yield 关键字，然后返回 yield 后的值作为第一次迭代的返回值. 然后，每次执行这个函数都会继续执行你在函数内部定义的那个循环的下一次，再返回那个值，直到没有可以返回的。

直接`print generator()`，发现只有一个`<generator object generator at 0x106b79e60>`，而使用这样的代码，
```python
for i in generator():       
    print "in for", i
    print i                 
```
你就会发现打印的是
```
in generator 1 
in for 1 
1

in generator 2 
in for 4 
4

in generator 3 
in for 9 
9

in generator 4 
in for 16 
16
```

Lazy evaluation
---------------
```python
class Person:
    def __init__(self, name, occupation):
        self.name = name
        self.occupation = occupation
        self.relatives = self._get_all_relatives()
        
    def _get_all_relatives(self):
        # 非常耗时的计算
        sleep(10)
        ...
```
我们可以将这个耗时的操作推迟，在需要的时候才进行，然后缓存结果
```python
class Person:
    def __init__(self, name, occupation):
        self.name = name
        self.occupation = occupation
        self._relatives = []
        
    @property
    def relatives(self):
        if not self._relatives:
            self._relatives = self._get_all_relatives()
        return self._relatives
    
    def _get_all_relatives(self):
        # 非常耗时的计算
        sleep(10)
        ...
```

更加pythonic的方法是使用修饰符
```python
def lazy_property(fn):
    '''Decorator that makes a property lazy-evaluated.
    '''
    attr_name = '_lazy_' + fn.__name__
 
    @property
    def _lazy_property(self):
        if not hasattr(self, attr_name):
            setattr(self, attr_name, fn(self))
        return getattr(self, attr_name)
    return _lazy_property
 
class Person:
    def __init__(self, name, occupation):
        self.name = name
        self.occupation = occupation
        
    @lazy_property
    def relatives(self):
        # Get all relatives
        relatives = ...
        return relatives
```

参考 http://stevenloria.com/lazy-evaluated-properties-in-python/
