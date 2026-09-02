# 親クラス2 カスタマイズ コードスニペット（コピー元）

出典：UserGuide 纏め者編 §3-§7、`Frameworks/Infrastructure/Business/**`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。
親クラス2 は override して共通処理を注入する。**アプリ側は触らない**（`opentouryo-project-policy`）。

## overlay ドリフト確認（`develop` を引き直したら overlay 適用前に diff）

**overlay はファイル丸ごと差し替え**なので、`develop` を引き直すと**上流が同じファイルに入れた変更を黙って巻き戻す**（ビルドは通るので露見しない）。
やむを得ず moving ref で運用するなら、**引き直すたびに pristine と diff して「意図した変更しか無い」ことを確かめる**：

```powershell
# 新しい ZIP から overlay 対象ファイルだけ取り出し、overlay 版と1ファイルずつ diff する
foreach ($f in (Get-ChildItem base2-overlay -Recurse -File -Filter *.cs)) {
    $rel      = $f.FullName.Substring((Resolve-Path base2-overlay).Path.Length + 1)
    $pristine = Join-Path "<extract>\root\programs\CS" $rel   # 新しい develop の素のファイル
    "==== $rel ===="
    Compare-Object (Get-Content $pristine) (Get-Content $f.FullName)   # 差分＝overlay で入れた変更のはず
}
```

**意図した変更（OLE/ODBC 分岐削除・master ページ ハンドラ削除等）以外の差分が出たら、上流の変更を巻き戻している**＝overlay を新 pristine に対して作り直す。
実測（2026-08-19 の develop 引き直し）では overlay 5ファイルとも意図した差分のみ＝影響なしだった。

**★ ヘッダの「更新履歴」行を機械挿入するときの位置**：基盤ソースはファイルヘッダに更新履歴表を持つ＝挿入は **Apache License region の直後ではなく、最後の `//*  YYYY/MM/DD` 行の直後**（履歴表の末尾）に入れる（`opentouryo-comment-convention`）。

## DBMS を足す/減らすときの「面」＝チェックリストの根拠

SKILL の「面①〜⑥」の詳細。実測（develop）で裏取り済み。

- **①ロジック分岐は4クラス全部（`MyFcBaseLogic`/`MyBaseLogic`〔`[Obsolete]`〕/`MyFcBaseLogic2CS`/`MyBaseLogic2CS`）。置換後は grep で残存確認。**
  upstream は同じ分岐でも**ガードの `#if` が4クラスで不揃い**（`#if NETCOREAPP` と `#if NETCOREAPP2_0` が混在。`net10` は
  `NETCOREAPP2_0` 未定義＝`#else` 側が有効）。片方の `#if` を目印にした機械置換は**当たらないクラスを無言で残す**
  （ビルドは通るので気付けない）＝置換後に4クラスを grep して残存ゼロを確認する。
  **★ どの分岐がどのランタイムか（実ソース `MyFcBaseLogic.cs`）＝`OLE` は net48 のみ〔`#if NETCOREAPP` の `#else`〕・`NPS` は core のみ〔`#if NET48` の `#else`〕・`SQL`/`ODB`/`ODP`/`MCN` は両方（ガード無し）・`ORA`/`DB2`/`HIR` はコメントアウト＝分岐無しで `else`（SQL）へ。**「`OLE`/`ODB` はまとめて net48」と決め打たない（`ODB` は core でも有効）。
- **②③は「Dam が別アセンブリの DBMS」だけ。** ②csproj の `<Reference>`+`HintPath`／③ベンダ Dam DLL を `Build_*` から外す、は
  Dam が**別 DLL**（`OpenTouryo.DamManagedOdp`/`.DamMySQL`/`.DamPstGrS`）のときだけ該当。
  **`DamOLEDB`/`DamODBC` は `Public`（親クラス1）に同居**（`Public\Db\Dam{OLEDB,ODBC}.cs`）＝**外せない・外してはいけない**
  （外すには親クラス1 を触る＝規約違反）。→「Dam がどのアセンブリに居るか」で②③の要否が決まる。
- **④ config の `ConnectionString_<code>`＝親クラス2 を参照して B層を動かす側すべて。**
  対象は**アプリの config だけでなく、WS ホスト（`ASPNETWebService`/`WCFService`）の `<connectionStrings>`（`name="ConnectionString_<code>"`）も含む**
  （実測：両ホストに `ConnectionString_OLE`/`_ODBC`。3層構成で「アプリ側だけ」と書くとホストを取りこぼす）。
  一方 **開発支援ツール `OT_Tools\DaoGen_Tool`（墨壺）は対象外**：親クラス2 を経由せず自前で `OdbcConnection`/`OleDbConnection` を開く（`Form1.cs`）
  ＝キーを消すとツールが壊れる＝**残すのが正**。
  **★ ①のランタイム差が config に出る**：`OLE` は net48 の config だけ・`ODB`/`ODP` は両方＝**core の config は `_ODBC` はあるが `_OLE` は無い**（実測：`2_MVC_Sample_Core/appsettings.json`）。削除対象がランタイムで非対称＝core に `_OLE` が無いのを「消し漏れ」や「未対応」と誤認しない。
- **④' サンプル UI の DAP 選択肢（第5の面）。** 分岐を消しても、サンプルのドロップダウンに DBMS コードが残ると、
  選んだとき `UOC_ConnectionOpen` の**最後の `else` が SQL Server に黙ってフォールバック**する（エラーにならず別 DBMS で動く＝
  最も気付きにくい壊れ方）。UI 側（`Form1.cs`/`CrudViweModel.cs` 等）の選択肢も揃える。
  **傍証**：MVC core の picker は `DB2`/`HIR` を出すのに親クラス2 にその分岐は無い（コメントアウト）＝上流の時点で同じ不整合。
  → 消す DBMS の選択肢を削るだけでなく、**分岐の無い選択肢（`else` フォールバック予備軍）が他に無いか**も突き合わせる（`DB2`/`HIR` は今回範囲外なら残置と記録）。
- **⑥ DBMS 別の SQL 資産・手順書。** `resource\Sql\ole_odbc\`（ODBC/OLEDB 用の `.sql`/`.xml` 一式＋`Configuration steps ODBC.txt`）のような
  **DBMS 別リソース**は、分岐を消しても残る＝**どこからも参照されないまま「静かに腐る」**（ビルドにも実行にも出ない）。参照の有無を確認して残す/消すを判断する（未参照でも実害は無いが、面の一覧に載せて見落とさない）。
- **反映確認は「バイナリ走査」が正道（リフレクションは使えないことがある）。** PS7（.NET 10）から **net48 の DLL を `Assembly.LoadFrom`→`GetType()` すると `Could not load type 'System.Web.UI.Page' …` で型自体が取れない**（`System.Web` 派生のため。実測）＝リフレクションで確認できない。→ バイナリ（メタデータ）を直接走査する。
  **エンコードに注意**：**型名・メソッド名（メタデータ）は UTF-8、`ldstr` の文字列リテラル（`ConnectionString_<code>` 等）は UTF-16（`#US` ヒープ）**。ASCII/UTF-8 一律で走査すると接続キー等が全 False になり誤判定する＝型名は UTF-8、リテラルは UTF-16 で見る。

## B層：MyFcBaseLogic の UOC 群

```csharp
public abstract class MyFcBaseLogic : BaseLogic
{
    // DB 初期化（DAM 生成・接続・分離レベル・Tx 開始）＝実装必須
    protected override void UOC_ConnectionOpen(BaseParameterValue pv, DbEnum.IsolationLevelEnum iso)
    {
        // actionType の先頭[0]で DBMS を選ぶ（ランタイム別＝OLE は net48 のみ・NPS は core のみ・SQL/ODB/ODP/MCN は両方。分岐無しは else で SQL）
        BaseDam dam;
        switch (pv.ActionType.Split('%')[0])
        {
            case "SQL": dam = new DamSqlSvr(); break;
            case "ODP": dam = new DamManagedOdp(); break;   // 使わない DBMS は csproj 参照ごと外す
            default:    dam = new DamSqlSvr(); break;
        }
        dam.ConnectionOpen(GetConfigParameter.GetConnectionString("ConnectionString_SQL"));
        if (iso == DbEnum.IsolationLevelEnum.User)
            iso = DbEnum.IsolationLevelEnum.DefaultTransaction; // User の振替先（プロジェクト依存）
        dam.BeginTransaction(iso);
        this.SetDam(dam);
    }

    // 前後処理・Tx 後処理（アクセスログ・性能測定など）
    protected override void UOC_PreAction(BaseParameterValue pv) { }
    protected override void UOC_AfterAction(BaseParameterValue pv, BaseReturnValue rv) { }
    protected override void UOC_AfterTransaction(BaseParameterValue pv, BaseReturnValue rv) { }

    // 業務処理の自動振り分け（methodName → UOC_〈methodName〉 をレイトバインド）
    protected override void UOC_DoAction(BaseParameterValue pv, ref BaseReturnValue rv)
    {
        string methodName = "UOC_" + pv.MethodName;
        try { Latebind.InvokeMethod(this, methodName, new object[] { pv }); }
        catch (System.Reflection.TargetInvocationException ex)
        {
            this.OriginalStackTrace = ex.InnerException.StackTrace;
            throw ex.InnerException;
        }
        finally { rv = this.ReturnValue; }  // レイトバインドは戻り値を取りこぼすためメンバで戻す
    }

    // 例外処理（3オーバーロード）。業務例外=リスローしない／システム・一般=リスロー（一般は振替可）
    protected override void UOC_ABEND(BaseParameterValue pv, BaseReturnValue rv, BusinessApplicationException baEx) { }
    protected override void UOC_ABEND(BaseParameterValue pv, BaseReturnValue rv, BusinessSystemException bsEx) { }
    protected override void UOC_ABEND(BaseParameterValue pv, ref BaseReturnValue rv, Exception ex)
    {
        // 一般例外→業務例外に振替（ErrorFlag）or システム例外に振替（throw）or そのまま throw
        rv.ErrorFlag = true; rv.ErrorMessageID = "..."; rv.ErrorMessage = "..."; rv.ErrorInfo = "-";
    }
}
```

> ★ 2CS は別クラス `MyFcBaseLogic2CS : BaseLogic2CS`（同名 UOC を持つ）＋**別 sln ビルド**。DBMS 分岐等は
> deprecated 双子 `MyBaseLogic`/`MyBaseLogic2CS` にも重複＝DLL から消すなら4クラス全部直す（SKILL 本文）。

## D層：MyBaseDao の UOC

```csharp
public abstract class MyBaseDao : BaseDao
{
    protected override void UOC_PreQuery() { }                       // SQL 実行前
    protected override void UOC_AfterQuery(string sql) { }           // 正常時（SQLトレース等）
    protected override void UOC_AfterQuery(string sql, Exception ex) { } // 異常時（エラーログ・振替）
}
```

## P層：MyBaseController（Web Forms）の UOC

```csharp
public abstract class MyBaseController : BaseController
{
    protected override void UOC_CMNFormInit() { /* HTML タイトルは this.Page.Title に設定 */ } // 初回（認証・権限・閉塞・タイトル・ログ）
    protected override void UOC_CMNFormInit_PostBack() { }    // ポストバック
    protected override void UOC_PreAction(FxEventArgs e) { }
    protected override void UOC_AfterAction(FxEventArgs e) { }
    protected override void UOC_Screen_Transition(string url) // 画面遷移方式を統一
    {
        if (url == "") return;
        if (MyBaseController.TransitionMethod == FxLiteral.OFF) this.FxTransfer(url);
        else this.ScreenTransition(url);
    }
    // 例外3オーバーロード（業務=表示、システム/一般=共通エラー画面 TransferErrorScreen）
    protected override void UOC_ABEND(BusinessApplicationException baEx, FxEventArgs e) { }
    protected override void UOC_ABEND(BusinessSystemException bsEx, FxEventArgs e) { }
    protected override void UOC_ABEND(Exception ex, FxEventArgs e) { }
}
```

WinForms は `MyBaseControllerWin`（例外は `RcFxEventArgs` 付き3オーバーロード）、Web API は
`MyBaseAsyncApiController`（±Core）、非同期は `MyBaseAsyncFunc`（`UOC_Pre/After/ABEND/Finally`）。

## P層イベント対応コントロールの追加（addControlEvent）

```csharp
// 「ページ ロード処理」から呼ぶ。集約イベントハンドラを接頭辞に結線する
private void addControlEvent()
{
    // 最新版は GetCtrlAndSetClickEventHandler2（Dictionary<接頭辞, ハンドラ>）
    Dictionary<string, object> map = new Dictionary<string, object>();
    string prefix = GetConfigParameter.GetConfigValue(MyLiteral.PREFIX_OF_CHECK_BOX);
    if (!string.IsNullOrEmpty(prefix))
        map.Add(prefix, new System.EventHandler(this.Check_CheckedChanged));
    MyCmnFunction.GetCtrlAndSetClickEventHandler2(this, map, this.ControlHt);
}

// コントロール種別ごとの集約イベントハンドラ（既定にない種別を足すとき）
protected void Check_CheckedChanged(object sender, System.EventArgs e)
{
    FxEventArgs fx = new FxEventArgs(((Control)sender).ID, 0, 0, "",
        this.GetMethodName(((Control)sender).ID, FxLiteral.UOC_METHOD_FOOTER_CHECKED_CHANGED));
    this.CMN_Event_Handler(fx);   // 以降はフレームワークが処理
}
```

## 例外メッセージ定数クラス

```csharp
namespace Touryo.Infrastructure.Business.Exceptions
{
    public class MyBusinessApplicationExceptionMessage
    {
        public static readonly string[] SAMPLE_ERROR =
            new string[] { "MessageID_SampleError", "Message_SampleError" };
    }
}
```

## 引数/戻り値の親クラス2（B/D層を跨ぐ持ち回り）

```csharp
[Serializable()]  // ★ WS 転送のため外さない
public class MyParameterValue : BaseParameterValue
{
    private MyUserInfo _user;
    public MyParameterValue(string screenId, string controlId, string methodName, string actionType, MyUserInfo user)
        : base(screenId, controlId, methodName, actionType) { this._user = user; }
    public MyUserInfo User { get { return this._user; } }
}
[Serializable()]
public class MyReturnValue : BaseReturnValue { /* 共通の戻り値項目を足す */ }
```

> ビルド（`3_Build_Business_*`＋2CS は `BusinessRichClient_*.sln` を `/t:build`）・オーバーレイ運用は SKILL 本文。
