---
id: 773
layout: post
title: '使用树莓派 Zero 实现带回显的新型 Bad USB'
date: 2017-08-03 18:09:07
author: virusdefender
tags: 安全
---

某天小黑以修理网络的名义潜入某企业公司办公室，想窃取一位运维台式机上的某个私钥文件，根据之前的信息收集，该公司电脑不能连接外网，而且有 DLP 产品监控的 agent，插入优盘后会提示，如果向优盘复制文件，会立即报警，文件也会被加密，无线网卡类设备也也不可以，只有键盘鼠标可以随便使用。办公环境下有一个 SSID 和密码已知的 guest 网络，可以访问外网。这种情况下怎么窃取私钥，并尽可能长时间的维持权限呢？

很多人也许会说 [BadUSB](https://security.tencent.com/index.php/blog/msg/74) ，但是这种情况下怎么植入木马然后传回私钥呢？

## 现有的 BadUSB 设备的缺点

### 底层硬件和驱动修改复杂

Bad USB 火了有几年了，网上的教程也是花式繁多，主要分为 Teensy 系列和 USB Rubber Ducky 系列，它们是使用 Arduino 或者优盘实现的，相对来说制作的难度比较大，因为宽泛来说都是属于"嵌入式编程"了，而且因为很多固件并不是真正开源的，是通过[各种 Hack 实现的](https://electronics.stackexchange.com/questions/49140/what-exactly-are-the-difference-between-a-usb-host-and-device)。还有一点就是这个硬件平台都是很简化的，和其他的硬件对于一般人并不是特别容易搞定的。

![](http://storage.virusdefender.net/blog/images/773/1.jpg)

### 单向数据传递，没有回显，无法更新 Paylaod

黑客们在进行渗透测试的时候，很是很讨厌没有回显的洞的，因为看不到是否执行成功，甚至看不到执行结果，只能靠运气和人品。而且设备插上之后，是否成功就已经决定了，即使执行失败，也没有办法去更新和修复自己的 Payload，不是一个持久化的方案。我们希望的是能实现攻击者、BadUSB 和受害者三部分两条链路的双向通信。

### 遇到密码就懵逼

如果你的 Payload 会弹出 UAC 或者需要 root 权限，那基本上避免不了需要输入密码了。有几个办法可以尝试下，首先是通过社工尝试收集密码字典然后暴力尝试，其次是自带一个提权脚本，比如很多洞的提权脚本并不长，而且很好用，最后那就是寄希望于人品了，如果对方直接就是使用的高权限用户，那就是人品大爆发了。这个问题的解决方案我们会放在展望章节中，并不在这一次的文章中解决。

## 树莓派也可以做 BadUSB？

一般来说，USB 设备有两种，一种是 Host，比如电脑，可以去读取其他 USB 设备的数据，另外一种是 Device，比如键盘鼠标优盘。所以从根本上来说，制作一个 Bad USB 核心要求只有一个，就是自身可以作为 USB Device。参考 https://electronics.stackexchange.com/questions/49140/what-exactly-are-the-difference-between-a-usb-host-and-device

市面上稍早些的树莓派，比如树莓派2B，树莓派3等，它们都只支持作为 Host，而迷你的[树莓派 Zero 和 Zero w](https://www.raspberrypi.org/products/raspberry-pi-zero/) 同时支持作为 Host 和 Device。

和 Zero 比，Zero w 主要是增加了 WiFi 和蓝牙，所以以下都是用的这个型号，官方价10刀，某宝大约需要25刀才能买到。当然缺点还是体积稍大，长度略长，而宽度就是正常优盘的两倍多了。

![](http://storage.virusdefender.net/blog/images/773/7.jpg)

### 电脑怎么知道我是一个键盘的

http://www.usb.org/developers/hidpage/Hut1_12v2.pdf 是 HID 设备（人机交互设备）的部分通信协议，不需要看的太仔细，有大致印象，需要的时候会再回来翻阅。

树莓派中运行的是更加熟悉的 Linux，系统已经集成了很多底层驱动，不用接触硬件细节，想声明自己是一个键盘也非常简单。

### 声明 USB HID 设备

[USB Gadget](https://www.kernel.org/doc/htmldocs/gadget/index.html) 实现了 USB 协议定义的设备端的软件功能，它需要一些配置，比如自己的类型，序列号等等。如果要创建一个 USB Gadget，就需要先配置那些信息。

Linux 中一切皆文件，配置也是，操作 Configfs 就可以告诉内核相关的配置，这一段就是围绕着这个来的。

在 https://www.kernel.org/doc/Documentation/usb/gadget_configfs.txt 也有相关的配置说明。

首先，每个 gadget 都有一个独立的文件夹，先创建一个

```shell
cd /sys/kernel/config/usb_gadget/
mkdir -p g1
cd g1
```

然后需要 `vender id` 和 `product id`等信息，这里我们用别人的id

```
echo 0x1d6b > idVendor # Linux Foundation
echo 0x0104 > idProduct # Multifunction Composite Gadget
echo 0x0100 > bcdDevice # v1.0.0
echo 0x0200 > bcdUSB # USB2
```

每个 gadget还需要序列号，制造商等信息，Linux 要求的是在一个子文件夹中存储

```
mkdir -p strings/0x409
echo "fedcba9876543210" > strings/0x409/serialnumber
echo "Valentin Brosseau" > strings/0x409/manufacturer
echo "Keyboard-dev" > strings/0x409/product
```

接下来是创建配置了，都是在 `configs/<name>.<number>` 中的

```shell
C=1
mkdir -p configs/c.$C/strings/0x409
echo "Config $C" > configs/c.$C/strings/0x409/configuration
echo 1000 > configs/c.$C/MaxPower
```

然后是需要创建一些功能的描述，是在 `functions/<name>.<instance name>` 中的

```shell
mkdir -p functions/hid.$N
echo 1 > functions/hid.usb0/protocol
echo 1 > functions/hid.usb0/subclass
echo 8 > functions/hid.usb0/report_length
echo -ne \\x05\\x01\\x09\\x06\\xa1\\x01\\x05\\x07\\x19\\xe0\\x29\\xe7\\x15\\x00\\x25\\x01\\x75\\x01\\x95\\x08\\x81\\x02\\x95\\x01\\x75\\x08\\x81\\x03\\x95\\x05\\x75\\x01\\x05\\x08\\x19\\x01\\x29\\x05\\x91\\x02\\x95\\x01\\x75\\x03\\x91\\x03\\x95\\x06\\x75\\x08\\x15\\x00\\x25\\x65\\x05\\x07\\x19\\x00\\x29\\x65\\x81\\x00\\xc0 > functions/hid.usb0/report_desc
```

最后是关联配置和功能的文件夹和启用设备

```
ln -s functions/hid.$N configs/c.$C/
ls /sys/class/udc > UDC
```

其中在创建功能描述的时候，有一些 Magic number，这些都是需要参考 USB 输入设备的协议规定的。

对于 HID 设备来说，`protocol` 和 `subclass` 都是1，`report_length` 是8，然后 `report_desc` 是比较复杂的结构。暂时不用关心，后面才会用到。

大家可以参考 https://github.com/c4software/pi-as-keyboard 的初始化脚本。

### 这就做完了

注意：树莓派 Zero 有两个 micro USB，一个标记 USB，一个标记 PWR，要使用标记 USB 的那个（题图红框区域），否则只能供电。

Linux 上 `lsusb` 就可以看到这个设备

```shell
Bus 001 Device 011: ID 1d6b:0104 Linux Foundation Multifunction Composite Gadget
```

Mac上显示是这样的

![](http://storage.virusdefender.net/blog/images/773/2.jpg)

我们先简单的测试下，在树莓派上把

```shell
for run in {1..10}
do
  echo -ne "\x00\x00\x00\x17\x00\x00\x00\x00" > /dev/hidg0
  echo -ne "\x00\x00\x00\x00\x00\x00\x00\x00"  > /dev/hidg0
done
```

保存为 `test.sh`，然后使用 root 权限运行，如果看到看到自动输出了一堆字母 `t`，那就说明成功了一大半了。但是字符串是怎么转换为上面的一堆指令的呢？这时候要引入 KeyCode 的概念。

KeyCode 顾名思义就是一个键就是一个编号，告诉系统对应的编号就可以。具体的实现是

```python
[modifier, reserved, Key1, Key2, Key3, Key4, Key6, Key7]
```

的结构，第一位是代表一些特殊的按键，比如 Ctrl、Shift 等，后面的6位就是指哪些键被按下了，它最多支持键盘上同时按下6个键。

在上文提到的 USB 协议 PDF 的 `10 Keyboard/keypad page(0x07)` 章节规定了所有的 KeyCode，可以查阅，网上也有一些转换脚本。然后通过输入连续的8个 null 数据，代表按键结束了。

要注意的是，在协议中，大小写字母还有部分数字和符号的 KeyCode 是一样的，这个时候，需要修改第一个位为 Shift，和平时使用键盘是一样的。比如

```python
# t
\x00\x00\x00\x17\x00\x00\x00\x00
# T
\x02\x00\x00\x17\x00\x00\x00\x00
```

如果使用 Python 实现的话，就是

```python
with open("/dev/hidg0", "wb") as f:
    for item in s:
      s, k = letter_to_keycode(item)
      f.write(s + "\x00" + k + "\x00" * 5)
      f.write("\x00" * 8)
      f.flush()
```

至此，如果我们将对应的指令修改为创建后门（下载文件执行、上传文件到网络等等）的命令，然后插入后自动运行脚本，那市面上常见的 BadUSB 就制作完成了。

### 树莓派安装小贴士

 - 如果 `systemctl status enable_hid` 出现 `enable_hid.sh[623]: /usr/bin/enable_hid.sh: line 27:   636 Segmentation fault      ls /sys/class/udc > UDC`，请降级系统，[这个问题目前已经修复但是没有发布](https://github.com/raspberrypi/linux/issues/1943)。可以使用命令 `rpi-update 2ca627126e49c152beb1bf7abd7122ce076dcc65` 回退到和我一样的版本。
 - 树莓派写存储卡镜像之后，在存储卡根目录创建一个 `wpa_supplicant.conf` 的文件，内容是

     ```
     network={
        ssid="WiFi SSID"
        psk="WiFi 密码"
        key_mgmt=WPA-PSK
     }
     ```

然后创建一个 `ssh` 文件，内容为空，这样树莓派启动之后会自动联网和开启 ssh，默认用户名密码是`pi:raspberry`。

## 下面才是重点

但是我们不能满足于此，上面提到的问题一个都没解决呢。

### 自带网卡和蓝牙的树莓派

相对其他 BadUSB 的平台，树莓派 Zero w 自带网卡和蓝牙，这样我们就可以实现远程的交互了。比如可以使用蓝牙在实施攻击的初期进行配置，比如 WiFi 密码和 Payload 类型，之后就可以使用 client，通过 socket 远程加密连接到控制端，如果发现自己的 Payload 有 bug 或者有更好的 Payload 就可以随时更新了，是不是很棒。

### 黑夜中的那盏灯

键盘特点是用来输出，很多人认为 Host 无法给键盘写入数据，其实并不是的。

![黑夜里的一盏灯](http://storage.virusdefender.net/blog/images/773/3.jpg)

键盘上按下 Caps Lock，再打开了系统自带的软键盘，点击软键盘的 Caps Lock，这个灯是会熄灭的，也就是键盘上的 LED 灯也是可以被软件控制的，主机也会发送信号给键盘的。

### 回归原始的0和1

还记得[使用硬盘灯进行边信道攻击的新闻](http://www.freebuf.com/news/127629.html)么 ，虽然看起来有些魔幻，但是确实有人能做到，所以我们也要做到。

在 Linux 上，可以使用 [Input 子系统 Event Interface](http://blog.sina.com.cn/s/blog_602f87700101dno6.html) 来控制 LED 灯或者使用 sysfs 控制，但是系统怎么知道我们有多少个灯呢，怎么知道我们支持哪些灯呢？这就要回到开头的 HID `report_desc` 和协议 `11 LED Page (0x08)` 章节了，在那一长串数据中隐藏了 LED 灯的秘密。

我们的定义是

```python
0x95, 0x05,        //   Report Count (5)
0x75, 0x01,        //   Report Size (1)
0x05, 0x08,        //   Usage Page (LEDs)
0x19, 0x01,        //   Usage Minimum (Num Lock)
0x29, 0x05,        //   Usage Maximum (Kana)
```

但是通过测试发现下面两个 "feature" ，让这个用法变得困难

 - Linux 只能最多展示控制5个灯的状态（这是我 descriptor 写的不对还是特性？）
 - 每个灯发送的控制指令和上一次的不一致才可以收到这个信号
 
 ![](http://storage.virusdefender.net/blog/images/773/4.jpg)

图的上半部分是声明了3个 LED 灯，下半部分是声明了6个 LED 灯，但是实际只能显示出5个。

向 `input7::capslock/brightness` 写入0或者1可以改变对应灯的状态，但是这里一次只能改变一个，而且重复写入相同的状态，在树莓派上是收不到的。可以在树莓派上使用脚本读取 `/dev/hidg0` 设备查看。

这种 "feature" 就阻碍了数据的传输，因为这是一次可以传递 n bit （n 为灯的数量）数据的带宽，但是现在的情况下到底还能不能传递数据了呢？答案是肯定的，那就是使用两个 bit 代表一个 bit 的数据。

使用 `00` 和 `01` 状态代表数据0，使用 `10` 和 `11` 状态代表数据1，假设初始状态为`00`，如果下一位是1，则使用 `10` 状态，只改变第一个灯的开关，如果下一位还是0，那使用 `01` 状态，以此类推，就可以发现，无论下一位是什么状态，总可以只改变一个灯的状态，这一点和数字电路中的[格雷码](https://zh.wikipedia.org/wiki/%E6%A0%BC%E9%9B%B7%E7%A0%81)有点像。

```python
state_table = [[1, 2],
               [0, 3],
               [0, 3],
               [1, 2]]

last_state = 0

def write_data(data):
    global last_state
    for item in data:
        cur_value = int(item != "0")
        last_state = state_table[last_state][cur_value]
        # print "data", item, "cur value", cur_value, "cur_state", last_state
        for i in range(2):
            # print "write led", i, "value", int((last_state & (i + 1)) != 0)
            write_led(i, int((last_state & (i + 1)) != 0))
```

这个在代码层面上就是写对应的 `brightness` 文件或者使用 Input Event 实现，其中 LED 的 code 是 `EV_LED`。使用 Python 实现的简化代码如下

```python
# 写 sysfs
if led == 0:
   path = "/sys/class/leds/input23::numlock/brightness"
else:
   path = "/sys/class/leds/input23::capslock/brightness"
with open(path, "w") as f:
   f.write(str(value))
   time.sleep(0.001)

# Input Event
fd = os.open(device_path, os.O_WRONLY)
now = time.time()
sec = int(now)
usec = int((now - sec) * 1.0E6)
data = struct.pack('@llHHI', sec, usec, 0x11, led, value)
os.write(fd, data)
os.close(fd)
```

经过测试，写 sysfs 要比 Input Event 快一些，但是每次 write 之间最好 sleep 1毫秒，否则可能出现一些奇怪的数据（黑人问号，我也不知道为啥啊）。总体上可以实现也就比 56k 猫才慢百倍的带宽。

美中不足的是:

  1. 需要 BadUSB 输入一个脚本或者可执行文件，然后才可以与键盘交互。
  2. bit 传递数据太暴力了，如果中间有一位丢失或者发生错误，可能导致整个数据乱掉，如果想实现一些更高级的校验，就会进一步的降低带宽。
  3. Linux 上操作 sysfs 和使用 Input Event 都需要 root 权限。

控制键盘 LED 的代码，Mac版本的实现在 https://developer.apple.com/library/content/samplecode/HID_LED_test_tool/Introduction/Intro.html，Windows版本的实现在 https://github.com/dnet/usbpwn-host，并没有测试这两个平台上的权限情况。

### 大道至简

虽然实现了交互，但是这个速度并不能让人满意。我们需要去更底层上去操作设备，从而规避上面的这些问题，那就是 `hidraw`。在[内核的相关文档](https://www.kernel.org/doc/Documentation/hid/hidraw.txt)中， 提到说这个接口是底层的底层接口，部分非标准的设备可以使用它传递原始数据。

hidapi https://github.com/signal11/hidapi 库实现了三平台上的向 HID 设备写 raw 数据的 API `hid_write`。（Linux 上需要 root 权限，据说 Windows 上不需要特殊权限？）

以 Linux 为例，其实逻辑非常非常简单，使用 Python 描述就是

```python
fd = os.open("/dev/hidraw1", os.O_RDWR)
os.write(fd, data)
os.close(fd)
```

而且这个是可读的，也就是你在树莓派中向 `/dev/hidg0` 写入的数据，这里可以直接读取到，而且不会再出发输入动作。除了第一步写 client，之后就再也不需要使用键盘打开 shell，输入，然后快速关闭 shell 的流程了，可以在后台完成一切的操作。这个也大大的降低了被发现的几率。

我们发现事情是越做越简单了，而且这个接口速度要快的多，一般的命令执行结果，都几乎可以实时读取到。

### 攻击小 tips

在插入 BadUSB 设备之后，不要立即调用键盘输入，毕竟人坐在电脑前面还是能注意到一个一闪而过的黑框的，可以先模拟按下大写锁定键，如果发现很快就切换回了小写状态，那用户很可能正在使用电脑，如果长期没有响应，那可能用户不在电脑前面。

## 展望

### USB 中间人
 
 还记得某宝上的硬件 USB 键盘记录器么
 
 ![](http://storage.virusdefender.net/blog/images/773/5.jpg)
 
 但是这种键盘记录器只能被动的记录，无法传输记录的内容，如果我们的 BadUSB 和这种 keyLogger 结合在一起就大有作为了。
 
一种场景是先默默的记录键盘输入，然后自动或者人工筛选可能是密码的值，比如 `sudo $command` 后面跟的一串奇怪的字符串，之后使用密码获取更高权限植入传输脚本和传输数据。

### 使用优盘启动

在2016年 Geekpwn 上，有一个环节叫"机器人挑战赛"，来自哈尔滨理工大学的选手[薛恩鹏](http://www.sohu.com/a/136066424_505799)实现了使用机器人给电脑插入优盘窃取资料，但是我并不清楚实现的细节，可能是在 BIOS 中设置为优盘启动（类似安装操作系统的流程），在硬盘没有加密的情况下就可以完全绕过主机里面的 DLP 产品。BadUSB 也可以使用相同的思路，因为我们的树莓派也是完全可以将自己模拟为一个优盘的。

### Bad Bridge

其实薛恩鹏的机器人还可以做的更多，比如使用机器拔掉电脑的网线，然后植入 [Throwing Star LAN Tap](https://greatscottgadgets.com/throwingstar/) 类似的流量抓包工具，360也要一款类似的产品，原理都很简单，就是 Hub。

![](http://storage.virusdefender.net/blog/images/773/6.jpg)

可以使用树莓派作为抓包端，兼顾 BadUSB，就可以实现实时的流量中转了。
 
## 防范

 - 安全意识，不要随便插来历不明的 USB 设备，不仅仅是优盘，包括键盘鼠标。
 - USB 白名单，DLP 产品应该使用更加严格的 USB 限制策略
 - 全盘加密，对开机密码、root密码等引入多因素认证

8月3日，Red Hat 发表[文章](http://rhelblog.redhat.com/2017/08/03/built-in-protection-against-usb-security-attacks-with-usbguard/)，声称 Red Hat Enterprise Linux 7.4 版本开始集成 USBGuard 软件框架，利用黑白名单等技术抵御流氓 USB 设备的攻击。
 
## 感谢

 - http://www.csoonline.com/article/3087484/security/say-hello-to-badusb-20-usb-man-in-the-middle-attack-proof-of-concept.html 伦敦 Royal Holloway University 信息安全组发表的论文
 - 技术最厉害的萌神，给指点了很多思路


