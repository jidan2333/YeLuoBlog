---
title: "Sqlalchemy管理回测数据"
date: 2022-05-02T23:16:40+08:00
description: "使用python的ORM框架Sqlalchemy对BTC、ETH的Ticker级数据进行存储和访问，方便回测"
categories:
  - 宽客
tags:
  - 量化框架
  - Sqlalchemy
draft: false
---

## 背景

在进行量化回测的时候发现，需要有一个稳定的历史数据来源，进行策略的回测相关工作，以优化在不同行情下的策略表现。

## Sqlalchemy介绍

Sqlalchemy是 Python 著名的 ORM 工具包。通过 ORM，开发者可以用面向对象的方式来操作数据库，不再需要编写 SQL 语句。参考JAVA开发的JDBC实现，MyBatis和Hibernate等等。

## 编码思路

下面以从binance上爬取BTC/USDT币对的1MIN级Ticker Data举例，说明如何爬取、存储、访问我们获取的OHLCV（open high low close volume）数据。

### 获取BTC/USDT的数据来源

币对（symbol）的OHLCV数据对常见交易所而言，都是公开数据，通常不需要鉴权就可以访问，我们通常直接访问binance的官方API接口就可以查询到指定时间戳范围内的OHLCV数据。

官方接口：[币安API](https://www.binance.com/zh-CN/binance-api)

但可以通过更加偷懒的方式，那就是名为`ccxt`的Python库，关于`ccxt`相关说明本文不详细展开，具体获取指定币对的OHLCV数据的方法如下：

```python
import ccxt
exchange = ccxt.binance()
ohlcv_data = exchange.fetch_ohlcv("BTC/USDT", timeframe="1m", since=start_time, limit=1000)
```

返回的`ohlcv_data`是二级列表，每一条数据依次为，时间戳、open、high、low、close、volume。

### 存入数据库

下面以本人环境Mysql为例，进行数据抓取后的存储。

>注意要安装好mysql驱动的依赖：
>
>pip install pymysql

* 定义表结构

```python
from sqlalchemy import Column, BigInteger, Float, create_engine, desc
from sqlalchemy.orm import declarative_base, sessionmaker

Base = declarative_base()

class Ticker(Base):
    __tablename__ = "BTC_TICKER"

    id = Column(name="id", type_=BigInteger, primary_key=True, autoincrement=True)
    unix = Column(name="unix", type_=BigInteger, unique=True, index=True)
    open = Column(name="open", type_=Float)
    high = Column(name="high", type_=Float)
    low = Column(name="low", type_=Float)
    close = Column(name="close", type_=Float)
    volume = Column(name="volume", type_=Float)

# 下述环境地址按实际情况填写
engine = create_engine(f"mysql+pymysql://{user}:{password}@{mysql_ip}:{mysql_port}/{database}")
# 到这一步完成自动建表
Base.metadata.create_all(engine)
```

* 数据写入

```python
session_class = sessionmaker(bind=engine)
session = session_class()

# 从币安获取到的数据转成Ticker对象列表
ohlcv_objs = [Ticker(unix=d[0], open=d[1], high=d[2], low=d[3], close=d[4], volume=d[5]) for d in ohlcv_data]
# 批量写入
session.add_all(ohlcv_objs)
# 执行事务
session.commit()
# 关闭会话
session.close()
```

## 读取数据

在量化分析场景，通常需要筛选指定时间段的数据，那么可以基于`Ticker`对象的`unix`成员变量进行筛选。

> 由Ticker声明的变量可以知道，unix是唯一索引，这将大幅提升查询结果的速度

查询方法为：

```python
# session构造方式与数据写入的流程类似
# Ticker为上述定义的对象，后面filter接and_方法聚合从start开始从end结束时间的过滤条件
session.query(Ticker).filter(and_(Ticker.unix >= start, Ticker.unix < end)).all()
# 将返回包含Ticker实例化对象的列表，即可按照需求解析读取
```

本人读取的一个完整案例如下：

```python
class MysqlDataFeed:

    # 一次最长查一周数据, ms
    max_search_delta = 86400 * 7 * 1000

    # 查询对象由symbol外部传入，可类似定义ETH、LTC其他币对的类
    def __init__(self, symbol, mysql_ip, mysql_port, user, password, database):
        engine = create_engine(f"mysql+pymysql://{user}:{password}@{mysql_ip}:{mysql_port}/{database}")
        db_session = sessionmaker(bind=engine)
        self.session = db_session()
        self.symbol = symbol

    # 指定查询起止时间
    def query_by_timerange(self, start: datetime, end: datetime):
        logger.info(f"start to search data from {start.isoformat()} to {end.isoformat()}.")
        start_ts = int(start.timestamp() * 1000)
        end_ts = int(end.timestamp() * 1000)

        cursor = start_ts
        result = []
        total_start = time.time()
        total_count = 0
        while cursor < end_ts:
            current_start = cursor
            # 这里限制单次查询最长周期，防止周期过长把数据库搞死
            cursor = min(end_ts, cursor + self.max_search_delta)
            start_time = time.time()
            logger.info(f"search data from {datetime.fromtimestamp(current_start/1000).isoformat()}"
                        f" to {datetime.fromtimestamp(cursor/1000).isoformat()}...")
            batch_result = self.session.query(self.symbol) \
                .filter(and_(self.symbol.unix >= current_start, self.symbol.unix < cursor)).all()
            total_count += len(batch_result)
            logger.info(f"search success, size:{len(batch_result)}, time_cost:{time.time() - start_time}s.")
            result += batch_result
        logger.info(f"search finished, total:{total_count}, time_cost:{time.time() - total_start}s.")
        return result
```

