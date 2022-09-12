---
title: "freqtrade框架的常用命令"
date: 2022-09-12T12:43:46+08:00
description: "freqtrade常用命令集合"
categories:
  - 宽客
tags:
  - 量化框架
  - freqtrade
---

## 常用命令

### 下载回测数据
```shell
python -m freqtrade download-data --days 360 --exchange binance \
                                  -p BTC/USDT -t 5m --userdir wzw
```

### 启动回测
```shell
python -m freqtrade backtesting -s VegasTunnel20220827 \ 
                                -d wzw/data/binance --userdir wzw
```

### 绘图
```shell
python -m freqtrade plot-dataframe -s VegasTunnel20220827 --userdir wzw
```

### 启动dry-run
```shell
python -m python -m freqtrade trade --userdir wzw -s VegasTunnel20220827
```