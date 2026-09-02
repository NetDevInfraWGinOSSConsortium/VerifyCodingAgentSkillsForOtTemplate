# 不正操作防止機能（設計・実装の基本）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。対象＝**P層（ASP.NET Web Forms 専用）**。
出典：OpenTouryo「不正操作防止機能」「Webアプリケーションの不正操作」＋実ソース（`BaseController.cs` / `FxLiteral.cs`）＋最新動向（末尾 Sources）。**キャッシュ制御と一体**（`references/cache-control.md`）。

> **★ Web Forms 専用・MVC には無い。** 不正操作防止（RequestTicket）・二重送信防止・画面遷移制御・ブラウザ/ウィンドウ別 Session 領域は **`BaseController`（Web Forms）だけ**が生成・検出する。**MVC（`MyBaseMVController`/`Core`）はこれらの検出機構を持たない**（「不正操作/画面遷移チェック エラーならセッションを解放しない」防御ハンドリングの残置のみ〔L450〕）。**キャッシュ制御（`FxCacheControl`）だけは例外で MVC でも効く**。MVC の CSRF は .NET 標準のアンチフォージェリで対応（末尾 最新動向）。

## 不正操作の6分類と対策（キャッシュ⇄不正操作防止の中間マップ）

標準ブラウザ機能だけでは業務要件に足りない → **クライアント側制御（JS。クロスブラウザは限界あり）＋サーバ側検出**の両建てで補完する。まず**「どこまで抑止するか」の要件を明確化**してから機能を割り当てる。

| 不正操作 | 原因／現象 | 主な対策（C=クライアント／S=サーバ） |
| --- | --- | --- |
| ①新規ウィンドウ | 複数ウィンドウで同一業務→**Session 競合** | C: `window.open()` 名前付き／S: 画面遷移制御＋ブラウザ・ウィンドウ別 Session 領域 |
| ②URL 直打ち | 初期表示前提でない画面で Form/Session 不足→**NullReference** | C: アドレスバー非表示／S: **画面遷移制御で GET 要求を拒否** |
| ③二重送信 | 多重クリック／遅延で同一要求が複数→キー重複・二重更新（ts アンマッチ）・Session 不整合。Firefox は既定抑止・IE6〜8 は非抑止 | C: **二重送信防止機能**〔`FxDoubleTransmissionCheck=on`→フォームに `onSubmit="return Fx_OnSubmit();"` を仕掛ける JS〕／S: 不正操作防止機能 |
| ④戻る（バック・サブミット） | 戻って再送信＝③相当 | C: 戻る無効化／**キャッシュ無効化**〔`Cache-Control: no-cache`。ただしプロキシ／IE 一時ファイル設定でファジー〕／S: 不正操作防止機能 |
| ⑤更新（リロード） | 旧リクエストが再送＝③相当 | C: F5 等の無効化／S: 不正操作防止機能 |
| ⑥読み込み停止後の操作 | 中止（Esc 等）後に再サブミット＝③相当 | C: 中止操作の無効化／S: 不正操作防止機能 |

- **④⑤⑥は「送信済み画面の再現」＝不正操作防止機能（Request Ticket）で一括検出**。④はキャッシュが絡む → **キャッシュ無効化（`FxCacheControl`）と一体**（`references/cache-control.md`）。
- **リロード時の HTTP メソッドは遷移方式で変わる**：`Server.Transfer` 後のリロード＝**POST 再送**／`Response.Redirect` 後のリロード＝**GET 再送**。この非対称を使い **PRG（Post-Redirect-Get）で二重送信を防ぐ**方法もある（`opentouryo-screen-transition`）。
- **機能は4つ**：不正操作防止（S・下記）／二重送信防止（C・JS）／画面遷移制御（②URL 直打ち拒否・①ウィンドウ制限。`opentouryo-screen-transition`）／ブラウザ・ウィンドウ別 Session 領域（①競合回避）。

## OpenTouryo の仕組み：リクエスト チケット（Request Ticket GUID）

- **防ぐ操作**：二重送信・リロード・**バック→サブミット（戻ってから再送信）**・**キャッシュ参照**——いずれも「同一ユーザによる、送信済みフォームの再現」。
- **仕組み**：`RequestTicketGuid`（**マスタの Hidden フィールド**〔`FxLiteral.HIDDEN_REQUEST_TICKET_GUID = "RequestTicketGuid"`〕）と、
  **Session 側のキュー** `RequestTicketGuid_Queue`（`Queue<string>`・**LRU の世代管理**）を**サーバで突き合わせて**検出。→ **マスタの隠しフィールドが必須**（`opentouryo-layer-p-webforms-screen`）。
- **世代数** ＝ config **`FxRequestTicketGuidMaxQueueLength`**（`FxLiteral` L80）。実質「**戻るを何段まで許すか**」の目安。
- **複数ブラウザ/ウィンドウ対応**：ブラウザ別・ウィンドウ別 Session 領域（`FxScreeenGuidMaxQueueLength` / `FxWindowGuidMaxQueueLength`）と連携。
- **検出時**：例外。ただし**セッションは解放しない＝業務続行可能**（致命でなく、やり直し可能な扱い）。ログ出力・セッション解放は親クラス2（`MyBaseController`）でカスタマイズ可。
- **誤検知対策**：画面別に **`CanCheckIllegalOperation`（`bool?`・`BaseController`）** で当該画面のチェック動作を変更／OFF。

## 併用する関連機能（config）

| 機能 | config キー | 参照 |
| --- | --- | --- |
| 二重送信防止 | `FxDoubleTransmissionCheck` | `opentouryo-config` |
| ボタン履歴（`ButtonID` 判別） | `FxButtonhistoryMaxQueueLength`（0以下=OFF → `ButtonID="dummy"`） | `opentouryo-config` / `opentouryo-webforms-dialog` |
| ブラウザ・ウィンドウ別／親画面別 Session 領域（入れ子2層） | `FxWindowGuidMaxQueueLength`（外＝窓別）/ `FxScreeenGuidMaxQueueLength`（内＝親画面別） | `opentouryo-config` / `opentouryo-webforms-dialog` |
| 画面遷移制御 | `FxScreenTransitionMode` / `FxScreenTransitionCheck` | `opentouryo-screen-transition` |
| キャッシュ無効化 | `FxCacheControl` | `references/cache-control.md` |

- **キャッシュ制御・画面遷移制御・不正操作防止は三点セット。** キャッシュされた古い画面から戻る/再送すると Request Ticket が不整合になり検出される → **キャッシュ無効化（`FxCacheControl=on`）と必ず併用**。

## 最新動向（同種の防御）

- **PRG（Post-Redirect-Get）**：POST 後に Redirect → GET。リロード/戻るでの**偶発的な二重送信**を防ぐ基本形。
- **シンクロナイザ／冪等化トークン**：フォームごとに一意トークンを発行し使い捨て。OpenTouryo の Request Ticket と同型（**CSRF トークンにも「複数世代を Session に上限付きで保持」する強化策**があり、OpenTouryo のキュー方式と同じ発想）。
- **CSRF（アンチフォージェリ）トークン**：ASP.NET Core は**既定で有効**（Cookie＋Hidden の二重トークン。POST/PUT/DELETE で要求、GET/HEAD は副作用なし）。**★ 目的が違う**——CSRF は**別サイトからの強制送信**を防ぐ／OpenTouryo の Request Ticket は**同一ユーザの再送・リプレイ**を防ぐ。**両方必要**（補完関係）。
- **API 冪等化キー**：クライアントが一意キーを送り、サーバで重複排除（REST の二重実行対策）。

## 設計時に決めること（チェック）

- 更新系フォームで**二重送信/戻る再送/リロード**をどう防ぐか（OpenTouryo は Request Ticket が既定で働く。**マスタの隠しフィールドが要る**）。
- `FxRequestTicketGuidMaxQueueLength`（戻り許容段数）・二重送信・ボタン履歴・画面/ウィンドウ GUID のスイッチを決める。
- **キャッシュ無効化・画面遷移制御と一体**で設計（三点セット）。
- 誤検知が出る画面は `CanCheckIllegalOperation` で調整。
- Core/新規は **CSRF アンチフォージェリ（別目的）＋ PRG／冪等化** も併せて検討。

## Sources（最新動向）

- Prevent CSRF (anti-forgery) in ASP.NET Core — https://learn.microsoft.com/en-us/aspnet/core/security/anti-request-forgery
- OWASP CSRF Prevention Cheat Sheet — https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html
