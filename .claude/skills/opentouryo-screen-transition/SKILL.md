---
name: opentouryo-screen-transition
description: "OpenTouryo の画面遷移制御機能を実装する。SCDefinition.xml に Screen / Transition / CmnTransition 要素で画面ごとの遷移先を定義し、FxScreenTransitionCheck 設定を on にしてフレームワークに自動チェックさせる。directLink=allow/deny による Get 直リンクの許可・拒否、定義にない遷移の FrameworkException による拒否を扱う。画面遷移 / 画面遷移制御 / 画面遷移定義 / SCDefinition / directLink / 直リンク拒否 / 不正遷移 を伴う作業のときに使う。ASP.NET Web Forms 専用（MVC / Windows Forms にはこの機能が無い）。Web Forms の画面実装は opentouryo-layer-p-webforms を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 画面遷移制御機能

> 📋 **コピー元スニペット**：`references/snippets.md`（ScreenTransition/FxTransfer/FxRedirect・SCDefinition.xml・config。実装時はここから写す）。

## このスキルの適用範囲

`SCDefinition.xml` の書式と、画面遷移チェックの有効化。

**ASP.NET Web Forms 専用。** MVC / Windows Forms にこの機能は無い。
Web Forms の画面実装そのものは `opentouryo-layer-p-webforms-screen` /
`opentouryo-layer-p-webforms-event` を参照。

## 実際の遷移手段は2通り（この機能は「チェック」の追加）

イベントハンドラで**遷移先を決める**基本手段はこの機能とは別にある。使い分け：

- **単純遷移**：ハンドラで URL を返す（`return "遷移先.aspx"`）、または `this.FxRedirect(url)` / `this.FxTransfer(url)`
  を呼ぶ。**SCDefinition 不要**。遷移しない（ポストバック）なら `return ""`（`opentouryo-layer-p-webforms-event`）。
- **論理名遷移＋チェック**：`this.ScreenTransition("遷移ラベル")` は `SCDefinition.xml` の**ラベル定義が必須**。
  併せて下の**チェック機能**で不正遷移を弾ける。

本スキルは主に後者（`SCDefinition.xml` とチェック）を扱う。単純遷移だけなら SCDefinition は要らない。

**★ 「単純遷移」と「ラベル遷移」は別 API ではない＝UOC の戻り値の“意味”が主スイッチ `FxScreenTransitionMode` で切り替わる**
（実装 `MyBaseController.UOC_Screen_Transition(url)`＝ハンドラの `return` 値を受ける唯一の入口）：

| `FxScreenTransitionMode` | `return` した文字列の意味 | 遷移 |
| --- | --- | --- |
| **`off`（配布サンプルの既定）** | **URL**（`return "遷移先.aspx"`） | `ScreenTransitionMethod`（`1`=`Server.Transfer`＝`FxTransfer`／`2`=`Response.Redirect`＝`FxRedirect`。`~/` は `ResolveUrl` 解決）。**`SCDefinition.xml` は読まれない**（空の `<SCD/>`）＝定義を書いても効かない |
| **`T` / `R`** | **遷移ラベル**（`return "遷移ラベル"`） | そのまま `ScreenTransition()` に渡り `SCDefinition.xml` から URL を解決（`this.ScreenTransition(...)` を自分で呼ぶ必要はない） |

**∴ 定義ファイルを使うには主スイッチを `T`/`R` にすることが前提。** これを知らないと「`off` のまま `SCDefinition.xml` を書いて `return "ラベル"`」＝ラベルが URL 扱いで **404**、逆に「`T`/`R` で `return "url.aspx"`」＝未定義ラベルで **`FrameworkException`**、のどちらかに必ず陥る。`ScreenTransitionMethod`（`1`/`2`）と `FxScreenTransitionMode`（T/R/off）は**別キー**なので混同しない。

**★ 「`SCDefinition.xml` に定義がある」＝「画面遷移制御を使っている」ではない。** 主スイッチ `off` では定義は読まれず（空の `<SCD/>`）**効いていない**＝`off` のまま整合性のために `SCDefinition.xml` をメンテナンスする〔画面追加・削除に合わせて更新しておく〕のは**便宜として妥当**（将来 `T`/`R` に切り替える布石にもなる）。ただし**「定義したから使えている」と誤認しない**——実際に効いているかは**主スイッチが `T`/`R` かどうか**（＝実 `app.config` の `FxScreenTransitionMode`）で判断し、報告でも「定義あり」と「機能が有効」を区別する。

## Redirect と Transfer の使い分け（設計比較）

| | **Redirect**（`FxRedirect`＝`Response.Redirect`・`ScreenTransitionMethod=2`） | **Transfer**（`FxTransfer`＝`Server.Transfer`・`=1`） |
| --- | --- | --- |
| URL | **変わる**（画面＝URL＝パイプラインが1対1＝素直） | **変わらない**（1対1でない） |
| リロード時 | **最後のリクエストを再実行**（＝**GET 再送**） | **前のリクエストを再実行**（＝**POST 再送**。二重送信注意＝`opentouryo-app-design/references/illegal-operation-prevention.md`） |
| 情報の持ち回り | **`Session`**（別リクエストになるため。`opentouryo-app-design/references/state-management.md`） | **`HttpContext.Items`／Hidden**（同一リクエスト内で引き継げる） |
| 性能 | 往復1回増える | **有利**（サーバ内転送） |

- **既定は Redirect が素直**（URL と画面が1対1・リロード挙動が分かりやすい）。Transfer は性能重視だが URL ズレ・二重送信リスク。
- **★ Transfer＋Hidden/HttpContext で「セッション不要（ステートレス）」設計も可能**（1リクエスト内で完結＝`IsNoSession`。`opentouryo-auth`）。
- **MVC は Transfer が無い**：`RedirectToAction`／`Redirect(Url.Action(...))` で他コントローラへ、`Html.BeginForm` は自コントローラへ Post して View 再描画、`Ajax.BeginForm` は PartialView（`opentouryo-layer-p-mvc`）。

## 何のための機能か

**不正な画面遷移を検出して拒否する。** 定義にない遷移や、直リンク禁止の画面への Get アクセスを
`FrameworkException` で弾く。URL を直打ちして業務の途中から入る、といった操作を防ぐ。

**コードから呼ぶ API は無い。** 設定を ON にすれば、フレームワークが自動でチェックする。

## 有効化する（これを忘れると動かない）

**スイッチは `app.config` の `appSettings`（Web Forms 専用＝net48 なので XML。`appsettings.json` ではない）。2段ある。**

```xml
<add key="FxScreenTransitionMode"  value="T"/>   <!-- 主スイッチ：T / R / off。off だと機能全体が無効 -->
<add key="FxScreenTransitionCheck" value="on"/>  <!-- 副スイッチ：不正遷移チェックの on / off -->
```

**★ 主スイッチは `FxScreenTransitionMode`。これが `off` だと、`FxScreenTransitionCheck` の値に関わらずチェックは走らない**
（実装 `BaseController.cs`：`_transitionMethod == off` で `_transitionCheck` を強制 `false`）。`FxScreenTransitionCheck` が
効くのは主スイッチが `T` / `R`（有効）のときだけ。

| `FxScreenTransitionMode`（主） | `FxScreenTransitionCheck`（副） | チェック |
| --- | --- | --- |
| `off` | （不問） | **走らない**（強制無効） |
| `T` / `R` | `on` | 走る |
| `T` / `R` | `off` / 未設定 | 走らない |
| `T` / `R` | 上記以外 | 書式不正で例外 |

**両方を設定しないと黙って無効になる。** 定義ファイルを書いただけでは動かない。
**★ 配布サンプルは `Mode=off`** なのでチェックは実際には効いていない（未登録画面への直リンクも通る）。既存 app.config を必ず確認する。

## 定義ファイル

パスは `appSettings` の **`FxXMLSCDefinition`** で指定する（`opentouryo-config` 参照）。
**ランタイムによらず XML のまま。**

**定義例（DTD 埋め込み・`Screen`/`Transition`/`CmnTransition`・`directLink`=allow/deny・`mode`=T/R）は `references/snippets.md`。** 要素・属性は下表。

| 要素・属性 | 内容 |
| --- | --- |
| ルート要素 | `SCD` |
| `Screen` の `value` | 現画面の仮想パス |
| `Screen` の `directLink` | `allow` / `deny`。Get 直リンクを許すか。既定は `allow` |
| `Transition` の `value` | 遷移先の仮想パス |
| `Transition` の `label` | 遷移のラベル |
| `Transition` の `mode` | `T` / `R`。**DTD にあるが読み取る実装が無い**（後述） |
| `CmnTransition` | 全画面共通の遷移。`label` が `ID` 型 |

**`Screen` の `value` は `ID` 型にできない**（仮想パスに `/` を含むため）。
`CmnTransition` の `label` だけが `ID` 型で、**先頭に数字を使えない**。

### DTD を省かない

**DTD を埋め込んだ形式。** 他の OpenTouryo の XML 定義ファイルと共通の作法。

## directLink="deny" は Get による直リンクを拒否する

`deny` の画面へ URL 直打ち（Get）でアクセスすると **`FrameworkException`（画面遷移チェック
エラー）** になる。`allow` なら許可。

ログイン画面やメニュー画面は `allow`、業務の途中の画面は `deny` にする、という使い方。

`directLink` 属性そのものが無いと、これも `FrameworkException` になる（属性なしは許容されない）。
DTD の既定値は `allow` だが、**明示的に書く**。

## mode 属性は機能していない

DTD に `mode (T|R) #IMPLIED` と定義され、`FxLiteral.XML_SC_ATTR_MODE = "mode"` という定数も
あるが、**この定数を参照している実装が存在しない**。書いても効かない。

<!--
  確認済み: grep "XML_SC_ATTR_MODE" の結果は FxLiteral.cs の定義行のみ。
  Attributes["mode"] / GetAttribute("mode") も実装に無い。
  T=Transfer / R=Redirect の想定と見えるが、実装されていないため意味を断定しない。
  DevelopmentHistory.md 4.3 参照。
-->

## やってはいけないこと

- **`FxScreenTransitionCheck` を設定せずに `SCDefinition` を書く** — 未設定は `off` 扱い。
  **黙ってチェックされない**
- **主スイッチを `off`→`T`/`R` にする前に、既存の全画面の `return` をラベル化し忘れる** — 主スイッチはアプリ全体に効くので、URL を返していた既存画面は一斉に未定義ラベル扱い＝`FrameworkException`。片方だけ直すと直さなかった画面が壊れる
- **主スイッチを ON にしたのに未登録の画面を残す** — `Check` が実際に効き始め、`SCDefinition.xml` に無い **`MyBaseController` 派生画面**（例：Sign-out の素リンク `logout.aspx` への Get）が拒否される。**`directLink="allow"` で登録**する（`System.Web.UI.Page` 派生〔`ErrorScreen.aspx`・ダイアログ・`Ping.aspx` 等〕はチェック対象外＝登録不要）
- **`directLink` 属性を省く** — 属性なしは `FrameworkException` になる
- **`CmnTransition` の `label` の先頭に数字を使う** — XML の `ID` 型なので不正
- **DTD を省く** — 埋め込み形式が前提
- **`mode` 属性に意味があると考える** — DTD と定数だけで、読む実装が無い
- **MVC / Windows Forms でこの機能を使おうとする** — Web Forms 専用
- **この XML を `appsettings.json` に移そうとする** — ランタイムによらず XML のまま
