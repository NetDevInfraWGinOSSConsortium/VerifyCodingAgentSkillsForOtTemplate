# フレームワーク毎の共通仕様

## データベース
- 接続先の DB は **`Northwind2`**（接続文字列は `Initial Catalog=Northwind2`）。NorthwindDbSampleSpec の DDL・DML（`Northwind/SQLSvr/`）で初期化した、
  楽観排他用の `RowVersion` 列付きのスキーマを使う（`HLD/Common.md` 9 節）。
  - LocalServicesOnDocker が作る `Northwind`（Microsoft 公式の `instnwnd.sql`。`RowVersion` 列・`SalesTargets` 表が無く、FOREIGN KEY・CHECK の制約がある）は使わない。名前を分けて並べて置く。
- 初期化：`01_CreateDatabase.sql` → `02_CreateTables.sql` → `03_InsertData.sql` を、**DB 名を `Northwind2` に置き換えた写し**（一時フォルダ）で、この順に流す。
  - 置き換えるのは `[Northwind]` と `N'Northwind'` だけ（スクリプトは DB 名を決め打ちにしている）。NorthwindDbSampleSpec の原本は直さない。
  - `sqlcmd` で流す（SQL 認証は `-U sa -P <パスワード>`。スクリプトは BOM 付き UTF-8 でコメントに日本語があるので `-f 65001`）。
  - 3 つとも再実行できる（`02` は表を消して作り直し、`03` はデータを消して入れ直す）。流し直すと、テストが入れた行も消える。
- 接続文字列は、アプリ・テスト・ツールの構成ファイル（`Web.config`・`App.config`・`appsettings.json` など）のすべてで `Initial Catalog=Northwind2` にする（サンプルの既定は `Northwind`）。

## 画面共通
- すべての画面のメインボタンはフッタ部に5つ配置し、動的にボタンのキャプションを適切な名称に変更し、不要なボタンはdisableにする。
  - メインボタンとは、機能トランザクションを起動するボタン（検索・登録・更新・削除など）である。画面定義書がこれらのボタンを別の領域に置いていても、フッタ部に配置する。
  - 入力支援のボタン（条件クリアなど）やページングのボタンはメインボタンに含まれず、画面定義書の配置に従う。
  - 遷移だけのボタン（編集・戻る・新規登録など、機能トランザクションを起動せず画面を移るだけのもの）はメインボタンに含めず、画面定義書の配置に従う。
  - ダイアログ（元画面に重ねて表示する画面）も「画面」に含め、メインボタンはダイアログのフッタ部に5つ配置する。閉じるボタン（遷移だけ）はメインボタンに含めず、画面定義書の配置に従う。
  - サーバの機能トランザクションを起動しないボタン（ブラウザの印刷機能を呼ぶだけの印刷など）はメインボタンに含めず、画面定義書の配置に従う。この結果、フッタの5つがすべてdisableになる画面もある。
- また、Web画面については、ヘッダ、左メニュー、コンテンツ構成になっているので、このボタンはコンテンツのフッタ部に出るようにする。
- Web画面の日付の入力項目は `<input type="date">` を使う（WebForms は `TextBox` の `TextMode="Date"`）。
  - 入力途中の値（年だけ入れた等。`validity.badInput`）はブラウザが空として送るので、画面のscriptで送信を止め、形式の違反として項目の直下に出す（未入力として扱わない）。

## WebForms
- フッタのボタン実装は、
  - Master Page（`.master`）にレイアウトを配置する。
  - 画面ごとのボタン制御（表示/非表示やテキスト設定）は、各ページの コードビハインド（基本は初期処理）で動的に行う。

- ダイアログ表示には、基本的にOpen棟梁のフレームワーク機能を使用する。
  - メッセージ・ダイアログ：ShowOKMessageDialog
  - 確認ダイアログ：ShowYesNoMessageDialog
  - 子画面表示：ShowModalScreen

- 共通メッセージ領域のメッセージは、種類を class で区別する：エラーは `text-danger`、情報は `text-info`。
- 一覧表示は `GridView`（`DataSource` にバインド）を使用する。

## MVC
- フッタのボタン実装は、
  - `_Layout.cshtml` に共通レイアウトを配置する。
  - 画面ごとのボタン配置や差し替えは、`@RenderSection` を使用して動的に切替・定義する。
  - ただし `@section` の中身は `@RenderBody()` の外（`<form>` の外）に描画されるため、  
    送信させたい submit ボタンには `form="<フォームID>"` を付けてフォームへ明示的に紐付ける（付けないと押しても無反応）。

- ダイアログ表示には、基本的にJavaScript機能を使用する（OK、Yes/No）。
- 共通メッセージ領域のメッセージは、種類を class で区別する：エラーは `text-danger`、情報は `text-info`。
- 一覧表示は tableタグを自前で生成し、trタグをループで実装する。

## WindowsForms（2CSClientWin_sample / WSClientWin_sample）
- Form画面は OpenTouryo のリッチクライアント基底フォーム `MyBaseControllerWin`（画面コード親クラス２）を継承する。
- フッタのボタン実装は、
  - `MyBaseControllerWin` を継承したBaseFormに共通レイアウトとして実装する。各Form(画面）は、このBaseFormを継承する。
  - 画面ごとのボタン制御（表示/非表示やテキスト設定）は、各ページの コードビハインド（基本は初期処理）で動的に行う。

- ダイアログ表示には、標準機能を使用する。
  -  `MessageBox.Show`（OK は `MessageBoxButtons.OK`、YES/NO は `MessageBoxButtons.YesNo`）
  - 子画面表示は `DialogResult result = dialog.ShowDialog(this);` ココでのdialogはForm `Form2 dialog = new Form2()`
  
- 一覧表示は `DataGridView`（`DataSource` にバインド）を使用する。
- また、初期画面は、Program.csから起動した選択ダイアログの結果で振り分けるようにする。
- なお、WSClientWin_sampleは、画面端に「通信制御機能のサービス論理名」を選択するDDLを配置する。
