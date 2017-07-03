---
id: 136
layout: post
title: 'python __new__和__metaclass__'
date: 2014-12-15 00:16:00
author: virusdefender
tags: 
---

先说`__new__`

`__new__`原型为`object.__new__(cls,[...])`,cls是一个类对象。当你调用`C(*arg, **kargs)`来创建一个类C的实例时。python内部调用是`C.__new__(C, *arg, **kargs)`,然后返回值是类C的实例c。在确认c是C的实例后，python再调用`C.__init__(c, *arg, **kargs)`来实例化c

```python
class Person(object):
    def __new__(cls, name, age):
        print '__new__ called.'
        return super(Person, cls).__new__(cls, name, age)

    def __init__(self, name, age):
        print '__init__ called.'
        self.name = name
        self.age = age

    def __str__(self):
        return '<Person: %s(%s)>' % (self.name, self.age)

if __name__ == '__main__':
    piglei = Person('piglei', 24)
    print piglei
```

`__new__`方法主要是当你继承一些不可变的class时(比如int, str, tuple)， 提供给你一个自定义这些类的实例化过程的途径。还有就是实现自定义的metaclass

比如这样是没效果的
```python
class PositiveInteger(int):
    def __init__(self, value):
        super(PositiveInteger, self).__init__(self, abs(value))
```
这样才行
```python
class PositiveInteger(int):
    def __new__(cls, value):
        return super(PositiveInteger, cls).__new__(cls, abs(value))
```

使用`__new__`可以实现单例模式

```python
class Singleton(object):
    def __new__(cls):
        if not hasattr(cls, 'instance'):
            cls.instance = super(Singleton, cls).__new__(cls)
        return cls.instance
```
或者
```python
class Singleton(object):
    _singleton = {}
     
    def __new__(cls):
        if not cls._singleton.has_key(cls):
            cls._singleton[cls] = object.__new__(cls)
        return cls._singleton[cls]
```

下面是`__metaclass__`

> “元类就是深度的魔法，99%的用户应该根本不必为此操心。如果你想搞清楚究竟是否需要用到元类，那么你就不需要它。那些实际用到元类的人都非常清楚地知道他们需要做什么，而且根本不需要解释为什么要用元类。”
> —— Python界的领袖 Tim Peters

比如我们想给python的list增加一个`add`方法，实现`append`方法的功能的时候，我们可以这样
```python
class MyList(list):
    def add(self, value):
        self.append(value)
```

还可以这样
```python
class ListMetaclass(type):
    def __new__(cls, name, bases, attrs):
        attrs['add'] = lambda self, value: self.append(value)
        return type.__new__(cls, name, bases, attrs)

class MyList(list):
    __metaclass__ = ListMetaclass 
```

在这里面也能看出来`__new__`方法接受的参数是四个，而前面用到的一般只使用了cls一个参数

对于
```python
class Foo(Bar):
    pass
```
Python做了如下的操作：

Foo中有`__metaclass__`这个属性吗？如果是，Python会在内存中通过`__metaclass__`创建一个名字为Foo的类对象（我说的是类对象，请紧跟我的思路）。如果Python没有找到`__metaclass__`，它会继续在Bar（父类）中寻找`__metaclass__`属性，并尝试做和前面同样的操作。如果Python在任何父类中都找不到`__metaclass__`，它就会在模块层次中去寻找`__metaclass__`，并尝试做同样的操作。如果还是找不到`__metaclass__`,Python就会用内置的type来创建这个类对象。

所以类的父类的`__metaclass__`是会被调用两次的，也就是说metaclass可以隐式地继承到子类，但子类自己却感觉不到。比如
```python
class ListMetaclass(type):
    def __new__(cls, name, bases, attrs):
        print name
        attrs['add'] = lambda self, value: self.append(value)
        return type.__new__(cls, name, bases, attrs)

class MyList(list):
    __metaclass__ = ListMetaclass 
    
    
class MyList1(MyList):
    pass
    
l = MyList1()
l.add(2)
```

可以发现输出为
```python
MyList
MyList1
```

使用`__metaclass__`实现的一个简单的orm
```python
class User(Model):
    # 定义类的属性到列的映射：
    id = IntegerField('id')
    name = StringField('username')
    email = StringField('email')
    password = StringField('password')


class Model(dict):
    __metaclass__ = ModelMetaclass

    def __init__(self, **kw):
        super(Model, self).__init__(**kw)

    def __getattr__(self, key):
        try:
            return self[key]
        except KeyError:
            raise AttributeError(r"'Model' object has no attribute '%s'" % key)

    def __setattr__(self, key, value):
        self[key] = value

    def save(self):
        fields = []
        params = []
        args = []
        for k, v in self.__mappings__.iteritems():
            fields.append(v.name)
            params.append('?')
            args.append(getattr(self, k, None))
        sql = 'insert into %s (%s) values (%s)' % (self.__table__, ','.join(fields), ','.join(params))
        print('SQL: %s' % sql)
        print('ARGS: %s' % str(args))


class ModelMetaclass(type):
    def __new__(cls, name, bases, attrs):
        # 还是上面的原因 Mode类不需要调用这个__new__
        if name=='Model':
            return type.__new__(cls, name, bases, attrs)
        mappings = dict()
        # attrs的内容是{'password': <__main__.StringField object at 0x7fb405714c10>...}等
        for k, v in attrs.iteritems():
            if isinstance(v, Field):
                print('Found mapping: %s==>%s' % (k, v))
                mappings[k] = v
        # 删除这些类属性 防止访问实例属性的时候发生错误，因为实例属性优先级大于类属性
        for k in mappings.iterkeys():
            attrs.pop(k)
        # 假设表名和类名一致
        attrs['__table__'] = name 
        # 保存属性和列的映射关系
        attrs['__mappings__'] = mappings 
        return type.__new__(cls, name, bases, attrs)
```


本文参考

[廖雪峰的官方网站][1]

[深刻理解Python中的元类(metaclass)][2]


  [1]: http://www.liaoxuefeng.com/wiki/001374738125095c955c1e6d8bb493182103fac9270762a000/001386820064557c69858840b4c48d2b8411bc2ea9099ba000
  [2]: http://blog.jobbole.com/21351/