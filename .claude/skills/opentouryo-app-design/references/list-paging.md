# 一覧ページ制御方式（設計・実装の基本）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。
出典：OpenTouryo「一覧ページ制御方式」＋実務（DBMS 別 SQL）。関連＝`opentouryo-query-definition`／`opentouryo-layer-d`／`opentouryo-layer-p-webforms-event`（グリッド）。

## まず決めること

1. **最大表示件数・最大取得件数**（1ページの表示数と、そもそも取得を打ち切る上限）。**業務要件で決めてアプリ側に設定**する（フレームワーク固定のキーはない）。大量ヒットを無制限に取得しない＝メモリ・転送・DB 負荷の防止。
2. **ページ制御の実装方式**（下記3つ）。

## ページ制御の3方式

| 方式 | 概要 | 向き |
| --- | --- | --- |
| ①アプリケーション制御 | **主キーだけ先に取得** → 表示対象ページの主キーで本体を再検索。ODP.NET の `DataReader` はサーバカーソル対応で `FetchSize` で取得数を制御 | 件数が読みやすく、UI ページャと相性可 |
| ②ストアドプロシージャ制御 | サーバ側で範囲（例 101〜200件目）を絞って返す | ロジックを DB 側に置きたいとき |
| ③SQL 制御 | **`ROW_NUMBER()`／`TOP`／`ROWNUM`** で範囲を SQL 内に埋める（下記） | 最も一般的。動的クエリと相性可 |

## SQL パターン（DBMS 別）

- **SQL Server**：上位 N＝`SELECT TOP 10 * FROM T ORDER BY C`／範囲＝**`ROW_NUMBER() OVER (ORDER BY …)` ＋ CTE**（2005+）で `WHERE RNUM BETWEEN @from AND @to`。
- **Oracle**：上位 N＝`SELECT * FROM (SELECT * FROM T ORDER BY C) WHERE ROWNUM <= 10`／範囲＝**`ROW_NUMBER() OVER (ORDER BY …) RNUM`** で `WHERE RNUM BETWEEN 3 AND 5`。
- SQL 構文は DBMS 別＝**SQL 定義ファイルも DBMS 別ディレクトリ**（`sqlserver/`・`oracle/`…。`opentouryo-query-definition`）。ソート列・範囲を可変にするなら**動的クエリ（DPQ）**でタグ化する。

## 大量データの考え方

- **全件取得してメモリでページングしない**（メモリ・転送コスト）。**SQL でページング**（③）が基本。
- 一覧の**総件数**が要るなら別途 `COUNT(*)`（自動生成 Dao の `D5_SelCnt`／件数取得系＝`opentouryo-dao-generated`）。
- ストリーミングで大量に流すなら `ExecSelect_DR`（DataReader）が `ExecSelectFill_DT` より速い（`opentouryo-layer-d`／`opentouryo-dao-common`）。
- **UI ページャ**（GridView `PageIndexChanging`・ListView `DataPager` 等）は表示制御。**表示ページャとデータ取得方式（③）を混同しない**——UI だけでページングすると全件を持つことになる（`opentouryo-layer-p-webforms-event`）。

## 設計時に決めること（チェック）

- 最大表示件数・最大取得件数（打ち切り上限）。
- ページ制御方式（①/②/③。既定は③ SQL 制御）。DBMS 別 SQL を用意。
- ソート・絞り込みを可変にするなら DPQ（`opentouryo-query-definition`）。
- 総件数の要否（`COUNT`）と、UI ページャ／データ取得の役割分担。
