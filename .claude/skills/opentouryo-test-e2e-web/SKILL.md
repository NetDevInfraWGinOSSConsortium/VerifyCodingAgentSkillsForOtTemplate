---
name: opentouryo-test-e2e-web
description: "OpenTouryo の Web アプリ（ASP.NET Core MVC・net10.0）の画面の E2E テストを、NUnit と Playwright（.NET）で書く。テストのプロジェクト（<Webプロジェクト名>.E2ETests）の作り方、テストからのアプリの起動と停止（dotnet run・空いたポート・起動の待ち合わせ）、ブラウザ（Edge のチャネル）、ログイン、画面の操作と確かめ方（Expect）、テストのデータの準備と後始末（SqlClient で直接）、根拠の ID を書く [Basis] 属性、Red の落ち方の見分けを扱う。テスト先行（TESTING.md）で、画面の振る舞い（トリガー → 画面の状態・メッセージ・遷移・ボタンの活性）を確かめるテストを先に書くときに使う。E2E / 画面のテスト / Playwright / ブラウザのテスト / E2ETests を伴う作業のときに使う。"
---

# 画面の E2E テスト（Web・Playwright）

画面の振る舞い（トリガー → 画面の状態・メッセージ・遷移・ボタンの活性）を、**実際のブラウザでアプリを操作して**確かめる。
B層の振る舞い（抽出条件・計算・業務エラー）は B層のテスト（`opentouryo-test-layer-b`）で確かめ、E2E では繰り返さない。

**実測の範囲：ASP.NET Core MVC（net10.0）。** net48（IIS Express）・Web Forms は実測していない。
それらで E2E を書くときは、アプリの起動の仕方を推測で書かず、作者に聞く。

## 構成（固定）

| 項目 | 決まり |
| --- | --- |
| テストのプロジェクト | **`<Webプロジェクト名>.E2ETests`**（B層のテストの `<Webプロジェクト名>.Tests` とは分ける。起動とブラウザが要り、実行の条件が違う）。sln に加える（`dotnet sln add`） |
| パッケージ | `NUnit` 4.6.1・`NUnit3TestAdapter` 6.3.0・`Microsoft.NET.Test.Sdk` 18.10.1・**`Microsoft.Playwright` 1.63.0**（実測）。データの準備に `Microsoft.Data.SqlClient`（**Web の csproj と同じ版**。脆弱性の対策で足している依存〔例 `System.Security.Cryptography.Pkcs`〕も同じものを足す） |
| 参照 | **Web のプロジェクトも OpenTouryo の DLL も参照しない**（外から操作するだけ）。csproj は `references/snippets.md` |
| ブラウザ | **Edge のチャネル**（`Channel = "msedge"`・`Headless = true`）。Windows に標準で入っており、ダウンロードが要らない |
| 根拠 | `[Basis("<仕様の ID>")]`。属性は B層のテストと同じ `QualityAttributes.cs` を、名前空間だけ変えて置く |

**ブラウザを Playwright の chromium にしない**（Windows では）。`Microsoft.Playwright` の版ごとに求める chromium の版が決まっており
（1.63.0 は chromium 1243）、他の版が入っていても `Executable doesn't exist … playwright.ps1 install` で起動しない（実測）。
Edge の無い環境（Linux の CI など）だけ、`Channel` を外し、ビルドの後に `pwsh bin/Debug/net10.0/playwright.ps1 install chromium` で入れる。

## アプリの起動と停止

**テストがアプリを起動する**（人が先に起動しておく前提にしない。起動し忘れると接続で落ち、Red の確かめが濁る）。
`[SetUpFixture]` の `[OneTimeSetUp]` で、名前空間の全テストに 1 回だけ起動する。骨格は `references/snippets.md` の `AppHost`。

1. **空いたポート**を取る（`TcpListener` を `IPAddress.Loopback`・ポート 0 で開いて閉じる）。
2. Web のプロジェクトのフォルダで **`dotnet run --no-launch-profile --urls http://127.0.0.1:<port>`** を起動する。
   - `--no-launch-profile`：`launchSettings.json` の https・ブラウザの起動を使わない。環境は `ASPNETCORE_ENVIRONMENT=Development` を渡す。
   - **`OT_RESOURCE_ROOT`**（または appsettings.json が参照する変数）は、テストを実行するシェルから引き継ぐ（アプリの実行と同じ。`opentouryo-project-setup-config`）。
   - Web のフォルダは、テストの出力（`TestContext.CurrentContext.TestDirectory` = `bin/Debug/net10.0`）から `../../../../<Webプロジェクト名>`。
3. **ログインの要らない URL が 200 を返すまで待つ**（MVC_Sample なら `/Ping`。上限 3 分。プロセスが終わっていたら、待たずに失敗させる）。
   実測：初回（ビルドあり）13 秒、2 回目以降 6〜7 秒。
4. `[OneTimeTearDown]` で **`Kill(entireProcessTree: true)`** する（`dotnet run` の子のアプリまで止める。残らないことを実測）。

アプリの出力は `TestContext.Progress` へ流す（起動に失敗した理由が見える）。

## テストを書く

骨格は `references/snippets.md` の「テストの骨格」。要点だけ。

- **テストごとに新しい `IBrowserContext`**（`BaseURL` = アプリの URL）を作り、`[TearDown]` で閉じる（クッキー・セッションを持ち越さない）。
- **ログインは `[SetUp]` で画面から行う**（ログインの画面に利用者名・パスワードを入れて送る）。ログインの仕方はアプリごとに違うので、
  ログインの画面とコントローラを読んで書く（MVC_Sample は利用者名を入れれば通る）。
- 要素は **id で指す**（`#CustomerID`・`#pageInfo`）。画面項目（`I01`…）・ボタン（`B01`…）の id が画面に無ければ、
  **テスト仕様で id を決め**、実装（段 4）がその id を付ける（テストを先に書くので、テストが id を決める）。
- 確かめは **`Assertions.Expect(...)`**（`using static Microsoft.Playwright.Assertions;`）で書く：
  `ToHaveTextAsync`・`ToBeVisibleAsync`・`ToBeEnabledAsync`・`ToBeDisabledAsync`・`ToHaveURLAsync`・`ToHaveValueAsync`。
  **Expect は条件が満たされるまで待つ**（既定 5 秒）。読み込み・送信の後に固定の時間を待たない。
- 送信は、画面のボタンを押す（`ClickAsync("#btnMain1")`）。URL へ直接 POST しない（画面の振る舞いを確かめていない）。

| 仕様に書かれていること | E2E で確かめること |
| --- | --- |
| 画面の初期状態（`EV-*` のページ読み込み） | 項目の値・選択肢の先頭・ページ情報の文言 |
| トリガー → 画面の変化 | ボタンを押した後の一覧・件数・ページ情報・メッセージの文言 |
| ボタンの活性条件 | `ToBeEnabledAsync`・`ToBeDisabledAsync`（境界の両側：例 1 ページ目の「前へ」と最終ページの「次へ」） |
| 遷移 | `ToHaveURLAsync`・遷移先の画面の要素 |

- **Red（`TESTING.md` 段 2）**：まだ無い要素・振る舞いに対し、**`Expect` で落ちる**こと（`PlaywrightException: Locator expected to …`）を見る。
  アプリが起動しない・ログインできない・`net::ERR_…` で落ちるのは Red ではない（先に直す）。
  Red の段では、画面に要素を足さない（id を付けるのは段 4）。

## データの準備と後始末

B層のテストと同じ（`opentouryo-test-layer-b` の「データの準備と後始末」）。**テストが自分で入れ、自分で消す。**

- **テストから直接 `Microsoft.Data.SqlClient`** で入れて消す。接続文字列は **Web の `appsettings.json` から読む**
  （`System.Text.Json`。キーは appsettings.json の綴りどおり〔MVC_Sample は `connectionStrings`〕。コメントを許す設定で読む）。
- 画面では、**テストが入れたデータだけが出る条件**で操作する（例：テスト用の顧客を選んで検索する）。
  他のデータと混ざる一覧の件数・並びを確かめない。日付の項目は、既存のデータと重ならない値にする。
- **日付の範囲は、B層のテスト（`<Web>.Tests`）と分ける。** sln の `dotnet test` は 2 つのテストのプロジェクトを**並行して**動かすため、
  同じ表に同じ範囲の行を入れると、全件を対象にする B層のケース（「条件なしの 1 ページ目に自分の行が入る」など）を押し出す。
  `<Web>.Tests` の日付（`new DateTime(` を検索）を読み、E2E はそれより古く既存のデータより新しい範囲にする
  （MVC_Sample：B層 2199 年 → E2E 2198 年）。
- `[TearDown]` で、ブラウザを閉じてからデータを消す（親子は子から）。

## 実行

```powershell
dotnet test <Webプロジェクト名>.E2ETests        # E2E だけ（アプリの起動を含む）
dotnet test <Webプロジェクト名>.Tests           # B層だけ（速い）
```

sln を `dotnet test` すると、両方が**並行して**動く（E2E はアプリを起動する分だけ遅い）。段 4 の確認は sln で（`-m:1` で順に動かして通すのは、データの干渉を隠す）。

## やってはいけないこと

- **Green の段でテスト（期待値・`[Basis]`・`Expect`）を書き換えて通す** — テストを変えるのは仕様が変わったときだけ（`TESTING.md`）
- **固定の時間を待つ**（`Task.Delay`・`WaitForTimeoutAsync`）— `Expect` に待たせる
- **テストどうしでブラウザのコンテキストやデータを共有する** — 順番に依存し、単独で動かなくなる
- **既存のデータ（Northwind の元の行）の件数・並びに頼る** — テストが入れたデータで絞る
- **アプリを起動したまま残す** — `[OneTimeTearDown]` で止める（ポート・ファイルのロックが残る）
- **B層の計算・抽出条件を E2E で網羅する** — B層のテストで確かめる。E2E は画面の振る舞いだけ
