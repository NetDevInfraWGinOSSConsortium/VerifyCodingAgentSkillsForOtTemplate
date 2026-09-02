# 親クラス2 のテーブル駆動制御（多言語化・UI 制御・閉塞）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。**親クラス2（纏め者）で実装するパターン**。
出典：OpenTouryo「国際化（多言語化）辞書テーブル」「UI コントロールの制御方式」「閉塞・閉塞チェック方式」＋実ソース（`UOC_CMNFormInit`・各親クラス2 の `// 閉塞チェック` stub）。

## 共通の仕組み（親クラス2 で全画面一括）

**全画面共通の初期化フック `UOC_CMNFormInit`（親クラス2）で、画面上の Control を再帰走査し、「画面名＋コントロール名」をキーにテーブルから設定を引いて一括適用する。**

- 実装するのは**纏め者（親クラス2）**（`opentouryo-base2-customize`）。`UOC_CMNFormInit` は WebForms=`BaseController`／WinForms=`BaseControllerWin` の **abstract フック**で、**全画面で自動的に走る**（`UOC_FormInit` の共通版）。
- 再帰走査：`if (ctrl.HasControls()/HasChildren) { foreach (child in ctrl.Controls) 再帰 }`。各 Control の `ID`/`Name` でテーブルを引き、`Text`／`Enabled`／`Visible`／`ReadOnly` 等を設定する。
- **★ WebForms/WinForms のみ**（Control ツリーがあるから再帰できる）。**MVC は Control ツリーが無く不可**＝別戦略（Razor のローカライズ／タグヘルパー等。`opentouryo-layer-p-mvc`）。カスタムコントロールは `Render` 系のカスタマイズで対応。
- **同じ Control 再帰走査の手法は「単項目の入力値チェック」でも使う**（カスタムコントロールの `CheckType` 宣言でも、**単項目チェックテーブルを作ればテーブル駆動でも**実装できる＝`references/input-validation.md`）。**ただし場所が違う**：本節は**親クラス2（纏め者・全画面自動）**、単項目チェックは**画面コードクラスのイベントハンドラ（開発者・サブミット時）**。

## 応用①：多言語化（辞書テーブル）＝`.resx` の代替

- **辞書テーブル**：`ID／画面名／コントロール名／日本語／英語／中国語／…`。**画面名＋コントロール名**で多言語文言を一元管理。
- 表示時に画面名で結果セットを取り、再帰走査で各 Control の `Text` を差し替える。
- 格納：**SQL Server／XML（`DataTable.WriteXml()`/`ReadXml()`）／DataTable（`DataTable.Select()` で DB レス）**。
- **★ 既定は `.resx` だが、辞書テーブルは定義の可視性が良い**（DB／表で一覧でき、運用で変更しやすい）。resx 方式・カルチャは `references/internationalization.md`。

## 応用②：権限・状態制御

- **権限・状態テーブル**：`画面名／コントロール名／ロール／状態／表示・活性`。ロール・状態に応じて各 Control の `Visible`／`Enabled` 等を一括設定。
- 認可（ロール）は `opentouryo-auth`。詳細は公式「権限制御方式」「状態制御方式」。

## 応用③：閉塞・閉塞チェック

- **閉塞テーブル**：`機能／画面／イベント` 単位 × 閉塞状態。**種類**＝**障害閉塞**（エラーをトリガに自動閉塞）／**運用閉塞**（メンテナンス・バッチのための計画停止）。
- **実装＝親クラス2 の共通処理の「閉塞チェック」stub。全 P層方式の親クラス2 に `// 権限チェック`・`// 閉塞チェック` の空 stub が実在**（`MyBaseController`〔WebForms〕・`MyBaseMVController(Core)`〔MVC〕・`MyBaseAsyncApiController(Core)`〔Web API〕・`MyBaseControllerWin`〔WinForms〕）。纏め者がここに閉塞テーブル参照を実装する（`opentouryo-base2-customize`）。
- 閉塞なら**業務例外 or システム例外に「閉塞用 messageID」をセットしてスロー** → `UOC_ABEND` の振替に乗る（続行可否＝業務/システムで決まる。`opentouryo-exception`）。オンラインバッチ排他（更新系のみ閉塞）は業務例外、システム全停止はシステム例外。
- **★ 閉塞は Control 再帰でなく「テーブル引き＋例外スロー」**なので、①②（Control 再帰＝WebForms/WinForms のみ）と違い、**MVC/Web API でも stub 経由で実装できる**。

## 設計時に決めること（チェック）

- 多言語化を **`.resx`（既定）か辞書テーブル（可視性が良い）**か。辞書テーブルなら格納（SQL／XML／DataTable）を決める。
- 権限・状態・**閉塞**を**テーブル駆動で制御**するか（親クラス2 に実装）。閉塞の種類（障害/運用）と単位（機能/画面/イベント）を決める。
- **①②（Control 再帰）は MVC 不可**＝別戦略。**③閉塞は全 P層方式で可**（テーブル引き＋例外）。
- 実装は**纏め者（親クラス2 の `UOC_CMNFormInit`）**＝`opentouryo-base2-customize`。
