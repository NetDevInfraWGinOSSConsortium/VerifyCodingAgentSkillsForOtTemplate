# D層 コードスニペット（コピー元）

出典：UserGuide 開発者編 §3／纏め者編 §4、`Frameworks/Infrastructure/Business/Dao/MyBaseDao.cs`・`Public/Db/*`（実ソース）で裏取り。
**on-demand 参照**（SKILL 予算外）。クラス名・メソッド名は任意に変更可。

## データアクセスクラスの骨格

```csharp
#region using
using System;
// ～
using ProjectName.Infrastructure.Public.Util;
#endregion

/// <summary>LayerD の概要</summary>
public class LayerD : MyBaseDao   // 「データアクセス親クラス２」を継承する
{
    /// <summary>コンストラクタ（B層から渡される Dam を基底へ）</summary>
    public LayerD(BaseDam dam) : base(dam)
    {
        // 基本的に何も実装しない
    }
}
```

## データアクセスメソッドのテンプレート

シグネチャは自由。①SQL 設定 → ②パラメタ設定 → ③実行、の順。

```csharp
public void 〈任意のメソッド〉(TestParameterValue p, TestReturnValue r)
{
    // ① SQL を設定（いずれか）
    this.SetSqlByFile2("ファイル名");       // ファイル/埋め込みリソースから（推奨）
    // this.SetSqlByCommand("SQL文");       // 文字列リテラルで直接

    // ② パラメタを設定
    this.SetParameter("P1", p.ShipperID);   // パラメタライズドクエリのパラメタ（接頭辞なし）
    this.SetUserParameter("SEQUENCE", "DESC"); // ユーザ定義パラメタ（%% は付けない）※SQLi 注意

    // ③ 実行（いずれか。下表参照）
    object obj;
    obj = this.ExecInsUpDel_NonQuery();     // 追加/更新/削除 → 影響行数
    obj = this.ExecSelectScalar();          // SELECT → 先頭1セル
    obj = new DataTable();
    this.ExecSelectFill_DT((DataTable)obj); // SELECT → DataTable（引数で渡す）
    obj = new DataSet();
    this.ExecSelectFill_DS((DataSet)obj);   // SELECT → DataSet（引数で渡す）
    IDataReader idr = (IDataReader)this.ExecSelect_DR(); // SELECT → DataReader

    r.Obj = obj;   // 戻り値へ
}
```

## 実行メソッドと戻り値

| 区分 | メソッド | 戻り値 |
| --- | --- | --- |
| INSERT/UPDATE/DELETE | `ExecInsUpDel_NonQuery()` | 影響行数（int） |
| SELECT | `ExecSelectScalar()` | 先頭1セル（object） |
| SELECT | `ExecSelectFill_DT(DataTable)` | DataTable（引数に格納） |
| SELECT | `ExecSelectFill_DS(DataSet)` | DataSet（引数に格納） |
| SELECT | `ExecSelect_DR()` | IDataReader |

## SQL 設定 API の使い分け

```csharp
// 旧：フォルダを config から取り Path.Combine で連結
this.SetSqlByFile(
    Path.Combine(GetConfigParameter.GetConfigValue("sqlTextFilePath"), "ファイル名"));

// 推奨：SetSqlByFile2（内部で sqlTextFilePath 連結＋埋め込みリソース対応）
// 埋め込みリソースから読むなら次を有効化：
MyBaseDao.UseEmbeddedResource = true;
this.SetSqlByFile2("ファイル名");
```

SQL の書き方（静的 `.sql`／動的 `.xml`・パラメタ接頭辞の DBMS 差）は `opentouryo-query-definition`。
共通 Dao は `opentouryo-dao-common`、自動生成 Dao は `opentouryo-dao-generated`。
