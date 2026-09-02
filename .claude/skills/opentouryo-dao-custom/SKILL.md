---
name: opentouryo-dao-custom
description: "OpenTouryo の個別Dao（業務固有のデータアクセスクラス）を実装する。MyBaseDao を継承した 個別Daoクラスの書き方、コンストラクタでの BaseDam の受け取り、SetSqlByFile2 / SetSqlByCommand による SQL の指定、SetParameter によるパラメタ設定（型・サイズ・ParameterDirection のオーバーロードを含む）、ExecSelectScalar / ExecSelectFill_DT / ExecSelectFill_DS / ExecSelect_DR / ExecInsUpDel_NonQuery による実行、GetParameter とストアドプロシージャ（戻り値・出力パラメタ）の実行、SetUserParameter の SQL インジェクション リスクを扱う。個別Dao / LayerD / 業務固有のデータアクセス / 複雑なSQL / ストアドプロシージャ を伴う作業のときに使う。共通Dao は opentouryo-dao-common、自動生成Dao は opentouryo-dao-generated、系統の選び方は opentouryo-layer-d を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 個別Dao

> 📋 **コピー元スニペット**：`references/snippets.md`（Dao メソッド・SetParameter オーバーロード・ストアド・ユーザ定義パラメタ。実装時はここから写す）。

## このスキルの適用範囲

**業務固有のデータアクセスクラス**（`MyBaseDao` を継承して手で書く Dao）の実装。

| 系統 | スキル |
| --- | --- |
| **個別Dao** | **このスキル** |
| 共通Dao（`CmnDao`） | `opentouryo-dao-common` |
| 自動生成Dao | `opentouryo-dao-generated` |
| 3系統の選び方 | `opentouryo-layer-d` |

SQL 定義ファイルの中身は `opentouryo-query-definition`、B層からの呼び出しは
`opentouryo-layer-b` を参照。

## 使う場面

**業務固有のデータアクセス。** 複雑な SQL、複数クエリの組み合わせ、業務的な単位でまとめたいとき。

テーブル単位の CRUD で足りるなら自動生成Dao、単発の SQL 実行だけなら共通Dao を使う
（`opentouryo-layer-d` 参照）。

## なぜ個別Dao を作るのか

**`BaseDao` の実行系メソッドはすべて `protected`。** 外部から呼べない。

```csharp
protected void ExecSelectFill_DT(DataTable dt)
protected int  ExecInsUpDel_NonQuery()
protected void SetParameter(string parameterName, object obj)
```

したがって `MyBaseDao` を継承し、**業務的な名前の `public` メソッドとして公開する**のが個別Dao。

## 実装場所

| 階層 | クラス | 修正 |
| --- | --- | --- |
| データアクセス親クラス1 | `BaseDao`（`Touryo.Infrastructure.Framework.Dao`） | **不可**（バイナリ提供） |
| データアクセス親クラス2 | `MyBaseDao`（`Touryo.Infrastructure.Business.Dao`） | **不可**（バイナリ提供） |
| データアクセスクラス | `MyBaseDao` を継承した Dao | **可**（ここに実装する） |

親クラス2 は `UOC_PreQuery` / `UOC_AfterQuery` に共通処理（性能測定・SQLトレースログ・例外振替）を
持つが、**バイナリで提供されるため利用側では変更できない。**

## 書き方

`MyBaseDao` を継承し、`SetSqlByFile2`（/`SetSqlByCommand`）→`SetParameter`→`Exec*` を包む `public` メソッドを書く。
**クラス骨格・メソッド例は `references/snippets.md`**。

- コンストラクタで `BaseDam` を受け取り `base(dam)` に渡す。**Dao 側で接続を張らない**
- メソッドは `public`。引数クラス・戻り値クラスを引数に取るのが慣例
- **個別Daoクラス名はプロジェクト依存。`LayerD` はサンプルの名前で、`LayerD` になるとは限らない。**
  個別Daoクラスは**機能ごとに複数**作られる（テーブルや業務単位など）。名称付与規則は
  プロジェクトごとに決まるので、既存コードの命名に合わせる

### SQL の指定

| メソッド | 内容 |
| --- | --- |
| `SetSqlByFile2(ファイル名)` | SQL 定義ファイルから。`MyBaseDao` が `public` で追加 |
| `SetSqlByCommand(SQL文)` | SQL 文を直接指定 |

`SetSqlByFile2` に `.sql` を渡せば静的パラメタライズドクエリ、`.xml` を渡せば動的
パラメタライズドクエリになる（`opentouryo-query-definition` 参照）。

## 実行メソッド

`this.` 経由で呼ぶ。

| メソッド | 戻り値 | 用途 |
| --- | --- | --- |
| `ExecSelectScalar()` | `object` | 先頭1セルを取得（件数取得など） |
| `ExecSelectFill_DT(dt)` | `void` | `DataTable` に格納 |
| `ExecSelectFill_DS(ds)` | `void` | `DataSet` に格納 |
| `ExecSelect_DR()` | `IDataReader` | データリーダを取得。**使い終わったら `Close()` する** |
| `ExecInsUpDel_NonQuery()` | `int` | INSERT / UPDATE / DELETE。**更新件数を返す** |

`ExecInsUpDel_NonQuery()` の戻り値（更新件数）は捨てない。0 件は楽観排他の失敗などを意味する。

**大量データの SELECT（10万件超が目安）は `ExecSelectFill_DT`（`DataTable`）より `ExecSelect_DR`（`DataReader`）が速い**
（`DataTable` は全件をメモリに展開するため）。自動生成 Dao のテンプレート修正でも対応可。

**繰り返し実行時のパラメタ・クリア**：個別Dao には `ClearParameters()` が**無い**（`CmnDao` 専用）。同じ Dao を
ループで何度も実行するなら、生コマンドで `this.GetDam().DamIDbCommand.Parameters.Clear();`（**DBMS 中立**）でクリアする
（DBMS 依存キャストなら `((DamSqlSvr)this.GetDam()).DamSqlCommand.Parameters.Clear();`）。系統別の対比は `opentouryo-layer-d`。

**★ Dam から生の ADO.NET コマンドを取り出して直接設定できる**（フレームワークがラップしない ADO.NET プロパティを触る一般手段）：
- **DBMS 中立**：`this.GetDam().DamIDbCommand`（`IDbCommand`。`BaseDam` abstract）。
- **DBMS 依存**：`((DamSqlSvr)this.GetDam()).DamSqlCommand`（`SqlCommand`）／`((DamManagedOdp)this.GetDam()).DamOracleCommand`（`OracleCommand`）等。
- 用途例：`Parameters.Clear()`（上記）／**ODP.NET の `FetchSize`**（サーバカーソルの取得数＝メモリ制御。`((DamManagedOdp)this.GetDam()).DamOracleCommand.FetchSize = …`。OpenTouryo はラップしないので生コマンドで）／配列バインド `ArrayBindCount`（下記）。**`CommandTimeout` は生設定でなく共通 config `FxSqlCommandTimeout`／`SetCommandTimeout()` を使う**（`opentouryo-dao-common`）。

## SetParameter のオーバーロード

**既定は基本形 `SetParameter(名前, 値)` を使う。** オーバーロードは `+dbTypeInfo`／`+size`／`+ParameterDirection`
の3段（一覧は `references/snippets.md`）。**指定する引数が増える**ので、むやみに使わない。

**型・サイズを明示するのは、暗黙の型変換による性能劣化が顕在化してから**
（先回りして指定しない。`opentouryo-query-definition` の該当節を参照）。
ただし `ParameterDirection`（下記ストアド）は出力を取るのに必要で、これは性能とは別。

**パラメタ名は接頭辞なし**（`"P1"`。`@` や `:` を付けない。接頭辞は DBMS ごとに
フレームワークが付ける）。**`dbTypeInfo` の型は DBMS 依存**：SQL Server は `SqlDbType.Int`、
Oracle は `OracleDbType.Int32` など（引数は `object` なのでどちらも渡せる）。

## ストアドプロシージャの実行

**入出力方向を `ParameterDirection` で指定し、戻り値・出力は `GetParameter` で取る**
（`SetSqlByCommand("プロシージャ名")`→入力 `SetParameter`→出力/戻り値を `Output`/`ReturnValue` で宣言→実行→
`GetParameter(名前)`。**コードは `references/snippets.md`**）。

`ParameterDirection` は `ReturnValue` / `Output` / `InputOutput` / `Input`。
**出力系は `GetParameter(名前)` で取得する**（実行前は `null`、実行後に値が入る）。

- **`CommandType.StoredProcedure` を指定する**：`SetSqlByFile2(名前, CommandType.StoredProcedure)`
  （SQL 文直接なら `SetSqlByCommand` の `CommandType` 引数）。既定は `Text` なので明示が要る。
- **複数結果セット**は `ExecSelect_DR()` の `IDataReader` を **`DataTable.Load()`／`dr.NextResult()`** で順に読む。

## 配列バインド（バルク・ODP.NET / HiRDB）

**大量 INSERT/UPDATE を1往復で流す**なら配列バインド（ODP.NET・HiRDB が対応）。`((DamManagedOdp)this.GetDam()).ArrayBindCount`
に件数を設定し、各 `SetParameter` へ**配列**を渡す（`OracleDbType` の明示が必須）。**非対応 DBMS はバッチクエリ作成支援で代替**
（`opentouryo-batch-update` の `SQLUtility`）。※実クラスは `DamManagedOdp`（FAQ の `DamOraOdp` 表記に注意）。

## SetUserParameter にユーザ入力を渡さない

`SetParameter` と `SetUserParameter` は**別物**。

| メソッド | 仕組み | ユーザ入力 |
| --- | --- | --- |
| `SetParameter(名前, 値)` | パラメタライズドクエリのパラメタ | **渡してよい** |
| `SetUserParameter(名前, 値)` | **SQL 文字列への置換** | **渡してはならない** |

`SetUserParameter` は動的 SQL 中のプレースホルダを文字列置換するもので、ORDER BY の列名など
パラメタにできない箇所に使う。**ユーザ入力をそのまま渡すと SQL インジェクションになる。**

正しい使い方は、入力値を**コード側で安全な値に変換してから**渡す。

```csharp
// 入力値そのものではなく、コード内で決めた列名に変換して渡す
string orderColumn = "";
if (testParameter.OrderColumn == "c1")      { orderColumn = "ShipperID"; }
else if (testParameter.OrderColumn == "c2") { orderColumn = "CompanyName"; }

this.SetUserParameter("COLUMN", " " + orderColumn + " ");
```

前後に空白を付けているのは、動的 SQL の `VAL` タグが前後の空白をつめることがあるため。

## Dao集約クラスでまとめる方針のプロジェクト

プロジェクトによっては、Dao の呼び出しを**Dao集約クラス**でまとめ、B層から直接呼ばせない
方針をとる。集約クラスは**系統を問わず使える**仕組みで、詳細は `opentouryo-layer-d` を参照。
既存コードが集約クラス経由になっているなら、それに合わせる。

## やってはいけないこと

- **Dao の中で接続を張る** — コンストラクタで `BaseDam` を受け取る。B層が `this.GetDam()` で渡す
- **Dao の中でコミット・ロールバックする** — B層フレームワークが行う（`opentouryo-layer-b` 参照）
- **`ExecInsUpDel_NonQuery()` の戻り値を捨てる** — 更新件数 0 は楽観排他の失敗を意味する
- **`SetUserParameter()` にユーザ入力を渡す** — 文字列置換のため SQL インジェクションになる
- **先回りして `SetParameter` で型・サイズを指定する** — 既定は基本形。型指定は暗黙の型変換の
  性能劣化が顕在化してから（`ParameterDirection` はストアドの出力取得に必要で、これは別）
- **`ExecSelect_DR()` の `IDataReader` を閉じない** — コネクションが解放されない
- **`BaseDao` / `MyBaseDao` を修正しようとする** — バイナリで提供される
