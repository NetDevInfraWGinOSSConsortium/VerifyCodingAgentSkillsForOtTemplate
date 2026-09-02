---
name: opentouryo-webforms-dialog
description: "OpenTouryo の P層（ASP.NET Web Forms）で子画面表示機能を使う。OK メッセージダイアログ（ShowOKMessageDialog）、YES/NO 確認ダイアログ（ShowYesNoMessageDialog）とその後処理（UOC_YesNoDialog_Yes_Click / _No_Click / _X_Click）、業務モーダルダイアログ（ShowModalScreen / GetScriptToShowModalScreen / CloseModalScreen / CloseModalScreen_NoPostback）とその後処理（UOC_ModalDialog_End）、業務モードレス画面（ShowNormalScreen）、ダイアログ間の情報受け渡し（SetDataToModalInterface / GetDataFromModalInterface）を扱う。子画面 / ダイアログ / モーダル / モードレス / メッセージダイアログ / 確認ダイアログ / ポップアップ / サブ画面 を Web Forms で表示する作業のときに使う。画面の新規作成そのものは opentouryo-layer-p-webforms-screen を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# P層（Web Forms）：子画面表示機能

> 📋 **コピー元スニペット**：`references/snippets.md`（OK/YesNo/モーダル/モードレス・UOC後処理・データ受け渡し。実装時はここから写す）。

## このスキルの適用範囲

**Web Forms で、ダイアログや子画面を開く。** 親クラス1（`BaseController`）が用意する
子画面表示 API を、画面コードクラスのイベント処理から呼ぶ。

- 画面そのものの作成 → `opentouryo-layer-p-webforms-screen`
- イベントハンドラの書き方 → `opentouryo-layer-p-webforms-event`
- **Web Forms 専用。** MVC / Windows Forms には無い

## 4種類の子画面

| 種類 | 開くメソッド | 後処理（コールバック） |
| --- | --- | --- |
| OK メッセージダイアログ | `ShowOKMessageDialog` | **無い**（通知のみ） |
| YES/NO 確認ダイアログ | `ShowYesNoMessageDialog` | `UOC_YesNoDialog_Yes_Click` / `_No_Click` / `_X_Click` |
| 業務モーダルダイアログ | `ShowModalScreen` / `GetScriptToShowModalScreen` | `UOC_ModalDialog_End` |
| 業務モードレス画面 | `ShowNormalScreen` / `GetScriptToShowNormalScreen` | **無い** |

### ブラウザ実装（最新版）

**IE 以外のブラウザでは擬似ダイアログを使う。**

- OK / YES・NO ダイアログ → **Floating div**
- 業務モーダルダイアログ → **`window.open` メソッド**

（古いドキュメントには「モダンブラウザで業務モーダルが表示できない」とあるが、
これは `showModalDialog` を使っていた旧版の話。最新版は上記の方式に置き換わっている。）

**`CloseModalScreen_WithAllParent` はサポートされなくなった。** メソッドは残っているが使わない。

## OK メッセージダイアログ

**通知だけ。後処理は無い。** イベント処理から呼ぶ。

```csharp
this.ShowOKMessageDialog(
    "messageID",                        // メッセージID
    "メッセージ本文",                    // メッセージ
    FxEnum.IconType.Information,         // アイコン（下記）
    "ダイアログ表示テスト");             // ウィンドウ名
```

`dialogStyle` を足すオーバーロードもある（`"dialogWidth:450px;dialogHeight:250px;status:no;"`）。

`FxEnum.IconType` は **`Information` / `Exclamation` / `StopMark`** の3値
（情報 / 警告 / エラー。**旧ドキュメントの `INFORMATION` 等の綴りは古い**）。

## YES/NO 確認ダイアログ

**後処理を画面コードクラスに `override` で実装する。**

```csharp
this.ShowYesNoMessageDialog("messageID", "保存しますか？", "確認");
// dialogStyle を足すオーバーロードもある
```

**★ 後処理は「別ポストバック」で走る。** `ShowYesNoMessageDialog` を呼んだハンドラはそこで終わり、
`UOC_YesNoDialog_Yes_Click` は**ユーザが YES を押した次のポストバック**で実行される。したがって
「更新ボタン → 確認 → YES で更新」は、**ダイアログを出す時点で編集内容を確定して持ち回る**必要がある
（例：編集中の `DataTable` を `Session` に保持＝`opentouryo-batch-update`。ローカル変数は次ポストバックまで残らない）。

後処理は `UOC_YesNoDialog_Yes_Click` / `_No_Click` / `_X_Click(FxEventArgs parentFxEventArgs)` を
`override`（**コードは `references/snippets.md`**）。**★ 戻り値は `void`**＝`protected override void UOC_YesNoDialog_Yes_Click(...)`
（モーダルの `UOC_ModalDialog_End` も `void`）。同じ画面コードに並ぶ `UOC_（コントロール名）_（イベント名）` は
**`string`（遷移先 URL）**なので、釣られて `string` で書くと `CS0508`（戻り値の型は `void` でなければならない）になる。

**`parentFxEventArgs.ButtonID` で、どのボタンからダイアログを開いたかを判別する。**
1画面に確認ダイアログが複数ある場合、`switch` で振り分ける。

**★ 前提：ボタン履歴記録機能が OFF だと、`ButtonID` は常に `"dummy"`（`FxLiteral.VALUE_STR_DUMMY_STRING`）になり、
`ButtonID` による `switch` 分岐が効かない。** この機能の on/off は config **`FxButtonhistoryMaxQueueLength`**
（`> 0` で ON・`0` 以下＝実質未設定で OFF。実装 `BaseController.cs`）。後処理でボタンを判別するなら正の値にする（`opentouryo-config`）。

## 業務モーダルダイアログ

### サーバ側イベントから開く

```csharp
this.ShowModalScreen("Aspx/Sub/subScreen.aspx");
// dialogStyle を足すオーバーロードもある
```

### クライアント側イベントから開く

`GetScriptToShowModalScreen` は**起動用の JavaScript 文字列を返す。**
コントロールの `OnClientClick` などに設定する。

```csharp
this.btnOpen.OnClientClick = this.GetScriptToShowModalScreen("Aspx/Sub/subScreen.aspx");
```

### 閉じる（子画面側で呼ぶ）

| メソッド | 閉じた後の親画面 |
| --- | --- |
| `CloseModalScreen()` | ポストバックし、後処理（`UOC_ModalDialog_End`）を実行 |
| `CloseModalScreen_NoPostback()` | ポストバックせず、後処理を実行しない |
| ~~`CloseModalScreen_WithAllParent()`~~ | **サポート外**（使わない） |

### 後処理

`UOC_ModalDialog_End(FxEventArgs parentFxEventArgs, FxEventArgs childFxEventArgs)` を `override`
（parent＝開いたボタン・child＝閉じたボタン。二段 `switch` のコードは `references/snippets.md`）。

## 業務モードレス画面

```csharp
this.ShowNormalScreen("Aspx/Sub/normalScreen.aspx");
```

**後処理は無い**（親子間の制御をしないため）。クライアント側から開く
`GetScriptToShowNormalScreen` もある。

## ダイアログ間の情報受け渡し

**親画面 ↔ モーダルダイアログのデータ受け渡し。**

```csharp
this.SetDataToModalInterface("orderId", orderId);          // 設定
object v = this.GetDataFromModalInterface("orderId");      // 取得
this.DeleteDataFromModalInterface("orderId");              // 削除（キー指定）
this.DeleteDataFromModalInterface();                       // 削除（全て）
```

保持先は**親画面別セッション領域**（画面ごとに内部で別インデックスになるので、キー名が
衝突しても競合しない）。**所定の画面からしかアクセスできない。**

**複数ウィンドウ対応なら「ブラウザ・ウィンドウ別セッション領域」**：`SetDataToBrowserWindow` / `GetDataFromBrowserWindow`
（＋ `DeleteDataFromBrowserWindow`。`BaseController.cs` L3195〜）。ブラウザ ウィンドウごとに別領域になるので、同一画面を複数ウィンドウで
開いても競合しない。GET 要求時（遷移リダイレクトを除く）に GUID を採番し Hidden／QueryString で持ち回る。
**Session 領域は入れ子の2層**：外側＝ブラウザ・ウィンドウ別（config `FxWindowGuidMaxQueueLength`）／内側＝
親画面別（`FxScreeenGuidMaxQueueLength`。上記モーダルの保持先）。どちらも世代数を超えると LRU で自動削除（`opentouryo-config`）。

**使い終わったら消す。** 消さない・大きなデータを入れると、サーバがメモリリークする。

## トラブルシュート：IFRAME 親画面が操作不能

一部ブラウザで IFRAME のページ `readyState` が `interactive` のまま `complete` にならず、**二重送信防止機能が
抑止し続けて親画面を操作できなくなる**ことがある。その場合、**親画面の出力時に
`this.Form.Attributes.Remove("onSubmit")`** で二重送信防止をキャンセルする（局所対処）。

## 後処理をマスタページ共通ハンドラに書けない

**YES/NO・モーダルの後処理（`UOC_YesNoDialog_*` / `UOC_ModalDialog_End`）は、
画面コード親クラス2 の「マスタページ上のコントロールの共通イベント処理」に実装できない。**
どのページのボタン履歴かを親クラス2 側で判別できないため。**画面コードクラスに実装する。**

## やってはいけないこと

- **`CloseModalScreen_WithAllParent()` を使う** — サポートされなくなった
- **`FxEnum.IconType.INFORMATION` と書く** — 正しくは `Information`（旧ドキュメントの綴りは古い）
- **YES/NO・モーダルの後処理をマスタページ共通ハンドラに実装する** — 判別できない。
  画面コードクラスに書く
- **`SetDataToModalInterface` のデータを消さずに大きなまま残す** — メモリリークする
- **OK ダイアログに後処理を期待する** — 通知のみ。後処理があるのは YES/NO とモーダル
- **モジュール名（ダイアログの `.aspx`）を変えて `web.config` の `FxOKMessageDialogPath` /
  `FxYesNoMessageDialogPath` を直し忘れる** — ダイアログが開かない
