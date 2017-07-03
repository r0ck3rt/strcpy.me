---
id: 652
layout: post
title: 'OnlineJudge 沙箱实现思路'
date: 2016-01-19 21:23:00
author: virusdefender
tags: 
---

有一个在线运行用户提交代码的功能，为了保证服务器安全，沙箱是必不可少的，用来限制系统调用。目前常用的有 `ptrace` 和 `seccomp`。

听说 `ptrace` 存在效率问题，可能会让你的代码运行时间增加很多，但是我并没有测试，直接就 pass 了。

而加载 `seccomp` 需要主动的在自己的代码中加载策略，也就是说需要修改已有的代码，但是去修改用户提交的代码是不大可能的。然后就想到了下面几个方法：

 - `LD_PRELOAD`加载动态链接库，然后在 so 中 hook `__libc_start_main`，然后就可以在用户的`main`函数执行自己的代码了。但是如果在用户的代码中再定义`__lbc_start_main`函数就可以绕过，虽然网上有人说需要 `-nostdlib` 的编译参数，但是我实际测试并不需要。下面是沙箱的实现代码

```c
#define _BSD_SOURCE // readlink
#include <dlfcn.h>
#include <stdlib.h> // exit
#include <string.h> // strstr, memset
#include <link.h>   // ElfW
#include <errno.h>  // EPERM
#include <unistd.h> // readlink
#include <seccomp.h>
#include <stdio.h>
int syscalls_whitelist[] = {SCMP_SYS(read), SCMP_SYS(write), 
                            SCMP_SYS(fstat), SCMP_SYS(mmap), 
                            SCMP_SYS(mprotect), SCMP_SYS(munmap), 
                            SCMP_SYS(brk), SCMP_SYS(access), 
                            SCMP_SYS(exit_group)};
typedef int (*main_t)(int, char **, char **);

#ifndef __unbounded
# define __unbounded
#endif

int __libc_start_main(main_t main, int argc, 
    char *__unbounded *__unbounded ubp_av,
    ElfW(auxv_t) *__unbounded auxvec,
    __typeof (main) init,
    void (*fini) (void),
    void (*rtld_fini) (void), void *__unbounded
    stack_end)
{

    int i;
    ssize_t len;
    void *libc;
    int whitelist_length = sizeof(syscalls_whitelist) / sizeof(int);
    scmp_filter_ctx ctx = NULL;
    int (*libc_start_main)(main_t main,
        int,
        char *__unbounded *__unbounded,
        ElfW(auxv_t) *,
        __typeof (main),
        void (*fini) (void),
        void (*rtld_fini) (void),
        void *__unbounded stack_end);

    // Get __libc_start_main entry point
    libc = dlopen("libc.so.6", RTLD_LOCAL  | RTLD_LAZY);
    if (!libc) {
        exit(1);
    }

    libc_start_main = dlsym(libc, "__libc_start_main");
    if (!libc_start_main) {
        exit(2);
    }
    
    ctx = seccomp_init(SCMP_ACT_KILL);
    if (!ctx) {
        exit(3);
    }
    for(i = 0; i < whitelist_length; i++) {
        if (seccomp_rule_add(ctx, SCMP_ACT_ALLOW, 
                             syscalls_whitelist[i], 0)) {
            exit(4);
        }
    }
    if (seccomp_load(ctx)) {
        exit(5);
    }
    seccomp_release(ctx);
    return ((*libc_start_main)(main, argc, ubp_av, auxvec,
                 init, fini, rtld_fini, stack_end));
}
```
  参考  http://stackoverflow.com/a/27735456/2737403 和 https://github.com/daveho/EasySandbox

 - 编译的时候将两个文件编译在一起，`gcc sandbox.c user_code.c -ldl -lseccomp -o user_code`，虽然说直接定义`__libc_start_main`函数会提示重复定义，但是部分库函数还是可以通过定义同名函数覆盖绕过，比如 `seccomp`里面的函数、`dlopen`函数。
  
 - `exceve` 之前加载策略，就需要将 `exceve` 系统调用加白名单，有点不安全，但是可以在 `seccomp` 参数中指定 `exceve` 的执行参数，第一个参数就是文件路径，必须得匹配才行，否则就会 kill 掉。可以将指定的文件名加白名单。
```c
#include <stdio.h>
#include <unistd.h>
#include <seccomp.h>

int main() {
  char file_name[30] = "/bin/ls";
  char file_name1[30] = "xxxxxx";
  char *argv[] = {"/", NULL};
  char *env[] = {NULL};
  printf("unrestricted\n");

  // Init the filter
  scmp_filter_ctx ctx;
  ctx = seccomp_init(SCMP_ACT_ALLOW);

  seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(execve), 1,
                        SCMP_A0(SCMP_CMP_NE, file_name));

  seccomp_load(ctx);
  execve(file_name, argv, env);
  return 0;
}
```
  如果改成`execve(file_name1, argv, env);`，就没法执行了。这样的话，应该尽力的限制了系统调用。

  但是上面的仅仅是一个 demo，如果改成白名单的形式，需要放行的 syscalls 还是比 `__libc_start_main` 里面的要多的，比如说`open`、`arch_prctl`等，这些都是 libc 初始化的时候需要的。

  开源 https://github.com/QingdaoU/Judger

参考 

 - http://manpages.ubuntu.com/manpages/saucy/man3/seccomp_rule_add.3.html
 - https://filippo.io/linux-syscall-table/
 - https://www.zhihu.com/question/23067497