---
title: "改进布林线量化策略（一）"
date: 2022-05-01T21:45:28+08:00
description: "基于布林线的量化策略"
categories:
  - 宽客
tags:
  - 量化策略
  - freqtrade
  - 布林线
draft: false
---

## 基本概念

**传统布林线**

根据过去m天的指数加权移动平均线（EMA）作为中线，上下边界采用k倍的标准差。

其中k的取值影响了收盘价落在上下通道的概率。

> k = 1.7 分布概率 90% k = 2 分布概率 95% k = 2.3 分布概率 97%

**改进布林线**

中线改用卡夫曼自适应移动均线（AMA），其他概念保持不变。对AMA的描述如下：

> 大部分时间股票市场都会存在明显的噪声交易，这种交易价格偏离均价和当天众数价格，投资者既想避免受噪声交易影响又希望消除长期均线趋势中的滞后特点，考夫曼发明了自适应的均线策略，现在理论中称为卡夫曼自适应移动均线系统，英文缩写为 AMA。当市场趋势趋于快速波动时，AMA使用短周期均线比例大一些来更好的拟合市场均线波动，当市场趋势处于盘整状态时，使用长周期均线比例多一些来拟合市场。

**KDJ**

-   K与D值永远介于0到100之间。当KDJ指标中K值大于80值时、D 值大于 70，J 值大于 100，此时可以认为超买点达到了;K 值小于 20、D 值小于 30、J 值小于 10，这时认为超卖点达到了;
-   当股票价格持续上升时，这时 K 值是小于 D 值，指标中的 K 线向上突 破 D 线时，达到买进条件。当股票价格下降时，指标中的 K 值大于 D 值，K 线继 续向下穿越 D 线时，达到卖出条件;
-   KDJ 指标主要针对一些优质的大盘股，而对于小盘股预测效果不明显， 相对大盘股量能较大，指标指数更容易带起来。

**蒙特卡洛方法**

> 参考：[https://zhuanlan.zhihu.com/p/143016455](https://zhuanlan.zhihu.com/p/143016455)

## 策略调试笔记

> 布林线整体策略应用： (1)价格趋势向下直到下穿上轨线时，此时为买入点，价格趋势由下向上转 到上穿下轨线时，这时可以做多买入;该条使用原则不变。 (2)市场趋势从下向上时，直到穿越卡夫曼自适应均线时，表明市场是买方 强势时，趋势会大概率更快上涨，此时根据资金量可以适当增加仓位; (3)趋势短期或中期处于上轨线、卡夫曼自适应均线、上下轨之间时，此时 多头力量强盛，如果强行进场，风险较大，应该选择观望市场状态。 (4)趋势长期处于上轨线、卡夫曼自适应均线、上下轨之间时，突然从上向 下转变并且下穿到卡夫曼自适应均线之下，这时应该及时止损或者止盈，空出仓 位。 (5)趋势向上时，并且价格上穿卡夫曼自适应均线，这时市场风险加剧，投 资者应该选择卖出一部分仓位股票，趋势进一步向上，上穿上轨线时，此时应该 适当卖出部分仓位股票;

**传统布林线调试**

-   开仓条件：价格上穿下轨时开仓
    
    (dataframe[‘close’] >= dataframe[‘close’].shift()) & # 收盘价趋势向上 (qtpylib.crossed_above(dataframe[‘close’], dataframe[‘bb_lowerband’])) & # 上穿布林线下轨 (dataframe[‘volume’] > 0) # Make sure Volume is not 0
    
-   平仓条件：价格下穿上轨时平仓
    
    (dataframe[‘close’] <= dataframe[‘close’].shift()) & # 收盘价趋势向下 (qtpylib.crossed_below(dataframe[‘close’], dataframe[‘bb_upperband’])) & # 下穿布林线上轨 (dataframe[‘volume’] > 0) # Make sure Volume is not 0
    
-   止损10%
    

调试结果（-3.95%）：

```
=============== SUMMARY METRICS ===============
| Metric                | Value               |
|-----------------------+---------------------|
| Backtesting from      | 2021-05-29 02:30:00 |
| Backtesting to        | 2021-06-20 07:05:00 |
| Max open trades       | 2                   |
|                       |                     |
| Total trades          | 157                 |
| Starting balance      | 1000.000 USDT       |
| Final balance         | 960.524 USDT        |
| Absolute profit       | -39.476 USDT        |
| Total profit %        | -3.95%              |
| Trades per day        | 7.14                |
| Avg. stake amount     | 100.000 USDT        |
| Total trade volume    | 15700.000 USDT      |
```

**改进布林线**

-   开仓条件：价格上穿卡夫曼自适应均线或上穿下轨线时开多
-   平仓条件：价格下穿下轨时平仓
-   止损10%

调试结果（-0.39%）
```
=============== SUMMARY METRICS ===============
| Metric                | Value               |
|-----------------------+---------------------|
| Backtesting from      | 2021-05-29 02:30:00 |
| Backtesting to        | 2021-06-20 07:05:00 |
| Max open trades       | 2                   |
|                       |                     |
| Total trades          | 98                  |
| Starting balance      | 1000.000 USDT       |
| Final balance         | 996.113 USDT        |
| Absolute profit       | -3.887 USDT         |
| Total profit %        | -0.39%              |
| Trades per day        | 4.45                |
| Avg. stake amount     | 100.000 USDT        |
| Total trade volume    | 9800.000 USDT       |
```
