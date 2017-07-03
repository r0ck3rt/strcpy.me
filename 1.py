import json
import datetime
import re
import os
import requests


def fromtimestamp(ts):
    return datetime.datetime.utcfromtimestamp(ts)


with open("/Users/virusdefender/Desktop/select___from_typecho_contents_where_typ.json", "r", encoding="utf-8") as f:
    data = json.load(f)

for item in data:
    created = fromtimestamp(item["created"]) + datetime.timedelta(hours=8)

    text = item["text"].replace("<!--markdown-->", "")

    nums = re.findall("!\[[\s\S]*?\]\[(\d+)\]", item["text"])
    if nums:
        os.mkdir("images/" + str(item["cid"]))

    for i in nums:
        print(i)
        for img in re.findall(r"\[%s\]:\s(http[^\n]*)" % i, item["text"]):
            img = img.strip()
            if "qbox" in img:
                ext = img.split(".")[-1]
                path = "images/%s/%s.%s" % (item["cid"], i, ext)

                try:
                    content = requests.get(img).content
                except Exception as e:
                    print(e)
                    continue
                with open(path, "wb") as f:
                    f.write(content)

                new_url = "https://storage.virusdefender.net/blog/" + path

                print(img, path)
                text = text.replace(img, new_url)

    with open("pages/%d-%d-%d-%s.md" % (created.year, created.month, created.day, item["title"]), "w", encoding="utf-8") as f:

        tpl = '''---
id: %d
layout: post
title: '%s'
date: %s
author: virusdefender
tags: 
---\n\n''' % (item["cid"], item["title"], str(created))
        f.write(tpl)
        f.write(text)
