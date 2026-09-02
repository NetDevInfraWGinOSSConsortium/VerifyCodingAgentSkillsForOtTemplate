# タイムアウト値の設計（ASP.NET／OpenTouryo）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。出典：「ASP.NET で考慮すべきタイムアウト値」＋実ソース
（`BaseDam.SetCommandTimeout` → `PubLiteral.SQL_COMMANDTIMEOUT = "FxSqlCommandTimeout"` L61）で裏取り。

## 原則：呼び出し元（上流・外側）ほど長く

ネストした呼び出しでは、**内側（下流）が先にタイムアウトして、その失敗を外側が受け取れる**ようにする。
外側が先に切れると、内側の処理が孤児化し（続行中なのに呼び出し元は諦める）、真の失敗も掴めない。

## リクエスト経路のネストしたタイムアウト（外 → 内。外側を長く）

| 階層（外→内） | タイムアウト | 設定場所 | 既定 | OpenTouryo／備考 |
| --- | --- | --- | --- | --- |
| ① クライアント／呼び出し元 | `HttpClient.Timeout` / `WebRequest.Timeout` | コード | 100秒 | OAuth2/OIDC は `OAuth2AndOIDCClient.HttpClient`（`opentouryo-oauth2-client`） |
| ② ASP.NET リクエスト処理 | `httpRuntime executionTimeout` | Web.config | 110秒（`debug="false"` 時） | net48 Web Forms |
| ③ DB 接続確立 | `SqlConnection.ConnectionTimeout`（接続文字列 `Connect Timeout=`） | 接続文字列 | 15秒 | 接続文字列は `opentouryo-config` |
| ④ DB コマンド実行 | `SqlCommand.CommandTimeout` | コード／config | 30秒 | **OpenTouryo は config `FxSqlCommandTimeout` で共通設定**（`BaseDam.SetCommandTimeout`。`opentouryo-config` / `opentouryo-dao-common`） |
| ⑤ DB ロック待ち | `SET LOCK_TIMEOUT`（SQL Server） | セッション／SQL | `-1`（無限） | 最下流 |

→ **大小関係の目安：① > ② > ④ > ⑤**（外側ほど長く）。特に **② `executionTimeout` を ④ の DB 実行より長く**しないと、
DB 実行の途中で ASP.NET がリクエストを打ち切る（孤児化）。長時間処理（バッチ／帳票）は ② を延ばすか非同期化する。

## セッション／アイドル系（リクエストのネストとは別カテゴリ）

| タイムアウト | 設定場所 | 既定 | OpenTouryo／備考 |
| --- | --- | --- | --- |
| `Session.Timeout`（セッション） | Web.config `<sessionState timeout>` | 20分 | 予期せぬタイムアウトの検出・破棄は `opentouryo-auth`（`FxSessionAbandon`）、スイッチは `opentouryo-config` |
| アプリケーションプール アイドル タイムアウト | IIS | 20分 | **アイドル/プール ≧ セッション**にする（短いと、セッションが生きているつもりでプロセスが先に落ちる） |

## 設計時に決めること（チェック）

- リクエスト経路 ①〜⑤ を**外側ほど長く**に整合（特に ② を DB 実行より長く）。
- 長時間処理は ② を延ばすか**非同期化**（`opentouryo-richclient-async` 等）。
- OpenTouryo の共通キー（`FxSqlCommandTimeout`・セッション）を使い、**コード直書きを避ける**。
