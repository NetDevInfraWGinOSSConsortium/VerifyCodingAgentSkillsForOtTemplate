---
name: opentouryo-transaction-control
description: "OpenTouryo のトランザクション制御機能を実装する。TCDefinition.xml に TransactionPattern（接続文字列 connkey と分離レベル isolevel の組）と TransactionGroup（パターンの束ね）を定義し、BaseLogic.InitDam(パターンID, dam) / GetTransactionPatterns(グループID) で Dam を初期化する。isolevel の2文字略号（nc / nt / uc / rc / rr / sz / ss / df）と DbEnum.IsolationLevelEnum の対応、複数 Dam の使い分けを扱う。トランザクション制御 / トランザクション パターン / トランザクション グループ / TCDefinition / InitDam / GetTransactionPatterns / 接続文字列の切り替え / 分離レベルの定義 を伴う作業のときに使う。B層の実装と分離レベルの指定は opentouryo-layer-b を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# トランザクション制御機能

> 📋 **コピー元スニペット**：`references/snippets.md`（InitDam/GetTransactionPatterns・TCDefinition.xml・MyAttribute。実装時はここから写す）。

## このスキルの適用範囲

`TCDefinition.xml` の書式と、`InitDam` / `GetTransactionPatterns` による Dam の初期化。

B層の実装（`DoBusinessLogic` の分離レベル指定、`UOC_ConnectionOpen`）は
`opentouryo-layer-b` を参照。

## 何のための機能か

**接続文字列と分離レベルの組み合わせに「パターンID」という名前を付け、コードからは
その名前だけで Dam を初期化できるようにする。** 接続先や分離レベルを変えたいとき、
コードを触らず定義ファイルだけを直せる。

```csharp
BaseDam dam = new DamSqlSvr();
BaseLogic.InitDam("SQL_RC", dam);   // ← パターンIDを渡すだけ
this.SetDam(dam);
```

`InitDam("SQL_RC", dam)` は `TCDefinition.xml` の `SQL_RC` を引いて、
`connkey` の接続文字列と `isolevel` の分離レベルで Dam を初期化する。
**接続文字列も分離レベルもコードに書かない。**

## 定義ファイル

パスは `appSettings` の **`FxXMLTCDefinition`** で指定する（`opentouryo-config` 参照）。
**ランタイムによらず XML のまま。**

**定義例（DTD 埋め込み・`TransactionPattern`/`TransactionGroup`）は `references/snippets.md`。** 要素・属性は下表。

| 要素・属性 | 内容 |
| --- | --- |
| ルート要素 | `TCD` |
| `TransactionPattern` の `id` | パターンID。**XML の `ID` 型** |
| `TransactionPattern` の `connkey` | 接続文字列のキー（`connectionStrings` セクションのキー名） |
| `TransactionPattern` の `isolevel` | 分離レベル。**2文字の略号**。既定は `rc` |
| `TransactionGroup` の `id` | グループID。**XML の `ID` 型** |
| `TransactionGroup` の `value` | パターンIDをカンマ区切りで並べる |

### id の先頭に数字を使えない

`id` は XML の `ID` 型なので、**先頭に数字を使えない**。

### DTD を省かない

**DTD を埋め込んだ形式。** 他の OpenTouryo の XML 定義ファイルと共通の作法。

## isolevel の略号

`DbEnum.IsolationLevelEnum` に対応する（`opentouryo-layer-b` 参照）。

| 略号 | 分離レベル |
| --- | --- |
| `nc` | コネクションしない（`NotConnect`） |
| `nt` | ノー トランザクション（`NoTransaction`） |
| `uc` | リード アン コミット（`ReadUncommitted`） |
| `rc` | リード コミット（`ReadCommitted`）**既定** |
| `rr` | リピータブル リード（`RepeatableRead`） |
| `sz` | シリアライザブル（`Serializable`） |
| `ss` | スナップ ショット（`Snapshot`） |
| `df` | デフォルト（規定の分離レベル。`DefaultTransaction`） |

**各レベルが防ぐ現象（ダーティ/反復不可/ファントム）・MVCC vs ロック法の DBMS 差・`READ_COMMITTED_SNAPSHOT`** は `opentouryo-app-design/references/data-access-design.md`（分離レベルの基礎）。

**`User` に対応する略号は無い。** `User` は親クラス2 が既定の分離レベルへ振り替えるための
マーカーで、Dam へ渡らない（`opentouryo-layer-b` 参照）。

## トランザクション グループ

**パターンIDをまとめて取り出すための束ね。** 同じ処理を複数の分離レベルで試す、
複数 DB へ同時に接続する、といった用途。`BaseLogic.GetTransactionPatterns("SQL", out patternIDs)` で
グループのパターンを取得し、各々を `InitDam` → `SetDam(patternID, dam)`（キー付きで複数 Dam 保持）。**コードは `references/snippets.md`**。

`GetTransactionPatterns` / `InitDam` は `BaseLogic` の **`protected static`** メソッド。
**業務コード親クラス2・業務コードクラスから呼べる。**

**キー付き `SetDam(key, dam)` で 2本目以降の接続を「管理下」に追加でき、フレームワークが `_dams`（`Dictionary<string,BaseDam>`）の
全 Dam を一括コミット／ロールバックする**（サーバ側 `BaseLogic`）。★ **2CS の `BaseLogic2CS` はキー付き `SetDam` を持たず単一
`static _dam` のみ**。2CS で追加接続が要るときは `InitDam(パターン, dam)` で開けるが、コミット／クローズは手動（`CommitAndClose` は `_dam` だけ）。

## 高度なトランザクション操作（★ 非標準・逸脱は要相談）

既定は「B層完了時にフレームワークが自動でコミット／例外時のみロールバック」。以下は**標準の外**なので、
**採るなら標準化観点の例外認可を個別に検討**（`opentouryo-project-policy`）。**コードは `references/snippets.md`**。

- **手動トランザクション制御**：**B層なら `this.GetDam()`（管理下の Dam）の `BeginTransaction`/`CommitTransaction`/`RollbackTransaction`
  を自分で呼べば手動制御できる**（新規に Dam を生成しなくてよい）。**2本目以降の接続を追加するのは「キー付き Dam」（標準機能）**
  なので上の「トランザクション グループ」節を使う（ここで扱うのは既存 Tx の途中操作）。
- **分割コミット**：B層から `this.GetDam().CommitTransaction()` → `this.GetDam().BeginTransaction(iso)` で途中コミットして続行。
- **SAVEPOINT**：**プロバイダ固有**（例 Oracle）。`((DamManagedOdp)this.GetDam()).DamOracleTransaction` の
  `.Save("名")`／`.Rollback("名")`（実物では `DamOraClient` も `DamOracleTransaction` を公開）。
- **2フェーズコミット（分散トランザクション）は未サポート**。`TransactionScope` 対応の親クラス1 を作れば実現可能だが、
  需要が低く見送られている（＝現状は使えない）。

## やってはいけないこと

- **`InitDam()` に接続文字列や分離レベルを直接書く** — 渡すのはパターンID（`SQL_RC` など）。
  接続文字列と分離レベルは定義ファイル側にある
- **`isolevel` に `IsolationLevelEnum` の名前を書く** — 2文字の略号（`rc` / `sz` など）
- **`id` の先頭に数字を使う** — XML の `ID` 型なので不正
- **DTD を省く** — 埋め込み形式が前提
- **`TransactionGroup` の `value` に存在しないパターンIDを書く** — 実行時に解決できない
- **`FxXMLTCDefinition` の設定を忘れる** — パスを設定しないとファイルが読まれない
- **この XML を `appsettings.json` に移そうとする** — ランタイムによらず XML のまま
