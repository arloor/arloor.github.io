---
title: "面试：Kafka"
date: 2022-11-28T21:04:01+08:00
draft: false
categories: [ "undefined"]
tags: ["interview"]
weight: 10
subtitle: ""
description : ""
keywords:
- 刘港欢 arloor moontell
---
<!--more-->

## 使用page cache磁盘读写

默认模式下，linux都是使用缓存IO，即将内存作为磁盘的缓存，称之为page cache。当读写文件时，实际是写入内存中的page cache，由操作系统来决定什么时候真正写入磁盘。

这样当我们在无积压的情况下生产和消费时，实际是内存操作，而非磁盘操作。

## 提升效率：batch读写，减少io次数

io操作涉及到系统调用、cpu拷贝、上下文切换等等，网络IO则有rtt的影响，有不小的损耗减少IO的次数是经典的提速方式。

## 提升效率：使用0拷贝技术

kafka使用sendfile的系统调用，只有一次系统调用、两次上下文切换、0次cpu拷贝和2次DMA拷贝（这里指DMA gather copy支持下）。

## 压缩

kafka会对一组消息进行压缩，更多的消息意味着更多重复的字符，意味着更大的压缩比。

## 无路由层设计

不像RabbitMQ设计了exchange交换机，通过binding（路由键）来决定将消息发给哪个queue，Kafka没有路由层，producer直接发送到对应partition的lead broker中。

消息发送到哪个partition可以完全随机，也可以指定part key，也可以重写确定partition的逻辑。

## 异步发送

## Consumer

指定offset来fetch一大段消息。offset完全由consumer记录，broker不记录。而其他大多数消息系统在broker上保存关于consumer消费到哪里的元数据。也就是当broker交给consumer一份数据时，broker立刻记录或收到consumer的ack后记录。

## 静态成员资格

kafka有rebalance-protocal：消费组协调者会将动态的id授予消费组的成员，当消费者重新启动时，会授予新的id——这导致消费会发生漂移（partition-consumer的对应关系变化）。如果不想发生消费漂移，则可以启用 static membership，加一个配置即可:

```plaintext
ConsumerConfig#GROUP_INSTANCE_ID_CONFIG
```

## 推和拉的模式

producer - broker - consumer

producer向broker发送消息时，使用的是push；consumer从broker获取数据使用的是pull——大多数消息系统都是这样。kafka称自己是pull-based，毕竟消费的部分才是重点。

推和拉都有优劣。推的模式下，下游很有可能被生产者压垮。拉的模式下，消费者可以控制消费速率，但是可能产生消息积压（很常见）。所以kakfa增加了一个broker，把所有问题都给broker来抗，简化producer和consumer这两个会出现在业务方代码里的东西。broker模式是一种常见的架构模式，通过borker可以增加可交互性（《软件架构》）

pull-based的另一个好处是拉的consumer可以控制batch。在push-based系统中，producer必须控制是立刻发送消息，还是积累到一定数量（却不知道这个数量会不会压垮下游）。

拉的方式不好的地方在于，如果broker没有数据，consumer还是会进行轮训(busy-waiting)。为了解决这个，consumer的fetch请求中会有参数控制，无数据时block到有数据到达，或者等到有足够多的bytes到达。

## 消息分发保证

基本上有三种消息分发保证：

- 最多一次（可能丢失） —Messages may be lost but are never redelivered.
- 最少一次（可能重复消费） —Messages are never lost but may be redelivered.
- 准确的一次 —this is what people actually want, each message is delivered once and only once.

这个保证可以分为两个问题：发的消息的持久化保证（produce后不会丢），保证会被消费（一定会consume）

kafka的保证是这样的，produce时，消息一旦被标记为“committed”，除非repicate leader的所有broker都挂了，该消息才会完全丢失。（这里涉及的replicate、failover下面会讲）。这又可能存在重复produce的问题：committed响应丢失了，于是producer再生产一条。

在0.11.0.0之后，kafka的producer增加了幂等生产和跨分区原子写入，并基于这两个功能，对kafka stream的read-process-write增加了Exact-Once支持。

**幂等生产**：producer可以修改配置，使重复produce变为幂等的（producer加id，消息增加序列号）。 

**跨分区原子写入**：0.11.0.0之后，同样支持类似事物地将多个消息同时发送到多个partition，要么全部失败，要么全部成功，这用于确保准确地被“处理一次”。当然，producer可以控制是不是要等待committed，毕竟并不是所有场景都要求强持久化保证。

在Kafka stream中可以通过事务保证 准确地被消费一次。kafka stream可以认为是read-process-write：从一个topic消费数据，处理一下，再发送到另一个topic。在这个过程中的能被保证的“Exact-Once”是，我一定能准确地write一次到另一个topic——失败了我就退回consume的offset，直到成功一次。