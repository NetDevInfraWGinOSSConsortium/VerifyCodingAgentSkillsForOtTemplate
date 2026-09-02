# 開発支援ツール：DPQuery_Tool（動的パラメタライズドクエリ 試験ツール）

`opentouryo-project-setup-core` ④ で取り出す **開発支援 GUI ツール**。SQL 定義ファイル
（静的 `.sql` / 動的 `.xml`）を**試験実行**して、動的 SQL の組み立て結果を確認する。
SQL 定義の書き方（タグ・`@` パラメタ・ユーザパラメタ・`PARAM`）は `opentouryo-query-definition`。

## `PARAM` タグとの関係

`.xml` の `<PARAM>`（`.sql` の `/*PARAM* ... *PARAM*/`）は、**このツールで試験実行するときのテスト値定義**で、
**実行時（アプリ本体）には削除される**（`opentouryo-query-definition` の PARAM タグ節）。動的クエリを書いたら
このツールで PARAM を与えて展開結果を確認する、という使い方。

## 置き場所とランタイム

- ソース：**`Frameworks\Tools\DPQuery_Tool`**（`Samples\` ではない。基盤ツリー配下）。
- WinExe（WinForms の GUI）。`AssemblyName` は `OpenTouryo.DPQuery_Tool`。
- net48：`DPQuery_Tool.csproj` / `.sln`（msbuild）。
- net10.0：`DPQuery_ToolCore.csproj` / `.sln`（`net10.0-windows7.0`＝Windows 専用。`dotnet build`）。

## 取り出しと参照張り替え（⑤ と同じ要領）

1. `DPQuery_Tool` フォルダを **`OT_Tools\DPQuery_Tool\`** に置く（`DaoGen_Tool`/`DPQuery_Tool` は **`OT_Tools\` 配下に
   まとめる**＝リポ直下に散らさない。配置はこの1通りに固定）。
2. **参照は `HintPath` と `PackageReference` が混在する。両方を面倒みる**（配置が `OT_Tools\<tool>\`＝ルートから2階層なので
   ベンダ先 HintPath は `..\..\`）。
   - **`<Reference>`+HintPath**（`OpenTouryo.Public` / `.DamManagedOdp` / `.DamMySQL` / `MySql.Data` /
     `Oracle.ManagedDataAccess`）→ ベンダ先へ張り替える。net48 は `..\..\Infrastructure\Build\` →
     **`..\..\OpenTouryoAssemblies\Build_net48\`**（末尾フォルダ名も変わる。`MySql.Data`/`Oracle` も NuGet 非復元で対象。
     → `references/reference-rewrite.md`）。core は `OpenTouryo.*` を **`..\..\OpenTouryoAssemblies\Build_netcore100\net10.0\`** へ。
   - **`<PackageReference>`（net48 も持つ。`packages.config` は無い）→ ビルド前に restore する**
     （`msbuild -t:restore` / `nuget restore` / `dotnet restore`）。**`Microsoft.Data.SqlClient` 等がここにある**ので、
     復元しないと `using Microsoft.Data.SqlClient;` が **`CS0234`**。`Microsoft.Data.SqlClient` は **SNI ネイティブ**を要するため
     **restore が正道**（ベンダ先 DLL への HintPath 差し替えは compile は通るがネイティブ依存を落として起動で失敗しやすい）。
3. ビルドして起動確認（WinForms なので Windows で実行）。
