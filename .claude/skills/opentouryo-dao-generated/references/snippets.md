# 自動生成Dao コードスニペット（コピー元）

出典：UserGuide D層自動生成編、`Samples/2CS_sample/.../Business/LayerB.cs`・`Samples/WebApp_sample/WebForms_Sample/.../Business/LayerB.cs`（実ソース）で裏取り。
**on-demand 参照**（SKILL 予算外）。クラス名は `Dao<テーブル名>`。

## 生成と CRUD（B層から）

```csharp
// B層メソッド内。this.GetDam() を渡して生成
DaoShippers genDao = new DaoShippers(this.GetDam());

// ── 参照（主キー指定・1レコード）──────────────
genDao.PK_ShipperID = p.Shipper.ShipperID;
DataTable dt = new DataTable();
genDao.S2_Select(dt);

// ── 挿入（動的：指定した列だけ）────────────────
genDao.CompanyName = p.Shipper.CompanyName;
genDao.Phone       = p.Shipper.Phone;
genDao.D1_Insert();

// ── 更新（WHERE=主キー、SET=Set_x_forUPD）──────
genDao.PK_ShipperID           = p.Shipper.ShipperID;
genDao.Set_CompanyName_forUPD = p.Shipper.CompanyName;
genDao.Set_Phone_forUPD       = p.Shipper.Phone;
int count = genDao.S3_Update();   // 楽観排他があれば count==0 で競合

// ── 件数 ───────────────────────────────────
long n = genDao.D5_SelCnt();
```

## メソッド命名（S=主キー固定 / D=任意条件）

`S` = WHERE が主キー固定、`D` = WHERE も動的。**静的/動的 SQL の意味ではない。**

| メソッド | 内容 |
| --- | --- |
| `S1_Insert()` / `D1_Insert()` | 全列挿入（.sql）／指定列のみ挿入（.xml） |
| `S2_Select(dt)` / `D2_Select(dt)` | 主キーで1件／任意条件で参照 |
| `S3_Update()` / `D3_Update()` | 主キーで更新／**任意条件で更新（危険）** |
| `S4_Delete()` / `D4_Delete()` | 主キーで削除／**任意条件で削除（危険）** |
| `D5_SelCnt()` | 件数取得 |

> ★ `D3_Update()` / `D4_Delete()`（検索条件を動的化）は条件ミスで大量データを破壊しうる。
> 主キー指定の `S3` / `S4` で足りるならそちらを使う。

## プロパティ命名

| プロパティ | 用途 |
| --- | --- |
| `PK_<列名>` | 主キー値（**WHERE 句**） |
| `<列名>` | 主キー以外（挿入/検索の値） |
| `Set_<列名>_forUPD` | **UPDATE の SET 句**の値 |
| `<列名>_Like` | LIKE 検索条件 |

UPDATE では WHERE 用（`PK_`）と SET 用（`Set_..._forUPD`）を**必ず使い分ける**。

## 楽観排他（タイムスタンプ列があるテーブル）

タイムスタンプ列があると自動生成 Dao に楽観排他が組み込まれ、UPDATE は `SET [ts]=RAND() ... WHERE [ts]=@ts`。
他者が先に更新していれば `count==0`（タイムスタンプ アンマッチ）。件数0チェックで検知する（`opentouryo-exception`）。

> 非サポート（JOIN・特殊条件・Select 使用の Insert/Update 等）は個別 Dao で（`opentouryo-dao-custom`）。

## クエリ・キャッシュ（DaoTemplate2 生成物）

出典：`Samples/WebApp_sample/WebForms_Sample/.../Dao/DaoShippers.cs`（`DaoTemplate2` で生成）＋ `Business/LayerB.cs` L538 で裏取り。

```csharp
// 呼び出し側：固定のキャッシュ ID を渡す（GUID ハードコード or 完全修飾名。Guid.NewGuid() は不可）
DaoShippers dao = new DaoShippers(this.GetDam(), "f54d4d7bd5c8441187ec6939c4da7303");
```

```csharp
// 生成物（DaoTemplate2）側のキャッシュ実装（理解用・自分では書かない）
protected static ConcurrentDictionary<string, string> CDicQueryCache = new ConcurrentDictionary<string, string>();
protected string CacheId = "";

public DaoShippers(BaseDam dam) : base(dam) { }                      // 無印＝毎回組み立て
public DaoShippers(BaseDam dam, string cacheId) : base(dam) { this.CacheId = cacheId; }

// SetSqlByFile2 のラッパ（生成される）
string key = this.CacheId + sqlFileName;
if (string.IsNullOrEmpty(this.CacheId)) { this.SetSqlByFile2(sqlFileName); }           // 従来
else if (CDicQueryCache.ContainsKey(key)) { this.SetSqlByCommand(CDicQueryCache[key]); } // ヒット＝静的再利用
else { this.SetSqlByFile2(sqlFileName); /* 実行後 */ CDicQueryCache[key] = this.GetDam().DamIDbCommand.CommandText; } // ミス＝組立→格納
```

> キャッシュは **Dao クラス単位の `static`**＝別 Dao とは非共有。同一 ID には同一パラメタ・セットのみ（動的タグの有効/無効で `CommandText` が変わるため）。
