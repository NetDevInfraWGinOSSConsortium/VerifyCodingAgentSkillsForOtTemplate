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
