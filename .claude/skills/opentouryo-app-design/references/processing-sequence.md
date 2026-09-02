# Web Forms P層の処理シーケンス（リクエスト→応答の UOC 呼び出し順・前提知識）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。**フレームワークが UOC をどの順で呼ぶかの地図**（各 UOC の実装ルールは割り付け先スキル）。
出典：OpenTouryo「処理シーケンス」＋実ソース（`BaseController.cs`・`BaseLogic.cs`）。

## 前提：UOC は「フレームワークが決まった順で呼ぶ空フック」

親クラス1（`Base*`）が固定の順序で処理を回し、要所で `UOC_*`（virtual 空メソッド）を呼ぶ。**開発者（画面コード／業務ロジック）と纏め者（親クラス2）はこの UOC を override するだけ**で、順序制御そのものは書かない。

## ① Web Forms：Page ロードのシーケンス（`BaseController`）

親クラス1 コンストラクタで `this.Load += Page_Load` を登録（`BaseController` L284）→ `Page.Init`（空）→ **`Page_Load`（親クラス1）が内部で下記の順に実行**：

1. セッション スコープのロック
2. マスタ ページ初期化（`RootMasterPage`）／ユーザ コントロール初期化
3. Ajax 状態確認（ASP.NET Ajax／ClientCallback）
4. エラー画面へのパスチェック
5. **セッションタイムアウト検出**（`FxSessionTimeOutCheck`。`references/state-management.md`）
6. **二重送信防止（リクエストチケット）**（`references/illegal-operation-prevention.md`）
7. HIDDEN コントロール取得（`WindowGuid`／`RequestTicketGuid`）＝ブラウザ・ウィンドウGUID／画面GUID 生成（**子画面は Query String で GUID 継承**）
8. ボタン履歴メンテ（`buttonHistoryRecorder`。`opentouryo-webforms-dialog`）
9. `FindControl` でコントロール取得＋**イベントハンドラ設定**（接頭辞→ハンドラ。`addControlEvent`。`opentouryo-layer-p-webforms-event`）
10. **親クラス2 の共通初期化：`UOC_CMNFormInit`（初回）／`UOC_CMNFormInit_PostBack`（PostBack）**（纏め者・全画面共通。`opentouryo-base2-customize`・`references/table-driven-control.md`）
11. ダイアログ表示処理（`opentouryo-webforms-dialog`）
12. **`UOC_Finally`**（`EVENT_PAGE_LOAD`。`BaseController` L1687）

**開発者が書くのは `UOC_FormInit`／`UOC_FormInit_PostBack`（画面コードクラス。実装必須。`opentouryo-layer-p-webforms-screen`）**。上記10の `UOC_CMNFormInit` は**纏め者**（全画面共通の初期化フック）で、`UOC_FormInit` の共通版。

## ② Web Forms：PostBack のコントロールイベント シーケンス（`BaseController`）

コントロール操作で共通イベントハンドラ（`Button_Click` 等）が起動し、下記の順に呼ぶ（`BaseController` L2349-2403）：

1. 共通イベントハンドラ（レイトバインド用にメソッド名 `UOC_<コントロール名>_<イベント名>` を生成）
2. **`UOC_PreAction`**（P層・`FxEventArgs`。イベント開始）
3. **`UOC_<コントロール名>_<イベント名>`**（レイトバインドで**画面コードクラスのイベントハンドラ**＝開発者。`opentouryo-layer-p-webforms-event`）
4. **`UOC_AfterAction`**（P層・イベント終了）
5. **`UOC_Screen_Transition`**（画面遷移。`opentouryo-screen-transition`）
6. **`UOC_Finally`**（最終処理）

## ③ B層：`DoBusinessLogic` のシーケンス（`BaseLogic`）

P層が B層を論理名で呼ぶ（`opentouryo-p-call-business`）と、`DoBusinessLogic(pv, iso)` が下記の順に回す（`BaseLogic.cs`）：

1. **`UOC_ConnectionOpen`**（接続 Open＋Tx 開始・DBMS/接続文字列選択。L195。`opentouryo-base2-customize`）
2. **`UOC_PreAction`**（B層・`BaseParameterValue`。L203）
3. **`UOC_DoAction`**（**業務ロジック本体＝開発者が実装**。L206。`opentouryo-layer-b`）
4. **`UOC_AfterAction`**（B層。L209）
5. 正常時＝**自動 Commit**
6. **`UOC_AfterTransaction`**（コミット後の共通処理。L248）
7. 例外時＝**`UOC_ABEND`**（業務／システム／その他で振替。L304/353/403）＋**自動 Rollback**（`opentouryo-exception`）

## ★ P層 と B層の `UOC_PreAction`/`UOC_AfterAction` は別物（混同しない）

- **P層** `BaseController.UOC_PreAction(FxEventArgs)`／`UOC_AfterAction(FxEventArgs)`＝**コントロールイベントの前後**（画面・②）。
- **B層** `(My)BaseLogic.UOC_PreAction(BaseParameterValue)`／`UOC_AfterAction(BaseParameterValue)`／`UOC_AfterTransaction`＝**業務ロジックの前後・トランザクション後**（③）。
- **同名だが引数・層・タイミングが違う**。共通処理（認証チェック・ログ等）を差し込むとき、どちらの層かを取り違えない（纏め者＝`opentouryo-base2-customize`）。

## ④ Web Forms 以外の違い

- **WinForms（2層C/S・オンライン）**：Page ライフサイクルの代わりに Form のイベント駆動。`UOC_FormInit`／コントロールイベント／`UOC_Screen_Transition`／`UOC_Finally` は同型（`opentouryo-layer-p-winforms-screen`／`-event`）。
- **MVC**：Page ライフサイクルが無く、コントローラの**アクション＋フィルタ**（Core は `OnActionExecutionAsync`）で回る。**`UOC_CMNFormInit` の Control 再帰は無い**（Control ツリーが無いため。`references/table-driven-control.md`）。タイムアウト検出は MVC 親クラスにもある（`references/state-management.md`）。実装は `opentouryo-layer-p-mvc`。
- **非同期呼出フレームワーク**：`BaseAsyncFunc`／`MyBaseAsyncFunc` の非同期シーケンス（`opentouryo-richclient-async`）。
- **通信制御（P→B が WS）**：P層とB層の間に**サービス インターフェイス（サーバ エンドポイント）＋サービス プロキシ（クライアント エンドポイント）**が挿入される（`opentouryo-transmission`）。P層コードは論理名呼び出しのまま（挿入は構成で切替）。

## 設計時に押さえること（チェック）

- 初期化は `UOC_FormInit`（開発者・画面別）か `UOC_CMNFormInit`（纏め者・全画面共通）か。
- イベント後処理を P層（`UOC_AfterAction`/`UOC_Screen_Transition`）に置くか、業務の後処理を B層（`UOC_AfterAction`/`UOC_AfterTransaction`）に置くか。**層を取り違えない**。
- 共通の前後処理（認証・ログ・閉塞）は親クラス2 の該当 UOC に差す（`opentouryo-base2-customize`）。
