# minimize — サンプル/テスト画面を除いて最小骨格へ

`opentouryo-project-transform` の subcommand。**セットアップ済みの WebForms サンプルから、動作確認用のテスト/デモ画面を
除いて「業務画面を足していける最小骨格」に落とす。** 出典：トランスフォーム テスト（develop の `WebForms_Sample` を最小化した実測）。

## ゴールの姿（最小骨格に残るもの）

残すのは「枠組み」だけ。実測（develop）で残ったのは次：

- **Framework ダイアログ**：`Aspx\Framework\`＝`DialogFrame.htm` / `DialogLoader.htm` / `myOKMessageDialog.aspx` /
  `myYesNoMessageDialog.aspx` / `Ping.aspx`（画面遷移・ダイアログ機構。`opentouryo-webforms-dialog` / `-screen-transition`）。
- **共通画面**：`Aspx\Common\ErrorScreen.aspx`（エラー画面）。
- **開始画面**：`Aspx\start\`＝`login.aspx` / `logout.aspx` / `menu.aspx`。
- **実シェルのマスタ（＝残す画面の `MasterPageFile` が指すもの）だけ**：`Aspx\Common\Master\` のうち、残す画面が実際に使うマスタ。
  develop では **`testBlankScreen.master` 1枚**。**どれが実シェルかは版で変わる＝名前で決めず `MasterPageFile` を grep して特定する**（下記★トラップ）。
- **認証系**：`Aspx\OAuth2\OAuth2AuthorizationCodeGrantClient.aspx`（**認証方式次第**。ただし `login.aspx` の
  「外部ログイン」ボタンの遷移先でもある＝**使わないなら画面とボタンを対で消す**。`opentouryo-auth` / `-oauth2-client`）。
- **土台**：`App_Start\{BundleConfig,RouteConfig}.cs`、`Global.asax(.cs)`、`Properties\AssemblyInfo.cs`、
  `Content\` / `Scripts\` / `images\`（bootstrap・jQuery・touryo・WebForms スクリプト等）、`Web.config` / `app.config` / `Bundle.config`、`packages.config`。
- **空フォルダ**：`AppCode\`（業務コードを足す場所）、`App_Data\`。

## 削る対象

- **テスト/デモの content 画面**：`testScreen*`、`sampleScreen.aspx` / `sampleScreen_cc.aspx`（＝画面本体）等の動作確認画面、
  Web ユーザ コントロール（`Aspx\Common\Wuc\`）。
  **★ 削除対象が「検証手段」を兼ねていないか先に確認する**（`SCDefinition.xml` 掃除と同じ「静かに腐る」系）。例：`sampleScreen_cc.aspx` は
  **`ws-decouple`（2層化）の実行時確認に使う伝送制御画面**＝消す前に `ws-decouple` の実行時確認を済ませる（順序制約は `opentouryo-project-transform` の「関係」節）。
- **3層（3Tier）画面**：`Aspx\sample\3Tier\` 等。※これは **WS 依存ではない**（`_3TierEngine` 等は基盤側＝`ws-decouple` 参照）。
  「最小化で消す」判断であって「WS 切り離し」とは別。専用周辺（`AppCode\sample\3TierTableAdapter\*`・`AppCode\sample\Business\GetMasterData.cs`）も。
- **無参照になったマスタ**：画面を消した結果、どの残存画面の `MasterPageFile` からも指されなくなったマスタは**削る**（`sample*`/`test*` 名でも）。
  develop では crud 2画面を消すと `sampleScreen.master`（MButton 現存）が無参照になる＝**削除対象**。
- **`menu.aspx` のリンク掃除**：画面を消すと `menu.aspx` に**リンク切れが残る**。**ビルドも `aspnet_compiler` も通り、実行時も 404 とは限らない**
  （Forms 認証／画面遷移チェックが先に効いて **302〔login へ〕になる**＝実測）＝**「404 で気付く」を判定条件にしない**。自動検出できないので**手順として必ずリンクを掃除する**（削った画面へのリンクは menu から消す・業務画面用のプレースホルダ コメントへ置換）。
  **※ 元から実体の無いリンクもある**（例：`~/Aspx/TestPublic/testScreen.aspx` はセットアップ直後から画面が無い＝上流のリンク切れ）＝「最小化で生まれた切れ」と混同しない。
- **★ 消した画面/クラスを指す XML 定義・config の後始末**：画面・B層（`LayerB`）を消すと、それを指す `resource\Xml` の定義が
  **存在しない画面/クラスを指したまま静かに腐る**（呼ぶ画面も消えるので実行時に露見しない＝ビルドでも出ない）。実測（develop）：
  `SCDefinition.xml`（画面遷移）は `~/Aspx/testScreenCtrl/...` 等の削除済み画面を、`TMInProcessDefinition`（＋2層化で作った
  `TMInProcessDefinition_<App>.xml`）は消えた `LayerB` を指したまま残る。→ **`SC`/`TMInProcess`/`SP`/`TC` 定義（`resource\Xml`）と
  `app.config` の該当キーから、消した画面/クラスのエントリを掃除する**（2層化〔`ws-decouple`〕で作ったアプリ専用 TMInProcess 定義は、
  B層ごと消えたら空＋書式テンプレのコメントに戻す）。
  **★ 複数サンプルが単一の `resource\` を共有する repo では、共有ファイルをその場で掃除すると他サンプルを壊す**（例：`TMInProcessDefinition.xml` は WS ホスト2つと MVC core も参照）。→ **掃除の前にその定義ファイルを他サンプルが参照していないか grep する**。参照が他にあるなら、`ws-decouple` と同じ**アプリ専用ファイル方式**（`SCDefinition_<App>.xml`/`TMInProcessDefinition_<App>.xml` を作り `app.config` を向け替え・**共有ファイルは無改変**）に揃える。
- 上記からのみ参照される型・`using`。

## ★トラップ（名前で決めない・結論は版で反転する＝最優先の注意）

**`test*` / `sample*` という名前は判断材料にならない。** 実シェルの特定は**必ず `MasterPageFile` の grep で行う**：

1. 残す画面（`login`/`logout`/`menu`/`ErrorScreen`/`OAuth2` 等）の `MasterPageFile` を集める。
2. そこに出るマスタ＝**実シェル＝残す**。出ないマスタ＝**無参照＝削る**（`sample*`/`test*` 名でも）。

**版で結論が反転する実例（同じ `sampleScreen.master` でも逆になる）：**

| 版 | `menu.aspx` の `MasterPageFile`（実シェル） | `sampleScreen.master` の実態 |
| --- | --- | --- |
| **develop（現行）** | **`testBlankScreen.master`** | crud 2画面（`sampleScreen.aspx`/`_cc`）専用＝**削除対象**。**MButton 現存**（`btnMButton1〜9`/`101`/`102`） |
| 旧 03-20 | `sampleScreen.master` | menu の実シェルだった＝残す |

＝「`sampleScreen.master` は残す/消す」を**名前で固定して書かない**。マスタを**改名**したら、`MasterPageFile` 参照と
ハンドラ命名（`UOC_<マスタ名>_…`）も揃える。

## master 上コントロールのハンドラ（`MyBaseController`・削除は任意）

master 上のコントロール（ボタン等）のイベントハンドラは、命名契約 **`UOC_<マスタ名(拡張子なし)>_<control>_<event>`**
（例 `UOC_sampleScreen_btnMButton101_Click`）で結線される。**実装先は画面コードクラス（コンテンツ側のコードビハインド）でよい**
（名前はマスタ名だが実装はコンテンツ側＝`opentouryo-layer-p-webforms-event` の実装先表）。**サンプルはたまたま `MyBaseController`（親クラス2）に束ねている**が、
**フッタ共通ボタンの実装に親クラス2 のカスタマイズは必須ではない**（画面ごとに画面コードクラスへ書けば、親クラス2 を触らずに済む）。
`MyBaseController` 側に束ねる場合に編集・カスタマイズするなら `opentouryo-base2-customize`。

- **削除は任意（残してよい）。** 最小化で master 上のコントロール（や、その master 自体）を外すと、その**ハンドラは結線されず＝到達不能・
  デッドコードになる**だけで、呼ばれないので大きな問題にはならない。無理に消さなくてよい（実測では `#region マスタ ページ上の…` を
  region 丸ごと削除できた＝`base2-customize` overlay 経由）。
- **消すなら注意**：`MyBaseController` は複数サンプルで共有される。**最小化していない**サンプル側の画面が同名ハンドラを使っていると、
  その **master ページ上のコントロールのハンドラが動作しなくなる**。＝削除は共有の影響を確認してから（WebForms 系が1本だけか等。実測 OK）。

## csproj の剪定（大量エントリ）

**「実在しない `Include` を消す」方式が堅牢**（実測で 151 件を一発処理）。ファイルを先に削除し、csproj の `Content` / `Compile` /
`None` / `EmbeddedResource` のうち **`Include` 先が実在しないエントリ**を XML DOM で剪定する（`PreserveWhitespace=true` ＋直前の
空白ノード除去で差分最小。**ワイルドカードと `Reference` 系は除外**）。名前マッチで消すより安全・高速。
**剪定後、空になった `ItemGroup` も除去する**。剪定後も段階ビルドで確認する。

## 進め方（段階ビルド）

1. **まずビルドして現状把握**（何が何に依存するかはビルドエラーが教える）。
2. テスト/デモ画面を削る → **再ビルド** → `CS0246`（型・名前空間が見つからない）を上から潰す
   （同名クラスが同梱ソースにある→`using` 差し替え／3層専用→削る。`ws-decouple`）。
3. **残す画面の `MasterPageFile` を grep → 無参照マスタを削る**（★トラップ）。
4. **`menu.aspx` のリンク掃除**（削った画面への link を除去。ビルド・`aspnet_compiler` では検出できず実行も 404 とは限らない〔302 になる〕＝**必ず手順として行う**）。
5. **消した画面/クラスを指す XML 定義（`resource\Xml` の `SC`/`TMInProcess`/`SP`/`TC`）と `app.config` の該当キーを掃除**（静かに腐る＝ビルドでも実行でも出ない）。
6. csproj を剪定（空 `ItemGroup` 除去含む）→ 再ビルド → `aspnet_compiler` で静的検証（マークアップの参照切れ検出）。
7. 認証（OAuth2 等）を使わないなら、**画面と `login` 側のボタンを対で**削る。
