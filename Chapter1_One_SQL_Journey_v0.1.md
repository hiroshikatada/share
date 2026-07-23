# BigQuery Lineage Engine Architecture Overview

## Version 0.1

# Chapter 1 一本のSQLの旅

------------------------------------------------------------------------

# Slide 1

# BigQuery Lineage Engine

## Architecture Overview

### サブタイトル

**カラムレベル影響調査を実現するSQL解析アーキテクチャ**

### このスライドで伝えたいこと

これから一本のSQLを題材にして、BigQuery Lineage Engine
がどのようにSQLを理解し、
最終的にカラムレベルの依存関係を生成するのかを説明します。

------------------------------------------------------------------------

# Slide 2

# 本資料について

本資料は **BigQuery Lineage Engine の設計を理解するための資料** です。

## 本資料で理解できること

-   SQLがどのように解析されるのか
-   各コンポーネントの役割
-   コンポーネント間のデータの流れ
-   なぜこのアーキテクチャになっているのか

------------------------------------------------------------------------

# Slide 3

# 一本のSQLの旅

``` sql
SELECT
    customer_id,
    SUM(amount) AS total_amount
FROM sales
GROUP BY customer_id;
```

``` text
SQL
 ↓
Lexer
 ↓
Parser
 ↓
AST
 ↓
Resolver
 ↓
Repository
 ↓
Impact Analysis
```

------------------------------------------------------------------------

# Slide 4

# SQLはそのまま理解できるのか

SQLは人間には読めますが、コンピュータから見ると単なる文字列です。

------------------------------------------------------------------------

# Slide 5

# Lexer

入力：SQL文字列

出力：Token列

次工程：Parser

## Chapter Review

-   SQLはそのままでは解析できない
-   Lexerは文字列をTokenへ変換する
-   次章でParserを説明する
