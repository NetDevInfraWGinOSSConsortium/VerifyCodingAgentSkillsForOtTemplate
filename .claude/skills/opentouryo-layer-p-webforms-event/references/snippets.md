# P層 Web Forms（イベント処理）コードスニペット（コピー元）

出典：UserGuide 共通編 §2.2.4／開発者編 §4.1.3-4／纏め者編 §5.2-5.3、実ソースで裏取り。**on-demand 参照**（SKILL 予算外）。

## イベントハンドラの命名と実装位置

コントロール名＝`[接頭辞]任意文字列`（`btn`/`txt`/`ddl`… は app.config で定義）。UOC メソッド名は実装位置で変わる。

| コントロールの位置 ＼ 実装位置 | 画面コードクラス／親クラス2・3 | その要素自身（マスタ/UC）上 |
| --- | --- | --- |
| コンテンツページ上 | `UOC_（コントロール名）_（イベント名）` | — |
| マスタページ上 | `UOC_（マスタページファイル名）_（コントロール名）_（イベント名）` | `UOC_（コントロール名）_（イベント名）` |
| Web ユーザコントロール上 | `UOC_（UCのID）_（コントロール名）_（イベント名）` | `UOC_（コントロール名）_（イベント名）` |

## 基本シグネチャ（戻り値 = string）

```csharp
// URL を返すと画面遷移、空文字を返すとポストバック
protected string UOC_btnCntnt_Click(FxEventArgs fxEventArgs)
{
    // TODO:
    return "";
}
```

マスタページ上ボタン（マスタ名 = TestScreen.master、画面コードクラスに実装）：

```csharp
protected string UOC_TestScreen_btnMasterIdvdl_Click(FxEventArgs fxEventArgs)
{
    return "";
}
```

> UOC メソッドは共通ハンドラからレイトバインドで呼ばれるため **`public` か `protected`**（`private` 不可）。

## コントロール種別と既定イベント名

| 種別（接頭辞） | イベント名 |
| --- | --- |
| ボタン `btn`／リンク `lbn`／イメージ `ibn`／イメージマップ `imp` | `Click` |
| テキスト `txt` | `TextChanged` |
| ドロップダウン `ddl`／リスト `lbx`／ラジオリスト `rbl`／チェックリスト `cbl` | `SelectedIndexChanged` |
| ラジオ `rbn`（＋チェックボックス `cbx`） | `CheckedChanged` |
| リピータ `rpt` | `ItemCommand` |
| グリッド `gvw` | `RowCommand`/`SelectedIndexChanged`/`RowUpdating`/`RowDeleting`/`PageIndexChanging`/`Sorting` |
| リストビュー `lvw` | `OnItemCommand`/`SelectedIndexChanged`/`ItemUpdating`/`ItemDeleting`/`PagePropertiesChanged`/`Sorting` |

## FxEventArgs のプロパティ

> **`FxEventArgs` は `Touryo.Infrastructure.Framework.Presentation`**（`using` を1行足す＝無いと `CS0246`）。

| プロパティ | 内容 |
| --- | --- |
| `ButtonID` | イベント発生元のコントロール名 |
| `InnerButtonID` | リピータ等の内部コントロール |
| `MethodName` | レイトバインドしたハンドラ（メソッド）名 |
| `X` / `Y` | イメージボタンのクリック座標 |
| `PostBackValue` | イメージマップのホットスポット値／**一覧表示系コントロールではアイテムの index**（`int.Parse`→`Items[index]`） |

> B層呼び出しは `opentouryo-p-call-business`、接頭辞の自動結線拡張は `opentouryo-base2-customize`（addControlEvent）。

## 一覧表示系（GridView / ListView / Repeater）の実装

出典：`Aspx/testFxLayerP/table/test{GridView,ListView,Repeater}.aspx(.cs)`（実サンプル）で裏取り。**3コントロール共通の勘所**：

- **UOC で来るのは「…ing」系（キャンセル可能）＋ `RowCommand`/`ItemCommand`/`SelectedIndexChanged`**。第2引数は**そのイベント固有の EventArgs**。
- 対の「編集開始／キャンセル／…ed」は **UOC でなく標準ハンドラ `(object sender, …EventArgs e)`**（markup の `On…` 属性で結線）。
- **行内コントロールは `fxEventArgs.PostBackValue`（＝アイテムの index）** → `Items[index].FindControl("id")`。全行走査は `foreach (… Item …)`。
- **キー列は `DataKeyNames` に指定**し、`DataKeys[index].Value` で取る。★ **GridView は `e.RowIndex`／ListView は `e.ItemIndex`**。
- 動的コマンドボタンを使うページは `@Page` に **`EnableEventValidation="false"`**。カスタムコントロールは `<%@ Register Assembly="OpenTouryo.CustomControl" Namespace="Touryo.Infrastructure.CustomControl" TagPrefix="cc1" %>`。

| 操作（UOC 第2引数の型） | GridView | ListView |
| --- | --- | --- |
| 更新 | `RowUpdating`(`GridViewUpdateEventArgs`) | `ItemUpdating`(`ListViewUpdateEventArgs`・`object sender`) |
| 削除 | `RowDeleting`(`GridViewDeleteEventArgs`) | `ItemDeleting`(`ListViewDeleteEventArgs`・`object sender`) |
| コマンド | `RowCommand`（第2引数なし） | `OnItemCommand`(`ListViewCommandEventArgs`・`object sender`) |
| ページング | `PageIndexChanging`(`GridViewPageEventArgs`) | `PagePropertiesChanged`(`EventArgs`) |
| ソート | `Sorting`(`GridViewSortEventArgs`) | `Sorting`(`ListViewSortEventArgs`) |

対の標準ハンドラ（GridView）：`RowEditing`(`GridViewEditEventArgs`)／`RowCancelingEdit`(`GridViewCancelEditEventArgs`)／`SelectedIndexChanging`(`GridViewSelectEventArgs`)／`RowUpdated`／`RowDeleted`。
Repeater は `ItemCommand`（`FxEventArgs` のみ）＋行内コントロールの個別イベント。

### GridView

#### .aspx

```aspx
<%@ Page ... EnableEventValidation="false" %>  <%-- 動的コマンドボタンには必須 --%>
<asp:GridView ID="gvwGridView1" runat="server" AutoGenerateColumns="False" DataKeyNames="fileid">
  <Columns>
    <asp:CommandField ShowEditButton="True" />   <%-- 編集/更新/キャンセル --%>
    <asp:TemplateField><ItemTemplate>
      <asp:LinkButton ID="LinkButton1" runat="server" CommandName="Delete" Text="削除"
        OnClientClick="return confirm('削除してよろしいですか？');" />
    </ItemTemplate></asp:TemplateField>
  </Columns>
</asp:GridView>
```

#### .aspx.cs

```csharp
private void BindGridData()                         // バインド（Session の DataTable から）
{
    this.gvwGridView1.DataSource = Session["SampleData"];
    this.gvwGridView1.DataBind();
}

// 更新：編集行の各コントロールを FindControl で読み、キーは DataKeys（★ e.RowIndex）
protected string UOC_gvwGridView1_RowUpdating(FxEventArgs fxEventArgs, GridViewUpdateEventArgs e)
{
    GridViewRow gvRow = this.gvwGridView1.Rows[e.RowIndex];
    TextBox  txt = (TextBox)gvRow.FindControl("TextBox1");            // テンプレート列のコントロール
    CheckBox cbx = (CheckBox)gvRow.FindControl("cbxCheckBox3");
    int fileid = (int)this.gvwGridView1.DataKeys[e.RowIndex].Value;
    // … 値を反映（B層で UPDATE、または Session 保持の DataTable を書き換え）…
    this.gvwGridView1.EditIndex = -1; this.BindGridData();           // 編集解除→再バインド
    return "";
}

// 削除：キーは DataKeys（第2引数は GridViewDeleteEventArgs）
protected string UOC_gvwGridView1_RowDeleting(FxEventArgs fxEventArgs, GridViewDeleteEventArgs e)
{
    int fileid = (int)this.gvwGridView1.DataKeys[e.RowIndex].Value;
    // … B層で DELETE（→ opentouryo-p-call-business）…
    return string.Empty;
}

// コマンド：どのコマンドかは InnerButtonID（Select/Edit/Update/Cancel/Delete/Page/Sort/カスタム）
protected string UOC_gvwGridView1_RowCommand(FxEventArgs fxEventArgs) { string cmd = fxEventArgs.InnerButtonID; return ""; }

// 編集開始・キャンセルは標準ハンドラ（UOC でない）
protected void gvwGridView1_RowEditing(object sender, GridViewEditEventArgs e)
{ this.gvwGridView1.EditIndex = e.NewEditIndex; this.BindGridData(); }
```

### ListView

#### .aspx

`LayoutTemplate` の `itemPlaceholderContainer`/`itemPlaceholder` は**必須**。`OnItemEditing`/`OnItemCanceling` は標準ハンドラをマークアップ結線。`DataKeyNames` を付ける。

```aspx
<asp:ListView ID="lvwListView1" runat="server" DataKeyNames="fileid"
    OnItemEditing="lvwListView1_ItemEditing" OnItemCanceling="lvwListView1_ItemCanceling">
  <LayoutTemplate>
    <table runat="server">
      <tr runat="server" id="itemPlaceholderContainer">   <%-- ★ この2つのIDが必須 --%>
        <tr runat="server" id="itemPlaceholder"></tr>
      </tr>
    </table>
  </LayoutTemplate>
  <ItemTemplate>
    <tr>
      <td><asp:Label runat="server" Text='<%# Bind("filename") %>' /></td>
      <td><asp:LinkButton runat="server" CommandName="Edit"   Text="Edit" /></td>
      <td><asp:LinkButton runat="server" CommandName="Delete" Text="Delete" /></td>
      <%-- ソートは CommandName="Sort" ＋ CommandArgument に列名 --%>
      <th><asp:LinkButton runat="server" CommandName="Sort" CommandArgument="FileName" Text="File Name" /></th>
    </tr>
  </ItemTemplate>
  <EditItemTemplate>
    <tr>
      <td><asp:TextBox runat="server" Text='<%# Bind("filename") %>' /></td>
      <td><asp:LinkButton runat="server" CommandName="Update" Text="Update" />
          <asp:LinkButton runat="server" CommandName="Cancel" Text="Cancel" /></td>
    </tr>
  </EditItemTemplate>
</asp:ListView>
<asp:DataPager runat="server" PagedControlID="lvwListView1" PageSize="5">
  <Fields><asp:NumericPagerField /></Fields>
</asp:DataPager>
```

#### .aspx.cs

**★ GridView と違い `RowIndex` でなく `ItemIndex`**。編集開始/キャンセルは標準、`ItemUpdating`/`ItemDeleting`/`OnItemCommand` は `UOC_` でも `(object sender, …)`。

```csharp
private void BindListViewData()                     // バインド（Session の DataTable から）
{
    this.lvwListView1.DataSource = Session["SampleData"];
    this.lvwListView1.DataBind();
}

// 編集開始・キャンセルは標準ハンドラ（markup の OnItemEditing/OnItemCanceling で結線）
protected void lvwListView1_ItemEditing(object sender, ListViewEditEventArgs e)
{ this.lvwListView1.EditIndex = e.NewEditIndex; BindListViewData(); }
protected void lvwListView1_ItemCanceling(object sender, ListViewCancelEventArgs e)
{ this.lvwListView1.EditIndex = -1; BindListViewData(); }

// 更新：Items[e.ItemIndex].FindControl で編集セル、キーは DataKeys[e.ItemIndex]
protected void UOC_lvwListView1_ItemUpdating(object sender, ListViewUpdateEventArgs e)
{
    TextBox txt = (TextBox)this.lvwListView1.Items[e.ItemIndex].FindControl("txtFileName");
    int fileid = (int)this.lvwListView1.DataKeys[e.ItemIndex].Value;
    // … Session の DataTable を書き換え …
    this.lvwListView1.EditIndex = -1; BindListViewData();
}

// 削除：キーは DataKeys[e.ItemIndex]
protected string UOC_lvwListView1_ItemDeleting(object sender, ListViewDeleteEventArgs e)
{
    int fileid = (int)this.lvwListView1.DataKeys[e.ItemIndex].Value;
    // … DataTable の該当行を .Delete() …
    this.lvwListView1.EditIndex = -1; BindListViewData();
    return "";
}

// ItemCommand：CommandName/CommandArgument で判定（★ 対象外は null を返す＝遷移しない）
protected string UOC_lvwListView1_OnItemCommand(object sender, ListViewCommandEventArgs e)
{
    if (e.CommandName == "GetFiedID") { /* e.CommandArgument */ return ""; }
    return null;
}

// ソート・ページングは FxEventArgs 版
protected string UOC_lvwListView1_Sorting(FxEventArgs fxEventArgs, ListViewSortEventArgs e) { /* DataView でソート */ return ""; }
protected void   UOC_lvwListView1_PagePropertiesChanged(FxEventArgs fxEventArgs, EventArgs e) { BindListViewData(); }
```

### Repeater

#### .aspx

**★ 行のコマンドボタンの `CommandName="<%# Container.ItemIndex %>"` が `fxEventArgs.PostBackValue`（＝行 index）の正体。**

```aspx
<%@ Register Assembly="OpenTouryo.CustomControl" Namespace="Touryo.Infrastructure.CustomControl" TagPrefix="cc1" %>
<asp:Repeater ID="rptRepeater1" runat="server">
  <HeaderTemplate><table border="1"><tr><th>…</th><th>Button</th></tr></HeaderTemplate>
  <ItemTemplate>
    <tr>
      <td><%# DataBinder.Eval(Container.DataItem, "fileid") %></td>
      <td><asp:TextBox ID="TextBox1" runat="server" Text='<%# DataBinder.Eval(Container.DataItem, "textbox") %>' /></td>
      <td><asp:CheckBox ID="cbxCheckBox1" runat="server" AutoPostBack="true"
            Checked='<%# DataBinder.Eval(Container.DataItem, "checkbox") %>' /></td>
      <td><asp:Button ID="command1" runat="server" Text="コマンド" CommandName="<%# Container.ItemIndex %>" /></td>
    </tr>
  </ItemTemplate>
  <FooterTemplate></table></FooterTemplate>
</asp:Repeater>
```

#### .aspx.cs

DataSource は**公開プロパティ**にして markup の `<%# … %>` から参照。`HeaderInfo` 辞書もヘッダ描画用。行内コントロールは `PostBackValue`＝index。

```csharp
protected override void UOC_FormInit()              // 初回ロード：バインド
{
    this.HeaderInfo.Add("col0", "select"); // …      // markup の <% = this.HeaderInfo["col0"] %> 用
    this.DropDownListDataSource = CreateDataSource2(); // 行内 DropDownList のデータ源（公開プロパティ）
    DataTable dt = CreateDataSource1();
    this.RepeaterDataSource = dt;                    // 公開プロパティ（再描画で使う）
    this.rptRepeater1.DataSource = dt; this.rptRepeater1.DataBind();
}

protected override void UOC_FormInit_PostBack()     // 全行を読み戻す（例：選択ラジオの判定）
{
    int i = 0;
    foreach (RepeaterItem ri in this.rptRepeater1.Items)   // ★ 各行を走査
    {
        i++;
        WebCustomRadioButton rbn = (WebCustomRadioButton)ri.FindControl("rbnRadioButton");
        if (rbn != null && rbn.Checked) { /* i 行目が選択 */ }
    }
}

// 行内コントロールの個別イベント：PostBackValue が行 index
protected string UOC_cbxCheckBox1_CheckedChanged(FxEventArgs fxEventArgs)
{
    int idx = int.Parse(fxEventArgs.PostBackValue);
    CheckBox cbx = (CheckBox)this.rptRepeater1.Items[idx].FindControl("cbxCheckBox1");
    return "";
}

protected string UOC_rptRepeater1_ItemCommand(FxEventArgs fxEventArgs) { return ""; }  // コマンド名は InnerButtonID
```
