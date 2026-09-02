# 性能設計（性能問題のポイントの地図）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。**設計で決める性能事項**の地図。
出典：「性能問題のポイント」（技術情報）＋既存 references。**性能の分析（実測後）は `opentouryo-log-analysis`**。

## ★ 性能ポイントは「アプリの実装」だけに無い（層をまたぐ）

性能問題は全層に散る。**アプリ開発者/設計者が関わる性能事項は「アプリケーションの実装」節だけでなく、DB 物理設計・サーバ構成・Web サーバ・ミドルウェアの各節にも散在する**：

| 層（出典の節） | アプリ設計で決める性能事項 | 参照 |
| --- | --- | --- |
| サーバ構成（垂直分散） | 2→3層化・**非同期処理**・帳票/バッチの分離（重い処理を別プロセス/サーバへ） | `references/batch-processing.md`・`opentouryo-richclient-async`・処理方式選択（本スキル冒頭） |
| DB 物理設計 | **インデックス設計**（暗黙の型変換で不使用＝×）・**非正規化**・パーティション | `opentouryo-query-definition`・`references/data-access-design.md` |
| Web サーバ | **静的コンテンツのキャッシュ**・HTTP 圧縮・SSL | `references/cache-control.md` |
| ミドルウェア/接続 | 接続数・キャッシュサイズ・同時実行 | `references/concurrency-tuning.md` |
| **アプリの実装** | **ラウンドトリップ集約**（複数レコードまとめ取得・JOIN・ストアド）・**ページング**・フェッチサイズ・UI 性能 | `references/list-paging.md`・`opentouryo-batch-update`・`opentouryo-layer-d`（`ExecSelect_DR`） |
| タイムアウト | 呼び出し元ほど長く | `references/timeout-values.md` |

## 設計時に決めること（チェック）

- **ラウンドトリップを減らす**（DB/通信）：複数レコードまとめ取得・JOIN・ストアド・バッチ・配列バインド。
- **大量データはページング＋`DataReader`＋フェッチサイズ**（メモリ。`references/list-paging.md`・`opentouryo-layer-d`）。
- **インデックス設計**（暗黙の型変換でインデックス不使用にしない＝`opentouryo-query-definition`）。重い参照は**非正規化**も検討。
- **キャッシュ**（静的＝Web/CDN、参照データ＝Memory/Distributed、レスポンス無効化＝`references/cache-control.md`）。
- **重い処理は分離**（非同期・バッチ・帳票を別プロセス/サーバへ＝垂直分散）。
- **接続・同時実行**（Kestrel/async・接続上限＝`references/concurrency-tuning.md`）。
- **先回りせず実測してから対処**。分析は `opentouryo-log-analysis`、負荷テストで確認。

## 出典の全体像（性能問題は全層に散る）

概要／サーバマシン（垂直分散・CPU/メモリ/ディスク/NIC）／ネットワーク（水平分散・帯域/品質）／ミドルウェア（キャッシュ/CPU アフィニティ/NUMA）／DB 物理設計（インデックス/圧縮/分割/**非正規化**）／Web サーバ（SSL/圧縮/静的キャッシュ）／**アプリの実装**（通信ラウンドトリップ/ページング/UI）／テスト（単体/結合/**負荷**）／運用（バッチ/バックアップ/統計/障害復旧/ウィルススキャン）。
→ **アプリ設計は「アプリの実装」節に閉じず、上表の各層に関与する。**
