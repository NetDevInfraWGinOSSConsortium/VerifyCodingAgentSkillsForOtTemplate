---
name: opentouryo-layer-p-winforms-event
description: "OpenTouryo の P層（Windows Forms、リッチクライアント）でコントロールのイベント処理を実装する。コントロール名の接頭辞（FxPrefixOfButton 等、有効なのは6種だけ）によるイベントの自動結線、種別ごとに決まるハンドラのイベント名（ボタン・ピクチャボックス=Click / コンボボックス・リストボックス=SelectedIndexChanged / ラジオボタン・チェックボックス=CheckedChanged）、protected void ...(RcFxEventArgs) のシグネチャ（戻り値は void）、対応コントロールの拡張と未対応時のトレードオフ、Control の所在別のハンドラ配置（Form 上＝接頭辞なし・ベースForm 継承分も再帰検索で不要／UserControl 上＝UC クラス自身に定義 or Form 側に UC 名接頭辞・Form 優先）を扱う。Windows Forms / WinForms / イベントハンドラ / 接頭辞 / 自動結線 / RcFxEventArgs / UOC_btnXXX_Click / ベースForm / UserControl を伴う作業のときに使う。画面の新規作成は opentouryo-layer-p-winforms-screen、ハンドラ内での B層呼び出しと手動トランザクションは opentouryo-p-call-business を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# P層（Windows Forms）：イベント処理の実装

> 📋 **コピー元スニペット**：`references/snippets.md`（UOC_btnXXX_Click(RcFxEventArgs)・6接頭辞・隠しボタン DoClick。実装時はここから写す）。

## このスキルの適用範囲

**コントロールのイベントハンドラ（UOC メソッド）を実装する。**

- 画面の新規作成 → `opentouryo-layer-p-winforms-screen`
- ハンドラの中身（B層の呼び出し・**2CS の手動トランザクション**）→ `opentouryo-p-call-business`
- 例外 → `opentouryo-exception`

## イベントは接頭辞で自動結線される

**Web Forms と同じ仕組み。** コントロール名の接頭辞（`FxPrefixOfButton` = `btn` など）を
設定から読み、コントロールツリーを走査してハンドラを結線し、UOC へレイトバインドする。

**接頭辞は命名規約ではなく機能。** 規約から外れた名前を付けるとイベントが発火しない。
設定は `app.config` の `appSettings`（`opentouryo-config` 参照）。

## 有効な接頭辞は6種だけ

**Web Forms（14種）より大幅に少ない。** 対応していないコントロールは自動結線されない。

**ハンドラ名のイベント名は、コントロール種別ごとに決まっている**（右列）。

| 設定キー | サンプルでの値 | コントロール | ハンドラのイベント名 |
| --- | --- | --- | --- |
| `FxPrefixOfButton` | `btn` | ボタン | `Click` |
| `FxPrefixOfComboBox` | `cbb` | コンボボックス | `SelectedIndexChanged` |
| `FxPrefixOfListBox` | `lbx` | リストボックス | `SelectedIndexChanged` |
| `FxPrefixOfRadioButton` | `rbn` | ラジオボタン | `CheckedChanged` |
| `FxPrefixOfPictureBox` | `pbx` | ピクチャボックス | `Click` |
| `FxPrefixOfCheckBox` | `cbx` | チェックボックス | `CheckedChanged` |

`FxPrefixOfComboBox` / `FxPrefixOfPictureBox` はリッチクライアント固有（Web Forms では未使用）。
逆に **`FxPrefixOfTextBox` / `FxPrefixOfGridView` などは結線されない**（Web Forms 専用）。

**値はプロジェクトごとに変えられる。** 上記はサンプルの値。既存コードと `app.config` を確認する。

**一覧は「フレームワーク既定」であって、このプロジェクトの全部とは限らない。**
対応コントロール・イベントは `MyBaseControllerWin`（親クラス2）の `addControlEvent` に実装を
足せば拡張できる（`CheckBox` 自体がその実例）。**拡張するのは纏め者**で、利用側は既存の対応を
使う。何に対応しているかは、提供されていれば `MyBaseControllerWin` の `addControlEvent` を
読んで確認する（`opentouryo-project-policy`）。

**対応していないコントロール・イベントは、.NET 標準のイベント処理（デザイナ結線、`+=`）でも
書ける。ただしその場合、フレームワークの例外処理（`UOC_ABEND`）とログ出力を通らない。**

**★ データアクセスを伴わない細かなイベント（単項目チェック `Validating`、`DataGridView`／`DataTable` の編集など）は、
カスタム結線せず標準の .NET イベントで処理してよい。** DB に触れない＝`UOC_ABEND`（例外→エラー画面）やアクセスログの
土台が要らないため。**B層（データアクセス）を呼ぶイベントだけ**フレームワーク結線に載せる。

**カスタム結線（親クラス2 `addControlEvent` の拡張＝纏め者）を実装する前に、まず隠しボタン（HiddenButton）の活用を検討する。**
`.NET 標準イベント → HiddenButton.DoClick() → Click` で発火させれば、対応外のイベントもフレームワークの土台に
載せられる（マルチプル/マルチキャストにも使える）。`MenuItem` は親クラス2 のカスタマイズ不要で、`UOC_FormInit` で
各 `MenuItem.Click` に共通ハンドラ（`Item_Click`）を結線して使える。

**★ 接頭辞で自動結線させるコントロールを動的に足すなら、コンストラクタ（`InitializeComponent()` の直後）で足す。`UOC_FormInit` では遅い。**
基底 `BaseControllerWin.Form_Load` は **接頭辞走査＆結線（`GetCtrlAndSetClickEventHandler2`。1回きり）→ `UOC_CMNFormInit` → `UOC_FormInit`** の順（実ソースで裏取り）。
`UOC_FormInit` の中で `Controls.Add()` したボタンは**走査済みで結線対象にならず、接頭辞 `btn` を付けても押下無反応**（実測：コンストラクタ追加＝結線1／`UOC_FormInit` 追加＝結線0）。
※上の `MenuItem`（`Item_Click` を**手動**結線）や動的 UserControl（`LstUserControl` で別途自動収集）は成立する＝**「接頭辞による自動結線」だけがこの順序制約に掛かる**。

## ハンドラをどこに書くか（Control の所在別）

**Control が「Form 上」か「UserControl 上」かで、UOC を書く場所が変わる**（実装 `GetMethodName` / `CMN_Event_Handler`。Web Forms のコンテンツ/マスタ/UC 命名に相当）。

| Control の所在 | UOC の書き方 | 書く場所 |
| --- | --- | --- |
| **Form 上**（**ベースForm から継承した分も含む**） | `UOC_（コントロール名）_（イベント名）` | その **Form クラス** |
| **UserControl 上**（推奨＝UC 側） | `UOC_（コントロール名）_（イベント名）`（接頭辞なし） | その **UserControl クラス自身** |
| **UserControl 上**（Form 側で受ける） | `UOC_（UserControl の Name）_（コントロール名）_（イベント名）` | **Form クラス**（UC の Name が接頭辞） |

- **★ ベースForm 上の Control に接頭辞は不要。** フレームワークはコントロールツリーを**再帰検索**する（`RcMyCmnFunction`）ので、ベースForm から継承した Control も自動で見つかる。**Web Forms のマスタページのような「マスタ名の接頭辞」（`UOC_（マスタ名）_…`）は WinForms では要らない**（Form 側は所在に関わらず `UOC_（名）_（イベント）`）。
  → **フッタ等の共通レイアウトを中間 BaseForm（`MyBaseControllerWin` を継承）に置いて各画面で共有する定石**は `opentouryo-layer-p-winforms-screen`（継承したフッタ ボタンも接頭辞不要で自動結線＝この再帰検索が効く）。
- **UserControl は Form 側が優先。** フレームワークは **Form → 各 UserControl** の順に UOC を探す。Form 側に UC 用ハンドラ（UC の Name を接頭辞にした形）があればそれを、無ければ UserControl 自身のハンドラ（接頭辞なし）を使う。
- **UserControl は自動収集される**（`LstUserControl`＝手動登録不要）。**動的な追加/削除**にも対応（`groupBox.Controls.Add(new 〈UserControl〉())`）。
- 参考サンプル：`Samples/WS_sample/WSClient_sample/WSClientWin2_sample`（`Form3` ＋ `UserControl3`/`UserControlChild`/`UserControlParent`）。※サンプルは削除されうるので**上の規則を正とする**。

## グリッド（DataGridView）に DataTable をバインドして一括更新するなら

`DataGridView` は自動結線の対象外（`FxPrefixOfGridView` は Web Forms 専用）。リッチクライアントでは
**`DataGridView` に `DataTable` を（`BindingSource` 経由で）バインド**し、**[追加]／[削除] は通常のボタン**
（`btn` で結線＝`UOC_btnAdd_Click` / `UOC_btnDelete_Click`）で行う。グリッド上の編集は `DataTable` の `RowState` に
乗るので、まとめて INSERT/UPDATE/DELETE できる → **`opentouryo-batch-update`**（追加=空行 Added、削除=`dr.Delete()`=Deleted、
編集=Modified を `RowState` で振り分け・楽観排他）。

<!--
  結線箇所は2つに分かれている（実装で確認済み）:
    BaseControllerWin（親クラス1）  … BUTTON / COMBO_BOX / LIST_BOX / RADIO_BUTTON / PICTURE_BOX
    MyBaseControllerWin（親クラス2）… CHECK_BOX（MyLiteral.PREFIX_OF_CHECK_BOX）
  親クラス2 で接頭辞を追加できる作りだが、バイナリ提供のため利用側では変更できない。
-->

## イベントハンドラのシグネチャ

**イベント名はコントロール種別で決まる**（上の接頭辞の表）。ボタン／ピクチャボックスは
`Click`、コンボボックス／リストボックスは `SelectedIndexChanged`、ラジオボタン／チェックボックスは
`CheckedChanged`。

```csharp
protected void UOC_btnButton1_Click(RcFxEventArgs rcFxEventArgs)
// コンボボックス cbbKind なら UOC_cbbKind_SelectedIndexChanged
```

| 要素 | Windows Forms | （参考）Web Forms |
| --- | --- | --- |
| 共通引数 | **`RcFxEventArgs`** | `FxEventArgs` |
| 戻り値 | **`void`** | `string`（遷移先 URL） |
| アクセス修飾子 | `protected` | `protected` |

**戻り値が `void`。** Web Forms は遷移先 URL を返すが、リッチクライアントに画面遷移が無いため。

レイトバインドで呼ばれるため、**シグネチャが違っても修飾子が `private` でも
コンパイルは通り、実行時に呼ばれないだけ。**

## ハンドラの中身は B層呼び出し

**イベントハンドラの本体は、引数クラスを組み立てて B層を呼ぶ。** 2CS はコミットが手動なので、
呼んだ後に `CommitAndClose()` を呼ぶ。手順は `opentouryo-p-call-business`。

```csharp
protected void UOC_btnButton1_Click(RcFxEventArgs rcFxEventArgs)
{
    // 引数クラスを組み立てて B層を呼ぶ（画面名は this.Name、
    // コントロール名は rcFxEventArgs.ControlName、ユーザ情報は static）
    // ★ 2CS はコミットが手動：LayerB.CommitAndClose()
    // 詳細は opentouryo-p-call-business
}
```

## やってはいけないこと

- **イベントハンドラの戻り値を `string` にする** — `void`。Web Forms とは違う
- **`FxEventArgs` を使う** — リッチクライアントは `RcFxEventArgs`
- **接頭辞の規約から外れたコントロール名を付ける** — 結線されずイベントが発火しない
- **イベント名を間違える** — 種別ごとに固定（コンボボックスは `_SelectedIndexChanged` 等）
- **イベントハンドラを `private` にする** — レイトバインドで呼ばれない。`protected` にする
- **未対応コントロールを標準結線して済ませる（気づかず例外処理・ログを失う）** — 失うものを
  承知の上でのみ。土台に載せたいなら親クラス2 での拡張（纏め者）
