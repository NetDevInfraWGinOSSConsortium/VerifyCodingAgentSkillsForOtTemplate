# 個別Dao コードスニペット（コピー元）

出典：UserGuide 開発者編 §3.3・§3.4／各機能編（DPQuery ツール §2.3 型指定）、`Public/Db/BaseDam.cs`・`Business/Dao/MyBaseDao.cs`（実ソース）で裏取り。
**on-demand 参照**（SKILL 予算外）。

## 個別 Dao メソッド

```csharp
public void 〈メソッド〉(TestParameterValue p, TestReturnValue r)
{
    this.SetSqlByFile2("Select_Xxx");          // または SetSqlByCommand("SELECT ...")
    this.SetParameter("P1", p.ShipperID);      // 接頭辞なし（@ / : を付けない）
    r.Obj = this.ExecSelectScalar();
}
```

## パラメタ設定 API（SetParameter のオーバーロード）

`SetParameter("名前", 値)` のほか、型・サイズ・入出力方向を指定できる。**通常は値のみ**でよい
（型は自動推測：.NET 型 → 各データプロバイダの DbType）。

```csharp
this.SetParameter("P1", value);                                  // 値のみ（推奨）
this.SetParameter("P1", value, dbTypeInfo);                      // +DbType（型を明示）
this.SetParameter("P1", value, dbTypeInfo, size);               // +サイズ
this.SetParameter("P1", value, dbTypeInfo, ParameterDirection.Input); // +入出力方向
```

## ストアドプロシージャ（出力/戻り値パラメタ）

出力は `ParameterDirection.Output` / `ReturnValue` で宣言し、実行後に `GetParameter` で取得する。
**`CommandType.StoredProcedure` を明示する**（既定は `Text`）。

```csharp
// SQL 定義ファイルなら SetSqlByFile2(名前, CommandType.StoredProcedure)
this.SetSqlByCommand("〈ストアド名〉", CommandType.StoredProcedure);
this.SetParameter("IN1", inValue, dbTypeInfo, ParameterDirection.Input);
this.SetParameter("OUT1", null, dbTypeInfo, ParameterDirection.Output);
this.SetParameter("RET", null, dbTypeInfo, ParameterDirection.ReturnValue);

this.ExecInsUpDel_NonQuery();

object outVal = this.GetParameter("OUT1");
object retVal = this.GetParameter("RET");
```

### 複数結果セット

`ExecSelect_DR()` の `IDataReader` を `DataTable.Load()`／`NextResult()` で順に読む。

```csharp
IDataReader dr = this.ExecSelect_DR();
DataTable dt1 = new DataTable(); dt1.Load(dr);   // Load は次の結果セットまで読む
DataTable dt2 = new DataTable(); dt2.Load(dr);   // 2つ目
// もしくは dr.NextResult() で明示的に送る
dr.Close();
```

## 配列バインド（バルク・ODP.NET / HiRDB）

`ArrayBindCount` に件数を設定し、各パラメタへ**配列**を渡す（`OracleDbType` の明示が必須）。
実クラスは `DamManagedOdp`（FAQ の `DamOraOdp` 表記に注意）。

```csharp
DamManagedOdp dam = (DamManagedOdp)this.GetDam();
dam.ArrayBindCount = ids.Length;                        // バインドする件数
this.SetParameter("ID",   ids,   OracleDbType.Int32);  // 値は配列
this.SetParameter("NAME", names, OracleDbType.Varchar2);
this.SetSqlByCommand("INSERT INTO T (ID, NAME) VALUES (:ID, :NAME)");
this.ExecInsUpDel_NonQuery();                           // 1往復で全件
```

> 非対応 DBMS はバッチクエリ作成支援（`SQLUtility`）で代替＝`opentouryo-batch-update`。

## ユーザ定義パラメタ（動的に SQL 文字列を置換）

`%名前%`（静的 `.sql`）や `<VAL name="名前"/>`（動的 `.xml`）を置換する。**`%%` は付けない。**

```csharp
this.SetUserParameter("COLUMN", "CompanyName"); // ORDER BY %COLUMN% → CompanyName
this.SetUserParameter("SEQUENCE", "DESC");
```

> ★ `SetUserParameter` は SQL 文字列への直接置換＝**SQL インジェクション対策がされない**。
> ユーザ入力は必ず `SetParameter`（パラメタライズドクエリ）で渡す。置換用文字列は自前でチェックする。

## 直呼び防止・SQL 指定ミス

- `CmnDao` の `SetSqlByFile2()` を直呼びすると実行時 `BusinessSystemException`（`opentouryo-dao-common`）。
- SQL の書式（DBMS 別接頭辞・動的タグ）は `opentouryo-query-definition`。
