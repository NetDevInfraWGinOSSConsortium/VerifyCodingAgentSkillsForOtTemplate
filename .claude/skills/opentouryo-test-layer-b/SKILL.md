---
name: opentouryo-test-layer-b
description: "OpenTouryo のアプリで、B層のルート メソッド（P層から DoBusinessLogic で呼ばれ UOC_<MethodName> に振り分けられる入口）の単体テストを NUnit で書く。テストのプロジェクト（<Webプロジェクト名>.Tests）の作り方（net48 / net10.0 の csproj・OpenTouryo の DLL の参照・net48 の App.config と Microsoft.Data.SqlClient・net10.0 の InitConfiguration）、DoBusinessLogic の境界での呼び方（引数クラス → 戻り値クラス・ErrorFlag・BusinessSystemException）、実 DB（LocalServicesOnDocker）でのデータの準備と後始末、根拠の ID を書く [Basis] 属性、ビルドと実行のコマンドを扱う。テスト先行（TESTING.md）の段 2（Red）で、テストを先に書くときに使う。B層のテスト / 単体テスト / NUnit / LayerBTests / DoBusinessLogic のテスト / [Basis] / テストのプロジェクトを伴う作業のときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# B層のルート メソッドの単体テスト（NUnit）

> 📋 **コピー元スニペット**：`references/snippets.md`（csproj 2 種・App.config・TestSetup・[Basis]・テストの骨格。実装時はここから写す）。

進め方（テスト仕様 → Red → Green）と、承認したテストを守る規則は **`TESTING.md`**。このスキルは「どう書くか」だけを扱う。
B層の書き方そのものは `opentouryo-layer-b`、呼び出し方は `opentouryo-p-call-business`。

<!-- as-built：2026-11-06、VerifyCaSkillsForOT の写し（ASP.NET MVC 5〔net48〕・ASP.NET Core MVC〔net10.0〕・Web Forms〔net48〕）で、
     テストのプロジェクトを足し、SQL Server（LocalServicesOnDocker）に対して全件通した。OpenTouryo は develop（D8BAE60FC77F）。 -->

## 決まり（選ばない）

| 項目 | 決まり |
| --- | --- |
| フレームワーク | **NUnit 4**（`NUnit` 4.6.1・`NUnit3TestAdapter` 6.3.0・`Microsoft.NET.Test.Sdk` 18.10.1。OpenTouryo 本体と同じ） |
| プロジェクト | **`<Webプロジェクト名>.Tests`**。Web のプロジェクトのフォルダと**同じ階層**に置く（`MVC_Sample\` の隣に `MVC_Sample.Tests\`） |
| 形式 | **SDK 形式の csproj**。`TargetFramework` は **Web のプロジェクトと同じ**（net48 なら `net48`、net10.0 なら `net10.0`） |
| 参照 | Web のプロジェクトへの `ProjectReference` ＋ **`OpenTouryo.Business`・`OpenTouryo.Framework`・`OpenTouryo.Public` の `Reference`**（HintPath は Web のプロジェクトと同じフォルダ） |
| B層を WS_sample で共用する構成 | Web が `WSServer_sample` を参照していれば、テストも `WSServer_sample`・`WSIFType_sample`（net10.0 は `WS_sample_Core` の 2 つ）を `ProjectReference` する。設定は Web のものを使うので、テストのプロジェクトは `<Web>.Tests` のまま。**B層のテストのコードは `Shared\WSServer_sample.Tests\` に 1 つだけ書く**（下の「B層を共用する構成のテスト」） |
| テストの単位 | **B層のクラスごとに 1 つのテスト クラス**（`<LayerBのクラス名>Tests`）。テスト メソッドは `<MethodName>_<何を確かめるか>` |
| 呼び方 | **`new <LayerB>().DoBusinessLogic(引数クラス, 分離レベル)`**（同期版）。`UOC_` は直接呼べない（`FrameworkException`） |
| 根拠 | **`[Basis("<仕様の ID>")]`** をテスト メソッドに付ける（`EV-ORD-101`・`VAL-ORD-03` など。複数可）。属性はテストのプロジェクトに定義する |
| DB | **実 DB**（LocalServicesOnDocker）。**テストが自分でデータを入れ、自分で消す**（外側のロールバックに頼らない） |

**Web の参照（HintPath）はテストのコンパイルに引き継がれない**（実測。`CS0246: 'Touryo' が見つからない`）。だから 3 つの `Reference` を書く。
テストのコードが他の OpenTouryo の型（`DamSqlSvr` など）を `using` するときは、その DLL も足す。実行時の DLL は Web の出力から写る。

## B層を共用する構成のテスト（`Shared\` があるとき）

B層のソースと同じく、**テストのコード（`<LayerB>Tests.cs` と `QualityAttributes.cs`。名前空間 `WSServer_sample.Tests`）は `Shared\WSServer_sample.Tests\` に置き**、
**ランタイムごとに 1 つの `<Web>.Tests`**（net48 は先に作った方、例 `MVC_Sample.Tests`。net10.0 は `MVC_Sample_Core\MVC_Sample.Tests`）がリンクで取り込む。
同じテストが両方のランタイムで走る（実測：net48・net10.0 とも成功）。P層ごとに重ねない（同じランタイムの 2 つ目の Web の `<Web>.Tests` はリンクしない）。

```xml
<ItemGroup>
  <Compile Include="..\..\Shared\WSServer_sample.Tests\**\*.cs" Link="Shared\%(RecursiveDir)%(Filename)%(Extension)" />
</ItemGroup>
```

- 設定（net48 の `App.config`・net10.0 の `TestSetup.cs`）は、各 `<Web>.Tests` に置く（ランタイムで違う）。リンクするのは B層のテストだけ。
- テストのコードは **net48（C# 7.3）でも組める書き方**にする（下の「テストを書く」は両方で通る形）。
- フォルダ名を `.Tests` で終える（期待値の変更の検出器のパス・段 4 の「テストのファイルを編集しない」に当たるように）。
- B層を変えたら、**両方のランタイムの `<Web>.Tests` を流す**。

## プロジェクトを作る

1. csproj を `references/snippets.md` の「net48」または「net10.0」から写し、`<Webプロジェクト名>` と HintPath の `..\..\OpenTouryoAssemblies\…` を、
   **Web のプロジェクトの csproj に書かれている HintPath と同じ場所**に合わせる。
2. **net48 だけ**、次を足す（どちらも実測で必要だった）。
   - **`App.config`**：テストは `Web.config` を読まない。`connectionStrings` は `Web.config` から写す。
     `appSettings` は、`Web.config` が `<appSettings file="app.config"/>` なら、その `app.config` をリンクして出力へ写し（`<None Include … Link=…>`）、
     `<appSettings file="<Webプロジェクト名>.appSettings.config"/>` で読む。`file=` でなければ、`<appSettings>` の中身を写す。
   - **`Microsoft.Data.SqlClient` の `PackageReference`**（版は Web の `packages.config` と同じ）。無いと、ネイティブの
     `Microsoft.Data.SqlClient.SNI.x64.dll` がテストの出力に写らず、接続で `DllNotFoundException` になる。
3. **net10.0 だけ**、`[SetUpFixture]` で `GetConfigParameter.InitConfiguration(...)` に `appsettings.json` を渡す（`TestSetup.cs`）。
   Web の `appsettings.json` は、参照しただけでテストの出力へ写る（実測）。
4. `[Basis]`・`[Observation]` の定義（`QualityAttributes.cs`）を写す。
5. ソリューションへの追加：**net10.0** は `dotnet sln <sln> add <Tests の csproj>`。
   **net48 は sln に加えない**（`dotnet sln add` は Web のプロジェクトを評価できずに失敗することがあり〔`WebApplication.targets`〕、成功しても旧形式の sln を書き直す。実測。成功しても加えない）
   （加えるには Visual Studio での人の操作が要る）。テストのビルドと実行は **csproj を直接指定**すれば sln に無くてもできる
   （`MSBuild.exe <csproj> -restore` → `dotnet test <csproj> --no-build`。E2E と並行で全件を流すのは `opentouryo-test-e2e-web` の「実行」）。

## 実行する

| 対象 | ビルドと実行 |
| --- | --- |
| net10.0 | `dotnet test <Tests の csproj>` |
| net48 | `MSBuild.exe <Tests の csproj> -restore` の後に `dotnet test <Tests の csproj> --no-build`（Web のプロジェクトは MSBuild でしか組めない） |

**`OT_RESOURCE_ROOT` が要る**（SQL ファイル・ログの設定・XML 定義を読むため。アプリの実行と同じ。設定は `opentouryo-project-setup-config`）。
ログはそこの `Log\` に書かれる。

## テストを書く

骨格は `references/snippets.md` の「テストの骨格」。要点だけ。

- **引数クラス**：`new <業務>ParameterValue(screenId, controlId, methodName, actionType, new MyUserInfo("test", "127.0.0.1"))`。
  - `methodName` は `UOC_` の後ろと**完全一致**（綴りが違うと実行時に見つからない）。
  - `actionType` の **`%` で区切った先頭が DB の種類**（`SQL` なら SQL Server。親クラス2 の `UOC_ConnectionOpen` が見る）。2 つ目以降は業務が決める。
  - **`MyUserInfo` を null にしない**（親クラス2 の前処理が利用者名を参照する）。
- **分離レベル**：P層の呼び出しと同じ値を渡す（P層の `DoBusinessLogic` の第 2 引数を読む。`opentouryo-layer-b`）。
  **テストを先に書く（P層がまだ無い）ときは、テスト仕様（段 1）で値を決め、段 4 で P層もその値で呼ぶ**
  （決めずに `User` で書くと、後から作る画面の値〔例 `ReadCommitted`〕とずれる。実測）。
- **確かめること**（イベント仕様書の「出力・検証内容・エラーハンドリング」から）

| 仕様に書かれていること | テストで確かめること |
| --- | --- |
| 正常の出力 | `rv.ErrorFlag` が `false`、戻り値クラスの値、**DB の状態**（テストから SELECT して数える） |
| 業務エラー（`ERR-*`・`VAL-*`） | `rv.ErrorFlag` が `true`。仕様がメッセージを ID で定めるなら `rv.ErrorMessageID`、文言で定めるなら `rv.ErrorMessage`（`BaseLogic` は例外の文言をそのまま戻す。実ソース）。**DB が変わっていない**（業務例外はロールバックされる。実測） |
| システム エラー | `Assert.Catch<BusinessSystemException>(…)` で捕まえ、`ex.messageID` を見る（システム例外は呼び出し側へ投げられる。実測） |

- **期待は、テストが入れた値から C# の値（文字列・数値）で書く。** 実装と同じ式（SQL の `LastName + N' ' + FirstName` など）で期待を作らない
  （式の誤りが実装とテストの両方にそろうと通ってしまい、仕様を確かめていない）。
- **例外を待つラムダは `new Action(() => { …; })` と書く**（net48・net10.0 共通）。
  NUnit 4 は `Assert.Catch` などに `TestDelegate` と `Action` の両方を持ち、net48（C# 7.3）では `() => …` が曖昧で `CS0121`、
  `new TestDelegate(…)` は net10.0 で旧形式の警告 `CS0618` になる（どちらも実測）。

- **Red（`TESTING.md` 段 2）**：引数クラス・戻り値クラス（テストのコンパイルに要る）と、**戻り値を設定するだけの空の `UOC_<MethodName>`** を先に置き、
  アサーションで落ちることを見る。`UOC_` が無いままだと `ArgumentException`（「メソッド名：[UOC_…]が存在しません」。実測）で落ち、
  テストが振る舞いを見ているかを確かめられない。

## データの準備と後始末

**B層は自分でトランザクションを開始・確定する**ので、テストの外側でロールバックして戻すことはしない。

1. **他と衝突しないキー**のデータを使う。既存のデータを書き換えない。**キーは、その列の型と書式に合わせて作る**：
   - 幅のある文字列の列：GUID から作る（例 `"T-" + Guid.NewGuid().ToString("N").Substring(0, 10)`。列の長さに収まるか確かめる）
   - 書式の決まったコードの列（固定長・使える文字が決まっている）：その書式でランダムに作る（根拠は仕様の書式の決まり）
   - IDENTITY の列：値を作らない。`INSERT …; SELECT CAST(SCOPE_IDENTITY() AS int);` を 1 つのコマンドで実行して受け、それで絞る・消す（実測）
2. 前提のデータが要るなら `[SetUp]` で入れる。**`[TearDown]` で、そのキーのデータを消す**（失敗したテストの後でも消える）。
   ただし **`[SetUp]` が例外だと `[TearDown]` は呼ばれない**＝複数の行を入れる途中で落ちうるなら、`[SetUp]` の中で後始末して投げ直す。
   **親子のあるデータは子から消す**（例：明細 → 受注 → 顧客。外部キーがあると、親から消すと失敗する）。
3. 準備・後始末・DB の状態の確かめには、**テストから直接 `SqlConnection`** を使う
   （接続文字列は `GetConfigParameter.GetConnectionString("ConnectionString_SQL")`。アプリの設定と同じものが読める。実測）。
   B層の別の `UOC_` で準備・後始末をしない（確かめたい処理と、準備の処理が同じ不具合で同時に壊れる）。
4. 件数を確かめるときは「全体の件数」ではなく**そのキーで数える**（並行して動く他のテスト・人の操作に影響されない）。
5. **並びは、テストが入れた行どうしの前後関係で確かめる**（C# で並べ直して比べない。DB の照合順序と一致しない）。
   並べ替えのキーが複数なら、**1 つ目のキーが同じで、2 つ目のキーの順を ID の順と逆にした行**を入れて、2 つ目のキーも確かめる
   （既存のデータに同じ値が無いと、2 つ目のキーが効いていなくても通る）。

## 根拠の ID（`[Basis]`）

- 期待値の出どころ（イベント仕様書の `EV-*`・`VAL-*`・`ERR-*`・`PRE-*`、業務ルール）を `[Basis("…")]` で書く。1 つのテストに複数書いてよい。
- **根拠の ID を付けられないケースは書かない**。仕様の決定として、テスト仕様の段（`TESTING.md` 段 1）で人に上げる（`TESTING.md` 5）。
- 今の振る舞いを写しただけの期待値には `[Observation("理由")]` を付ける（根拠が無いことを明示する）。
- **`[Basis]` を消す・テストを消す・`[Ignore]` を足すと「期待値の変更」になる**。コミットにはトレーラー `Expectation-Change: <理由（変わった仕様の ID）>` が要る（`TESTING.md`）。

## やってはいけないこと

- **Green の段でテスト（期待値・`[Basis]`）を書き換えて通す** — テストを変えるのは仕様が変わったときだけ（`TESTING.md`）
- **`UOC_` を直接呼ぶ・リフレクションで呼ぶ** — `DoBusinessLogic` の境界でだけ呼ぶ
- **`MyUserInfo` に null を渡す** — 親クラス2 の前処理で失敗する
- **既存のデータ（Northwind の元の行）を書き換える・消す** — テストが自分で入れたデータだけを扱う
- **`TransactionScope` などで外側から包んでロールバックする** — B層の確定と両立するか確かめていない。後始末は `[TearDown]` で消す
- **テストのプロジェクトに `Web.config` を写す**（net48）— テストのホストは読まない。`App.config` に書く
