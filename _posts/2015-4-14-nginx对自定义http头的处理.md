---
id: 244
layout: post
title: 'nginx对自定义http头的处理'
date: 2015-04-14 15:04:00
author: virusdefender
tags: 其他
---

有一个app调用后端api的时候，会在http头里面放置`AUTH_TOKEN`字段，用来用户鉴权，但是后端一直返回用户没有登录，但是本地使用django自带的runserver是可以的。后端的代码是这样的。
```python
class TokenAuthMiddleware(object):
    def process_request(self, request):
        if isinstance(request.user, User):
            return
        
        path = request.path_info.lstrip('/')
        exempt_urls = [re.compile(expr) for expr in LOGIN_REQUIRED_EXEMPT_URLS]

        # 不管是否登录 只要访问到的地址是排除在外的就不用接下来的判断了
        if any(m.match(path) for m in exempt_urls):
            return

        token = request.META.get("HTTP_AUTH_TOKEN", None)
        if token:
            r = redis.Redis(db=REDIS_USER_TOKEN_DB)
            user_id = r.get(token)
            if user_id:
                try:
                    user = User.objects.get(pk=user_id)
                    request.user = user
                    return
                except User.DoesNotExist:
                    pass

        return HttpResponse(json.dumps({"status": "error",
                                        "content": u"必须登录之后才能查看~"}),
                            content_type="application/json")
```
就考虑后端可能取到的http头有问题，在日志中打印`request.META`，发现服务器上没有找到`AUTH_TOKEN`的http头，而加一个其他的http头就可以找到，猜测是下划线的问题，将`AUTH_TOKEN`换成`AUTH-TOKEN`后可以找到`HTTP_AUTH_TOKEN`字段。

然后搜索发现nginx对header的字符做了限制，默认`underscores_in_headers`为`off`，表示如果header中包含下划线，则忽略掉。在配置文件增加`underscores_in_headers on;`就可以了。

> underscores_in_headers on | off; 
> 
> Default:off  
> Context:http, server 
> 
> Enables or disables the use of underscores in client request header
> fields. When the use of underscores is disabled, request header fields
> whose names contain underscores are marked as invalid and become
> subject to the ignore_invalid_headers directive.  level, its value is
> only used if a server is a default one. The value specified also
> applies to all virtual servers listening on the same address and port.

还有一个就是后端取到的http头里面是把`-`变成了`_`的，比如上面的`AUTH-TOKEN`，后端要获取`HTTP_AUTH_TOKEN`。
