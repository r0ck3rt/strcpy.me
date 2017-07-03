---
id: 543
layout: post
title: '使用类来写 Python 的 decorator'
date: 2015-10-13 18:07:00
author: virusdefender
tags: 
---

平时看到的 Python 的 decorator 都是使用函数来写的，比如说我之前在写的 `login_required`

```python
def login_required(func):
    @wraps(func)
    def check(*args, **kwargs):
        # 在class based views 里面，args 有两个元素，一个是self, 第二个才是request，
        # 在function based views 里面，args 只有request 一个参数
        request = args[0]
        if request.user.is_authenticated():
            return func(*args, **kwargs)
        if request.is_ajax():
            return error_response(u"请先登录")
        else:
            return HttpResponseRedirect("/login/")
    return check

@login_required
def view(request):
    pass
```
这样的话，在调用 view 函数的时候就相当于 `login_required(view)` 了。

其实我们使用类也能完成这样的任务，调用函数就相当于 `DecoratorClass(func)()`了，后面的括号和调用函数的意思差不多，是在`__call__`方法中定义的，所以我们就可以这样写

```python
class login_required(object):
    def __init__(self, func):
        self.func = func

    def __call__(self, *args, **kwargs):
        print args, kwargs
        return self.func(*args, **kwargs)

@login_required
def index(*args, **kwargs):
    print "index page"

index(1, 2, 3, a=4, b=5)
```
输出就是
```python
__call__ (1, 2, 3) {'a': 4, 'b': 5}
index page
```
看起来一切正常。

至于为什么使用类呢。今天下午在写代码的时候，发现有三个 decorator，结构基本一致，就是判断条件有差别，分别的`login_required`、`admin_required`和`super_admin_required`。这不能忍，我就想到了使用类来写，因为可以继承啊，很快就写好了。

```python
class BasePermissionDecorator(object):
    def __init__(self, func):
        self.func = func

    def __get__(self, obj, obj_type):
        return functools.partial(self.__call__, obj)

    def __call__(self, *args, **kwargs):
        if len(args) == 2:
            self.request = args[1]
        else:
            self.request = args[0]

        if self.check_permission():
            return self.func(*args, **kwargs)
        else:
            if self.request.is_ajax():
                return error_response(u"请先登录")
            else:
                return HttpResponseRedirect("/login/")

    def check_permission(self):
        raise NotImplementedError()


class login_required(BasePermissionDecorator):
    def check_permission(self):
        return self.request.user.is_authenticated()
```

就只贴 `login_required` 这一个吧，剩下的基本一样。

然后在运行之前的测试用例的时候出错了，这个 decorator 用在类方法上的时候就会报错，self 参数没了，而普通 def 的函数没问题，demo 如下。

```python
class IndexView(object):
    @login_required
    def post(self, request):
        print self, request

IndexView()post(1, 2, 3, a=4, b=5)
```
输出如下
```python
__call__ (1, 2, 3) {'a': 4, 'b': 5}
1 (2, 3) {'a': 4, 'b': 5}
```
发现 self 参数没了，匹配到了参数1。

而正常的调用应该是
```python
<__main__.IndexView object at 0x1013dd890> (1, 2, 3) {'a': 4, 'b': 5}
```
后来查了一下，说是在 decorator 中需要定义一个`__get__`方法，
```python
class BasePermissionDecorator(object):
    def __init__(self, func):
        self.func = func

    def __get__(self, obj, obj_type):
        return functools.partial(self.__call__, obj)

    def __call__(self, *args, **kwargs):
        if len(args) == 2:
            self.request = args[1]
        else:
            self.request = args[0]

        if self.check_permission():
            return self.func(*args, **kwargs)
        else:
            if self.request.is_ajax():
                return error_response(u"请先登录")
            else:
                return HttpResponseRedirect("/login/")
```
原因如下。
```python
class IndexView(object):
    @login_required
    def post(self, request):
        print self, request
```
相当于
```python
class IndexView(object):
    def post(self, request):
        print self, request
    post = login_required(post)

```
所以
```python
view = IndexView() 
view.post
```
就相当于`view.post.__get__(post, view, <type of view>)`就相当于`login_required(post).__get__(view, <type of view>)`，也就是调用的`class login_required`里面的`__get__`方法，因为我们使用了`partial`函数，相当于返回了一个指定了一个参数为 view 的函数，然后再调用的时候再增加一个其他参数。

至于为什么会调用`__get__`函数，可以参考http://intermediatepythonista.com/classes-and-objects-ii-descriptors，这是 Python 的 descriptor。