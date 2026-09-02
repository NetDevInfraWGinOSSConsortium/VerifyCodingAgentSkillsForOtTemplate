# サンプル固有メモ：ASP.NET MVC（`Samples\WebApp_sample\MVC_Sample`・net48 / `Samples4NetCore\Backend\MVC_Sample`・core）

`opentouryo-project-setup-core` でこのサンプルを取り出すときの、**サンプル固有の癖**。
（WS/3層まわりの共通機構は `webservices.md`、HintPath の edge case は `references/reference-rewrite.md`。）

## ★ MVC(net48) の WS 参照は「未使用の陳腐化参照」＝実使用を確認して削除（目視検出で是正）

`MVC_Sample.csproj`(net48) は `WSIFType_sample`/`WSServer_sample` を **`..\..\..\WS_sample\Build\*.dll`（DLL 参照）**で持つが、
**MVC のコードは WS 型を一切使っていない**（実測：`.cs`/`.cshtml` に `using WSIFType_sample`・`WSServer_sample`・WS 型が **0 件**）
＝**陳腐化した未使用参照**（`About`/`Contact.cshtml` の残骸と同類）。

- → **WS 参照を (A) ProjectReference 化・`.sln` に追加してはいけない**（不要な参照・sln 肥大が残る＝**目視で検出された不具合**）。
- **取り出し時に `.cs`/`.cshtml` を grep して WS 型の実使用を確認**し、無ければ **WS 参照（DLL 参照）を csproj から削除**する
  （使っていないので削除しても `CS0246` は出ない）。
- **WebForms との違い**：WebForms は `sampleScreen_cc.aspx.cs` が WS 型（`TestParameterValue`/`TestReturnValue`）を**実際に使う**ので (A)/(B) の判断が要る。
  MVC は使っていないので判断の余地なく**削除**＝**(A)/(B) は「参照があるか」でなく「実使用があるか」で決める**（共通手順は `webservices.md`）。

## MySql/Oracle の HintPath は「Frameworks 側」＝WebForms と割れる

同じ csproj の `MySql.Data`/`Oracle.ManagedDataAccess` の**元 HintPath は MVC(net48) では
`..\..\..\..\Frameworks\Infrastructure\Build\`**（WebForms は `WS_sample\Build\`）。**機械的な一括置換で外す**ので、
各 HintPath の実際の「元」を見てベンダ先へ張り替える（`references/reference-rewrite.md`）。

## MVC core（`Samples4NetCore\Backend\MVC_Sample`）＝WS 依存なし・SDK 形式

- **WS 依存なし**（3層でない）。SDK 形式で 3rd-party は `PackageReference`（`log4net` / `Microsoft.Data.SqlClient` /
  `Newtonsoft.Json`）＝触らない。`OpenTouryo.*` の HintPath だけベンダ先 `Build_netcore100\<TFM>\` へ（MVC core は `net10.0\`）。
- config は `appsettings.json`（**キー集合・綴り・スラッシュ区切り・JSONC が net48 と割れる**＝`opentouryo-project-setup-config` /
  `references/resource-config.md`。core の ⑥ は見落とされやすい）。

## 上流の残骸：`Views\Home\{About,Contact}.cshtml`（develop）

`MVC_Sample.csproj`(net48/develop) は `Views\Home\About.cshtml` / `Contact.cshtml` を `<Content Include>` するが
**実ファイルが ZIP に無い**（参照するアクション・リンクも無い＝陳腐化した残骸）。`Content` なのでビルドは通るが、
VS で「見つからないファイル」表示になる。**④ の Include 突き合わせで検出できる**。
**セットアップでは構成変更しないので上流のまま残す**（除去は `opentouryo-project-transform` の領分。上流＝OpenTouryo 本体の課題）。
