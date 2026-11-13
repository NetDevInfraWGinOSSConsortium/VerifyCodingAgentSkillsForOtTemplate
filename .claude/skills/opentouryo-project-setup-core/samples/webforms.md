# サンプル固有メモ：Web Forms（`Samples\WebApp_sample\WebForms_Sample`・net48）

`opentouryo-project-setup-core` でこのサンプルを取り出すときの、**サンプル固有の癖**。
（WS/3層まわりの共通機構は `webservices.md`。サンプル別メモはこの `samples/` 配下。育ったら独立スキルへ昇格。）

## WS/3層依存（共通手順は `webservices.md`）

`WebForms_Sample` は**3層構成**で、2層画面 `sampleScreen_cc.aspx.cs` が `using WSIFType_sample;` で WS 側の型
（`TestParameterValue` / `TestReturnValue`）を掴むため、**取り出し直後は `CS0246` が残る**（実測）。
解消の一般手順（**(A) そのまま残す**＝WS も取り出し `WSServer_sample`/`WSIFType_sample` を **ProjectReference** 化／
**(B) WS 依存を切り離す**）は **`webservices.md`**。

このサンプル固有の点：
- **Web で WS をインプロセス利用**するので **(B) 切り離しも選べる**。(B) の画面差し替えは
  `using WSIFType_sample;` → `using MyType;`（同名型が同梱 `AppCode\sample\Common\` にある）。詳細は `opentouryo-project-transform`。
- (A) の場合、csproj の `WSServer_sample`/`WSIFType_sample` は元 `..\..\..\WS_sample\Build\*.dll`（DLL 参照）だが、
  **その `<Reference>`+HintPath を削除して `.csproj` への `<ProjectReference>` に切り替える**（webservices.md の原則）。
  同じ csproj の `MySql.Data`/`Oracle.ManagedDataAccess`（同じく WS_sample\Build を指す）は**サンプルでなく 3rd-party
  なので ProjectReference にはできない＝ベンダ先 `Build_net48\` への DLL 参照に張り替える**（`references/reference-rewrite.md`）。
  **★ (A) では `WebForms_Sample.sln` にも `WSIFType_sample`/`WSServer_sample` の2プロジェクトを追加**し、
  `<ProjectReference>` の `<Project>` GUID を参照先 `<ProjectGuid>` に一致させる（`webservices.md`「ProjectReference 化の共通注意」）。
- (A) の成否を実行で確かめられるのは、3 層の画面 **`Aspx/sample/crud/sampleScreen_cc.aspx`** だけ（`ddlCmctCtrl`＝`testInProcess` で、bin の `WSServer_sample.dll` をインプロセスで呼ぶ）。
  ほかの 2 つの値（`testWebService4`・`testWebService3`）は WS ホストが要る。⑦の手順は `opentouryo-project-setup-config` の `references/run-verify.md`。
- 取り出した `WS_sample\WSServer_sample\WSServer_sample.sln`（源に付いている単独の sln）は、残してよい（アプリは `WebForms_Sample.sln` を使う。新しい配置でもパスは解決する）。

## (C) を選んだとき：自身の B層を Shared に張り替える（実測）

`AppCode\sample` の B層・D層は、Shared（元 `WS_sample`）と**名前空間だけが違う**（`WebForms_Sample`・`MyType` ↔ `WSServer_sample.*`・`WSIFType_sample`）。
引数・戻り値の形が同じなので、**P層の変換は要らない**（MVC と違う。`mvc.md`）。

1. **消す**：`AppCode\sample\Business\LayerB.cs`・`Dao\LayerD.cs`・`Dao\DaoShippers.cs`（csproj の `<Compile Include>` も）。
2. **画面の `using` を替える**：`Aspx\sample\crud\sampleScreen.aspx.cs` の `using MyType;` → `using WSIFType_sample;` と `using WSServer_sample.Business;`
   （`sampleScreen_cc.aspx.cs` は元から `WSIFType_sample` を使う）。
3. **WS の 2 つを ProjectReference にし、`WebForms_Sample.sln` に足す**：WS の DLL 参照を消して `..\..\WS_sample\…` を ProjectReference にする。
   sln の行の足し方は `webservices.md` の「ProjectReference 化の共通注意」と同じ（最後の `EndProject` の直後に足す、構成の行は同じ sln の既存のプロジェクトの行を雛形に GUID だけ替える、GUID の行の数で検算する。実測：Project 行 2・構成行 8）。
4. **残す**（Shared に無い・ほかが使う）：`Business\GetMasterData.cs`・`Dao\DaoCategories.cs`・`Dao\DaoSuppliers.cs`・`3TierTableAdapter\ProductsTableAdapter.cs`、
   `Common\TestParameterValue.cs`・`TestReturnValue.cs`（名前空間 `MyType`。`AppCode\testPublic\Business\TestMTC_txg.cs` が使う）。
   **Shared が受け持つのは CRUD 画面（Shippers）の B層・D層だけ**。`TestParameterValue` が `MyType` と `WSIFType_sample` に 2 つ並ぶが、名前空間が別なのでぶつからない。

`AppCode` の `DaoShippers` は Shared のものより新しい生成物（クエリのキャッシュ・`CommandTimeout` を持つ）。張り替えると Shared のものが使われる。
確かめた：msbuild 成功、`aspnet_compiler` 成功（`CS1685` のみ）、作者が起動し `sampleScreen.aspx`・`sampleScreen_cc.aspx` とも DB に届いた（VerifyCaTddForOT、2026-11-13）。

## config は二段構成（初見で `Web.config` を探して迷う）

net48 Web Forms は実効 config が `Web.config` だが、キーの所在が分かれる（⑥のパス張り替えで効く）：

| 種類 | 所在 |
| --- | --- |
| パス系キー（`Fx*` / `SqlTextFilePath` / `SpRp_RsaCerFilePath` 等） | **`app.config`**（`Web.config` の `<appSettings file="app.config"/>` で読み込まれる） |
| 接続文字列（`ConnectionString_*`） | **`Web.config` 直下**（`<connectionStrings>`） |

パス系キーの張り替えは `app.config` を開く（`Web.config` を眺めても見つからない）。
（.NET Core のサンプルはこの二段構成ではなく `appsettings.json` に集約される。）

## サンプル整理：`test*` 一括削除は足場を壊す（固有名）

不要なテスト画面を削るとき、**`test*` 接頭辞で機械的に消さない**（実測）。手順は `opentouryo-project-transform`
「サンプル固有コードの整理」。このサンプルの固有名：

- **残すマスタ＝`testBlankScreen.master`** — 名前は `test` でも**実マスタ**。`login` / `logout` / `menu` /
  `ErrorScreen` / OAuth2 等が `MasterPageFile` に参照する足場。消すと残す画面が全滅する。
- **CRUD 用マスタ＝`sampleScreen.master`**。
- 削除前に、**残す画面の `MasterPageFile` を確認**してから消す。
