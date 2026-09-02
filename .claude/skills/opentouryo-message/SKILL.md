---
name: opentouryo-message
description: "OpenTouryo のメッセージ取得機能を実装する。MSGDefinition.xml に Message 要素で id（メッセージID）と description（メッセージの雛形）を定義し、GetMessage.GetMessageDescription() で取得する。例外の messageID との対応、%1 / %2 プレースホルダに業務例外の Message / Information を埋める方式、カルチャ別ファイル（MSGDefinition_ja-JP.xml）による国際化、FxXMLMSGDefinition / FxExceptionMessageCulture の設定を扱う。メッセージ / メッセージID / MSGDefinition / GetMessage / エラーメッセージ / メッセージ定義 / 国際化 / 多言語 を伴う作業のときに使う。例外の型は opentouryo-exception を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# メッセージ取得機能

> 📋 **コピー元スニペット**：`references/snippets.md`（GetMessageDescription・MSGDefinition.xml・%1/%2。実装時はここから写す）。

## このスキルの適用範囲

`MSGDefinition.xml` の書式と `GetMessage` の呼び出し。

例外の型と処理方式は `opentouryo-exception` を参照。

## 何のための機能か

**メッセージ本文をコードから追い出し、メッセージID で引けるようにする。**
例外の `messageID` と対応させることで、**例外の型を増やさずにエラーの種類を識別できる**
（`opentouryo-exception` 参照）。

### 例外メッセージには事前定義の系統もある

`MSGDefinition.xml` は**開発者がプロジェクト進行中に採番していく**メッセージ。
これとは別に、**纏め者が事前定義する** `MyBusinessApplicationExceptionMessage` /
`MyBusinessSystemExceptionMessage`（`.resx` リソース。国際化対応）がある。

**競合ではなく住み分け。** 基盤として先に用意されたものは再定義せず使い、
新しいエラーは `MSGDefinition.xml` に採番する。事前定義に何があるかは
`opentouryo-project-policy` で確認する。

## 定義ファイル

パスは `appSettings` の **`FxXMLMSGDefinition`** で指定する（`opentouryo-config` 参照）。
**ランタイムによらず XML のまま**（`appsettings.json` になっても、この定義ファイルは XML）。

**定義例（DTD 埋め込み・`Message` の `id`/`description`・先頭 E=異常系/I=正常系）は `references/snippets.md`。** 要素・属性は下表。

| 要素・属性 | 内容 |
| --- | --- |
| ルート要素 | `MSGD` |
| `Message` の `id` | メッセージID。**XML の `ID` 型** |
| `Message` の `description` | メッセージの雛形 |

### id の先頭に数字を使えない

`id` は XML の `ID` 型なので、**先頭に数字を使えない**（`0001` は不可、`E0001` は可）。

`I` = 正常系、`E` = 異常系という接頭辞は**慣例**で、フレームワークは解釈しない。

### DTD を省かない

**DTD を埋め込んだ形式。** 他の OpenTouryo の XML 定義ファイルと共通の作法。

## 取得する

```csharp
using Touryo.Infrastructure.Framework.Util;

string msg = GetMessage.GetMessageDescription("E0001");
```

## %1 / %2 は例外のフィールドで置換される

**`GetMessage` は置換しない。** 置換するのは P層の親クラス2。

| プレースホルダ | 置換される値 |
| --- | --- |
| `%1` | 業務例外の `Message`（可変文字列） |
| `%2` | 業務例外の `Information`（エラー情報） |

```csharp
// MyBaseController（Web Forms の親クラス2）の UOC_ABEND での実装
messageDescription = messageDescription.Replace("%1", baEx.Message);
messageDescription = messageDescription.Replace("%2", baEx.Information);
```

つまり**例外の `Message` は「完成した文」ではなく「雛形に埋める可変部分」**として使う。

```csharp
// MSGDefinition.xml: <Message id="E0001" description="○△□エラー、%1が%2しました。"/>
throw new BusinessApplicationException("E0001", "受注番号", "重複");
// → 「○△□エラー、受注番号が重複しました。」
```

### この方式は強制ではない

**置換を実装しているのは Web Forms の親クラス2（`MyBaseController`）だけ。**
MVC / Core MVC / リッチクライアントの親クラス2 にはこの処理が無い。実装コメントにも
`// 方式は、プロジェクト毎に検討のこと。` とある。

**雛形＋可変文字列の方式を採るかは、使っているプロジェクトの親クラス2 の実装次第。**
利用側では変えられないので、既存の実装に合わせる。

**`%1`/`%2` を書く前に、このプロジェクトの親クラス2 が置換を行うかを確認すること**
（確認方法は `opentouryo-project-policy`）。**置換されないのに `%1` を書くと、そのまま画面に出る。**

**★ 確認できないとき（親クラス2 がバイナリのみ・質問相手も居ない自動実行など）の安全な既定＝`%1`/`%2` を使わず完成文で定義する。**
置換の有無に依らず正しく表示される（可変値は呼び出し側で文に組み込む）。確認不能時のフォールバックの考え方は `opentouryo-project-policy`。

## カルチャ別ファイルで国際化する

`FxExceptionMessageCulture` 設定と連動し、**ファイル名にカルチャ名を挟んだファイル**を探す。

```
MSGDefinition.xml          ← 既定
MSGDefinition_ja-JP.xml    ← ja-JP のとき
```

命名は `（ファイル名）_（カルチャ名）.xml`。

```csharp
string msg = GetMessage.GetMessageDescription("E0001", new CultureInfo("ja-JP"));
```

## やってはいけないこと

- **`id` の先頭に数字を使う** — XML の `ID` 型なので不正。`E0001` のように英字で始める
- **DTD を省く** — 埋め込み形式が前提
- **例外の `Message` に完成した文を入れる（雛形を使うプロジェクトで）** — `%1` に埋める
  可変部分として使う
- **`%1` / `%2` を `GetMessage` が置換すると考える** — 置換するのは P層の親クラス2。
  しかも Web Forms のテンプレートにしか実装が無い
- **`FxXMLMSGDefinition` の設定を忘れる** — パスを設定しないとファイルが読まれない
- **この XML を `appsettings.json` に移そうとする** — ランタイムによらず XML のまま
