---
name: opentouryo-project-setup-config
description: "OpenTouryo 新規立ち上げ（opentouryo-project-setup）の ⑥⑦。取り出したサンプルを動く状態にする仕上げ：root/files/resource をリポジトリ直下へ移設し config のパスを環境変数方式（%OT_RESOURCE_ROOT%）へ張り替える、.gitignore を置く、接続文字列・core の InitConfiguration・nuget restore・sessionState(StateServer) など残りの構成を整え、ビルドと IIS Express 実行で検証する。resource 移設 / config パス張替 / OT_RESOURCE_ROOT / .gitignore / 接続文字列 / sessionState / 実行検証 / IIS Express を伴う作業のときに使う。前工程は取り出しと参照張替 opentouryo-project-setup-core、設定キーの一般解説は opentouryo-config。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# ⑥⑦ resource 移設・config パス張替・検証

新規立ち上げ（`opentouryo-project-setup`）の仕上げ。前提：④⑤で取り出し・参照張替が済み
（`opentouryo-project-setup-core`）、ソリューションが開ける状態になっている。ここで**動く状態**にする。
設定キーの一般解説は `opentouryo-config`。

## ⑥ リソース（resource）の移設と config パスの張り替え

**サンプルの config はリソースを絶対パス `C:\root\files\resource\...` で参照している。** 動かすには：

1. OpenTouryo の **`root/files/resource`**（`Log` / `Sql` / `Xml` / `X509` / `Test`）を導入リポジトリ**直下**へ
   コピーする（展開済み ZIP から。＝リポジトリ直下に `resource\` ができる）。
2. `app.config` / `appsettings.json` の**パス系キーを環境変数方式 `%OT_RESOURCE_ROOT%\...` に張り替える**
   （絶対 `C:\root\files\resource\...` から。**相対パスは不可**。既設と衝突するなら番号付き `%OT_RESOURCE_ROOTn%`＝例 `%OT_RESOURCE_ROOT1%`）。
3. **ログ定義ファイル `resource\Log\*.xml`（`SampleLogConf.xml` 等）の出力先パスも同様に張り替える**——ただし
   **張り替えなくても起動する**（`<param name="File" value="C:\root\files\resource\Log\...">` が残ってもログが旧パスへ出るだけ＝一部設定は空/誤りでも起動）。
   ここは `%OT_RESOURCE_ROOT%` が効かず log4net の `%env{}`（`<file type="log4net.Util.PatternString" value="%env{OT_RESOURCE_ROOT}\Log\...">`）を使う。詳細は下記。

**機構の詳細は `references/resource-config.md`**（相対不可＝`ResourceLoader` フルパス前提・`%VAR%` 展開が
`FxContainerization` と別機構・パス系キー一覧・綴りの罠 `Xml`/`Test`・net48 Web の config 二段）。Fx キーは `opentouryo-config`。

## ⑦ .gitignore・残りの構成と検証

- 接続文字列（`ConnectionString_SQL` ほか。DBMS 選択は `actionType` 先頭。`opentouryo-p-call-business`）。
  **接続先のローカル DB が無ければ（選択式）`opentouryo-project-setup-db`** で Docker 一式を立てられる（既定はサンプルの
  `ConnectionString_SQL` と一致）。
- **core は `GetConfigParameter.InitConfiguration()` が必須**（`opentouryo-config`）
- **net48（`packages.config`）は msbuild の前に `nuget restore <sln>` が必須**（`/t:restore` では不可。
  `nuget.exe` は ZIP の `root\programs\nuget.exe` を流用）。core は `dotnet restore`（`dotnet build` に含む）。
- **セッション状態は `StateServer` のまま残す**（`InProc` に変えない）。StateServer は**セッションを
  シリアライズ可能に保ち、後の変更（out-of-proc 化・スケールアウト）が効く**（InProc にすると失う）。net48 は
  **ASP.NET State Service を起動**して使う（`root\files\bat\aspnet_state-stat.bat` で起動。未起動だと実行できない
  ＝ビルドは通る。**サービス起動はマシン全体の変更＝`SETUP-CHANGES.md` に記録**〔停止は `aspnet_state-stop.bat`〕）。
  **起動には管理者権限が要る**（非昇格の `Start-Service`／`.bat` は `Cannot open 'aspnet_state' service` で失敗）
  ＝**昇格できなければユーザに依頼する**（実行時のポストバック検証だけが要る場面は `run-verify` の一時 InProc を参照）。
  **core は StateServer 非対応**なので必要なら Redis 等。
- ビルドが通り、実行できることを確認する（net48＝msbuild／core＝`dotnet build`）。**ビルド成功＝動く、ではない**
  （初期化は `%OT_RESOURCE_ROOT%` を読むので実行して初めて ⑥ の成否が分かる）。WebForms の IIS Express 実行確認
  （SSL 回避・スモーク・500 の見方）は `references/run-verify.md`
- **★ WebForms は `.aspx`/`.master` を msbuild が検証しない**（`.cs` のみコンパイル）。マークアップのエラー
  （`Inherits` 綴り・`ContentPlaceHolderID` 不一致・`TagPrefix` 未登録・designer 宣言漏れ）は実行時まで出るので、
  **`aspnet_compiler.exe -v / -p <プロジェクトディレクトリ> -f <出力先>` で事前コンパイル検証する**
  （エージェント/CI では必須。`opentouryo-layer-p-webforms-screen`）

### `.gitignore` を置く

リポジトリ直下に `.gitignore` を生成する。**まず作業ツリー `Temp/`（③の ZIP 展開・基盤ビルド）を除外する。**
`Temp/` には**基盤ソース（`Frameworks/Infrastructure` ＝親クラス2 を含む）丸ごと**が入るが、
アプリ リポジトリはビルド済み DLL を参照するだけなので**丸ごとは取り込まない**のが正しい。
親クラス2 をカスタマイズする場合でも、**バージョン管理するのは修正差分だけ**
（`base2-overlay/` は除外せずコミットする。`opentouryo-base2-customize`）。

```gitignore
# OpenTouryo セットアップの作業ツリー（ZIP 展開・基盤ビルド。基盤ソース＝親クラス2 を含む）
Temp/

# .NET ビルド生成物
bin/
obj/
packages/
.vs/
*.user
```

- **`OpenTouryoAssemblies/`（ベンダした DLL）と `base2-overlay/`（親クラス2 の修正差分）は除外しない**。
  リポジトリに含めて、再セットアップ無しでビルドでき、修正差分も追跡できるようにする。
  **※ 検証/CI 用途では `OpenTouryoAssemblies/` を除外してもよい**（DLL は使い捨て＝クローン後に `scripts\setup-build.ps1` を回す前提。リポ肥大を避ける）。ただし **`base2-overlay/` は必ずコミット**（失うと DLL を再現できない）。既存 repo の `.gitignore` が `OpenTouryoAssemblies/` を除外していても、この方針なら矛盾しない＝どちらにするかは検収者判断。
- 既存の `.gitignore` があれば追記（重複行は避ける）。サンプル同梱の `.gitignore` があれば統合する。

検証まで通ったら、`opentouryo-project-setup` の「完了後（任意）」に従い、構成変更（`opentouryo-project-transform`）へ
進むか選ばせ、成果のコミットを促す。

## やってはいけないこと

- **マシン固有の絶対パス（`C:\root\files\...` や `D:\git\MyApp\resource\...`）を config に直書きする**
  — 環境変数方式（`%OT_RESOURCE_ROOT%\...`）にする。可搬性が失われ、クローンごとに壊れる
- **resource のパスを相対（`resource\...`）にする** — カレント ディレクトリ基準で解決され、
  IIS Express / w3wp では届かず実行時 500。環境変数方式にする
- **セッション状態を `InProc` に変える** — `StateServer` のまま残す（シリアライズ可能＝後の変更が効く）
- **作業ツリー `Temp/`（基盤ソース＝親クラス2 を含む）をコミットする** — `.gitignore` で除外する
