# 開発支援ツール：DaoGen_Tool（墨壺 ＝ D層自動生成ツール）

`opentouryo-project-setup-core` ④ で取り出す **開発支援 GUI ツール**。テーブル定義から
**自動生成Dao**（`DaoXxx : MyBaseDao`。`DaoShippers` 等）を生成する。生成物の使い方は
`opentouryo-dao-generated`、系統の選び方は `opentouryo-layer-d`。**手書きせず、テーブル定義が
変わったらこのツールで再生成する**のが前提なので、プロジェクトに取り出しておく。

## 置き場所とランタイム

- ソース：**`Frameworks\Tools\DaoGen_Tool`**（`Samples\` ではない。基盤ツリー配下）。
- WinExe（WinForms GUI）。`AssemblyName` は `OpenTouryo.DaoGen_Tool`。**新しい ref は非対話 CLI（`/CUI`）も持つ**
  ＝実行時の CLI 起動（エージェント/CI で生成）は **`opentouryo-daogen-cli`**。
- net48：`DaoGen_Tool.csproj` / `.sln`（msbuild）。
- net10.0：`DaoGen_ToolCore.csproj` / `.sln`（`net10.0-windows7.0`＝Windows 専用。`dotnet build`）。

標的サンプルのランタイムに合わせてどちらかを使えばよい（DAO 生成が目的なので net48 版だけでも足りる）。

## 取り出しと参照張り替え（⑤ と同じ要領）

1. `DaoGen_Tool` フォルダを **`OT_Tools\DaoGen_Tool\`** に置く（`DaoGen_Tool`/`DPQuery_Tool` は **`OT_Tools\` 配下に
   まとめる**＝リポ直下に散らさない。配置はこの1通りに固定）。
2. **参照は `HintPath` と `PackageReference` が混在する。両方を面倒みる**（配置が `OT_Tools\<tool>\`＝ルートから2階層なので
   ベンダ先 HintPath は `..\..\`）。
   - **`<Reference>`+HintPath**（`OpenTouryo.Public` / `MySql.Data` / `Oracle.ManagedDataAccess`）→ ベンダ先へ張り替える。
     net48 は `..\..\Infrastructure\Build\` → **`..\..\OpenTouryoAssemblies\Build_net48\`**（末尾フォルダ名も変わる。
     `MySql.Data`/`Oracle` も NuGet 非復元なので対象。→ `references/reference-rewrite.md`）。
     core は `OpenTouryo.*` を **`..\..\OpenTouryoAssemblies\Build_netcore100\net10.0\`** へ。
   - **`<PackageReference>`（net48 も持つ。`packages.config` は無い）→ ビルド前に restore する**
     （`msbuild -t:restore` / `nuget restore` / `dotnet restore`）。**`Microsoft.Data.SqlClient` 等がここにある**ので、
     復元しないと `using Microsoft.Data.SqlClient;` が **`CS0234`**（＝「参照が無い」ように見えるが実体は復元漏れ）。
     `Microsoft.Data.SqlClient` は **SNI ネイティブ**を要するため **restore が正道**（ベンダ先 DLL への HintPath 差し替えでも
     compile は通るが、ネイティブ依存を落として GUI 起動で失敗しやすい）。core の 3rd-party も同じく restore に任せる。
3. ビルドして起動確認（WinForms なので Windows で実行）。
4. **★ テンプレートも取り出す**（`/CUI` の `/TEMPLATE` に渡す `DGenTemplates`）＝**`Frameworks\Tools` 配下ではなく `root\files\tools\DGenTemplates`** にあるので ⑤ の取り出し対象（`Samples`/`Frameworks/Tools`）から漏れる＝**リポジトリに存在しないまま**になりやすい。**`OT_Tools\DGenTemplates\` に置く**（`DaoTemplate*.cs`/`.sql`/`.xml` が平置き）。生成 Dao の名前空間・親クラス2 名等はこのテンプレートで決まる（`opentouryo-daogen-cli`）。

## 使い方の要点

- DB に接続してテーブルを選び、**自動生成Dao のソースを出力**する（出力したソースをプロジェクトの D層へ入れる）。
- **非対話（エージェント/CI）で生成するなら CLI＝`opentouryo-daogen-cli`**（`/CUI`・`/HELP`。GUI は開かない）。
- 生成物の命名体系（`S1_Insert`/`D2_Select` 等、`PK_列名`/`Set_列名_forUPD` 等）と楽観排他は `opentouryo-dao-generated`。
- SELECT を含む INSERT/UPDATE は自動生成の対象外（個別Dao ＝ `opentouryo-dao-custom`）。
