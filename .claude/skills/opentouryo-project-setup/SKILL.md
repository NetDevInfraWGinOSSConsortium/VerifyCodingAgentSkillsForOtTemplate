---
name: opentouryo-project-setup
description: "OpenTouryo を使う新規プロジェクトをゼロから立ち上げる（セットアップ）ときの入口＝ファサード。手順を順序で4スキルに分け、全体の流れと呼び出し順だけをここで示す：①②サンプル選択・取得元＝opentouryo-project-setup-selection、③基盤ビルドとベンダ＝opentouryo-project-setup-build、④⑤取り出しと参照張り替え＝opentouryo-project-setup-core、⑥⑦resource 移設・config・検証＝opentouryo-project-setup-config。net48 / net10.0 の両対応。プロジェクト作成 / セットアップ / 新規立ち上げ / サンプルから始める / 参照設定 / DLL 参照 / OpenTouryoAssemblies を伴う作業の入口に使う。既存プロジェクトでコードを書くのは各層スキル、構成キーの詳細は opentouryo-config を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.2.0"
---

# 新規プロジェクトのセットアップ（ファサード）

## このスキルの役割

**ゼロから新規に OpenTouryo アプリを立ち上げる**ときの**入口**。OpenTouryo のサンプルを起点に、
基盤 DLL を参照する標準構成のプロジェクトを作る。**このスキル自体は全体の流れと呼び出し順を示すだけ**で、
各工程の手順は下の順序別サブスキルが担う。

- 既存プロジェクトでコードを書く → 各層スキル（`opentouryo-layer-*` / `opentouryo-p-*` ほか）
- 構成ファイル・設定キーの詳細 → `opentouryo-config`

**両ランタイム対応**（net48 / net10.0）。エージェントが全工程を実行する。

## 全体の流れ（7ステップ ＝ 4スキル）

**上から順に、各サブスキルを呼んで進める。**

```
①② 作りたいサンプルを選ぶ／取得元（固定タグ・develop）を選ぶ  → opentouryo-project-setup-selection
③  基盤 DLL をビルドして OpenTouryoAssemblies\ へベンダ         → opentouryo-project-setup-build
④⑤ サンプルを取り出し、.csproj の OpenTouryo.* HintPath を張替  → opentouryo-project-setup-core
⑥⑦ resource 移設・config パス張替・.gitignore・ビルド／実行検証 → opentouryo-project-setup-config
（選択式）ローカルのデータストア（DB 等）を Docker で用意          → opentouryo-project-setup-db
```

- **①② `opentouryo-project-setup-selection`** — 起点サンプル（全系列を提示）と `<ref>`（固定タグ/develop）を決める。
- **③ `opentouryo-project-setup-build`** — ②の `<ref>` と標的ランタイムで基盤をビルド→ベンダ。1回で再利用可。
- **④⑤ `opentouryo-project-setup-core`** — サンプル（＋開発支援ツール）を取り出し、参照をベンダ先へ張り替える。核心。
- **⑥⑦ `opentouryo-project-setup-config`** — resource を移設し config を環境変数方式へ、`.gitignore`、ビルド／実行で検証。
- **（選択式）`opentouryo-project-setup-db`** — ローカルのデータストア（SQL Server 等）を Docker で用意する。⑦ の接続確認・
  実行検証の DB 依存操作の前提を満たす。**既存 DB があれば不要**。

**基盤（OpenTouryo フレームワーク）はバイナリ提供が前提。** ビルドした DLL を参照する
（`opentouryo-common-parts` / `AGENTS.md` の「クラスの階層と修正可否」）。**親クラス2 をカスタマイズする**なら
`opentouryo-base2-customize`（③のビルドに関わる）。

## 既存プロジェクトへの追加・再実行（冪等性）

このスキルは新規立ち上げが主眼だが、**既に構築済みの repo に別サンプルを追加**する再実行もある
（例：WebForms がある repo に MVC を足す）。その場合：

- **既存成果を上書きしない。** 取り出し済みサンプル・`resource\`・config・`OpenTouryoAssemblies\` を壊さないよう
  追加分だけを対象にする。衝突しうるなら**ユーザに意図を確認**してから進める。
- **同一ランタイムなら ③ 基盤ビルドは流用**（`OpenTouryoAssemblies\Build_net48\` 等を再利用。再ビルド不要）。
  ③ を回すのはタグを変える／別ランタイムを足すときだけ（`opentouryo-project-setup-selection` で判断）。**別ランタイムを
  足すなら、そのランタイムの `Build_netcore100\` 等だけをビルド**（既存 ZIP 展開を再 DL せず流用してよい）。
- **例外：2CS/リッチクライアント系（`2CSClientWin/WPF`・`WSClient_*`）は、同一ランタイム・同一タグでも ③ に追加ビルドが要る。**
  これらは `OpenTouryo.Business.RichClient` を参照するが、③ が回す `2_/3_Build_*` サブセットには含まれない
  （別ビルド。フル一式／`9_CICD.bat` なら出る＝本体の欠陥ではない。**base2 の有無と無関係**）。**netcore は欠落が広く、
  `net10.0-windows7.0\` の `Business`/`Dam*` ごと無い→フォルダ丸ごと再ベンダ**（net48 は `Business.RichClient` のみ）。
  → `opentouryo-project-setup-build` / `opentouryo-project-setup-selection`。
- **フォルダ名は判断させず固定規則にする（実測構成に準拠）：**
  - **net48 は元のサンプル名のまま**（`MVC_Sample` / `WebForms_Sample` / `SimpleBatch_sample` / `2CSClientWin_sample`）。
  - **core（.NET10）は、そのサンプルに net48 版が“存在する”とき（＝両ランタイム対応サンプル）だけ接尾辞 `_Core` を付ける**
    （`MVC_Sample_Core` / `SimpleBatch_sample_Core` / `RerunnableBatch_sample2_Core` / `2CSClientWPF_sample_Core`）。
    **判定は「そのサンプルが net48（`Samples\`）にも在るか」という固定属性**で行う＝**repo にいま net48 を入れたかは無関係**
    （まだ net48 を入れていなくても core は最初から `_Core`。順序に依らず名前を一意に決め、後から改名しない）。
    **★ `_Core` を付けるのはフォルダ名だけ。内側の `.csproj`/`.sln`/`AssemblyName` は原名のまま変えない**
    （実測：`2CSClientWPF_sample_Core\2CSClientWPF_sample.csproj`）。**内側名やアセンブリ名を `_Core` にリネームしない**——
    `SqlTextFilePath` が `<アセンブリ名>.Dao` 形式（埋め込みリソースの名前空間。例 `GenDaoAndBatUpd_sample.Dao`）のサンプルは、
    アセンブリ名が変わると SQL 定義解決が**実行時に壊れる**。sln の参照パスは新フォルダ位置に合わせるが、プロジェクト名は変えない。
  - **net48 のみ（`WebForms_Sample`）・.NET10 のみ（`Simple_CLI`＝net48 版が存在しない）は無印**（接尾辞を付けない）。
  - **WS 系は `WS_sample\` に集約**（`WSClient_sample\` / `WSIFType_sample` / `WSServer_sample` ＋ WS ホスト
    `ServiceInterface\`＝源は `Frameworks\Infrastructure\ServiceInterface`）。内部階層は保つ（フラット化しない。
    `opentouryo-project-setup-core` の `samples/webservices.md`）。**`WSClientWin2_sample` が WS 非依存でも配置は
    `WSClient_sample\` 配下のまま＝例外を作らない**（WS 非依存は参照の話で、置き場所は WSClient 派生と一律）。
  - **開発支援ツールは `OT_Tools\` 配下にまとめる**（`OT_Tools\DaoGen_Tool\` / `OT_Tools\DPQuery_Tool\`。リポ直下に
    散らさない。HintPath は2階層＝`..\..\`。`samples/daogentool.md` / `dpquerytool.md`）。
- ⑥ resource・⑦ `.gitignore` は既に整っていれば再張替不要（追加サンプル固有のキーだけ足す）。

## 完了後（任意）：構成変更へ進むか選ぶ

セットアップ（①〜⑦）が済んだら、**続けて構成変更（`opentouryo-project-transform`）を行うかをユーザに選ばせる**。
早くフィードバックを得たいなら、セットアップ直後にその場で実行してよい（**任意**）。

- 進む → `opentouryo-project-transform`（例：WS 依存の切り離し・サンプル固有コードの整理・`CS0246` 解消）
- 後回し → 何もしない。利用者がソリューションを俯瞰してから別途依頼する

**セットアップの途中に構成変更の判断を割り込ませない**（選ばせるのは「開ける状態」の後）。
**セットアップ成果はコミットを促す**（未コミットのままだと作業ツリーから失われうる。ビルド確認まで済んだ
節目でユーザに提案する。git 操作はしない方針は保つ）。

## やってはいけないこと（全工程共通の原則）

- **`OpenTouryo.*` を `ProjectReference` にする** — 基盤はバイナリ提供が前提。DLL 参照にする
- **基盤（`Frameworks/Infrastructure/*`）を導入リポジトリに取り込んで改造する** — 纏め者の領分
  （`opentouryo-project-policy` / `opentouryo-base2-customize`）。導入プロジェクトはビルド済み DLL を参照するだけ
  （**例外：3層CS の WS ホスト（源 `Frameworks\Infrastructure\ServiceInterface`→`WS_sample\ServiceInterface\` に集約。
  ASPNETWebService/WCFService）は実動に必須なので引き込む＝改造ではなくホストとして配置・起動する。`samples/webservices.md`**）
- **作業ツリー `Temp/`（基盤ソース＝親クラス2 を含む）をコミットする** — `.gitignore` で除外する（⑦）
- **Download→Build→ベンダをアドホックなコマンド羅列で済ませる** — スクリプト化して残す（③）
- **net48 サンプルを net10.0 で、または Web Forms を core で使おうとする** — ランタイム対象外

各工程固有の禁止事項は、それぞれのサブスキルに置く。
