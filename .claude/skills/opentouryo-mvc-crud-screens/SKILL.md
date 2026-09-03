---
name: opentouryo-mvc-crud-screens
description: "OpenTouryo の ASP.NET Core MVC（net10.0。net48 MVC も同型）でテーブル保守（マスタメンテ）の CRUD 画面を実装する。2方式＝(1) 一覧→詳細（行選択で詳細画面へ遷移し単一レコードの追加・更新・削除）、(2) 一覧＆更新（一覧でその場に複数行を追加・編集・削除＝RowState バッチ、［更新］でまとめて反映）。MVC 固有＝UOC 無しのアクションメソッド、`<form asp-action>`＋`@Html.AntiForgeryToken()`＋`[ValidateAntiForgeryToken]`、複数ボタンは formaction で送信先を分岐、フッタのメイン5ボタンは @section（＝<form> の外に出る）に置いて form=\"ID\" で紐付け、一覧は table を自前生成し tr をループ、各行に hidden の RowIndex＋input を出して List<行VM> にモデルバインド、ダイアログは JavaScript（window.confirm/alert）。複数リクエストに跨る編集中 DataTable の Session 保持は net48＝binary で直接・net10.0（Core）＝DTTables JSON。RowState バッチ（AddRow=Added・DeleteRow=dr.Delete()=Deleted・セル読み戻し=Modified・IDENTITY は負値仮採番・成功後 AcceptChanges・採番後に一覧再取得）、PK＋timestamp の楽観排他を扱う。MVC の CRUD 画面 / 一覧＆更新 / テーブルメンテナンス / マスタメンテ / Razor で一覧更新 / DataTable を Session に持つ を伴うときに使う。バッチ更新の中核は opentouryo-batch-update、コントローラ基礎は opentouryo-layer-p-mvc。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# テーブル・メンテナンス画面（一覧・詳細・更新）の P層パターン（MVC）

**ASP.NET MVC のテーブル保守 CRUD 画面**の型。**主対象は ASP.NET Core MVC（net10.0）**（net48 MVC も実装は同型＝差は Session 直列化だけ・後述）。
コントローラ／アクションの基礎は `opentouryo-layer-p-mvc`、RowState バッチの中核は `opentouryo-batch-update`、
動的検索は `opentouryo-query-definition`（DPQ）、一覧ページングの SQL は `opentouryo-app-design/references/list-paging.md`。

> 📋 **コピー元スニペット（コントローラ骨格・ビュー骨格）は `references/snippets.md`。**

> **★ Web Forms と違い MVC には自動生成の CRUD 足場（`_3TierEngine`/`ObjectDataSource`/`GridView`）が無い。** アクションメソッド＋Razor で自前に組む
> （`opentouryo-layer-p-mvc`＋本スキル＋`opentouryo-batch-update`）。Web Forms 版は `opentouryo-webforms-crud-screens`。

## 2方式（どちらで作るか）

| 方式 | 画面構成 | 追加/更新/削除 | 使いどころ |
| --- | --- | --- | --- |
| **(1) 一覧→詳細** | 検索一覧 → 詳細（別アクション/画面） | すべて詳細で（単一レコード CRUD） | **オーソドックス。基本はこちら** |
| **(2) 一覧＆更新** | 一覧でその場に複数行を編集 | 追加・更新・削除すべて一覧で（複数行＝RowState バッチ・**[追加] はグリッド外ボタンで空行＝Added**） | 一覧で直接編集したいとき（**オプショナル**） |

> **★ Web系（MVC／Web Forms）ではバッチ更新〔(2)〕はオプショナル＝通常は (1) 一覧→詳細（詳細画面で単一レコード CRUD）で処理する。** 一覧でその場に複数行を編集したいときだけ (2) を採る（Web Forms も同一仕様＝`opentouryo-webforms-crud-screens`）。

## MVC 固有の要点（Web Forms との違い）

- **UOC は無い＝アクションメソッド。** `[HttpGet] Index` で表示、`[HttpPost] SelectAll`/`AddRow`/`DeleteRow`/`BatchUpdate` で操作。
  B層の振り分けは引数クラスの `MethodName`（サンプルに倣い `this.ActionName` を渡す）＝`opentouryo-layer-p-mvc`。P→B は `new LayerB().DoBusinessLogicAsync(pv, iso)`。
  **★ 既存の共有 LayerB に相乗りするなら `MethodName` に一意な UOC 名を明示**（`this.ActionName` は画面専用 LayerB のとき。相乗り時の衝突＝全フレームワーク共通＝`opentouryo-p-call-business`）。
- **フォームと CSRF**＝`<form method="post" asp-action="…">`＋`@Html.AntiForgeryToken()`／**POST アクションに `[ValidateAntiForgeryToken]`**。
- **1フォームから複数アクションへ**＝ボタンの `formaction="@Url.Action("<action>","<ctrl>")"` で送信先を分岐（`SelectAll`/`AddRow`/`DeleteRow`/`BatchUpdate`）。
- **★ 行ボタンの配置3パターン（[削除]のみ／[更新][削除]／[編集][削除]）と読み戻し規則は `opentouryo-batch-update`（共通）。** ただし **MVC に `ButtonField`/`RowCommand`/`EditIndex` は無い**＝各行ボタンを **`formaction` で per-row アクションに飛ばし当該行の `RowIndex` を送る**：[更新]＝`UpdateRow(rowIndex)`・[編集]＝その行の input だけ編集可（他行 `readonly`／編集中行 index を hidden）→編集後 [更新]・[削除]＝`DeleteRow(rowIndex)`。実 CUD はグリッド外 `BatchUpdate` で一括（読み戻しの判定1行・規則は `opentouryo-batch-update`「Web 共通」①。`UpdateRow`＝当該 index・他＝-1）。
- **★ フッタのメイン5ボタンは `@section` に置く→ `form="<フォームID>"` で紐付ける。** `@section` の中身は `@RenderBody()`＝`<form>` の外に描画されるので、
  付けないと押しても送信されない（`opentouryo-layer-p-mvc` の `@section` 罠）。キャプションは画面ごと・不要は `disabled`。
- **一覧は `<table>` を自前生成し `<tr>` をループ**（`for` はコード文脈なので `@` を付けない＝付けると Razor パースエラー）。各行に **hidden `Rows[i].RowIndex`＋各列の
  `input name="Rows[i].<列>"`** を出し、ポストバックで **`List<行VM>`（`RowIndex`＋編集列）にモデルバインド**する。
  **★ 表示列は対象テーブルの全列（＝自動生成Dao が返す列）を既定とする**（仕様に列数の明記が無くても全列表示。IDENTITY 主キーは `readonly`）。**`snippets.md` の例は列を絞った省略＝そのまま写さない**（列を絞ると B層は書けるのに画面から入力できない列が生まれる）。
  **★ `Deleted` 行は描画しない＝表示連番でなく DataTable の行インデックスを `RowIndex` で持ち回る**（連番だと Deleted でズレる）。
  **★ 添字 `i` が 0 起点の連番でない〔Deleted を飛ばす〕とき、各行に `<input type="hidden" name="Rows.Index" value="@i" />` も出す**——ASP.NET (Core) MVC のコレクション モデルバインドは**非連番の添字は `Rows.Index` が無いとバインドしない**＝`model.Rows` が空のまま `BatchUpdate` が走り**編集が静かに捨てられる**（実測：追加行が `NULL` で INSERT→`SqlException 515`。ビルドも 200 も通る）。スニペット＝`references/snippets.md`。
- **★ hidden 項目名とアクション引数名を衝突させない**——ページ移動等をクエリ文字列の引数（例 `Page(… , int pageIndex)`）で渡すとき、フォームに同名の hidden（編集状態保持用の `PageIndex` 等）があると、**モデルバインドは大文字小文字を区別せず衝突しフォーム値がクエリ文字列より優先**＝移動先が無視される（実測：［次ページ］で常に同じページが返る／ビルドも 200 も通る）。**アクション引数名をフォーム項目と別名にする**（`targetPage` 等）。
- **ダイアログは JavaScript**（確認＝`onclick="return window.confirm('…')"`、通知＝`window.alert(@Json.Serialize(Model.Message))` を `@section` のスクリプトで）。
- **★ (1) 一覧→詳細の戻り・二重実行**：MVC は `Session` を避け、**検索条件をクエリ文字列で詳細へ渡し [戻る] で返して再検索**（`autoSearch=true`）＝「一覧→詳細→一覧」で条件が消えない。**単票の追加・削除の後は同じ操作の二重実行を防ぐ**（追加2件・削除は「件数0」の誤メッセージ）＝追加/削除後は該当ボタンを非活性にし [戻る] を促す（更新は `AcceptChanges` で継続可）。Web Forms は `Session` 退避で復元＝`opentouryo-webforms-crud-screens`。

## 編集中 DataTable の保持（Web 共通は `opentouryo-batch-update`）

**複数ポストバックに跨る保持・(a) サーバ Session/(b) クライアント保持〔hidden/SPA〕・net48 は binary で直置き/Core は `DTTables` JSON・件数上限/ページング/結果セット固定・`keepOriginal`／列属性・NOT NULL 515 は `opentouryo-batch-update`「Web 共通」。** MVC 固有だけ：

- **Core は `ISession` が `byte[]`/`string`＝`DTTables` JSON で保持**：`session.SetString(key, DTTables.DTTablesToJson(DTTables.FromDataSet(ds)))`／復元 `DTTables.JsonToDTTables(json).ToDataSet()`（`Public.Dto`）。net48 MVC は `DataTable` を Session に直置き（binary）。
- **(b) クライアント保持は WebAPI クライアントと同じ機構**（DTTables JSON が HTTP を往復）＝UI を API 駆動にするなら**バッチ更新を Web API 化し（`opentouryo-webapi-server`）ページ/SPA をそのクライアントに（`opentouryo-webapi-client`）するのが本来の形**。**MVC に ViewState は無い**（hidden 保持が相当）。

## RowState バッチ（一覧＆更新の核）

**RowState 振り分け・[追加]＝グリッド外の空行〔Added〕・`dr.Delete()`＝Deleted〔`Rows.Remove` にしない〕・NOT NULL 列に値を入れる〔`SqlException 515`〕・IDENTITY は `D1_Insert`／負値仮採番・読み戻し規則〔追加行は常に／既存行は行 [更新] のとき／[削除]のみ型は全行・空文字は NULL 可否で `""`/`DBNull`〕・成功後 `AcceptChanges`・IDENTITY 採番後に一覧再取得・楽観排他〔`Original`/timestamp・件数0〕は `opentouryo-batch-update`（共通）。** MVC 側のアクション対応だけ（コード＝`references/snippets.md`）：

- **［一覧取得］`SelectAll`／［行追加］`AddRow`／［行更新］`UpdateRow(rowIndex)`／［行削除］`DeleteRow(rowIndex)`／［更新］`BatchUpdate`**（`formaction` で分岐）。読み戻しは各行 VM を DataRow へ（`ReadRowsIntoTable(dt, model, targetRowIndex)`）。**業務例外は `ErrorFlag`（ロールバック済み）＝`RowState` を残してやり直せる**。

## やってはいけないこと

- **フッタの submit を `@section` に置いて `form=` を付けない** — `<form>` の外に出て無反応（`opentouryo-layer-p-mvc`）。
- **表示連番を DataTable の行インデックスに使う** — `Deleted` は描画されずズレる。**hidden `RowIndex` を持ち回る**。
- **Core Session に `DataTable`／オブジェクトを直接置こうとする** — `byte[]`/`string` のみ。`DTTables` JSON にする（net48 は直接置ける）。
- **削除を `Rows.Remove()` でやる** — `Deleted` にならず DELETE が出ない。`dr.Delete()`。
- **POST アクションに `[ValidateAntiForgeryToken]` を付け忘れる／業務例外を `catch` する** — 前者は改ざん防御が抜ける、後者は `ErrorFlag` で戻る（飛んでこない）。

> ※ 配布サンプル（`MVC_Sample_Core` 等）に本パターンそのままの画面が無いこともある＝**本パターンを正**とし、`opentouryo-layer-p-mvc`＋`opentouryo-batch-update` で組む。
