# net48 版 Web API サーバとの差（レガシー・優先度低）

本スキル本文は **ASP.NET Core（net10.0）** が主対象。**net48 のクラシック ASP.NET Web API（System.Web.Http／OWIN ホスティング）**でも同じ
リソースサーバを組めるが、ホスティングと応答の作法が違う。**業務の骨格〔`[MyBaseAsyncApiController]` 属性・`GetClaims`・B層 `DoBusinessLogicAsync`・
DTTables JSON〈`FromDataTable(dt, keepOriginal:true)`〉・エラー形 `{ErrorMessageID,…}`・`test()` 疎通〕は net48/Core で同一**。
出典＝サンプル `Samples\WS_sample\ASPNETWebService`（net48。Core は `Samples4NetCore\Backend\ASPNETWebService`）。

## 差の一覧

| 面 | net10.0（Core・本文） | net48（レガシー） |
| --- | --- | --- |
| ホスティング | Kestrel＋`Program.cs`／`Startup.cs`（`ConfigureServices`/`Configure`） | **IIS/System.Web＋OWIN**：`[assembly: OwinStartup(typeof(Startup))]`／`public void Configuration(IAppBuilder app)` |
| 起動時の登録 | `services.AddControllers().AddNewtonsoftJson()`・`AddOpenApi()`・`UseCors`・`UseEndpoints` | **`WebApiConfig.Register(GlobalConfiguration.Configuration)`**＋`FilterConfig.RegisterGlobalFilters`＋`GlobalConfiguration.Configuration.Initializer(...)` |
| コントローラ基底 | 素の `ControllerBase`＋`[ApiController]` | **`System.Web.Http.ApiController`**（`[ApiController]` は無い） |
| ルーティング | `[Route("api/[controller]/[action]")]`（トークン置換） | **`[RoutePrefix("api/batchupdate")]`＋アクション毎 `[Route("test")]`/`[Route("SelectCount")]`**（属性ルーティング）＋`config.MapHttpAttributeRoutes()` |
| 応答 | `ContentResult`＋アクション毎に `JsonConvert.SerializeObject(obj, JSS)` | **`Task<HttpResponseMessage>`＋`Request.CreateResponse(HttpStatusCode.OK, obj)`**（`Content`/`JsonConvert` を毎回書かない） |
| JSON 設定（camelCase） | アクション毎の `JsonSerializerSettings`（`CamelCase…Resolver`） | **`WebApiConfig` で一括**：XML フォーマッタ除去＋`config.Formatters.JsonFormatter.SerializerSettings.ContractResolver = new CamelCasePropertyNamesContractResolver()` |
| CORS | `app.UseCors(b => b.AllowAnyOrigin()…)`（**AllowCredentials 無し**） | **属性 `[EnableCors(origins:"*", headers:"*", methods:"*", SupportsCredentials = true)]`**＋`config.EnableCors()`（`System.Web.Http.Cors`）。※サンプルは `SupportsCredentials=true`（Core 版は付けない） |
| 認証フィルタの実体 | `MyBaseAsyncApiController`（`IAsyncAuthorizationFilter`/`IAsyncActionFilter`/`IExceptionFilter`） | 同名 `MyBaseAsyncApiController`（**`IAuthenticationFilter`/`IActionFilter`/`IExceptionFilter`**＝System.Web.Http 版）。**属性の書き方・`httpAuthHeader` は同じ** |
| OpenAPI（IDL） | `services.AddOpenApi()`＋`endpoints.MapOpenApi()`（.NET9+ 標準） | **無し**（必要なら Swashbuckle 等を別途） |
| 設定ファイル | `appsettings.json`（環境変数 `appSettings__<キー>`） | **`Web.config` の `<appSettings>`/`<connectionStrings>`**（＋`app.config`） |
| 復元/ビルド | SDK（`dotnet build`） | **`packages.config`＝`nuget restore`**・非 SDK csproj（msbuild）。`opentouryo-project-setup-build`/`webservices.md` |
| Bearer/JWK | ミドルウェア構成 | OWIN 起動で `OAuth2AndOIDCClient.HttpClient = new HttpClient()`（JwkSet 取得用）を用意 |

## コントローラの雛形（net48）

```csharp
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using System.Web.Http;
using System.Web.Http.Cors;
using Touryo.Infrastructure.Business.Presentation;   // MyBaseAsyncApiController
using Touryo.Infrastructure.Public.Security;         // EnumHttpAuthHeader

[EnableCors(origins: "*", headers: "*", methods: "*", SupportsCredentials = true)]
[MyBaseAsyncApiController(httpAuthHeader: EnumHttpAuthHeader.None | EnumHttpAuthHeader.Bearer)]
[RoutePrefix("api/batchupdate")]
public class BatchUpdateController : ApiController   // ★ ControllerBase でなく ApiController
{
    [HttpGet, Route("test")]
    public string test() => "test";

    [HttpPost, Route("SelectAll")]
    public async Task<HttpResponseMessage> SelectAll()
    {
        SuppliersReturnValue rv = await this.CallLayerB("SelectAll", null);
        if (rv.ErrorFlag) { return this.CreateErrorResponse(rv); }

        DTTables dtts = new DTTables();
        dtts.Add(DTTable.FromDataTable(rv.Suppliers, true));   // keepOriginal は net48/Core 同じ
        return Request.CreateResponse(HttpStatusCode.OK, new { Suppliers = DTTables.DTTablesToJson(dtts) });
    }

    // CallLayerB / GetClaims / DTTables 受信・ToDataTable は Core 版と同じ（references/snippets.md）。
    // エラー応答も同形：Request.CreateResponse(HttpStatusCode.OK, new { rv.ErrorMessageID, rv.ErrorMessage, rv.ErrorInfo });
}
```

**要点**：クライアント（`opentouryo-webapi-client`）は HTTP＋JSON なので **net48/Core どちらのサーバでも同じ叩き方**（DTTables 往復・判定も同じ）。差はサーバの実装作法だけ。
