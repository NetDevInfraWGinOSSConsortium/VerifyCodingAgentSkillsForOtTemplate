# ws-decouple — WS 依存の切り離し（俗称「2層化」）

`opentouryo-project-transform` の subcommand。**サンプルから WS（Web サービス）依存を外す。** 2層サンプル画面は残し、
WS 参照を削る（「3層/2層」は呼び方の別で、判断軸は **WS 依存の有無**。core は通信制御を使ってもインプロセスのみ＝実質2層になり得る）。

一部サンプル（例：`WebForms_Sample`）は WS 依存があり、**他サンプルの B・D層/型**（`WSServer_sample` / `WSIFType_sample`。
(A) 構成では ProjectReference＝`opentouryo-project-setup` の `samples/webservices.md`）に依存する。WS が不要なら次を削る／直す。

## ★実行時に落ちる罠：`TMInProcessDefinition.xml`（最重要）

**WS 参照を外すとビルドは 0 error のまま、通信制御画面が実行時に落ちる。** 通信制御経由の画面（例 `sampleScreen_cc.aspx.cs`）は
`CallController.Invoke(<サービス論理名>, …)` で B層を呼ぶ。この論理名は**インプロセス名前解決定義**
（`FxXMLTMInProcessDefinition`＝`resource\Xml\TMInProcessDefinition.xml`）で解決され、**実測では全 id が
`assemblyName="WSServer_sample" className="WSServer_sample.Business.LayerB"`**。WS 参照を消すと、
実行時に **`System.ArgumentException: アセンブリ名：[WSServer_sample]が存在しません。`**（`Latebind.InvokeMethod` ← `CallController.Invoke`）で画面が落ちる。

**手当て**：共有定義（`resource\Xml\TMInProcessDefinition.xml`）は他サンプル用にそのまま残し、
**アプリ専用の `resource\Xml\TMInProcessDefinition_<App>.xml`**（例 `_WebForms_Sample`。中身は
`assemblyName="WebForms_Sample" className="WebForms_Sample.LayerB"`。**同梱 B層は WSServer 版と UOC メソッドが同一**）を作り、
`app.config` の `FxXMLTMInProcessDefinition` をそちらへ向ける。＝**「WS 参照を消したら、この定義ファイルの向き先もアプリ側 B層へ替える」**。

## 削る

- **WS 参照**：csproj の `WSIFType_sample` / `WSServer_sample`（ProjectReference）。**さらに `.sln` からも当該2プロジェクトを除去する**
  （csproj だけ消しても sln に残るとビルド対象・`nuget restore <sln>` 対象に残り続ける＝セットアップ側「sln へ追加」の対）。
- **3層（3Tier）画面**（消すなら）：`Aspx\sample\3Tier\`、`menu.aspx` の3層リンク、専用周辺
  （`AppCode\sample\3TierTableAdapter\ProductsTableAdapter.cs`・3層専用 B層 `AppCode\sample\Business\GetMasterData.cs`）。
  **※これは WS 依存の切り離しとは別判断**（下記）。

> **3層画面は WS 依存ではない。** 実測で `_3TierParameterValue`/`_3TierReturnValue`/`_3TierEngine` は
> **基盤（`Touryo.Infrastructure.Business.Common/Business`）の汎用データアクセス**で、`WSIFType_sample`/`WSServer_sample` を一切参照しない。
> ＝**3層画面を消さなくても WS 依存は切れる**。実際に WS 型を掴んでいたのは **`sampleScreen_cc.aspx.cs` の1ファイルだけ**。
> 「WS 依存の切り離し」と「3層データバインド サンプルの除去」は**別の end-state**として分けて判断する。

> **`MySql.Data.dll` / `Oracle.ManagedDataAccess.dll` の HintPath**（実測）：WebForms の csproj はこの2つも `WS_sample\Build\` を参照する。
> **ただしセットアップ ⑤ を経ていればベンダ先（`OpenTouryoAssemblies\Build_net48\`）へ張替済み**で、`WS_sample` を消さない構成なら無害
> ＝**セットアップ→変形の順なら「確認だけ」で済む**。`WS_sample` ごと消して完全に断つ場合のみ張替が要る（`opentouryo-project-setup-core` ⑤）。

> **`Web.config` の endpoint（`system.serviceModel`）は削らない。** これは3層固有ではなく**フレームワークの Transmission WCF 設定**
> （`IWCFHTTPSvcForFx` / `IWCFTCPSvcForFx`）と `IJSONService`。`WSServer_sample` は (A)＝ProjectReference でインプロセス呼び出しされ
> 専用 endpoint を持たない。消しても切り離しに不要なうえ、実行時構成を壊しかねない。

## 直す（見落としやすい罠）

**2層画面が WS 側（`WSIFType_sample`）の型を掴んでいることがある。** `sampleScreen_cc.aspx.cs` は
`using WSIFType_sample;` で `TestParameterValue` / `TestReturnValue` を **WS 側の参照から**解決している。
同名クラスがサンプル同梱ソース（`AppCode\sample\Common\`、`using MyType;`）にもあるので、
`using WSIFType_sample;` → `using MyType;` に差し替える。

## 確実な進め方

WS 参照（`WSIFType_sample` / `WSServer_sample`）を csproj・sln から外してビルドし、**`CS0246` が出た箇所を上から潰す**。
**★ 外したら `bin\` の旧 WS アセンブリも消す（or `Clean`）＝実行時検証の偽陽性を防ぐ**：csproj/sln から参照を外しても **`bin\WSServer_sample.dll`/`WSIFType_sample.dll` は残る**（msbuild は bin を掃除しない）。残ると `Latebind` が見つけて **`TMInProcessDefinition` を直さなくても動く＝「2層化 OK」に見える偽陽性**（上の★罠が発現しない）うえ、成果物に WS アセンブリが同梱されたまま＝切り離し未完了。**bin から2 DLL を削除してから実行検証する**（実測：これで初めて `ArgumentException` が再現）。
その後**必ず実行して**通信制御画面を叩く（ビルドだけではこの実行時エラーを検出できない）。**ポストバックを伴うので
StateServer 稼働が前提**（＝要管理者。昇格不可なら一時 InProc で検証し戻す。押すボタン name はマスタページ側のことがある）＝
非対話手順は `opentouryo-project-setup-config` の `references/run-verify.md`。

- 同名クラスが同梱ソースにある → `using` を差し替える（上記の罠）
- 3層専用のコードだった → 削る
- `CallController.Invoke` 系の画面 → `TMInProcessDefinition` の向き先をアプリ B層へ

## end-state で決めること（残す/消すの判断）

- **残る WS 呼出 UI**：2層化後も通信制御画面の `ddlCmctCtrl` に「ASP.NET WebAPI呼出」等の **WS 呼出の選択肢が残る**。
  既定の「インプロセス呼出」は動くが、WS の選択肢は（WS ホストを建てない限り）失敗する。**選択肢を残すか削るかを end-state として明記**する
  （markup 変更を伴うので、指示範囲を確認してから触る）。
- **`WS_sample` ごと消すか**：**他サンプルが同じ WS 資産を共有していないか確認する**。例：`WSClientWin_sample`（3層クライアント）が
  `WS_sample\{WSIFType,WSServer}_sample\` を使っていると、`WS_sample` を消すとそのサンプルが壊れる。
  共有しているなら **当該プロジェクトからの参照を外すだけに留める**（`WS_sample` 自体は残す）。

## 未収録：WebForms 以外のサンプル

現行手順は **`WebForms_Sample` 前提（裏取り済み）**。`MVC_Sample` も WS 依存を持つ（`MVC_Sample.csproj` が
`WSIFType_sample`/`WSServer_sample` を `..\..\..\WS_sample\Build\*.dll` へ HintPath 参照）が、
**参照形態が違う**（WebForms＝ProjectReference (A) / MVC＝DLL Reference (B)）ため、削り方・張り替え先が一部変わる。
＝**MVC は未収録**。来たら SKILL の「未収録の対象が来たら」に従い、**未収録と断ったうえで実ソースを裏取りしつつ段階ビルドでベストエフォート**する。
