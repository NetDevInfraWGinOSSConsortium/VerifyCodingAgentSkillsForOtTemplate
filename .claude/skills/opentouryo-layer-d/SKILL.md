---
name: opentouryo-layer-d
description: "OpenTouryo の D層（データアクセス層）の全体像と、Dao 3系統（個別Dao / 共通Dao=CmnDao / D層自動生成ツールが生成する自動生成Dao）の使い分けを扱う。どの系統を使うべきかの判断基準、データアクセス親クラス1（BaseDao）・親クラス2（MyBaseDao）・データアクセスクラスの3階層、B層から this.GetDam() を渡して Dao を生成する共通の作法、Dao集約クラス（BaseConsolidateDao）による集約を扱う。D層 / データアクセス層 / Dao / DBアクセス / どのDaoを使うか / Dao集約クラス / BaseConsolidateDao を伴う作業のときに使う。実装の詳細は opentouryo-dao-custom（個別Dao）/ opentouryo-dao-common（共通Dao）/ opentouryo-dao-generated（自動生成Dao）を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# D層（データアクセス層）

> 📋 **コピー元スニペット**：`references/snippets.md`（データアクセスクラス骨格・SQL/パラメタ設定・実行5メソッド。実装時はここから写す）。

## このスキルの適用範囲

**D層の全体像と、Dao 3系統の使い分け。** 実装の詳細は系統ごとのスキルにある。

| 系統 | 実体 | 出所 | スキル |
| --- | --- | --- | --- |
| 個別Dao | `（機能名）: MyBaseDao`（**機能ごとに複数**。命名はプロジェクト依存） | 手書き | `opentouryo-dao-custom` |
| 共通Dao | `CmnDao : MyBaseDao` | フレームワーク提供。そのまま使う | `opentouryo-dao-common` |
| 自動生成Dao | `DaoXxx : MyBaseDao` | D層自動生成ツール（墨壺）が生成 | `opentouryo-dao-generated` |

**使う系統が決まっているなら、このスキルは読まずに該当スキルへ直行してよい。**

SQL 定義ファイルの中身は `opentouryo-query-definition`、B層からの呼び出しは
`opentouryo-layer-b`、例外は `opentouryo-exception` を参照。

## どの系統を使うか

1. **テーブル単位の CRUD で足りるか** → 足りるなら**自動生成Dao**。
   タイムスタンプ列があれば**楽観排他が組み込まれる**ので、更新系は特にこれを使う
2. **単発の SQL を実行するだけか** → **共通Dao**
3. **上記で表せないか**（複数クエリ、業務ロジックを伴う） → **個別Dao**

自動生成Dao は手で書き換えない。テーブル定義が変わったらツールで再生成する。

なお、プロジェクトによっては Dao を**Dao集約クラス**でまとめ、B層から直接呼ばせない方針をとる
（後述）。既存コードがその作りなら、それに合わせる。

## 実装場所

**3系統に共通。**

| 階層 | クラス | 修正 |
| --- | --- | --- |
| データアクセス親クラス1 | `BaseDao`（`Touryo.Infrastructure.Framework.Dao`） | **不可**（バイナリ提供） |
| データアクセス親クラス2 | `MyBaseDao`（`Touryo.Infrastructure.Business.Dao`） | **不可**（バイナリ提供） |
| データアクセスクラス | `MyBaseDao` を継承した Dao | **可**（ここに実装する） |

親クラス2 は `UOC_PreQuery` / `UOC_AfterQuery` に共通処理（性能測定・SQLトレースログ・例外振替）を
持つが、**バイナリで提供されるため利用側では変更できない。**

### なぜ個別Dao という系統があるのか

**`BaseDao` の実行系メソッドはすべて `protected`。** 外部から呼べない。

```csharp
protected void ExecSelectFill_DT(DataTable dt)
protected int  ExecInsUpDel_NonQuery()
```

したがって `MyBaseDao` を継承し、**業務的な名前の `public` メソッドとして公開する**のが個別Dao。
`CmnDao` は例外で、`public new` で親のメソッドを再公開している。

## 3系統に共通する作法

- **B層から `this.GetDam()` をコンストラクタに渡して生成する。** Dao 側で接続を張らない
- **Dao の中でコミット・ロールバックしない。** B層フレームワークが行う（`opentouryo-layer-b` 参照）
- **更新件数を捨てない。** 0 件は楽観排他の失敗などを意味する
- **ユーザ入力を `SetUserParameter` 系に渡さない。** 文字列置換なので SQL インジェクションになる

```csharp
// B層の業務コードクラスから
LayerD myDao     = new LayerD(this.GetDam());        // 個別Dao
CmnDao cmnDao    = new CmnDao(this.GetDam());        // 共通Dao
DaoShippers gen  = new DaoShippers(this.GetDam());   // 自動生成Dao
```

## 同じ Dao を繰り返し実行するときのパラメタ・クリア（系統別）

**ループや明細処理で同じ Dao インスタンスを何度も実行するなら、実行の間にパラメタをクリアする**
（前回のパラメタが残ると重複・誤りになる）。**方法は系統ごとに違う。**

| 系統 | クリア方法 |
| --- | --- |
| 個別Dao | **`BaseDao` に `ClearParameters()` は無い**。生コマンドで `this.GetDam().DamIDbCommand.Parameters.Clear();`（**DBMS 中立**）。DBMS 依存キャスト形は `((DamSqlSvr)this.GetDam()).DamSqlCommand.Parameters.Clear();`（Oracle は `((DamManagedOdp)…).DamOracleCommand` 等） |
| 共通Dao | `cmnDao.ClearParameters()`（`CmnDao` が `public` で公開） |
| 自動生成Dao | `ClearParametersFromHt()`（生成物のメソッド。`SetParameteToHt` で溜めた Hashtable をクリア） |

**★ クリア後に動的SQL（`.xml` の DPQ）が再処理されるかは系統で違う**（`BaseDam.PreExecQuery`／`init` で確認）：

- **個別Dao・共通Dao**：SQL を自分で1回だけセットするので、**初回の実行で動的SQL→静的SQLに変換され（以後 SPQ 扱い・XML は破棄）**、
  次からのクリア＋再セット＋実行は**その静的SQLに値を差し替えるだけ＝動的SQLは再処理されない**（速い）。ただし**動的構造は初回で固定**——
  行ごとに `IF` タグの有効/無効を変えたいなら `SetSqlByFile2` を都度呼び直す。
- **自動生成Dao**：生成メソッドが**毎回 `SetSqlByFile2` を呼ぶため、動的SQLを毎回再処理**する（行ごとに列を変えられる代わりに遅い）。
  繰り返しの組み立てコストは「**クエリ・キャッシュ**」で下げられる（コンストラクタに固定のキャッシュ ID を渡す。`opentouryo-dao-generated`）。

## 複数行の INSERT / UPDATE / DELETE を混在させるときの注意

同じ処理で追加・更新・削除が混ざるとき（明細一括更新に限らず）に共通する落とし穴。

- **IDENTITY（自動採番）主キーは、INSERT しても採番値がメモリ側（引数の `DataTable`／オブジェクト）に戻らない。**
  挿入した行を**取り直さずに**続けて UPDATE/DELETE すると、WHERE の主キーが `NULL`（`… WHERE PK IS NULL`）になり
  **0 件＝排他エラー**になる。→ 続けて操作する前に**採番後の行を再 SELECT** する。
- **実行順は DELETE → INSERT にする（INSERT → DELETE は不可）。** 主キー／一意キーを使い回すと、先に INSERT すると
  まだ消えていない旧行とキーが衝突する。同一処理内に削除と追加があるなら**削除を先**に流す。

明細を `DataRow` の `RowState` で一括反映するのは `opentouryo-batch-update`。

### 親子（ヘッダ・明細）を1つの UOC＝1トランザクションで扱う

親（ヘッダ）と子（明細）を1トランザクションで CUD するとき（詳細画面に明細グリッドを足す等。画面側は `opentouryo-mvc-crud-screens`／`opentouryo-webforms-crud-screens`／`opentouryo-winforms-crud-screens`）：

- **削除は子 → 親の順**。子に親への FK があると**親を先に消すと参照整合性違反**（SQL Server `Msg 547`）で落ちる。これは**実行するまで分からない**（ビルドも静的検証も通る）。∴ **先に子を全件削除してから親を `S4`/`D4_Delete`**。子の**親キーによる全件削除は「複合主キーの親キーだけ設定」**でできる＝`opentouryo-dao-generated`。
- **採番したばかりの親キーを子に差し込む**なら `@@IDENTITY` で取る（上記のとおり自動生成Dao の INSERT は採番値をメモリに戻さない）。親 `D1_Insert` の直後に **`SELECT CAST(@@IDENTITY AS int)` を共通Dao（`CmnDao`）で実行**して拾い、子の FK 列に入れて INSERT する。**`SCOPE_IDENTITY()` は使えない**——自動生成Dao の INSERT と採番取得は**別コマンド＝別スコープ**なので `NULL` になる。`@@IDENTITY` は**同一コネクション**で有効で、**B層の1トランザクション＝同一接続**なので成立する（対象表にトリガが無ければ、トリガ由来の採番を拾う `@@IDENTITY` の弱点も該当しない）。

## 楽観排他方式（更新・削除の競合検出）

**取得してから更新／削除するまでの間に、他者が先に同じ行を変更していないかを検出する。** 判定は方式を問わず共通で
**「更新／削除の件数が 0 か」**——0 なら他者が先に変更済み＝**やり直し可能な業務例外**にする（`opentouryo-exception`）。
更新系メソッドの戻り値（件数）を**必ず判定する**（握りつぶさない）。検出のしかたは、テーブルに**タイムスタンプ列があるか**で変わる。

- **タイムスタンプ列がある場合（推奨）**：自動生成Dao の更新／削除に**楽観排他が自動で組み込まれる**——UPDATE は
  タイムスタンプ列を新値に更新し、WHERE に取得時のタイムスタンプを含める。他者が先に更新していれば値が一致せず件数0になる。
  開発者は取得時の**主キー＋タイムスタンプ**を渡し、**件数0チェックだけ**行えばよい（メソッドは `opentouryo-dao-generated`）。
- **タイムスタンプ列が無い場合**：自動チェックが無いので、`D3_Update`／`D4_Delete`（動的 WHERE）に**取得時の全列の値**
  （`DataRowVersion.Original` 等）を入れて**全行一致**で判定する（`NULL` 列は `null` を渡して `IS NULL` に落とす）。他者が
  1 列でも変えていれば WHERE が一致せず件数0になる。列が多いほど WHERE が長くなるので、可能なら**タイムスタンプ列を足す**方が簡潔。
  - **★ どの列を判定に含めるかは「その列の `@パラメタ` を設定するか」で決まる**（生成 XML は各列 `<IF>AND [列] = @列<ELSE>AND [列] IS NULL</ELSE></IF>`。DPQ の挙動＝`opentouryo-query-definition`）：
    **値を設定＝`= @列`／`null` を設定＝`IS NULL`／設定しない＝その列は WHERE から消える（判定対象外）**。
    → 変更を検出したい列だけ取得時の値（`Original`）を設定すればよい。**「設定しない」を「`null` 設定」と混同しない**（後者は `IS NULL` が残る）。
  - **★ `ntext`／`text`／`image`（大きなオブジェクト型）を含むテーブル**：SQL Server はこれらを `=` で比較できず、値を設定すると**実行時エラー**になる。
    → **その列の `@パラメタ` を設定しないだけでよい**（未設定＝ブロック削除で WHERE から消える。**生成 XML の編集は不要**）。その列の変更は検出できなくなる。
    全列を厳密に見たいなら**タイムスタンプ列を足す**か、主キーのみ（`S3`/`S4`）＋件数0チェックに割り切る。

## Dao集約クラス

**複数の Dao の呼び出しを集約するレイヤ。系統を問わず使える。** 採用するかはプロジェクト基準による。

### 何のためにあるか

Dao を B層から直接使うと、**B層が DB スキーマや SQL の存在を知ることになる**。
特に自動生成Dao はテーブル単位なので、テーブル構成が変わるたびに B層が影響を受ける。

集約クラスを間に挟むと、B層は業務的な単位のメソッドを呼ぶだけになり、
どのテーブルをどう更新するかは集約クラスに閉じる。

```
【集約クラスなし】 B層 ──→ DaoShippers, DaoOrders, CmnDao …（B層がスキーマを知る）
【集約クラスあり】 B層 ──→ 集約クラス ──→ DaoShippers, DaoOrders, CmnDao …
```

### 書き方

`BaseConsolidateDao`（`Touryo.Infrastructure.Business.Dao`）を継承する。
**このクラスは `BaseDao` を継承していない。** Dao 自身ではなく、`Dam` を保持して
配るだけの `abstract` クラス。保持した `Dam` は `protected BaseDam Dam` で取得する。

**Dao の種類を限定しない。** 共通Dao も自動生成Dao も個別Dao も、同じように `this.Dam` を渡して
生成できる。

```csharp
public class ShippingConsolidateDao : BaseConsolidateDao
{
    public ShippingConsolidateDao(BaseDam dam) : base(dam) { }

    /// <summary>業務的な単位のメソッドを公開する</summary>
    public void RegisterShipping(TestParameterValue param)
    {
        // 保持している Dam を各 Dao へ配る（系統は問わない）
        DaoShippers daoShippers = new DaoShippers(this.Dam);   // 自動生成Dao
        CmnDao      cmnDao      = new CmnDao(this.Dam);        // 共通Dao

        // 複数テーブルへのアクセスをここに閉じ込める
        daoShippers.PK_ShipperID = param.Shipper.ShipperID;
        daoShippers.Set_CompanyName_forUPD = param.Shipper.CompanyName;
        daoShippers.S3_Update();

        cmnDao.SQLFileName = "OrderUpdate.sql";
        cmnDao.SetParameter("P1", param.Shipper.ShipperID);
        cmnDao.ExecInsUpDel_NonQuery();
    }
}
```

B層からは他の Dao と同じく `this.GetDam()` を渡して生成する。

```csharp
ShippingConsolidateDao dao = new ShippingConsolidateDao(this.GetDam());
dao.RegisterShipping(testParameter);
```

<!--
  補足: BaseConsolidateDao は「Dao集約クラスのベースクラスの例」というコメントのみで、
  Samples / Samples4NetCore に利用実例が無い。上記コード例は、クラス定義（Dam を保持する
  abstract クラス。Dao の種類を限定していない）と設計意図から起こしたもの。
  実プロジェクトの実装例が手に入ったら、そちらに差し替えるのが望ましい。
-->

### 採用しているプロジェクトでの注意

集約クラスを使う方針のプロジェクトでは、**B層から Dao を直接呼ばない**。
既存コードが集約クラス経由になっているなら、それに合わせる。

## やってはいけないこと

- **Dao の中で接続を張る** — コンストラクタで `BaseDam` を受け取る
- **Dao の中でコミット・ロールバックする** — B層フレームワークが行う
- **`BaseDao` / `MyBaseDao` を修正しようとする** — バイナリで提供される
- **自動生成Dao を手で書き換える** — 再生成で消える
- **集約クラスを使う方針のプロジェクトで、B層から Dao を直接呼ぶ** — 既存コードに合わせる
- **集約クラスが自動生成Dao 専用だと考える** — `BaseConsolidateDao` は `Dam` を保持する
  だけで、Dao の種類を限定しない。共通Dao も個別Dao も集約できる
