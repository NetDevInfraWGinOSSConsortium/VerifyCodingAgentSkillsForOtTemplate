# コピー元スニペット（WinForms テーブル保守 CRUD 画面）

実装時はここから写す。**RowState の switch 全文・自動生成 Dao の CUD 振り分けは `opentouryo-batch-update` の `references/snippets.md`**（重複させない）。

## 画面（一覧＆更新）の骨格＝編集中 DataTable はフィールドに持つ

```csharp
using System.Data;
using System.Windows.Forms;
using Touryo.Infrastructure.Framework.RichClient.Presentation;   // RcFxEventArgs

// SuppliersBaseForm＝共通フッタ5ボタンを持つ中間 BaseForm（opentouryo-layer-p-winforms-screen）
public partial class SuppliersScreenB : SuppliersBaseForm
{
    private DataTable _dt;                    // ★ 編集中の DataTable はフォームのフィールドに保持（Session 不要）
    private BindingSource _bs = new BindingSource();

    protected override void UOC_FormInit()
    {
        this.dgvSuppliers.AutoGenerateColumns = true;   // ★ 骨格は自動生成＝全列そのまま。業務画面は列を明示（IDENTITY 主キーは ReadOnly。Web と列を揃えるなら AutoGenerateColumns=false ＋ DataGridViewTextBoxColumn を並べる）
        this.dgvSuppliers.DataSource = _bs;   // グリッドは BindingSource にバインド
        // ★ 一覧の列は「例を短く保つ省略」でなく対象テーブルの全列（＝自動生成Dao の D2_Select が返す列）を基準に表示/編集可否を決める
        //   （worked example の列を絞ったまま採ると、B層は書けるのに画面から入力できない列が静かに生まれる）
        // フッタ ボタンのキャプション・活性/非活性はここで動的に（opentouryo-layer-p-winforms-screen）
    }

    // ★ グリッドの保留中の編集を確定（各操作＝追加/削除/バッチ更新・確認ダイアログの前に必ず呼ぶ）
    private void CommitGridEdits()
    {
        this.dgvSuppliers.EndEdit();                 // セルの編集を確定
        _bs.CurrencyManager.EndCurrentEdit();        // ★ 行(DataRowView)の保留編集を確定（無いと追加/更新で入力が消える＝実測）
    }
}
```

## ［一覧取得］→ フィールドへ保持しバインド

```csharp
protected void UOC_btnSelectAll_Click(RcFxEventArgs e)
{
    // B層で DataTable を取得（opentouryo-p-call-business / opentouryo-layer-b）
    SuppliersReturnValue rv = /* new SuppliersLayerB().DoBusinessLogic(pv, iso) の戻り */;
    _dt = rv.Suppliers;
    _bs.DataSource = _dt;                    // 再バインド。RowState は _dt が保持
}
```

## ［追加］＝グリッド外ボタン（Added）。NOT NULL 列は値を入れる

```csharp
protected void UOC_btnAdd_Click(RcFxEventArgs e)
{
    CommitGridEdits();                       // ★ 先に保留編集を確定
    DataRow nr = _dt.NewRow();
    nr["CompanyName"] = "";                  // ★ DB 側 NOT NULL 列は "" で初期化（DBNull のまま INSERT すると SqlException 515。
                                             //    ExecSelectFill_DT は制約を落とすので dt からは判定できない＝アプリが知っておく。opentouryo-batch-update）
    _dt.Rows.Add(nr);                        // ＝Added。IDENTITY 主キーは仮採番が要るときだけ負値で（opentouryo-batch-update）
}
```

## ［削除］＝Delete キーで可（＝原則ボタン不要）。任意で [削除] ボタンを足す場合

```csharp
// 標準：DataGridView の Delete キーで削除できる（AllowUserToDeleteRows=true）。
//   バインド経由で DataRowView.Delete() が呼ばれ RowState=Deleted になる（Rows.Remove ではない）。

// 任意：発見可能性・アクセシビリティのために [削除] ボタン列を置く場合。
//   ★ DataGridViewButtonColumn は自動結線対象外＝btn 接頭辞の UOC_btn…_Click にならない。
//     素の CellContentClick で拾う（opentouryo-layer-p-winforms-event）。
private void dgvSuppliers_CellContentClick(object sender, DataGridViewCellEventArgs e)
{
    if (e.RowIndex < 0) return;
    if (this.dgvSuppliers.Columns[e.ColumnIndex] is DataGridViewButtonColumn &&
        this.dgvSuppliers.Columns[e.ColumnIndex].Name == "colDelete")
    {
        CommitGridEdits();
        if (this.dgvSuppliers.Rows[e.RowIndex].DataBoundItem is DataRowView drv) drv.Row.Delete();   // ＝Deleted
    }
}
```

## ［更新］（フッタ）＝RowState バッチ＋2CS 手動トランザクション

```csharp
protected void UOC_btnBatchUpdate_Click(RcFxEventArgs e)
{
    // 確認ダイアログの前に確定する
    CommitGridEdits();
    if (MessageBox.Show("更新します。よろしいですか？", "確認", MessageBoxButtons.YesNo) != DialogResult.Yes) return;

    // ★ MyBaseControllerWin.UserInfo は protected＝画面クラス（MyBaseControllerWin 派生 Form）の中からのみ可。
    //   Form でないクラス（検証ハーネス／ユーティリティ）からは CS0122＝MyUserInfo を自前で生成して渡す。
    SuppliersParameterValue pv = new SuppliersParameterValue(/* 画面名, "-", this の ActionName 相当, "SQL", MyBaseControllerWin.UserInfo */);
    pv.Suppliers = _dt;                      // RowState 付きの DataTable をそのまま渡す
    SuppliersLayerB layerB = new SuppliersLayerB();

    try
    {
        SuppliersReturnValue rv = (SuppliersReturnValue)layerB.DoBusinessLogic(pv, DbEnum.IsolationLevelEnum.User);

        if (rv.ErrorFlag)
        {
            layerB.RollbackAndClose();       // ★ 2CS は業務例外で自動ロールバックしない＝明示ロールバック（opentouryo-p-call-business）
            MessageBox.Show(rv.ErrorMessage);
            return;                          // RowState は _dt に残る＝やり直せる
        }

        layerB.CommitAndClose();             // ★ 2CS は明示コミット（呼ばないと確定しない）
        _dt.AcceptChanges();                 // 反映できたので確定

        // IDENTITY 採番値は DataTable に戻らない＝一覧を取り直して再バインド
        // （B層で SelectAll → _dt = rv2.Suppliers; _bs.DataSource = _dt;）
    }
    catch
    {
        layerB.RollbackAndClose();           // システム例外も明示ロールバック
        throw;
    }
}
```

- **B層内の RowState 振り分け**（`foreach (DataRow dr in dt.Rows)` の `switch (dr.RowState)`→自動生成 Dao の S1/D1_Insert・S3/D3_Update・S4/D4_Delete）は **`opentouryo-batch-update` の `references/snippets.md`** をそのまま使う。
- **3層（WSクライアント）** は `LayerB.DoBusinessLogic` の代わりに `CallController.Invoke(<サービス論理名>, pv)`＝サーバ側がコミット（手動 Commit/Rollback は不要。`opentouryo-p-call-business`／`opentouryo-transmission`）。

## (1) 一覧→詳細＝子フォームを ShowDialog で開く

```csharp
// 一覧の行をダブルクリック等で詳細へ（選択行の主キーを渡す）
private void dgvSuppliers_CellDoubleClick(object sender, DataGridViewCellEventArgs e)
{
    if (e.RowIndex < 0) return;
    DataRowView drv = (DataRowView)this.dgvSuppliers.Rows[e.RowIndex].DataBoundItem;
    int supplierId = (int)drv["SupplierID"];

    using (SuppliersDetail dlg = new SuppliersDetail(supplierId))   // 主キーをコンストラクタで渡す（新規は「無し」＝INSERT モード）
    {
        if (dlg.ShowDialog(this) == DialogResult.OK) { /* 変更されたので一覧を再取得して再バインド */ }
    }
}
```

- 詳細フォームは**単一レコード CRUD**（取得→表示、Insert/Update/Delete）。更新/削除は **PK＋タイムスタンプで楽観排他**（件数0チェック＝`opentouryo-layer-d`／`opentouryo-dao-generated`）。トランザクションは (2) と同じ 2CS 手動／3層 Invoke。
