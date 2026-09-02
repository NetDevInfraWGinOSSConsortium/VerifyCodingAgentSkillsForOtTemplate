<!-- opentouryo-agent-assets:generated -->
<!--
  このファイルは OpenTouryo を利用するアプリ開発リポジトリへ配布される
  「概要」インストラクションの原本（Single Source of Truth）です。

  ■ 位置づけ
    - 概要・規約・地図 → このファイル（常時コンテキストに載る）
    - 具体的なコードの書き方 → src/skills/ 配下のスキル（必要時のみロードされる）
    手順や特定領域だけの話はスキルへ。ここには毎回必要な事実だけを書く。

  ■ 制約
    - 目安 200 行以内。長いほど追従率が下がる。
    - このような HTML コメントは Claude Code では読み込み時に除去される。
      執筆者向けメモの置き場として使える（他プロダクトでは除去されない点に注意）。

  ■ TODO の埋め方
    「TODO:」を検索して各節を埋めてください。空欄のまま配布しないこと。
-->

# プロジェクト ポリシー

このリポジトリは

- [OpenTouryo](https://github.com/OpenTouryoProject/OpenTouryo/)（.NET 用アプリケーションフレームワーク）
- [OpenTouryoCodingAgentAssets](https://github.com/OpenTouryoProject/OpenTouryoCodingAgentAssets/)（Open棟梁を使用するエージェント・スキル）

を利用している。

コーディング・エージェントは、以下の規約に従って実装すること。

<!--
  導入プロジェクト固有の運用ルールを記述する欄。
  「どう実装するか」ではなく「どう振る舞うか」を書く。技術的な規約は各スキルへ。

  Git 操作の1件は、どのプロジェクトでも共通の前提として既定で入れてある。
  方針が異なる場合は、このプロジェクトの実態に合わせて書き換えること。
-->

### Git 操作は行わない（状態を変える操作をしない）

**成果物の検収は人が行う。** エージェントは作業結果をワーキング ツリーに残すところまでを担当し、
Git 操作は人が手動で行う。

したがって、指示がない限り次を実行してはならない。

- `git add` / `commit` / `push`（検収前・未レビューの変更を確定・送信しない）
- `git checkout` / `switch` / `branch` / `reset` / `restore` / `stash`（人の作業状態や未保存の作業を壊す）

**参照系は制限しない。** 何を変更したかを正確に報告するために必要なため、次は自由に実行してよい。

- `git status` / `diff`（`--cached` 含む）/ `log` / `show` / `ls-files` / `check-ignore` / `blame`

作業が完了したら**何を変更したかを報告するに留める**。コミットの要否とタイミングは人が判断する。

<!--
  補足（執筆者向け）:
  インストラクションは「文脈」であって強制力を持たない。上記は遵守されやすい書き方に
  しているが、確実に阻止したい場合は仕組み側で塞ぐ必要がある。
    - Claude Code : PreToolUse フックで Bash(git commit:*) 等を deny する
    - 各プロダクト: 同等の機構があればそれを使う
  必要になったら install.ps1 に設定の配布を追加することを検討する。
-->

### マシン/ユーザ全体に残る変更は `SETUP-CHANGES.md` に記録する

セットアップ等で**リポジトリの外＝マシン/ユーザ全体に残る変更**を行ったら、対象リポジトリ直下の
**`SETUP-CHANGES.md`** に追記する（`種別 ／ 対象 ／ 値 ／ 実施日 ／ 巻き戻し方法`）。監査と巻き戻しのため。
`SETUP-CHANGES.md` はコミットする（`.gitignore` で除外しない）。**AGENTS.md 自体には書かない**
（インストーラが再生成で上書きするため）。対象となる変更の例：

- **環境変数**（例：`OT_RESOURCE_ROOT` を User に設定 → 削除で戻す）
- **Windows サービスの起動**（例：ASP.NET State Service → `aspnet_state-stop.bat` で停止）
- **リポジトリ外のファイル/ディレクトリ**（例：短い作業ルート `C:\otr\` の作成 → 削除可）
- **PATH / レジストリ / ソフトウェア導入**（例：long path 有効化 `LongPathsEnabled=1` → `0`、VS Build Tools 導入）

これらを伴うスキル：`opentouryo-project-setup-build`（③）／`opentouryo-project-setup-config`（⑥⑦）／`opentouryo-base2-customize`。

### その他のポリシー

<!-- TODO: レビュー体制、ブランチ運用、成果物の扱いなど、プロジェクト固有のルールを追記する。 -->

- **選択肢は間引かない。** スキルが挙げる候補をユーザに選ばせるとき、**固定 N 択の chooser に畳んで一部を落とさない・
  無関係な項目を勝手に併合しない**。選択 UI が選択肢数を制限するなら、**全候補を番号付きリストで提示**して番号で選ばせる。
  実測で欠落した例：①サンプル系列（`opentouryo-project-setup-selection`。3層CS/WPF が脱落）／親クラス2 の差し込み点
  （`opentouryo-base2-customize`。`%1/%2` 置換・Web API 認証・引数戻り値・非同期・サブシステム/属性が脱落）。

## 対象バージョン

<!-- TODO: OpenTouryo 本体のバージョンと IDE を埋める。ランタイムは確定済み。 -->

- OpenTouryo: TODO
- ランタイム: net48 / net10.0
- IDE: TODO

### DBMS による差異（スキルの SQL 例は特記なければ SQL Server）

対象 DBMS はプロジェクト依存（SQL Server / Oracle / MySQL / PostgreSQL 等）。
**SQL 定義ファイル（`.sql` / `.xml`）は DBMS 別**で、パラメタの接頭辞（SQL Server `@P1` /
Oracle `:P1`）・`CAST`・関数の構文が違う。**型情報も DBMS 依存**
（`SqlDbType.Int` / `OracleDbType.Int32`）。一方、**コードの `SetParameter("P1", ...)` は
接頭辞なしで DBMS 中立**（接頭辞はフレームワークが付ける）。既存の SQL ファイルに合わせる。
詳細は `opentouryo-query-definition` / `opentouryo-dao-custom`。

## アーキテクチャ

OpenTouryo は **P層 / B層 / D層** の3層構造をとる。各層の責務は厳格に分離されており、
層をまたぐ呼び出しは規定の経路以外を通してはならない。

| 層 | 責務 | 基底クラス（親クラス1 / 2） | スキル |
| --- | --- | --- | --- |
| P層（画面 / API） | 画面の入出力とイベント処理。**業務ロジックを書かない** | 処理方式による（下表） | `opentouryo-layer-p-*` |
| B層（業務ロジック） | 業務処理。**トランザクション境界**でもある | `BaseLogic` / `MyFcBaseLogic` | `opentouryo-layer-b` |
| D層（データアクセス） | SQL の実行。**業務判断をしない** | `BaseDao` / `MyBaseDao` | `opentouryo-layer-d` |

**P層は処理方式ごとに実装モデルが違う。** 使っている方式のスキルを読むこと。

| 処理方式 | 画面コード親クラス1 / 2 | 実装モデル | スキル |
| --- | --- | --- | --- |
| ASP.NET MVC / ASP.NET Core MVC | `BaseMVController` / `MyBaseMVController`<br>`BaseMVControllerCore` / `MyBaseMVControllerCore` | アクションメソッド（**UOC メソッドは無い**） | `opentouryo-layer-p-mvc` |
| ASP.NET Web Forms | `BaseController` / `MyBaseController` | UOC メソッド | `opentouryo-layer-p-webforms-screen`（作成）<br>`opentouryo-layer-p-webforms-event`（イベント） |
| Windows Forms | `BaseControllerWin` / `MyBaseControllerWin` | UOC メソッド | `opentouryo-layer-p-winforms-screen`（作成）<br>`opentouryo-layer-p-winforms-event`（イベント） |

P層から B層を呼ぶ共通手順（引数クラス・`DoBusinessLogic`・`ErrorFlag`・2CS の手動トランザクション）は
`opentouryo-p-call-business`。

**WPF は P層フレームワークを持たない。** 画面は素の WPF（`Window` 継承）とし、B層・D層のみ利用する
（`MyBaseControllerWin` は `Form` 継承で使えない。P層以外のスキルを使う）。

### 層間の呼び出し規約

```
P層  --B層呼び出し（処理方式で既定が違う。下記）-->  B層
B層  --new LayerD(this.GetDam()) / new CmnDao(this.GetDam())-->  D層
```

- **P層 → B層の呼び出しは処理方式で既定が違う**（`opentouryo-p-call-business`「呼び出し経路の選択」）。
  - **Web（WebForms・MVC）＝`new LayerB().DoBusinessLogic(pv, iso)` 直呼び**（インプロセス・per-call で分離レベル指定可）。
  - **3層C/S（リッチクライアント・WS）＝`CallController.Invoke(サービス論理名, pv)`**（URL やクラス名でなく**論理名**。
    定義ファイルが実体解決し、インプロセス⇄Web サービスをコード無変更で切替。**分離レベルはサーバ側で決める**＝`iso` を渡せない）。
  - **リモート（Web サービス）は net48 専用**、`net10.0` はインプロセスのみ（`BinarySerialize` が core に無い）。
- **B層 → D層は `this.GetDam()` を渡して Dao を生成する。** 接続・トランザクションは B層が持つ
  （D層は自前で接続を開かない）
- **P層から D層を直接呼ばない**（トランザクション境界は B層）。層をまたぐ引数・戻り値は
  **`BaseParameterValue` / `BaseReturnValue` の派生型**で受け渡す

### クラスの階層と修正可否

各層は「親クラス1 → 親クラス2 → 業務コード（画面コード）クラス」の3階層で構成される。

| 階層 | 例 | 名前空間（アセンブリ） | 提供 | 修正 |
| --- | --- | --- | --- |
| 親クラス1 | `BaseLogic` / `BaseDao` / `BaseController` | `Touryo.Infrastructure.Framework.*` | バイナリ提供 | 修正不可 |
| 親クラス2 | `MyFcBaseLogic` / `MyBaseDao` / `MyBaseController` | `Touryo.Infrastructure.Business.*` | 纏め者が開発・改修 | **このプロジェクトでは修正不可** |
| 業務コードクラス | 各画面 / B層 / D層 クラス | プロジェクトの名前空間 | ここに実装する。 | **可** |

汎用の基盤部品は `Touryo.Infrastructure.Public.*`（`Db` / `Log` / `Util` 等。バイナリ提供・修正不可）。

**依存は一方向：ユーザプログラム → `Business` → `Framework` → `Public`。** 間飛ばし
（`Business` → `Public`）はよいが、逆向き（`Framework` → `Business` 等）は循環参照になり禁止。

**親クラス1・2 はビルド後のバイナリで提供され、このプロジェクトでは修正しない**（ソースが
読める形のこともあるが、読むためであって修正してよい意味ではない）。カスタマイズするのは
纏め者であってこのプロジェクトではない。スキルに親クラス2 の実装（`UOC_ABEND` の例外振替など）が
出てくるのは**挙動を理解するため**。変えたくなったら業務コードクラス側で対処できないか先に検討し、
それでも必要なら人に相談する。

### 親クラス2 の挙動はプロジェクトごとに違う

**フレームワークが決めず、親クラス2 の実装が決める仕様がある**（メッセージの `%1`/`%2` 置換、
`MyUserInfo` が持つ項目、`User` 分離レベルの振替先など）。既定のテンプレートは付いてくるが、
**纏め者が書き換える前提**なので、テンプレートの値をこのプロジェクトの仕様と決めつけない。

**推測で書かない。** 確認方法（ソースを探して読む／読めなければ纏め者への質問にする）は
**`opentouryo-project-policy`** を参照。

## ディレクトリ構成

<!-- TODO: このリポジトリでの実際の配置。エージェントが「どこに何を書くか」を即断できる粒度で。 -->

```
TODO
```

## 命名規約

<!-- TODO: 検証可能な形で書く。「適切に命名する」ではなく「Dao クラスは <テーブル名>Dao とする」。 -->

- TODO

## 実装時の必須ルール

<!--
  TODO: 毎回守らせたい「常にXXする / 絶対にXXしない」だけをここに。手順はスキルへ。
  以下1件は検証済み。.NET の一般的な作法と逆で、知らないと必ず間違えるためここに置く。
-->

- **親クラス1・2 を修正しない**（実装するのは業務コードクラスだけ。「クラスの階層と修正可否」参照）。
- **業務例外（`BusinessApplicationException`）はリスローされない。** B層でスローすると
  フレームワークが捕捉し、正常系の戻り値（`ErrorFlag = true`）に変換する。呼び出し側で
  `catch` してはならない（飛んでこない）。詳細は `opentouryo-exception` を参照。
- **新規 `.cs`/`.vb` にはファイルヘッダ**（所属機能名バナー＋クラス情報＋更新履歴表を言語コメントで）。クラス・メソッドは XML doc（`/// <summary>`）。詳細＝`opentouryo-comment-convention`。
- TODO

## MS 系開発ツールの落とし穴（横断）

MS ツールチェーン起因で**「ビルドは通るのに壊れる／静かに失敗する」**罠。**authoring 時に複数スキルへ横断で効くものだけここに集約**する
（詳細はリンク先スキル。setup/build 時の罠〔`.bat`＝ASCII 限定／`.ps1`＝PS5.1 のエンコード／exit-code 不信＝生成物で判定／MAX_PATH／
`Select-Object -First` でスクリプト停止／sln の CRLF・LF 依存〕は `opentouryo-project-setup-build` に集約している）。

- **新規に作った／書き直したソースとビューは UTF-8 BOM を付ける。** BOM 無し UTF-8 を MS ツールが既定コードページ
  （日本語＝Shift-JIS）で誤読し日本語が化ける。**対象は `.cs`/`.vb` だけでなく、実行時コンパイルされるビュー `.cshtml`/`.aspx`/`.master`**。
  実害が確認済みなのは **net48 MVC のビュー**（`Web.config` に `<globalization fileEncoding>` が無い）＝CP932 の2バイト目が直後の ASCII
  （`</button>` の `<` 等）を食ってタグも壊す＝**文字化け＝ボタンも動かない**。ビルドも `aspnet_compiler` も素通り。**書き直すたびに BOM を確認**
  （エディタが剥がす）。詳細＝`opentouryo-comment-convention`。
- **ビューはビルドで検証されない → `aspnet_compiler` で事前検証する。** `.aspx`/`.master`、および **net48 の `.cshtml`** は構文エラーでも
  `msbuild` は通り、実行しても 500 にならず白画面になることがある（発見が遅れる）。**Core の `.cshtml` は `dotnet build` 時にコンパイルされ非対称**。
  詳細＝`opentouryo-layer-p-mvc`（net48 MVC）／`opentouryo-layer-p-webforms-screen`（`.aspx`/`.master`）。

## 非推奨クラス・メソッド

以下は `[Obsolete]` が付いている。**新規に書くコードで使ってはならない。**
`[Obsolete]` はビルド警告にしかならず、そのままビルドが通ってしまうため、ここで明示する。

<!--
  更新方法（Infrastructure 配下を対象に採取する）:
    grep -rn -A2 "\[Obsolete" --include=*.cs root/programs/CS/Frameworks/Infrastructure
  private メンバは呼び出せないため一覧から除外している
  （例: EmbeddedResourceLoader.GetEntryAssembly()）。

  網羅範囲の調査結果（2026-07-16）:
  - この一覧は CS / VB のどちらでも通用する（言語非依存）。VB を採取し直す必要はない。
    - root/programs/VB には Framework（親クラス1）が無い。CS のアセンブリを流用する
      （VB/1_GetLibrariesFromCS.bat）。よって親クラス1 の非推奨は CS の調査で網羅済み。
    - VB の Business（親クラス2）は CS のミラー。MyBaseLogic / MyBaseLogic2CS に
      同じく <Obsolete("... please use MyFcBaseLogic ...")> が付いている（実物で確認）。
    - VB での属性構文は <Obsolete(...)>。ビルド警告止まりなのは C# と同じ。
  - root/programs/CS/Frameworks/Tools 配下に [Obsolete] は無い。
-->

### クラス

| 非推奨 | 代替 | 用途 |
| --- | --- | --- |
| `MyBaseLogic` | `MyFcBaseLogic` | B層 業務コード親クラス2 |
| `MyBaseLogic2CS` | `MyFcBaseLogic2CS` | 同上（リッチクライアント用） |
| `DamOraClient` | `DamManagedOdp` | Oracle 用 Dam |
| `GetPasswordHashV1` | `GetPasswordHashV2` | パスワード ハッシュ |

### メソッド

`PubCmnFunction` のユーティリティ系メソッドは別クラスへ移動している。
**メソッド名は同じ**なので、クラス名だけ差し替える。

| 非推奨 | 代替 |
| --- | --- |
| `PubCmnFunction.GetPropsFromPropString()`<br>`PubCmnFunction.GetCommandArgs()`<br>`PubCmnFunction.BuiltStringIntoEnvironmentVariable()` | `StringVariableOperator` の同名メソッド |
| `PubCmnFunction.GetCurrentMethodName()`<br>`PubCmnFunction.GetCurrentPropertyName()`<br>`PubCmnFunction.GetCurrentCodeInfo()` | `StackFrameOperator` の同名メソッド |
| `PubCmnFunction.CopyArray()`<br>`PubCmnFunction.CombineArray()`<br>`PubCmnFunction.ShortenByteArray()`<br>`PubCmnFunction.GetLongFromByte()` | `ArrayOperator` の同名メソッド |
| `BaseController.CMN_Event_Handler(FxEventArgs)`<br>`BaseController.CMN_Event_Handler(FxEventArgs, EventArgs)` | 他のオーバーロード |

## ビルドと実行

<!-- TODO: このプロジェクト固有の具体的なコマンドを埋める。ランタイム別の一般則は下記。 -->

- ビルド: net48 は msbuild（非 SDK csproj・VS Build Tools 前提）、net10.0 は `dotnet build`
- テスト: TODO
- 実行: TODO

**新規プロジェクトの立ち上げ**（OpenTouryo を取得・ビルドし、サンプルを起点に構成する）は
`opentouryo-project-setup` を参照。基盤はビルド済み DLL を参照する（ソースを取り込まない）。

## 開発の進め方（spec → plan → 実装：推奨）

規模のある変更は、いきなり実装せず次の順で進めるのを既定とする（小さな修正は省略してよい）。

1. **仕様**：何を作るかを `docs/spec/<名前>.md` に書く（要件・受入条件）。
2. **計画**：どう作るかを `docs/plan/<名前>.md` に書く（対象ファイル・使用スキル・手順。**設計事項の漏れ防止は `opentouryo-app-design`**）。
3. **実装**：計画に沿って実装する。着手前に該当スキルを読む。

`docs/tutorial/` に、スキル群を通しで試す実例がある（`docs/spec` / `docs/plan` の書き方の見本）。
インストーラの `-IncludeTutorial` で配置される。

## スキル

具体的な実装手順は各スキル（`SKILL.md`）に記述されている。該当する作業に着手する前に、該当スキルを読むこと。

**利用可能なスキルは各 `SKILL.md` の `description` から自動的に認識される**ので、この文書に一覧は持たない
（配置先：`.claude/skills/`〔Claude Code〕/ `.github/skills/`〔Copilot〕/ `.agents/skills/`〔agents〕）。
**全スキルの一覧と「使いどころ」**（用途別に分類）は README を参照：
<https://github.com/OpenTouryoProject/OpenTouryoCodingAgentAssets/blob/main/README.md>（「スキル一覧」節）。

## 参考資料

- OpenTouryo 本体: https://github.com/OpenTouryoProject/OpenTouryo
- ドキュメント: https://github.com/OpenTouryoProject/OpenTouryoDocuments
- Wiki: https://opentouryo.osscons.jp/
