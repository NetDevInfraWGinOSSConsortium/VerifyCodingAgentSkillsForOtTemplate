# P層 Windows Forms（画面作成）コードスニペット（コピー元）

出典：UserGuide リッチクライアント編 §1、`Samples/WS_sample/WSClient_sample`・`MyBaseControllerWin`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## 画面コードクラス（Form）

```csharp
using System;
// ～
using ProjectName.Infrastructure.Business.Util;

public partial class Form1 : MyBaseControllerWin  // 「画面コード親クラス２」を継承
{
    /// <summary>ページロード（初回）＝実装必須</summary>
    protected override void UOC_FormInit()
    {
        // フォーム初期化（初回ロード）時の処理
        // TODO:
    }
}
```

> `MyBaseControllerWin`（親クラス2）は具象（override 任意）。親クラス1 `BaseControllerWin` は `abstract` で
> VS デザイナが使えないため、共通 UI を親クラス2 に足す場合は注意（`opentouryo-base2-customize`）。

## コントロールの配置（接頭辞規約）

Windows Form 上に `[接頭辞]任意文字列` でコントロールを配置（接頭辞は app.config 定義）。有効なのは **6種**：
`btn`(Button)／`pbx`(PictureBox)／`cbb`(ComboBox)／`lbx`(ListBox)／`rbn`(RadioButton)（＋隠しボタン）。

```xml
<add key="FxPrefixOfButton" value="btn"/>
<add key="FxPrefixOfPictureBox" value="pbx"/>
<add key="FxPrefixOfComboBox" value="cbb"/>
<add key="FxPrefixOfListBox" value="lbx"/>
<add key="FxPrefixOfRadioButton" value="rbn"/>
```

## ユーザ情報

`MyBaseControllerWin` の `UserInfo` は **static**（`protected static MyUserInfo UserInfo`）＝画面間で共有。

イベント処理は `opentouryo-layer-p-winforms-event`、B層呼び出し/手動トランザクションは `opentouryo-p-call-business`、
非同期呼び出しは `opentouryo-richclient-async`。**WPF は P層フレームワークを持たない**（素の `Window`＋B/D層のみ）。
