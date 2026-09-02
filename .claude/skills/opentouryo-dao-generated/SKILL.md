---
name: opentouryo-dao-generated
description: "OpenTouryo の自動生成Dao（D層自動生成ツール「墨壺」がテーブル単位で生成する Dao）を使う。S1_Insert / D1_Insert / S2_Select / D2_Select / S3_Update / D3_Update / S4_Delete / D4_Delete / D5_SelCnt のメソッド命名体系（S=主キー固定 / D=任意条件）、PK_列名 / 列名 / Set_列名_forUPD / 列名_Like のプロパティ命名体系、タイムスタンプによる楽観排他と更新件数0件チェックを扱う。自動生成Dao / 墨壺 / DaoShippers / テーブル単位のCRUD / 楽観排他 / タイムスタンプ を伴う作業のときに使う。個別Dao は opentouryo-dao-custom、共通Dao は opentouryo-dao-common、系統の選び方は opentouryo-layer-d を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 自動生成Dao

> 📋 **コピー元スニペット**：`references/snippets.md`（Dao生成・CRUD呼出・S/Dメソッド・PK_/Set_forUPD プロパティ・楽観排他。実装時はここから写す）。

## このスキルの適用範囲

**D層自動生成ツール（墨壺）がテーブル単位で生成する Dao** の使い方。

| 系統 | スキル |
| --- | --- |
| 個別Dao | `opentouryo-dao-custom` |
| 共通Dao（`CmnDao`） | `opentouryo-dao-common` |
| **自動生成Dao** | **このスキル** |
| 3系統の選び方 | `opentouryo-layer-d` |

B層からの呼び出しは `opentouryo-layer-b`、例外は `opentouryo-exception` を参照。

## 使う場面

**テーブル単位の CRUD。** タイムスタンプ列があれば**楽観排他が組み込まれる**ので、
更新系は特にこれを使う。

**手で書き換えない。** テーブル定義が変わったらツールで再生成する。

### 自動生成が対応しない処理

**テーブル・ビュー単位の CRUD だけが対象。** JOIN を使うクエリ、特殊な検索条件、
SELECT を使う INSERT / UPDATE は**自動生成できない**。これらは個別Dao（`opentouryo-dao-custom`）で
SQL を直接書く。**参照系なら、ビューを作れば**自動生成の対象に載せられる。

### ツールで生成し直す／既存を流用する（エージェント / CI）

D層自動生成ツール（墨壺）は `WinExe`（GUI）だが、**新しい ref には非対話 CLI（`/CUI`）が入った**（`Program.cs`）＝
**テーブル定義から生成できる＝`opentouryo-daogen-cli`**（`/HELP` が引数の一次情報）。
**CLI が無い（古い ref）／生成し直さないときは、既に生成済みの Dao を流用する**：

- **既に生成済みの Dao があればそれを流用する。** 生成物はプロジェクト内・配布サンプルの `.../Dao/`（例 `AppCode/.../Dao/DaoSuppliers.cs`・
  `GenDaoAndBatUpd_sample/Dao/`）に置かれ、ヘッダに「テスト用クラスなので、必要に応じて流用 or 削除して下さい」と付く。
  「手で書き換えない」は**生成ロジックを直に編集しない**意味＝**既存生成物をそのまま使う/コピーするのは可**。
- **名前空間は生成時に決まる＝テンプレート（`DaoTemplate.cs`）の名前空間**（サンプルは `namespace WebForms_Sample`。`/NAMESPACE` 引数は無い）。
  自プロジェクトの名前空間に入れたいなら**テンプレートを直して作り直す**（生成後に名前空間だけ手で書き換えても再生成で消える。`opentouryo-daogen-cli`）。

## 書き方

クラス名は `Dao<テーブル名>`。B層から `DaoShippers genDao = new DaoShippers(this.GetDam())` で生成し、
プロパティ（`PK_列名`・`列名`・`Set_列名_forUPD`）を設定してメソッド（`S2_Select(dt)`・`S3_Update()`・`D1_Insert()` 等）を呼ぶ。
**参照/更新/挿入のコードは `references/snippets.md`**。

## メソッドの命名体系

**`S` = 主キー指定（WHERE が主キー固定）／`D` = 任意の検索条件（WHERE も動的）。**
静的 / 動的 SQL の意味ではない。

| メソッド | 意味 |
| --- | --- |
| `S1_Insert()` | 全列を指定して1レコード挿入（静的SQL `.sql`） |
| `D1_Insert()` | **パラメタで指定した列のみ**挿入（動的SQL `.xml`） |
| `S2_Select(dt)` | 主キーを指定し、1レコード参照 |
| `D2_Select(dt)` | 検索条件を指定し、結果セットを参照 |
| `S3_Update()` | 主キーを指定し、1レコード更新 |
| `D3_Update()` | 任意の検索条件で更新 |
| `S4_Delete()` | 主キーを指定し、1レコード削除 |
| `D4_Delete()` | 任意の検索条件で削除 |
| `D5_SelCnt()` | レコード件数を取得 |

Insert だけは主キー条件がないため、`S1` = 全列固定、`D1` = 指定列のみ、という区別になる。

**★ `S2_Select(dt)` は主キーが不一致でも「列（スキーマ）だけの0行 `DataTable`」を返す**（中身は `DataAdapter.Fill`＝結果セットのメタデータから列を作る）。これを使うと**追加モードの空の器**を D層スキーマから起こせる：`dao.PK_<主キー> = 0; dao.S2_Select(dt); dt.Rows.Add(dt.NewRow());`＝型付きの空行（`RowState=Added`）が得られ、画面側に列定義を持たなくて済む（型変換もそのまま効く。`opentouryo-batch-update`）。

**`D3_Update()` / `D4_Delete()`（検索条件を動的化した更新・削除）は危険。** 条件を1つ間違えると
大量データを破壊しうる。主キー指定の `S3_Update()` / `S4_Delete()` で足りるなら、そちらを使う。

<!--
  S1_Insert だけ .sql（静的）で他は全て .xml（動的）なので、
  「S=静的 / D=動的」と誤読しやすい。実際は WHERE が主キー固定か動的かの区別。
  DevelopmentHistory.md 4.3 参照。
-->

## プロパティの命名体系

**値の設定はプロパティで行う。** 用途ごとに接頭辞・接尾辞が決まっている。

| プロパティ | 用途 |
| --- | --- |
| `PK_<列名>` | 主キーの値。**WHERE 句**に使われる |
| `<列名>` | 一般列の値。INSERT の値、D系の WHERE 条件に使われる |
| `Set_<列名>_forUPD` | **UPDATE の SET 句**の値 |
| `<列名>_Like` | LIKE 検索の条件 |

UPDATE では **WHERE 用（`PK_`）と SET 用（`Set_..._forUPD`）を必ず使い分ける**。
混同すると更新対象が変わる。

その他に `SetParameteToHt()` / `SetUserParameteToHt()` / `ClearParametersFromHt()` /
`ExecGenerateSQL()`（静的SQL の生成。バッチ更新用）がある。**DataTable の RowState で明細を一括更新するなら
`opentouryo-batch-update`**（生成 Dao の CUD を `RowState` で振り分ける・グリッド編集・楽観排他）。

**`SetUserParameteToHt()` は SQL 文字列への置換。** ユーザ入力を渡すと SQL インジェクションに
なる（`opentouryo-dao-custom` の該当節を参照）。

### Oracle：ORA-00972「識別子が長すぎます」

自動生成 Dao はパラメタ識別子に**接頭辞・接尾辞**（`Set_..._forUPD` など）を付けるため、元の列名が長いと
**30 文字を超えて `ORA-00972`** になることがある。**D層自動生成ツールの設定で接頭辞・接尾辞を短くして再生成**する
（生成済みは文字列一括置換でも回避可）。

## 楽観排他（タイムスタンプ）

タイムスタンプ列を持つテーブルの自動生成Dao には、**楽観排他が自動的に組み込まれる**。
生成される UPDATE 文が次の形になる。

```xml
SET
  <DELCMA>
    <IF>[val] = @Set_val_forUPD,</IF>
    [ts] = RAND(),          <!-- タイムスタンプ列は無条件に更新 -->
  </DELCMA>
<WHERE>
  WHERE
    <IF>AND [id] = @id<ELSE>AND [id] IS NULL</ELSE></IF>
    <IF>AND [ts] = @ts<ELSE>AND [ts] IS NULL</ELSE></IF>   <!-- 取得時の値と一致するか -->
</WHERE>
```

他者が先に更新していればタイムスタンプが一致せず、**更新件数が 0 になる**。

したがって**更新件数の 0 件チェックが楽観排他の判定そのもの**。0 件だったら業務例外
（タイムスタンプ アンマッチ）をスローする。詳細は `opentouryo-exception` を参照。

```csharp
int count = genDao.S3_Update();
if (count == 0)
{
    // 楽観排他の失敗。リトライ可能なので業務例外
    throw new BusinessApplicationException(
        "W0002", GetMessage.GetMessageDescription("W0002"), "");
}
```

## クエリ・キャッシュ（列数の多いテーブルの性能対策）

**列が非常に多いテーブルの自動生成 Dao は、動的パラメタライズド・クエリの組み立てコストが高い。**
コンストラクタに**クエリ・キャッシュ ID** を渡すと、一度組み立てた SQL（`CommandText`）を静的 SQL として再利用する。

```csharp
DaoShippers dao = new DaoShippers(this.GetDam(), "f54d4d7bd5c8441187ec6939c4da7303");
```

- **生成テンプレートを `DaoTemplate2` に切り替えて再生成する**（自動生成ツールの `app.config`：`DaoTemplateFileName` = `DaoTemplate2`）。
  キャッシュ ID 付きコンストラクタはこのテンプレートでのみ生成される。ID を渡さない無印コンストラクタは従来どおり毎回組み立てる。
- キャッシュは **Dao クラスごとの `static ConcurrentDictionary`**（キー＝キャッシュ ID＋SQL ファイル名）。**別の Dao とは共有されない**（同じ ID でも別 Dao なら別キャッシュ）。
- **キャッシュ ID は必ず固定値**（ハードコードした GUID か「呼出し元クラス.メソッドの完全修飾名」）。**`Guid.NewGuid()` は使わない**
  （毎回変わってヒットせず、キャッシュが無限に増える）。
- **同一キャッシュ ID には同一パラメタ・セットだけを使う。** パラメタ・セットが違うと、先に組み立てた SQL が再利用されて
  **パラメタ不一致エラー**になる（動的タグの有効/無効が変わるため）。同一 ID の共有は「同じ箇所・同じパラメタ・セット」に限る。
- v02-50 で追加。テンプレート修正のみなので旧バージョンにも適用可。**キャッシュ実装の詳細は `references/snippets.md`**。

## Dao集約クラスでまとめる方針のプロジェクト

プロジェクトによっては、Dao の呼び出しを**Dao集約クラス**でまとめ、B層から直接呼ばせない
方針をとる。**その場合は自動生成Dao も集約クラス経由で使う。**

集約クラスは系統を問わず使える仕組みなので、詳細は `opentouryo-layer-d` を参照。
既存コードが集約クラス経由になっているなら、それに合わせる。

## やってはいけないこと

- **自動生成Dao を手で書き換える** — 再生成で消える。ツールで生成し直す
- **`S` / `D` を「静的 / 動的」の意味だと考える** — `S`=WHERE が主キー固定、`D`=WHERE も動的
- **`D3_Update()` / `D4_Delete()` を安易に使う** — 検索条件を動的化した更新・削除は、条件の
  間違いで大量データを破壊しうる。主キー指定の `S3` / `S4` で足りるならそちらを使う
- **UPDATE で `Set_<列名>_forUPD` ではなく `<列名>` に値を入れる** — SET 句ではなく WHERE 条件になる
- **更新系メソッドの戻り値（更新件数）を捨てる** — **0 件チェックが楽観排他の判定そのもの**
- **`SetUserParameteToHt()` にユーザ入力を渡す** — 文字列置換のため SQL インジェクションになる
- **Dao の中で接続を張る / コミットする** — `this.GetDam()` を渡す。トランザクションは B層が制御する
- **クエリ・キャッシュ ID に `Guid.NewGuid()` を使う** — 毎回変わってヒットせずキャッシュが肥大。固定 GUID か完全修飾名にする
- **同一キャッシュ ID で異なるパラメタ・セットを使う** — 再利用された SQL とパラメタが合わずエラーになる
