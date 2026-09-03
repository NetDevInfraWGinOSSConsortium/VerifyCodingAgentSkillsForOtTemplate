---
name: opentouryo-layer-p-webforms-event
description: "OpenTouryo の P層（ASP.NET Web Forms）でコントロールのイベント処理を実装する。コントロール名の接頭辞（FxPrefixOfButton = btn 等）によるイベントの自動結線、種別ごとに決まるハンドラのイベント名（ボタン=Click / テキストボックス=TextChanged / ドロップダウン=SelectedIndexChanged / チェックボックス=CheckedChanged など）、UOC メソッドの命名規約（コンテンツページ / マスタページ / Web ユーザコントロールで変わる）、protected string ...(FxEventArgs) のシグネチャ、GridView の EventArgs 追加引数、FxEventArgs のプロパティ、対応コントロールの拡張と未対応時のトレードオフを扱う。イベントハンドラ / ボタン / 接頭辞 / 自動結線 / UOC_btnXXX_Click / ポストバック / コントロール を伴う作業のときに使う。画面の新規作成は opentouryo-layer-p-webforms-screen、ハンドラ内での B層呼び出しは opentouryo-p-call-business を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# P層（Web Forms）：イベント処理の実装

> 📋 **コピー元スニペット**：`references/snippets.md`（UOC 命名表・シグネチャ・GridView 2引数・FxEventArgs プロパティ。実装時はここから写す）。

## このスキルの適用範囲

**コントロールのイベントハンドラ（UOC メソッド）を実装する。**

- 画面の新規作成 → `opentouryo-layer-p-webforms-screen`
- ハンドラの中身（B層の呼び出し）→ `opentouryo-p-call-business`
- 例外 → `opentouryo-exception`

## イベントは接頭辞で自動結線される

**これが Web Forms 版の中核。コントロール名の接頭辞は命名規約ではなく機能そのもの。**

```
設定ファイルから接頭辞を読む（FxPrefixOfButton = "btn" など）
  → 「接頭辞 → フレームワークのイベントハンドラ」の対応表を作る
  → コントロールツリーを走査し、ID が接頭辞で始まるコントロールにハンドラを結線
  → ハンドラが UOC_（コントロール名）_（イベント名）へレイトバインドする
```

**`.aspx` に `OnClick` を書かない。** フレームワークが結線する。

```xml
<%@ Register Assembly="OpenTouryo.CustomControl"
             Namespace="Touryo.Infrastructure.CustomControl" TagPrefix="cc1" %>

<!-- OnClick は書かない。ID の接頭辞 btn が結線を決める -->
<cc1:WebCustomButton ID="btnButton1" runat="server" Text="検索" />
```

> **★ コードビハインドで `ListItem` は完全修飾する（`CS0104`）。** `.cs` に `using Touryo.Infrastructure.CustomControl;` があると `new ListItem(...)` が **`CustomControl.ListItem` と `System.Web.UI.WebControls.ListItem` のあいまい参照**になる（DDL にマスタをバインドする画面で必ず出る）＝**`new System.Web.UI.WebControls.ListItem(...)`** と書く。

## 接頭辞の一覧とイベント名

**接頭辞は設定ファイル（`app.config` の `appSettings`）で定義する。**
未設定の種類は**結線されない**（`if (!string.IsNullOrEmpty(prefix))` で分岐している）。
＝**接頭辞を空指定にすれば、その種別の P層イベント処理を止められる**（機能のキャンセル）。
結線はページのコントロールツリーを**再帰走査**して行うので、**動的に生成したコントロール**も規約に沿えば結線される。

**ハンドラ名のイベント名は、コントロール種別ごとに決まっている**（右列）。
`_Click` はボタン系だけ。他は種別ごとに違うので、間違えると結線されない。

| 設定キー | サンプルでの値 | コントロール | ハンドラのイベント名 |
| --- | --- | --- | --- |
| `FxPrefixOfButton` | `btn` | ボタン | `Click` |
| `FxPrefixOfLinkButton` | `lbn` | リンクボタン | `Click` |
| `FxPrefixOfImageButton` | `ibn` | イメージボタン | `Click` |
| `FxPrefixOfImageMap` | `imp` | イメージマップ | `Click` |
| `FxPrefixOfTextBox` | `txt` | テキストボックス | `TextChanged` |
| `FxPrefixOfDropDownList` | `ddl` | ドロップダウンリスト | `SelectedIndexChanged` |
| `FxPrefixOfListBox` | `lbx` | リストボックス | `SelectedIndexChanged` |
| `FxPrefixOfRadioButton` | `rbn` | ラジオボタン | `CheckedChanged` |
| `FxPrefixOfRadioButtonList` | `rbl` | ラジオボタンリスト | `SelectedIndexChanged` |
| `FxPrefixOfCheckBox` | `cbx` | チェックボックス | `CheckedChanged` |
| `FxPrefixOfCheckBoxList` | `cbl` | チェックボックスリスト | `SelectedIndexChanged` |
| `FxPrefixOfRepeater` | `rpt` | リピータ | `ItemCommand` |
| `FxPrefixOfGridView` | `gvw` | グリッドビュー | `RowCommand` / `SelectedIndexChanged` / `RowUpdating` / `RowDeleting` / `PageIndexChanging` / `Sorting` |
| `FxPrefixOfListView` | `lvw` | リストビュー | `OnItemCommand` / `SelectedIndexChanged` / `ItemUpdating` / `ItemDeleting` / `PagePropertiesChanged` / `Sorting` |

例：`ddl` のドロップダウンリスト `ddlKind` なら `UOC_ddlKind_SelectedIndexChanged`。
`txt` のテキストボックスなら `UOC_txtName_TextChanged`。

**値はプロジェクトごとに変えられる。** 上記はサンプルの値。既存コードと設定ファイルを確認する。

**一覧は「フレームワーク既定」であって、このプロジェクトの全部とは限らない。**
対応コントロール・イベントは `MyBaseController`（親クラス2）の `addControlEvent` に実装を足せば
拡張できる（`CheckBox` 自体がその方法で親クラス2 に追加された実例）。**拡張するのは纏め者**で、
利用側は既存の対応を使う。このプロジェクトで何に対応しているかは、提供されていれば
`MyBaseController` の `addControlEvent` を読んで確認する（`opentouryo-project-policy`）。

**対応していないコントロール・イベントは、.NET 標準のイベント処理（`.aspx` の `OnClick`、
コードビハインドの `+=`）でも書ける。ただしその場合、フレームワークの例外処理
（`UOC_ABEND` による振替・共通エラー画面）とアクセスログ出力を通らない。**
土台に載せたいなら、親クラス2 での拡張（纏め者）を検討する。

`FxPrefixOfComboBox` / `FxPrefixOfPictureBox` はリッチクライアント専用で、**Web Forms では
結線されない**（`opentouryo-layer-p-winforms-event` 参照）。`FxPrefixOfCommand` は定数が定義
されているだけで、実装では使われていない（ASP.NET Mobile Web の名残と見られる）。

<!--
  結線箇所は2つに分かれている（実装で確認済み）:
    BaseController（親クラス1）  … 上表のうち CheckBox 以外の13種
    MyBaseController（親クラス2）… CHECK_BOX（MyLiteral.PREFIX_OF_CHECK_BOX）
  親クラス2 で接頭辞を追加できる作りだが、バイナリ提供のため利用側では変更できない。
  PREFIX_OF_COMMAND は FxCmnFunction.cs:218,486 にコメントアウトで残っているのみ。
-->

## イベントハンドラの命名規約

**コントロールがどこに置かれているかで名前が変わる。**

| コントロールの位置 | ハンドラ名 | 実装先 |
| --- | --- | --- |
| コンテンツページ上 | `UOC_（コントロール名）_（イベント名）` | 画面コードクラス（`MyBaseController` 派生） |
| マスタページ上 | `UOC_（マスタページのファイル名）_（コントロール名）_（イベント名）` | **画面コードクラス**（名前はマスタ名だが実装はコンテンツ側）／またはマスタページ側なら接頭辞なし |
| Webユーザコントロール上 | `UOC_（ユーザコントロールのID）_（コントロール名）_（イベント名）` | 画面コードクラス／または UC 側なら接頭辞なし |

`（イベント名）` はコントロール種別で決まる（上の接頭辞の表）。

**★ 接頭辞は「マスタページの `.master` ファイル名」。コンテンツ `.aspx` の名前ではない。** マスタとコンテンツが
同名（例：`sampleScreen.master` と `sampleScreen.aspx` が両方ある）だと取り違えやすいが、**マスタ上ボタンの接頭辞は
必ずマスタ名**。具体例（`UOC_TestScreen_btnMasterIdvdl_Click` 等）は `references/snippets.md`。

同じユーザコントロールを2つ置いた場合、**ID が違えばハンドラも別**になる
（`UOC_sampleControl1_btnUCButton_Click` と `UOC_sampleControl2_btnUCButton_Click`）。

## シグネチャ

```csharp
protected string UOC_（コントロール名）_（イベント名）(FxEventArgs fxEventArgs)
```

| 要素 | 決まり |
| --- | --- |
| アクセス修飾子 | `protected`。**`private` にすると呼ばれない** |
| 戻り値 | `string`。**遷移先 URL**（`FxScreenTransitionMode=T`/`R` のときは代わりに**遷移ラベル**＝`opentouryo-screen-transition`）。遷移しないなら `string.Empty` を返す |
| 引数 | `FxEventArgs` |

GridView の `RowUpdating` / `RowDeleting` / `PageIndexChanging` / `Sorting` だけ、
オリジナルの `EventArgs` も取る。

```csharp
protected string UOC_gvwGridView_RowUpdating(FxEventArgs fxEventArgs, EventArgs e)
```

**レイトバインドで呼ばれるため、シグネチャが違っても、修飾子が `private` でも、
コンパイルは通り実行時に呼ばれないだけ。**

**★ 対応する UOC メソッドがどこにも無いボタンは、押しても何も起きない（無視）＝例外にならない。**
フレームワークは呼ぶ前に存在確認する（`Latebind.CheckTypeOfMethodByName` でコンテンツ→マスタ→ユーザコントロールを探索。
呼び出しも `InvokeMethod_NoErr`）。**→ マスタ上の未使用ボタンに空の UOC を書く必要はない**（未実装でも押下は無害な postback）。

### 一覧表示系（GridView / ListView / Repeater）の実装

`DataTable` をバインドするグリッド系の **`.aspx` ＋ コードビハインドの実装**（バインド・編集/更新/削除・行内コントロール取得・
全行走査・第2引数の EventArgs 型）は `references/snippets.md` に**系統別・同レベルでまとめてある**（実サンプル `testFxLayerP/table` で裏取り）：
**[GridView](references/snippets.md#gridview)** ／ **[ListView](references/snippets.md#listview)** ／ **[Repeater](references/snippets.md#repeater)**。

先に要点だけ：

- キー列は **`DataKeyNames`** に指定し `DataKeys[index].Value` で取る。★ **GridView は `e.RowIndex`／ListView は `e.ItemIndex`**。
  **★ ただしバッチ更新（`DataTable` の RowState）では例外**：追加行の主キーが未採番＝`DBNull` で `DataKeyNames` が成立せず、
  `Deleted` 行がグリッドから外れて index もずれる → DataRow 側で対応付ける（`opentouryo-batch-update`）。
- 削除・コマンド用の `<asp:LinkButton CommandName="Delete">` など**動的コマンドボタンを使うページは `@Page` に `EnableEventValidation="false"`**。
- 行内コントロールは `fxEventArgs.PostBackValue`（＝アイテムの index）→ `Items[index].FindControl("id")`。
- **★ グリッド／テンプレート内のコントロールには自動結線の接頭辞（`txt`／`lbn` 等）を付けない。** 接頭辞は機能なので、
  付けると行ごとに `TextChanged`／`Click` 等が**不要に自動結線される**。行内コントロールは接頭辞なしの名前にし、値は `FindControl("ID")` で取る
  （グリッド自身は `gvw` 等が付くので `RowCommand` は結線される。使わないなら空実装を置く）。

### FxEventArgs

| プロパティ | 内容 |
| --- | --- |
| `ButtonID` | イベントに関係付けられているコントロール名 |
| `InnerButtonID` | リピータ等の内部に配置されたコントロール |
| `MethodName` | レイトバインドに使ったメソッド名 |
| `X` / `Y` | イメージボタンの座標 |
| `PostBackValue` | イメージマップのホットスポット値／**一覧表示系コントロールではアイテムの index** |

## ハンドラの中身は B層呼び出し

**イベントハンドラの本体は、たいてい引数クラスを組み立てて B層を呼ぶ。**
手順は `opentouryo-p-call-business`。

```csharp
protected string UOC_btnButton1_Click(FxEventArgs fxEventArgs)
{
    // 引数クラスを組み立てて B層を呼ぶ（→ opentouryo-p-call-business）
    // 業務例外は戻り値の ErrorFlag で受ける（→ opentouryo-exception）
    return string.Empty;   // 遷移しないなら空文字列
}
```

## グリッド系に DataTable をバインドして一括更新するなら

データバインド系コントロール（**`GridView` / `ListView` / `Repeater` / `DataList`**）に `DataTable` をバインドして
明細を編集し、まとめて反映する構成は **`opentouryo-batch-update`**（`DataRow` の `RowState` で INSERT/UPDATE/DELETE を
振り分け・楽観排他）。一般的な仕様＝**グリッド外の [追加] ボタンで空行（Added）、グリッド内の [削除]（`GridView` なら
`RowDeleting` 等）で `dr.Delete()`（Deleted）、セル編集（Modified）**。`GridView`/`ListView`/`Repeater` のイベント自体は
上の接頭辞で自動結線される（`DataList` は自動結線外＝ボタンで扱う）。

## やってはいけないこと

- **対応済みのコントロールを `.aspx` の `OnClick` 等で結線する** — フレームワークが接頭辞で
  自動結線する。標準結線するとフレームワークの例外処理・ログを通らない（未対応の場合のみ、
  失うものを承知で使う）
- **接頭辞の規約から外れたコントロール名を付ける** — 命名規約ではなく機能。
  結線されずイベントが発火しない
- **イベント名を間違える** — 種別ごとに固定（ドロップダウンは `_SelectedIndexChanged` 等）。
  `_Click` は万能ではない
- **イベントハンドラを `private` にする** — レイトバインドで呼ばれるため `protected` にする。
  コンパイルは通り、実行時に呼ばれないだけ
- **イベントハンドラの戻り値を `void` にする** — `string`（遷移先 URL）。遷移しないなら
  `string.Empty` を返す
- **コントロール名をページ・マスタページ・ユーザコントロールを跨いで重複させる** —
  ASP.NET としては問題ないが、P層フレームワークのイベント処理機能が許可しない
- **マスタページ上のコントロールのハンドラに接頭辞（ファイル名）を付け忘れる** —
  `UOC_（マスタページのファイル名）_（コントロール名）_（イベント名）`
- **接頭辞にコンテンツ `.aspx` 名を使う（マスタ名と取り違える）** — マスタ上ボタンの接頭辞は**マスタ `.master` 名**。
  マスタとコンテンツが同名だと間違えやすく、間違えても**コンパイルは通り実行時に呼ばれないだけ**（`private` と同じ静かな失敗）
