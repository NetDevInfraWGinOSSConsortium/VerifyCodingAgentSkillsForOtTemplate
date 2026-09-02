# テーブル保守 CRUD 画面 スニペット（コピー元＋自動生成→推奨の書き換え）

出典：配布サンプル `WebForms_Sample` の `Aspx/sample/3Tier/Products{ConditionalSearch,Detail,SearchAndUpdate}.aspx(.cs)`＋`AppCode/sample/3TierTableAdapter/ProductsTableAdapter.cs`＋framework `Business/Business/_3TierEngine.cs`・`Business/Presentation/CmnTableAdapter.cs`。
**★ サンプルは自動生成（墨壺２）。以下は「構造はそのまま使える部分」と「自動生成→推奨実装へ書き換える部分（★）」を分けて示す。サンプルは削除されうるので本スニペットを正とする。**

## 1. 一覧（検索）画面：行選択 → Session → 詳細へ遷移【そのまま使える】

`.aspx`：`<asp:GridView DataKeyNames="ProductID" AllowPaging="True" AllowSorting="True" PageSize="30">` に `<asp:CommandField ShowSelectButton="true">`。

```csharp
// Page_Init で「選択前」イベントを結線（PostBack 前に選択行の PK を確定するため）
protected void Page_Init(object sender, EventArgs e)
    => this.gvwGridView1.SelectedIndexChanging += this.gvwGridView1_SelectedIndexChanging;

// 選択前：選択行の主キー（＋タイムスタンプ）を Session へ（詳細画面へ持ち回る）
private void gvwGridView1_SelectedIndexChanging(object sender, GridViewSelectEventArgs e)
{
    DataTable dt = (DataTable)Session["SearchResult"];
    var pk = new Dictionary<string, object>();
    pk.Add("ProductID", dt.Rows[e.NewSelectedIndex]["ProductID"].ToString());
    // タイムスタンプ列があればここで追加
    Session["PrimaryKeyAndTimeStamp"] = pk;
}

// 選択後：詳細へ遷移（PK は Session 済み＝表示モード）
protected string UOC_gvwGridView1_SelectedIndexChanged(FxEventArgs e) => "ProductsDetail.aspx";

// 追加ボタン：PK を Session に入れず詳細へ（＝新規モード）
protected string UOC_btnInsert_Click(FxEventArgs e)
{
    Session["PrimaryKeyAndTimeStamp"] = null;   // ★ 新規は PK を消す
    return "ProductsDetail.aspx";
}
```
状態持ち回りは Session（別画面・別ポストバックをまたぐ。`opentouryo-app-design/references/state-management.md`）。

## 2. 詳細画面：モード分岐（新規/表示）と CRUD

### モード分岐【そのまま使える】
```csharp
protected override void UOC_FormInit()
{
    if (Session["PrimaryKeyAndTimeStamp"] == null)
    {   // 新規（INSERT）モード：更新/削除/編集を不活性・入力可
        this.btnUpdate.Enabled = this.btnDelete.Enabled = this.btnEdit.Enabled = false;
        this.SetControlReadOnly(false);
    }
    else
    {   // 表示モード：レコード取得→表示（初期 ReadOnly、btnEdit で編集可に）
        // …下の「P→B 呼び出し」で SelectRecord…
        this.SetControlReadOnly(true);
    }
}
protected string UOC_btnEdit_Click(FxEventArgs e) { this.SetControlReadOnly(false); return ""; }
```

### P→B 呼び出し：★自動生成 → 推奨に書き換える
**自動生成（汎用エンジン `_3TierEngine`＋`TableName`＋`Dictionary`＋actionType）：**
```csharp
// 更新（自動生成）
var pv = new _3TierParameterValue(this.ContentPageFileNoEx, e.ButtonID, "UpdateRecord",
    (string)Session["DAP"], (MyUserInfo)this.UserInfo);
pv.TableName = "Products";
pv.AndEqualSearchConditions = (Dictionary<string, object>)Session["PrimaryKeyAndTimeStamp"]; // PK+TS
pv.InsertUpdateValues = new Dictionary<string, object>();
pv.InsertUpdateValues.Add("ProductName", this.txtProductName.Text);   // … 各列 …
var rv = (_3TierReturnValue)new _3TierEngine().DoBusinessLogic((BaseParameterValue)pv, iso);
```
**推奨（業務 `LayerB`＋業務 `ParameterValue`＋自動生成 Dao）：**
```csharp
// P層：業務ごとの型で組み立て、LayerB を直呼び（Web＝直呼び。opentouryo-p-call-business）
var pv = new ProductsParameterValue(this.ContentPageFileNoEx, e.ButtonID, "Update", actionType, this.UserInfo);
pv.ProductID   = int.Parse(this.txtProductID.Text);     // PK
pv.ProductName = this.txtProductName.Text;              // 更新値（型付き）／…各列…／ts があれば取得時の値も
var rv = (ProductsReturnValue)new LayerB().DoBusinessLogic(pv, iso);

// B層（LayerB.UOC_Update）：自動生成 Dao で更新（楽観排他＝件数0チェック）
private void UOC_Update(ProductsParameterValue pv)
{
    DaoProducts dao = new DaoProducts(this.GetDam());
    dao.PK_ProductID = pv.ProductID;
    dao.Set_ProductName_forUPD = pv.ProductName;         // … Set_列_forUPD …／ts があれば WHERE 用に元値
    int n = dao.S3_Update();                             // or D3_Update（タイムスタンプ併用時）
    if (n == 0) throw new BusinessApplicationException("E0001", "他者が先に更新（楽観排他）");
    this.ReturnValue = new ProductsReturnValue() { /* 件数など */ };
}
```
- **INSERT/DELETE も同型**：actionType を `Insert`/`Delete`、Dao は `S1_Insert`/`S4_Delete`（採番 IDENTITY はメモリに戻らない＝反映後に再取得。`opentouryo-dao-generated`・`opentouryo-layer-b`）。
- **検索条件（一覧）は `Dictionary` でなく DPQ**（動的クエリ `.xml`。`opentouryo-query-definition`）。

## 3. 一覧＆更新：結果セットを固定【★核心・UI ロジックはそのまま使える】

`.aspx`：一覧に行ごとの `<asp:CommandField>`＝[更新][削除]列（`CommandName="Update"/"Delete"`）。

```csharp
protected string UOC_gvwGridView1_RowCommand(FxEventArgs e)
{
    if (e.InnerButtonID == "Sort") return string.Empty;

    DataTable dt = (DataTable)Session["SearchResult"];   // 現在の結果セット
    int index = int.Parse(e.PostBackValue);              // 押された行の表示 index

    // 表示 index → DataRow（★ Deleted/Added を飛ばして数える。ヘルパは opentouryo-batch-update）
    DataRow dr = GetDataRowForDisplayIndex(dt, index);

    if (e.InnerButtonID == "Delete")
    {
        dr.Delete();                                     // → Deleted
    }
    else if (e.InnerButtonID == "Update")
    {
        GridViewRow row = this.gvwGridView1.Rows[index];
        foreach (DataColumn c in dt.Columns)             // グリッドのセル → DataRow へ読み戻し（→ Modified）
        {
            var tb = (TextBox)row.FindControl("txt" + c.ColumnName);
            if (tb != null) dr[c] = tb.Text;             // ※ DBNull↔"" の無駄 Modified に注意（opentouryo-batch-update）
            var ddl = (DropDownList)row.FindControl("ddl" + c.ColumnName);
            if (ddl != null) dr[c] = ddl.SelectedValue;
        }
    }

    // ★★ 結果セットを固定：ページングを止め、Session の DataTable に再バインド
    this.gvwGridView1.AllowPaging = false;               // ページ切替の再取得を止める＝RowState を保つ
    this.gvwGridView1.DataSourceID = null;               // ObjectDataSource を外す
    this.gvwGridView1.DataSource = dt;
    this.gvwGridView1.DataBind();
    Session["SearchResult"] = dt;
    this.btnBatUpd.Enabled = true;                       // バッチ更新ボタンを活性化
    return string.Empty;
}
```
- **バッチ更新ボタン**：`Session["SearchResult"]` の `DataTable`（RowState 保持）を B層で **RowState バッチ更新**。★自動生成は `_3TierEngine` "BatchUpdate"／推奨は業務 `LayerB` の `switch(dr.RowState)`＋自動生成 Dao（`opentouryo-batch-update`）。
- **[追加] はグリッド外のボタンで一覧に空行を足す**（`UOC_btnAdd_Click`→`dt.NewRow()`＋`dt.Rows.Add()`＝Added。MVC と同一＝`opentouryo-batch-update`）。**DB 側 NOT NULL 列に値を入れる**（`SqlException 515`）。※ 一覧の列は例（`ProductName` 等）を短く保つ省略＝**実装は対象テーブルの全列を基準に**表示/編集可否を決める（IDENTITY 主キーは `readonly`）。

## DDL（`DropDownList`）列の注意（FK をマスタ選択にするとき）

- **`ListItem` は完全修飾する（`CS0104`）**：コードビハインドに `using Touryo.Infrastructure.CustomControl;` があると、`new ListItem(...)` が **`Touryo.Infrastructure.CustomControl.ListItem` と `System.Web.UI.WebControls.ListItem` のあいまい参照（`CS0104`）**になる。DDL にマスタをバインドする画面では必ず出る＝**`new System.Web.UI.WebControls.ListItem(...)` と書く**。
- **検索条件 DDL の空選択肢を二重に足さない**：グリッド内 DDL 用のバインド ヘルパが先頭に空 `ListItem` を入れる作りだと、検索条件側で `Items.Insert(0, new ListItem("（すべて）", ""))` すると空が2つ並ぶ。**検索条件側は先頭の空選択肢を「（すべて）」に置き換える**（追加しない）。

## 4. ページング（P層 ObjectDataSource ⇄ D層 SQL）

`.aspx`：`<asp:ObjectDataSource EnablePaging="True" TypeName="…ProductsTableAdapter" SelectMethod="SelectMethod" SelectCountMethod="SelectCountMethod" MaximumRowsParameterName="maximumRows" StartRowIndexParameterName="startRowIndex">`。

```csharp
// TableAdapter（CmnTableAdapter 派生）：ソート・ページング条件を B層へ渡す
public int SelectCountMethod() { /* B層で COUNT を取る（D5_SelCnt 等） */ }

public DataTable SelectMethod(int startRowIndex, int maximumRows)
{
    var pv = this.CreateParameter("Products", "SelectMethod", MyBaseController.GetUserInfo2());
    pv.SortExpression = (string)HttpContext.Current.Session["SortExpression"];
    pv.SortDirection  = (string)HttpContext.Current.Session["SortDirection"];
    pv.StartRowIndex  = startRowIndex;  pv.MaximumRows = maximumRows;
    // ★書き換え：new _3TierEngine() でなく 業務 LayerB を呼ぶ
    var rv = (ProductsReturnValue)new LayerB().DoBusinessLogic(pv, iso);
    HttpContext.Current.Session["SearchResult"] = rv.Dt;   // 一覧＆更新のためフル結果を Session へ
    return rv.Dt;
}
```
- **D層はページング SQL**：`ROW_NUMBER() OVER (ORDER BY … ) BETWEEN @from AND @to`（DBMS 別＝SQL Server は `WITH … CTE`／Oracle は別式。`opentouryo-app-design/references/list-paging.md`）。自動生成 `_3TierEngine` は内部でこの ROW_NUMBER SQL を生成している（`_3TierEngine.cs`）。

## 書き換えチェック（何処を → どう）

| 何処（自動生成） | どう（推奨） |
| --- | --- |
| `new _3TierEngine()` | 業務 `new LayerB()`（`UOC_Select/Insert/Update/Delete/BatchUpdate`） |
| `_3TierParameterValue`＋`TableName`＋`Dictionary` | 業務 `ProductsParameterValue`（型付きプロパティ。`MyParameterValue` 派生） |
| engine 内部の自動生成 SQL 直利用 | 業務 Dao から自動生成 Dao（`S1/D1_Insert`・`S3/D3_Update`・`S4/D4_Delete`・件数 `D5_SelCnt`） |
| 検索条件 `Dictionary`（AndEqual/Like/Or…） | 動的クエリ DPQ `.xml`（`opentouryo-query-definition`） |
| バッチ＝`_3TierEngine` "BatchUpdate" | `switch(dr.RowState)`＋自動生成 Dao（`opentouryo-batch-update`） |
| `SelectMethod` が `_3TierEngine` を呼ぶ | `SelectMethod` は **業務 `LayerB`** を呼ぶ（ObjectDataSource／ページング機構は残してよい） |
| **そのまま**＝行選択→Session、モード分岐、結果セット固定、ROW_NUMBER ページング | UI・データ取得の**構造は推奨実装でも同じ**。呼び先を engine→LayerB に替えるだけ |
