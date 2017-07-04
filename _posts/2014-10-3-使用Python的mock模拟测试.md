---
id: 10
layout: post
title: '使用Python的mock模拟测试'
date: 2014-10-03 09:54:00
author: virusdefender
tags: Python
---

最近写的项目里面有一个创建预约成功后就给客户发一条短信或者邮件的功能，但是怎么去自动化的测试这个功能呢，难道每次都要发送一遍，然后去看么。这时候我们就可以引入Python的mock测试，我们首先来看一个[网上流传的比较广的教程][1]里面的例子。


  [1]: http://www.toptal.com/python/an-introduction-to-mocking-in-python
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os

def rm(filename):
    os.remove(filename)
```
然后测试是这样的
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

from mymodule import rm

import os.path
import tempfile
import unittest

class RmTestCase(unittest.TestCase):

    tmpfilepath = os.path.join(tempfile.gettempdir(), "tmp-testfile")

    def setUp(self):
        with open(self.tmpfilepath, "wb") as f:
            f.write("Delete me!")
        
    def test_rm(self):
        # remove the file
        rm(self.tmpfilepath)
        # test that it was actually removed
        self.assertFalse(os.path.isfile(self.tmpfilepath), "Failed to remove the file.")
```
使用mock改写后的测试是这样的
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

from mymodule import rm

import mock
import unittest

class RmTestCase(unittest.TestCase):
    
    @mock.patch('mymodule.os')
    def test_rm(self, mock_os):
        rm("any path")
        # test that rm called os.remove with the right parameters
        mock_os.remove.assert_called_with("any path")
```
上面用到了`assert_called_with(*args, **kwargs)`按照官方文档，这就是assert这个方法被调用的一个简介的方法（翻译好别扭）
This method is a convenient way of asserting that calls are made in a particular way:
```python
mock = Mock()
mock.method(1, 2, 3, test='wow')
<Mock name='mock.method()' id='...'>
mock.method.assert_called_with(1, 2, 3, test='wow')
```

然后修改了一下删除文件的代码，删除之前先去判断一下文件是否存在
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import os.path

def rm(filename):
    if os.path.isfile(filename):
        os.remove(filename)
```
相应的单元测试是这样的
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

from mymodule import rm

import mock
import unittest

class RmTestCase(unittest.TestCase):
    
    @mock.patch('mymodule.os.path')
    @mock.patch('mymodule.os')
    def test_rm(self, mock_os, mock_path):
        # set up the mock
        mock_path.isfile.return_value = False
        
        rm("any path")
        
        # test that the remove call was NOT called.
        self.assertFalse(mock_os.remove.called, "Failed to not remove the file if not present.")
        
        # make the file 'exist'
        mock_path.isfile.return_value = True
        
        rm("any path")
        
        mock_os.remove.assert_called_with("any path")
```
里面用到了`return_value`这个方法，这个就是设置mock的返回值的，比如
```python
mock = Mock()
mock.return_value = 'fish'
mock()
>>>'fish'
```
`is_called`方法就是看这个方法是否被调用，前面的`assert_called_with`就是在这个的基础上来的。


然后上面的那些都是mock的一些函数，下面我们将测试去mock一下类和实例。
我们将上面删除文件的函数改写成这样的
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import os.path

class RemovalService(object):
    """A service for removing objects from the filesystem."""
    
    #这个self貌似是原作者笔误漏掉了
    def rm(self, filename):
        if os.path.isfile(filename):
            os.remove(filename)
```
然后单元测试是这样的
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

from mymodule import RemovalService

import mock
import unittest

class RemovalServiceTestCase(unittest.TestCase):
    
    @mock.patch('mymodule.os.path')
    @mock.patch('mymodule.os')
    def test_rm(self, mock_os, mock_path):
        # instantiate our service
        reference = RemovalService()
        
        # set up the mock
        mock_path.isfile.return_value = False
        
        reference.rm("any path")
        
        # test that the remove call was NOT called.
        self.assertFalse(mock_os.remove.called, "Failed to not remove the file if not present.")
        
        # make the file 'exist'
        mock_path.isfile.return_value = True
        
        reference.rm("any path")
        
        mock_os.remove.assert_called_with("any path")
```
我们现在想知道`RemovalService`是否正常工作，我们先声明它为一个实例。在另外的一个类里面调用它。
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import os.path

class RemovalService(object):
    """A service for removing objects from the filesystem."""

    def rm(self, filename):
        if os.path.isfile(filename):
            os.remove(filename)
            

class UploadService(object):

    def __init__(self, removal_service):
        self.removal_service = removal_service
        
    def upload_complete(self, filename):
        self.removal_service.rm(filename)
```
到目前为止，我们的测试已经覆盖了RemovalService， 我们就不用对我们测试用例中UploadService的内部函数rm进行验证了。相反，我们将调用UploadService的RemovalService.rm方法来进行简单的测试（为了不产生其他副作用），我们通过之前的测试用例可以知道它可以正确地工作。
有两种方法可以实现以上需求:

 - 模拟RemovalService.rm方法本身。
 - 在UploadService类的构造函数中提供一个模拟实例。

**模拟实例方法**
该模拟库有一个特殊的方法用来装饰模拟对象实例的方法和参数。使用@mock.patch.object 进行装饰
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

from mymodule import RemovalService, UploadService

import mock
import unittest

class RemovalServiceTestCase(unittest.TestCase):
    
    @mock.patch('mymodule.os.path')
    @mock.patch('mymodule.os')
    def test_rm(self, mock_os, mock_path):
        # instantiate our service
        reference = RemovalService()
        
        # set up the mock
        mock_path.isfile.return_value = False
        
        reference.rm("any path")
        
        # test that the remove call was NOT called.
        self.assertFalse(mock_os.remove.called, "Failed to not remove the file if not present.")
        
        # make the file 'exist'
        mock_path.isfile.return_value = True
        
        reference.rm("any path")
        
        mock_os.remove.assert_called_with("any path")
      
      
class UploadServiceTestCase(unittest.TestCase):

    @mock.patch.object(RemovalService, 'rm')
    def test_upload_complete(self, mock_rm):
        # build our dependencies
        removal_service = RemovalService()
        reference = UploadService(removal_service)
        
        # call upload_complete, which should, in turn, call `rm`:
        reference.upload_complete("my uploaded file")
        
        # check that it called the rm method of any RemovalService
        mock_rm.assert_called_with("my uploaded file")
        
        # check that it called the rm method of _our_ removal_service
        removal_service.rm.assert_called_with("my uploaded file")
```
这里有一个使用修饰符的陷阱，就是使用修饰符的顺序和参数的顺序
比如说
```python
@mock.patch('mymodule.sys')
    @mock.patch('mymodule.os')
    @mock.patch('mymodule.os.path')
    def test_something(self, mock_os_path, mock_os, mock_sys):
        pass
```
然后实际情况是这样调用的
`patch_sys(patch_os(patch_os_path(test_something)))`
也就是说是相反的
由于这个关于`sys`的在最外层，因此会在最后被执行，使得它成为实际测试方法的最后一个参数。请特别注意这一点，并且在做测试使用调试器来保证正确的参数按照正确的顺序被注入。

**创建一个mock实例**
我们可以在UploadService的构造函数中提供一个模拟测试实例，而不是模拟创建具体的模拟测试方法。
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-

from mymodule import RemovalService, UploadService

import mock
import unittest

class RemovalServiceTestCase(unittest.TestCase):
    
    @mock.patch('mymodule.os.path')
    @mock.patch('mymodule.os')
    def test_rm(self, mock_os, mock_path):
        # instantiate our service
        reference = RemovalService()
        
        # set up the mock
        mock_path.isfile.return_value = False
        
        reference.rm("any path")
        
        # test that the remove call was NOT called.
        self.assertFalse(mock_os.remove.called, "Failed to not remove the file if not present.")
        
        # make the file 'exist'
        mock_path.isfile.return_value = True
        
        reference.rm("any path")
        
        mock_os.remove.assert_called_with("any path")
      
      
class UploadServiceTestCase(unittest.TestCase):

    #原作者这里还有一个参数是mock_rm，没用吧？
    def test_upload_complete(self):
        # build our dependencies
        mock_removal_service = mock.create_autospec(RemovalService)
        reference = UploadService(mock_removal_service)
        
        # call upload_complete, which should, in turn, call `rm`:
        reference.upload_complete("my uploaded file")
        
        # test that it called the rm method
        mock_removal_service.rm.assert_called_with("my uploaded file")
```
mock库包含两个重要的类mock.Mock和mock.MagicMock，大多数内部函数都是建立在这两个类之上的。在选择使用mock.Mock实例，mock.MagicMock实例或auto-spec方法的时候,通常倾向于选择使用 auto-spec方法，因为它能够对未来的变化保持测试的合理性。这是因为mock.Mock和mock.MagicMock会无视底层的API，接受所有的方法调用和参数赋值。比如下面这个用例：
```python
class Target(object):
    def apply(value):
        return value

def method(target, value):
    return target.apply(value)
```
We can test this with a mock.Mock instance like this:
```python
class MethodTestCase(unittest.TestCase):

    def test_method(self):
        target = mock.Mock()

        method(target, "value")

        target.apply.assert_called_with("value")
```
This logic seems sane, but let’s modify the Target.apply method to take more parameters:
```python
class Target(object):
    def apply(value, are_you_sure):
        if are_you_sure:
            return value
        else:
            return None
```
重新运行你的测试，然后你会发现它仍然能够通过。这是因为它不是针对你的API创建的。这就是为什么你总是应该使用create_autospec方法，并且在使用@patch和@patch.object装饰方法时使用autospec参数。
