# キャッシュ制御（設計・実装の基本）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。対象＝**P層（Web Forms・MVC の両方）**。
※ **他の不正操作防止系機能（不正操作防止・二重送信・画面遷移制御・ブラウザ/ウィンドウ別 Session 領域）は Web Forms 専用だが、キャッシュ制御は例外で MVC でも効く**（`references/illegal-operation-prevention.md`）。
出典：OpenTouryo「キャッシュ・コントロール」＋実ソース（`MyBaseController.cs` / `MyLiteral.cs` / `PubLiteral.cs`）＋最新動向（ASP.NET Core。末尾 Sources）。

## OpenTouryo の方針：動的画面のレスポンスはキャッシュ無効が基本

Web アプリのデータ不整合・機密漏えい（戻るボタンでのログアウト後表示・プロキシ残存）を避けるため、**動的画面のレスポンスはキャッシュさせない**のが基本方針。

- フレームワークが**スイッチ config `FxCacheControl`**（`MyLiteral.CACHE_CONTROL`。ON/OFF・**既定 OFF**）を持つ。**`FxCacheControl=on`** にすると
  親クラス2 が全レスポンスに無効化ヘッダを付ける（既定 OFF なので、**方針として ON を推奨**）。
  **Web Forms は `MyBaseController`、MVC は `MyBaseMVController`／`MyBaseMVControllerCore` が同処理を実装**（両対応）：
  ```
  Cache-Control: no-cache, no-store, must-revalidate   （HTTP/1.1）
  Pragma: no-cache                                      （HTTP/1.0）
  Expires: 0                                            （プロキシ）
  ```
- **不正操作防止機能／画面遷移制御機能と併用**して、戻るボタンでの再表示を防ぐ（`opentouryo-screen-transition`）。
- **ファイル ダウンロード等でこの制御を上書きしたいとき**は、`Response.Clear()` してからヘッダを再設定する（`references/file-upload-download.md`）。

## D層の SQL キャッシュ（別カテゴリ）

- **`FxSqlCacheSwitch`**（config・`PubLiteral.SQL_CACHE_SWITCH`）＝SQL 定義のキャッシュ。P層のレスポンス キャッシュとは別物。
- 自動生成 Dao の**クエリ・キャッシュ**（コンストラクタに固定 ID）は `opentouryo-dao-generated`。

## 最新動向（ASP.NET Core）

- **レスポンス（HTTP）キャッシュ**：`[ResponseCache]` 属性で `Cache-Control` を宣言（RFC 9111）。属性は**ヘッダを出すだけ**でサーバには保存しない。
- **OutputCache ミドルウェア（.NET 7+）**：**UI アプリ向けの推奨**。サーバ側の出力キャッシュ（`AddOutputCache` / `app.UseOutputCache()` / `.CacheOutput()`）。既定は `MemoryCache`。旧 ResponseCaching ミドルウェアより推奨。
- **データ キャッシュ**：`IMemoryCache`（単一サーバ・シリアライズ不要で速い）／`IDistributedCache`（Redis 等・複数インスタンスで共有・シリアライズ/ネットワーク）。
- **静的アセット**：長い `max-age` ＋ `immutable` ＋ 内容ハッシュ（フィンガープリント）で積極キャッシュ。
- **セキュリティ（OpenTouryo と同じ結論）**：**ユーザ識別・認証に依存する内容はキャッシュしない**（`Cache-Control: no-store`）。`X-Content-Type-Options: nosniff`。

## 設計時に決めること（チェック）

- 動的/認証画面＝**キャッシュ無効**（OpenTouryo は `FxCacheControl=on`／Core は `no-store`）。
- 静的アセット＝**積極キャッシュ**（`max-age`＋`immutable`＋フィンガープリント）。
- 重い参照データ＝`IMemoryCache`／`IDistributedCache`（**TTL と無効化戦略**を決める）。
- ファイル ダウンロードで framework の no-cache を `Response.Clear` で上書きしてよいか判断。

## Sources（最新動向）

- Overview of caching in ASP.NET Core — https://learn.microsoft.com/en-us/aspnet/core/performance/caching/overview
- Output caching middleware — https://learn.microsoft.com/en-us/aspnet/core/performance/caching/output
- Response caching (`[ResponseCache]`) — https://learn.microsoft.com/en-us/aspnet/core/performance/caching/response
