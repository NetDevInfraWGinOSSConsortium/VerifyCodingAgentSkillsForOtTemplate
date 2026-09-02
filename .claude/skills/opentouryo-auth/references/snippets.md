# 認証・ユーザ情報 コードスニペット（コピー元）

出典：UserGuide 纏め者編 §2.1／共通編、`Framework/Util/UserInfoHandle.cs`・`Business/Util/MyUserInfo.cs`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## ユーザ情報の格納・取得（UserInfoHandle）

```csharp
using Touryo.Infrastructure.Framework.Util;

// 格納（ログイン時など）
UserInfoHandle.SetUserInformation(myUserInfo);

// 取得
MyUserInfo u1 = UserInfoHandle.GetUserInformation<MyUserInfo>();  // ★ Core 専用（ジェネリック）
UserInfo   u2 = UserInfoHandle.GetUserInformation();              // ★ net48 専用

// 削除（通常は不要。破棄はログイン画面入場時に FxSessionAbandon で行う設計）
UserInfoHandle.DeleteUserInformation();
```

> ★ `GetUserInformation<T>()`＝Core、`GetUserInformation()`＝net48 でシグネチャが違う（ランタイムで使い分け）。

## MyUserInfo（親クラス2＝纏め者がカスタマイズ）

```csharp
// 既定は UserName / IPAddress の2項目。案件で項目を足す（opentouryo-base2-customize）
MyUserInfo u = new MyUserInfo(userName, ipAddress);
```

持つ項目はプロジェクト依存＝確認は `opentouryo-project-policy`。

## 認証は2つ必要（.NET 認証 ＋ OpenTouryo ユーザ情報）

- .NET の認証（Forms/Cookie）だけでは OpenTouryo のユーザ情報が無い。**両方**必要。
- 消失時（セッションタイムアウト等）は、認証チケット/実行アカウントから再生成するか、ログイン画面へ。
  再生成は親クラス2 `MyBaseController.GetUserInfo`（`opentouryo-base2-customize`）。

## 認証方式の差

- Web Forms / MVC(net48)：Forms 認証（`web.config` の `<authentication mode="Forms">` ＋ `<authorization><deny users="?"/>`）。
- MVC(Core)：Cookie 認証（`web.config` 無し・`Startup` で構成）。

## Web API（Bearer/Basic）

親クラス2 `MyBaseAsyncApiController`（±Core）の `EnumHttpAuthHeader`（None/Basic/Bearer）。
Bearer は JWT 検証雛形（`AccessToken.Verify`）＝`opentouryo-base2-customize`。OAuth2 クライアントは `opentouryo-oauth2-client`。

## ログイン画面/予期せぬ Session タイムアウト例外の対策（Web Forms）

**P層 FW は Session 必須**なので、ログイン画面ではタイムアウト例外が出やすい。対策は3択：

1. **ログイン画面に P層 FW を使わない**（Windows 認証・SiteMinder 等の認証基盤に寄せる）。
2. **`IsNoSession = true`**（コンストラクタ）でその画面の機能を OFF（`opentouryo-layer-p-webforms-screen`）。
3. **`FxSessionAbandon()`**（`Session.Abandon` ＋ タイムアウト検出 Cookie 消去）。

```csharp
public login()  { this.IsNoSession = true; }            // (2)
protected override void UOC_FormInit() { this.FxSessionAbandon(); }  // (3)
```

- **予期せぬタイムアウト例外**はエラー画面等で `FxSessionAbandon()` を呼ぶ（エラー画面は素の `Page`＝`opentouryo-layer-p-webforms-screen`）。
- **タイムアウト後も業務を続けるなら**、セッション領域自動削除・ボタン履歴・不正操作防止を OFF（`opentouryo-config`）。
