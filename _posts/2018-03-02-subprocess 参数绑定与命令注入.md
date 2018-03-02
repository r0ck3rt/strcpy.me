---
id: 787
layout: post
title: 'subprocess 参数绑定与命令注入'
date: 2018-03-01 23:46:07
author: virusdefender
tags: 安全 CTF
---
使用了 subprocess 传递数组形式的 args 过去就一定没有命令注入的问题么？

一般认为说这样的代码是存在命令注入问题的，比如

```python
import os
import subprocess

host = "baidu.com"

subprocess.call("ping -c 1 %s" % host, shell=True)
os.system("ping -c 1 %s" % host)
```

如果 `host = "baidu.com; ls"` 就可以执行 `ls` 了

推荐的做法是

> args is required for all calls and should be a string, or a sequence of program arguments. Providing a sequence of arguments is generally preferred, as it allows the module to take care of any required escaping and quoting of arguments (e.g. to permit spaces in file names). If passing a single string, either shell must be True (see below) or else the string must simply name the program to be executed without specifying any arguments.

所以写法应该修改为

```python
subprocess.call(["ping", "-c", "1", host])
```

如果传入 `host = "baidu.com; ls"`，就会提示 `ping: cannot resolve baidu.com; ls: Unknown host`，那是因为 ping 会把最后一个参数看做一个整体。下面是另外一个 demo

```python
import os
import subprocess

for host in ["baidu.com", "baidu.com; echo 1"]:
    subprocess.call("./ping.py -c 1 %s" % host, shell=True)
    os.system("./ping.py -c 1 %s" % host)
    subprocess.call(["./ping.py", "-c", "1", host])
```

`ping.py` 的内容是

```
#!/usr/bin/python
import sys
print(sys.argv)
```

输出是

```
['./ping.py', '-c', '1', 'baidu.com']
['./ping.py', '-c', '1', 'baidu.com']
['./ping.py', '-c', '1', 'baidu.com']
['./ping.py', '-c', '1', 'baidu.com']
1
['./ping.py', '-c', '1', 'baidu.com']
1
['./ping.py', '-c', '1', 'baidu.com; echo 1']
```

因为 `ping` 只会去最后一个 args 中取 host，并不会自己去 parse 参数，所以第三种写法是安全的，但是也不是绝对的，这里很多人都有误解。因为对于很多参数非常复杂的程序来说，args 提供的拆分可能并不是预期的，比如说

```
tcpdump -i lo tcp port 80
```

tcpdump 支持写各种 expression 作为过滤条件，这种情况下，args 还是按照空格分隔的，取到的参数是 `['tcpdump', '-i', 'lo', 'tcp', 'port', '80']`，而实际期望是 `['tcpdump', '-i', 'lo', 'tcp port 80']`，这样就不能简单的去看 args 了，tcpdump 就会自己去 parse 命令行参数，可能是比较宽松的，这种情况下，如果 expression 可以被用户控制，还是可能产生命令注入的问题。

另外一个就是 tcpdump 支持参数名和值之间不写空格的写法，比如 `tcpdump -ilo tcp port 80`。

## 可以写文件么

```
sudo python -c 'import subprocess; subprocess.call(["tcpdump", "-i", "lo", "-w /tmp/1.pcap"])'
```

这种情况下会报错，提示 `tcpdump:  /tmp/1.pcap: No such file or directory`

这样才可以

```
sudo python -c 'import subprocess; subprocess.call(["tcpdump", "-i", "lo", "-w/tmp/2.pcap"])'
```

## 可以执行命令么

```
sudo python -c 'import subprocess; subprocess.call(["tcpdump", "-i", "lo", "-G1", "-w", "/tmp/1.pcap", "-z/usr/games/cowsay"])'
```

更详细的利用可以参考 https://www.anquanke.com/post/id/87260

## 更加通用的解决方法

虽然文档上没有提到，但是作为 Linux 下的通用做法，tcpdump 也支持使用 `--` 分隔参数和表达式。比如果有个文件的文件名是 `-la`，想使用 `ls -la` 查看文件的详细信息的话，就需要 `ls -la -- -la`。

```
sudo python -c 'import subprocess; subprocess.call(["tcpdump", "-i", "lo", "-G1", "-w", "/tmp/1.pcap", "--", "-z/usr/games/cowsay"])'

sudo python -c 'import subprocess; subprocess.call(["tcpdump", "-i", "lo", "-G1", "-w", "/tmp/1.pcap", "--", "tcp port 80"])'
```

无论最后一个参数怎么写，都不会出现问题了。