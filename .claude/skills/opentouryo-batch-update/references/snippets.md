# バッチ更新 コードスニペット（コピー元）

出典：UserGuide ベターユース編 §4.3・§4.8、`Samples/2CS_sample/GenDaoAndBatUpd_sample/Business/LayerB_BatUpd.cs`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## グリッド操作 → DataTable（RowState を作る）

```csharp
// [追加]（グリッド外のボタン）：空行を足す → RowState = Added
DataRow nr = dt.NewRow();
// nr["ProductName"] = "";  // 既定値を入れてよい
dt.Rows.Add(nr);

// [削除]（グリッド内のボタン）：★ Delete（Remove ではない）→ RowState = Deleted
dr.Delete();

// セル編集：値を書き換えると RowState = Modified
```

- **Web Forms（`GridView` / `ListView` / `Repeater` / `DataList`）**：削除ボタンの `UOC_gvw..._RowDeleting`（`GridView`）等で
  該当行を `Delete()`、追加ボタンの `UOC_btnAdd_Click` で `NewRow()`＋`Rows.Add()`（`opentouryo-layer-p-webforms-event`。
  `DataList` はイベント自動結線外＝ボタンで扱う）。複数ポストバックに跨るなら `DataTable` を Session に保持。
- **`RowDeleting` は該当行を `Delete()` して再バインドするだけ**で足りる＝`e.Cancel` は不要（`DataTable` バインド〔`DataSourceID` 無し〕では GridView 自身は削除処理を持たない。実サンプル `testGridView` も `e.Cancel` を設定しない）。
- **WinForms（`DataGridView`）**：`DataTable`（`BindingSource` 経由）をバインド。**セル編集は自動でバインド先 `DataTable` に反映される**（Web と違い読み戻し不要）＝**行内 [更新] ボタンは不要**。
  **行削除も標準の Delete キーで可**（バインド経由＝`DataRowView.Delete()`＝`Deleted` になる。`Rows.Remove` ではない）＝**[削除] ボタンも基本は不要**だが、**発見可能性・アクセシビリティのために足すこともある**
  （`UOC_btnDelete_Click`）。[追加] は通常のボタン（`UOC_btnAdd_Click`）。`DataGridView` は自動結線外＝`opentouryo-layer-p-winforms-event`。実 CUD はフッタ [更新]＝バッチ更新で一括。
  **★ ただし保留中の編集は `CommitGridEdits()` で確定してから**［追加］/［削除］/バッチ更新・**確認ダイアログの前**に進む——`EndEdit()` は**セルの編集しか確定せず**、行（`DataRowView`）の保留編集は `CurrencyManager.EndCurrentEdit()` まで確定しない＝そのまま進むと入力が失われる（実測）。

```csharp
// WinForms: バインド
BindingSource bs = new BindingSource { DataSource = dt };
this.dataGridView1.DataSource = bs;

// ★ グリッドの保留中の編集を確定（各操作＝追加/更新/削除/バッチ更新・確認ダイアログの前に呼ぶ）
void CommitGridEdits() {
    this.dataGridView1.EndEdit();          // セルの編集を確定
    bs.CurrencyManager.EndCurrentEdit();   // ★ 行(DataRowView)の保留編集を確定（これが無いと追加/更新で入力が消える）
}

// [追加]（UOC_btnAdd_Click）：空行 → Added（★ DB 側 NOT NULL 列には値を入れる＝DBNull のままだと INSERT で SqlException 515）
CommitGridEdits();
DataRow nr = dt.NewRow();
dt.Rows.Add(nr);

// [削除]（任意。Delete キーでも同じ＝バインド経由で Deleted になる）
CommitGridEdits();
if (bs.Current is DataRowView drv) drv.Row.Delete();   // ★ Delete（Remove ではない）
```

## ★ Web グリッド：セル値を DataRow へ読み戻す（index ずれ・DBNull 対策）

セル編集は自動では `DataTable` に入らない。**グリッドのセル → DataRow へ読み戻す**（`Modified` はこの代入で立つ）。
`Deleted` 行は表示から外れるので `e.RowIndex` と `dt.Rows[i]` はずれる → **`Deleted` を飛ばして数える**。
`DataKeyNames` は追加行の PK が `DBNull` で使えない。
**★ 読み戻す行は「追加行は常に／既存行はその行の [更新] のときだけ／削除行は対象外」**（追加行は DB に戻す値が無く落とすと再バインドで空行化＝要保護／既存行は取得時値が `dt` に残る＝読み戻さず「未確定」で可）。呼び出し側で `targetDisplayIndex` を渡す（[更新]＝当該行・[削除]/[バッチ更新]＝-1）。**※ 行 [更新] を置かない（[削除]のみ）パターンは既存行を per-row 確定する手段が無い＝[バッチ更新] で全レコードを読み戻す（上の skip を外す）。**

```csharp
// targetDisplayIndex ＝ [更新] が押された行の表示 index（[削除]/[バッチ更新] は -1＝追加行のみ）
foreach (GridViewRow gvr in this.gvwSuppliers.Rows)
{
    if (gvr.RowType != DataControlRowType.DataRow) continue;

    // 表示 index → DataRow（Deleted を飛ばしながら数える。★ dt.Rows[gvr.RowIndex] としない）
    DataRow dr = GetDataRowForDisplayIndex(dt, gvr.RowIndex);

    // ★ 追加行は常に読み戻す（DB に戻す値が無く、落とすと再バインドで空行化）。既存行はその行の [更新] のときだけ。
    if (dr.RowState != DataRowState.Added && gvr.RowIndex != targetDisplayIndex) continue;

    string edited = ((TextBox)gvr.FindControl("txtCompanyName")).Text;

    // ★ 追加行（Added）は全列が DBNull 始まり。skip 判定に掛けると値を入れない列が DBNull のまま残り、
    //   NOT NULL 列へ NULL を送って INSERT が SqlException 515 → Added は skip せず無条件代入する
    //   （下の「空↔空は変更なし」は Unchanged/Modified 行だけの話）
    if (dr.RowState == DataRowState.Added) { dr["CompanyName"] = edited; continue; }

    // ★ 元が DBNull の列に "" を代入しない・現在値と同じなら代入しない（無駄 Modified＝無駄 UPDATE を防ぐ）
    object cur = dr["CompanyName"];
    bool curBlank = (cur == DBNull.Value) || (string)cur == "";
    if (curBlank && edited == "") continue;                 // 空↔空は変更なし
    if (!curBlank && (string)cur == edited) continue;       // 同値は触らない
    dr["CompanyName"] = edited;                             // ここで初めて Modified
}

// Deleted を飛ばして「表示 index 番目」の DataRow を返す
DataRow GetDataRowForDisplayIndex(DataTable dt, int displayIndex)
{
    int i = -1;
    foreach (DataRow dr in dt.Rows)
    {
        if (dr.RowState == DataRowState.Deleted) continue;  // 表示されていない
        if (++i == displayIndex) return dr;
    }
    return null;
}
```

## B層：RowState で振り分け（自動生成 Dao）

```csharp
DaoProducts dao = new DaoProducts(this.GetDam());

foreach (DataRow dr in dt.Rows)
{
    dao.ClearParametersFromHt();   // 行ごとにパラメタをクリア

    switch (dr.RowState)
    {
        case DataRowState.Added:
            // 全列を現在値で設定
            dao.PK_ProductID = dr["ProductID"].ToString();
            dao.ProductName  = dr["ProductName"].ToString();
            // …他の列…
            dao.S1_Insert();     // または D1_Insert()
            break;

        case DataRowState.Deleted:
            // ★ 削除行は Original しか読めない
            dao.PK_ProductID = dr["ProductID", DataRowVersion.Original].ToString();
            // 楽観排他するならタイムスタンプの Original もここで設定
            dao.D4_Delete();     // タイムスタンプ併用時は D4、主キーのみなら S4_Delete()
            break;

        case DataRowState.Modified:
            // WHERE 用：主キー＋（楽観排他するなら）元の値
            dao.PK_ProductID = dr["ProductID"].ToString();
            dao.ProductName  = dr["ProductName", DataRowVersion.Original].ToString();  // ← 元値で照合
            // …他の WHERE 列も Original…
            // SET 用：現在値
            dao.Set_ProductName_forUPD = dr["ProductName"].ToString();
            // …他の Set_列_forUPD も現在値…
            dao.D3_Update();     // タイムスタンプ併用時は D3、主キーのみの WHERE なら S3_Update()
            break;

        default:
            break;               // Unchanged はスキップ
    }
}

// 成功後：RowState を Unchanged に戻す
dt.AcceptChanges();
```

- ★ **追加した行（`Added`）を `Delete()` すると `Detached` になり `dt.Rows` から外れる**＝この switch には来ない
  （＝追加→削除した行は DELETE されず単に消える。正しい挙動）。`Deleted` に来るのは**元から DB にあった行**だけ。

- `Set_列_forUPD`＝UPDATE の SET 句、`PK_列`＝WHERE、`列名`＝挿入/主キー以外（`opentouryo-dao-generated`）。
- 更新/削除の**件数0＝楽観排他の失敗**（タイムスタンプ アンマッチ）→ 業務例外（`opentouryo-exception`）。

## 大量データ：SQLUtility でバッチ INSERT（SQL Server のみ）

```csharp
// 型/日付書式は SQLUtility の【コンストラクタ】引数（GetInsertSQLParts の引数ではない）。
//   第2 convertString  … Convert() の変換先型。SQL Server 既定 "nvarchar"
//   第3 dateTimeFormat … 日付の文字列化書式。SQL Server 既定 "yyyy/MM/dd HH:mm:ss.fff"
SQLUtility su = new SQLUtility(DbEnum.DBMSType.SQLServer);          // 既定でよければ dbms のみ
string[] parts = su.GetInsertSQLParts(dt);   // [0]=列リスト, [1..]=各行の VALUES（1引数）

string collist = parts[0];
StringBuilder sb = new StringBuilder();
for (int i = 1; i < parts.Length; i++) sb.Append(parts[i] + ",");
string values = sb.ToString().TrimEnd(',');

CmnDao cd = new CmnDao(this.GetDam());
cd.SQLText = string.Format("INSERT INTO Products{0} VALUES{1}", collist, values);
cd.ExecInsUpDel_NonQuery();
// → INSERT INTO Products([col..]) VALUES (..),(..),(..)  の1文
```

- UPDATE は `su.GetUpdateSQLParts(dt, new string[]{ "ProductID" })`（第2引数＝主キー列の配列。各行 WHERE 付き UPDATE を生成）。
  **複数 UPDATE 文は `;` で連結**して 1 回で流す。
- **値はパラメタではなく SQL 文字列へ展開**される（パラメタ数上限の回避）。型は `Convert()` で明示、`NULL` は明示的に出力。
- **`ExecGenerateSQL`（生成のみ・実行しない）**：**自動生成 Dao は公開の2引数 `ExecGenerateSQL(fileName, sqlUtil)` を持つ**
  （生成物にこの形で出る）。中身は下記。基底は `BaseDao.ExecGenerateSQL(sqlUtil)`（1引数・`protected`）／`CmnDao` は1引数 `public new`／実体 `BaseDam`。

```csharp
// 自動生成 Dao 側（DaoTemplate 生成物）— 呼び出しは dao.ExecGenerateSQL("Xxx.xml", su)
public string ExecGenerateSQL(string fileName, SQLUtility sqlUtil)
{
    this.SetSqlByFile2(fileName);        // SQL ファイル
    this.SetCommandTimeout();
    this.SetParametersFromHt();          // Ht に溜めたパラメタ
    return base.ExecGenerateSQL(sqlUtil); // ← 基底の1引数（生成のみ・実行しない）
}
```

> ※ フレームワーク経由は 1 件 ≈ 0.5ms。件数が多いときだけバッチ SQL を検討（少数なら上の RowState ループで十分）。
