# フレームワーク毎の共通仕様

## 画面共通
- すべての画面のメインボタンはフッタ部に5つ配置し、動的にボタンのキャプションを適切な名称に変更し、不要なボタンはdisableにする。
- また、Web画面については、ヘッダ、左メニュー、コンテンツ構成になっているので、このボタンはコンテンツのフッタ部に出るようにする。

## WebForms
- フッタのボタン実装は、
  - Master Page（`.master`）にレイアウトを配置する。
  - 画面ごとのボタン制御（表示/非表示やテキスト設定）は、各ページの コードビハインド（基本は初期処理）で動的に行う。

- ダイアログ表示には、基本的にOpen棟梁のフレームワーク機能を使用する。
  - メッセージ・ダイアログ：ShowOKMessageDialog
  - 確認ダイアログ：ShowYesNoMessageDialog
  - 子画面表示：ShowModalScreen

- 一覧表示は `GridView`（`DataSource` にバインド）を使用する。

## MVC
- フッタのボタン実装は、
  - `_Layout.cshtml` に共通レイアウトを配置する。
  - 画面ごとのボタン配置や差し替えは、`@RenderSection` を使用して動的に切替・定義する。
  - ただし `@section` の中身は `@RenderBody()` の外（`<form>` の外）に描画されるため、  
    送信させたい submit ボタンには `form="<フォームID>"` を付けてフォームへ明示的に紐付ける（付けないと押しても無反応）。

- ダイアログ表示には、基本的にJavaScript機能を使用する（OK、Yes/No）。
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
