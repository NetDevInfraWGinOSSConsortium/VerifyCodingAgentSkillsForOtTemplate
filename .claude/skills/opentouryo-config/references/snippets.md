# コンフィグ取得 コードスニペット（コピー元）

出典：UserGuide 纏め者編 §1／共通編、`Public/Util/GetConfigParameter.cs`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## 取得 API

```csharp
using Touryo.Infrastructure.Public.Util;

string v    = GetConfigParameter.GetConfigValue("キー");             // appSettings
string conn = GetConfigParameter.GetConnectionString("ConnectionString_SQL"); // connectionStrings
```

## Core 系（net10.0）の必須初期化

```csharp
// Core は使用前に InitConfiguration() が必要（呼ばないと ArgumentException）
GetConfigParameter.InitConfiguration();
// Core 専用：GetAnyConfigValue / GetAnyConfigSection もある
```

## appSettings の主なキー

```xml
<!-- コントロール接頭辞（P層イベント自動結線） -->
<add key="FxPrefixOfButton" value="btn"/>
<add key="FxPrefixOfTextBox" value="txt"/>
<!-- 機能の ON/OFF -->
<add key="FxSessionTimeOutCheck" value="on"/>
<add key="FxDoubleTransmissionCheck" value="on"/>
<add key="FxButtonhistoryMaxQueueLength" value="20"/>   <!-- 0以下=OFF。off だと ButtonID が "dummy" -->
<!-- D層 -->
<add key="FxSqlTraceLog" value="on"/>
<add key="FxSqlCacheSwitch" value="off"/>
<add key="FxSqlEncoding" value="shift_jis"/>
<add key="FxSqlCommandTimeout" value="30"/>
<!-- 各定義ファイルへのパス -->
<add key="FxXMLMSGDefinition"  value="..."/>
<add key="FxXMLSCDefinition"   value="..."/>
<add key="FxXMLTCDefinition"   value="..."/>
<add key="FxXMLTMProtocolDefinition"  value="..."/>
<add key="FxXMLTMInProcessDefinition" value="..."/>
<!-- SQL フォルダ -->
<add key="SqlTextFilePath" value="..."/>
```

## 接続文字列（connectionStrings）

```xml
<add name="ConnectionString_SQL"  connectionString="Data Source=localhost;Initial Catalog=Northwind;User ID=sa;Password=...;Encrypt=false;" />
<add name="ConnectionString_ODP"  connectionString="User Id=SCOTT;Password=tiger;Data Source=localhost/XE;" /> <!-- Oracle -->
<add name="ConnectionString_MCN"  connectionString="Server=localhost;Database=test;User Id=root;Password=...;" /> <!-- MySQL -->
```

> パスは機微情報の平文回避（環境変数方式 `%OT_RESOURCE_ROOT%\...`）＝`opentouryo-project-setup-config`。
> web.config/app.config の二段構成・キー一覧の詳細は SKILL 本文。
