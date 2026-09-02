---
name: opentouryo-oauth2-client
description: "OpenTouryo のアプリケーションを外部 IdP と連携させる（OAuth2 / OIDC のクライアント＝RP として実装する）。認可コードグラントの流れ、認可エンドポイントへのリダイレクト（client_id / response_type / scope / state / nonce / redirect_uri）、OAuth2AndOIDCClient.GetAccessTokenByCodeAsync によるトークン取得、IdToken.Verify による id_token の検証、state / nonce による CSRF 対策、GetUserInfoAsync による userinfo の取得、CmnClientParams / OAuth2AndOIDCParams の設定、コールバック画面を認可から除外する設定を扱う。外部IdP / 外部ログイン / OAuth2 / OIDC / OpenID Connect / 認可コード / 認可コードグラント / id_token / アクセストークン / シングルサインオン / 汎用認証サイト との連携 を伴う作業のときに使う。ユーザ情報の保持そのものは opentouryo-auth を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 外部 IdP 連携（OAuth2 / OIDC クライアント）

## このスキルの適用範囲

**アプリケーションを OAuth2 / OIDC のクライアント（RP）にして、外部 IdP でログインさせる。**
認可コードグラントの実装を扱う。

- ユーザ情報の保持（`MyUserInfo` / `UserInfoHandle`）→ `opentouryo-auth`
- 画面の実装 → `opentouryo-layer-p-webforms-screen` / `opentouryo-layer-p-mvc`

**SAML2 クライアント機能（`SAML2Client` / `SAML2Bindings`）もあるが、このスキルは扱わない。**

<!-- TODO: SAML2 で連携する方針になったら、別スキルとして起こすこと。 -->

## 最後にやることは通常のログインと同じ

**外部 IdP を使っても、認証が成功したあとの処理は変わらない。**
.NET 側の認証と OpenTouryo のユーザ情報の**両方**を設定する（`opentouryo-auth` 参照）。

外部 IdP から受け取った `sub`（OIDC の subject）がユーザ名になる。

## 認可コードグラントの流れ

```
① ログイン画面の「外部ログイン」→ IdP の認可エンドポイントへリダイレクト
     client_id / response_type=code / scope / state / nonce / redirect_uri を付ける
② IdP で認証・同意
③ IdP が redirect_uri へ code と state を返す（＝コールバック画面）
④ state を検証する（CSRF 対策。必須）
⑤ GetAccessTokenByCodeAsync で code をトークンに交換
⑥ IdToken.Verify で id_token を検証し、nonce も突き合わせる
⑦ 必要なら GetUserInfoAsync で userinfo を取得
⑧ .NET 側の認証 + MyUserInfo をセッションへ（＝通常のログインと同じ）
```

## ① 認可エンドポイントへリダイレクトする

### Web Forms

**イベントハンドラの戻り値（遷移先 URL）をそのまま使う。**

```csharp
protected string UOC_btnButton2_Click(FxEventArgs fxEventArgs)
{
    return CmnClientParams.SpRp_AuthRequestUri
        + "?client_id=" + OAuth2AndOIDCParams.ClientID
        + "&response_type=code"
        + "&scope=profile%20email%20phone%20address%20roles%20openid"
        + "&state=" + this.State
        + "&nonce=" + this.Nonce
        + "&redirect_uri=" + CustomEncode.UrlEncode(CmnClientParams.SpRp_RedirectUri)
        + "&prompt=none";
}
```

### ASP.NET Core MVC

```csharp
return Redirect(string.Format(
    CmnClientParams.SpRp_AuthRequestUri
    + "?client_id=" + OAuth2AndOIDCParams.ClientID
    + "&response_type=code"
    + "&scope=profile%20email%20phone%20address%20openid"
    + "&state={0}"
    + "&nonce={1}"
    + "&prompt=none"
    + "&redirect_uri={2}",
    this.State, this.Nonce,
    CustomEncode.UrlEncode(CmnClientParams.SpRp_RedirectUri)));
```

`redirect_uri` は **`CustomEncode.UrlEncode()` で URL エンコードする。**

## state / nonce はセッションで持つ

**CSRF 対策の要。** 生成してセッションに保持し、コールバックで突き合わせる。

```csharp
public string State
{
    get
    {
        if (Session["state"] == null)
        {
            Session["state"] = GetPassword.Base64UrlSecret(10);
        }
        return (string)Session["state"];
    }
}
// Nonce も同様に Session["nonce"] で持つ
```

`GetPassword.Base64UrlSecret(10)`（`Touryo.Infrastructure.Public.Security.Pwd`）で生成する。

## ③④ コールバック画面

### 認可から除外する（忘れると動かない）

**コールバック時点では未認証。** 認可設定から除外しないと IdP からの戻りを受け取れない。

Web Forms は `web.config` の `<location>` で開ける。

```xml
<location path="Aspx/OAuth2">
  <system.web>
    <authorization><allow users="*" /></authorization>
  </system.web>
</location>
```

MVC は `[AllowAnonymous]` を付ける。

```csharp
[HttpGet]
[AllowAnonymous]
public async Task<ActionResult> OAuth2AuthorizationCodeGrantClient(string code, string state)
```

### Web Forms のコールバック画面は素の Page

サンプルのコールバック画面（`OAuth2AuthorizationCodeGrantClient.aspx.cs`＝サンプル固有名。自プロジェクトでは
任意の画面名でよい）は **`System.Web.UI.Page` を継承していて、`MyBaseController` ではない。**

```csharp
public partial class OAuth2AuthorizationCodeGrantClient : System.Web.UI.Page
{
    protected async void Page_Load(object sender, EventArgs e)
```

P層フレームワークのイベント処理機能を使わず、`Page_Load` で `code` / `state` を受けるだけの
画面だから。

## ⑤⑥⑦ トークン取得と検証

**両ランタイムで同じ。**

```csharp
using Touryo.Infrastructure.Framework.Authentication;

string code  = Request.QueryString["code"];    // MVC は引数で受ける
string state = Request.QueryString["state"];

if (state == this.State)   // ★ CSRF(XSRF)対策の state の検証は重要
{
    // ⑤ code をトークンに交換
    string response = await OAuth2AndOIDCClient.GetAccessTokenByCodeAsync(
        new Uri(CmnClientParams.SpRp_TokenRequestUri),
        OAuth2AndOIDCParams.ClientID, OAuth2AndOIDCParams.ClientSecret, "", code);

    Dictionary<string, string> dic =
        JsonConvert.DeserializeObject<Dictionary<string, string>>(response);

    // ⑥ id_token を検証し、nonce も突き合わせる
    string sub = "";
    string nonce = "";
    JObject jobj = null;

    if (IdToken.Verify(dic["id_token"], dic["access_token"],
        code, state, out sub, out nonce, out jobj) && nonce == this.Nonce)
    {
        // ⑦ 必要なら userinfo エンドポイントへ
        response = await OAuth2AndOIDCClient.GetUserInfoAsync(
            new Uri(CmnClientParams.SpRp_UserInfoUri), dic["access_token"]);

        // ⑧ 以降はログイン処理（後述）
    }
}
```

**`state` の検証と `nonce` の突き合わせは省かない。** サンプルにも
`// CSRF(XSRF)対策のstateの検証は重要` と明記されている。

`IdToken.Verify()` は `id_token` の検証に加えて `sub` / `nonce` / クレーム（`JObject`）を
`out` で返す。**戻り値の `bool` と `nonce == this.Nonce` の両方**を確認する。

## ⑧ ログイン処理

**通常のログインと同じ。** `sub` をユーザ名として、.NET 側の認証と `MyUserInfo` の両方を設定する。

### Web Forms / MVC（net48・Forms 認証）

```csharp
FormsAuthentication.RedirectFromLoginPage(sub, false);

MyUserInfo ui = new MyUserInfo(sub, Request.UserHostAddress);
UserInfoHandle.SetUserInformation(ui);
```

### ASP.NET Core MVC（Cookie 認証）

```csharp
List<Claim> claims = new List<Claim>();
claims.Add(new Claim(ClaimTypes.Name, sub));

ClaimsIdentity userIdentity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
ClaimsPrincipal userPrincipal = new ClaimsPrincipal(userIdentity);

await AuthenticationHttpContextExtensions.SignInAsync(
    this.HttpContext, CookieAuthenticationDefaults.AuthenticationScheme, userPrincipal);

MyUserInfo ui = new MyUserInfo(sub, (new GetClientIpAddress()).GetAddress());
UserInfoHandle.SetUserInformation(ui);

return this.Redirect(Url.Action("Index", "Home"));
```

## 設定

`appSettings` に書く（`opentouryo-config` 参照）。コードからは以下のクラス経由で読む。

| クラス | プロパティ | 内容 |
| --- | --- | --- |
| `CmnClientParams` | `SpRp_AuthRequestUri` | 認可エンドポイント |
| | `SpRp_TokenRequestUri` | トークンエンドポイント |
| | `SpRp_UserInfoUri` | userinfo エンドポイント |
| | `SpRp_RedirectUri` | コールバック URL（`redirect_uri`） |
| | `RsaCerFilePath` ほか | 証明書のパス |
| `OAuth2AndOIDCParams` | `ClientID` | クライアントID |
| | `ClientSecret` | クライアントシークレット |

`CmnClientParams` は `Touryo.Infrastructure.Framework.Authentication`。SAML2 / OAuth2・OIDC /
FAPI で共用する。

### 起動時に HttpClient の設定が要る（Framework / Core 共通）

```csharp
// アプリ起動時に一度だけ設定する
//   Framework（ASP.NET）… Global.asax の Application_Start
//   Core（ASP.NET Core）… Startup / Program
//   リッチクライアント／CLI … Login や Program.Main
OAuth2AndOIDCClient.HttpClient = new HttpClient();
```

**設定しないと通信できない**（`OAuth2AndOIDCClient._HttpClient` は既定 `null`＝遅延生成しない。net48 サンプルの `Global.asax` でも設定している）。

## OAuth2AndOIDCClient の他の機能

サンプルは**認可コードグラント**だけを使っているが、`OAuth2AndOIDCClient` は他のグラント・
拡張も持つ。

`ClientCredentialsGrantAsync` / `ResourceOwnerPasswordCredentialsGrantAsync` /
`UpdateAccessTokenByRefreshTokenAsync` / `RevokeTokenAsync` / `IntrospectTokenAsync` /
`JwtBearerTokenFlowAsync` / `DeviceAuthZRequestAsync` / `CibaAuthZRequestAsync` /
`PKCE_S256_CodeChallengeMethod` / `GetJwkSetAsync` など。

<!-- TODO: 認可コードグラント以外を使う方針なら、その手順をここに追記する。 -->

## やってはいけないこと

- **`state` の検証を省く** — CSRF(XSRF) 対策。サンプルにも「重要」と明記されている
- **`nonce` の突き合わせを省く** — `IdToken.Verify()` の戻り値だけでは不十分。
  `nonce == this.Nonce` も確認する
- **コールバック画面を認可から除外し忘れる** — 未認証で戻ってくるので受け取れない
  （Web Forms は `<location>`、MVC は `[AllowAnonymous]`）
- **`redirect_uri` を URL エンコードせずに渡す** — `CustomEncode.UrlEncode()` を使う
- **`state` / `nonce` をセッション以外で持つ** — 突き合わせができなくなる
- **外部 IdP でログインしたら `MyUserInfo` の設定が不要と考える** — 通常のログインと同じで、
  .NET 側の認証と `MyUserInfo` の**両方**が要る（`opentouryo-auth` 参照）
- **起動時に `OAuth2AndOIDCClient.HttpClient` の設定を忘れる** — 既定 `null` で通信できない。Framework/Core とも要る
  （Framework は `Global.asax`、Core は `Startup`/`Program`）
