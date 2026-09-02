---
name: opentouryo-config
description: "OpenTouryo の構成ファイルを読み書きする。GetConfigParameter による設定値の取得（GetConfigValue / GetConnectionString / GetAnyConfigValue / GetAnyConfigSection）、net48 の app.config・web.config と net10.0 の appsettings.json の違い、core 系で必須の InitConfiguration、appSettings / connectionStrings セクション、コンテナ・モード（FxContainerization）による環境変数の優先、Fx で始まるフレームワークの設定キー、XML 定義ファイル（SPDefinition / MSGDefinition / SCDefinition / TCDefinition / TMProtocolDefinition / TMInProcessDefinition）を扱う。設定 / 構成ファイル / app.config / web.config / appsettings.json / 接続文字列 / 環境変数 を伴う作業のときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 構成ファイル

> 📋 **コピー元スニペット**：`references/snippets.md`（GetConfigValue/GetConnectionString・Core の InitConfiguration・主要キー。実装時はここから写す）。

## このスキルの適用範囲

設定値の取得と、構成ファイルへの設定の書き方。

ログの設定は `opentouryo-logging`、SQL 定義ファイル（`.sql` / `.xml`）は
`opentouryo-query-definition` を参照（あちらは「設定」ではなくクエリの定義）。

### 外部パラメタの置き場（何をどこに）

| 種類 | 置き場 | 取得 |
| --- | --- | --- |
| 一般設定・接続文字列 | `appSettings` / `connectionStrings`（`app.config`/`web.config`/`appsettings.json`） | `GetConfigValue` / `GetConnectionString`（このスキル） |
| アプリ共通の独自パラメタ（key-value） | 共有情報 `SPDefinition.xml` | `GetSharedProperty.GetSharedPropertyValue`（`opentouryo-shared-property`） |
| 多言語メッセージ | `MSGDefinition.xml` / `.resx` | `opentouryo-message` |

- **★ 設定は基本「起動時に読む／キャッシュ」＝オンライン中の変更は反映されない。** 変更は**再起動**（web.config 変更は IIS がアプリプールを再起動）、無停止なら**ローリング・アップグレード**で運用する。
  （`appsettings.json` の `reloadOnChange` はあるが、`GetConfigParameter` は `InitConfiguration` 時の構成を使うため、Fx 系設定は起動時前提で設計する。）

## GetConfigParameter が唯一の入り口

`GetConfigParameter`（`Touryo.Infrastructure.Public.Util`）の `static` メソッドを使う。
**`ConfigurationManager` や `IConfiguration` を直接使わない。** ランタイム差とコンテナ・モードを
吸収しているのがこのクラス。

```csharp
using Touryo.Infrastructure.Public.Util;

string path = GetConfigParameter.GetConfigValue("FxLog4NetConfFile");
string conn = GetConfigParameter.GetConnectionString("ConnectionString_SQL");
```

| メソッド | 読む場所 | net48 | net10.0 |
| --- | --- | --- | --- |
| `GetConfigValue(key)` | `appSettings` セクション | ○ | ○ |
| `GetConnectionString(key)` | `connectionStrings` セクション | ○ | ○ |
| `GetAnyConfigValue(key)` | 任意のキー（`:` 区切りで階層指定） | **✗** | ○ |
| `GetAnyConfigSection(key)` | 任意のセクション（`IConfigurationSection`） | **✗** | ○ |

`GetAnyConfigValue` / `GetAnyConfigSection` は **core 系専用**。net48 向けのコードで使うと
コンパイルできない（`#if` で切られている）。両対応のコードでは
`GetConfigValue` / `GetConnectionString` だけを使う。

## ランタイムによる違い

**設定の置き場所が根本的に違う。** 読み出す API は同じでも、書く先が違う。

| | net48 | net10.0 |
| --- | --- | --- |
| 構成ファイル | `app.config` / `web.config` | `appsettings.json` |
| 内部で使うもの | `ConfigurationManager` | `IConfiguration` |
| 初期化 | 不要 | **`InitConfiguration()` が必須** |
| XML 定義ファイル | 変わらない | 変わらない |

### core 系では InitConfiguration が必須

**`InitConfiguration()` を呼ぶ前に設定値を取ると `ArgumentException` になる。**

```
NOT_INITIALIZED : InitConfiguration method is not called.
```

アプリケーションの起動時に一度呼ぶ。オーバーロードは4つ。

```csharp
GetConfigParameter.InitConfiguration();                    // カレントの appsettings.json
GetConfigParameter.InitConfiguration("appsettings.json");  // ファイル名を指定
GetConfigParameter.InitConfiguration(configuration);       // 既存の IConfiguration を渡す
GetConfigParameter.InitConfiguration(builder);             // IConfigurationBuilder から
```

ASP.NET Core アプリでは、ホストが構築した `IConfiguration` を渡すのが素直。

### appsettings.json でも appSettings / connectionStrings

**JSON でも `appSettings` / `connectionStrings` というセクション名を使う。**
`GetConfigValue` は `appSettings:` を、`GetConnectionString` は `connectionStrings:` を
キーの前に付けて読むため、このセクション名でないと取得できない。

```json
{
  "connectionStrings": {
    "ConnectionString_SQL": "Data Source=localhost;Initial Catalog=Northwind;..."
  },
  "appSettings": {
    "FxLog4NetConfFile": "C:/root/files/resource/Log/SampleLogConf.xml",
    "FxSqlTraceLog": "on"
  },
  "Logging": {
    "LogLevel": { "Default": "Information" }
  }
}
```

**接続文字列は DBMS ごとに用意する**（`ConnectionString_SQL` / `_ODP` / `_MCN` など）。
どれを使うかは B層呼び出し時の `actionType` の先頭コードで決まる
（既定テンプレートの挙動。`opentouryo-p-call-business` 参照）。上の値・パス（`SampleLogConf.xml` 等）は
**配布サンプルの例。自プロジェクトの設定に読み替える**（`opentouryo-logging`）。

`Logging` のような他のセクションは `GetAnyConfigValue("Logging:LogLevel:Default")` で読む。

## コンテナ・モード

`FxContainerization` を `ON` にすると、**設定ファイルより環境変数を優先する**。

```json
"FxContainerization": "on"
```

| メソッド | 環境変数の名前 | 対応 |
| --- | --- | --- |
| `GetConfigValue(key)` | キーそのまま | ○ |
| `GetConnectionString(key)` | キーそのまま | ○ |
| `GetAnyConfigValue(key)` | `:` を `__` に置換 | ○ |
| `GetAnyConfigSection(key)` | — | **✗ 非対応** |

`GetAnyConfigSection` は `IConfigurationSection` を返す都合で環境変数に対応できない。
コンテナで動かす設定を `GetAnyConfigSection` で読むと、環境変数が効かない。

各メソッドの第2引数 `checkContainerization` を `false` にすると、コンテナ・モードでも
設定ファイルを読む。

```csharp
GetConfigParameter.GetConfigValue("SomeKey", false);   // 環境変数を見ない
```

## フレームワークの設定キー

`Fx` で始まるキーはフレームワークが読む。**アプリケーション独自のキーに `Fx` 接頭辞を付けない。**

### 基盤・DB

| キー | 内容 |
| --- | --- |
| `FxSqlTraceLog` | SQLトレースログの ON / OFF（`opentouryo-logging` 参照） |
| `FxSqlCacheSwitch` | SQL キャッシュ機能の ON / OFF |
| `FxSqlEncoding` | SQL ファイルのエンコーディング |
| `FxSqlCommandTimeout` | `CommandTimeout` 値 |
| `FxSqlDotnetTypeInfo` | パラメタの型推測。`OFF`（既定）＝データプロバイダ固有型 / `ON`＝.NET 汎用型（型・暗黙の型変換は `opentouryo-query-definition`） |
| `FxLog4NetConfFile` | log4net の設定ファイルへのパス |
| `FxExceptionMessageCulture` | 例外メッセージの国際化 |
| `FxContainerization` | コンテナ・モードの ON / OFF |
| `LogLib` | ログ ライブラリの選択（`Fx` 接頭辞が**付かない**） |

### XML 定義ファイル

**ランタイムによらず XML のまま。** `appsettings.json` になっても、これらの定義ファイル自体は
XML で、パスを設定に書く。

**ここで扱うのはパスの設定だけ。** 中身の書き方と使い方は、機能ごとのスキルを参照。

| キー | 定義ファイル | 機能 | スキル |
| --- | --- | --- | --- |
| `FxXMLSPDefinition` | `SPDefinition.xml` | 共有情報取得 | `opentouryo-shared-property` |
| `FxXMLMSGDefinition` | `MSGDefinition.xml` | メッセージ取得 | `opentouryo-message` |
| `FxXMLSCDefinition` | `SCDefinition.xml` | 画面遷移制御 | `opentouryo-screen-transition` |
| `FxXMLTCDefinition` | `TCDefinition.xml` | トランザクション制御 | `opentouryo-transaction-control` |
| `FxXMLTMProtocolDefinition`<br>`FxXMLTMInProcessDefinition` | `TMProtocolDefinition.xml`<br>`TMInProcessDefinition.xml` | 通信制御 | `opentouryo-transmission` |

```json
"FxXMLMSGDefinition": "C:/root/files/resource/XML/MSGDefinition.xml"
```

### P層の設定キー

**P層の `Fx` キーは処理方式ごとに有効・無効が違う。** 使っている P層フレームワークのスキルを
参照する。

| キー | Web Forms | MVC | Windows Forms |
| --- | --- | --- | --- |
| `FxPrefixOf*`（接頭辞） | ○ 14種 | — | ○ 6種 |
| `FxErrorScreenPath` | ○ | ○ | — |
| `FxSessionTimeOutCheck` | ○ | ○ | — |
| `FxScreenTransitionCheck` / `FxScreenTransitionMode` | ○ | — | — |
| `FxDoubleTransmissionCheck` | ○ | — | — |
| `FxRequestTicketGuidMaxQueueLength` | ○ | — | — |
| `FxButtonhistoryMaxQueueLength` | ○ | — | — |
| `FxScreeenGuidMaxQueueLength` / `FxWindowGuidMaxQueueLength` | ○ | — | — |
| `FxOKMessageDialogPath` / `FxYesNoMessageDialogPath` / `FxDialogFramePath` | ○ | — | — |
| `FxCacheControl` | ○ | ○ | — |

画面遷移・ダイアログ・二重送信抑止は **Web Forms 専用**。Windows Forms が使う P層キーは
接頭辞だけ。

**★ P層のセキュリティ/セッション機能のスイッチ**：`FxDoubleTransmissionCheck`＝二重送信防止、
`FxRequestTicketGuidMaxQueueLength`＝不正操作防止（画面単位の操作履歴。0以下で OFF）、
`FxButtonhistoryMaxQueueLength`＝ボタン履歴（0以下で OFF。OFF だと `ButtonID="dummy"`＝`opentouryo-webforms-dialog`）、
`FxScreeenGuidMaxQueueLength`／`FxWindowGuidMaxQueueLength`＝親画面別/ウィンドウ別セッション領域の自動削除。
**Session タイムアウト後も業務を継続させるなら、セッション領域自動削除・ボタン履歴・不正操作防止を OFF にする**
（`opentouryo-auth` のタイムアウト対策）。

### FxPrefixOf* は機能に直結する

**コントロール名の接頭辞でイベントを自動結線する仕組みに使われる。**
未設定だとそのコントロール種別が結線されず、**イベントが発火しない**
（コンパイルエラーにならないので気付きにくい）。

有効な接頭辞は処理方式で違う。詳細は `opentouryo-layer-p-webforms-event`（14種）/
`opentouryo-layer-p-winforms-event`（6種）を参照。MVC は接頭辞の仕組みを使わない。

## やってはいけないこと

- **`ConfigurationManager` / `IConfiguration` を直接使う** — `GetConfigParameter` を経由する。
  直接使うとランタイム差とコンテナ・モードの吸収が効かない
- **core 系で `InitConfiguration()` を呼ばずに設定値を取る** — `ArgumentException`（NOT_INITIALIZED）
- **`appsettings.json` のセクション名を JSON 流に変える** — `appSettings` / `connectionStrings`
  という名前でないと `GetConfigValue` / `GetConnectionString` が読めない
- **net48 対応のコードで `GetAnyConfigValue` / `GetAnyConfigSection` を使う** — core 系専用
- **コンテナで使う設定を `GetAnyConfigSection` で読む** — 環境変数に対応しておらず効かない
- **アプリケーション独自のキーに `Fx` 接頭辞を付ける** — フレームワークの予約
- **接続文字列を `GetConfigValue` で読む** — セクションが違う。`GetConnectionString` を使う
