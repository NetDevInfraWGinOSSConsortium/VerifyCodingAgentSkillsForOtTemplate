# 受注一覧（OrdTf）
[共通の決まり](./cmn-testfirst.md)に従い、受注一覧画面の次の範囲を、テスト先行で作る。

## 作る範囲（仕様の ID）
- 画面：`SC-ORD-01`（`I01`〜`I08`、`B01`、`B05`）
- イベント：`EV-ORD-101`（ページ読み込み。選択肢の構築を含む）・`EV-ORD-102`（受注の検索）・`EV-ORD-104`（一覧のページ切替）
- あわせて読む：`LLD/EventSpec/Orders.md` の「共通の処理」（受注検索クエリ・状況の判定・選択肢の構築）、`LLD/TableSchema/Orders.md` の業務ルール、
  `LLD/Decisions/Common.md`・`LLD/Decisions/Orders.md`

範囲外（作らない）：`EV-ORD-103`（条件クリア）・`EV-ORD-105`（並べ替え）・詳細への遷移・新規登録・出荷更新（`EV-ORD-106`〜`108`）、
他の画面から戻ったときの一覧状態の復元（画面遷移 F-2。詳細の画面が無いため）。範囲外の項目・ボタンは置かない。

## 名前（固定）
ProgramID は **`OrdTf`**（テスト先行。トランザクション2 の `Ord` と衝突させない）。

| 対象 | 名前 |
| --- | --- |
| 業務コードクラス | `OrdTfBusiness`（`MyFcBaseLogic` を継承。D層は CmnDao） |
| B層のルート メソッド | `MethodName` = `OrdTfInit`（選択肢）・`OrdTfSearch`（検索。ページは `PageNo`） |
| 引数クラス・戻り値クラス | `OrdTfParameterValue`・`OrdTfReturnValue` |
| テストのプロジェクト・クラス | `<Webプロジェクト名>.Tests`・`OrdTfBusinessTests`、`<Webプロジェクト名>.E2ETests`・`OrdTfScreenTests` |
| テスト仕様 | `docs/spec/test3-testfirst-OrdTf-<フレームワーク>-tests.md`（例 `…-OrdTf-mvc-core-tests.md`） |
| 計画 | `docs/plan/test3-testfirst-OrdTf-<フレームワーク>.md` |
| 決定のレポート | `docs/spec/test3-testfirst-OrdTf-<フレームワーク>-decisions.md`（司令役が書き、人の判断を対話で聞いて書き込む） |
