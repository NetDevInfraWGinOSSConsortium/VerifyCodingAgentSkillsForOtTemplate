# ASP.NET の状態管理方式（設計・実装の基本）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。
出典：「ASP.NET の状態管理方式」（Microsoft 技術情報）＋実ソース／既存スキル。**どこに何を持たせるか**の地図。

> **★ ViewState と Server.Transfer＋HTTP Context は Web Forms 専用**（MVC には無い）。Session／Application／Cache はサーバ側技術で **ASP.NET 全般（Web Forms・MVC）で使える**。

## クライアント側（サーバ ステートレス）

| 方式 | 用途／スコープ・寿命 | 注意 | Web Forms 専用 |
| --- | --- | --- | --- |
| **ViewState** | Web コントロール状態の復元・ポストバックのイベント振り分け。`__VIEWSTATE` Hidden に Base64＋ハッシュ。同一画面・ポストバック単位 | HTML 肥大＝トラフィック増。既定で暗号化なし（`EnableViewState`／`EnableViewStateMac`／`ViewStateEncryptionMode`） | **★ 専用** |
| Hidden / Form / Query String | リクエスト単位で値を持ち回る。サーバ資源不要 | 改ざんリスク（サーバで検証） | 共通 |
| Cookie | SessionID・認証チケット・個人化。複数ページ | クライアント保持＝改ざん・容量 | 共通 |
| **Server.Transfer ＋ HTTP Context 領域** | サーバ処理内（単一リクエスト）で状態を持ち回る（`HttpContext.Items` 等） | 遷移をまたがない | **★ 専用** |

## サーバ側（サーバ ステートフル）

| 方式 | 用途／スコープ・寿命 | 注意 |
| --- | --- | --- |
| **Session** | ユーザ単位の状態・複数ページ。既定タイムアウト約20分 | 資源消費・拡張性。**負荷分散は StateServer/SQLServer**（直列化要）。容量＝1人分×同時ユーザ数 |
| **Application** | アプリ全体でユーザ横断共有（採番プール等） | 排他制御要・**負荷分散で共有不可** |
| **Cache** | キャッシング・マスタ保持。自動破棄（メモリ不足／期限／ファイル・依存変更） | 排他・**取得時 null チェック必須** |
| 静的変数 | アプリ全体のグローバル | 排他が難しい |

## 負荷分散（Web ファーム）

- **net48**：`web.config` の **`<machineKey>` を全ノードで統一**する。ViewState・Session（暗号化）・Cookie 認証チケットの暗号化／検証がノード間で相互運用可能になる（`opentouryo-config`／`opentouryo-auth`）。
- **★ Core（net10.0）に `machineKey` は無い**。代わりに **ASP.NET Core Data Protection**（`AddDataProtection`）が Cookie 認証・アンチフォージェリ・TempData 等を保護。既定のキーリングは**マシン ローカル**なので、Web ファーム/複数インスタンスでは**共有ストレージに永続化**（`PersistKeysToFileSystem`〔共有UNC〕／`PersistKeysToStackExchangeRedis`／Azure Blob）＋**複数アプリ共有なら `SetApplicationName("同一名")`**。放置するとスケールアウト/再起動でトークン失効（ログイン切れ・anti-forgery エラー）。

## OpenTouryo での対応（どれをどのスキルで）

| 持たせたいもの | OpenTouryo での置き場 | スキル |
| --- | --- | --- |
| フレームの隠しフィールド（`RequestTicketGuid`／`ScreenGuid`／`WindowGuid` 等） | マスタの Hidden。不正操作防止・画面遷移で使用 | `references/illegal-operation-prevention.md`・`opentouryo-layer-p-webforms-screen` |
| ユーザ単位の状態（Session） | **ブラウザ・ウィンドウ別／親画面別 Session 領域**（入れ子2層）・モーダル受け渡し | `opentouryo-webforms-dialog`・`opentouryo-config` |
| レスポンス／データのキャッシュ（Cache） | `FxCacheControl`（レスポンス無効化）／`FxSqlCacheSwitch`（SQL）／`IMemoryCache`・`IDistributedCache`（Core） | `references/cache-control.md` |
| アプリ共通の**定数**（Application 的な固定値） | **共有情報**（`SPDefinition.xml`＋`GetSharedProperty`）＝ユーザ状態でなく設定値 | `opentouryo-shared-property` |
| 認証チケット（Cookie）・`machineKey` | Forms 認証（net48）／Cookie 認証（Core） | `opentouryo-auth`・`opentouryo-config` |
| 複数ポストバックに跨る編集（`DataTable`） | **Session 保持**（StateServer/SQLServer なら直列化可能に）／**同一画面のポストバック内なら ViewState も検討**（下記） | `opentouryo-batch-update` |

> **★ 編集中 `DataTable` の置き場は Session と ViewState のトレードオフ**（同一画面のポストバックで完結する編集）：
> **Session**＝サーバ メモリを消費し**後始末が要る**（`FxSessionAbandon`／明示削除・LRU 上限。切り忘れると次ユーザ・タイムアウトまで残る）が NW は増えない。
> **ViewState**（**Web Forms 専用**・同一画面のポストバック限定）＝`__VIEWSTATE` に載せて往復＝**NW オーバーヘッドは増える**が、**リクエストと共に消える＝サーバ資源も後始末も不要**なのが大きな利点。
> ただし**画面遷移をまたぐ持ち回り〔(1) の PK＋TS〕には使えない**（そこは Session/Query String）。件数が多いと ViewState 自体が肥大するので、**上限/ページングは Session と同様に要る**。

## ★ 共通情報の持ち回り（2経路）

システム全体で共通に使う情報（ユーザ情報等）の持ち回りは**2経路**：

1. **ユーザ情報クラス `MyUserInfo`**（ユーザ名／端末〔IP・マシン名〕／権限）——**ログオン時に設定**し、**ASP.NET は Session／リッチクライアントはグローバル変数（`static`）**で保持。取得は `UserInfoHandle`（`opentouryo-auth`）。
2. **共通引数クラス（`MyParameterValue`/`MyReturnValue` 派生）**——画面名・コントロール名・メソッド名・処理区分（`actionType`）・ユーザ情報 を持ち、**P→B→D へ引数で渡す**（`opentouryo-p-call-business`）。全 B層で運ぶ共通項目は親クラス2 で追加（`opentouryo-project-policy`／`opentouryo-base2-customize`）。

**使い分け**：ユーザ状態＝Session/global（①）／レイヤ間の受け渡し＝引数クラス（②）／アプリ共通の定数＝共有情報（`GetSharedProperty`・上表）。

## OpenTouryo の Session 管理機能（補足）

- **Session 領域の自動削除**（★ **Web Forms 専用**＝`BaseController` の GUID キュー）：**あり**＝親画面別／ブラウザ・ウィンドウ別（LRU。`FxScreeenGuidMaxQueueLength`／`FxWindowGuidMaxQueueLength`。`opentouryo-webforms-dialog`）。**なし**＝ユーザ情報用／サブシステムID別（セッション中は保持され消えない）。

- **タイムアウト検出**（**Web Forms・MVC 両方**）：スイッチ＝`FxSessionTimeOutCheck`（`opentouryo-config`・既定 **OFF**）。仕組み＝**揮発性 Cookie `SessionTimeOut`**（ブラウザを閉じると消える）＋**新規セッション判定**。セッションが切れた後の再アクセスは「新規セッションなのに検出用 Cookie が残っている」ため**タイムアウトと判定**し `FrameworkException`（`SESSION_TIMEOUT`）をスロー→共通エラー画面。**全 Web 親クラス1 に実装**＝`BaseController`〔WebForms〕／`BaseMVController`〔MVC net48〕／`BaseMVControllerCore`〔MVC Core〕。**★ Core は `HttpSessionState.IsNewSession` が無いため Session キーで疑似実装**。⇔ **不正操作防止（RequestTicket）・`IsNoSession` は Web Forms 専用**（MVC 親クラスに無い）と対照的。

- **タイムアウト後の Session クリア＝`FxSessionAbandon()`**（**全3クラスに実装**・`opentouryo-auth`）：検出 ON 中に**通常の `Session.Abandon()`/`Clear()` を呼ぶと次アクセスで必ずタイムアウト例外**（検出用 Cookie が残るため）。`FxSessionAbandon` は**検出用 Cookie も同時に消す**ので例外にならない。**net48=`Abandon()`／Core=`Clear()`**。**クリア後は別画面へ GET 遷移**（同画面ポストバックは不正操作防止でエラー）。ログイン画面の対策3択（P層FW非使用／`IsNoSession=true`〔★ WebForms 専用〕／`FxSessionAbandon`）は `opentouryo-auth`。

- **タイムアウト防止（Ping＝キープアライブ）**：クライアント JS **`Scripts/touryo/common.js` の `HttpPing()`**（`$.ajax` GET・`cache:false`）が**一定間隔でサーバへ ping** し、画面を開いている間 Session を維持する。**有効化＝`window.setInterval(HttpPing, 5*60*1000)` のコメントアウト（`//`）を外す**（既定は無効）。ping 先は **WebForms=`ping.aspx`／MVC=`~/Ping`（`Fx_ResolveServerUrl('~/Ping')`）**。**★ クライアント JS なので MVC でも有効**（Web Forms 専用ではない。`MVC_Sample/Scripts/touryo/common.js` に実在）。

- **Session サイズ計測**：**`MyCmnFunction.CalculateSessionSizeMB()`／`CalculateSessionSizeKB()`**（`Business/Util`・public static）で肥大を監視（Session に大きな `DataTable` 等を持つとメモリ圧迫＝`opentouryo-batch-update`）。

## 設計時に決めること（チェック）

- その状態の**スコープと寿命**（1リクエスト／画面／ユーザ／アプリ）で方式を選ぶ。
- **MVC なら ViewState・Server.Transfer は使えない**（Hidden／TempData／Session 等で代替）。
- ユーザ状態を Session に置くなら**負荷分散（StateServer/SQLServer・直列化・`machineKey`）**を設計。
- Cache は **null チェック・破棄戦略（TTL）** を決める（`references/cache-control.md`）。
