---
title: "面试：Redis"
date: 2022-11-23T19:38:31+08:00
draft: false
categories: [ "undefined"]
tags: ["interview"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---

## 缓存雪崩、缓存击穿、缓存穿透

讨厌命名党，明明是很简单的几种情况

- 缓存雪崩：redis中大量key在短时间失效，导致集中查询mysql，mysql压力突增。
- 缓存击穿：某个热点key，突然失效，导致该key上的几千qps打到mysql上。
- 缓存穿透：大量请求redis中不存在的key，导致向mysql中请求这些数据。多发于非法的参数。

## 数据库和缓存双写，导致的不一致问题

偏业务，不看

## 线程模型

- 命令执行（get、set以及hash计算等）使用单线程
- 网络处理、报文解析：5.0以前也是单线程，6.0以后多线程

redis处理socket连接采用IO多路复用，即单线程处理多个FD，FD可读、可写时再进行处理。

单线程的好处是没有线程切换的损耗，以及避免加锁

但是对于大value，网络io将会占用大量cpu时间，单线程就会导致cpu在io上等待，所以6.0开始有多线程。

## Redis的过期策略和内存淘汰策略

过期策略：

- 定时过期：每隔一段时间扫描expire字典中的若干个（不是全部）key，若过期则删除。并不扫描全部，避免过高的cpu负载
- 惰性删除：已过期的key在访问到时进行过期。

过期策略针对的是设置了expire时间的key，redis还支持不过期。针对不过期的key，以及定时过期没扫描到的key，redis也有内存淘汰机制，防止撑爆内存。

内存淘汰机制：

- noeviction：当内存不足以容纳新写入数据时，新写入操作会报错。
- allkeys-lru：当内存不足以容纳新写入数据时，在键空间中，移除最近最少使用的key。
- allkeys-random：当内存不足以容纳新写入数据时，在键空间中，随机移除某个key。
- volatile-lru：当内存不足以容纳新写入数据时，在设置了过期时间的键空间中，移除最近最少使用的key。
- volatile-random：当内存不足以容纳新写入数据时，在设置了过期时间的键空间中，随机移除某个key。
- volatile-ttl：当内存不足以容纳新写入数据时，在设置了过期时间的键空间中，有更早过期时间的key优先移除。

## LRU最近最少使用 java实现

使用HashMap+LinkedList实现

- LinkedList实现双端队列，保存使用顺序
- HashMap保存索引，即key是否存在

## 高可用

高可用涉及到的点有：

- 持久化
- 主从复制
- sentinel（哨兵模式）
- redis集群模式

这些主题有一些演进关系，例如，主从复制用的是持久化的aof/rdb，sentinel又依赖于主从复制，redis集群则是抛弃了哨兵的高可用方案。接下来就按照这个顺序来看。

## 持久化

### RDB

- 使用SAVE， BGSAVE命令来定时地快照
- BGSAVE使用fork来创建子进程，利用copy-on-write的机制，只有脏页才会新增内存占用，共用未变更的内存。
- 因为是快照，所以更加紧凑
- 因为是定时执行，所以可能丢失部分数据

### AOF

- 尾部追加
- 在网络IO线程接收到RESP协议的指令后面，处理流程的最后会进行写AOF
- 写AOF的过程不仅是写到文件，也会写到slave
- 当AOF文件过大时，会进行rewrite，也就是将生成RDB，替换头部的操作记录。 

### 异步拷贝

1. 调用SLAVEOF或CLUSTER REPLICATE命令，获取master的ip、port
2. redis的定时任务创建到master的tcp连接（在发现没有有效连接的情况下）
3. 通过该tcp连接发送PING AUTH REPLCONF等指令，完成与master的握手
4. 如果是第一次拿拷贝，没有runid 和offset，转到5。如果不是第一次拿拷贝，则转到6
5. 发送PSYNC ? -1，接收master的rdb格式的全量同步数据、runid 和offset。rdb接收完毕后，redis加载rdb文件，而后转到7
6. 发送PSYNC runid offset，收到+CONTINUE runid，表示主节点继续“增量”地发送异步拷贝信息 ，转到7。（PS：这里仅覆盖runid和offset有效的情况，关于有效性和无效时的表现在《主节点PSYNC实现》有叙）
7. 主节点会不断发送自己收到的写请求的tcp报文，从节点执行这些写请求，并增加offset。直到该tcp连接异常断开，转到2（定时任务创建新的连接）

**备份积压缓冲区**

因为是异步拷贝，那么master和slave之间肯定存在一定的偏差。备份积压缓冲区就是保存这个offset里的数据。如果异步拷贝的时候offset大于这个阈值，psync的追加将会失败，需要重新同步完整的RDB。

> 考虑：考虑来不及主从复制，一直超出这个备份积压缓冲区，那么一直会触发RDB，对系统的压力会很高。

## sentinel

sentinel是redis官方高可用方案，从宏观角度看，sentinel提供以下能力。

- 监控： 持续检测主从节点是否正常工作
- 通知： sentinel可以通过调用notification_script向系统管理员报告事件
- 自动故障转移： 如果主节点不能正常工作，sentinel会提升其他从节点为主节点，并通知客户端新主节点的地址。
- 配置提供：告知客户端主节点的地址

### 模拟sentinel故障迁移过程

使用`redis-cli -p 6379 DEBUG sleep 30`模拟主节点宕机三十秒。会出现以下过程

1. 每个sentinel都判定该主节点为+sdown（主观宕机）
2. 最终该主观宕机被确认为+odown（客观宕机）——多个sentinel判定其为主观宕机
3. 一个sentinel被大部分sentinel投票来执行故障迁移
4. 该sentinel执行故障迁移

### SDOWN事件和ODOWN事件

SDOWN是主观宕机，即sentinel自己认为某master宕机。   
ODWON是客观宕机，即大于等于quorum个sentinel都认为该master宕机——此时才可故障。

在sentinel向master发送PING后，超过`is-master-down-after-milliseconds`毫秒仍未收到有效的响应（+PONG、-LOADING、-MASTERDOWN），则sentinel记录master的状态为SDOWN。

从SDOWN到ODOWN状态的转换没有使用强一致性协议，而是一种gossip（流言蜚语）协议——只要一个sentinel被足够数量的sentinel告知master处于SDOWN，则该sentinel标记其为ODOWN，并开始选举从而执行故障迁移。

ODOWN只适用于master，而slave和sentinel节点还有SDOWN状态。**被标记为SDOWN的从节点不会被选举为主节点。**

## 集群模式

分布到16384个slot中，再分配到不同的node中（二次分桶）

gossip协议

PFAIL、FAIL

currentEpoch：执行故障迁移时+1

configEpoch： 用于标记slot分布、主从关系的version，用于网路分区后老主节点恢复连接后的处理

https://www.arloor.com/posts/redis/redis-cluster/

## 分布式寻址

**Hash**

hash算到一个桶

问题是有worker下线时，hash结果会大量迁移

**一致性Hash**

将workers计算hash，放置在hash环中，并增加虚拟节点（用多种方式计算hash）。

将task也计算hash，顺时针在hash环中寻找下一节点。

**二次分桶**

像redis一样，先hash到16384个slot，再将这些slot分布到不同的node