# 同時実行性・スレッド/接続のチューニング（環境設定）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。**主にインフラ／纏め者の環境設定・性能設計**。
出典：「ASP.NET config（同時実行性）」（.NET Framework 時代）＋最新動向（.NET Core/Kestrel。末尾 Sources）。

> **★ ランタイムで全く違う。** net48（classic IIS）の設定の多くは **`processModel autoConfig` が自動最適化**（.NET 2.0 以降）＝手動調整は稀。
> **net10.0（Core/Kestrel）では下記 classic 設定はすべて無効**——**async/await と Kestrel** で捌く。

## classic（.NET Framework・net48・IIS）＝旧知識（多くは自動／不要）

| 設定ファイル | 要素・属性 | 役割 |
| --- | --- | --- |
| `machine.config` | `<processModel maxWorkerThreads minWorkerThreads maxIoThreads>` | ワーカー/IO スレッド上限（**`autoConfig=true` で自動最適化**） |
| `machine.config` | `<httpRuntime minFreeThreads minLocalRequestFreeThreads executionTimeout>` | 空きスレッド確保・実行タイムアウト（`executionTimeout` は `references/timeout-values.md`） |
| `machine.config` | `<connectionManagement maxconnection>` | **アウトバウンド接続プール**（1アドレスあたり同時接続数・**既定2**）。外部 API/WS を大量に呼ぶなら要増 |
| `aspnet.config` | `<system.web><applicationPool maxConcurrentRequestsPerCPU maxConcurrentThreadsPerCPU requestQueueLimit>` | IIS 統合パイプラインの同時要求 |
| レジストリ | `MaxConcurrentRequestsPerCPU`（DWORD・**既定12**） | CPU あたり同時要求（IIS7+ 統合パイプライン） |

- **★ .NET 2.0 以降は `processModel autoConfig=true` が上記スレッド系を自動最適化**＝通常は触らない。**実測でスレッド枯渇／キュー溢れが出たときだけ**調整する。

## modern（.NET Core・net10.0・Kestrel）＝classic 設定は無効

- **スレッドプールは自動**（自動拡張）。`processModel`／`applicationPool`／レジストリは**効かない**。
- **★ 第一原則＝`async`/`await` を末端まで通す。** スレッドをブロックしない設計なら、少ないスレッドで高同時実行を捌ける（thread-per-request ではない）。**スレッド数を弄る前に async 化。**
- **Kestrel**：`KestrelServerOptions.Limits.MaxConcurrentConnections`（**既定 null＝無制限**）・`MaxConcurrentUpgradedConnections`（WebSocket 昇格分）。`builder.WebHost.ConfigureKestrel(o => o.Limits.MaxConcurrentConnections = N)`。
- **IIS 背後（ANCM）で動かす**なら、同時要求・キューは IIS のアプリプール／`requestQueueLimit` 側。
- **アウトバウンド接続**：classic の `maxconnection` → **`SocketsHttpHandler.MaxConnectionsPerServer`**（既定 `int.MaxValue`）／`HttpClientHandler.MaxConnectionsPerServer`。**`IHttpClientFactory`** で接続プール・DNS 更新を管理（`HttpClient` を毎回 `new` しない・使い捨てない）。**`ServicePointManager.DefaultConnectionLimit` は classic 用で Core では無効**。

## OpenTouryo との対応

- **net48 サンプル**は IIS/IIS Express＝classic 設定が効くが、通常は `autoConfig` で足りる。外部 IdP／WS を多用するなら `maxconnection`（既定2）を検討（`OAuth2AndOIDCClient.HttpClient`＝`opentouryo-auth`／`opentouryo-oauth2-client`、WS＝`opentouryo-transmission`）。
- **net10.0** は Kestrel＝上記 modern。**async 化と `MaxConnectionsPerServer`／`IHttpClientFactory`** で対応。
- タイムアウトの整合（`executionTimeout`／DB／ロック／セッション）は `references/timeout-values.md`（呼び出し元ほど長く）。

## 設計時に決めること（チェック）

- **ランタイムで調整対象が全く違う**（net48=classic の machine/aspnet.config／net10.0=Kestrel＋async）。
- Core は **まず async 化**（スレッド調整はその後）。
- 外部呼び出しが多いなら**アウトバウンド接続上限**（classic `maxconnection`／Core `MaxConnectionsPerServer`＋`IHttpClientFactory`）。
- **先回りで machine.config を弄らない**——実測でスレッド枯渇／キュー溢れが出てから（`opentouryo-log-analysis` の性能分析）。

## Sources（最新動向）

- Kestrel options（`Limits.MaxConcurrentConnections`）— https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel/options
- `HttpClientHandler`/`SocketsHttpHandler.MaxConnectionsPerServer` — https://learn.microsoft.com/en-us/dotnet/api/system.net.http.httpclienthandler.maxconnectionsperserver
- （classic 参考）ASP.NET Thread Usage on IIS — https://techcommunity.microsoft.com/blog/iis-support-blog/asp-net-thread-usage-on-iis-7-5-iis-7-0-and-iis-6-0/3203917
