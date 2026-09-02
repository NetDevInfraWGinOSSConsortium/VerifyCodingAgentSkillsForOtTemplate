# コピー元スニペット：Web API サーバ（ASP.NET Core・リソースサーバ）

`opentouryo-webapi-server` の実装コード。**net10.0 Core**。表は `Suppliers` を例にした worked example。
出典＝サンプル `Samples4NetCore\Backend\ASPNETWebService` のコントローラ／Startup パターン（実ソースで裏取り）。

## コントローラ（DTTables で一覧・件数・バッチ更新）

```csharp
using System.Data;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;

using ASPNETWebService.Logic.Business;   // 業務 LayerB / ParameterValue / ReturnValue
using ASPNETWebService.Logic.Common;
using Touryo.Infrastructure.Business.Presentation;   // MyBaseAsyncApiController
using Touryo.Infrastructure.Business.Util;           // MyUserInfo
using Touryo.Infrastructure.Public.Db;               // DbEnum
using Touryo.Infrastructure.Public.Dto;              // DTTables / DTTable
using Touryo.Infrastructure.Public.Security;         // EnumHttpAuthHeader

[EnableCors]
[ApiController]
[MyBaseAsyncApiController(httpAuthHeader:
    EnumHttpAuthHeader.None       // 認証無しでも通し、
    | EnumHttpAuthHeader.Bearer)] // Bearer の結果は GetClaims で検証
[Route("api/[controller]/[action]")]
public class BatchUpdateController : ControllerBase
{
    private const string TableName = "Suppliers";

    // camelCase で返す（Newtonsoft）
    private readonly JsonSerializerSettings JSS =
        new JsonSerializerSettings { ContractResolver = new CamelCasePropertyNamesContractResolver() };

    // 疎通（DB を使わない）。GET /api/batchupdate/test
    [HttpGet]
    public string test() => "test";

    // 件数
    [HttpPost]
    public async Task<ContentResult> SelectCount()
    {
        SuppliersReturnValue rv = await this.CallLayerB("SelectCount", null);
        if (rv.ErrorFlag) { return this.CreateErrorResponse(rv); }
        return this.Content(JsonConvert.SerializeObject(new { Count = rv.Count }, this.JSS));
    }

    // 一覧（★ keepOriginal:true＝クライアントが編集して戻す＝楽観排他用に Original を保持）
    [HttpPost]
    public async Task<ContentResult> SelectAll()
    {
        SuppliersReturnValue rv = await this.CallLayerB("SelectAll", null);
        if (rv.ErrorFlag) { return this.CreateErrorResponse(rv); }

        DTTables dtts = new DTTables();
        dtts.Add(DTTable.FromDataTable(rv.Suppliers, true));
        return this.Content(JsonConvert.SerializeObject(
            new { Suppliers = DTTables.DTTablesToJson(dtts) }, this.JSS));
    }

    // バッチ更新（★ 本文は JSON。DTTables JSON は長い文字列なので [FromForm] にしない）
    [HttpPost]
    public async Task<ContentResult> BatchUpdate(BatchUpdateParams param)
    {
        if (param == null || string.IsNullOrEmpty(param.Suppliers))
        {
            return this.Content(JsonConvert.SerializeObject(new { ErrorMSG = "更新対象がありません。" }, this.JSS));
        }

        DTTables dtts = DTTables.JsonToDTTables(param.Suppliers);
        DataTable dt = dtts[BatchUpdateController.TableName].ToDataTable();   // RowState と Original が戻る

        SuppliersReturnValue rv = await this.CallLayerB("BatchUpdate", dt);
        if (rv.ErrorFlag) { return this.CreateErrorResponse(rv); }

        return this.Content(JsonConvert.SerializeObject(
            new { rv.InsertCount, rv.UpdateCount, rv.DeleteCount }, this.JSS));
    }

    // --- B層呼び出し（クレーム→ユーザ情報→DoBusinessLogicAsync。MVC と同じ） ---
    private async Task<SuppliersReturnValue> CallLayerB(string methodName, DataTable dt)
    {
        MyBaseAsyncApiController.GetClaims(out string userName, out _, out _, out string ipAddress);

        SuppliersParameterValue pv = new SuppliersParameterValue(
            "BatchUpdateController", "-", methodName, methodName, new MyUserInfo(userName, ipAddress));
        pv.Suppliers = dt;

        return (SuppliersReturnValue)await new SuppliersLayerB()
            .DoBusinessLogicAsync(pv, DbEnum.IsolationLevelEnum.DefaultTransaction);
    }

    // --- 業務エラーの応答（形を固定＝クライアントは camelCase で受ける） ---
    private ContentResult CreateErrorResponse(SuppliersReturnValue rv)
        => this.Content(JsonConvert.SerializeObject(
            new { rv.ErrorMessageID, rv.ErrorMessage, rv.ErrorInfo }, this.JSS));
}

// 本文 DTO（DTTables JSON を1個持つ）
public class BatchUpdateParams { public string Suppliers { get; set; } }
```

## Startup（要点だけ。`MVC_Sample/Startup.cs` と diff が取れる形にする）

```csharp
public Startup(IConfiguration configuration)
{
    Configuration = configuration;
    GetConfigParameter.InitConfiguration(configuration);   // ライブラリにも構成を渡す
}

public void ConfigureServices(IServiceCollection services)
{
    services._AddHttpContextAccessor();                    // HttpContext マイグレーション
    services.AddControllers().AddNewtonsoftJson();         // WebAPI（ビュー無し）＋Newtonsoft
    services.AddOpenApi();                                 // .NET9+ 標準（/openapi/v1.json）

    // ★ Cookie/セッション/認証ミドルウェアは登録しない（Bearer は [MyBaseAsyncApiController] が担う）。
    //   AddSession / AddDistributedMemoryCache / AddAuthentication+AddCookie / AddDataProtection は
    //   MVC_Sample からコメントアウトで残す＝Cookie 認証へ広げるときの手本。
}

public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
{
    // 転送ヘッダ（#549）：リバースプロキシで TLS 終端すると Request.IsHttps が false になる。
    //   appsettings の UseForwardedHeaders=on で X-Forwarded-Proto/-For を取り込む。★パイプライン先頭に置く。
    //   コンテナは既知プロキシを特定できない＝KnownIPNetworks/KnownProxies を Clear（範囲制限なし）。
    if (IsOn("UseForwardedHeaders")) { /* ForwardedHeadersOptions … app.UseForwardedHeaders(options); */ }

    if (env.IsDevelopment()) { app.UseDeveloperExceptionPage(); }
    else { app.UseHsts(); }   // ★ UseExceptionHandler("/Home/Error") は使わない（画面が無い＝JSON で返る）

    if (IsOn("UseHttpsRedirection")) { app.UseHttpsRedirection(); }   // on ならリダイレクト先ポートも要る

    app._UseHttpContextAccessor();
    app.UseRouting();

    // ★ UseAuthentication/UseAuthorization/UseSession/UseStaticFiles/UseCookiePolicy は使わない。
    app.UseCors(b => b.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());   // AllowCredentials は付けない

    app.UseEndpoints(endpoints =>
    {
        endpoints.MapControllers();
        endpoints.MapOpenApi();     // IDL を返す
    });
}

// appsettings（環境変数 appSettings__<キー> で上書き可・区切り __）
private static string GetValue(string key) => GetConfigParameter.GetConfigValue(key) ?? "";
private static bool IsOn(string key) => GetValue(key).ToLower() == "on";
```

## 注意

- コントローラの `using`／名前空間は導入プロジェクトに合わせる（`Logic.Business` 等はサンプルの例）。
- 認証ヘッダの種別（`EnumHttpAuthHeader`）はプロジェクトの要件で選ぶ（リソースサーバは `None | Bearer`）。Bearer トークンの発行元（IdP）連携は `opentouryo-oauth2-client`。
- `DataTable` 往復の詳細（`keepOriginal`・列属性は非保持・負値仮採番）は `opentouryo-batch-update`。非対話の疎通/実行検証は `opentouryo-project-setup-config` の `references/run-verify.md`。
