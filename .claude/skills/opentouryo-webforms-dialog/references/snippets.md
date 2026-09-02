# 子画面表示（Web Forms）コードスニペット（コピー元）

出典：UserGuide 各機能編 §2、実ソースで裏取り。**on-demand 参照**（SKILL 予算外）。

## OK メッセージダイアログ（後処理なし）

```csharp
// IconType は Information / Exclamation / StopMark（旧 doc の INFORMATION 等は古い綴り）
this.ShowOKMessageDialog("メッセージID", "本文", FxEnum.IconType.Information, "タイトル");
// オーバーロード：+ "dialogWidth:450px;dialogHeight:250px;status:no;"
```

## YES/NO 確認ダイアログ＋後処理

```csharp
this.ShowYesNoMessageDialog("メッセージID", "本文", "タイトル");

// 後処理は画面コードクラスに override（Yes/No/X）
protected override void UOC_YesNoDialog_Yes_Click(FxEventArgs parentFxEventArgs)
{
    switch (parentFxEventArgs.ButtonID)   // どのボタンから開いたか
    {
        case "btnXXXX": /* ... */ break;
        default: break;
    }
}
protected override void UOC_YesNoDialog_No_Click(FxEventArgs parentFxEventArgs) { }
protected override void UOC_YesNoDialog_X_Click(FxEventArgs parentFxEventArgs) { }
```

> ★ `buttonHistoryRecorder`=off だと `parentFxEventArgs.ButtonID` が常に `"dummy"`＝switch が効かない。

## 業務モーダルダイアログ

```csharp
this.ShowModalScreen("URL");                       // サーバ側イベントから
// クライアント側イベントから：
this.btn.OnClientClick = "return " + this.GetScriptToShowModalScreen("URL") + ";";

// 子画面を閉じる
this.CloseModalScreen();            // 親でポストバック＋後処理あり
this.CloseModalScreen_NoPostback(); // 後処理なし
// ※ CloseModalScreen_WithAllParent() はサポート終了（使わない）

// 後処理（親×子のボタンで分岐）
protected override void UOC_ModalDialog_End(FxEventArgs parentFxEventArgs, FxEventArgs childFxEventArgs)
{
    switch (parentFxEventArgs.ButtonID) { /* ... childFxEventArgs.ButtonID で更に分岐 ... */ }
}
```

## 業務モードレス画面／データ受け渡し（親画面別セッション）

```csharp
this.ShowNormalScreen("testScreen.aspx");   // 引数は開く子画面の URL（例。任意の画面パスでよい）

this.SetDataToModalInterface("key", value);
object v = this.GetDataFromModalInterface("key");
this.DeleteDataFromModalInterface("key");   // 引数なしで全削除
```

> 画面の新規作成は `opentouryo-layer-p-webforms-screen`。最新版は `window.open`／Floating div（旧 `showModalDialog` から置換）。

## ★ ヘッドレス検証（クライアント→サーバの hidden フィールド契約）

ブラウザを持たないエージェントがダイアログ経由の業務フロー（YES で更新確定 等）を `Invoke-WebRequest` だけで
再現するための、`Scripts/touryo/common.js` が使う hidden フィールド契約（**WebForms `common.js` で裏取り**）。
**ダイアログは JS が hidden を書いてフォームを submit するだけ**＝これらを自前でセットして再ポストすれば同じサーバ後処理が走る。

| hidden（`ctl00$` 接頭辞） | 値 | 意味（サーバ後処理） |
| --- | --- | --- |
| `SubmitFlag` | `1` | YES/NO ダイアログで **「×」**（`UOC_YesNoDialog_X_Click`） |
| `SubmitFlag` | `2` | YES/NO ダイアログで **「YES」**（`UOC_YesNoDialog_Yes_Click`） |
| `SubmitFlag` | `3` | YES/NO ダイアログで **「NO」**（`UOC_YesNoDialog_No_Click`） |
| `SubmitFlag` | `4` | 業務モーダル/モードレスを閉じた後のポストバック（`UOC_ModalDialog_End`） |
| `CloseFlag` | `1`/`2`/`3` | 子画面側で閉じる（`1`=親で後処理あり／`2`=後処理なし／`3`=判定） |
| `ChildScreenType`/`ChildScreenUrl` | 非空 | **サーバが「ダイアログ起動中」を返した**印（`ChildScreenUrl` に `?ParentScreenGUID=…`）＝次段でこの契約に沿って再ポスト |

- **submit 時にボタン名は送らない**（`fobj.submit()`）＝どのボタンから開いたかは `SubmitFlag` と保持済みの状態で判定する。
- 手順：①通常ポストで「YES/NO を出す」イベントを起こす→②応答の `ChildScreenType`/`ChildScreenUrl` で起動を検出→
  ③`__VIEWSTATE`/`__EVENTVALIDATION` を引き継ぎ **`ctl00$SubmitFlag=2`** を足して同じ URL へ再ポスト（＝YES 確定）。
- ★ これは**検証用の内部契約**。業務コードから触るものではない（`ShowYesNoMessageDialog`／`UOC_YesNoDialog_*` を使う）。
