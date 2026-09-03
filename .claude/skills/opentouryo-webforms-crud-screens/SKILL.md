---
name: opentouryo-webforms-crud-screens
description: "OpenTouryo の ASP.NET Web Forms でテーブル保守（マスタメンテ）の CRUD 画面を実装する。2方式＝(1) 一覧→詳細（検索一覧で行選択して詳細画面で単一レコードの追加・更新・削除。オーソドックス・既定）、(2) 一覧＆更新（一覧でその場で複数行を更新・削除＝RowState バッチ、追加だけ詳細画面）。検索条件（AND/OR/Like）→動的クエリ、GridView と ObjectDataSource による一覧・ページング・ソート、行選択で主キー＋タイムスタンプを Session に持ち回り、詳細画面の INSERT/表示モード分岐、(2) の「最初の編集で結果セットを固定＝ページング停止」、グリッド↔DataRow の対応付けを扱う。自動生成（_3TierEngine / CmnTableAdapter / ObjectDataSource）を推奨実装（LayerB/DoBusinessLogic＋自動生成 Dao＋DPQ＋RowState）へ置き換える指針も示す。テーブルメンテナンス画面 / 一覧画面 / 検索画面 / 詳細画面 / 一覧→詳細 / 一覧＆更新 / CRUD 画面 / マスタメンテ / GridView の更新・削除 を伴う作業のときに使う。バッチ更新の中核は opentouryo-batch-update、一覧ページングの SQL は opentouryo-app-design の list-paging を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# テーブル・メンテナンス画面（一覧・詳細・更新）の P層パターン

**Web Forms のテーブル保守 CRUD 画面**を、一覧/詳細/更新でどう分けるかの型。**ASP.NET Web Forms（net48）専用。**
実装の中核部品は `opentouryo-batch-update`（RowState バッチ）／`opentouryo-layer-p-webforms-screen`・`-event`（画面・グリッド）／`opentouryo-screen-transition`（遷移）／`opentouryo-app-design/references/list-paging.md`（ページング）。
出典：自動生成サンプル `Aspx/sample/3Tier/Products{ConditionalSearch,Detail,SearchAndUpdate}.aspx(.cs)`＋`ProductsTableAdapter.cs`＋実ソース `Business/Business/_3TierEngine.cs`・`Business/Presentation/CmnTableAdapter.cs`。

> 📋 **コピー元スニペット＋「何処を→どう書き換えるか」（自動生成→推奨）の対比は `references/snippets.md`**（サンプルは削除されうるのでスニペットを正とする）。

> **★ サンプルは自動生成（墨壺２）で、汎用エンジン `_3TierEngine`（`TableName`＋`Dictionary`＋`actionType` を渡すと内部で自動生成 SQL を直利用）を使う＝OpenTouryo の推奨実装とは少し違う。** 構造（画面分割・状態遷移・結果セット固定・RowState バッチ）を参考にし、**推奨部品**（`LayerB`/`DoBusinessLogic`＋自動生成 Dao＋DPQ＋RowState）で実装する。自動生成そのままを写さない。

## 2方式（どちらで作るか）

| 方式 | 画面構成 | 追加/更新/削除 | 使いどころ |
| --- | --- | --- | --- |
| **(1) 一覧→詳細**（`→`＝画面遷移） | 検索一覧 → **詳細** | すべて詳細画面で（単一レコード CRUD） | **オーソドックス。基本はこちら** |
| **(2) 一覧＆更新**（`＆`＝同一画面） | 検索一覧＝その場で追加/更新/削除 | **追加・更新・削除すべて一覧で（複数行＝RowState バッチ・[追加] はグリッド外ボタンで空行＝Added）** | 一覧で直接編集したいとき（**オプショナル**） |

> **★ Web系（MVC／Web Forms）ではバッチ更新〔(2)〕はオプショナル＝通常は (1) 一覧→詳細（詳細画面で単一レコード CRUD）で処理する。** 一覧でその場に複数行を編集したいときだけ (2) を採る。**(2) の追加・更新・削除は MVC と同一仕様**（`opentouryo-mvc-crud-screens`／`opentouryo-batch-update`）。

## (1) 一覧→詳細

- **検索一覧画面**：AND/OR/Like 条件 → WHERE を組む（推奨＝**動的クエリ DPQ** `.xml`。サンプルは条件を `Dictionary` で `_3TierEngine` に渡す）。GridView＋ページング（下記）。
  **行選択で主キー（＋タイムスタンプ）を `Session` に入れて**詳細へ遷移（`return "ProductsDetail.aspx"`）。追加ボタンも詳細へ（Session に PK を入れない＝新規モード）。
- **詳細画面**：**`Session` の PK 有無でモード分岐** — **無＝INSERT モード**（編集可・更新/削除ボタン不活性）、**有＝表示モード**（レコード取得・`ReadOnly`・編集ボタンで編集可に）。Insert/Update/Delete を実行。
  更新/削除は **PK＋タイムスタンプで楽観排他**（件数0チェック＝`opentouryo-layer-d`・`opentouryo-dao-generated`）。
- **状態持ち回り**：選択→詳細は別画面・別ポストバックをまたぐので **`Session` に PK＋TS**（`opentouryo-app-design/references/state-management.md`）。
- **★ 戻り（詳細→一覧）で検索条件を復元する**：検索条件も `Session` に退避し、画面Ａの `UOC_FormInit` で復元して再検索する（遷移の機構〔URL 返し／ラベル返し〕とは独立の話。**画面遷移制御は既定では無効**＝`FxScreenTransitionMode=off` なので条件復元に `SCDefinition.xml` は要らない＝`opentouryo-screen-transition`）。復元しないと「一覧→詳細→一覧」で条件が消える（MVC は `Session` を避けクエリ文字列で持ち回る＝`opentouryo-mvc-crud-screens`）。
- **★ 単票の追加・削除の後は二重実行を防ぐ**：詳細画面はボタン1回押しで完結するので、追加/削除の直後に同じボタンをもう一度押すと二重実行になる（追加は2件・削除は「件数0＝他のユーザによって更新されています」の誤メッセージ）。**追加・削除後は該当ボタンを非活性にし [戻る] を促す**（更新は `AcceptChanges` で `Original` が現在値に揃い続けて実行できる）。

## (2) 一覧＆更新（特殊）

- 一覧に行ごとの **[更新][削除]列**。**編集前はページング有効**（ObjectDataSource＝サーバ側ページング）。
- **★ 最初の [更新]/[削除] で「結果セットを固定」する**：`UOC_gvwGridView1_RowCommand` で当該行を編集（セル読み戻し→`Modified` ／ `dr.Delete()`→`Deleted`）した後、
  **ページングを止め（`AllowPaging=false`）、GridView を `Session` の `DataTable` にバインドし直す**（`DataSource=dt; DataSourceID=null; DataBind()`）。
  **理由：ページングはページ切替で再取得するため `RowState` を保てない。** 固定後は同一結果セット上で複数行を編集し、**[バッチ更新] で RowState バッチ更新**（`opentouryo-batch-update` 本文）。
- **[追加] はグリッド外のボタンで一覧に空行を足す**（`NewRow`＋`Rows.Add`＝Added。NOT NULL 列に値・IDENTITY は `D1_Insert`・仮採番は `opentouryo-batch-update`）＝**MVC と同一**。※ サンプル（`ProductsSearchAndUpdate`）は追加を詳細画面でやる as-built だが、**本パターンはグリッド外 [追加] で一覧に空行**（追加・更新・削除を一覧で完結）。
- グリッド index↔DataRow は **`Deleted` を飛ばして数える**、セルは **DataRow へ読み戻す**（`opentouryo-batch-update`「Web グリッド ↔ DataRow」＝本サンプルが実例）。
- **★ 表示列は対象テーブルの全列（＝自動生成Dao が返す列）を既定とする**（仕様に列数の明記が無くても全列表示。IDENTITY 主キーは表示のみ）。**snippets の例は列を絞った省略＝そのまま写さない**。
- **★ 行ボタンの3配置（[削除]のみ／[更新][削除]／[編集][削除]）と読み戻し規則は `opentouryo-batch-update`（共通）。** Web Forms の実装＝行に **`<asp:ButtonField CommandName="Update"/"Delete">`**（サンプル `ProductsSearchAndUpdate` は ② 型）、**`UOC_gvwGridView1_RowCommand` で `fxEventArgs.InnerButtonID` を `switch`**し `PostBackValue` の表示 index から `DataRow` を引く（`Added`/`Deleted` を飛ばして数える）：
  - **[更新]**＝その行の `txt<列>`/`ddl<列>` を `DataRow` へ読み戻して `Modified`。**[編集]**＝`EditIndex` にその行を設定（他行は表示のまま）→編集後 [更新]（※サンプルは全行常時 TextBox 編集可＝[編集] 無しの ② 型）。**[削除]**＝`dr.Delete()`。
  - **実 CUD はグリッド外 [バッチ更新]（`btnBatUpd`）で一括**。行ボタン押下後は結果セット固定（`AllowPaging=false`→`DataSource=dt` 再バインド）。
  - 読み戻しの判定1行・規則は `opentouryo-batch-update`「Web 共通」①（[更新]＝当該行・[削除]/[バッチ更新]＝-1・[削除]のみ型は全行）。

## ページング（P層 ⇄ D層）

- **P層**：GridView `AllowPaging`＋ObjectDataSource `EnablePaging`＝`SelectMethod(startRowIndex, maximumRows)`＋`SelectCountMethod()`（`CmnTableAdapter` 派生）でサーバ側ページング。ソートは `Session` に保持して SelectMethod へ。
- **D層**：**`ROW_NUMBER() OVER (ORDER BY …) BETWEEN @from AND @to`** で SQL ページング（DBMS 別＝SQL Server は `WITH … CTE`／Oracle は別式。`opentouryo-app-design/references/list-paging.md`）。総件数は別途 `COUNT`。
  ※ サンプルの `_3TierEngine` は内部でこの ROW_NUMBER SQL を自動生成している（`_3TierEngine.cs`）。
- **★ (2) はバッチ更新のため編集中の `DataTable` を `Session` に持つ＝件数がメモリを圧迫する。** **レコード件数に上限を設けるか、ページングを前提にする**
  （Web Forms は net48＝`DataTable` は binary シリアライズ可能で InProc も StateServer/SQLServer も直列化の手当ては要らない。Core の MVC で JSON 化が要る話は `opentouryo-mvc-crud-screens`）
  （大量一覧では必須）。**ページングする場合は編集開始後にページングを止める**（上記「結果セット固定」。`opentouryo-batch-update`）。
- **★ 置き場は `Session` か `ViewState` か**：(2) は同一画面のポストバックで完結するので **`ViewState` も検討する**（`this.ViewState["dt"] = dt;`／復元 `(DataTable)this.ViewState["dt"]` を `Session` の代わりに使い、`DataSource=dt` で GridView に再バインド）。
  **NW オーバーヘッドは増える（`__VIEWSTATE` に全表が載って往復する）が、サーバ メモリを使わず後始末が要らない**のが大きな利点（`Session` は使用後に消す／LRU 上限が要る）。件数が多いと ViewState が肥大するので上限/ページングは同様に要る（`opentouryo-app-design/references/state-management.md`）。

## 推奨実装への置き換え（自動生成 → 推奨）

| 自動生成サンプル | OpenTouryo 推奨実装 |
| --- | --- |
| 汎用エンジン `_3TierEngine`（`TableName`＋`Dictionary`＋`actionType`） | 業務ごとの **`LayerB`**（`UOC_Select/Insert/Update/Delete/BatchUpdate`）＋業務 **`ParameterValue`/`ReturnValue`** 派生（`opentouryo-layer-b`・`opentouryo-p-call-business`） |
| P→B＝`new _3TierEngine().DoBusinessLogic(pv, iso)` | **Web は `new LayerB().DoBusinessLogic(pv, iso)` 直呼び**（`opentouryo-p-call-business`「呼び出し経路の選択」） |
| 条件を `Dictionary` で渡す | **動的クエリ（DPQ）** の `.xml`（`opentouryo-query-definition`） |
| engine 内部の自動生成 SQL 直利用 | 自動生成 **Dao** を業務 Dao から呼ぶ（`S1/D1_Insert`・`S3/D3_Update`・`S4/D4_Delete`・件数 `D5_SelCnt`・ページング。`opentouryo-dao-generated`・`opentouryo-batch-update`） |
| `CmnTableAdapter`＋`ObjectDataSource`（ページング） | ページング機構は残してよい。ただし `SelectMethod` は engine でなく**業務 `LayerB` を呼ぶ** |

## やってはいけないこと

- **(2) でページングを止めずに複数行編集する** — ページ切替で再取得＝`RowState` が消える。**最初の編集で結果セットを固定**する。
- **★ ポストバックのたびに無条件でグリッドを `DataBind()` する** — 行内コントロールが作り直され、**ポスト値が読み戻し（`ReadDetailGrid` 等）より前に消える**＝既定値のまま INSERT（実測：明細で商品が選び直せず PK 重複／ビルドも 200 も通る）。**再バインドは明示的な場面〔行追加・削除・反映後の再表示〕だけ**にし、ポストバック時は ViewState＋ポスト値からの復元に任せる。
- **追加行の DB 側 NOT NULL 列を空のまま [バッチ更新] する**（(2)）— INSERT で `SqlException 515`。グリッド外 [追加] で空行を足したら NOT NULL 列に値を入れる（`opentouryo-batch-update`）。
- **グリッド index をそのまま DataRow index に使う** — `Deleted` で必ずずれる（`opentouryo-batch-update`）。
- **自動生成（`_3TierEngine`）のまま実装を残す** — 構造の参考に留め、推奨部品で書く。

> ※ 配布サンプルは 2層化・整理で削除・変更されうる＝**本パターン（と上表の置き換え）を正とする**。
