---
name: opentouryo-auth
description: "OpenTouryo で認証済みユーザの情報を保持する。ユーザ情報クラス（UserInfo / MyUserInfo）、UserInfoHandle によるセッションへの格納・取得（SetUserInformation / GetUserInformation / DeleteUserInformation）、.NET の認証との組み合わせ方、ログインから P層・B層へユーザ情報が流れる経路を扱う。P層フレームワークごとの差異（Web Forms と MVC は Forms 認証、ASP.NET Core MVC は Cookie 認証 + ClaimsPrincipal + Startup での構成）と、net48 / net10.0 の API 差も扱う。認証 / ログイン / ログアウト / ユーザ情報 / MyUserInfo / UserInfoHandle / セッション / Forms認証 / Cookie認証 / ClaimsPrincipal / FormsAuthentication を伴う作業のときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 認証とユーザ情報

> 📋 **コピー元**：`references/snippets.md`（UserInfoHandle・MyUserInfo・認証方式差）。

## このスキルの適用範囲

**OpenTouryo の認証実装の主眼は「認証済みユーザの情報をどう保持するか」。** 認証そのものの
仕組みは提供せず、Web では **.NET の認証・セッション維持の仕組みと組み合わせて使う**。

このスキルは、その「ユーザ情報の保持」と「.NET の認証との組み合わせ方」を扱う。
OpenTouryo を使う全アプリケーションが対象。

- 認可（権限チェック）→ P層 の親クラス2 に実装箇所がある（P層のスキルを参照）
- 設定値の読み方 → `opentouryo-config`

## ユーザ情報クラス

| 階層 | クラス | 担当 | 中身 |
| --- | --- | --- | --- |
| ユーザ情報親クラス1 | `UserInfo`（`Touryo.Infrastructure.Framework.Util`） | フレームワーク | **空のクラス**。マーカーとしてのみ存在 |
| ユーザ情報親クラス2 | `MyUserInfo`（`Touryo.Infrastructure.Business.Util`） | 纏め者 | **テンプレートは `UserName` / `IPAddress` の2つだけ**。プロジェクトが項目を追加する |

`UserInfo` は本当に `public class UserInfo { }` で中身がない。実体は `MyUserInfo` にある。

### 既定のテンプレートが持つ項目は2つだけ

既定は `UserName` / `IPAddress` の2プロパティのみ（`[Serializable()]`・`MyUserInfo(userName, ipAddress)`。骨格は `references/snippets.md`）。

**どちらも setter を持つ。** 生成後に代入できる（Windows Forms のログインはこれを使う。
`opentouryo-layer-p-winforms-screen` 参照）。

`<remarks>` に「自由に（**拡張して**）利用できる。」とあるとおり、
**プロジェクト固有の項目（所属、権限、ロールなど）を足す前提のテンプレート。**

### 足すのは整備する側

**このプロジェクトでは項目が増えている可能性がある。** `UserName` / `IPAddress` しか無いと
決めつけず、実際の `MyUserInfo` を確認すること（→ `opentouryo-project-policy`）。
項目は P層・B層のどこからでも参照できる。

ただし**足せるのは纏め者だけ。** 親クラス2 はバイナリで提供されるため、ユーザプログラム
開発プロジェクトでは項目を追加できない。新しい項目が必要に見える場合は、引数クラス
（`MyParameterValue` の派生）で渡せないかを先に検討し、それでも必要なら人に相談すること。

**`[Serializable()]` が付いている。** core 系ではセッションへ JSON シリアライズされるため
（後述）、拡張する側もシリアライズ可能な型に限る。

## UserInfoHandle（セッションへの出し入れ）

`UserInfoHandle`（`Touryo.Infrastructure.Framework.Util`）が**セッション**に読み書きする。
セッション キーは `AuthenticationUserInformation`。

| メソッド | 用途 |
| --- | --- |
| `SetUserInformation(userInfo)` | セッションへ格納（ログイン時） |
| `GetUserInformation<T>()` | セッションから取得（**net10.0 専用**） |
| `GetUserInformation()` | セッションから取得（**net48 専用**） |
| `DeleteUserInformation()` | セッションから削除（ログアウト時） |

### 取得 API がランタイムで違う

**同名だがシグネチャが違い、`#if` で切り替わる**（net10.0＝`GetUserInformation<MyUserInfo>()`、net48＝
`(MyUserInfo)GetUserInformation()`）。両対応のコードを書くときの罠。コードは `references/snippets.md`。

内部の保存方式も違う。

| | net48 | net10.0 |
| --- | --- | --- |
| 保存 | `Session[key]` にオブジェクトのまま | **JSON にシリアライズ** |
| 取得 | キャスト | JSON からデシリアライズ |

## ユーザ情報の流れ

```
【ログイン時】アプリケーションのログイン処理
    new MyUserInfo(userName, ipAddress)
    UserInfoHandle.SetUserInformation(ui)      → セッションへ

【リクエストごと】P層の親クラス2（フレームワーク）
    this.UserInfo = UserInfoHandle.GetUserInformation<MyUserInfo>()
                                               → コントローラの UserInfo プロパティへ

【B層呼び出し時】開発者が書く
    new TestParameterValue(..., this.UserInfo) → 引数クラスへ

【B層】
    myPV.User.UserName                         → アクセスログ等で使われる
```

**P層でのセッションからの取り出しはフレームワークが行う。** 開発者は
`this.UserInfo`（コントローラのプロパティ）を引数クラスへ渡すだけ。

## .NET の認証と組み合わせる

**ログインでは2つのことを両方やる。** 片方だけでは動かない。

| | 何をするか | 仕組み |
| --- | --- | --- |
| ① .NET 側 | 認証状態を維持する | ASP.NET Core の Cookie 認証（`ClaimsPrincipal` + `SignInAsync`） |
| ② OpenTouryo 側 | ユーザ情報を保持する | `MyUserInfo` + `UserInfoHandle`（セッション） |

**この2つは別物。** ① は「認証済みかどうか」、② は「フレームワークが使うユーザ情報」。
OpenTouryo は ① を提供しないので、.NET の仕組みを使う。

- ① だけ → 認証は通り、`this.UserInfo` も**認証チケットから復元される**。ただし
  **`UserName` と `IPAddress` しか埋まらない**（後述）
- ② だけ → 認証状態が維持されない

### ユーザ情報は認証チケットから復元される

P層の親クラス2 は、リクエストごとに以下を行う。**3方式とも同じ。**

```
Session が無効 → 何もしない
Session が有効
  UserInfoHandle.GetUserInformation() を試みる
    取れた   → それを使う
    null だった
      認証チケットからユーザ名を取る
        net48 : System.Threading.Thread.CurrentPrincipal.Identity.Name
        Core   : AuthenticateAsync(...).Principal?.Identity?.Name
      ユーザ名が空 → new MyUserInfo("未認証", IP)   ※セッションには入れない
      ユーザ名あり → new MyUserInfo(ユーザ名, IP) + SetUserInformation() で復元
```

**したがって `this.UserInfo` が null になることはない**（セッションが有効なら）。
未認証なら `UserName` が `"未認証"` になる。

**それでもログイン時に `SetUserInformation()` を呼ぶ理由は、復元では `UserName` と
`IPAddress` しか埋まらないため。** プロジェクト固有の項目（所属、権限など）を持たせるには、
ログイン時に完全な `MyUserInfo` を作ってセッションへ入れる必要がある。

親クラス2 の復元処理には「★ 必要であれば、他の業務共通引継ぎ情報などをロードする」という
拡張ポイントがあるが、既定のテンプレートでは実装されていない。**ここを実装するかは
親クラス2 を整備する側の判断**で、ユーザプログラム開発プロジェクトからは変えられない。

### P層フレームワークごとの差異

<!--
  ■ 執筆者向け：分配は完了済み（このスキルは約4,950トークンで目安5,000内）。
    各方式の実装詳細は P層スキルへ分配した:
      Web Forms  → opentouryo-layer-p-webforms-screen
      MVC / Core → opentouryo-layer-p-mvc（net48 / net10.0 のランタイム差として1スキル）
      WinForms   → opentouryo-layer-p-winforms-screen（static ユーザ情報）
    この節（下の比較表と ①②③ の要約）は「どのスキルを読めばよいか」の地図として意図的に残す。
    MyUserInfo / UserInfoHandle・ユーザ情報の流れ・「.NET 認証＋OpenTouryo ユーザ情報の両方が必要」
    という原則は3方式共通なのでこのスキルが本体。
-->

**② の `MyUserInfo` + `UserInfoHandle` は3方式で共通。① の .NET 側だけが違う。**

| | ① Web Forms（net48） | ② MVC（net48） | ③ ASP.NET Core MVC（net10.0） |
| --- | --- | --- | --- |
| コントローラの基底 | `MyBaseController` | `MyBaseMVController` | `MyBaseMVControllerCore` |
| .NET 側の認証 | **Forms 認証** | **Forms 認証**（①と同じ） | **Cookie 認証** |
| 認証の構成 | `web.config` の `<authentication mode="Forms">` | **①と同じ**（`loginUrl` / `defaultUrl` の値のみ違う） | `Startup.cs` の `AddAuthentication()` + `AddCookie()` |
| サインイン | `FormsAuthentication.RedirectFromLoginPage(userName, false)` | ①と同じ | `ClaimsPrincipal` を作り `SignInAsync()` |
| サインアウト | `FormsAuthentication.SignOut()` | ①と同じ | `SignOutAsync()` |
| 認可（サイト全体） | `web.config` の `<authorization>` に `<deny users="?" />` | **①と同じ** | — （`web.config` が無い） |
| 認可（個別） | `<location path="...">` で**パス単位** | `[Authorize]` / `[AllowAnonymous]` で**コントローラ・アクション単位** | ②と同じ（ただし `AuthenticationSchemes` の指定が要る） |
| IP アドレスの取得 | `Request.UserHostAddress` | ①と同じ | `(new GetClientIpAddress()).GetAddress()` |
| ログイン画面の実装単位 | `login.aspx.cs` の `UOC_btnXXX_Click` | `HomeController.Login` アクション | ②と同じ |

**① と ② は .NET 側の認証がまったく同じ**（Forms 認証、`web.config` の設定も同一）。
違うのは**実装をどこに書くか**（`UOC_btnXXX_Click` かコントローラのアクションか）と、
**個別の認可をどう指定するか**（`<location>` か属性か）。

断層は **net48 と Core の間**にある。Core には Forms 認証も `web.config` も無い。

### ① Web Forms（net48）

**詳細は `opentouryo-layer-p-webforms-screen` を参照。** ログイン画面の実装例、`web.config` の
構成をそちらに記述している。

要点だけ再掲する。

- **Forms 認証**。`web.config` の `<authentication mode="Forms">` + `<authorization>` で設定する
- ログイン画面は `IsNoSession = true` をコンストラクタで設定し、`UOC_FormInit` で
  `FxSessionAbandon()` を呼ぶ
- サインインは `FormsAuthentication.RedirectFromLoginPage(userName, false)`
- 認可はサイト全体が `<authorization><deny users="?" /></authorization>`、
  パス単位の例外は `<location path="...">`

### ② MVC（net48）／③ ASP.NET Core MVC（net10.0）

**詳細は `opentouryo-layer-p-mvc` を参照。** 実装例、`web.config` と `Startup.cs` の構成、
net48 と net10.0 の差をそちらに記述している。

要点だけ再掲する。

- **net48 MVC は Forms 認証**。`web.config` の記述は Web Forms と同一。認可は
  `<authorization>` と `[Authorize]` の二段構え
- **Core MVC は Cookie 認証**。`FormsAuthentication` は存在しない。`ClaimsPrincipal` を作って
  `SignInAsync()` する。`web.config` が無いので認可は属性のみ
- **Core だけ `Startup.cs` での構成が必須**。`services._AddHttpContextAccessor()` /
  `app._UseHttpContextAccessor()` を呼ばないと `UserInfoHandle` が動かない（コンパイルは通る）
- **Core に `Request.UserHostAddress` は無い**。`GetClientIpAddress` を使う


### 認証方式そのものは問わない

パスワード照合でも、外部 IdP から受け取った情報でも、最後に `MyUserInfo` を作って
セッションへ入れれば、以降のフレームワークの仕組みは同じように動く。

### セッションの破棄は「ログイン画面に入るとき」

**ログアウト処理はセッションを消さない。** 3方式とも `Logout` は .NET 側のサインアウトだけで、
`UserInfoHandle.DeleteUserInformation()` を呼んでいない。

代わりに**ログイン画面に入る時点で `FxSessionAbandon()` を呼んでセッションごと消す**設計。
セッションが消えればユーザ情報も消えるため、`DeleteUserInformation()` は通常不要。

```csharp
// Web Forms: login.aspx.cs（login.aspx はサンプル画面名。自プロジェクトのログイン画面に読み替える）
protected override void UOC_FormInit()
{
    this.FxSessionAbandon();   // セッション消去
}

// net48 MVC: HomeController.Login（GET）
public ActionResult Login()
{
    this.FxSessionAbandon();
    ...
}
```

`FxSessionAbandon()` は3方式すべての親クラス1 が提供する。
**セッション タイムアウト検出用 Cookie の削除とセッションの消去**をまとめて行う。

**★ ログイン画面の Session タイムアウト対策3択**（P層FW非使用／`IsNoSession=true`／`FxSessionAbandon`）は `references/snippets.md`。

| | 実装 |
| --- | --- |
| Web Forms / net48 MVC | Cookie 削除 + **`Session.Abandon()`**（セッションを破棄） |
| ASP.NET Core MVC | Cookie 削除 + **`Session.Clear()`**（中身を消すがセッションは残る） |

Core だけ `Clear()` なのは、`ISession` に `Abandon()` が無いため。

<!--
  注意: Core のサンプル（Samples4NetCore の HomeController.Login）では
  FxSessionAbandon() の呼び出しが**コメントアウトされている**（98行目・152行目）。
  net48 MVC のサンプルでは有効（95行目・142行目）。
  Core で意図的に外しているのか、移植時の漏れなのかは不明。
-->

## OAuth2 / OIDC / SAML2 について

`Touryo.Infrastructure.Framework.Authentication` に OAuth2 / OIDC / SAML2 のクライアント・
サーバ実装（`OAuth2AndOIDCClient` / `SAML2Client` など）がある。

**これらはサブプロダクトの汎用認証サイト（MultiPurposeAuthSite）用に開発されたもので、
OpenTouryo でアプリケーションを作る際の標準的な認証手段ではない。**

ただし**アプリケーション側から外部 IdP と連携する（クライアント＝RP になる）用途には使える。**
サンプルにも実装がある。→ **`opentouryo-oauth2-client`**

その場合も**最後にやることは同じ**（.NET 側の認証 + `MyUserInfo` をセッションへ）。
外部 IdP から受け取った `sub` がユーザ名になるだけ。

SAML2 クライアント機能（`SAML2Client` / `SAML2Bindings`）もあるが、スキル化していない。

## セッションが前提（Web のみ）

`UserInfoHandle` はセッションに依存する。**セッションを使わない構成では成立しない。**
Web の P層フレームワーク（Web Forms / MVC / ASP.NET Core MVC）を使う場合、セッションは必須。

### リッチクライアントは別（このスキルの対象外）

**Windows Forms（リッチクライアント）は `UserInfoHandle` もセッションも使わない。**
`MyBaseControllerWin.UserInfo`（`static` フィールド）でユーザ情報を保持し、
.NET の認証機構も使わない。詳細は `opentouryo-layer-p-winforms-screen` を参照。

WPF は P層フレームワークを持たないため、ユーザ情報の保持方法もアプリケーション側で決める。

このスキルの記述は **Web 系（Web Forms / MVC / ASP.NET Core MVC）が対象**。

## やってはいけないこと

- **セッションから直接ユーザ情報を読む** — `UserInfoHandle` を経由する。
  ランタイム差（JSON シリアライズの有無）を吸収している
- **`MyUserInfo` に項目を足そうとする** — 親クラス2 はバイナリで提供される。
  既存の項目を使うか、引数クラスで渡す
- **net48 向けコードで `GetUserInformation<T>()` を使う** — core 系専用。逆も同様
- **B層で `UserInfoHandle` からユーザ情報を取る** — 引数クラス経由で受け取る。
  B層がセッション（＝ P層の関心事）に依存してはならない
- **P層で毎回 `UserInfoHandle.GetUserInformation()` を呼ぶ** — 親クラス2 が取得済み。
  コントローラの `this.UserInfo` を使う
- **`UserInfo` / `MyUserInfo` を編集しようとする** — どちらもバイナリで提供される親クラス。
  ソースが無い
- **ログインで .NET 側のサインインだけ、または `SetUserInformation` だけを書く** — 両方必要。
  サインインだけだと `UserName` / `IPAddress` しか復元されず、プロジェクト固有の項目が欠ける。
  `SetUserInformation` だけだと認証状態が維持されない
- **`this.UserInfo` の null チェックを書く** — 親クラス2 が必ず埋める。
  未認証時は `UserName` が `"未認証"` になる（null ではない）
- **P層フレームワークを取り違える** — Web Forms / MVC（net48）は **Forms 認証**、
  ASP.NET Core MVC は **Cookie 認証**。`FormsAuthentication` は Core に存在しない
- **net48 MVC で `web.config` の `<authorization>` を消して `[Authorize]` だけにする** —
  両方使う二段構え。`<authorization>` は Web Forms と同一の設定で、サイト全体に効く
- **Core MVC で `Request.UserHostAddress` を使う** — 存在しない。`GetClientIpAddress` を使う
- **Core MVC で `_AddHttpContextAccessor()` / `_UseHttpContextAccessor()` を呼び忘れる** —
  `UserInfoHandle` が `MyHttpContext.Current.Session` に依存しているため動かない
- **OpenTouryo が認証機構そのものを提供すると考える** — 認証状態の維持は .NET の仕組みを使う。
  OpenTouryo が持つのは認証済みユーザ情報の保持
