---
name: opentouryo-query-definition
description: "OpenTouryo の SQL 定義ファイルを書く。静的パラメタライズドクエリ（.sql）と動的パラメタライズドクエリ（.xml）の両方を扱う。@パラメタとユーザパラメタ（静的の %名前% / 動的の VAL タグ）の違い、動的SQLのタグ（ROOT / IF / ELSE / WHERE / DELCMA / INSCOL / VAL / LIST / SELECT / CASE / DEFAULT / JOIN / SUB / PARAM / DIV）の意味と書き方、DPQuery_Tool 用の PARAM タグを扱う。SQL 定義ファイル / .sql / .xml / 静的SQL / 動的SQL / パラメタライズドクエリ / ORDER BY の動的化 / 検索条件の動的化 を伴う作業のときに使う。Dao 側の実装は opentouryo-dao-custom / opentouryo-dao-common / opentouryo-dao-generated を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# SQL 定義ファイル（静的 / 動的パラメタライズドクエリ）

> 📋 **コピー元スニペット**：`references/snippets.md`（静的.sql・動的.xml の実例、タグ早見、DBNull/null、CDATA。実装時はここから写す）。

## このスキルの適用範囲

Dao から実行する SQL 定義ファイルの書き方。ファイルの指定は Dao 側の責務なので
`opentouryo-layer-d`（3系統の使い分け）と系統ごとのスキルを参照。

**SQL 定義ファイルは DLL に埋め込んで配布もできる**（PaaS/クラウド向け）。**起動時に `MyBaseDao.UseEmbeddedResource = true;` を設定**すると、
`SetSqlByFile2` が通常ファイルの代わりに埋め込みリソースを読む（appSettings の `Azure`＝既定の名前空間名を使う。ローダは `EmbeddedResourceLoader.LoadAsString()`）。
詳細は `references/snippets.md`。

## 2種類の定義ファイル

| 拡張子 | 種類 | 中身 |
| --- | --- | --- |
| `.sql` | 静的パラメタライズドクエリ | SQL 文をそのまま書く |
| `.xml` | 動的パラメタライズドクエリ | タグで囲んだ SQL。実行時に条件で組み立てる |

**拡張子で自動的に切り替わる。** Dao 側で `SQLFileName = "Xxx.sql"` なら静的、`"Xxx.xml"` なら
動的として扱われる。

実行時に `.xml` の書式を検証し、**正しい動的クエリなら動的（DPQ）として組み立て、書式が不正ならそのまま静的 SQL
として実行**にフォールバックする。どちらで実行されたかは `IsDPQ`（`BaseDam`）で判別でき、`DPQuery_Tool` の書式確認にも使う。

### 使い分け

- **SQL の形が実行時に変わらない** → `.sql`
- **条件・列・ORDER BY などが実行時に変わる** → `.xml`

「値だけ変わる」なら静的で足りる（値は `@パラメタ` で渡せる）。**SQL の構造そのものが変わる場合に
初めて動的にする。** 動的は読みにくくデバッグしにくいので、必要がなければ使わない。

## パラメタとユーザパラメタ

**両形式に共通する概念だが、構文が違う。** そして安全性がまったく違う。

| | パラメタ | ユーザパラメタ |
| --- | --- | --- |
| 仕組み | パラメタライズドクエリのパラメタ | **SQL 文字列への置換** |
| 静的（`.sql`）の構文 | `@名前` | `%名前%` |
| 動的（`.xml`）の構文 | `@名前` | `<VAL name="名前"/>` |
| 設定する API | `SetParameter("名前", 値)` | `SetUserParameter("名前", 値)` |
| 用途 | 値 | 列名・ソート順など、パラメタにできない箇所 |
| ユーザ入力 | **渡してよい** | **渡してはならない**（SQL インジェクション） |

ユーザパラメタは文字列置換なので、値をそのまま SQL に埋め込む。**入力値はコード側で安全な値に
変換してから渡す**（`opentouryo-dao-custom` / `opentouryo-dao-common` 参照）。

## パラメタの接頭辞は DBMS で違う（このスキルの例は SQL Server）

**SQL 定義ファイルは DBMS ごとに別物。** パラメタの接頭辞が違う。

| DBMS | パラメタの書き方 |
| --- | --- |
| SQL Server | `@P1`（このスキルの例はこれ） |
| Oracle | `:P1` |

本体のリソースでも `sqlserver/` `oracle/` `db2/` `hirdb/` `mysql/` `pstgrs/` などに
**同じクエリを DBMS 別に用意**している。複数 DBMS 対応や Oracle 案件では、**このスキルの例の
`@` を対象 DBMS の接頭辞に読み替える**（既存の SQL ファイルの書き方に合わせる）。

**コード側（`SetParameter("P1", ...)`）は接頭辞なしで DBMS 中立。** 接頭辞をフレームワークが
DBMS ごとに付ける。型を明示するときの `dbTypeInfo` は DBMS 依存
（`SqlDbType.Int` / `OracleDbType.Int32` など。`opentouryo-dao-custom`）。

**バインドは名前バインドのみ**（ODP.NET は名前バインド固定、OLEDB／ODBC／HiRDB はフレームワーク内部で名前バインドに変換）。

`CAST` や関数など SQL の構文そのものも DBMS で違う（後述の暗黙の型変換対策の `CAST` も
SQL Server の例）。

## 静的パラメタライズドクエリ（.sql）

SQL をそのまま書く。パラメタは `@名前`、ユーザパラメタは `%名前%`。

```sql
-- ShipperSelectOrder.sql
SELECT
  ShipperID, CompanyName, Phone
FROM
  Shippers
WHERE
  CompanyName != @P1
ORDER BY %COLUMN% %SEQUENCE%
```

```csharp
cmnDao.SQLFileName = "ShipperSelectOrder.sql";
cmnDao.SetParameter("P1", "test");                  // @P1 に対応
cmnDao.SetUserParameter("COLUMN", " ShipperID ");   // %COLUMN% に対応
cmnDao.SetUserParameter("SEQUENCE", " ASC ");       // %SEQUENCE% に対応
```

## 動的パラメタライズドクエリ（.xml）

### 基本構造

`<ROOT>` で囲む。中は SQL とタグの混在。

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<ROOT>
  SELECT
    ShipperID, CompanyName, Phone
  FROM
    Shippers
  <WHERE>
    WHERE
      <IF>CompanyName != @P1</IF>
  </WHERE>
  ORDER BY <VAL name="COLUMN"/> <VAL name="SEQUENCE"/>
</ROOT>
```

**タグ名は大文字・小文字を区別する。** すべて大文字で書く。

**★ 性能：タグ総数が 200 を超えると負荷が高くなる**（XML パースと組み立てのコスト。目安・公式ガイド）。
巨大な動的クエリはタグを増やしすぎない（分割やビュー化も検討）。

### タグ一覧

| タグ | 役割 |
| --- | --- |
| `<ROOT>` | ルート要素。必須 |
| `<IF>` | 中のパラメタが設定されていれば有効、未設定なら消える |
| `<ELSE>` | `<IF>` の中に入れ子にする。`IF` が無効のとき代わりに出力される |
| `<WHERE>` | WHERE 句を囲む。中が空になれば WHERE ごと消える。余剰な先頭 AND / OR を除去する |
| `<DELCMA>` | 囲んだ範囲の**前後**のカンマを削除する |
| `<INSCOL name="列名">` | INSERT の列リスト。対応するパラメタが未設定なら消える |
| `<VAL name="名前"/>` | ユーザパラメタ（文字列置換） |
| `<LIST>` | IN 句。1つのパラメタ名に複数値を展開する |
| `<SELECT name="名前">` | 値による分岐。中に `<CASE>` / `<DEFAULT>` を置く |
| `<CASE value="値">` | `SELECT` のパラメタ値が一致したとき有効 |
| `<DEFAULT>` | どの `CASE` にも一致しなかったとき有効 |
| `<JOIN name="名前">` | JOIN 句。Boolean パラメタで有効・無効を切り替える。ネスト可 |
| `<SUB name="名前">` | サブクエリ。Boolean パラメタで有効・無効を切り替える |
| `<PARAM>` | **DPQuery_Tool 用のテスト値定義。実行時には削除される** |
| `<DIV/>` | `<PARAM>` 内の区切り |

### IF / ELSE

`<IF>` は中の先頭の `@パラメタ` の**設定状態**で3通りに分岐する（テキスト内パラメタ。実装 `BaseDam.ProcessIFTag`）。

```xml
<IF>AND [ts] = @ts<ELSE>AND [ts] IS NULL</ELSE></IF>
```

| `@ts` の状態 | 結果 |
| --- | --- |
| **値を設定** | `<IF>` 有効＝`AND [ts] = @ts`（`<ELSE>` は削除） |
| **`null` を設定** | `<ELSE>` 有効＝`AND [ts] IS NULL`（`<ELSE>` が無ければエラー） |
| **未設定（`SetParameter` を呼ばない）** | **`<IF>` ブロックごと削除**＝`ts` が句から消える（`<ELSE>` も出ない） |

**★ 「未設定」と「`null` を設定」は別物。** 未設定＝**ブロック削除（列が消える）**／`null` 設定＝**`ELSE`（`IS NULL`）**。
**ある列を条件から外したいなら、その `@パラメタ` を設定しない**（`null` を渡すと逆に `IS NULL` が残るので外れない）。

`name` 属性を付けると、Boolean パラメタで明示的に制御できる。

```xml
<IF name="if1">CompanyName IS NOT NULL</IF>
```

### パラメタの2種類：テキスト内 と タグ内

**タグの有効・無効を制御するパラメタに2種類ある。作用範囲と、処理後に残るかが違う。**
`IF` / `JOIN` / `SUB` / `SELECT` / `INSCOL` などタグ制御全体に共通する概念。

| | テキスト内パラメタ | タグ内パラメタ |
| --- | --- | --- |
| 書き方 | タグ内の先頭の `@パラメタ`（`<IF>AND X=@p1</IF>`） | タグの `name` 属性（`<IF name="x">`） |
| 有効・無効 | 値設定＝有効／`null`設定＝`ELSE`／**未設定＝ブロック削除**（上の IF/ELSE 表） | `true`＝有効／`false`・`null`＝`ELSE`（無ければエラー）／**未設定＝ブロック削除** |
| 処理後 | **残る**（DBMS のパラメタなので実行に必要） | **消える**（静的 SQL の実行には不要） |
| 作用範囲 | **同名を書いた全タグに作用する** | **最初の1タグにだけ作用する** |

- テキスト内は「タグ内の先頭の `@パラメタ` 1つ」がスイッチ。**未設定＝ブロック削除／`null`＝`ELSE`（あれば）／値＝有効**（上の IF/ELSE 参照。未設定と `null` を混同しない）。
- タグ内（`name`）で `false` / `null` は、`<ELSE>` があれば `ELSE`、無ければエラー。
  `JOIN` / `SUB` に `true` / `false` / `null` 以外を渡すとエラー。

### WHERE

**各条件の先頭に `AND` を付けて書く。** WHERE 直後の余剰な `AND` / `OR` は自動で除去される。

```xml
<WHERE>
  WHERE
    <IF>AND [ShipperID] = @ShipperID</IF>
    <IF>AND [CompanyName] = @CompanyName</IF>
    <IF>AND [Phone] = @Phone</IF>
</WHERE>
```

どの `<IF>` も有効にならなければ、`WHERE` 句ごと消える。先頭に付ける `AND` を省くと、
1つ目が無効になったときに `WHERE AND ...` にならず壊れるので、**全条件に付ける**。

### DELCMA / INSCOL

カンマ区切りのリストで、一部の要素が消えたときのカンマを処理する。

```xml
INSERT INTO [Shippers]
  (
    <DELCMA>
      <INSCOL name="ShipperID">[ShipperID],</INSCOL>
      <INSCOL name="CompanyName">[CompanyName],</INSCOL>
      <INSCOL name="Phone">[Phone],</INSCOL>
    </DELCMA>
  )
VALUES
  (
    <DELCMA>
      <IF>@ShipperID,</IF>
      <IF>@CompanyName,</IF>
      <IF>@Phone,</IF>
    </DELCMA>
  )
```

**各要素の末尾にカンマを付けて書く。** `<DELCMA>` が前後のカンマを削除する
（無くなるまで繰り返す）ので、どの要素が残っても正しくなる。

UPDATE の SET 句も同じ。

```xml
SET
  <DELCMA>
    <IF>[CompanyName] = @Set_CompanyName_forUPD,</IF>
    <IF>[Phone] = @Set_Phone_forUPD,</IF>
  </DELCMA>
```

### VAL

ユーザパラメタ。`<VAL name="名前"/>` は空要素タグで書く。

```xml
ORDER BY <VAL name="COLUMN"/> <VAL name="SEQUENCE"/>
```

**前後の空白がつめられることがある。** 必要なら値側で明示的に空白を付ける。

```csharp
cmnDao.SetUserParameter("COLUMN", " " + orderColumn + " ");
```

### LIST

IN 句。1つのパラメタ名に複数の値を展開する。

```xml
<LIST>AND SEX IN (@SEX)</LIST>
```

`ArrayList` に入れた数だけパラメタが自動展開される。**このため後述の「暗黙の型変換」対策の
SQL 内キャストが効かない**（展開後のパラメタに掛からない）。`LIST` で型変換が要るときは、
API 側で型を明示する（`opentouryo-dao-custom`）か、`VAL` タグで必要な数だけ
キャスト付きパラメタを埋め込む。

## 暗黙の型変換による性能劣化に注意

**`string`（.NET）で渡したパラメタは `nvarchar` になる。** 列が `varchar` だと型が不一致になり、
**列側が丸ごと `varchar → nvarchar` に変換されてインデックスが使われない**（インデックス
シークではなくスキャンになり、性能が大きく劣化する）。SQL Server での典型例。

**対策は、SQL ファイル側でパラメタを列の型にキャストする**のを既定とする（以下は SQL Server の例。
接頭辞 `@` や `CAST` 構文は DBMS で違う）。

```sql
-- @P1 は nvarchar で来るが、BBB 列は varchar。SQL 側でキャストして一致させる
SELECT * FROM AAA WHERE BBB = CAST(@P1 AS varchar(10))
```

- **通常は型を明示せず、性能劣化が確認されてから対処する**（先回りしてキャストしない）
- コード側で対処するなら `SetParameter` の型指定オーバーロード（`opentouryo-dao-custom`）
- `LIST` タグ使用時は SQL 内キャストが効かない（上記参照）

### SELECT / CASE / DEFAULT

パラメタの値による分岐。

```xml
<SELECT name="sel">
  <CASE value="a1">
    SELECT * FROM Shippers
  </CASE>
  <CASE value="b2">
    SELECT * FROM Products
  </CASE>
  <DEFAULT>
    SELECT * FROM [Order Details]
  </DEFAULT>
</SELECT>
```

`sel` パラメタの値が `a1` なら1つ目、`b2` なら2つ目、いずれでもなければ `<DEFAULT>` が有効。

### JOIN / SUB

JOIN 句・サブクエリを Boolean パラメタで丸ごと有効・無効にする。`<JOIN>` はネストできる。

```xml
<JOIN name="j1">
  INNER JOIN
    (SELECT * FROM shippers
      <WHERE>WHERE
        <IF name="if1">CompanyName IS NOT NULL</IF>
        <SUB name="s1">AND ShipperID IN (SELECT DISTINCT(ShipperID) FROM shippers)</SUB>
      </WHERE>)
    AS s ON o.shipvia = s.shipperid
</JOIN>
```

`j1` に `true` を設定すれば JOIN が有効になる。不要な JOIN を実行時に外せる。

## PARAM タグ（ツール用）

`<PARAM>`（`.xml`）と `/*PARAM* ... *PARAM*/`（`.sql`）は、**DPQuery_Tool でクエリを試験実行する
ためのテスト値定義**。実行時にはフレームワークが削除するので、SQL には影響しない。

```xml
<PARAM>
  JOB, String, CLERK<DIV/>
  COMM, Decimal, 2301.00<DIV/>
  SEX, Char, M, F<DIV/>
  COLUMN, EMPNO<DIV/>
</PARAM>
```

```sql
/*PARAM*FN,String,CHRISTINE*PARAM*/
/*PARAM*COLUMN,EMPNO*PARAM*/
```

書式は `名前, 型, 値`。`<LIST>` 用は値を複数並べる（`SEX, Char, M, F`）。
ユーザパラメタは型を書かない（`COLUMN, EMPNO`）。

アプリケーションのコードから読まれることはない。**残しても消しても実行結果は変わらない。**

## やってはいけないこと

- **コメントに `@名前` を書く** — パラメタとみなされてエラーになる。
  コメントでパラメタに言及するときは `＠P1` のように全角にするなどして避ける
- **`SetUserParameter()`（`%名前%` / `<VAL>`）にユーザ入力を渡す** — 文字列置換のため
  SQL インジェクションになる。コード側で安全な値に変換してから渡す
- **比較演算子の `<` / `>` をそのまま書く** — XML タグと誤認されて構文エラーになる。
  `&lt;` / `&gt;` に置き換えるか、`<![CDATA[ ... ]]>` で囲む
- **`DBNull` と `null` を混同する** — **別物**。`DBNull` は DB の NULL 値を設定する
  （INSERT / UPDATE 用。WHERE では使えず `IS NULL` を SQL に書く）。`null` は**タグを無効化**する
  （`IF`-`ELSE` なら `ELSE` が有効になる）
- **タグを小文字で書く** — 大文字・小文字を区別する。`<if>` は認識されない
- **`<WHERE>` 内の条件の先頭 `AND` を省く** — 前の条件が無効になったときに壊れる。全条件に付ける
- **`<DELCMA>` 内の要素の末尾カンマを省く** — カンマは `<DELCMA>` が消す前提で、必ず付ける
- **構造が変わらないのに `.xml` を使う** — 値だけ変わるなら `.sql` と `@パラメタ` で足りる
- **`<PARAM>` が実行に影響すると考える** — ツール用。実行時には削除される
