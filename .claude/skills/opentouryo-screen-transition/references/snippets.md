# 画面遷移制御 コードスニペット（コピー元）

出典：UserGuide 各機能編 §4、実ソースで裏取り。**on-demand 参照**（SKILL 予算外）。ASP.NET Web Forms 専用。

## 遷移 API

```csharp
// 画面遷移制御機能を使う（ラベルで遷移。SCDefinition.xml を引く）
this.ScreenTransition("〈画面遷移ラベル〉");
this.ScreenTransition("〈ラベル〉?aaa=AAA&bbb=BBB");   // Query String 可

// 機能を使わず直接遷移
this.FxTransfer("〈URL〉");    // Server.Transfer（HTTP コンテキストで情報受け渡し）
this.FxRedirect("〈URL〉");    // Response.Redirect（HTTP セッションで情報受け渡し）
```

イベントハンドラは URL を返すと遷移、空文字でポストバック（`opentouryo-layer-p-webforms-event`）。
実際の遷移方式は親クラス2 `UOC_Screen_Transition` が統一（`opentouryo-base2-customize`）。

## XML 定義（SCDefinition.xml）

`directLink`＝Get 直リンク許可(`allow`)/拒否(`deny`)。`mode`＝`T`(Transfer)/`R`(Redirect)。
`CmnTransition`＝どの画面からでも使える共通遷移。

```xml
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE SCD[
 <!ELEMENT SCD (Screen*, CmnTransition*)> <!ELEMENT Screen (Transition*)>
 <!ELEMENT Transition EMPTY> <!ELEMENT CmnTransition EMPTY>
 <!ATTLIST Screen value CDATA #REQUIRED directLink (allow|deny) "allow">
 <!ATTLIST Transition value CDATA #REQUIRED label CDATA #REQUIRED mode (T|R) #IMPLIED>
 <!ATTLIST CmnTransition value CDATA #REQUIRED label ID #REQUIRED mode (T|R) #IMPLIED>
]>
<SCD>
  <Screen value="/Aspx/testScreenCtrl/WebForm0.aspx" directLink="allow">
    <Transition value="/Aspx/testScreenCtrl/WebForm1.aspx" label="0→1" mode="T"/>
    <Transition value="/Aspx/testScreenCtrl/WebForm2.aspx" label="0→2" mode="R"/>
  </Screen>
  <Screen value="/Aspx/testScreenCtrl/WebForm1.aspx" directLink="deny"></Screen>
  <CmnTransition value="/Aspx/start/menu.aspx" label="menu"/>
</SCD>
```

> XML 中の `&` は `&amp;`。`value` は Query String を含められる。

## config

```xml
<add key="FxScreenTransitionMode"  value="off"/>  <!-- T / R / off。off で機能無効 -->
<add key="FxScreenTransitionCheck" value="off"/>  <!-- on で未定義遷移を FrameworkException 拒否 -->
<add key="FxXMLSCDefinition"       value="...\SCDefinition.xml"/>
```
