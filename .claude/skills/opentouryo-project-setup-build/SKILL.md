---
name: opentouryo-project-setup-build
description: "OpenTouryo の基盤（フレームワーク）DLL をローカルでビルドし、導入リポジトリの OpenTouryoAssemblies\\ へベンダするための手順。GitHub から指定 <ref>（固定タグ または develop）の ZIP を取得し、root/programs/CS の 2_/3_Build_* バッチを標的ランタイム分だけ実行して、Build_net48 / Build_netcore100 をベンダする。この Download→Build→ベンダを1本のセットアップ スクリプトに生成して実行する（.bat より PowerShell ラッパを推奨。非対話実行の落とし穴を回避）。net48 / net10.0 両対応。基盤ビルド / DLL 生成 / アセンブリのベンダ / OpenTouryoAssemblies / タグ更新で焼き直し / 再ビルド を伴う作業のときに使う。新規立ち上げ全体は opentouryo-project-setup（このスキルはその ③ の実装）、親クラス2 のカスタマイズは opentouryo-base2-customize。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 基盤 DLL のビルドとベンダ

## このスキルの適用範囲

**OpenTouryo の基盤（フレームワーク）DLL をローカルでビルドし、導入リポジトリの
`OpenTouryoAssemblies\` へベンダする**とき。`opentouryo-project-setup` の ③（新規立ち上げの一工程）
として呼ばれるほか、**タグ更新時の焼き直し**にも単独で使える。**1回実行すれば DLL は再利用でき**、
毎回ビルドする必要はない。

**ZIP 取得 → 基盤ビルド → `OpenTouryoAssemblies\` へベンダ**の3段を、**1本のセットアップ スクリプトに
生成して実行する**（その場限りのコマンド羅列にしない。再現・レビュー可能にし、リポジトリに残して
再セットアップに使う）。模範：MultiPurposeAuthSite の `root/programs/3_BuildLibsAtOtherRepos.bat`
（固定タグ）/ `3_BuildLibsAtOtherReposInTimeOfDev.bat`（develop）。

**生成した `.ps1` は `scripts/` フォルダに置く**（リポジトリ ルート直置きにしない＝ルートが散らかる）。
**スクリプト内の `$repo` はルート＝スクリプトの親**にする：`$repo = Split-Path -Parent $PSScriptRoot`
（`$PSScriptRoot` は `scripts\` 自身を指すため。相対 `HintPath` やベンダ先はルート基準なので親を採る）。
`$PSScriptRoot` 基準なので**どのカレントディレクトリからでも実行可**（`.ps1` として実行すること・`scripts\` はルート直下1階層）。

### 入力

| 入力 | 意味 |
| --- | --- |
| `<ref>` | 取得元。**固定タグ**（安定運用。具体的なタグは**ユーザに確認**。`03-20` はあくまで例示で既定値ではない）または **`develop`**（最新追従）。呼び出し元／ユーザが決める |
| 標的ランタイム | net48 / net10.0 / 両方。**選んだサンプルが対象とするランタイムだけ**をビルドする |
| `base2-overlay/` の有無 | 親クラス2 をカスタマイズしているか（あれば固定タグ必須。後述） |

## 1. ZIP 取得（`git clone` ではない）

`https://github.com/OpenTouryoProject/OpenTouryo/archive/<ref>.zip` を取得し、
**作業ツリー `OpenTouryo-<ref>\`** に展開する（基盤ソースを含むビルド用の作業場）。
**取得は `Invoke-WebRequest` を使い、事前に TLS1.2 を明示する**
（`[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12`）。
`WebClient.DownloadFile()` は既定 TLS が古く **GitHub codeload に 404**（`HEAD` は 200 が返るので原因が紛れる＝実測）。

**★ `develop`（moving ref）は ZIP を消して取得を強制する**（`examples.md` の `-Redownload`）＝古い ZIP を焼くと**0 エラーで「再取得した」と誤報告**になる（`-Fresh` の作業ツリー作り直しとは別操作・実測）。

**作業ツリーの置き場所は MAX_PATH(260) を避けて選ぶ**（実測）。既定はリポジトリ直下の `Temp\` だが、
**リポジトリ パスが深いと net48 Business ビルドが `MSB3553` で失敗する**：生成物
`obj\...\MyBusinessApplicationExceptionMessageResource.ja-JP.resources` の完全修飾パスが 260 文字を超える。
→ **深いリポでは短い作業ルート（例 `C:\otr\`）でビルドする**か、long path を有効化する。**ベンダ後の DLL だけが
リポに入る**ので、作業ツリーの場所はリポジトリと無関係でよい（リポ直下に置くなら `Temp\` は ⑦ の `.gitignore` で除外）。
**リポ外 `C:\otr\` の作成や long path 有効化（`LongPathsEnabled` レジストリ）はマシン全体の変更＝`SETUP-CHANGES.md` に記録**（AGENTS.md ポリシー）。

### ★ 親クラス2 をカスタマイズするなら、短ルートの展開ツリーをワークスペースに加えて直接いじる（コピーバックは廃止）

**親クラス2 をカスタマイズする（`base2-overlay/` がある、またはこれから作る）なら、短ルート `C:\otr\` を
ワークスペースに追加し、そこの基盤ソースを直接編集・ビルドする。** カスタマイズ対象の基盤ソース
`Frameworks\Infrastructure`（特に `Business`）は、ビルドのために展開した
**`C:\otr\OpenTouryo-<ref>\root\programs\CS\Frameworks\Infrastructure` に既に在る**。

以前の「深いリポへコピーバック」は**実測で繰り返し抜けた**ので廃止し、**展開ツリーをそのまま作業場所にする**：短ルート `C:\otr` を
ワークスペースに追加し（VS Code なら「フォルダーをワークスペースに追加」）、絶対パス `C:\otr\...\Frameworks\Infrastructure` を直接読み書きする。

- **深いリポへコピーしない**（MAX_PATH でどのみち深いリポではビルドできない）。基盤ソースの作業実体は `C:\otr` 側、
  **リポにコミットするのは差分 `base2-overlay/` だけ**（展開ツリーは使い捨て。取得元は固定タグ＝再現性。`opentouryo-base2-customize`）。
- 長パスを有効化できるなら、リポ直下で展開・ビルドして**分離自体を無くす**のも可（その場合この節は不要。
  ただし `Frameworks/Infrastructure` はコミットせず `.gitignore`）。

## 2. 基盤ビルド

展開先の `...\root\programs\CS\` で `2_/3_Build_*` バッチを順に実行する。
**標的サンプルのランタイムのバッチだけ**を回す（無駄なビルドと失敗面を増やさない）：

```
# net48 標的（例：Web Forms / net48 MVC / net48 2CS）はこの2本だけ
call .\2_Build_NuGet_net48.bat    < nul
call .\3_Build_Business_net48.bat < nul

# net10.0 標的はこの2本だけ
call .\2_Build_NuGet_netcore100.bat    < nul
call .\3_Build_Business_netcore100.bat < nul
```

**両ランタイムに対応させる標的のときだけ4本すべて**を回す。前提ツール：**VS Build Tools**
（net48 は非 SDK csproj で msbuild が要る）と **.NET SDK**（core は `dotnet build`）。
**このバッチ名（net48 / netcore100）が正**。本体の `99_BuildLibsAtOtherRepos*.bat` は陳腐化して
`net45`〜`netcore30` を呼ぶので**参考にしない**。なお `2_Build_NuGet_net48.bat` は `Nuget_RichClient_net48.sln` も
必ずビルドするので、RichClient を使わない標的でも `OpenTouryo.Framework.RichClient.dll` 等が生成される（無害。
「標的ランタイムのバッチだけ」で絞れるのはランタイム粒度まで）。

**★ 本スキルが回す `2_/3_Build_*` サブセットには `OpenTouryo.Business.RichClient` が含まれない＝別 sln の追加ビルドが要る（実測）。**
**本体のフル一式**（`root\programs\CS` の各 bat を順次、またはまとめ役 **`root\programs\9_CICD.bat`**）を回せば
Business.RichClient も含め**全部ビルドされる**。本スキルは標的を絞って速くするため `2_/3_Build_*` だけを回す方針で、
そのサブセットに `BusinessRichClient_*.sln` が入っていないだけ（`2_/3_` で出る RichClient は `Framework.RichClient` まで＝
本体の欠陥ではない）。**2CS（`2CSClientWin/WPF`）・3層リッチクライアント（`WSClient_*`）系のサンプルは
`OpenTouryo.Business.RichClient`（`MyFcBaseLogic2CS` 等）を参照する**ので、`BusinessRichClient_net48.sln`
（core は `_netcore100`）を追加でビルドしないと `CS0246`。**base2 カスタマイズの有無と無関係＝素の依存**
（親クラス2 を 2CS カスタマイズする場合も同じ sln。`opentouryo-base2-customize`）。→ **RichClient 系サンプルなら ③ に
このビルドを足す**（`examples.md` の 2b＝`setup-build-richclient.ps1` 相当。フル一式で回すなら不要）。

**★ netcore は欠落範囲がさらに広い（実測）。** `net10.0-windows7.0\` は標準 `2_/3_Build_netcore100` 直後だと
**`OpenTouryo.Business` と `Dam*`（`DamManagedOdp`/`DamMySQL`/`DamPstGrS`）まで無い**（`net10.0\` にはある）。
`3_Build_BusinessRichClient_netcore100.bat` がこれらと `Business.RichClient` をまとめて生成するので、**`net10.0-windows7.0\` を
丸ごと再ベンダ**する（拾い漏らすと `OpenTouryo.Business` で `CS0246`）。

**★ RichClient sln は2プロジェクト＝出力を1つずつ照合する（実測）。** net48 の `BusinessRichClient_net48.sln` は
`Business.RichClient` と **`CustomControl.RichClient`**（`CustCtrl_sample`＝WinForms カスタムコントロール デモが要る）の2つを生成する。
標準ベンダで WinForms 版 `CustomControl.RichClient.dll` が漏れやすい（netcore 側は元々揃う）。→ **RichClient 追加ビルド後は
sln の全出力を照合して両方ベンダする**（スクリプト化＝`examples.md` の RichClient 2 DLL 照合）。

### エージェント/CI では PowerShell ラッパを既定にする（推奨）

スクリプトは `.bat` でも PowerShell でもよいが、**非対話実行では PowerShell ラッパを既定に推奨**する
（子の基盤ビルド `.bat` は `cmd /c` で呼ぶ）。下記の落とし穴（`pause` / ASCII / `.\` / 括弧 / MSYS パス変換）を
一括で避けられる。**Bash/MSYS から `cmd //c ".\x.bat"` で叩くのは避ける**（次項）。

**実機で通した雛形2本（MAX_PATH・exit code 不信・WS 配置を織り込み済み）を同梱の
[`examples.md`](examples.md) に置く**（`setup-build.ps1`＝本スキル、`build-app.ps1`＝アプリ側ビルド）。生成の出発点にできる。

### 生成スクリプトの実環境での注意（非対話実行で顕在化。実機検証済み）

- **末尾 `pause`** — バッチ末尾に `pause` があり、非対話だと入力待ちで止まる → `< nul` で標準入力を塞ぐ。
- **`.\` を明示** — `NoDefaultCurrentDirectoryInExePath=1` の環境では `.\` 無しの `call` が「認識されない」で失敗。
- **.bat のコメント／`echo` は ASCII 限定** — UTF-8（`chcp 65001`）だと全角コメント行を `cmd` が破損させ、`%変数%` 展開ごと壊す。
- **`.ps1` を `powershell.exe`（WinPS 5.1）で実行するなら日本語コメントは ASCII 化／BOM 付き保存／`pwsh`(PS7) 実行のいずれか**
  （実測）。BOM 無しを 5.1 は Windows-1252 で読み、UTF-8 全角コメントが**直後の文を巻き込んで無効化**（`$ref` が空→
  `archive/.zip` を取得＝**「DL 404」に化けて**原因が紛れる）。`examples.md` の雛形はコメントを ASCII 化済み。
- **`if(...)` ブロック内 `echo` の未エスケープ `)`** — ブロックが早期に閉じ、後続の `goto :error` が無条件実行される
  （＝ビルド成功でも Step 3 で必ず失敗して見える）。`echo` 内の `)` は `^)` にエスケープする。
- **Bash/MSYS 経由の `cmd //c ".\x.bat"`／`msbuild /p:...`** — Windows パス風の引数が MSYS に変換される。`.bat` では
  `cmd` の `if exist "D:\..."` が実在フォルダを MISSING と誤判定し、**`msbuild` では `/nologo` が `C:/Program Files/Git/nologo` に、
  `/p:` が別プロジェクト指定に化けて `MSB1008`**（実測）。**PowerShell から `cmd /c`／`& $msb` で実行する**と正常（上の推奨）。
- **exit code は両方向に信用できない（偽の成功）** — これらのバッチは末尾 `pause` で、**msbuild が失敗しても
  バッチ自体は exit 0** を返す（`MSB3553` 等で失敗しても `cmd /c` の戻りは 0）。前述の未エスケープ `)` は逆に
  「偽の失敗」。**成否は exit code ではなく、生成物 DLL の実在で判定する**（下の §3 の確認を必ず行う）。

### VS のエディション・バージョンによる msbuild 解決（利用側で対処する）

本体の `z_Common.bat` は msbuild 検出で **VS18 系は `18\Community` しか見ない**（VS2022 までは
Community/Professional/Enterprise を網羅）。VS18 の BuildTools/Professional/Enterprise だけの環境だと
`BUILDFILEPATH` が空になり基盤ビルドが失敗する。**本体はエージェント/CI や新しい VS エディションでの
非対話ビルドまでは想定していない**ので、これは本体の不具合ではなく**利用側（このセットアップ）で対処する前提**：
ビルド前に msbuild が解決できることを確かめ、解決できなければ Community を入れる／msbuild のパスを通す
／`z_Common.bat` に自環境のパスを補う、などで通す。

### 親クラス2 をカスタマイズしている場合

リポジトリに `base2-overlay/` があるなら、`3_Build_Business_*` の**前に**オーバーレイを展開ツリーへ上書きする
（`xcopy /Y /E base2-overlay\* <extract>\root\programs\CS\`）。この場合、取得元 `<ref>` は**固定タグ**にする
（`develop` は土台が動いて再現性を失う。`opentouryo-base2-customize`）。カスタマイズが無ければ不要。

## 3. ベンダ

生成物を導入リポジトリへコピーする（`xcopy /Y /E`）。**コピー元の起点は展開先の `root\programs\CS\` 配下**
（`Build_*` はここに生成される。起点を省くと存在しないパスになる）。

```
<extract>\root\programs\CS\Frameworks\Infrastructure\Build_net48      → <repo>\OpenTouryoAssemblies\Build_net48\
<extract>\root\programs\CS\Frameworks\Infrastructure\Build_netcore100 → <repo>\OpenTouryoAssemblies\Build_netcore100\
```

（`<extract>` は手順1の作業ツリー `OpenTouryo-<ref>`。）**1回実行すれば DLL は再利用できる**（毎回ビルドしない）。

**ベンダ後、成否を生成物の実在で確認する**（バッチの exit code は当てにならない＝上の「偽の成功」）。
少なくとも **`OpenTouryo.Business.dll`**（Business ビルドの生成物で、`MSB3553` 等で最も失敗しやすい）が
ベンダ先にあることを確かめる。無ければビルドは失敗している（ビルド出力を確認する）。

**★ 確認パスはランタイムで違う**：net48 は `Build_net48\` 直下（平坦）だが、**core は `Build_netcore100\<TFM>\`
（`net10.0\`・`net10.0-windows7.0\`）配下**でベンダ先直下に無い＝**直下確認だと core は必ず偽の失敗**。core は
`net10.0\OpenTouryo.Business.dll` か `-Recurse` で確認する（`examples.md` netcore 雛形）。

**★ ベンダした `<ref>`・ランタイム・実施日を `OpenTouryoAssemblies\build-ref.txt` に記録しコミット**（無いと後で
`opentouryo-project-policy` が上流ソースを引けない。**moving ref は取得 ZIP のハッシュも併記**〔`examples.md`〕）。

## やってはいけないこと

- **`git clone` で取ってくる** — ZIP 取得（`archive/<ref>.zip`）にする。作業ツリーはコミットしない
- **標的でないランタイムまでビルドする** — 標的サンプルのランタイム分だけ回す（両対応が要るときだけ4本）
- **アドホックなコマンド羅列で済ませる** — スクリプト化して **`scripts/` に**残す（ルート直置きにしない）
- **作業ツリー `Temp/`（基盤ソース＝親クラス2 を含む）をコミットする** — `.gitignore` で除外
- **`base2-overlay` があるのに `develop` で焼く** — 固定タグにする（再現性）
- **★ 素の ref をビルドするのに、前回 overlay を適用した展開ツリーを再利用する** — 前回の親クラス2 改変が残り
  **素でない DLL がベンダされる**（差分はビルド結果に出ず気付けない）＝**overlay 無しの素ビルドは展開ツリーを作り直す**（`examples.md` の `-Fresh` 相当）
- **★ 親クラス2 をカスタマイズするのに、短ルートの展開ツリーをワークスペースに入れない** — 基盤ソースは
  `C:\otr\OpenTouryo-<ref>\...\Frameworks\Infrastructure` に在る。深いリポへコピーせず、**短ルートをワークスペースに
  追加して直接いじる**（§1。コピーバックは実測で繰り返し抜けたため廃止）
