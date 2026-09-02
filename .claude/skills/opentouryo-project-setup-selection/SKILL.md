---
name: opentouryo-project-setup-selection
description: "OpenTouryo 新規立ち上げ（opentouryo-project-setup）の ①②。起点にするサンプル系列を選び（作りたいもの＝ASP.NET MVC / Web Forms / Windows Forms 2CS / WPF 2CS / 3層リッチクライアント〔WSClient_sample〕/ バッチ / CLI）、OpenTouryo の取得元 <ref>（固定タグ〔安定運用〕または develop〔最新追従〕）をユーザに選ばせる。全系列を必ず提示し間引かない、固定タグは番号をユーザに確認する、が要点。サンプル選択 / 起点サンプル / どのサンプル / 取得元 / 固定タグ / develop / バージョン選択 を伴う作業のときに使う。選んだら基盤ビルドは opentouryo-project-setup-build、取り出しは opentouryo-project-setup-core。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# ①② サンプルと取得元を選ぶ

新規立ち上げ（`opentouryo-project-setup`）の最初の工程。**起点サンプル**と**取得元 `<ref>`** を決める。
決めたら ③ `opentouryo-project-setup-build`（基盤ビルド）→ ④⑤ `opentouryo-project-setup-core`（取り出し）へ。

## ① 取り出すサンプルを選ぶ

**作りたいものに合うサンプルが起点になる。** パスの接頭辞は **net48＝`Samples\`／net10.0＝`Samples4NetCore\`**
（Web 系は `Samples4NetCore\Backend\`、2CS/Bat/CLI/WS 系は `Samples4NetCore\Legacy\`）。下表は各系列の起点。

| 作りたいもの | サンプル（系列\起点） | ランタイム | WS/3層依存 |
| --- | --- | --- | --- |
| ASP.NET MVC | `WebApp_sample\MVC_Sample`（core は `Backend\MVC_Sample`） | net48 / net10.0 | **net48:あり** / core:なし |
| Web Forms | `WebApp_sample\WebForms_Sample` | **net48 のみ** | **あり（transform 前提）** |
| Windows Forms（2層C/S） | `2CS_sample\2CSClientWin_sample` | net48 / net10.0 | なし |
| WPF（2層C/S） | `2CS_sample\2CSClientWPF_sample` | net48 / net10.0 | なし |
| 3層リッチクライアント（WinForms/WPF・WS 経由） | `WS_sample\WSClient_sample\WSClientWin_sample`（`WPF`/`WinCone` も同階層で WS 依存あり。**`Win2` は例外＝WS 非依存の単独 P層 UI デモ**） | net48（core は ※実用性なし） | **あり**（Win/WPF/WinCone。**Win2 はなし**） |
| バッチ | `Bat_sample\SimpleBatch_sample`（再実行可 `RerunnableBatch_sample`〜`3`） | net48 / net10.0 | なし |
| CLI（コンソール） | `CLI_sample\Simple_CLI`（認証付 `DAG_Login_CLI` / `LIR_Login_CLI`） | **net10.0 のみ** | なし |

**「WS/3層依存」列の凡例**：`なし`＝csproj で WS 参照無しを確認済み／`あり`＝WS DLL 参照あり
（取り出し直後に missing-ref か `CS0246`。解消は ④⑤ の `opentouryo-project-setup-core`）。

**★ CLI は net10.0 のみ（net48 はドロップ）**：net48 の `CLI_sample\*`（Simple/DAG_Login/LIR_Login）は
**csproj が無く README だけ**（`Sharprompt` が .NET Fx サポートを終了したため本体が net48 版をドロップ）。
CLI を選んだら **net10.0（`Samples4NetCore\Legacy\CLI_sample\`）** を起点にする（Web Forms が net48 のみ、の逆）。
**依存差＝CLI で一般化しない**：`Simple_CLI` は純テンプレ（OpenTouryo 依存なし＝⑤ 張替不要）だが、認証付き
`DAG_Login_CLI`/`LIR_Login_CLI` は **OpenTouryo 依存あり**（Framework/Public/Public.Security・net10.0）＝⑤ HintPath 張替が要る。

**★ RichClient 基盤の追加ビルドが要るサンプル（WS/3層依存とは別軸）**：**Windows Forms 2CS・WPF 2CS・
3層リッチクライアント**（`2CSClientWin/WPF`・`WSClient_*`）は `OpenTouryo.Business.RichClient` を参照するが、
③ が回す `2_/3_Build_*` サブセットには含まれない（別 sln `BusinessRichClient_*.sln` を追加ビルド。フル一式／`9_CICD.bat`
なら出る。**base2 の有無と無関係・素の依存**）。
→ これらを選んだら「同一ランタイムは ③ 流用でスキップ可」の例外＝**③ に RichClient 追加ビルドが必須**
（`opentouryo-project-setup-build`）。バッチ・CLI・MVC・Web Forms は不要。**netcore は `net10.0-windows7.0\` の
`Business`/`Dam*` ごと欠けるのでフォルダ丸ごと再ベンダ**（net48 は `Business.RichClient` のみ）。
**★ `CustCtrl_sample`（2CS 機能デモ）はさらに `OpenTouryo.CustomControl.RichClient`（WinForms 版）も要る**＝`BusinessRichClient_net48.sln`
に同梱だが net48 のベンダ コピーで漏れがち（追加ビルド後に sln の全出力を照合。netcore は揃う。詳細は build スキル）。

**WPF 2CS は WinForms 2CS とほぼ同一手順**（実測）：デスクトップ exe・RichClient 基盤要・取り出し／参照張替は同じで、
config は `SqlTextFilePath` の1点張替で足りることが多い（④⑤＝`opentouryo-project-setup-core`、⑥⑦＝`-config`）。

**サンプル選択は2段階。どちらも間引かず・勝手に決め打ちしない。**

1. **系列を必ず全部提示して選ばせる**（実測：4択にまとめて **3層リッチクライアント＝`WSClient_sample` と WPF が
   選択肢から欠落**した）。選択 UI が選択肢数を制限しても、収まらなければ**全系列を番号付きリストで提示**する。
2. **選んだ系列に複数のサンプル（派生/variant）があれば、それも提示して選ばせる**（**勝手に代表を1つに決めない**。
   実測：バッチ系列で `SimpleBatch_sample` が無選択で選ばれた）。例：バッチ＝`SimpleBatch_sample` /
   `RerunnableBatch_sample`〜`3`／`WSClient_sample`＝`Win`/`WPF`/`WinCone`（3層WS）・`Win2`（WS 非依存の単独 P層 UI デモ）／**`2CS_sample` の機能デモ＝
   `CustCtrl_sample` / `GenDaoAndBatUpd_sample` / `TimeStamp_sample`（いずれも net48・net10.0 両対応）・
   `AsyncEvent_sample`（net48 のみ）**。派生が1つだけなら確認不要。どれが良いか不明なら候補の違いを添えて委ねる。
3. **派生ごとに対応ランタイムが違うことがある。勝手にランタイムを落とさない**（実測：2CS 機能デモ
   `CustCtrl`/`GenDaoAndBatUpd`/`TimeStamp` を「net10.0 のみ」と誤提示＝net48 が実在するのに欠落）。**各派生の
   ランタイムは、その派生フォルダに csproj があるか（net48＝`Samples\`配下／net10.0＝`Samples4NetCore\`配下）で判断**する。

**「WS/3層依存あり」の内訳**（取り出し直後 `CS0246` が残る。依存元ソースは `Samples\WS_sample` に実在）：
- **`WebForms_Sample`**（net48）— WS を利用（core 化の (B) 切り離しも可）。
- **`MVC_Sample` の net48**（`Crud1Controller` が `TestParameterValue` 等の WS 型を使用。**core の MVC はなし**）。
- **`WS_sample\WSClient_sample` の Win/WPF/WinCone**（core は `Samples4NetCore\Legacy\...`）— 3層リッチクライアント＝構成上 WS 必須。
  **※ core 版は `BinaryFormatter` 廃止で実質インプロセスのみ＝実用は net48 側**（`opentouryo-transmission`）。
  **※ WSClient の各 variant は依存構造が異なる**（`Win2` は WS 非依存の単独 P層）。**名前で決めず、取り出し時に csproj の
  `WSServer_sample`/`WSIFType_sample` 参照・WS 型使用の有無で判断する**（④⑤＝`opentouryo-project-setup-core` の `samples/webservices.md`）。

解消手順（(A) そのまま残す／(B) WS 依存を切り離す）は ④⑤＝`opentouryo-project-setup-core` の「3層サンプルの扱い」
（共通機構は同スキルの `samples/webservices.md`）。到達点は「開ける状態」で as-is クリーンビルドは保証しない。

**WPF は P層フレームワークを持たない**（`opentouryo-layer-p-winforms-screen`）。
`2CS_sample\2CSClientWPF_sample` を参考に、画面は素の WPF として実装する。

## ② 取得元をユーザに選ばせる

**どのバージョンの OpenTouryo を使うかをユーザに確認する。**

| 選択 | `<ref>` | 用途 |
| --- | --- | --- |
| 固定タグ | **どのタグかをユーザに確認**（例示は下記） | **安定運用**（`3_BuildLibsAtOtherRepos.bat` 相当） |
| develop | `develop` | 最新追従（`...InTimeOfDev.bat` 相当） |

**「固定タグ」を選ばれたら、具体的なタグ番号を必ずユーザに確認する。`03-20` は例示であり、
勝手に既定値として使わない**（作者フィードバック 2026-07-18：例示タグが強制選択されて選べなかった）。
利用可能なタグは OpenTouryo リポジトリの releases / tags（`https://github.com/OpenTouryoProject/OpenTouryo/tags`）
で確認できる。最新の安定タグが分からなければ、候補を提示するか latest を案内してユーザに決めてもらう。
**親クラス2 をカスタマイズするなら固定タグにする**（`develop` は土台が動く。`opentouryo-base2-customize`）。

選んだサンプルの**標的ランタイム**と `<ref>` を、次の ③ `opentouryo-project-setup-build` に渡す。

**既存 repo に 2本目以降を追加するとき**：既に同一ランタイムの基盤がベンダ済み（`OpenTouryoAssemblies\Build_net48\`
等が在る）なら **③ 基盤ビルドはスキップして流用**できる（再ビルド不要）。③ が要るのはタグを変える／別ランタイムを
足すときだけ。既存成果を壊さないよう追加分だけを対象にする（`opentouryo-project-setup` の「既存への追加・再実行」）。

## やってはいけないこと

- **サンプル選択で系列を間引く** — 固定4択に押し込めて **3層リッチクライアント（`WSClient_sample`）や WPF を
  落とさない**（実測で欠落。UI 制限時は番号付きリストで全系列を出す）
- **系列を選んだ後、派生（variant）を勝手に1つに決め打ちする** — 複数あるなら提示して選ばせる
  （実測：バッチで `SimpleBatch_sample` が無選択で選ばれた）。派生が1つのときだけ確認不要
- **固定タグの例示 `03-20` を既定値として勝手に使う** — どのタグかを必ずユーザに確認する
- **ランタイム対象外の組合せを選ぶ** — Web Forms を core で／**CLI を net48 で**（net48 CLI は csproj 無し＝
  net10.0 のみ）／net48 専用サンプルを net10.0 で、は不可
