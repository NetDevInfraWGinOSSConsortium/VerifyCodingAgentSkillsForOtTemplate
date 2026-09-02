---
name: opentouryo-webapi-server
description: "OpenTouryo で ASP.NET Core（net10.0）の Web API サーバ（OAuth2 リソースサーバ）を実装する。素の ControllerBase に [ApiController]＋[EnableCors]＋[Route(\"api/[controller]/[action]\")]＋属性 [MyBaseAsyncApiController(httpAuthHeader: EnumHttpAuthHeader.None | Bearer)] を付ける（この属性が認証/例外/アクションのフィルタ）。Authorization: Bearer で都度認証しクレームは MyBaseAsyncApiController.GetClaims(out ...) で取得、Cookie/セッションは使わない。B層は MVC と同じく ParameterValue→DoBusinessLogicAsync、応答は ContentResult＋JsonConvert（Newtonsoft・camelCase）、業務エラーは { ErrorMessageID, ErrorMessage, ErrorInfo }。DataTable は DTTables JSON（一覧は FromDataTable(dt, keepOriginal:true) で Original 保持、受信は JsonToDTTables→ToDataTable、本文は長い JSON 文字列 DTO を [FromBody]）。Startup は AddControllers().AddNewtonsoftJson()・AddOpenApi()・UseCors・_UseHttpContextAccessor で、Bearer ゆえ UseAuthentication/Session は無し。CSRF は Cookie 非使用で不成立＝ValidateAntiForgeryToken を付けない。WebAPI / リソースサーバ / REST / api コントローラ / Bearer / OpenAPI のサーバ側に使う。クライアントは opentouryo-webapi-client、Bearer 発行は opentouryo-oauth2-client、DTTables は opentouryo-batch-update。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# Web API サーバ（ASP.NET Core・OAuth2 リソースサーバ）

**ASP.NET Core（net10.0）で OpenTouryo の Web API サーバ**を作る型。**OAuth2 の「リソースサーバ」**（`Authorization: Bearer` ヘッダで都度認証・Cookie/セッション無し）。
コントローラ基礎は `opentouryo-layer-p-mvc`（アクションメソッド・B層呼び出しは同じ）、Bearer トークンを出す IdP 連携は `opentouryo-oauth2-client`、`DataTable` の JSON 化は `opentouryo-batch-update`／`opentouryo-common-parts`。

> 📋 **コピー元スニペット（コントローラ・Startup 骨格）は `references/snippets.md`。** クライアント側は `opentouryo-webapi-client`。

> **★ 通信制御（`opentouryo-transmission` の `CallController.Invoke`／WCF・net.tcp）とは別物。** あれはサービス論理名でインプロセス⇄WS を切り替える仕組み。
> こちらは **REST 風の HTTP＋JSON エンドポイント**（`api/<controller>/<action>`）。混同しない。

## コントローラの型

**素の `ControllerBase` に属性を4つ**付ける（`MVC` の画面コントローラと違い基底クラスの継承ではない）：

```csharp
[EnableCors]
[ApiController]
[MyBaseAsyncApiController(httpAuthHeader: EnumHttpAuthHeader.None | EnumHttpAuthHeader.Bearer)]
[Route("api/[controller]/[action]")]
public class BatchUpdateController : ControllerBase { ... }
```

- **`[MyBaseAsyncApiController(...)]` が本体のフック**（`Touryo.Infrastructure.Business.Presentation`＝`ActionFilterAttribute`。認証・例外・アクション前後を担う）。`httpAuthHeader` に
  **`EnumHttpAuthHeader`（`Touryo.Infrastructure.Public.Security`。`None`／`Bearer` 等・Flags）** を渡す。リソースサーバは **`None | Bearer`**（未認証も通し、Bearer の結果はクレームで検証）。
- **クレームは `MyBaseAsyncApiController.GetClaims(out string userName, out string roles, out string scopes, out string ipAddress)`**（static）で取り出す。
- **`[ValidateAntiForgeryToken]` は付けない。** Cookie 認証を使わず Bearer ヘッダ（ブラウザが自動付与しない）＋CORS は `AllowCredentials` 無し＝**CSRF は成立しない**。付けると非ブラウザ クライアントの疎通が壊れる（CodeQL の該当警告は false positive）。

## B層の呼び出し（MVC と同じ）

`opentouryo-p-call-business` どおり。クレームからユーザ情報を作って渡す：

```csharp
MyBaseAsyncApiController.GetClaims(out string userName, out _, out _, out string ipAddress);
var pv = new SuppliersParameterValue("BatchUpdateController", "-", methodName, methodName, new MyUserInfo(userName, ipAddress));
pv.Suppliers = dt;
var rv = (SuppliersReturnValue)await new SuppliersLayerB().DoBusinessLogicAsync(pv, DbEnum.IsolationLevelEnum.DefaultTransaction);
```

- **業務例外は `catch` しない**（`ErrorFlag` で戻る＝`opentouryo-exception`）。B層・D層・トランザクションは `opentouryo-layer-b`／`opentouryo-layer-d`。

## 応答（JSON）

**`ContentResult` を `JsonConvert.SerializeObject`（Newtonsoft）で返す**。**camelCase** に揃える（`CamelCasePropertyNamesContractResolver`）：

```csharp
private readonly JsonSerializerSettings JSS = new JsonSerializerSettings { ContractResolver = new CamelCasePropertyNamesContractResolver() };
return this.Content(JsonConvert.SerializeObject(new { Count = rv.Count }, this.JSS));
```

- **業務エラーの応答は形を固定**：`{ ErrorMessageID, ErrorMessage, ErrorInfo }`（クライアントは `errorMessageID` 等 camelCase で受ける）。
- 疎通用に `[HttpGet] public string test() => "test";` を置くと非対話で確認できる（`opentouryo-project-setup-config` の `run-verify`）。

## `DataTable` を API で受け渡す（DTTables JSON）

`opentouryo-batch-update` の `DTTables` をそのまま HTTP に載せる。**一覧は `keepOriginal: true`**（クライアントが編集して戻す＝往復後に全列 `Original` 楽観排他を効かせるため）：

```csharp
// 返す：DataTable → DTTables JSON（keepOriginal で変更前値も保持）
DTTables dtts = new DTTables(); dtts.Add(DTTable.FromDataTable(rv.Suppliers, true));
return this.Content(JsonConvert.SerializeObject(new { Suppliers = DTTables.DTTablesToJson(dtts) }, this.JSS));

// 受ける：DTTables JSON → DataTable（RowState と Original が戻る）
DTTables dtts = DTTables.JsonToDTTables(param.Suppliers);
DataTable dt = dtts["Suppliers"].ToDataTable();
```

- **本文は DTO を `[FromBody]`（JSON）で受ける**（`[FromForm]` にしない＝DTTables JSON はそれ自体が長い文字列でフォーム エンコードに向かない）。DTO は `public string Suppliers { get; set; }` のように JSON 文字列1個を持つ。

## Startup（`MVC_Sample` と diff が取れる形）

- **`services.AddControllers().AddNewtonsoftJson();`**（`AddControllersWithViews` でなく＝ビュー無し）＋ **`services.AddOpenApi();`**（.NET9+ 標準・`/openapi/v1.json`。Swashbuckle 不要）。
- **`GetConfigParameter.InitConfiguration(configuration)`**（コンストラクタ）／**`services._AddHttpContextAccessor()`**・**`app._UseHttpContextAccessor()`**（`opentouryo-layer-p-mvc` と同じ）。
- **Cookie/セッション/認証ミドルウェアは使わない**（`UseAuthentication`/`UseSession`/`UseStaticFiles`/`MapRazorPages` は無し＝Bearer は上記属性が担う）。`MVC_Sample` からはコメントアウトで残すと Cookie 認証へ広げる手本になる。
- **`app.UseCors(b => b.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader())`**（**`AllowCredentials` は付けない**＝資格情報を送らない）。
- **`endpoints.MapControllers();` ＋ `endpoints.MapOpenApi();`**。
- **appsettings で切り替える**（`opentouryo-config`。既定は従来動作）：`UseHttpsRedirection`（TLS 自前終端時 on。**リダイレクト先ポートが要る**＝`--urls https://…` か `ASPNETCORE_HTTPS_PORT`〈単数〉）／
  **`UseForwardedHeaders`＋`ForwardedHeadersKnownProxies`**（リバースプロキシで TLS 終端すると `Request.IsHttps` が false になる＝`X-Forwarded-Proto` を取り込む。**パイプライン先頭に置く**・コンテナは既知プロキシを空＝制限解除）。環境変数上書きは `appSettings__<キー>`（区切り `__`）。

## net48 版（レガシー・優先度低）

net48 のクラシック ASP.NET Web API（System.Web.Http／OWIN）でも同じリソースサーバを組める。**業務の骨格（`[MyBaseAsyncApiController]` 属性・`GetClaims`・
B層 `DoBusinessLogicAsync`・DTTables JSON〈`keepOriginal:true`〉・エラー形・`test()` 疎通）は同一**で、違うのはホスティングと応答の作法だけ：
コントローラ基底は `ApiController`（`ControllerBase`＋`[ApiController]` でない）／ルーティングは `[RoutePrefix]`＋アクション毎 `[Route]`／応答は `Task<HttpResponseMessage>`＋`Request.CreateResponse(...)`／
camelCase は `WebApiConfig` で一括／CORS は `[EnableCors]` 属性＋`config.EnableCors()`／ホストは OWIN `Startup`＋`Web.config`＋`packages.config`／OpenAPI は無し。**差の一覧と雛形は `references/net48.md`**。クライアント（`opentouryo-webapi-client`）は net48/Core の両サーバに同じ叩き方。

## やってはいけないこと

- **画面コントローラのように基底クラスを継承する** — Web API は `ControllerBase`＋`[MyBaseAsyncApiController]` 属性。
- **`[ValidateAntiForgeryToken]` を付ける** — Bearer＋CORS(no-credentials)で CSRF 不成立。非ブラウザ クライアントが壊れる。
- **`DataTable` を素の `System.Text.Json` で返す** — `RowState`/変更前値が落ちる。`DTTables` を使う（`opentouryo-batch-update`）。
- **`UseHttpsRedirection` を on にしてリダイレクト先ポートを決めない** — 警告だけ出て HTTP のまま素通り（`ASPNETCORE_HTTPS_PORTS` 複数形では決まらない）。
- **業務例外を `catch` する** — `ErrorFlag` で戻る。エラー画面へ飛ばさない（画面が無い＝`MyBaseAsyncApiController` が JSON で返す）。
