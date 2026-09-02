---
name: opentouryo-layer-p-mvc
description: "OpenTouryo の P層を ASP.NET MVC（net48）／ASP.NET Core MVC（net10.0）で実装する。コントローラの基底クラス（MyBaseMVController / MyBaseMVControllerCore）、アクションメソッドの書き方、ControllerName / ActionName / UserInfo プロパティ、引数クラスの MethodName（サンプルは ActionName を渡す）による B層の自動振り分け、フレームワークが提供するフィルタ（OnActionExecuting / OnActionExecutionAsync / OnException / MyMVCCoreFilterAttribute）、Forms 認証と Cookie 認証、Startup での構成を扱う。MVC / コントローラ / アクション / ASP.NET Core / Razor / 画面 / Web 画面 を伴う作業のときに使う。Web Forms は opentouryo-layer-p-webforms、Windows Forms は opentouryo-layer-p-winforms を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# P層（ASP.NET MVC / ASP.NET Core MVC）

> 📋 **コピー元スニペット**：`references/snippets.md`（コントローラ骨格・アクション・DoBusinessLogicAsync・net48/Core 差。実装時はここから写す）。

## このスキルの適用範囲

コントローラの実装。**ASP.NET MVC（net48）と ASP.NET Core MVC（net10.0）の両方**を扱う。

- Web Forms → `opentouryo-layer-p-webforms-screen` / `-event`
- Windows Forms（リッチクライアント）→ `opentouryo-layer-p-winforms-screen` / `-event`
  （WPF は P層フレームワークを持たない。B層・D層のみを利用する）
- B層の呼び出しの共通手順 → `opentouryo-p-call-business`
- B層の実装 → `opentouryo-layer-b`、例外 → `opentouryo-exception`
- ユーザ情報の詳細 → `opentouryo-auth`

## 最重要：MVC に UOC メソッドは無い

**Web Forms / Windows Forms とは実装モデルが根本的に違う。**

| | Web Forms / WinForms | **MVC** |
| --- | --- | --- |
| P層に書くもの | `UOC_FormInit` / `UOC_btnXXX_Click` などの UOC メソッド | **普通のアクションメソッド** |
| フレームワークの介入 | UOC メソッドの呼び出し | **MVC のフィルタ**（`OnActionExecuting` 等） |

**P層で `UOC_` で始まるメソッドを書かない。** アクションメソッドを普通に書けばよい。

`UOC_` が出てくるのは B層（`LayerB`）だけ（`opentouryo-layer-b` 参照）。

## MVC に無い Web Forms 専用のP層機能

**不正操作防止（Request Ticket）・二重送信防止・画面遷移制御・ブラウザ/ウィンドウ別 Session 領域は Web Forms 専用**（`BaseController` のみが生成・検出）。**MVC には無い**（`MyBaseMVController` は該当エラーが来たらセッションを解放しない防御コードだけを持つ）。
→ MVC では **CSRF は .NET 標準のアンチフォージェリ、二重送信/リロードは PRG・冪等化トークン**で自前対応する（`opentouryo-app-design/references/illegal-operation-prevention.md`）。
**例外＝キャッシュ制御（`FxCacheControl`）は MVC でも効く**（`MyBaseMVController`/`Core` が no-cache ヘッダを付与。`references/cache-control.md`）。

## 実装場所

| 階層 | net48 | net10.0 | 修正 |
| --- | --- | --- | --- |
| 画面コード親クラス1 | `BaseMVController` | `BaseMVControllerCore` | **不可**（バイナリ提供） |
| 画面コード親クラス2 | `MyBaseMVController` | `MyBaseMVControllerCore` + `MyMVCCoreFilterAttribute` | **不可**（バイナリ提供） |
| 画面コードクラス | 上記を継承したコントローラ | 同左 | **可**（ここに実装する） |

親クラス1・2 はビルド後のバイナリで提供されるため修正できない。以下の親クラス2 に関する記述は
**挙動を理解するためのもの**。

<!--
  注意: BaseMVController / BaseMVControllerCore の XML doc コメントは
  「画面コード親クラス２」となっているが、名前空間が Touryo.Infrastructure.Framework.Presentation
  （＝フレームワーク層）なので親クラス1。My* 版からのコピペ漏れと思われる。
  Web Forms（BaseController=親1 / MyBaseController=親2）と
  リッチクライアント（BaseControllerWin=親1 / MyBaseControllerWin=親2）は注記が正しい。
-->

## コントローラの書き方

`MyBaseMVControllerCore`（net48 は `MyBaseMVController`）を継承し、アクションで
引数クラス（コントロール名は `"-"`・`this.ControllerName`/`this.ActionName`/`this.UserInfo`）→
`DoBusinessLogicAsync` → `ErrorFlag` 判定 → `return View(model)`。
**コントローラ全文は `references/snippets.md`**。

### 使えるプロパティ

親クラス2 がリクエストごとに設定する。**自分で取得しない。**

| プロパティ | 中身 | 設定元 |
| --- | --- | --- |
| `this.ControllerName` | コントローラ名 | `RouteData` から自動設定 |
| `this.ActionName` | アクション名 | `RouteData` から自動設定 |
| `this.UserInfo` | `MyUserInfo` | セッション、無ければ認証チケットから復元 |

`this.UserInfo` は **null にならない**。未認証時は `UserName` が `"未認証"` になる。

## B層の呼び出し

引数クラスの組み立て・`DoBusinessLogic`・`ErrorFlag` の共通手順は `opentouryo-p-call-business`。

**B層の振り分けは常に「引数クラスに渡した `MethodName`」で決まる**（`UOC_` + `MethodName` をレイトバインド）。
これは処理方式によらず共通で、`MethodName` は**開発者が引数クラス生成時に渡す任意の文字列**（Web Forms/WinForms では
`"SelectCount"` のようなリテラルを渡す）。

```
new XxxParameterValue(screenId, controlId, methodName, actionType, user)
  → 渡した methodName が MethodName に入る
  → B層（MyFcBaseLogic）が "UOC_" + MethodName でレイトバインド
  → LayerB.UOC_<methodName>(...) が呼ばれる
```

**★ MVC サンプルは `methodName` に `this.ActionName` を渡している**（`new TestParameterValue(this.ControllerName,
"-", this.ActionName, ...)`）。だから「アクション名 = B層メソッド名」に見えるが、これは**サンプルの渡し方**であって
フレームワーク/MVC の強制仕様ではない（別のリテラルを渡してもよい）。サンプルに倣う場合は**アクション名と B層の
`UOC_` メソッド名を一致させる**（コンパイラは検出せず、綴りがズレると実行時に見つからない）。

引数クラスの第2引数（コントロール名）は `"-"` を渡す。MVC にコントロールの概念が無いため。

## フレームワークが自動で行うこと

親クラス2 が MVC のフィルタに乗って以下を行う。**アクションメソッドに書かない。**

- `ControllerName` / `ActionName` の取得（`RouteData` から）
- ユーザ情報のロード（`this.UserInfo`）
- カスタム認証・権限チェック・閉塞チェック（拡張ポイント。既定は空）
- キャッシュ制御（`FxCacheControl` 設定）
- 性能測定
- アクセスログの出力（`opentouryo-logging` 参照）
- 例外時のエラーログ出力とエラー画面への遷移（`FxErrorScreenPath` 設定）

### フィルタの構成がランタイムで違う

| | net48（`MyBaseMVController`） | net10.0（`MyBaseMVControllerCore`） |
| --- | --- | --- |
| アクション前後 | `OnActionExecuting` / `OnActionExecuted`（同期） | **`OnActionExecutionAsync`**（非同期・前後を統合） |
| 結果前後 | `OnResultExecuting` / `OnResultExecuted` | — |
| 例外処理 | `OnException` を `override` | **`MyMVCCoreFilterAttribute`**（`IExceptionFilter`） |

Core の `MyBaseMVControllerCore` には `[MyMVCCoreFilter()]` 属性が付いており、例外処理は
そちらへ分離されている。

net48 の `MyBaseMVController` は `View()` も `override` している。**アクセスログ
（`----->>` = ビューへ入る）を出すためで、ビューの動作自体は変えていない**（`base.View()` の
結果をそのまま返す）。**Core にはこのオーバーライドが無い。**

## 認証

**net48 は Forms 認証、Core は Cookie 認証。** ユーザ情報の保持（`MyUserInfo` +
`UserInfoHandle`）は共通。詳細は `opentouryo-auth`。

### net48（Forms 認証）

`web.config` に設定を書く。

```xml
<system.web>
  <authentication mode="Forms">
    <forms name="formauth" loginUrl="Home/Login" defaultUrl="Home" timeout="10" protection="All" ... />
  </authentication>
  <authorization>
    <deny users="?" />          <!-- 未認証ユーザをサイト全体で拒否 -->
  </authorization>
</system.web>
```

**`web.config` の `<authorization>` と `[Authorize]` の二段構え。** 属性だけではない。

```csharp
[HttpPost]
[AllowAnonymous]
[ValidateAntiForgeryToken]
public ActionResult Login(LoginViewModel model)
{
    // ① .NET 側：Forms 認証のチケットを生成
    FormsAuthentication.RedirectFromLoginPage(model.UserName, false);

    // ② OpenTouryo 側：ユーザ情報を保持
    MyUserInfo ui = new MyUserInfo(model.UserName, Request.UserHostAddress);
    UserInfoHandle.SetUserInformation(ui);

    return new EmptyResult();   // 基盤に任せるのでリダイレクトしない
}

[HttpGet]
public ActionResult Logout()
{
    FormsAuthentication.SignOut();
    return this.Redirect(Url.Action("Index", "Home"));
}
```

`RedirectFromLoginPage` の第2引数は Cookie を永続化するかどうか。**セキュリティを考慮して
`false` を推奨。**

### net10.0（Cookie 認証）

`FormsAuthentication` は存在しない。`ClaimsPrincipal` を作って `SignInAsync()` する。

```csharp
[HttpPost]
[AllowAnonymous]
[ValidateAntiForgeryToken]
public async Task<IActionResult> Login(LoginViewModel model)
{
    // ① .NET 側：ClaimsPrincipal を作ってサインイン
    List<Claim> claims = new List<Claim>();
    claims.Add(new Claim(ClaimTypes.Name, model.UserName));

    ClaimsIdentity userIdentity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
    ClaimsPrincipal userPrincipal = new ClaimsPrincipal(userIdentity);

    await AuthenticationHttpContextExtensions.SignInAsync(
        this.HttpContext, CookieAuthenticationDefaults.AuthenticationScheme, userPrincipal);

    // ② OpenTouryo 側：ユーザ情報を保持
    MyUserInfo ui = new MyUserInfo(model.UserName, (new GetClientIpAddress()).GetAddress());
    UserInfoHandle.SetUserInformation(ui);

    return View(model);
}

[HttpGet]
public async Task<IActionResult> Logout()
{
    await AuthenticationHttpContextExtensions.SignOutAsync(
        this.HttpContext, CookieAuthenticationDefaults.AuthenticationScheme);
    return this.Redirect(Url.Action("Index", "Home"));
}
```

`web.config` が無いので、認可は属性のみ。`[Authorize]` には `AuthenticationSchemes` の指定が要る。

## Core だけ Startup での構成が要る

net48 は `web.config` に書けば済むが、**Core は `Startup.cs` での構成が必須**。
**忘れてもコンパイルは通る。**

```csharp
public void ConfigureServices(IServiceCollection services)
{
    services._AddHttpContextAccessor();   // UserInfoHandle が依存する MyHttpContext 用
    services.AddSession();
    services.AddControllersWithViews();

    services.AddAuthentication(options =>
    {
        options.DefaultChallengeScheme    = CookieAuthenticationDefaults.AuthenticationScheme;
        options.DefaultSignInScheme       = CookieAuthenticationDefaults.AuthenticationScheme;
        options.DefaultAuthenticateScheme = CookieAuthenticationDefaults.AuthenticationScheme;
    })
    .AddCookie(CookieAuthenticationDefaults.AuthenticationScheme, options =>
    {
        options.LoginPath          = new PathString("/Home/Login");
        options.AccessDeniedPath   = new PathString(GetConfigParameter.GetConfigValue("FxErrorScreenPath"));
        options.ReturnUrlParameter = "ReturnUrl";
    });
}

public void Configure(IApplicationBuilder app, ...)
{
    app._UseHttpContextAccessor();   // MyHttpContext を初期化する
    app.UseSession(new SessionOptions() { ... });
    app.UseAuthentication();
    app.UseAuthorization();
    app.UseEndpoints(...);
}
```

さらに構成の初期化も要る（`opentouryo-config` 参照）。

```csharp
GetConfigParameter.InitConfiguration(configuration);
```

**`_AddHttpContextAccessor()` / `_UseHttpContextAccessor()` は OpenTouryo の拡張メソッド**
（`Touryo.Infrastructure.Framework.StdMigration`）。`UserInfoHandle` が内部で
`MyHttpContext.Current.Session` を見るため、呼ばないと動かない。**先頭の `_` は誤記ではない。**

## net48 と net10.0 の差（まとめ）

| | net48 | net10.0 |
| --- | --- | --- |
| 親クラス1 / 2 | `BaseMVController` / `MyBaseMVController` | `BaseMVControllerCore` / `MyBaseMVControllerCore` |
| 認証 | Forms 認証 | Cookie 認証 |
| 認可 | `web.config` + `[Authorize]` | `[Authorize(AuthenticationSchemes = ...)]` のみ |
| 構成の置き場 | `web.config` | `Startup.cs` / `appsettings.json` |
| IP アドレス | `Request.UserHostAddress` | `(new GetClientIpAddress()).GetAddress()` |
| ユーザ名の取得元 | `Thread.CurrentPrincipal.Identity.Name` | `AuthenticateAsync(...).Principal?.Identity?.Name` |
| セッション | 自動 | `AddSession()` + `UseSession()` が必要 |
| `MyHttpContext` | 不要 | `_AddHttpContextAccessor()` / `_UseHttpContextAccessor()` が必要 |
| 構成の初期化 | 不要 | `GetConfigParameter.InitConfiguration()` が必要 |

## ビュー（`.cshtml`）の落とし穴（net48 特有・ランタイム非対称）

**Razor のコンパイル時期がランタイムで違う**：**net48 は実行時コンパイル**（`.aspx`/`.master` と同じ）、
**Core は `dotnet build` 時に Razor SDK がコンパイル**。だから次の罠は **net48 MVC だけ**に出る（Core は build/実行で早期に露見する）。

- **★ net48 の `.cshtml` は msbuild で検証されない＝`aspnet_compiler` で事前検証する。** Razor 構文エラー
  （例 `@if { … @for(…) }` の不要 `@`）は **`msbuild` は Build OK**・**実行しても 500 にならず本文だけ空描画**（レイアウトは出る＝一見動く）。
  `aspnet_compiler` で初めて `ASPPARSE:"@" 文字の後に予期しない…` を検出できる（`.aspx` は 500 になるぶん、`.cshtml` は白画面で発見が遅れる）。
- **★ `@section` の中身は `@RenderBody()` の外に描画される。** レイアウトの `@RenderSection` 位置に出るため、ビューで
  `Html.BeginForm` の `using` ブロック内に置いても、生成 HTML では `<form>` の**外**に出る。`type="submit"` はフォーム外だと
  **押しても何も起きない**（実測：フッタ［件数確認］が無反応）。→ **`@section` に置く submit には HTML5 の `form="<フォームID>"` を付けて明示的に紐付ける**。
  Web Forms は `<form runat="server">` がマスタページ全体を包むので起きない＝**MVC 固有**。検証は `references/run-verify.md`（アクション URL への直接 POST だけで判定しない）。
- **★ net48 MVC のビューは UTF-8 BOM が必須**（`.cshtml`）。net48 MVC の `Web.config` には **`<globalization fileEncoding>` が無く**
  （WebForms サンプルには有る）、BOM 無し UTF-8 を実行時 Razor が OS コードページ（Shift-JIS）で誤読して**画面テキストが文字化け**する。
  しかも CP932 の2バイト目が直後の ASCII（`</button>` の `<` 等）を食ってタグを壊し**ボタンも動かなくなる**——ビルドも `aspnet_compiler` も素通りする。`opentouryo-comment-convention`。

## やってはいけないこと

- **P層に `UOC_` メソッドを書く** — MVC に UOC は無い。アクションメソッドを書く
- **アクション名と B層の `UOC_` メソッド名がズレる** — レイトバインドなのでコンパイルは通り、
  実行時に見つからない
- **`this.ControllerName` / `this.ActionName` / `this.UserInfo` を自分で取得する** —
  親クラス2 が設定済み
- **`this.UserInfo` の null チェックを書く** — 必ず埋まる。未認証時は `UserName` が `"未認証"`
- **アクションメソッドで例外を `catch` してエラー画面へ遷移する** — 親クラス2 が行う
- **業務例外を `catch` する** — 戻り値で返る（`opentouryo-exception` 参照）
- **net48 で `web.config` の `<authorization>` を消して `[Authorize]` だけにする** — 二段構え
- **Core で `FormsAuthentication` を使う** — 存在しない
- **Core で `Request.UserHostAddress` を使う** — 存在しない。`GetClientIpAddress` を使う
- **Core で `_AddHttpContextAccessor()` / `_UseHttpContextAccessor()` を呼び忘れる** —
  `UserInfoHandle` が動かない。コンパイルは通る
