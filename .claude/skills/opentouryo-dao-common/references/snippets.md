# 共通Dao（CmnDao）コードスニペット（コピー元）

出典：UserGuide 開発者編 §3、`Business/Dao/CmnDao.cs`・`Business/Dao/MyBaseDao.cs`（実ソース）で裏取り。
**on-demand 参照**（SKILL 予算外）。

## CmnDao の生成と実行（B層から）

専用の Dao クラスを作らず、`CmnDao` に SQL を指定して実行する。

```csharp
// B層メソッド内。this.GetDam() で B層の Dam を渡す
CmnDao dao = new CmnDao(this.GetDam());

// SQL を指定（プロパティで設定する）
dao.SQLFileName = "Select_Shippers";   // ファイル/埋め込みリソース名（推奨）
// dao.SQLText = "SELECT * FROM Shippers WHERE ShipperID = @P1"; // 文字列直接

// パラメタ
dao.SetParameter("P1", shipperId);

// 実行（メソッドは D層と同じ 5 種）
DataTable dt = new DataTable();
dao.ExecSelectFill_DT(dt);
```

## SQL 指定はプロパティ経由（直呼び注意）

```csharp
dao.SQLFileName = "ファイル名";   // ← これで指定する
dao.SQLText     = "SQL文";        // ← または直接
// ★ dao.SetSqlByFile2(...) を直接呼ぶと実行時 BusinessSystemException になる
```

## 埋め込みリソースから SQL を読む

```csharp
MyBaseDao.UseEmbeddedResource = true;   // 埋め込みリソースを使う場合
dao.SQLFileName = "〈名前空間〉.Select_Shippers"; // 名前空間＋ファイル名
```

## 使い分け

- **単発・使い捨ての SQL** → `CmnDao`（このファイル）。
- **業務ごとに整理した個別 Dao** → `opentouryo-dao-custom`。
- **テーブル単位の CRUD 自動生成** → `opentouryo-dao-generated`。
- SQL の書式（静的/動的・DBMS 別接頭辞） → `opentouryo-query-definition`。
