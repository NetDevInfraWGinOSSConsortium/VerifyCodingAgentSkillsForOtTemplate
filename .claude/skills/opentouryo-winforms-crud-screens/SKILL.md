---
name: opentouryo-winforms-crud-screens
description: "OpenTouryo の Windows Forms（リッチクライアント・2層C/S／3層WSクライアント）でテーブル保守（マスタメンテ）の CRUD 画面を実装する。2方式＝(1) 一覧→詳細（一覧の DataGridView で行選択→詳細を子フォーム ShowDialog(this) で開き単一レコードの追加・更新・削除）、(2) 一覧＆更新（DataGridView に DataTable を BindingSource でバインドし、その場で複数行を追加・編集・削除＝RowState バッチ、フッタの [更新] でまとめて反映）。WinForms 固有＝MyBaseControllerWin 派生の画面コードクラス・共通フッタは中間 BaseForm、DataGridView はセル編集が自動で DataTable に反映＝Web のような読み戻し不要＝行内 [更新] ボタンは不要・行削除は Delete キーで可（[削除] ボタンも原則不要・発見可能性/アクセシビリティで足すことはある）・[追加] はグリッド外ボタン、保留中の編集は CommitGridEdits（EndEdit＋CurrencyManager.EndCurrentEdit）で操作・確認ダイアログの前に確定、編集中 DataTable はフォームのフィールドに保持（Session 不要・RowState は自然に保たれる）、ダイアログは MessageBox.Show／子画面 ShowDialog、2CS は手動トランザクション（CommitAndClose/RollbackAndClose・業務例外で自動ロールバックしない）・3層は CallController.Invoke でサーバ側コミット。WinForms の CRUD 画面 / マスタメンテ / DataGridView で一覧更新 / 明細グリッド編集 を伴うときに使う。バッチ更新の中核は opentouryo-batch-update、画面作成は opentouryo-layer-p-winforms-screen、イベントは opentouryo-layer-p-winforms-event、B層呼び出しと手動トランザクションは opentouryo-p-call-business。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# テーブル・メンテナンス画面（一覧・詳細・更新）の P層パターン（Windows Forms）

**Windows Forms のテーブル保守 CRUD 画面**の型。**リッチクライアント（2層C/S＝2CS）と 3層WSクライアントが対象。**
画面コードクラス・クラス階層・共通フッタは `opentouryo-layer-p-winforms-screen`、コントロール／グリッドのイベントは `opentouryo-layer-p-winforms-event`、
RowState バッチの中核は `opentouryo-batch-update`、B層呼び出しと**2CS の手動トランザクション**は `opentouryo-p-call-business`。

> 📋 **コピー元スニペット（Form 骨格・DataGridView バインド・CommitGridEdits・RowState バッチ）は `references/snippets.md`。**

> **★ Web 系（`opentouryo-webforms-crud-screens`／`opentouryo-mvc-crud-screens`）の記述をそのまま持ち込まない。** WinForms は
> **ポストバック・Session・読み戻しが無い**（`DataGridView` の編集は `DataTable` へ自動反映）。Web 仕様（行内 [更新] ボタン等）を字句どおり適用しない。

## 2方式（どちらで作るか）

| 方式 | 画面構成 | 追加/更新/削除 | 使いどころ |
| --- | --- | --- | --- |
| **(1) 一覧→詳細** | 一覧（`DataGridView`）→ 詳細（**子フォーム** `ShowDialog(this)`） | すべて詳細で（単一レコード CRUD） | **オーソドックス。基本はこちら** |
| **(2) 一覧＆更新** | 一覧でその場に複数行を編集 | UPDATE/DELETE は一覧で（複数行＝RowState バッチ）・追加は空行 | 一覧で直接編集したいとき |

## WinForms 固有の要点（Web との違い）

- **画面は `MyBaseControllerWin` を継承した `Form`。** 共通フッタ（メイン5ボタン等）を複数画面で共有するなら**中間 BaseForm**に置く（`opentouryo-layer-p-winforms-screen`）。
  フッタ ボタンのハンドラ `UOC_btnMainN_Click(RcFxEventArgs)` は派生末端の画面に書く（接頭辞 `btn` で自動結線＝`opentouryo-layer-p-winforms-event`）。
- **一覧は `DataGridView` に `DataTable` を `BindingSource` 経由でバインド**（`DataSource = bs`）。**セル編集は自動でバインド先 `DataTable` に反映される**＝
  **Web のような「セルから DataRow への読み戻し」は不要**。`RowState`（Added/Modified/Deleted）はバインド操作で自然に立つ。
- **★ 行内 [更新] ボタンは不要**（編集が即 `DataTable` に入るため）。**行削除も標準の Delete キーで可**（バインド経由＝`DataRowView.Delete()`＝`Deleted`。`Rows.Remove` ではない）＝
  **[削除] ボタンも原則不要**。**発見可能性・アクセシビリティのために [削除] ボタンを足すことはある**（その場合、下記のとおり `DataGridViewButtonColumn` は自動結線外＝素の `CellContentClick` で拾う）。
- **[追加] はグリッド外の通常ボタン**（`UOC_btnAdd_Click`）＝空行 `dt.NewRow()`＋`dt.Rows.Add()`＝**Added**。
- **★ `DataGridViewButtonColumn`（グリッド内ボタン列）はフレームワークの自動結線対象外**（`btn` 接頭辞の `UOC_btn…_Click` にならない）。付けるなら `DataGridView.CellContentClick` で `e.ColumnIndex`/`e.RowIndex` を見て自前で分岐する（`opentouryo-layer-p-winforms-event`）。**そもそも行内ボタンは原則不要**（上記）なので、まず不要と判断する。
- **★ FK 列を `DataGridViewComboBoxColumn`（DDL 列）にするなら `DataError` を握りつぶす**——セル値が `NULL` やマスタ（データソース）に無い値の行で **`DataError` が起き画面に例外ダイアログが出る**。`dgv.DataError += (s, e) => e.ThrowException = false;` で抑止する（マスタ関連項目を DDL 化する仕様だと必ず踏む）。
- **★ 保留中の編集は `CommitGridEdits()` で確定してから**［追加］/［削除］/バッチ更新・**確認ダイアログの前**に進む。`DataGridView.EndEdit()` は**セルの編集しか確定せず**、
  行（`DataRowView`）の保留編集は `CurrencyManager.EndCurrentEdit()`（`BindingSource.CurrencyManager`）まで確定しない＝呼ばずに進むと入力が失われる（実測）。実装は `references/snippets.md`。
- **編集中の `DataTable` はフォームのフィールド（メンバ変数）に保持する。** Web のような **Session／`DTTables` JSON 化は不要**（プロセス内オブジェクトをそのまま持てる＝`RowState`・`Original` とも保たれる）。
- **ダイアログは WinForms ネイティブ**：確認＝`MessageBox.Show(…, MessageBoxButtons.YesNo)`／通知＝`MessageBox.Show(…)`。詳細・子画面は `Form2 dlg = new Form2(); DialogResult r = dlg.ShowDialog(this);`。
- **ユーザ情報は `static`**（`MyBaseControllerWin.UserInfo`）。Session／`UserInfoHandle`／`opentouryo-auth` は使わない（`opentouryo-layer-p-winforms-screen`）。

## (2) 一覧＆更新（RowState バッチの核）

**RowState 振り分け・[追加]＝グリッド外の空行〔Added〕・削除は `DataRowView.Delete()`〔Deleted・`Rows.Remove` にしない〕・NOT NULL 列に値を入れる〔`SqlException 515`〕・IDENTITY は `D1_Insert`／仮採番・成功後 `AcceptChanges`・IDENTITY 採番後に一覧再取得・楽観排他〔`Original`/timestamp・件数0〕は `opentouryo-batch-update`（共通）。** WinForms 固有だけ（コード＝`references/snippets.md`）：

1. **［一覧取得］** → B層で `DataTable` を取得し、**フォームのフィールドへ**保持＋`BindingSource` にバインド。
2. **［追加］**（`UOC_btnAdd_Click`）→ `CommitGridEdits()`→空行を足す（NOT NULL 列に値を入れる）。
3. **［削除］**（**Delete キー**／任意の [削除] ボタン）→ `DataRowView.Delete()`。
4. **セル編集** → バインドで自動的に `DataTable` に入り **Modified**（**Web のような読み戻しは不要**）。
5. **［更新］**（フッタ）→ `CommitGridEdits()` の後 `parameterValue.<表> = dt` で B層へ。**業務例外は `ErrorFlag`（2CS はロールバック・下記）＝`RowState` を残してやり直せる**。反映後は一覧を再取得して再バインド。

## B層の呼び出しとトランザクション（Web と違う）

- **2CS（2層）は手動トランザクション**：正常系は **`LayerB.CommitAndClose()` を明示的に呼ぶ**（呼ばないと確定しない）。**業務例外でも自動ロールバックしない**＝`catch` で
  **`LayerB.RollbackAndClose()`** を呼ぶ（`opentouryo-p-call-business` ④）。**Web/MVC のように「フレームワークが自動コミット／業務例外で自動ロールバック」を前提にしない。**
- **3層（WSクライアント）は `CallController.Invoke(<サービス論理名>, pv)`**＝サーバ側がコミットする（`opentouryo-p-call-business`／`opentouryo-transmission`）。**`Invoke` は `(serviceName, pv)` の2引数＝分離レベルは渡せない**（サーバ側が制御。2CS の `DoBusinessLogic(pv, iso)` と違う）。
  **★ サービス論理名はサーバ側の `TMInProcessDefinition`（`%OT_RESOURCE_ROOT%\Xml\`）にも登録する**——リモート経路はサーバ側を引く。クライアント側だけでは通らない（`opentouryo-transmission`）。
- B層・D層・自動生成 Dao は `opentouryo-layer-b`／`opentouryo-layer-d`／`opentouryo-dao-generated`。

## やってはいけないこと

- **グリッドのセルを「読み戻す」コードを書く** — `DataGridView` は自動バインドで `DataTable` に反映済み。Web の読み戻しは不要。
- **行内 [更新] ボタンを付ける** — 編集は即 `DataTable` に入る＝不要。[削除] も Delete キーで可＝原則不要（発見可能性で足すのは可）。
- **`CommitGridEdits()` を呼ばずに追加/更新/確認ダイアログへ進む** — 行の保留編集（`CurrencyManager.EndCurrentEdit()`）が未確定で入力が消える。
- **削除を `dt.Rows.Remove()` で行う** — `Deleted` にならず DELETE が出ない。`DataRowView.Delete()`。
- **編集中 `DataTable` を Session／`DTTables` JSON にしようとする** — WinForms はフォームのフィールドにオブジェクトを直接持てる（Web の話＝`opentouryo-mvc-crud-screens`）。
- **2CS で `CommitAndClose()` を呼び忘れる／業務例外で自動ロールバックを期待する** — どちらも `opentouryo-p-call-business` の作法に従う。
- **`MyBaseControllerWin.UserInfo`（`protected`）を Form 外から使う** — `CS0122`。Form 外（ハーネス等）は `MyUserInfo` を自前生成して渡す。
- **サンプルの `ComboBoxItem` をフレームワーク型と思って別 Form から使う** — 実体は `Form1` の `private` 入れ子クラス（`CS0234`/`CS0122`）。3層のサービス論理名 DDL 等は**同じ形のクラスを自前で用意**する。

> ※ 配布サンプル（`2CSClientWin_sample`／`WSClientWin_sample`）に本パターンそのままのマスタ保守画面が無いこともある＝**本パターンを正**とし、
> `opentouryo-layer-p-winforms-screen`＋`opentouryo-layer-p-winforms-event`＋`opentouryo-batch-update`＋`opentouryo-p-call-business` で組む。
