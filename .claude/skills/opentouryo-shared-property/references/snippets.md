# 共有情報取得 コードスニペット（コピー元）

出典：UserGuide 各機能編 §3、`Framework/Util/GetSharedProperty.cs`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## 取得 API

```csharp
using Touryo.Infrastructure.Framework.Util;

string v = GetSharedProperty.GetSharedPropertyValue("〈共有情報キー〉");
```

## XML 定義（SPDefinition.xml）

`key`（ID）の先頭に数字は使えない。

```xml
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE SPD[
 <!ELEMENT SPD (SharedProp*)>
 <!ELEMENT SharedProp EMPTY>
 <!ATTLIST SharedProp key ID #REQUIRED value CDATA #REQUIRED>
]>
<SPD>
  <SharedProp key="HostName1" value="host-a"/>
  <SharedProp key="HostName2" value="host-b"/>
</SPD>
```

## config パス

```xml
<add key="FxXMLSPDefinition" value="...\SPDefinition.xml"/>
<!-- 埋め込みリソースなら： value="（名前空間）.SPDefinition.xml" -->
```

> `FxXMLSPDefinition` 未指定なら空データで初期化される。メッセージ取得は `opentouryo-message`。
