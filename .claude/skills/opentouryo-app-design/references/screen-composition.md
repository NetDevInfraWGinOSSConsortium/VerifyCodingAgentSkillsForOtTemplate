# 画面の構成（WebForms / WinForms / MVC）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。実装は各 P層スキル。
出典：OpenTouryo「画面の構成」＋実装スキル／実ソース。

## 共通の考え方（パーツの階層）

画面は **Form ＋ Control** で構成し、3階層で組む——どのプラットフォームでも同じ。**実現手段が違うだけ**。

- **デザインベース（親フォーム）**＝共通の外枠（ヘッダ／フッタ／メニュー／共通ボタン）
- **個別デザイン（子フォーム）**＝業務ごとの画面本体
- **ユーザコントロール**＝複数 Control を集約した再利用パーツ

## プラットフォーム別の実現手段

| | 共通の外枠（親） | 個別画面（子） | 再利用パーツ | 実装スキル |
| --- | --- | --- | --- | --- |
| **WebForms** | **マスタページ**（`.master`＝`BaseMasterController`／`ContentPlaceHolder`／**Fx 隠しフィールド**） | コンテンツページ（`.aspx`） | **Web ユーザコントロール**（`.ascx`） | `opentouryo-layer-p-webforms-screen`/`-event`・`opentouryo-base2-customize` |
| **WinForms** | **ベースの Form クラス**（ボタンレイアウト標準化＝マスタページと同様の考え方） | 派生 Form | **UserControl** | `opentouryo-layer-p-winforms-screen`/`-event`・`opentouryo-base2-customize` |
| **MVC** | **`Views/Shared/_Layout.cshtml`**（Razor レイアウト）＋`@RenderBody`／`@RenderSection` | 各 View（`.cshtml`） | **HTML ヘルパー**（＝ユーザコントロールの代替） | `opentouryo-layer-p-mvc` |

- フッタ等の**ボタン共通化**は `opentouryo-base2-customize`。一覧（グリッド）は `opentouryo-webforms-crud-screens`・`references/list-paging.md`。ダイアログは `opentouryo-webforms-dialog`。

## ★ WebForms と MVC の構成は別物

- **WebForms のマスタページには Fx 隠しフィールド**（`RequestTicketGuid`／`ScreenGuid`／`WindowGuid` 等）が載り、**不正操作防止・画面遷移制御**が働く（`references/illegal-operation-prevention.md`）。
- **MVC の `_Layout.cshtml` にはこれが無い**——MVC はこれらの P層機能を持たず（`opentouryo-layer-p-mvc`「MVC に無い Web Forms 専用のP層機能」）、**標準 Razor レイアウトで OpenTouryo 独自のマスタ機構は無い**。
- **ボタンの動き方も違う**：WebForms/WinForms は**接頭辞で自動結線する UOC イベント**（`opentouryo-layer-p-webforms-event`）。MVC のボタンは**当該 Controller の Action を呼ぶ**（フォーム POST／リンク）。

## 設計時に決めること（チェック）

- 共通の外枠（ヘッダ/フッタ/メニュー/共通ボタン）を**親に集約**（マスタページ／ベース Form／`_Layout.cshtml`）。
- 再利用パーツ＝**ユーザコントロール**（Web/WinForms/WPF）／**MVC は HTML ヘルパー**。
- **WebForms はマスタに Fx 隠しフィールドを載せる**（不正操作防止・画面遷移。`references/illegal-operation-prevention.md`）。**MVC は該当機能無し**（CSRF は標準アンチフォージェリで自前）。
- マスタ／`_Layout` は**ネスト可**（共通→サブ共通→個別）。

## Sources（最新動向）

- Layout in ASP.NET Core（`_Layout.cshtml` / `RenderSection` / `RenderBody`）— https://learn.microsoft.com/en-us/aspnet/core/mvc/views/layout
