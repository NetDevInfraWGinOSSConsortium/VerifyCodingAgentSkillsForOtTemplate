---
name: opentouryo-logging
description: "OpenTouryo のログ出力を実装する。LogIF による出力（DebugLog / InfoLog / WarnLog / ErrorLog / FatalLog）、ロガー名（ACCESS / SQLTRACE / OPERATION / SERVICE-IF）の使い分け、フレームワークが自動出力するアクセスログとSQLトレースログ、log4net と NLog の切り替え（LogLib）、FxLog4NetConfFile / FxSqlTraceLog の設定、IsDebugEnabled 等によるログレベル判定を扱う。ログ / ロギング / ログ出力 / LogIF / log4net / NLog / アクセスログ / SQLトレース を伴う作業のときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# ログ出力

> 📋 **コピー元スニペット**：`references/snippets.md`（LogIF API・標準ロガー・log4net アペンダ。実装時はここから写す）。

## このスキルの適用範囲

アプリケーションからのログ出力と、フレームワークが自動出力するログの理解。

構成ファイルの読み方全般は `opentouryo-config`、例外時のログは `opentouryo-exception` を参照。
**出たログ（ACCESS/SQLTRACE 等）を分析して障害・性能の対応を提案するのは `opentouryo-log-analysis`。**

## LogIF が唯一の入り口

`LogIF`（`Touryo.Infrastructure.Public.Log`）の `static` メソッドを呼ぶ。
**log4net や NLog を直接使わない。**

```csharp
using Touryo.Infrastructure.Public.Log;

LogIF.InfoLog("OPERATION", "受注を登録した。受注ID=" + orderId);
```

シグネチャはすべて `(string loggerName, string message)`。

| メソッド | レベル |
| --- | --- |
| `LogIF.DebugLog(ロガー名, メッセージ)` | DEBUG |
| `LogIF.InfoLog(ロガー名, メッセージ)` | INFORMATION |
| `LogIF.WarnLog(ロガー名, メッセージ)` | WARNING |
| `LogIF.ErrorLog(ロガー名, メッセージ)` | ERROR |
| `LogIF.FatalLog(ロガー名, メッセージ)` | FATAL |

## ロガー名

**第1引数のロガー名は文字列で指定する。定数は用意されていない。**
綴りを間違えても**コンパイルは通り、実行時にも例外にならない**（設定にないロガーへ出力される）。
既存コードからコピーするか、ここの表と照合すること。

| ロガー名 | 何のログか | 誰が出すか |
| --- | --- | --- |
| `ACCESS` | アクセスログ。処理の入り／出、処理時間、エラー情報 | **フレームワーク**（親クラス2） |
| `SQLTRACE` | SQLトレースログ。実行した SQL と処理時間 | **フレームワーク**（`MyBaseDao`） |
| `OPERATION` | 業務操作ログ | **アプリケーション**（開発者） |
| `SERVICE-IF` | サービス インターフェイスのログ | **フレームワーク**（Web サービス / WCF） |

### 開発者が書くのは `OPERATION`

`ACCESS` / `SQLTRACE` / `SERVICE-IF` はフレームワークが自動で出す。**業務コードから出力しない。**
業務上の操作を記録したいときは `OPERATION` を使う。

```csharp
LogIF.InfoLog("OPERATION", "受注を登録した。受注ID=" + orderId);
```

**書式はプロジェクトの運用ルール。** フレームワークは `OPERATION` を出力しないため、
コードから読み取れる雛形が存在しない（`ACCESS` / `SQLTRACE` はカンマ区切りだが、
それに倣うかも含めて決めごと）。**勝手に決めず纏め者に確認する**
（→ `opentouryo-project-policy`）。既存の `OPERATION` 出力があれば、それに合わせる。

## フレームワークが自動出力するログ

**業務コードで書く必要はない。** 書式は親クラス2（`MyFcBaseLogic`）と `MyBaseDao` の
`UOC_` メソッドで決まっている。**親クラス2 はバイナリで提供されるため、
ユーザプログラム開発プロジェクトでは書式を変更できない。**

### アクセスログ（ACCESS）

カンマ区切りで以下を出力する。

```
ユーザ名, IPアドレス, レイヤ, 画面名, コントロール名, メソッド名, 処理名,
処理時間（実行時間）, 処理時間（CPU時間）, エラーメッセージID, エラーメッセージ
```

**「レイヤ」列は矢印記号で、どの層の入り／出かを表す。** 入れ子の深さが層の深さに対応する。

| 記号 | 意味 |
| --- | --- |
| `----->` | P層に入る |
| `----->>` | B層に入る |
| `<<-----` | B層から出る |
| `<-----` | P層から出る |

出力タイミングは `UOC_PreAction`（入り）、`UOC_AfterAction`（出）、`UOC_ABEND`（異常時）。

### SQLトレースログ（SQLTRACE）

`MyBaseDao.UOC_AfterQuery` が出力する。書式は以下。

```
処理時間（実行時間）, 処理時間（CPU時間）, 実行したSQL
```

**`FxSqlTraceLog` 設定で on / off を切り替える。**

```json
"FxSqlTraceLog": "on"
```

未設定なら出力しない。`on` / `off` 以外の値を書くと **`ArgumentException`（書式不正）**になる。
大文字小文字は区別しない。

## ログ ライブラリの切り替え

`LogLib` 設定（config キーは `"LogLib"`。`LogIF.cs`）で log4net と NLog を切り替える。

| `LogLib` の値 | 使われる実装 |
| --- | --- |
| 未設定 | log4net |
| `nlog` | NLog |
| 上記以外 | log4net |

判定は小文字化して比較するので `NLog` でも `nlog` でもよい。

**★ 方針：公式は NLog への移行を推奨**（log4net は本家の開発休止で将来廃止予定）。**新規プロジェクトは `LogLib=nlog`** を既定にする。既存の log4net もそのまま動く（`LogIF` の API は共通なので**業務コードは無変更**、切り替えは config と設定ファイルの差し替えだけ）。

**設定ファイルのパスは log4net/NLog とも同じキー `FxLog4NetConfFile`** で指す（NLog も実ソースでこのキーを読む）。
違うのは**中身のフォーマット**。雛形が `root\files\resource\Log` にある：**`Log4NetConfigTemplate.xml`（log4net）／
`NLogConfigTemplate.xml`（NLog）**。`SampleLogConf.xml` はサンプルの実 log4net 設定＝自プロジェクトの設定に読み替える。

```json
"FxLog4NetConfFile": "%OT_RESOURCE_ROOT%/Log/SampleLogConf.xml"
```

設定ファイル側で、ロガー名ごとに appender（出力先）とレベルを定義する。
`LogIF` に渡すロガー名と、設定ファイルの `<logger name="...">` が対応する。

**設定ファイル「の中」の出力先パス**を可搬にする（`%OT_RESOURCE_ROOT%` は中身では展開されないため、**log4net＝`PatternString` の `%env{OT_RESOURCE_ROOT}`／
NLog＝`${OT_RESOURCE_ROOT}`** を使う）方法は `opentouryo-project-setup-config`（`references/resource-config.md`）。出力先が旧パスのままでも起動はする。

## ログレベルで処理を分岐する

メッセージの組み立てが重い場合は、出力されるか先に判定する。

```csharp
if (LogIF.IsDebugEnabled("OPERATION"))
{
    LogIF.DebugLog("OPERATION", 重い処理でメッセージを組み立てる());
}
```

`IsDebugEnabled` / `IsInfoEnabled` / `IsWarnEnabled` / `IsErrorEnabled` / `IsFatalEnabled` があり、
いずれも引数はロガー名。

## イベントログ

Windows イベントログへ出力するクラスもある。通常のログ出力には使わない。

| クラス | 用途 |
| --- | --- |
| `CustomEventLog` | カスタム イベント ログ出力 |
| `SecurityEventLog` | セキュリティ イベント ログ出力 |

**どういう場面でイベントログへ出すかはプロジェクトの運用ルール。**
フレームワークもテンプレートも使いどころを定めていないので、コードから読み取れない。
**自分で判断せず纏め者に確認する**（→ `opentouryo-project-policy`）。

## やってはいけないこと

- **log4net / NLog を直接使う** — `LogIF` を経由する。直接使うと `LogLib` による切り替えが効かない
- **業務コードから `ACCESS` / `SQLTRACE` / `SERVICE-IF` へ出力する** — フレームワークが出す。
  業務操作の記録は `OPERATION`
- **ロガー名をタイポする** — 定数がなく、コンパイルも実行時チェックも通らない。
  設定にないロガーへ出力され、ログが消える
- **`FxSqlTraceLog` に `on` / `off` 以外を書く** — `ArgumentException` になる
- **本番で `FxSqlTraceLog` を `on` のままにする** — 全 SQL が出力され、性能とログ量に影響する
- **重いメッセージ組み立てを `IsXxxEnabled` なしで書く** — 出力されなくても組み立てコストは掛かる
