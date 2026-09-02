---
name: opentouryo-project-setup-db
description: "OpenTouryo アプリのローカル開発用データストア（SQL Server / MySQL / PostgreSQL / Redis / MongoDB）を Docker で立てる、opentouryo-project-setup の選択式（任意）の環境構築ステップ。LocalServicesOnDocker（NetDevInfraWGinOSSConsortium）を clone し Start-Services で起動・Stop-Services で停止する。既定（SQL Server 1433/sa/Northwind 等）が OpenTouryo サンプルの接続文字列と一致するので、多くは無改変で繋がる。⑦ config の接続確認・実行検証（run-verify）の DB 依存操作の前提を満たす。DB 構築 / データストア / Docker / ローカル環境 / SQL Server / Northwind / MySQL / PostgreSQL / 接続先 を伴う作業のときに使う。既存 DB があれば不要。接続キーの一般解説は opentouryo-config、DBMS 選択は opentouryo-p-call-business。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 環境（データストア）の構築 — 選択式（任意）

新規立ち上げ（`opentouryo-project-setup`）の**任意の環境構築ステップ**。OpenTouryo アプリが接続する
**ローカルのデータストアを Docker で用意**する。⑦ `opentouryo-project-setup-config` の接続確認や、
実行検証（`opentouryo-project-setup-config` の `references/run-verify.md`）の **DB 依存操作の前提**を満たす。

- **選択式**：**既に接続先 DB があるなら不要**（このスキルはスキップ）。ローカルにサッと一式を立てたいときに使う。
- 接続キーの一般解説は `opentouryo-config`、DBMS の選び方は `opentouryo-p-call-business`。

## 使うもの

**LocalServicesOnDocker**（NetDevInfraWGinOSSConsortium）：`SQL Server / MySQL / PostgreSQL / Redis / MongoDB` を
Docker でまとめて立てる構成。<https://github.com/NetDevInfraWGinOSSConsortium/LocalServicesOnDocker>

- **前提**：Docker（**Rancher Desktop** か **WSL2** のいずれか）。

## 取得と起動・停止

**clone 先は必ずユーザに確認する**（マシン固有＝エージェントが決めない）。**プロジェクト repo の外**に置くこと
（マシン全体のインフラ。成果物 repo に取り込むと汚染＋`.gitignore` 問題になる）を前提に、具体パスをユーザに聞いてから
clone する。clone したら**用途に合う起動スクリプトを実行**する。

- **★ まず既存の DB を試す**：**「ポートが空いているか」だけでなく「使える DB が既に応答するか」を先に確認**する。
  `localhost:1433` に**使える SQL Server（Northwind）が既に在るなら、それを使ってこのスキルはスキップ**する——
  **Docker とは別のネイティブ SQL Server が応答することがある**（実測：Docker デーモン停止中でも 1433 が `sa`/Northwind で応答した）。
  手順：`Test-NetConnection localhost -Port 1433` で疎通 → 続けて Northwind へ接続確認 → 繋がれば構築不要。塞がっていて別 DB なら別ポート/スキップ。
- **初回は数分**：SQL Server 2022（約 1.5GB）含む 5 イメージを pull する（時間・帯域・ディスクに余裕を）。

```powershell
# Windows（Rancher Desktop）— DB 初期化完了を待つ .ps1 を推奨（.bat は待たない）
.\Start-Services.ps1              # 起動＋各 DB 準備完了待ち＋localhost 到達確認（既定 = up）
.\Start-Services.ps1 ps           # 稼働状況（logs でログ追尾）
.\Start-Services.ps1 -NoPause     # 非対話（エージェント/CI）向け。入力ﾘﾀﾞｲﾚｸﾄ時は自動抑止だが明示が安全
.\Stop-Services.ps1               # 停止（内部で Start-Services.ps1 down）
```

`Start-Services.ps1` は `up`/`down`/`ps`/`logs`＋`-NoWait`/`-NoPause` を持ち、DB 準備完了待ち・破損時の自動作り直し
（永続無しゆえ無害）・localhost 到達確認まで実装済み。2行しか使わないのはもったいない。

```bash
# WSL2 — common_link を作ってから compose（★ 既存なら作らない＝2回目の create エラー回避）
docker network inspect common_link >/dev/null 2>&1 || docker network create --driver bridge common_link
docker compose up -d              # 起動
docker compose down               # 停止（4 DB は永続無しで毎回リセット＝後述）
```

WSL2 は冪等な `Start-Services_wsl2.ps1` / `Stop-Services_wsl2.ps1` の利用を推奨（手動 compose なら network は上記の冪等形で）。

- **★ 起動と停止は同じ系統でペアにする。** Rancher/Docker Desktop 系（`Start-Services.ps1`＝Windows ネイティブ docker）と
  WSL2 直（`Start-Services_wsl2.ps1`＝WSL 内 docker）は **docker インスタンスが別**で、コンテナも別々に存在する。
  片方で `up` して他方で `down` してもコンテナが見えず止まらない（＝二重起動やポート衝突の元）。
  **`Start-Services.ps1`↔`Stop-Services.ps1`／`Start-Services_wsl2.ps1`↔`Stop-Services_wsl2.ps1` を必ず対で使う**（系統を跨がない）。

## OpenTouryo との噛み合わせ（既定が一致）

**既定値が OpenTouryo サンプルの接続文字列とほぼ一致**する（同系プロジェクト。多くは無改変で繋がる）。

| サービス | ポート | ユーザ / パスワード | DB | OpenTouryo 側 |
| --- | --- | --- | --- | --- |
| SQL Server | 1433 | `sa` / `seigi@123` | `Northwind` | `ConnectionString_SQL`（サンプル既定と一致） |
| MySQL | 3306 | `root` / `seigi@123` | `test` | `ConnectionString_MCN`（一致）・`DamMySQL` |
| PostgreSQL | 5432 | `postgres` / `seigi@123` | `postgres` | `DamPstGrS`（接続文字列は用途に合わせ追加） |
| Redis | 6379 | — | — | キャッシュ等 |
| MongoDB | 27017 | `seigi` / `seigi@123` | — | — |

- **DBMS の選択は `actionType` の先頭**（`SQL%...` 等）＋対応する `ConnectionString_<code>`（`opentouryo-config` /
  `opentouryo-p-call-business`）。既定サンプルは SQL Server（`ConnectionString_SQL`）で動く。
- **Oracle は本 Docker に含まれない**（サンプルの `ConnectionString_ODP`＝SCOTT/tiger は別途 Oracle を用意する）。
- **サンプル固有の追加テーブルは Northwind に含まれない**：同梱 `CREATE *.sql` を別途流す
  （例：`RerunnableBatch_sample` の `ORDERS2`＝同梱 `CREATE ORDERS2.sql`。`run-verify.md` のバッチ/CLI 節）。
  **毎起動で消える**（下の「データは毎回リセット」）。
- 接続文字列を変える場合、機微情報の直書きを避ける方針は ⑥（`opentouryo-project-setup-config`）に従う。

## ★ データは毎回リセット（永続設定なし）

**この compose は 4 DB とも永続ボリュームを使っていない**（`docker-compose.yml` で mysql/postgres/sqlserver/mongo の
data マウントはコメントアウト）。**`-v` を付けなくても `down`→`up` でデータは残らない**（新コンテナ＝新規ボリューム）。
**残るのは `redis` だけ**（`./redis/data` をホストマウント）。「何が消えて何が残るか」をこの一点で押さえる。

- **Northwind の基本表は自動**：SQL Server は起動のたび `sqlserver/init/start-up.sh` が `CREATE DATABASE Northwind`＋
  `instnwnd.sql` を流し直す（＝基本表は毎回そろう。データ準備完了は `.ps1` がセンチネル表で待つ）。
- **サンプル固有表は手動・都度**：`instnwnd.sql` に無い表（例 `ORDERS2`）は**毎起動で消える → 起動のたびに流し直す**
  （＝「一度流せば済む」ではない）。この非対称（基本表＝自動／固有表＝手動）を前提に運用する。

## ★ グローバル変更として記録する

Docker の**コンテナ・ボリューム・ネットワーク（`common_link`）はマシン全体に残る変更**。**`SETUP-CHANGES.md` に記録**する
（AGENTS.md ポリシー）。例：`docker network common_link = 作成 ／ docker network rm common_link`、
`docker compose (LocalServicesOnDocker) = 起動 ／ docker compose down（停止。4 DB は永続無しで毎回リセット、redis のみ ./redis/data に残る）`。

## やってはいけないこと

- **`seigi@123` 等の既定資格情報を本番で使う** — これは**ローカル開発用**。本番は別の資格情報にする
- **接続文字列に機微情報を平文で残す** — 環境変数方式など（⑥ `opentouryo-project-setup-config`）
- **この Docker に Oracle を期待する** — 含まれない。Oracle が要るなら別途用意する
- **既存 DB があるのに重ねて立てる** — 選択式。接続先がある環境ではスキップする
