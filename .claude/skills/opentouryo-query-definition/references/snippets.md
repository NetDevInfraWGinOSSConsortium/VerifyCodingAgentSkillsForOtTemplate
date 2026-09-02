# SQL 定義 コードスニペット（コピー元）

出典：UserGuide 動的パラメタライズド・クエリ編／開発者編 §3.3、実ソースの SQL 定義ファイルで裏取り。
**on-demand 参照**（SKILL 予算外）。例は SQL Server（`@`）。Oracle は `:`、他 DBMS も接頭辞が違う。

## 静的パラメタライズドクエリ（.sql）

```sql
-- Select（主キー）
SELECT ShipperID, CompanyName, Phone FROM Shippers WHERE ShipperID = @P1
-- Insert
INSERT INTO Shippers (CompanyName, Phone) VALUES (@P2, @P3)
-- Update
UPDATE Shippers SET CompanyName = @P2, Phone = @P3 WHERE ShipperID = @P1
-- Delete
DELETE Shippers WHERE ShipperID = @P1
```

ユーザ定義パラメタ（`%名前%`）で ORDER BY 等を動的化：

```sql
SELECT c1, c2, c3 FROM t1 ORDER BY %COLUMN% %SEQUENCE%
-- SetUserParameter("COLUMN","c2") / SetUserParameter("SEQUENCE","DESC")
```

## 動的パラメタライズドクエリ（.xml）

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<ROOT>
  SELECT DISTINCT ctm.companyname FROM orders AS o
  INNER JOIN customers AS ctm ON o.customerid = ctm.customerid
  <JOIN name="j1">INNER JOIN shippers AS s ON o.shipvia = s.shipperid</JOIN>
  <WHERE>WHERE
    <IF>s.companyname = @p1</IF>
    <IF>AND cgy.categoryname = @p2</IF>
  </WHERE>
  ORDER BY [<VAL name="COLUMN"/>] <VAL name="SEQUENCE"/>
</ROOT>
```

設定（Boolean でタグの有効/無効、`@` はパラメタ、VAL はユーザ定義）：

```csharp
this.SetSqlByFile2("ファイル名");
this.SetParameter("j1", true);          // JOIN 有効
this.SetParameter("p1", "United Package");
this.SetUserParameter("COLUMN", "ctm.companyname");
this.SetUserParameter("SEQUENCE", "DESC");
```

## タグ早見

| タグ | 役割 |
| --- | --- |
| `<JOIN name="x">` | Boolean で JOIN の有効/無効 |
| `<IF>…</IF>` / `<IF name="x">` | 条件式の有効/無効（テキスト内 or タグ内パラメタ） |
| `<ELSE>` | IF が無効のとき（主に `IS NULL`）。`<IF>AND X=@P1<ELSE>AND X IS NULL</ELSE></IF>` |
| `<WHERE>` | 条件が全部消えたら WHERE ごと、先頭の AND/OR も除去 |
| `<SUB name="x">` | サブクエリの有効/無効（内部に IF/WHERE をネスト可） |
| `<LIST>…IN(@PLIST)…</LIST>` | ArrayList を `@名_1, @名_2…` へ自動展開（IN 句） |
| `<SELECT name="x"><CASE value="A">…</CASE><DEFAULT>…</DEFAULT></SELECT>` | 値による分岐 |
| `<VAL name="x"/>` | 任意文字列へ置換（SQLi 注意） |
| `<INSCOL name="列">` | INSERT の列リスト（未設定で消える。自動生成 SQL 用） |
| `<DELCMA>` | 前後の余分なカンマ除去（更新系自動生成 SQL 用） |
| `<PARAM>…<DIV/></PARAM>` | DPQuery_Tool 用のテスト値（実行時に無視/削除） |

## パラメタ2種の違い（重要）

- **テキスト内パラメタ**（`@p` 等）：処理後も**残る**＝全タグに作用（DBMS のパラメタ）。
- **タグ内パラメタ**（`name` 属性）：処理後に**消える**＝最初の1タグにしか作用しない。

## DBNull と null

- `DBNull`：DB の NULL 値（INSERT/UPDATE 用）。WHERE には使えない（SQL に `IS NULL` と書く）。
- `null`：タグを無効化する動作（IF-ELSE では ELSE が有効）。

## 注意

- **`<` `>` はそのまま書けない** → `&lt;` `&gt;`（最新版は `<![CDATA[ … ]]>` 可）。
- **タグ総数が 200 を超えると性能負荷**（分割/ビュー化も検討）。
- DPQuery_Tool 用の PARAM 記述・静的 SQL の `/*PARAM* … *PARAM*/` は UserGuide 動的クエリ編 §2 参照。

## SQL 定義ファイルを DLL に埋め込んで配布（PaaS/クラウド）

SQL 定義ファイルを `EmbeddedResource` として DLL に埋め込む構成。**起動時にフレームワークのスイッチを立てる**と、
`SetSqlByFile2` が通常ファイルの代わりに埋め込みリソースを読む（`MyBaseDao.cs`＝`UseEmbeddedResource` 分岐で裏取り）。

```csharp
// アプリ起動時（Global.asax / Startup / Program / Form 初期化 など）に一度だけ
Touryo.Infrastructure.Business.Dao.MyBaseDao.UseEmbeddedResource = true;
// appSettings に既定の名前空間名を設定（PaaS/DLL 時）
//   "Azure": "[Web アプリケーションの既定の名前空間名]"
// 以降は通常どおり Dao で SetSqlByFile2("Xxx.xml") ／自動生成 Dao を呼ぶだけ
```

- **SQL リソースは EntryAssembly 以外の任意のアセンブリにも埋め込める。SQL 以外のリソースは EntryAssembly に埋め込む。**
- 低レベルには `EmbeddedResourceLoader.LoadAsString(アセンブリ名, 埋め込み名, enc)`（`Touryo.Infrastructure.Public.IO`）。
  埋め込み名（「既定名前空間＋フォルダ＋ファイル名」）が不明なら `Assembly.GetManifestResourceNames()` で列挙して確認する。
