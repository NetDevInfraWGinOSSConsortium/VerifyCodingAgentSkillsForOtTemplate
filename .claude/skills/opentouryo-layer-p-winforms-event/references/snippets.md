# P層 Windows Forms（イベント処理）コードスニペット（コピー元）

出典：UserGuide リッチクライアント編 §1.2、`RcFxEventArgs`・`MyBaseControllerWin`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## イベントハンドラ（共通引数は RcFxEventArgs、戻り値は void）

Web Forms と違い **`RcFxEventArgs`**・**戻り値 void**（画面遷移の概念が無い）。

> **名前空間（`using` が無いと `CS0246`）**：`RcFxEventArgs` は **`Touryo.Infrastructure.Framework.RichClient.Presentation`**／3層の `CallController` は **`Touryo.Infrastructure.Framework.Transmission`**。

```csharp
// コンテンツ（Form）上のコントロール
protected void UOC_btnButton_Click(RcFxEventArgs rcFxEventArgs)
{
    // rcFxEventArgs.ControlName でコントロール名を取得
    // TODO:
}

// ユーザコントロール上のコントロール（UC 名 = testControl）
protected void UOC_testControl_btnButton_Click(RcFxEventArgs rcFxEventArgs)
{
    // TODO:
}
```

> UOC メソッドは共通ハンドラからレイトバインドで呼ばれるため **`public` か `protected`**（`private` 不可）。

## 対応コントロールと既定イベント（6接頭辞）

| 接頭辞 | コントロール | イベント |
| --- | --- | --- |
| `btn` | ボタン（隠しボタン含む） | `Click` |
| `pbx` | ピクチャボックス | `Click` |
| `cbb` | コンボボックス | `SelectedIndexChanged` |
| `lbx` | リストボックス | `SelectedIndexChanged` |
| `rbn` | ラジオボタン | `CheckedChanged` |

## イベント数が多い場合

.NET 標準のイベントハンドラから隠しボタン（HiddenButton）の `DoClick` で `Click` を発火させると、
マルチプル/マルチキャストのイベントも P層イベント処理機能に乗せられる。

> 対応コントロール/イベントの追加は親クラス2 の `addControlEvent`（`opentouryo-base2-customize`）。
> B層呼び出し/手動トランザクションは `opentouryo-p-call-business`、非同期は `opentouryo-richclient-async`。
