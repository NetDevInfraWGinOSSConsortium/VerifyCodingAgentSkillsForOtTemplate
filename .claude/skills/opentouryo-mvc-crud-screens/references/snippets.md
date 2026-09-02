# コピー元スニペット：MVC テーブル保守 CRUD（一覧＆更新）

`opentouryo-mvc-crud-screens` の実装コード。**Core MVC（net10.0）想定**。表は `Suppliers`（`SupplierID` は IDENTITY）を例にした worked example。
Session 直列化は **`DTTables` JSON**（`Touryo.Infrastructure.Public.Dto`）を使う（net48 MVC なら `DataTable` を直接 Session に置けるのでこの直列化は不要）。

## コントローラ（画面Ｂ＝一覧・行追加／行削除・バッチ更新）

```csharp
[Authorize(AuthenticationSchemes = CookieAuthenticationDefaults.AuthenticationScheme)]
public class SuppliersBController : MyBaseMVControllerCore
{
    private const string SessionKey = "SuppliersEditing";   // Core Session は string/byte[] のみ

    // --- Session への DataTable の出し入れ（Core＝DTTables JSON。net48 なら直接置ける） ---
    private DataTable LoadEditingTable()
    {
        string json = this.HttpContext.Session.GetString(SessionKey);
        if (string.IsNullOrEmpty(json)) { return null; }

        DataTable dt = DTTables.JsonToDTTables(json).ToDataSet().Tables["Suppliers"];
        // ★ 任意：DTTables 往復で列属性（AutoIncrement 等）が落ちるが、標準フローでは掛け直し不要
        //   （そもそも ExecSelectFill_DT は制約を取り込まない＝PrimaryKey/NOT NULL 無し・NewRow+Add は例外なし。
        //    IDENTITY は INSERT しない＝仮採番値は無関係。DB 側 NOT NULL 列は値を入れて INSERT＝空 DBNull は SqlException 515）。
        //   追加行の仮主キーを実際に使うとき（Rows.Find／自前 PrimaryKey／安定した仮 ID 表示）だけ呼ぶ。
        RestoreTempNumbering(dt);
        return dt;
    }

    // ★ IDENTITY 主キーの負値仮採番を掛け直す（上記のとおり任意）。シードは -1 固定でなく「既にある仮採番の最小 - 1」
    //   （-1 固定だと往復のたびに巻き戻り、2行目以降の追加行が -1 で重複する＝実測）。
    //   PrimaryKey / AllowDBNull も落ちるが、行特定はクライアント都合なので戻さない（DB 側の主キーが本体）。
    private static void RestoreTempNumbering(DataTable dt)
    {
        int minTemp = 0;   // 既存の最も小さい負値（＝仮採番）。無ければ 0 のまま
        foreach (DataRow r in dt.Rows)
        {
            if (r.RowState == DataRowState.Deleted) { continue; }   // Deleted は現在値を読めない
            if (r["SupplierID"] != DBNull.Value && Convert.ToInt32(r["SupplierID"]) < minTemp)
            {
                minTemp = Convert.ToInt32(r["SupplierID"]);
            }
        }
        DataColumn pk = dt.Columns["SupplierID"];
        pk.AutoIncrement = true; pk.AutoIncrementSeed = minTemp - 1; pk.AutoIncrementStep = -1;   // 無ければ -1 から
    }

    private void SaveEditingTable(DataTable dt)
    {
        if (dt == null) { this.HttpContext.Session.Remove(SessionKey); return; }

        DataSet ds = new DataSet();
        ds.Tables.Add(dt.Copy());
        this.HttpContext.Session.SetString(SessionKey, DTTables.DTTablesToJson(DTTables.FromDataSet(ds)));
    }

    // --- 画面表示（開き直したら編集内容は破棄） ---
    [HttpGet]
    public IActionResult Index(SuppliersViewModel model)
    {
        this.SaveEditingTable(null);
        return View(model);
    }

    // --- 一覧取得 ---
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> SelectAll(SuppliersViewModel model)
    {
        // ↓B層実行：Suppliers の一覧を取得------------------------------------------------
        SuppliersParameterValue pv = new SuppliersParameterValue(
            this.ControllerName, "-", this.ActionName, "SQL", this.UserInfo);
        SuppliersReturnValue rv = (SuppliersReturnValue)await (new SuppliersLayerB())
            .DoBusinessLogicAsync(pv, DbEnum.IsolationLevelEnum.User);
        // ↑B層実行：Suppliers の一覧を取得------------------------------------------------

        if (rv.ErrorFlag) { model.Message = rv.ErrorMessage; }
        else
        {
            this.SaveEditingTable(rv.Suppliers);
            model.Suppliers = rv.Suppliers;
            model.Message = "一覧を取得しました（" + rv.Suppliers.Rows.Count + " 件）。";
        }
        return View("Index", model);
    }

    // --- 行追加（RowState=Added。IDENTITY は負値で仮採番） ---
    [HttpPost]
    [ValidateAntiForgeryToken]
    public IActionResult AddRow(SuppliersViewModel model)
    {
        DataTable dt = this.LoadEditingTable();
        if (dt == null) { model.Message = "先に一覧を取得して下さい。"; return View("Index", model); }

        this.ReadRowsIntoTable(dt, model, -1);     // -1＝追加行のみ読み戻す（既存行は各行の[更新]で確定済み）
        DataRow nr = dt.NewRow();
        nr["CompanyName"] = "";                // ★ DB 側 NOT NULL 列は "" で初期化（DBNull のまま INSERT すると SqlException 515。ExecSelectFill_DT は制約を落とすので dt からは判定できない＝アプリが知っておく）
        dt.Rows.Add(nr);                       // 空行を足す＝Added
        this.SaveEditingTable(dt);
        model.Suppliers = dt; model.Message = "行を追加しました。";
        return View("Index", model);
    }

    // --- 行削除（RowState=Deleted。Rows.Remove ではない） ---
    [HttpPost]
    [ValidateAntiForgeryToken]
    public IActionResult DeleteRow(SuppliersViewModel model, int rowIndex)
    {
        DataTable dt = this.LoadEditingTable();
        if (dt == null) { model.Message = "先に一覧を取得して下さい。"; return View("Index", model); }

        this.ReadRowsIntoTable(dt, model, -1);   // -1＝追加行のみ読み戻す
        if (0 <= rowIndex && rowIndex < dt.Rows.Count) { dt.Rows[rowIndex].Delete(); }
        this.SaveEditingTable(dt);
        model.Suppliers = dt; model.Message = "行を削除しました（［更新］でDBに反映）。";
        return View("Index", model);
    }

    // --- 行［更新］（既存行をその場で確定＝Modified。追加行＋当該行だけ読み戻す） ---
    [HttpPost]
    [ValidateAntiForgeryToken]
    public IActionResult UpdateRow(SuppliersViewModel model, int rowIndex)
    {
        DataTable dt = this.LoadEditingTable();
        if (dt == null) { model.Message = "先に一覧を取得して下さい。"; return View("Index", model); }

        this.ReadRowsIntoTable(dt, model, rowIndex);   // 当該既存行＋追加行を読み戻す
        this.SaveEditingTable(dt);
        model.Suppliers = dt; model.Message = "行を更新しました（［更新］でDBに反映）。";
        return View("Index", model);
    }

    // --- バッチ更新（CUD を一括反映） ---
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> BatchUpdate(SuppliersViewModel model)
    {
        DataTable dt = this.LoadEditingTable();
        if (dt == null) { model.Message = "先に一覧を取得して下さい。"; return View("Index", model); }

        this.ReadRowsIntoTable(dt, model, -1);     // -1＝追加行のみ（既存行は各行の[更新]で確定済み）

        // ↓B層実行：Suppliers のバッチ更新------------------------------------------------
        SuppliersParameterValue pv = new SuppliersParameterValue(
            this.ControllerName, "-", this.ActionName, "SQL", this.UserInfo);
        pv.Suppliers = dt;
        SuppliersReturnValue rv = (SuppliersReturnValue)await (new SuppliersLayerB())
            .DoBusinessLogicAsync(pv, DbEnum.IsolationLevelEnum.User);
        // ↑B層実行：Suppliers のバッチ更新------------------------------------------------

        if (rv.ErrorFlag)
        {
            // 業務例外＝ロールバック済み。RowState を残してやり直せるようにする
            this.SaveEditingTable(dt);
            model.Suppliers = dt; model.Message = rv.ErrorMessage;
            return View("Index", model);
        }

        dt.AcceptChanges();   // 反映できたので確定

        // IDENTITY の採番値は DataTable に戻らないので、一覧を取り直す
        SuppliersParameterValue reloadPv = new SuppliersParameterValue(
            this.ControllerName, "-", "SelectAll", "SQL", this.UserInfo);
        SuppliersReturnValue reloadRv = (SuppliersReturnValue)await (new SuppliersLayerB())
            .DoBusinessLogicAsync(reloadPv, DbEnum.IsolationLevelEnum.User);

        this.SaveEditingTable(reloadRv.Suppliers);
        model.Suppliers = reloadRv.Suppliers;
        model.Message = "更新しました（挿入 " + rv.InsertCount + " 件／更新 " + rv.UpdateCount + " 件／削除 " + rv.DeleteCount + " 件）。";
        return View("Index", model);
    }

    // --- 画面のセル値を DataTable へ読み戻す（RowIndex で対応） ---
    //   ★ 追加行は常に／既存行は「確定する行（targetRowIndex）」だけ／削除行は対象外。
    //     追加行は DB に戻す値が無く落とすと再バインドで空行に戻る＝毎回読み戻す。
    //     既存行は取得時値が dt に残る＝その行の[更新]が押されたときだけ読み戻せばよい（無駄 Modified も減る）。
    //   ※ 行[更新]を置かない（[削除]のみ）パターンは既存行を per-row 確定する手段が無い
    //     ＝BatchUpdate で全行読み戻す（この判定を外した read-all 版を別に用意する）。
    private void ReadRowsIntoTable(DataTable dt, SuppliersViewModel model, int targetRowIndex)
    {
        if (model.Rows == null) { return; }
        foreach (SupplierRowViewModel row in model.Rows)
        {
            if (row.RowIndex < 0 || dt.Rows.Count <= row.RowIndex) { continue; }
            DataRow dr = dt.Rows[row.RowIndex];
            if (dr.RowState == DataRowState.Deleted) { continue; }                        // 削除行は対象外
            if (dr.RowState != DataRowState.Added && row.RowIndex != targetRowIndex) { continue; }   // ★ 追加行は常に・既存行は対象行だけ

            SetIfChanged(dr, "CompanyName", row.CompanyName, notNull: true);   // ★ DB 側 NOT NULL 列
            SetIfChanged(dr, "ContactName", row.ContactName);
            SetIfChanged(dr, "City", row.City);
            SetIfChanged(dr, "Country", row.Country);
            SetIfChanged(dr, "Phone", row.Phone);
        }
    }

    // --- 値が変わっているときだけ代入（無駄 Modified を作らない） ---
    //   ★ 空欄は DB の NULL 可否で分ける：NOT NULL 列は "" のまま／NULL 可列は DBNull（DBNull を NOT NULL 列へ送ると INSERT で SqlException 515）。
    //     ExecSelectFill_DT は AllowDBNull を落とすので dt からは判定できない＝アプリが NOT NULL 列を知っておく。
    private static void SetIfChanged(DataRow dr, string col, string newValue, bool notNull = false)
    {
        string current = dr[col] == DBNull.Value ? "" : Convert.ToString(dr[col]);
        string edited = newValue ?? "";
        if (current == edited) { return; }
        dr[col] = (edited.Length == 0 && !notNull) ? (object)DBNull.Value : (object)edited;
    }
}
```

**ViewModel**（一覧は `DataTable`、ポストバックで戻る明細は `List<行VM>`。`RowIndex` は DataTable の行インデックス）：

```csharp
public class SuppliersViewModel : BaseViewModel
{
    public string Message { get; set; } = "";
    public DataTable Suppliers { get; set; }                 // 表示用
    public List<SupplierRowViewModel> Rows { get; set; } = new();   // 編集後の明細（モデルバインド）
}
public class SupplierRowViewModel
{
    public int RowIndex { get; set; }   // ★ Deleted 行は描画しないので表示連番でなくこの値で DataRow を引く
    public string CompanyName { get; set; }
    public string ContactName { get; set; }
    public string City { get; set; }
    public string Country { get; set; }
    public string Phone { get; set; }
}
```

## ビュー（`Views/SuppliersB/Index.cshtml`）

> **★ 表示列は「例を短く保つための省略」（6列）＝実装はこの列数を写さない。** マスタ保守の一覧は**対象テーブルの全列（＝自動生成Dao の `D2_Select` が返す列）を基準に**、表示/編集可否を決める（`SupplierID` など IDENTITY 主キーは表示のみ＝`readonly`）。仕様に列数の明記が無くても**全列表示が既定**（列を絞ると B層は書けるのに画面から入力できない列が静かに生まれる）。ViewModel・読み戻し（`ReadRowsIntoTable`/`SetIfChanged`）も対象列に合わせて増やす。

```cshtml
@using System
@using System.Data
@model SuppliersViewModel
@{ ViewBag.Title = "Suppliers 画面Ｂ"; }

<form id="formB" method="post" asp-controller="SuppliersB" asp-action="SelectAll">
    @Html.AntiForgeryToken()

    @* グリッド外の［行追加］（フッタではない）。formaction で送信先アクションを分岐 *@
    <button type="submit" class="btn btn-success btn-sm"
            formaction="@Url.Action("AddRow", "SuppliersB")">行追加</button>

    @* 一覧は table を自前生成し tr をループ *@
    <table class="table table-sm table-bordered">
        <thead><tr><th>SupplierID</th><th>CompanyName</th><th>ContactName</th><th>City</th><th>Country</th><th>Phone</th><th>操作</th></tr></thead>
        <tbody>
        @if (Model.Suppliers != null)
        {
            @* ★ ここはコード文脈なので for に @ を付けない（付けると Razor パースエラー） *@
            for (int i = 0; i < Model.Suppliers.Rows.Count; i++)
            {
                DataRow dr = Model.Suppliers.Rows[i];
                if (dr.RowState == DataRowState.Deleted) { continue; }   @* ★ Deleted は描画しない *@

                string id = (dr["SupplierID"] == DBNull.Value || Convert.ToInt32(dr["SupplierID"]) < 0) ? "(採番)" : dr["SupplierID"].ToString();
                int idx = i;   @* ★ 表示連番でなく DataTable の行インデックスを持ち回る *@
                <tr>
                    @* ★ 添字 idx は Deleted を飛ばすので 0 起点連番でない → Rows.Index が無いとコレクション バインドが空になり編集が静かに捨てられる（追加行が NULL→SqlException 515） *@
                    <input type="hidden" name="Rows.Index" value="@idx" />
                    <td>@id<input type="hidden" name="Rows[@idx].RowIndex" value="@idx" /></td>
                    <td><input class="form-control form-control-sm" name="Rows[@idx].CompanyName" value="@(dr["CompanyName"] == DBNull.Value ? "" : dr["CompanyName"].ToString())" /></td>
                    <td><input class="form-control form-control-sm" name="Rows[@idx].ContactName" value="@(dr["ContactName"] == DBNull.Value ? "" : dr["ContactName"].ToString())" /></td>
                    <td><input class="form-control form-control-sm" name="Rows[@idx].City" value="@(dr["City"] == DBNull.Value ? "" : dr["City"].ToString())" /></td>
                    <td><input class="form-control form-control-sm" name="Rows[@idx].Country" value="@(dr["Country"] == DBNull.Value ? "" : dr["Country"].ToString())" /></td>
                    <td><input class="form-control form-control-sm" name="Rows[@idx].Phone" value="@(dr["Phone"] == DBNull.Value ? "" : dr["Phone"].ToString())" /></td>
                    <td>
                        @* ★ [更新]＝この既存行を確定（追加行＋この行だけ読み戻す）。[削除]＝この行を Deleted *@
                        <button type="submit" class="btn btn-primary btn-sm"
                                formaction="@Url.Action("UpdateRow", "SuppliersB", new { rowIndex = idx })">更新</button>
                        <button type="submit" class="btn btn-danger btn-sm"
                                formaction="@Url.Action("DeleteRow", "SuppliersB", new { rowIndex = idx })">削除</button>
                    </td>
                </tr>
            }
        }
        </tbody>
    </table>
</form>

@* ★ フッタのメイン5ボタン：@section は <form> の外に描画されるので form="formB" で紐付ける *@
@section FooterButtonsSection{
    <button type="submit" form="formB" id="btnMain1" class="btn btn-primary"
            formaction="@Url.Action("SelectAll", "SuppliersB")">一覧取得</button>
    <button type="submit" form="formB" id="btnMain2" class="btn btn-warning"
            formaction="@Url.Action("BatchUpdate", "SuppliersB")"
            onclick="return window.confirm('更新します。よろしいですか？');">更新</button>
    <button type="button" id="btnMain3" class="btn btn-secondary"
            onclick="location.href='@Url.Action("Index", "SuppliersA")';">戻る</button>
    <button type="button" id="btnMain4" class="btn btn-secondary" disabled>－</button>
    <button type="button" id="btnMain5" class="btn btn-secondary" disabled>－</button>
}

@* 通知ダイアログは JavaScript（@Json.Serialize でエスケープ） *@
@section FooterScriptsSection{
    <script type="text/javascript">
        @if (!string.IsNullOrEmpty(Model.Message)) { <text>window.alert(@Json.Serialize(Model.Message));</text> }
    </script>
}
```

**画面Ａ（件数確認・画面遷移）** は同じ骨格で `[HttpPost] SelectCount` だけ持ち、`window.confirm` 不要・遷移は `location.href='@Url.Action("Index","SuppliersB")'`。

## 注意（このスニペットの前提）

- `@section FooterButtonsSection`／`FooterScriptsSection`／`HeaderScriptsSection` は共通レイアウト `_Layout.cshtml` の `@RenderSection(..., required: false)` に対応（`opentouryo-layer-p-mvc`）。名前はプロジェクトのレイアウトに合わせる。
- B層（`SuppliersLayerB`）の `UOC_SelectAll`/`UOC_BatchUpdate`（RowState 振り分け）と負値仮採番・楽観排他は `opentouryo-batch-update`／`opentouryo-layer-b`。
- **Session の直列化は Core だけの話**（net48 MVC は `DataTable` を Session に直接置ける）＝`opentouryo-batch-update`「DataSet/DataTable を JSON 化して持つ」。
