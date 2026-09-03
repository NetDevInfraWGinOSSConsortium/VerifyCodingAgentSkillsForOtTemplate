---
name: opentouryo-daogen-cli
description: "OpenTouryo の D層自動生成ツール DaoGen_Tool（墨壺）を CLI（/CUI・非対話）で実行し、DB スキーマから Dao・DTO・SQL を生成する。エージェント/CI から起動できる（GUI を開かない）。2モードのパイプライン＝DAODEFGEN（スキーマ→D層定義情報 CSV。DB 接続要）→ DAOSQLGEN（定義 CSV＋テンプレート→Dao/DTO/動的SQL。DB 非接続）。引数仕様は /HELP が一次情報（本スキルは列挙しない＝二重管理を避ける）。エージェントが踏む罠＝パス区切りは / にする（\\ はエスケープで消える）・標準出力は PowerShell の *>&1 で受ける・/HELP か /CUI が無いと GUI が開いてハングする。Dao の自動生成 / 墨壺 / DaoGen_Tool の CLI / D層コード生成 / スキーマから Dao / 非対話で Dao 生成 を伴う作業のときに使う。ツールの取り出し・ビルドは opentouryo-project-setup-core の samples/daogentool.md、生成された Dao の使い方は opentouryo-dao-generated、動的 SQL(.xml) の書式は opentouryo-query-definition、DB は opentouryo-project-setup-db。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# DaoGen_Tool（墨壺）の CLI で D層を自動生成

セットアップで取り出した **DaoGen_Tool（D層自動生成ツール＝墨壺）を `/CUI`（非対話）で実行**し、DB スキーマから
**Dao・DTO・SQL** を生成する。GUI を開かないのでエージェント/CI から回せる。

- ツールの**取り出し・ビルド**は `opentouryo-project-setup-core` の `samples/daogentool.md`（`OT_Tools\DaoGen_Tool\` 配下・restore 要）。
- 生成された **Dao の使い方**（`S1_Insert`/`D3_Update` 等・名前空間）は `opentouryo-dao-generated`。
- 生成物の**動的 SQL（`.xml`）の書式**（`ROOT`/`WHERE`/`IF`/`LIST`/`PARAM`/`DIV`）は `opentouryo-query-definition`。

## 前提：CLI がある ref か（無ければフォールバック）

**CLI（`/CUI`・`/HELP`）は比較的新しい追加**（DaoGen の `Program.cs`）。取り出した ref が**それより古いと GUI のみ**で、
非対話実行できない。その場合は生成せず、**既存の事前生成 Dao を流用する**（`opentouryo-dao-generated` の該当節）。
`/HELP` が通れば CLI あり（下記）。

## まず `/HELP`（引数の一次情報）

**引数仕様は `/HELP` が正**。本スキルは引数一覧を列挙しない（二重管理を避ける）。**引数を組み立てる前に必ず `/HELP` を実行する。**

- **exe 名はプロジェクト名と違う＝`OpenTouryo.DaoGen_Tool.exe`**（`DaoGen_Tool.exe` ではない）。場所：
  net48＝`OT_Tools\DaoGen_Tool\bin\Debug\OpenTouryo.DaoGen_Tool.exe`／
  core＝`OT_Tools\DaoGen_Tool\bin\Debug\net10.0-windows7.0\OpenTouryo.DaoGen_Tool.exe`。

```powershell
$exe = "OT_Tools\DaoGen_Tool\bin\Debug\net10.0-windows7.0\OpenTouryo.DaoGen_Tool.exe"  # net48 は …\bin\Debug\
& $exe /HELP *>&1 | Out-File help.txt     # ★ 標準出力は *>&1 で受ける（下の罠 b）
```

`/HELP` から得る：起動切替（引数なし＝GUI／`/HELP`／`/CUI`）・`/CUI` の共通引数（`/MODE <DAODEFGEN|DAOSQLGEN>`）・
各モードの必須/任意引数・終了コード・パス区切りと `/PRIMARYKEYS` の書式。

## 2モードのパイプライン（連続で使う）

`DAODEFGEN` が出力した**定義 CSV** を `DAOSQLGEN` の入力にする。

- **`DAODEFGEN`**：DB のスキーマ → **D層定義情報（`*.csv`）**。**DB 接続が要る**（Northwind 等＝`opentouryo-project-setup-db`）。
- **`DAOSQLGEN`**：定義 CSV ＋ テンプレート → **Dao(`.cs`)・DTO・動的 SQL(`.xml`)・静的 SQL(`.sql`)**。**DB には接続しない**（テンプレート選択にのみ `/DAP` を使う）。
- **定義 CSV は中間ファイル＝Excel で編集できる**（2フェーズの間に対象の絞り込み・主キー調整ができる。ヘッダ行の扱いは `/NOHEADER`）。
- **主キーは SQL Server / Oracle は自動取得**（複合主キーもそのまま取得）。**それ以外の DBMS や、PK を持たないビューは `/PRIMARYKEYS <T:C|C,…>` で指定**する（`/HELP`）。
- **★ スペース入りテーブル名も扱える**（例 `/TABLES "Order Details"`＝クラス名は `_` 置換で `DaoOrder_Details`・生成 SQL は `[Order Details]` とブラケット）。

```powershell
$work = "C:/temp/daogen"        # ★ 出力先は / 区切り（下の罠 a）
New-Item -ItemType Directory -Force "$work/gen" | Out-Null   # ★ DAOSQLGEN の /OUTPUT フォルダは事前に作る（下の罠 b）
# スキーマ → D層定義 CSV（DB 接続要）
& $exe /CUI /MODE DAODEFGEN /OUTPUT "$work/DaoDef.csv" /DAP SQL /TABLES "Shippers,Orders"
# 定義 CSV → Dao/DTO/SQL（DB 非接続。/TEMPLATE にテンプレート ルート）
& $exe /CUI /MODE DAOSQLGEN /DAODEF "$work/DaoDef.csv" /TEMPLATE "<DGenTemplates のパス>" /OUTPUT "$work/gen" /DAP SQL /LANG CS /ENTITY
```

※上の引数は例。**実際の必須/任意・既定値は `/HELP` で確認**する（`/MODE` の既定は `DAOSQLGEN`）。
- **★ 罠 b：`DAOSQLGEN` の `/OUTPUT` フォルダは事前に存在していないと失敗する**（`出力ファイル…のルート フォルダが存在しません。`＝
  終了コード 2）。`DAODEFGEN` の `/OUTPUT` はファイル指定で親フォルダがあれば足りる＝**挙動が非対称**。DAOSQLGEN 前に `New-Item -ItemType Directory -Force` で作る。

## ★ エージェントが踏む罠（3つ・README 実測）

- **(a) パス区切りは `/` にする。** コマンド解析（`StringVariableOperator.GetCommandArgs`）は **`\` をエスケープ文字として扱い、`\` が消える**
  ＝別パスに解釈される。`"C:/temp/out"` か `"C:\\temp\\out"` は OK、**`"C:\temp\out"` は NG**。
  **★ これは終了コードで検出できない**（`\` でも処理は成功し `0` が返るが、出力が別の場所に出る）＝**生成物の実在を必ず確認する**。
  PowerShell から渡すなら `$out = (...).Replace("\","/")`。
- **(b) 標準出力は PowerShell のリダイレクトで受ける。** 本ツールは `WinExe` で、CUI 時に `AttachConsole(-1)` で接続するため、
  **`& $exe … *>&1 | Out-File $out` は取れる**が、**`cmd /c "$exe … > $out"` は 0 バイト**（取れない）。
- **(c) `/HELP` も `/CUI` も無いと GUI が開いてハングする**（`Application.Run(new Form1())`）。**必ずどちらかを付ける**。

## 前提物

- **接続文字列・作成者名（裏の I/F＝ツール自身の config）**：CLI 引数（`/CONNSTR`・`/FAMILYNAME`・`/PERSONALNAME`）を省くと、
  **DaoGen_Tool 自身の config**（net48＝`app.config`／core＝`appsettings.json`。**exe と同じフォルダ**。**アプリの config とは別物**）の
  **`ConnectionString_<code>`**（`/DAP` に対応。実測 net48＝`SQL`/`OLE`/`ODBC`/`ODP`/`MCN`・core＝`SQL`/`ODBC`/`ODP`/`MCN`/`NPS`）・`FamilyName`・`PersonalName` を使う。
  → **`DAODEFGEN`（DB 接続要）は、`/CONNSTR` かツール config の `ConnectionString_<DAP>` のどちらかが有効な接続先**であること（DB は `opentouryo-project-setup-db`）。
- **テンプレート**：`/MODE DAOSQLGEN` の `/TEMPLATE` に**テンプレート ルート フォルダ**（`DGenTemplates`＝`DaoTemplate*.cs`・`.sql`・`.xml` が平置き）を渡す。
  **★ 生成 Dao の名前空間・親クラス2 名（既定 `MyBaseDao`）・主キー接頭辞（既定 `PK_`）・コメント ヘッダ・参照系メソッドはテンプレートで決まる**（`/NAMESPACE` 等の引数は無い）。
  → **引数（表 I/F）・ツール config（裏 I/F）で足りるものはそれで済ませ、引数の無い項目のカスタマイズが要るときの最終手段がテンプレ修正**
  （自プロジェクトの名前空間化 等。`opentouryo-dao-generated` / 纏め者）。所在はセットアップ構成に依る（`samples/daogentool.md` / `/HELP`）。
- **DB**：`DAODEFGEN` はスキーマを読むため接続が要る（`opentouryo-project-setup-db` の Northwind 等）。`DAOSQLGEN` は不要。

## 判定

**終了コードと生成物の両方で判定する**（罠 a のとおり exit 0 でも出力先が違うことがある）。**終了コード＝`0` 成功／`1` 引数エラー／`2` 生成エラー**（詳細は `/HELP`）。生成物：

- `DAODEFGEN` … 定義 CSV に対象テーブルが並んでいる。
- `DAOSQLGEN` … **テーブルごとに Dao(`.cs`)×1・SQL×8**（静的/動的の CRUD）が揃っている（`/ENTITY` 時は DTO も）。
- **★ 生成 SQL 定義（`.sql`/`.xml`）が `resource\Sql` 同梱物と同名のことがある**（ヘッダ〔生成日・エンコーディング表記〕以外は同一）。**上書きは他サンプルに影響する**ので、**同名の同梱があるときは生成物のうち `.cs`（Dao クラス）だけ採用し、SQL 定義は同梱を使う**。

## やってはいけないこと

- **引数一覧を記憶・決め打ちで組む** — `/HELP` を一次情報にする（本体の更新で変わりうる）。
- **`\` 区切りのパスを渡す** — `/` にする（消えて別パスに出力。exit 0 でも失敗）。
- **`cmd /c ">"` で標準出力を取ろうとする** — 0 バイト。PowerShell `*>&1 | Out-File` で受ける。
- **引数なし／`/CUI` 無しで起動する** — GUI が開いて非対話で固まる。
- **生成物の実在を確認せず終了コードだけで OK とする** — 両方で判定する。
