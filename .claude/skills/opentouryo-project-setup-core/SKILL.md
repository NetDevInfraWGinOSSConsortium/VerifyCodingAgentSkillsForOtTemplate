---
name: opentouryo-project-setup-core
description: "OpenTouryo 新規立ち上げ（opentouryo-project-setup）の ④⑤＝核心。選んだサンプル（＋開発支援ツール DaoGen_Tool/DPQuery_Tool）を新規リポジトリへ取り出し、.csproj の OpenTouryo.* 参照の HintPath をベンダ先 OpenTouryoAssemblies\\ へ張り替える。3層（WCF/WS）サンプルの CS0246 解消〔(A) そのまま残す／(B) WS 依存を切り離す〕も扱う。サンプル取り出し / 参照張り替え / HintPath / DLL 参照 / CS0246 / WS 依存 / LayerB LayerD を伴う作業のときに使う。前工程はサンプル・取得元選択 opentouryo-project-setup-selection と基盤ビルド opentouryo-project-setup-build、後工程は resource/config の opentouryo-project-setup-config。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# ④⑤ サンプルの取り出しと参照の張り替え（核心）

新規立ち上げ（`opentouryo-project-setup`）の核心。前提：①②で起点サンプルと `<ref>` が決まり
（`opentouryo-project-setup-selection`）、③で基盤 DLL がベンダ済み（`opentouryo-project-setup-build`＝
`OpenTouryoAssemblies\Build_net48\` / `Build_netcore100\`）。この後は ⑥⑦ `opentouryo-project-setup-config`。

## ④ 取り出す

対象サンプルのフォルダを新規リポジトリへコピーする。**`LayerB.cs` / `LayerD.cs` は
サンプルに同梱されたソース**なので、それごと取り出す（別 DLL ではない）。

**★ サブツリー展開は `/**`（再帰）を使う。`/*`（非再帰）は下位フォルダを丸ごと落とす（実測・決定的）。**
ZIP の**サブツリーだけを選択展開**するとき、`unzip ".../<sample>/*"` のような**非再帰 glob だと `Dao\`/`Business\`/`Common\`/
`Properties\` などサブフォルダが丸ごと欠落**する（glob 依存の決定的挙動。ランダムではない）。`/**` で再帰展開する。
**★ さらに、取り出し後は csproj の `<Compile>`/`<EmbeddedResource>`/`<None>`/`<Content>` の `Include` を実ファイルと
突き合わせて欠落確認する（毎回必須）**＝展開方法に依らず漏れ（`Properties\AssemblyInfo.cs`、ClickOnce の `.pfx`/`app.manifest` 等）を
確実に拾う。csproj が参照しているのにファイルが無いと**ビルド失敗**する。

**開発支援ツールも一緒に取り出す。** `Frameworks\Tools\` 配下（`Samples\` ではない）の `DaoGen_Tool`
（墨壺＝D層自動生成）と `DPQuery_Tool`（動的クエリ試験）を取り出し対象に含める（DAO 自動生成・動的 SQL は標準ワークフロー）。
**取り出し先は `OT_Tools\DaoGen_Tool\` / `OT_Tools\DPQuery_Tool\` に固定**（`OT_Tools\` 配下にまとめる。
HintPath は2階層＝`..\..\`。`samples/daogentool.md` / `samples/dpquerytool.md`）。
⑤ と同様に張り替えるが、**両ツールは `HintPath`＋`PackageReference` 混在で net48 でも restore が要る**
（`Microsoft.Data.SqlClient` 等。漏れは `CS0234`）。詳細は `samples/daogentool.md` / `samples/dpquerytool.md`。

## ⑤ 参照を張り替える

サンプルの `.csproj` は、フレームワークを **`Reference` + `HintPath`（DLL 参照）** で参照している。
`Reference Include="OpenTouryo.*"` の **`HintPath` だけ**をベンダ先へ書き換える。

```xml
<!-- net48（core は Build_netcore100\net10.0\ に読み替え） -->
<Reference Include="OpenTouryo.Framework">
  <HintPath>..\OpenTouryoAssemblies\Build_net48\OpenTouryo.Framework.dll</HintPath>
</Reference>
```

- **必要なアセンブリはサンプルの csproj に列挙済み**（`OpenTouryo.Public` / `.Framework` / `.Business` ほか）。
  その `Reference` をそのまま使い、`HintPath` だけ直す。
- **触らないのは NuGet 復元される 3rd-party だけ**（net48＝`packages.config`、core＝`PackageReference`）。
  相対パス（`..\` の数）はプロジェクトの配置に合わせる。
  **★ ただし `develop`（moving ref）を再取得したら 3rd-party の版も基盤 `.csproj` に合わせる**——基盤が上げた `Microsoft.Data.SqlClient` 等をアプリが旧版のままだと
  **ビルドは通り実行時に `FileNotFoundException`**（`MSB3277` 警告が唯一の兆候＝合否は「警告0」で見る。詳細 `references/reference-rewrite.md`）。

**間違えやすい edge case は `references/reference-rewrite.md`**（末尾フォルダ名 `Build\`→`Build_net48\` も変わる／
`MySql`・`Oracle` もベンダ張替＝NuGet 非復元／net48 でも `PackageReference` 併用時は restore／MAX_PATH フラット化）。

## 3層（WCF/WS）サンプルの扱い

一部サンプルは **`WSServer_sample`（B・D層）/ `WSIFType_sample`（受け渡し型）** に依存する（ソースは `Samples\WS_sample`
に実在。元は `WS_sample\Build\*.dll` への DLL 参照だが出力が無く `CS0246`）。**フレームワーク `OpenTouryo.*` は DLL 参照の
ままだが、この2つ（サンプル自身の B・D・型）は ProjectReference に切り替える**（P・B・D を並行開発する対象だから）。解消は2通り：
- **(A) そのまま残す** — 依存元サンプルも取り出し、**`WSServer_sample`/`WSIFType_sample` を ProjectReference にして
  1ソリューションでビルド**（旧「`WS_sample\Build\` へ DLL 配置」は不要）。**セットアップで完結**。詳細＝`samples/webservices.md`。
- **(B) WS 依存を切り離す** — WS 参照を外す（**後工程 `opentouryo-project-transform`**）。

**(A)/(B) の選択・層の削減・画面改変は、セットアップ中に判断を求めない**（開ける状態の後に利用者が決める）。
**WS/3層の共通手順は `samples/webservices.md`、サンプル固有は `samples/<サンプル>.md`**（Web Forms は `samples/webforms.md`、MVC は `samples/mvc.md`）。

<!-- 執筆者メモ（Claude Code は読み込み時に除去）：samples/<サンプル>.md は検証したサンプルから順に整備する残件。
     現状あるのは webforms.md・mvc.md（サンプル）／daogentool.md・dpquerytool.md（開発支援ツール）。
     専用 md が無いサンプルも上の一般手順＋samples/webservices.md で取り出せる。癖が見つかったら md を起こす。 -->

## やってはいけないこと

- **3rd-party の `PackageReference` / `packages.config` まで張り替える** — NuGet 復元に任せる（`OpenTouryo.*` だけ張替）
- **`LayerB.cs` / `LayerD.cs` を別 DLL 化しようとする** — サンプルは同梱ソースが前提
- **`OpenTouryo.*` を `ProjectReference` にする** — 基盤はバイナリ提供が前提。DLL 参照にする
