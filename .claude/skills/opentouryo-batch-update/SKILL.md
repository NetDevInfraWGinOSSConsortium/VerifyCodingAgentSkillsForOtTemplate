---
name: opentouryo-batch-update
description: "OpenTouryo で .NET DataTable の行編集状態（DataRowState：Added / Modified / Deleted）を使った明細一括（バッチ）更新を実装する。DataTable をバインドしたグリッド系 UI（Web Forms の GridView / ListView / Repeater / DataList、WinForms の DataGridView 等）で、グリッド外の追加ボタン→空行（Added）、グリッド内の削除ボタン→行を Delete（Deleted）、セル編集→Modified、を DataRow の RowState で判定し、自動生成 Dao（S1_Insert / D1_Insert・S3_Update / D3_Update・S4_Delete / D4_Delete・PK_列 / Set_列_forUPD）で一括反映する。DataRowVersion.Original を使った楽観排他、Deleted 行は Original しか読めない点、成功後の AcceptChanges、Web で複数ポストバックに跨る編集は DataTable を Session に保持、大量データ時の SQLUtility（GetInsertSQLParts / GetUpdateSQLParts）と BaseDao.ExecGenerateSQL を扱う。バッチ更新 / 一括更新 / 明細更新 / DataTable / RowState / グリッド / 追加行 / 削除行 / 楽観排他 / CommandBuilder の代替 を伴う作業のときに使う。自動生成 Dao は opentouryo-dao-generated、グリッドのイベントは opentouryo-layer-p-webforms-event。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# DataTable の RowState を使ったバッチ更新

> 📋 **RowState switch の全文・グリッド追加/削除・SQLUtility の実装は `references/snippets.md`**。
> 🖥 **Web Forms のテーブル保守 CRUD 画面パターン**（一覧→詳細／一覧＆更新、ページングと結果セット固定、自動生成→推奨実装への置き換え）は `opentouryo-webforms-crud-screens`。

## いつ使うか

**グリッド系 UI（Web Forms の `GridView` / `ListView` / `Repeater` / `DataList`、WinForms の `DataGridView` 等）に
`DataTable` をバインドして明細を編集し、まとめて更新する**とき。**特にリッチクライアント（WinForms）で
`DataGridView` に `DataTable`／`BindingSource` をバインドする構成で重宝する。**
一般的な仕様：**グリッド外の [追加] ボタンでグリッドに空行を足し、グリッド内の [削除] ボタンで行を消し、
セルを直接編集し、[更新] で一括反映**。この編集を **DataRow の `RowState`** が覚えているので、それで INSERT/UPDATE/DELETE を振り分ける。

- 出典：UserGuide ベターユース編 §4.3・§4.8、サンプル `Samples/2CS_sample/GenDaoAndBatUpd_sample`（実ソースで裏取り）。
- **`.NET の CommandBuilder / DataAdapter 自動更新は使わない**（タイムスタンプ アンマッチを拾えない・IDENTITY を INSERT に含める・全列比較の楽観排他で遅い、等）。代わりに `RowState` で自作する。

## UI 操作と RowState の対応

| UI 操作 | DataTable での操作 | 結果の `RowState` |
| --- | --- | --- |
| グリッド外 [追加] → 空行 | `DataRow nr = dt.NewRow(); …; dt.Rows.Add(nr);` | **`Added`** |
| セル編集 | 値を書き換え | **`Modified`** |
| グリッド内 [削除] | **`dr.Delete();`**（★ `Rows.Remove()` ではない） | **`Deleted`** |
| 変更なし | — | `Unchanged`（対象外） |

> ★ 削除は **`dr.Delete()`**。`dt.Rows.Remove(dr)` だと行が切り離され `Deleted` にならず、バッチが DELETE を出せない。
> ★ **グリッド行ボタン（[削除]のみ／[更新][削除]／[編集][削除]）は Web（MVC / Web Forms）の概念**——`RowState` を作るだけで実 CUD はグリッド外 [バッチ更新] で一括。**配置・読み戻し規則は下記「Web 共通」①**。フレームワーク別の機構＝`opentouryo-webforms-crud-screens`／`opentouryo-mvc-crud-screens`（WinForms は自動バインドで行ボタン/読み戻し不要）。

## B層での一括処理（核心）

`foreach (DataRow dr in dt.Rows)` で回し、**`switch (dr.RowState)`** で自動生成 Dao の CUD を呼ぶ。
行ごとに `dao.ClearParametersFromHt()` でパラメタをクリアする。コード全文は `references/snippets.md`。

- **`Added`** → `S1_Insert()`（**全列必須**＝生成 INSERT が全列に `@param` を持つ。列を1つでも設定しないと実行時エラー）。
  **一覧が全列でないなら `D1_Insert()`**（動的＝設定した列だけ INSERT する。生成 SQL を読んで判断＝`opentouryo-dao-generated`）。
  **★ IDENTITY（自動採番）列があるテーブルは列数に関わらず `D1_Insert()` 一択**——DaoGen CLI の `S1_Insert` は
  **生成時に IDENTITY 列も列リスト/VALUES に含める**ため、そのまま実行すると `IDENTITY_INSERT が OFF…` で必ず失敗する
  （実測。本体同梱の手直し版 `.sql` は IDENTITY を除いている）。`D1_Insert()` で IDENTITY 列を設定しなければ回避できる。
- **`Modified`** → `PK_列` を設定、`Set_列_forUPD` に**現在値**、WHERE 用の列は**元の値**（下記）→ `S3_Update()` / `D3_Update()`。
- **`Deleted`** → `PK_列` を設定 → `S4_Delete()` / `D4_Delete()`。

（`S`=WHERE が主キー固定・`D`=WHERE 動的〔タイムスタンプ併用時〕。命名は `opentouryo-dao-generated`。）

## 楽観排他（`DataRowVersion.Original`）

**変更前の値**は `dr["列名", DataRowVersion.Original]` で取れる。UPDATE/DELETE の WHERE にこの元値
（またはタイムスタンプの元値）を入れると、**他者が先に更新していれば更新件数0**になる（＝タイムスタンプ アンマッチ。
`opentouryo-exception` / `opentouryo-dao-generated`）。件数0を業務例外にする。

> ★ **`Deleted` 行は `DataRowVersion.Original` しか読めない**（現在の値は存在しない）。削除行の PK も
> `dr["ProductID", DataRowVersion.Original]` で取る。

> ★ **複数行 DML の一般則（採番・実行順）と楽観排他方式は `opentouryo-layer-d`**。バッチ更新で特に効くのは：
> ①**IDENTITY 主キーは `S1_Insert()` で採番値が `DataTable` に戻らない**→ 反映後は一覧を再 SELECT して返す（追加直後の行に続けて操作しない）。
> ②同じキーを使い回すなら `switch(dr.RowState)` は **Deleted → Added の順**（Added を先に流すと旧行と衝突）。
> ③楽観排他は取得時の値を WHERE に入れて件数0で検知（タイムスタンプ列が無ければ全列 `Original`・`NULL`→`IS NULL`）。
> **★ `text`/`ntext`/`image` 列は「全列 `Original` を WHERE」に入れられない**——SQL Server はこれらを `=` 比較できず
> `Msg 402`（`ntext と nvarchar は equal to 演算子では互換性がありません`）で落ちる（実測。`Suppliers.HomePage`＝ntext）。対処は順に：
> **①その列だけ WHERE から外す**＝`D3_Update`/`D4_Delete`（動的）で**その列の WHERE 用 `@パラメタ` を設定しない**。生成 `.xml` は WHERE 列が1列ずつ
> `<IF>AND [col]=@col<ELSE>AND [col] IS NULL</ELSE></IF>` なので、**未設定なら `<IF>` ごと消える**＝残り全列で Original 排他が成立する（実測の生成 SQL でも `ntext` 列だけ抜けて確認）。
> **②主キーのみ WHERE の `S3_Update`/`S4_Delete`** に留める（Lost Update を検知できなくなる妥協＝①が組めないときだけ）。**③`rowversion`/`timestamp` 列の追加**。
> **★ ①の「外す」を取り違えると3通りとも静かに壊れる**（例外でなく更新件数0＝過敏な楽観排他に化け原因に辿れない。`<IF>` 3状態＝`opentouryo-query-definition`）：
> **未設定＝消える〔正〕／`null` 設定＝`AND [col] IS NULL`〔値のある行は必ず不一致〕／`DBNull` 設定＝`AND [col]=@col`(NULL)〔決して一致せず・ntext は Msg 402〕**。
> **★ WHERE に使う `Original` が `DBNull` の列は `null` に読み替えて渡す**（`DBNull` のままだと `=@col`(NULL) で永久不一致。**SET 句は逆に `DBNull` を渡す**＝役割が逆・同じ関数で済ませない）。
> **★ 更新と削除で手当てが違う**：全列 Original の往復保持（下記 `keepOriginal`）が効くのは **`Modified` 行＝`D3_Update` 用**だけ。`Deleted` 行は `keepOriginal` 不問で元値主キーが残る（`S4_Delete` は成立）が、**削除も全列 Original で排他するなら `D4_Delete` に同じ WHERE を別途組む**。

## 反映後の後始末

- 成功後に **`dt.AcceptChanges()`** で `RowState` を `Unchanged` に戻す（保存済み状態に同期）。
- トランザクション境界は B層（`opentouryo-layer-b`）。途中で失敗したら業務例外/システム例外でロールバック。

## Web 共通（MVC / Web Forms）：複数ポストバックに跨る編集

**★ 以下は Web（MVC / Web Forms）共通。WinForms は `DataGridView` 自動バインド＝読み戻し不要・編集中 DataTable はフォームのフィールド保持＝Session も不要**（`opentouryo-winforms-crud-screens`）。

- **① セルの読み戻し**：Web はポストバックでセルが自動で `DataTable` に入らない＝**グリッドのセル→DataRow へ読み戻す**（`Modified` はこの代入。下記「Web グリッド↔DataRow」）。読み戻す行＝**「追加行は常に／既存行はその行の [更新] のとき／削除行は対象外」**、判定1行＝`if (dr.RowState != DataRowState.Added && rowIndex != targetRowIndex) continue;`（[更新]＝当該行・[削除]/[バッチ更新]＝-1。行 [更新] を置かない [削除]のみ型は全行）。行ボタンは `RowState` を作るだけ＝**実 CUD はグリッド外 [バッチ更新] で一括**。
- **② 編集中 DataTable の保持**：一覧取得〜編集〜更新が複数ポストバックに跨るので保持する（開き直したら破棄）。置き場は **(a) サーバ `Session`**（後始末〔明示削除〕要・メモリ圧迫・スケールアウトは out-of-proc）／**(b) クライアント保持**（hidden／Web Forms は `ViewState`・SPA＝サーバ ステートレス・後始末不要だが全表が毎回往復＝NW 増。`opentouryo-app-design/references/state-management.md`）。**StateServer/SQLServer なら保持型は直列化可能に**（`DataTable` は可・`opentouryo-config`）。

- **③ ランタイム別の直列化**：**net48 は `DataTable` を Session/ViewState に直接置ける**（binary＝`RowState`/`Original` とも保つ・手当て不要）。**net10.0（Core・MVC のみ。Web Forms は net48 専用）は `ISession` が `byte[]`/`string`＝`DTTables`〔`Public.Dto`〕で JSON 化して往復**（素朴な `System.Text.Json` は `RowState`/変更前値を落とすので不可）：
  `session.SetString(key, DTTables.DTTablesToJson(DTTables.FromDataSet(ds)))`／復元 `DTTables.JsonToDTTables(json).ToDataSet()`。**`RowState` は往復で保持**。
  **変更前値 `Original` は既定 非保持**＝`DTTable.FromDataTable(dt, keepOriginal:true)` で保持可（`Modified` 行だけ変更前セルも載る＝転送量ほぼ増えず、全列 `Original` 排他が往復で成立。`FromDataSet` は引数無し＝表ごとに組む）。使わないなら往復排他は `rowversion`/`timestamp`。列属性は落ちるが実害小（`ExecSelectFill_DT` が制約非取込＝往復前から無い。仮採番の掛け直しは仮主キーを使うときだけ）。
  **★ `DTTables` の本来の用途は WebAPI 転送**（クライアント⇄サーバ往復＝`opentouryo-webapi-server`/`-client`）＝Session/hidden 保持はこの DTO を「同一サーバ内の往復」に流用したもの。
- **④ 件数**：(a)/(b) とも**全結果セットを丸ごと持つ**＝**レコード件数に上限か、ページング前提**（`opentouryo-app-design/references/list-paging.md`）。**編集（バッチ更新）開始後はページングを止め、結果セットを固定**する（ページ切替で再取得すると `RowState` が消える）。

### ★ Web グリッド ↔ DataRow の対応付け（index がずれる）

- **`Deleted` 行は `DefaultView`（既定の `RowStateFilter`）から外れてグリッドに表示されない** → **グリッドの
  `e.RowIndex` と `dt.Rows[i]` がずれる**。DataRow を引くときは `Deleted` を飛ばしながら数えるか、キーで引く。
  **素朴に `dt.Rows[e.RowIndex]` としない。**
- **`DataKeyNames`＋`DataKeys[i]` はバッチ更新では使えない**（`opentouryo-layer-p-webforms-event` は通常これを勧めるが、
  **追加行の主キーが未採番＝`DBNull`** なので成立しない）。バッチ更新時は DataRow 側で対応付ける。
- **★ `ExecSelectFill_DT` は制約を取り込まない**（実体 `new SqlDataAdapter(cmd).Fill(dt)`＝`FillSchema` せず・実ソース確認）＝`PrimaryKey`/NOT NULL 無し・`AllowDBNull` は全列 true。∴ `NewRow()`+`Add()` は**例外を出さない**（旧記述の `NoNullAllowedException` は誤り）。
  **真の罠は「DB 側 NOT NULL 列〔主キー以外も〕を `DBNull` で INSERT→`SqlException 515`」**＝INSERT 時に出て**ビルドも 200 応答も通り静かに壊れる**。→ **Added 行は DB-NOT-NULL 列すべてに値を入れ**、**読み戻しは NULL 可否に合わせる**（NOT NULL→空は `""`／NULL 可→空は `DBNull`）。**仮主キーが要るとき〔`Rows.Find`／自前 `PrimaryKey`／仮 ID 表示〕だけ負値仮採番**（`dt.PrimaryKey` 自前設定＋シード＝既存仮採番の最小-1。INSERT には渡さない。`references/snippets.md`）。
- **セル編集は自動では `DataTable` に入らない** → グリッドのセルから **DataRow へ読み戻す**（`Modified` はこの代入で立つ）。
  **★ 元が `DBNull` の列に `""` を代入すると無駄な `Modified`（無駄 UPDATE）が量産される** → **現在値と一致するなら代入しない**。
  読み戻しスニペットは `references/snippets.md`。

## 大量データ（性能）

フレームワーク経由は 1 件 ≈ 0.5ms のオーバーヘッド。件数が多いなら：**①配列バインド**（ODP.NET／HiRDB。`((DamManagedOdp)GetDam()).ArrayBindCount` に件数・各パラメタを配列で・`OracleDbType` 明示。`opentouryo-dao-custom`）／
**②バッチ SQL**（配列バインド非対応 DBMS の代替）＝**`SQLUtility`**（`Public.Db`）の `GetInsertSQLParts(dt)`/`GetUpdateSQLParts(dt, pk[])` で SQL パーツを作り 1文に複数 VALUES を並べ `CmnDao` で実行／
**③`ExecGenerateSQL`**（実行せず SQL 文字列を生成）＝自動生成 Dao の公開2引数 `ExecGenerateSQL(fileName, sqlUtil)`（基底 `BaseDao` は1引数 `protected`・`CmnDao` は1引数 `public new`・実体 `BaseDam`）。例は `references/snippets.md`。

## やってはいけないこと

- **CommandBuilder / DataAdapter の自動更新を使う** — フレームワーク非サポート。`RowState` で自作する
- **削除を `dt.Rows.Remove()` で行う** — `Deleted` にならず DELETE が出ない。**`dr.Delete()`** を使う
- **`Deleted` 行を現在値（`DataRowVersion` 省略）で読む** — 削除行は `Original` のみ。例外になる
- **楽観排他を忘れて主キーだけで UPDATE/DELETE する** — 上書き事故。WHERE に元値/タイムスタンプを入れ、件数0を検知する
- **更新後に `AcceptChanges()` を呼ばない** — 次の編集で `RowState` がズレる
- **Web で `DataTable` を Session に持ったまま肥大させる** — メモリを圧迫。使用後に消す
