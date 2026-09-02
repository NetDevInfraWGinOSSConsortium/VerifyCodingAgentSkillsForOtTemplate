# メッセージ取得 コードスニペット（コピー元）

出典：UserGuide 各機能編 §3、`Framework/Util/GetMessage.cs`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## 取得 API

```csharp
using Touryo.Infrastructure.Framework.Util;

string msg = GetMessage.GetMessageDescription("E0001");
// カルチャ指定版もある： GetMessage.GetMessageDescription("E0001", uiCulture)
```

## XML 定義（MSGDefinition.xml）

`id` の先頭に数字は使えない（XML の ID 型）。慣例：先頭 `E`=異常系／`I`=正常系。

```xml
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE MSGD[
 <!ELEMENT MSGD (Message*)>
 <!ELEMENT Message EMPTY>
 <!ATTLIST Message id ID #REQUIRED description CDATA #REQUIRED>
]>
<MSGD>
  <Message id="E0001" description="～エラーメッセージ～"/>
  <Message id="I0001" description="～正常系メッセージ～"/>
</MSGD>
```

## config パス

```xml
<add key="FxXMLMSGDefinition" value="%OT_RESOURCE_ROOT%\Xml\MSGDefinition.xml"/>
<!-- 埋め込みリソースなら： value="（名前空間）.MSGDefinition.xml" -->
```

## `%1` / `%2` 置換の注意

メッセージ雛形の `%1`/`%2` は `GetMessage` ではなく **P層の親クラス2 が置換**（既定では Web Forms の
`MyBaseController` にしか実装が無い）。置換の有無はプロジェクト依存＝`opentouryo-project-policy`。
