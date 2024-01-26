---
title: "Linux进程地址空间"
date: 2023-06-03T14:42:58+08:00
draft: false
categories: [ "undefined"]
tags: ["undefined"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## linux进程地址空间😄

### 概览

进程地址空间是属于进程的，虚拟的。每一个进程都有自己的从0开始的地址空间，并且这些地址是虚拟的，不是实存上真实的偏移量。虚拟内存地址通过mmu内存管理单元映射到物理内存地址上。

32位系统和64位系统的地址空间大小不一样。32位进程地址空间大小为4G。64位系统没有使用Math.power(2,64)的所有地址，而是给内核空间、用户空间各128TB，这已经完全够用了。32位和64位系统的内核空间、进程空间如下图所示。

![](/img/v2-f6b5b028da63af405fa19eaf4f545f1a_r.png)

先用一张图片描述下用户空间由哪些部分构成：（图片是64位系统下的）。如图所示，从0开始分别是code、data、bss、heap。stack从高地址开始。stack和heap中间是mapping area。

![](/img/2138374-20200828154940757-1842339641.png)

再用32位系统的一张图更精细地描述：

![](/img/2138374-20200828155103154-1191841853.jpg)

### 用户地址空间各分区

#### 代码段（text）

通常用于存放程序执行代码(即CPU执行的机器码)

#### 数据段（data）

存放程序中已初始化且初值不为0的全局变量和静态局部变量。数据段属于静态内存分配(静态存储区)，可读可写。

#### BSS段

包括:

- 未初始化的全局变量和静态局部变量
- 初始值为0的全局变量和静态局部变量(依赖于编译器实现)
- 未定义且初值不为0的符号(该初值即common block的大小)

#### 堆

- 堆用于存放进程运行时动态分配的内存段，可动态扩张或缩减。
- 堆中内容是匿名的，不能按名字直接访问，只能通过指针间接访问。当进程调用malloc(C)/new(C++)等函数分配内存时，新分配的内存动态添加到堆上(扩张)；当调用free(C)/delete(C++)等函数释放内存时，被释放的内存从堆中剔除(缩减) 。
- 堆的末端由break指针标识，当堆管理器需要更多内存时，可通过系统调用brk()和sbrk()来移动break指针以扩张堆，一般由系统自动调用。
- 可见，堆容易造成内存碎片；由于没有专门的系统支持，效率很低；由于可能引发用户态和内核态切换，内存申请的代价更为昂贵
- 操作系统为堆维护一个记录空闲内存地址的链表。当系统收到程序的内存分配申请时，会遍历该链表寻找第一个空间大于所申请空间的堆结点，然后将该结点从空闲结点链表中删除，并将该结点空间分配给程序。若无足够大小的空间(可能由于内存碎片太多)，有可能调用系统功能去增加程序数据段的内存空间，以便有机会分到足够大小的内存，然后进行返回

#### 内存映射段


- 此处，内核将硬盘文件的内容直接映射到内存, 任何应用程序都可通过Linux的mmap()系统调用请求这种映射。内存映射是一种方便高效的文件I/O方式，。普通文件被映射到进程地址空间后，进程可以像访问普通内存一样对文件进行访问，不必再调用read()/write()等操作。 因而被用于装载动态共享库。用户也可创建匿名内存映射，该映射没有对应的文件, 可用于存放程序数据

- 从进程地址空间的布局可以看到，在有共享库的情况下，留给堆的可用空间还有两处：一处是从.bss段到0x40000000，约不到1GB的空间；另一处是从共享库到栈之间的空间，约不到2GB。这两块空间大小取决于栈、共享库的大小和数量。这样来看，是否应用程序可申请的最大堆空间只有2GB？事实上，这与Linux内核版本有关。在上面给出的进程地址空间经典布局图中，共享库的装载地址为0x40000000，这实际上是Linux kernel 2.6版本之前的情况了，在2.6版本里，共享库的装载地址已经被挪到靠近栈的位置，即位于0xBFxxxxxx附近，因此，此时的堆范围就不会被共享库分割成2个“碎片”，故kernel 2.6的32位Linux系统中，malloc申请的最大内存理论值在2.9GB左右。

- mmap/munmap是常用的一个系统调用，使用场景是：**分配内存、读写大文件、连接动态库文件、多进程间共享内存**。

- malloc申请内存的大小超过128K就会**使用mmap分配内存，在堆和栈之间找一块空闲内存分配(对应独立内存，而且初始化为0)**

    - mmap通过将磁盘文件映射到用户空间（0拷贝）。
> 当进程读文件时，发生缺页中断，因为很明显 当前文件还不在内存当中，要去磁盘进行访问，给虚拟内存分配对应的物理内存，在通过磁盘调页操作将磁盘数据读到物理内存上，实现了用户空间数据的读取，整个过程只有一次内存拷贝。普通文件被映射到进程地址空间后，进程可以像访问普通内存一样对文件进行访问，不必再调用read()/write()等操作
    - 用于进程间大数据量通信：（进程之间通过共享内存进行通信的实例）：

> 两个进程映射同一个文件，在两个进程中，同一个文件区域映射的虚拟地址空间不同。当一个进程先操作文件时，先通过缺页获取物理内存，进而通过磁盘文件调页操作将文件数据读入内存。

> 另一个进程访问文件的时候，发现没有物理页面映射到虚拟内存，通过fs的缺页处理查找cache区是否有读入磁盘文件，有的话建立映射关系（都指向同一块内存），这样两个进程通过共享内存就可以进行通信。

![](/img/2138374-20200828160949603-365007815.jpg)

- 私有/共享、文件/匿名映射组合

(1)私有文件映射:多个进程使用同样的物理页面进行初始化，但是各个进程对内存文件的修改不会共享，也不会反映到物理文件中。

比如对linux .so动态库文件就采用这种方式映射到各个进程虚拟地址空间中。

(2)共享文件映射:多个进程通过虚拟内存技术共享同样物理内存，对内存文件的修改会反应到实际物理内存中，也是进程间通信的一种。

(3)私有匿名映射:mmap会创建一个新的映射，各个进程不共享，主要用于分配内存(malloc方式分配的内存)(malloc分配大内存会调用mmap)。

(4)共享匿名映射:这种机制在进行fork时不会采用写时复制，父子进程完全共享同样的物理内存页，也就是父子进程通信,父进程或者子进程malloc了一大块空间，对于父子进程都是可以访问的，共享的。

```c
#include <sys/mman.h>
void *mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset);
int munmap(void *addr, size_t length);
```

mmap系统调用接口函数

#### 栈

- 由编译器自动分配释放
- 为函数内部声明的非静态局部变量(C语言中称“自动变量”)提供存储空间
- 记录函数调用过程相关的维护性信息，称为栈帧(Stack Frame)或过程活动记录(Procedure Activation Record)
- 栈的大小在运行时由内核动态调整。
- Linux中ulimit -s命令可查看和设置堆栈最大值，当程序使用的堆栈超过该值时, 发生栈溢出(Stack Overflow)，程序收到一个段错误(Segmentation Fault)。

### c代码的内部布局例子

```c+
//main.cpp  
int a = 0; 全局初始化区  
char *p1; 全局未初始化区  
main()  
{  
      int a = 4; 栈,4也是存在栈上  
      char s[] = "abc"; 栈  "abc"也是存在栈上
      char *p2; 栈  
      char *p3 = "123456"; 123456\0在常量区（是在Data段上），p3在栈上。  
      static int c =0； 全局（静态）初始化为0,就是放在BSS段   
      p1 = (char *)malloc(10);  
      p2 = (char *)malloc(20);  
      malloc分配得来得10和20字节的区域就在堆区。因为属于动态申请分配内存空间  
      strcpy(p1, "123456"); 123456\0放在常量区，编译器可能会将它与p3所指向的"123456"优化成一个地方。  
}  
```

一定注意：数组s储存的内容是在运行的时候赋值的，但是指针p3指向的常量区中的字符串内容是编译时就赋值的。

## 参考文档

[linux进程地址空间划分](https://www.cnblogs.com/yizhanwillsucceed/p/13578076.html)

[Linux的进程地址空间[一]](https://www.zhihu.com/tardis/zm/art/66794639?source_id=1003)

[段页式内存管理](https://zofun.github.io/2020/05/15/%E6%AE%B5%E9%A1%B5%E5%BC%8F%E5%86%85%E5%AD%98%E7%AE%A1%E7%90%86/)