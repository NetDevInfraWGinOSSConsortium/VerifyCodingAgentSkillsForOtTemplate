# ログ分析 コードスニペット・早見（コピー元）

出典：実ログ `C:\root\files\resource\Log`（ACCESS/SQLTRACE/OPERATION/SERVICE-IF）で裏取り。**on-demand 参照**（SKILL 予算外）。
書式は log4net PatternLayout `[%date{yyyy/MM/dd HH:mm:ss,fff}],[%-5level],[%thread],%message`。

## 実ログ行の例（parse の目安）

### ACCESS（正常・入り／出）

```
[2026/03/05 02:53:14,042],[INFO ],[25],,未認証,localhost,----->,Account,LogOff(OnActionExecuting)
[2026/03/05 02:53:14,086],[INFO ],[25],,未認証,localhost,<-----,Account,LogOff(OnActionExecuted),44,
```
- `----->`＝層に入る／`<-----`＝層から出る（MVC は `(OnActionExecuting)`/`(OnActionExecuted)`）。
- **出る側の末尾 `,44,` が実行時間（ms 相当）**（続けて CPU時間）。

### ACCESS（エラー＝ERROR＋続く行がスタックトレース）

```
[2026/07/18 01:09:51,818],[ERROR],[7],,未認証,::1,<-----,login,Page_Load,,2,0,other Exception,セッションタイムアウトです。
Touryo.Infrastructure.Framework.Exceptions.FrameworkException: セッションタイムアウトです。
   場所 Touryo.Infrastructure.Framework.Presentation.BaseController.Page_Load(...) 場所 ...\BaseController.cs:行 534
```
- 末尾側：`…,2,0,other Exception,セッションタイムアウトです。`＝`実行時間=2, CPU=0, エラーメッセージID="other Exception", エラーメッセージ`。
- 次行＝**例外型: メッセージ**、その次＝**`場所 …:行 N`**（発生クラス・行を確定）。

### SQLTRACE（実行時間・CPU時間・SQL）

```
[2026/07/18 01:11:35,837],[INFO ],[5],167,109,[commandText]:SELECT COUNT(*) FROM Shippers [commandParameter]:
[2026/07/18 03:14:22,712],[INFO ],[8],361,328,[commandText]:SELECT * FROM Shippers [commandParameter]:
```
- `167,109` ＝ **実行時間, CPU時間**。`[commandText]:` 以降が SQL、`[commandParameter]:` 以降がパラメタ。

### OPERATION（業務操作・自由書式）／SERVICE-IF

```
[2026/05/11 13:24:37,426],[DEBUG],[9],xxxx(user@example.com) was created.
[2026/04/23 10:08:54,316],[INFO ],[3],正常終了
```
- OPERATION の書式は運用ルール依存（`opentouryo-project-policy`）。SERVICE-IF は `Processing start.`／`正常終了` 等。

## エラーメッセージID / 例外型 → 原因 → 対処

| エラーメッセージID・型 | 意味 | 対処 | スキル |
| --- | --- | --- | --- |
| `FrameworkException`（例 `セッションタイムアウトです。`） | フレームワーク検知。多くは仕様どおりの運用事象 | 多発なら timeout 値・再ログイン導線・不正操作防止の UX を見直す | `opentouryo-auth` |
| `BusinessSystemException`（`messageID` あり） | 業務停止のシステム例外 | 事前定義メッセージ・`UOC_ABEND` 振替の妥当性を確認。原因データ/IF 不整合を是正 | `opentouryo-exception` / `-project-policy` |
| `other Exception`（その他一般例外） | **未ハンドル**の一般例外 | スタックトレースで発生層を特定→入力チェック追加 or 業務/システム例外へ振替（振替は纏め者） | `opentouryo-base2-customize` / `-project-policy` |
| （ACCESS に出ない）業務例外 | 正常系の戻り値（`ErrorFlag`）で返る | **エラーではない**。更新0件＝楽観排他失敗などは想定内 | `opentouryo-exception` / `-dao-generated` |

## 性能パターン → 対処

| 兆候（SQLTRACE/ACCESS） | 推定原因 | 対処 | スキル |
| --- | --- | --- | --- |
| 同一 `commandText` が多発・ループ状 | N+1 | 1クエリ化・集約 Dao・IN 展開（`<LIST>`） | `opentouryo-layer-d` / `-query-definition` |
| 特定 SQL の実行時間が突出 | 索引不使用・全件・結合 | インデックス・条件見直し・**暗黙の型変換**（`string`→`nvarchar` で列変換） | `opentouryo-query-definition`（型変換の節） |
| ACCESS 実行時間が突出（B/D の矢印区間） | SQL 起因 | SQLTRACE を時刻で突き合わせ | `opentouryo-layer-d` |
| ACCESS 実行時間が突出（P 区間） | 画面処理・大量描画 | P層処理の見直し | `opentouryo-layer-p-*` |
| CPU時間 ≪ 実行時間 | I/O・DB 待ち・ロック | 接続/プール・ロック・分離レベル | `opentouryo-transaction-control` |
| デッドロック/ロックタイムアウトが頻出 | 分離レベル・トランザクション設計 | 分離レベル/パターン見直し | `opentouryo-transaction-control` / `-layer-b` |

## grep / 集計レシピ（PowerShell / bash）

```bash
# エラーだけ抽出（スタックトレース1行含める）
grep -nE "\[ERROR|\[FATAL" ACCESS.2026-07-18.log

# エラーメッセージID の頻度（末尾から2番目のカンマ区切りフィールド付近）
grep -E "\[ERROR|\[FATAL" ACCESS.*.log | grep -oE "other Exception|[A-Za-z]+Exception" | sort | uniq -c | sort -rn

# 遅い SQL 上位（SQLTRACE の実行時間＝4カラム目でソート）
grep "commandText" SQLTRACE.2026-*.log | awk -F',' '{print $4","$0}' | sort -t',' -k1 -rn | head

# 同一 SQL の多発（N+1 の兆候）
grep -oE "\[commandText\]:.*\[commandParameter\]" SQLTRACE.*.log | sort | uniq -c | sort -rn | head
```

> ※ フィールド位置はローリング/レイアウトで微妙に変わる。**まず数行を目視**してから集計式を合わせる。
> 個人情報（ユーザ名・メール）は外部に出さない。ログのパスは `FxLog4NetConfFile`（`opentouryo-logging`）。
