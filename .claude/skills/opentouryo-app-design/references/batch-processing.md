# バッチ処理方式（設計・実装の基本）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。処理方式＝**バッチ（コンソール EXE）**。
出典：OpenTouryo「バッチ処理方式」＋実サンプル `Samples/Bat_sample`（`SimpleBatch_sample`／`RerunnableBatch_sample`〜3）。

## P層＝コンソール app の `Program.Main`

バッチの「P層」は**コンソール app の `Main`**。**専用基底クラスは無い**（`BaseBatch` のようなものは無い）。

```csharp
static void Main(string[] args)
{
    // コマンドライン解析（/DAP /MODE1 … 形式のヘルパがある）
    StringVariableOperator.GetCommandArgs('/', out argsDic, out valsLst);

    // 引数クラス（画面名=実行ファイルの場所、controlName="-"、methodName、actionType、MyUserInfo）
    var pv = new 〈業務〉ParameterValue(asmLocation, "-", "〈method〉", actionType, new MyUserInfo(...));

    // B層を直呼び（インプロセス＝Web と同じ直呼び。opentouryo-p-call-business）
    var rv = (〈業務〉ReturnValue)new LayerB().DoBusinessLogic(pv, DbEnum.IsolationLevelEnum.ReadCommitted);
    if (rv.ErrorFlag) { /* 業務例外 */ } else { /* 正常系 */ }
}
```
- B層・D層・引数/戻り値クラスは**通常どおり**（`opentouryo-layer-b`／`-d`／`opentouryo-p-call-business`）。
- `↓/↑` の UOC 節区切りは呼び出し側なので `B層実行：〈説明〉`（`opentouryo-comment-convention`）。

## ★ 大量データ バッチの落とし穴（設計で潰す）

| 落とし穴 | 対策 |
| --- | --- |
| 全件をメモリに載せる（1万件） | **主キーだけ先に取得**（`SelectPkList`＝`SELECT PK … ORDER BY PK`）。本体は分割して都度読む |
| ロング トランザクション（長時間ロック） | **コミット インターバル**：N 件ごとに1トランザクション（都度 commit） |
| リラン機能が無い | **再開位置（行番号/インデックス）を所定ファイルに出力**し、再実行時にそこから再開 |
| 多重化できない | **EXE を多重起動**し、**分割キー/主キー範囲**をコマンドライン引数で変える |
| フェッチでメモリを食う | `DataReader`／フェッチサイズ（`ExecSelect_DR`＝`opentouryo-layer-d`） |
| 実行ファイル/DB 間通信の非効率 | まとめて処理（配列バインド／バッチ SQL） |

## RerunnableBatch のフロー（`Read →（処理→Write）→ loop`）

1. **`SelectPkList`**：主キーを全件取得（ORDER BY PK）＝軽い `ArrayList pkList`（データ本体は持たない）。
2. `INTERMEDIATE_COMMIT_COUNT`（例 100）ごとに **1トランザクション**：
   - `subPkList` を切り出し → **`ExecuteBatchProcess(subPkList)`**（B層1回＝この範囲を read→処理→write→**commit**）。
   - **トランザクション対象は「（処理→Write）」の範囲**。
3. `initialIndex`（処理開始位置）を再開位置に差し替えて**リラン**。`PerformanceRecorder` で性能測定。

## 明細一括更新の D層技法（大量データ）

- **配列バインド**（ODP.NET／HiRDB＝`((DamManagedOdp)this.GetDam()).ArrayBindCount`）／**バッチ SQL**（`SQLUtility`）／**クエリ・キャッシュ**（自動生成 Dao・v02-50+）。`RowState` バッチは `opentouryo-batch-update`・`opentouryo-dao-generated`。
- ※ 公式ページの `DamOraOdp` は表記で、実クラスは **`DamManagedOdp`**（`opentouryo-dao-custom`）。

## オンライン（画面）からのバッチ起動

- **同期**：`Process` を `WaitForExit()`（`start` なし）。**非同期**：`Process.Start()`（`start` あり）。多重度・リトライ・結果通知が要るなら**非同期処理サービス**（https://github.com/OpenTouryoProject/AsynchronousProcessingService）。
- 多重起動の排他は `Semaphore` / `Mutex`。

## 立ち上げ・設計チェック

- 起点サンプルの取り出し（`SimpleBatch_sample`／`RerunnableBatch_sample`）は `opentouryo-project-setup`。
- **単純処理＝`SimpleBatch`／大量・再実行要＝`RerunnableBatch`**（PK 先取り・コミット間隔・リラン・多重化）。
- 例外＝業務例外は `ErrorFlag`、システム例外はそのまま。exit code で運用に返す設計は業務要件。
