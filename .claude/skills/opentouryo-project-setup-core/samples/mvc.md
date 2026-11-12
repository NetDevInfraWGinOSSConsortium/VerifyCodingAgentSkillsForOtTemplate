# サンプル固有メモ：ASP.NET MVC（`Samples\WebApp_sample\MVC_Sample`・net48 / `Samples4NetCore\Backend\MVC_Sample`・core）

`opentouryo-project-setup-core` でこのサンプルを取り出すときの、**サンプル固有の癖**。
（WS/3層まわりの共通機構は `webservices.md`、HintPath の edge case は `references/reference-rewrite.md`。）

## ★ MVC(net48) の WS 参照は「未使用の陳腐化参照」＝実使用を確認して削除（目視検出で是正）

`MVC_Sample.csproj`(net48) は `WSIFType_sample`/`WSServer_sample` を **`..\..\..\WS_sample\Build\*.dll`（DLL 参照）**で持つが、
**MVC のコードは WS 型を一切使っていない**（実測：`.cs`/`.cshtml` に `using WSIFType_sample`・`WSServer_sample`・WS 型が **0 件**）
＝**陳腐化した未使用参照**（`About`/`Contact.cshtml` の残骸と同類）。

- → **WS 参照を (A) ProjectReference 化・`.sln` に追加してはいけない**（不要な参照・sln 肥大が残る＝**目視で検出された不具合**）。
  **例外：①′ で「B層を WS_sample に置いて共用する」を選んだとき**は、消さずに ProjectReference にする（`webservices.md` の (C)。これから B層を置くので「未使用」ではない）。
- **消す前に、①′（B層の置き場所）が決まっているかを確かめる。決まっていなければ聞く**（`opentouryo-project-setup-selection`）。
- **取り出し時に `.cs`/`.cshtml` を grep して WS 型の実使用を確認**し、無ければ **WS 参照（DLL 参照）を csproj から削除**する
  （使っていないので削除しても `CS0246` は出ない）。
- **WebForms との違い**：WebForms は `sampleScreen_cc.aspx.cs` が WS 型（`TestParameterValue`/`TestReturnValue`）を**実際に使う**ので (A)/(B) の判断が要る。
  MVC は使っていないので判断の余地なく**削除**＝**(A)/(B) は「参照があるか」でなく「実使用があるか」で決める**（共通手順は `webservices.md`）。

## (C) を選んだとき：MVC 自身の B層を Shared に張り替える（net48・core とも。実測）

`MVC_Sample`（net48・core とも）は自分の `Logic\`（`LayerB`・`LayerD`・`DaoShippers`・引数と戻り値のクラス）を持ち、`Crud1`・`Crud2` はそれを呼ぶ。
(C) では **`Logic\` を消し（csproj の `<Compile Include>` も）、コントローラを `WSServer_sample.Business.LayerB`・`WSIFType_sample` の型に張り替える**
（残すと、画面は MVC 自身の B層を使ったままで、Shared の B層は使われない）。Shared の B層は MVC 版と**引数・戻り値の形が違う**ので、P層に変換を足す
（例 `Models\ShipperMapper.cs`）：

| | MVC 自身の B層 | Shared の B層 | P層での変換 |
| --- | --- | --- | --- |
| 引数 | ViewModel（`Shipper`） | `ShipperID`（`int`）・`CompanyName`・`Phone` | ViewModel から設定（`ShipperID` は `long?` → `int`） |
| 一覧の戻り値 | `List<ShipperViweModel>` | `Obj` に `DataTable`／`DataSet` | `DataToPoco.DataTableToList<T>`。DataReader 版は列名が `c1`〜`c3` なので位置で変換 |
| 1 件の戻り値 | `Obj`＝ViewModel、`Obj2` | `ShipperID`・`CompanyName`・`Phone` | 戻り値から ViewModel を作る。`Obj2` を使うテストのコード（PocoToPoco）は消す |

確かめた：msbuild 警告 0・エラー 0、`aspnet_compiler` 成功、作者が起動して画面が Shared の B層で動いた（VerifyCaTddForOT、2026-11-12）。
MVC core（`Backend\MVC_Sample`）も同じ手順で通った：自身の `Logic\` の形が net48 と同じなので、`ShipperMapper.cs` は net48 のものをそのまま使える
（`dotnet build` 警告 0・エラー 0、`/Home/Login`・`/Home/Index` が 200。2026-11-12）。core の DB 到達（Crud 画面）は確かめていない。
Web Forms は変換が要らない（`webforms.md`）。

## MySql/Oracle の HintPath は「Frameworks 側」＝WebForms と割れる

同じ csproj の `MySql.Data`/`Oracle.ManagedDataAccess` の**元 HintPath は MVC(net48) では
`..\..\..\..\Frameworks\Infrastructure\Build\`**（WebForms は `WS_sample\Build\`）。**機械的な一括置換で外す**ので、
各 HintPath の実際の「元」を見てベンダ先へ張り替える（`references/reference-rewrite.md`）。

## MVC core（`Samples4NetCore\Backend\MVC_Sample`）＝WS 依存なし・SDK 形式

- **WS 依存なし**（3層でない。①′ で共用を選んだら `WS_sample_Core` を参照する＝`webservices.md` の (C)）。SDK 形式で 3rd-party は `PackageReference`（`log4net` / `Microsoft.Data.SqlClient` /
  `Newtonsoft.Json`）＝触らない。`OpenTouryo.*` の HintPath だけベンダ先 `Build_netcore100\<TFM>\` へ（MVC core は `net10.0\`）。
- config は `appsettings.json`（**キー集合・綴り・スラッシュ区切り・JSONC が net48 と割れる**＝`opentouryo-project-setup-config` /
  `references/resource-config.md`。core の ⑥ は見落とされやすい）。

## 上流の残骸：`Views\Home\{About,Contact}.cshtml`（develop）

`MVC_Sample.csproj`(net48/develop) は `Views\Home\About.cshtml` / `Contact.cshtml` を `<Content Include>` するが
**実ファイルが ZIP に無い**（参照するアクション・リンクも無い＝陳腐化した残骸）。`Content` なのでビルドは通るが、
VS で「見つからないファイル」表示になる。**④ の Include 突き合わせで検出できる**。
**セットアップでは構成変更しないので上流のまま残す**（除去は `opentouryo-project-transform` の領分。上流＝OpenTouryo 本体の課題）。
