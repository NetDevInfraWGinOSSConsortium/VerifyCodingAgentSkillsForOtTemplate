---
name: opentouryo-log-analysis
description: "OpenTouryo が出力するログ（ACCESS / SQLTRACE / OPERATION / SERVICE-IF＝resource/Log）を分析し、エラー情報と性能測定情報から対応すべき内容を提案する。ACCESS ログのレベル（ERROR/FATAL）・レイヤ矢印・実行時間/CPU時間・エラーメッセージID・スタックトレース、SQLTRACE の実行時間/CPU時間/commandText、例外型（FrameworkException / BusinessSystemException / その他一般例外）による分類、遅い SQL・暗黙の型変換・N+1・同一SQL多発・分離レベル起因（デッドロック/ロックタイムアウト）の検出、重大度順の提案（証跡→原因→対処→使うスキル）を扱う。ログ分析 / エラー分析 / 性能分析 / 障害調査 / ACCESS ログ / SQLTRACE / 遅いSQL / スタックトレース / 処理時間 を伴う作業のときに使う。ログの出力書式・切替は opentouryo-logging、例外型は opentouryo-exception、SQL 性能は opentouryo-query-definition。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# ログ分析（エラー・性能から対応を提案）

> 📋 **実ログ行の parse 例・原因→対処表・grep/集計レシピは `references/snippets.md`**。

## このスキルの役割

**OpenTouryo が出した運用ログを読んで、対応すべき点を重大度順に提案する。** 対象は
`resource/Log`（config `FxLog4NetConfFile` が指すフォルダ）の出力ログ。書式の**設定**は
`opentouryo-logging`、ここは出た**ログを分析する側**。

- 入力：`ACCESS` / `SQLTRACE` / `OPERATION` / `SERVICE-IF` の各ログ（`*_WS` は 3層 WS 側）。
- 出力：**証跡（ログ行）→ 原因の推定 → 対処案 → 使うスキル**、を重大度順に。**推測は証跡とセットで示す。**

## ログの種類とファイル

日付ローリング（`名前.YYYY-MM-DD.log`）。`_WS` 付きはサービスインターフェイス（3層 WS）側の同種ログ。

| ロガー | 内容 | 主に見るもの |
| --- | --- | --- |
| `ACCESS` | P/B/D 層の入り／出のトレース＋例外 | **ERROR/FATAL 行**、**実行時間**、レイヤ矢印 |
| `SQLTRACE` | 実行 SQL とその時間 | **実行時間/CPU時間**、`commandText`、多発 |
| `OPERATION` | 業務操作（運用ルール依存の自由書式） | 業務イベントの追跡（書式は `opentouryo-project-policy`） |
| `SERVICE-IF` | サービスIF の開始/終了 | WS の異常終了 |

## 行の読み方（parse）

共通の先頭：`[日時],[LEVEL],[thread],<message>`（log4net PatternLayout）。`LEVEL` は
`DEBUG/INFO/WARN/ERROR/FATAL`。**`ERROR`・`FATAL` が第一の調査対象。**

- **ACCESS の `<message>`**（カンマ区切り）：`,ユーザ名,IP,レイヤ矢印,画面名,処理名,,実行時間,CPU時間,エラーメッセージID,エラーメッセージ`。
  - レイヤ矢印：`----->`＝層に入る／`<-----`＝層から出る（入れ子が深いほど下層。MVC は `(OnActionExecuting)`／`(OnActionExecuted)`）。
  - **出る側の行の数値が実行時間・CPU時間**（例：`…(OnActionExecuted),44,`＝実行時間 44）。
  - **ERROR 行の直後の複数行がスタックトレース**（`型: メッセージ` ＋ `場所 …:行 N`）。
- **SQLTRACE の `<message>`**：`実行時間,CPU時間,[commandText]:〈SQL〉 [commandParameter]:〈パラメタ〉`。

実際の行例は `references/snippets.md`。

## エラー分析

1. **`ERROR`/`FATAL` を抽出**し、`エラーメッセージID` と続くスタックトレースの**先頭の例外型**で分類する。
2. 型で対応が変わる（詳細な原因→対処表は snippet）：
   - **`FrameworkException`**（例：`セッションタイムアウトです。`）＝フレームワーク検知。多くは仕様どおりの運用事象
     （タイムアウト→再ログイン導線）。**多発なら UX/タイムアウト値**を見直す。`opentouryo-auth`。
   - **`BusinessSystemException`**（`messageID` あり）＝業務停止のシステム例外。**事前定義メッセージ／`UOC_ABEND` の振替**を確認
     （`opentouryo-exception` / `opentouryo-project-policy`）。
   - **その他一般例外**（`エラーメッセージID` が `other Exception`）＝**未ハンドル**。振替（業務/システム例外へ）や
     入力チェックの追加を検討（`opentouryo-base2-customize` の `UOC_ABEND` は纏め者領分）。
   - **業務例外**は正常系の戻り値で返るため **ACCESS の ERROR には出ない**（更新0件＝楽観排他失敗などは業務例外＝正常。`opentouryo-dao-generated` / `-exception`）。
3. **スタックトレースの `場所 …:行` で発生層・クラスを特定**し、責任スキルへ割り当てる。

## 性能分析

**絶対値でなく分布（外れ値）で見る。** 単位はミリ秒相当。

- **SQLTRACE の実行時間が突出**／**同一 `commandText` が多発** → 遅い SQL。対処候補：
  - **暗黙の型変換**（`string`→`nvarchar` で列側が変換されインデックス不使用）＝`opentouryo-query-definition` の該当節。
  - **N+1**（ループ内で同一 SQL 反復）＝1クエリ化／集約 Dao（`opentouryo-layer-d`）。
  - 索引・結合・全件取得の見直し。
- **ACCESS の実行時間が突出** → レイヤ矢印で切り分け：**B/D が重い＝SQL 起因**（SQLTRACE を突き合わせ）、**P が重い＝画面処理**。
- **CPU時間 ≈ 実行時間** → CPU バウンド／**CPU時間 ≪ 実行時間** → I/O・DB 待ち（接続・ロック待ちを疑う）。
- **デッドロック／ロックタイムアウト**が業務例外/エラーで頻出 → **分離レベル**の見直し（`opentouryo-transaction-control` / `-layer-b`）。

## 提案の出し方

- **重大度順**（システム停止＞多発エラー＞遅い SQL＞散発）に、各項目で **①証跡（ログ行）②推定原因 ③対処案 ④使うスキル** を1組で提示。
- **証跡なしの断定をしない。** 「原因の可能性」と「確定」を区別する。
- **サンプル固有名に引きずられない**（`Shippers` 等はサンプル。自プロジェクトのテーブル/画面で読む）。
- 集計は grep/スクリプトで（レシピは snippet）。**個人情報（ユーザ名・メール）を外部に出さない。**

## やってはいけないこと

- **業務例外を「エラー」として報告する** — 業務例外は正常系（`ErrorFlag`）で、ACCESS の ERROR には出ない
- **絶対時間だけで「遅い」と決める** — 分布・多発・層で判断する（初回ヒットや dev 環境で単発的に遅いのは別）
- **スタックトレースの発生行を無視して層を推測する** — `場所 …:行` で確定してから割り当てる
- **ログの書式を変えて辻褄合わせ** — 書式は親クラス2／log4net 設定（`opentouryo-logging` / `-base2-customize`）。ここは読む側
- **ログの個人情報を外部サービスへ送る** — 分析はローカルで
