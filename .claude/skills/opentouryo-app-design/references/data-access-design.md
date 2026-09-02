# データアクセス設計（決めどころの地図）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。**設計で決めること**の地図（実装の詳細は各スキル）。
出典：OpenTouryo「データアクセス」（設計トピック目次）＋実装スキル／実ソース。

## データアクセス方式の選択（ADO.NET／DPQ vs EF vs Dapper）

**OpenTouryo は ADO.NET 系（柔軟性重視）**：Dam/Dao ＋ **DPQ（動的パラメタライズドクエリ）**＝パラメタライズドクエリに動的SQL 編集を足したラッパー（`opentouryo-query-definition`。XML 処理で若干の性能劣化）。**SQL が見え・完全制御でき・動的条件/射影に強い**。**★ 生の ADO.NET より生産性は上がる**——DPQ＋**自動生成 Dao**（楽観排他の自動化・POCO 生成。`opentouryo-dao-generated`）で手コーディングを減らせる。

| 方式 | 動的SQL の柔軟性 | 生産性 | SQL 可視性 | 向く先 |
| --- | --- | --- | --- | --- |
| ADO.NET／**OpenTouryo DPQ** | **高**（完全制御可能） | 低〜中（コード化の手間。**OpenTouryo は自動生成 Dao/DPQ で生の ADO.NET より上がる**） | **高** | **基幹系・複雑な集計・チューニング必須の処理** |
| EF（フル ORM） | 中（LINQ で条件追加は容易だが **SQL 制御は困難**・**N+1＝ラウンドトリップ増**） | **高**（CRUD・ドメイン操作） | 低（実行時生成） | 1ページ1テーブル・CRUD 中心・ドメインモデル構築 |
| Dapper（マイクロ ORM） | 中（**`Dapper.SqlBuilder`（NuGet）**等で構築するが SQL 組み立ては自作） | 中 | **高** | 高レスポンス要求・JSON 土管化・シンプルな参照処理 |

- **★ 基幹系で EF が避けられがちな理由**：**SQL を制御・チューニングできない**（LINQ で条件は足せるが生成 SQL が不可視・実行時生成）・**N+1（ラウンドトリップ増）**・トラッキング/大量データのメモリ・**外部スキーマ（論理データ独立性）が使えない**インピーダンス ミスマッチ・スキーマ変更に脆弱。
- **OpenTouryo と ORM は共存可**：DPQ/Dao が基本だが、単純 CRUD 部分に Dapper/EF を併用する設計もありうる（選択は業務要件）。

## コネクション・トランザクション

- コネクションは**B層が持つ**（`UOC_ConnectionOpen` で Open＋Tx 開始・完了時に自動 Close/Commit/Rollback・例外時のみロールバック）。プーリングは既定。
- 分離レベル・TC パターン・複数 Dam・手動 Tx は `opentouryo-transaction-control`／`opentouryo-layer-b`。

## 排他制御（決める）

- **楽観排他（既定・推奨）**：タイムスタンプ列 or 全列 `Original` を WHERE に入れ、**更新件数0で検知**（`opentouryo-layer-d`「楽観排他方式」）。
- **悲観排他（専用機構は無い＝設計パターン）**：
  - **短時間**＝DBMS トランザクション内でロックヒント（SQL Server `WITH (UPDLOCK/HOLDLOCK)`／Oracle `SELECT … FOR UPDATE`）or 高分離レベル（`Serializable`）（`opentouryo-transaction-control`＋`opentouryo-query-definition`）。
  - **ユーザ思考時間をまたぐ長時間**＝**ロック管理テーブル**（アプリでロック状態を記録。DB トランザクションはユーザ操作をまたげないため）。**ロング ロックに注意。**
- デッドロック／ロックタイムアウトは業務例外（`opentouryo-exception`）、多発なら分離レベル見直し（`opentouryo-log-analysis`）。

### 分離レベルと同時実行制御の基礎（DBMS 差・基礎知識）

- **3現象 × 分離レベル**（—＝防げる／有＝起きる）。＋**ロストアップデート**（後勝ち上書き）は楽観（ts）or 悲観（更新ロック/高分離）で防ぐ。

| 分離レベル | ダーティリード | 反復不可能読取 | ファントム |
| --- | --- | --- | --- |
| Read Uncommitted | 有 | 有 | 有 |
| **Read Committed（既定）** | — | 有 | 有 |
| Repeatable Read | — | — | 有 |
| Serializable | — | — | — |

- **同時実行制御は2方式（DBMS で違う）**：
  - **MVCC（多バージョン）**＝Oracle／PostgreSQL／MySQL(InnoDB)。**読み手はロックを取らず**旧バージョンを読む＝ブロッキング/デッドロックが少ない（TEMPDB・オーバーヘッド）。Oracle は既定 RC＋MVCC＝**更新中でも検索は待たない**。
  - **ロック法**＝SQL Server（既定）／DB2／HiRDB。**更新中は読み手が待つ**。SQL Server は 2005+ で **`READ_COMMITTED_SNAPSHOT`**（文発行時点）／**スナップショット分離**（`ALLOW_SNAPSHOT_ISOLATION`）で MVCC 化できる（Azure は既定 ON）。
- **ロック種類**：共有(S)／更新(U)／排他(X)。**更新ロック(U)＝デッドロック防止**。粒度（行/ページ/テーブル）・エスカレーション・インテントロックは内部仕様。
- **OpenTouryo 連携**：分離レベルは `TCDefinition.xml` の `isolevel`（`nc/rc/rr/sz/ss/df`）or `DoBusinessLogic(pv, iso)` で指定（`opentouryo-transaction-control`／`opentouryo-layer-b`）。**既定 iso と DBMS 差**を意識する。

### デッドロック（特に SQL Server）

- 原因＝**ロックのたすき掛け**。SQL Server は**ロック法**で**参照にも共有ロック**・スキャン/エスカレーションで**広範囲にロック**＝起きやすい。
- **対策**：①**オブジェクトへのアクセス順序を統一**する ②**トランザクションを短く**（1バッチに収める・**Tx 内でユーザ対話を挟まない**） ③**低い分離レベル**を使う ④**更新ロック（`UPDLOCK`）で先に取る** ⑤インデックス設計・**ロック エスカレーション抑止** ⑥**MVCC 化**（`READ_COMMITTED_SNAPSHOT`／スナップショット分離）。
- SQL Server は検出すると**犠牲者を選んで `Error 1205`**（並列クエリは `8650`）でロールバック → **リトライ**。OpenTouryo では**業務例外（`ErrorFlag`）で受けて再試行**（`opentouryo-exception`。多発は `opentouryo-log-analysis`）。

## テーブル設計（決める）

- **削除方式**：物理削除／**論理削除**（削除フラグ列で WHERE 除外・履歴保持。フレームワーク機構は無く**設計**）。
- **ID 採番**：`IDENTITY`（採番値がメモリに戻らない＝反映後に再取得。`opentouryo-layer-d`）／`SEQUENCE`（Oracle 等）／**連番採番テーブル**（アプリ採番）。DBMS で差がある。
- **更新履歴（監査）**：履歴テーブル or トリガで記録（設計）。※ コードファイルの「更新履歴」（`opentouryo-comment-convention`）とは別物。
- コード設計（採番コード／リストコード）・マスタ管理は業務設計。
- **数値・金額の型（基礎）**：**金額は `decimal`**（10進・有効桁28-29・誤差が出ない）。**`double`/`float` は誤差**（丸め/打ち切り/桁落ち/情報落ち）で金額に不可。オーバーフローは `System.OverflowException`（C# `checked`／VB `Option Strict`）。**丸めは `FormatConverter`**（`Round_Banker`＝銀行家=偶数丸め／`Round_4sya5nyu`＝四捨五入／`Floor`/`Ceiling`。`Public/Str`・`references/internationalization.md`）。

## 大量データ・性能（決める）

- 結果セット肥大 → **一覧ページング**（`references/list-paging.md`）・`DataReader`（`ExecSelect_DR`＝`opentouryo-layer-d`）。
- ラウンドトリップ → **配列バインド／バッチ SQL／`RowState` バッチ**（`opentouryo-batch-update`）。バッチ処理方式は `references/batch-processing.md`。
- **暗黙の型変換**（`string`→`nvarchar` でインデックス不使用）対策は `opentouryo-query-definition`。

## 複数 DBMS（決める）

- Dam を DBMS で切替（`UOC_ConnectionOpen` の `actionType`〔`[0]`〕で選択。`opentouryo-p-call-business`／`opentouryo-project-policy`）。対応＝Oracle／SQL Server／DB2／MySQL／PostgreSQL／HiRDB。
- **SQL 定義ファイルは DBMS 別**（`sqlserver/`・`oracle/`…・接頭辞 `@`/`:`・型が違う。`opentouryo-query-definition`）。**ID 採番・排他・一覧ページングの DBMS 差**に注意（`references/list-paging.md`）。

## DBMS 側機能（使うか決める）

- **ストアド プロシージャ**（`opentouryo-dao-custom`）・トリガ・外部参照制約・SQL CLR。ロジックを DB 側に置くかは**設計判断**（性能 vs 可搬性・テスト性のトレードオフ）。

## 設計時に決めること（チェック）

- 排他は**楽観（既定）か悲観**か。悲観なら短時間（ロックヒント）か長時間（ロック管理テーブル）か。
- 削除は物理か**論理**か。**ID 採番方式**（IDENTITY/SEQUENCE/連番）と DBMS 差。更新履歴の要否。
- 大量データはページング・`DataReader`・バッチ（配列バインド/バッチSQL/RowState）で潰す。
- 複数 DBMS 対応なら SQL 定義・採番・排他・ページングの差を吸収。
