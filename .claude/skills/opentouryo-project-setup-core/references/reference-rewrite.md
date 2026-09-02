# 参照（HintPath）張り替えの注意点

`opentouryo-project-setup-core` ⑤ の詳細。核心（`Reference Include="OpenTouryo.*"` の `HintPath` を
ベンダ先へ書き換える）は SKILL.md ⑤、ここは**間違えやすい edge case**をまとめる。

## 接頭辞だけでは済まない（末尾フォルダ名も変わる）

net48 サンプルの元 HintPath は `…\Frameworks\Infrastructure\Build\`（サフィックス無し）だが、
ベンダ先は `…\OpenTouryoAssemblies\Build_net48\`。**単純な接頭辞置換ではなく、末尾フォルダ名も変わる**
（`…\Build\` → `…\OpenTouryoAssemblies\Build_net48\`）。

**core（`Build_netcore100\`）は TFM サブフォルダが2種類ある**（実測）：`net10.0\` と `net10.0-windows7.0\`。
**Web / MVC / バッチ / CLI は `net10.0\`、WinForms / WPF（RichClient・2CS）は `net10.0-windows7.0\`** を参照する
（サンプルの csproj の `TargetFramework` に対応）。ベンダ先も `…\Build_netcore100\<TFM>\` の該当サブフォルダを指す。

**⚠ `net10.0-windows7.0\` は標準 `2_/3_Build_netcore100` 直後だと不完全**（実測）：`OpenTouryo.Business` と
`Dam*`（`DamManagedOdp`/`DamMySQL`/`DamPstGrS`）と `Business.RichClient` が**無い**（`net10.0\` 側にはある）。
`3_Build_BusinessRichClient_netcore100.bat` でこれらが揃うので、**`net10.0-windows7.0\` フォルダを丸ごと再ベンダ**してから
張り替える（個別 DLL だけ拾うと `OpenTouryo.Business` で `CS0246`）。→ `opentouryo-project-setup-build` ③。

**★ ベンダされる Dam の集合もランタイムで割れる**：`DamPstGrS`（PostgreSQL＝`NPS`）は **core 専用**
（`DamPstGrS_netcore100.csproj` のみ＝net48 に無い）。core サンプルは `DamPstGrS` を参照するので、
**net48 の DLL 一覧で core の要否を照合すると「無い」と誤判定**する＝**確認はランタイムごとのベンダ先で行う**
（`opentouryo-project-setup-build` §3 の確認パス）。

## 張り替え対象は「ベンダ先 `Build_*\` に含まれる DLL すべて」（`OpenTouryo.*` だけではない）

例：net48 サンプルの `MySql.Data` / `Oracle.ManagedDataAccess` は **`packages.config` に無く**、
HintPath が他サンプルのビルド出力（`..\..\..\WS_sample\Build\...`）を指すため **NuGet では復元されない**。
これらは基盤のビルド出力 `Build_net48\` に同梱される（`OpenTouryo.DamMySQL` / `.DamManagedOdp` が依存）ので、
`OpenTouryo.*` と同様にベンダ先へ張り替える。**触らないのは NuGet 復元される 3rd-party だけ**
（net48＝`packages.config`、core＝`PackageReference`）。

### ★ moving ref で基盤が 3rd-party の版を上げたら、アプリ側の版も合わせる（「触らない」の例外）

**上のルール（3rd-party は NuGet 復元に任せる）は固定タグでは成り立つが、`develop`（moving ref）を再取得すると崩れることがある**：
基盤（例 netcore100）の `Microsoft.Data.SqlClient` が上がる（実測 6.1.3→7.0.0）と、アプリの `.csproj`／`packages.config` が旧版のままでも
**`dotnet build` は成功する**（出るのは `MSB3277`〔バージョン競合〕警告1件だけ）。ところが**実行時に DB 接続の瞬間**
`FileNotFoundException: Could not load file or assembly 'Microsoft.Data.SqlClient, Version=7.0.0.0'` で落ちる（画面は汎用エラーのみ＝ログを見ないと分からない）。

- **対処**：moving ref を再取得・再ベンダしたら、**アプリの `PackageReference`／`packages.config` を基盤の `.csproj` と突き合わせて版を合わせる**。
- **合否判定は「エラー0」でなく「警告0＝`MSB3277` が出ていないこと」**にする（`opentouryo-project-setup-build` の run-verify）。
  「ビルドは通るのに実行で落ちる」型＝AGENTS.md「MS 系開発ツールの落とし穴」の系列。固定タグは版が動かないので不要。
- **どの版に合わせるかは面によって別**：実測では **net48 側の基盤は 6.0.2 のままでアプリ（`packages.config`）とも一致＝影響は netcore100 のみ**だった。両面を各々突き合わせる。

**※ 例外＝`WSServer_sample`/`WSIFType_sample` は DLL 張替の対象外**（ベンダ先 `Build_*\` に含まれない＝サンプル自身の
B・D層/型）。これらは **ProjectReference に切り替える**（`WS_sample\Build\*.dll` の DLL 参照は削除。`samples/webservices.md`）。

**⚠ `MySql.Data` / `Oracle.ManagedDataAccess` の「元」HintPath はサンプルで割れる**（実測。機械的な一括置換だと外す）：
- **MVC(net48)**：`..\..\..\..\Frameworks\Infrastructure\Build\`（DamMySQL 等と同じ場所）
- **WebForms**：`..\..\..\WS_sample\Build\`（3層構成で WS 側を指す。ただし同じ csproj 内でも `OpenTouryo.DamMySQL`
  だけは `..\..\..\..\Frameworks\Infrastructure\Build\` と**別**）

→ **`OpenTouryo.*` と DB DLL を一律の接頭辞で置換せず、各 `HintPath` の実際の「元」を見て**ベンダ先
`..\OpenTouryoAssemblies\Build_net48\`（相対 `..\` はプロジェクト配置に合わせる）へ張り替える。

## net48 でも `PackageReference` を併用することがある（`packages.config` 無し≠復元不要）

net48 は 3rd-party＝`packages.config` が典型だが、**非SDK net48 csproj が `PackageReference` を併用**している例がある
（`Frameworks\Tools` の `DaoGen_Tool` / `DPQuery_Tool` は `Microsoft.Data.SqlClient` 等を `PackageReference` で持つ）。
この場合 **`packages.config` が無くても restore が要る**（`msbuild -t:restore` / `nuget restore` / `dotnet restore`）。
復元しないと `using Microsoft.Data.SqlClient;` が `CS0234` になる（＝参照欠落に見えるが実体は復元漏れ。ベンダ先 DLL への
HintPath 追加でも compile は通るが、`Microsoft.Data.SqlClient` は SNI ネイティブを要するので restore が正道）。

## 非SDK csproj を直ビルドするなら `Platform` に注意（`Any CPU` ≠ `AnyCPU`）

非SDK net48 csproj を **`.csproj` 直叩き**で `msbuild X.csproj /p:Platform="Any CPU"` すると **「OutputPath が設定されていません」で失敗**する
ことがある（実測）。csproj の `PropertyGroup` 条件は **`'$(Platform)'=='AnyCPU'`（空白なし）** で書かれており、`Any CPU`（空白あり）だと
どの条件にも当たらず `OutputPath` 未定義になるため。→ **`.sln` 経由でビルドする**（sln が `Any CPU`↔`AnyCPU` を解決する）か、
直叩きなら **`/p:Platform=AnyCPU`（空白なし）** を渡す。

## 深いリポは MAX_PATH(260)

`Samples\WebApp_sample\...` の相対配置を保つと、`nuget restore` がパッケージ内部の深いパス
（`packages\...\analyzers\...\pt-BR\...`）で超過して失敗する（実測）。**取り出したプロジェクトをリポ直下へ
フラット化**し、相対 `HintPath`（`OpenTouryo.*`・WS 参照とも）を新配置に合わせて張り替える
（`long path` 有効化でも可）。WS 参照を含む3層サンプルのフラット化は `samples/webservices.md`。
