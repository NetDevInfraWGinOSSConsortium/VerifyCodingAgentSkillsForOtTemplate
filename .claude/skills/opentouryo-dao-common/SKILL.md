---
name: opentouryo-dao-common
description: "OpenTouryo の共通Dao（CmnDao）を使う。フレームワークが提供する CmnDao で SQL ファイル名か SQL 文を指定して単発実行する方法、SQLFileName / SQLText プロパティによる SQL 指定（SetSqlByFile2 の直呼びは実行時エラー）、SetParameter によるパラメタ設定（型・サイズ・ParameterDirection のオーバーロードと GetParameter・ストアドプロシージャも CmnDao で利用可）、ExecSelectScalar / ExecSelectFill_DT / ExecSelectFill_DS / ExecSelect_DR / ExecInsUpDel_NonQuery による実行、SetUserParameter の SQL インジェクション リスクを扱う。共通Dao / CmnDao / SQLFileName / SQLText / 単発のSQL実行 / ストアドプロシージャ を伴う作業のときに使う。個別Dao は opentouryo-dao-custom、自動生成Dao は opentouryo-dao-generated、系統の選び方は opentouryo-layer-d を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 共通Dao（CmnDao）

> 📋 **コピー元スニペット**：`references/snippets.md`（CmnDao 生成・SQLFileName/SQLText・実行。実装時はここから写す）。

## このスキルの適用範囲

フレームワークが提供する `CmnDao` の使い方。**自分で書くクラスではない。**

| 系統 | スキル |
| --- | --- |
| 個別Dao | `opentouryo-dao-custom` |
| **共通Dao（`CmnDao`）** | **このスキル** |
| 自動生成Dao | `opentouryo-dao-generated` |
| 3系統の選び方 | `opentouryo-layer-d` |

SQL 定義ファイルの中身は `opentouryo-query-definition`、B層からの呼び出しは
`opentouryo-layer-b` を参照。

## 使う場面

**SQL ファイル名か SQL 文を指定して単発で実行するとき。**

テーブル単位の CRUD で足りるなら自動生成Dao、業務固有のロジックを伴うなら個別Dao を使う
（`opentouryo-layer-d` 参照）。

## 書き方

`CmnDao`（`Touryo.Infrastructure.Business.Dao`）を、**B層から `this.GetDam()` を渡して生成**する。

```csharp
using Touryo.Infrastructure.Business.Dao;

CmnDao cmnDao = new CmnDao(this.GetDam());

cmnDao.SQLFileName = "ShipperSelect.sql";        // ファイルから
//cmnDao.SQLText   = "SELECT * FROM Shippers";   // SQL 文を直接

cmnDao.SetParameter("P1", testParameter.Shipper.ShipperID);

DataTable dt = new DataTable();
cmnDao.ExecSelectFill_DT(dt);
```

## SQL の指定はプロパティで行う

**個別Dao と作法が違う。** メソッドではなく**プロパティ**で指定する。

| プロパティ | 内容 |
| --- | --- |
| `SQLFileName` | SQL 定義ファイル名 |
| `SQLText` | SQL 文を直接 |

`SQLFileName` に `.sql` を渡せば静的パラメタライズドクエリ、`.xml` を渡せば動的パラメタライズド
クエリになる（`opentouryo-query-definition` 参照）。

`SQLFileName` と `SQLText` は**排他**。片方を設定すると、もう片方は内部でクリアされる。

### SetSqlByFile2() を直接呼んではならない

`CmnDao` は `MyBaseDao` を継承しているので `SetSqlByFile2()` / `SetSqlByCommand()` を
**呼べてしまうが、動かない。**

`CmnDao` の `ExecXxx()` は内部で `SQLFileName` / `SQLText` を読んで SQL を組み立てるため、
プロパティが空のままだと**実行時に `BusinessSystemException`（`CMN_DAO_ERROR`）**になる。
**コンパイルは通る。**

## 実行メソッド

| メソッド | 戻り値 | 用途 |
| --- | --- | --- |
| `ExecSelectScalar()` | `object` | 先頭1セルを取得（件数取得など） |
| `ExecSelectFill_DT(dt)` | `void` | `DataTable` に格納 |
| `ExecSelectFill_DS(ds)` | `void` | `DataSet` に格納 |
| `ExecSelect_DR()` | `IDataReader` | データリーダを取得。**使い終わったら `Close()` する** |
| `ExecInsUpDel_NonQuery()` | `int` | INSERT / UPDATE / DELETE。**更新件数を返す** |

`ExecInsUpDel_NonQuery()` の戻り値（更新件数）は捨てない。0 件は楽観排他の失敗などを意味する。

**大量データの SELECT（10万件超が目安）は `ExecSelectFill_DT`（`DataTable`）より `ExecSelect_DR`（`DataReader`）が速い**
（`DataTable` は全件をメモリ展開するため）。

**パラメタ操作**：同じ `CmnDao` を続けて別の SQL に使い回すときは `ClearParameters()` でパラメタを一括クリアする。

**コマンド タイムアウト**：`CommandTimeout` プロパティで個別に設定できるほか、**システム共通値は config の `FxSqlCommandTimeout`** で指定できる（`BaseDam.SetCommandTimeout`。タイムアウト全体の設計は `opentouryo-app-design` の `references/timeout-values.md`）。

## 型指定・ストアドも CmnDao で使える

**`CmnDao` は `SetParameter` のオーバーロード（型・サイズ・`ParameterDirection`）と
`GetParameter` を `public` で公開している。** 個別Dao と同じように、**ストアドプロシージャ**
（戻り値・出力パラメタ）も実行できる。

- 既定は基本形 `SetParameter(名前, 値)`。**型・サイズの指定は暗黙の型変換の性能劣化が
  顕在化してから**（先回りしない）
- 使い方の詳細（オーバーロードの一覧、ストアドの実装例、`CommandType.StoredProcedure` 指定・
  **複数結果セット**＝`ExecSelect_DR()`→`DataTable.Load()`/`NextResult()`、配列バインド）は `opentouryo-dao-custom` を参照
- **ただし呼び出し元が違う。** 個別Dao は Dao クラス自身なので `this.SetParameter(...)` /
  `this.GetParameter(...)`、**共通Dao は保持しているインスタンス**なので
  `cmnDao.SetParameter(...)` / `cmnDao.GetParameter(...)`。dao-custom の例の `this.` を
  `cmnDao.` に読み替える

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

cmnDao.SetUserParameter("COLUMN", " " + orderColumn + " ");
```

前後に空白を付けているのは、動的 SQL の `VAL` タグが前後の空白をつめることがあるため。

## Dao集約クラスでまとめる方針のプロジェクト

プロジェクトによっては、Dao の呼び出しを**Dao集約クラス**でまとめ、B層から直接呼ばせない
方針をとる。集約クラスは**系統を問わず使える**仕組みで、詳細は `opentouryo-layer-d` を参照。
既存コードが集約クラス経由になっているなら、それに合わせる。

## やってはいけないこと

- **`SetSqlByFile2()` / `SetSqlByCommand()` を直接呼ぶ** — コンパイルは通るが、実行時に
  `BusinessSystemException`（`CMN_DAO_ERROR`）になる。`SQLFileName` / `SQLText` を使う
- **`CmnDao` を継承して独自 Dao を作る** — 個別Dao は `MyBaseDao` を継承する
  （`opentouryo-dao-custom` 参照）
- **`new CmnDao()` に `Dam` を渡さない** — コンストラクタに `this.GetDam()` を渡す
- **`ExecInsUpDel_NonQuery()` の戻り値を捨てる** — 更新件数 0 は楽観排他の失敗を意味する
- **`SetUserParameter()` にユーザ入力を渡す** — 文字列置換のため SQL インジェクションになる
- **`ExecSelect_DR()` の `IDataReader` を閉じない** — コネクションが解放されない
