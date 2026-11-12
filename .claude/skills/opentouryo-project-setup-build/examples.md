# 参考：as-built セットアップ スクリプト（PowerShell 雛形）

実環境（WebForms_Sample / net48 / 固定タグ `03-20` / 深いリポ パス）で**実際に通した2本**。
本スキルが推奨する「生成スクリプトをリポジトリに残す・`.bat` より PowerShell ラッパ」の具体例で、
既知の落とし穴（MAX_PATH＝短い作業ルート、exit code 不信＝DLL 実在で判定、`.\`＋`< nul`、
**出力を `Select-Object -First N` で絞らない**〔下記〕、
**2CS＝`Business.RichClient` の別 sln**、**ツールの `PackageReference` restore**）を織り込み済み。
（※`build-app.ps1` は参照方式の更新に合わせて改訂：`WSServer_sample`/`WSIFType_sample` は ProjectReference＝
1ソリューション一括ビルド。旧「WS を別ビルドして `WS_sample\Build\` へコピー」は不要。`samples/webservices.md`。）

**これらは `scripts/` フォルダに置く**（ルート直置きにしない）。そのため各スクリプトの `$repo` は
**スクリプトの親＝リポジトリ ルート**を指す（`$repo = Split-Path -Parent $PSScriptRoot`。`$PSScriptRoot` は `scripts\` 自身）。

`$PSScriptRoot` は**スクリプト ファイルの場所**を指し**カレントディレクトリに依存しない**ので、
`cd scripts; .\setup-build.ps1` でもルートから `.\scripts\setup-build.ps1` でも同じく動く。ただし
**(1) `.ps1` ファイルとして実行する**（コンソールへ貼り付け実行だと `$PSScriptRoot` が空＝`$repo` が壊れる。dot-source は可）／
**(2) `scripts\` はリポジトリ ルート直下の1階層**に置く（`Split-Path -Parent` が1階層だけ上がる前提。深くしない）。

**雛形化する際は `$ref`・パス・標的ランタイム（net48）をパラメタ化**する。フラット化しない
（配置維持）方針なら相対パスは配置に合わせて変える。**as-built の雛形なので、環境に合わせて調整する**
（Configuration・restore 方式・msbuild 解決など）。

## ★ 実行時の罠：出力を `| Select-Object -First N` で絞らない（スクリプトごと止まる）

これらのスクリプトを `... | Select-String … | Select-Object -First N` のように**出力を絞って**実行すると、
PowerShell は上流パイプラインを**停止**するため、**スクリプトが途中で終了**する（例外は出ない＝静かな失敗）。実測2件：

- `setup-build.ps1`：overlay 適用と `2_Build_NuGet` は流れたが **`3_Build_Business` に到達せず**、DLL が更新されないまま「成功したように見えた」（DLL のタイムスタンプで気付いた）。
- `prune-csproj.ps1`：`pruned: N` と表示されたのに **`$xml.Save()` に到達せず csproj は無変更**（直後のビルドが `CS2001` 大量で落ちて初めて気付いた）。

→ **長い出力は `Out-File` に落として後から grep する**（`Select-Object -First N` で絞らない）。上の「exit code 不信＝生成物の実在／タイムスタンプで判定」原則は、まさにこの事故を検出してくれる。

## ★ 実行時の罠：`.ps1` の BOM は「通った＝安全」で判断しない（文字依存）

SKILL 本文どおり、日本語コメントを含む `.ps1` を WinPS 5.1 で走らせるなら **BOM 付き保存／ASCII 化／`pwsh` 実行**のいずれかが要る。
**★ 壊れるかは含む文字に依存する**：仮名・漢字だけの行は偶然通ることがあるが、**`★`(U+2605) 等の記号を含む行**で 5.1 が BOM 無し UTF-8 を誤読し、
**文字列の閉じ引用符を飲み込んで `The string is missing the terminator: "` でスクリプト全体が構文エラー**になる（実測）。
→ **「最小再現で壊れなかった＝予防措置で十分」と結論づけない。** 規約どおり BOM を付ける（`opentouryo-comment-convention` の「書き直したら毎回 BOM 確認」も同旨）。

## ★ 2ランタイムを1本に：`-Runtime` 引数化

下の2本（`setup-build.ps1`＝net48／`setup-build-netcore.ps1`＝netcore100）は**大半が重複**する。混在 repo
（net48 済みに netcore100 を後から足す等）で毎回どちらを複製/改変するか迷わないよう、**`-Runtime net48|netcore100` の
1本に畳む**（実測でそう直した）。**net48 の `setup-build.ps1` があるリポに net10.0 を足すときは、別のファイル（`setup-build-netcore.ps1` など）を足さず、
その 1 本に `-Runtime` を足す**（実測：別ファイルにされた）。**RichClient（2CS・`WSClient_*`）も同じ**：`setup-build-richclient.ps1` などを足さず、
`-RichClient` を付けて同じ 1 本を回し直す（実測：別ファイルにされた。回し直すと展開ツリーを作り直して全部建て直す＝それでよい）。バッチ名・ベンダ先が規則的なので引数1本で導出できる：

```powershell
param([ValidateSet('net48','netcore100')][string]$Runtime = 'net48', [switch]$RichClient)
$needRichClient = [bool]$RichClient   # 2CS / rich client (WSClient_*) を取り出したら -RichClient を付けて回し直す
$vendor = Join-Path $repo "OpenTouryoAssemblies\Build_$Runtime"
# バッチは 2_/3_Build_*_$Runtime.bat（例 3_Build_Business_$Runtime.bat / 3_Build_BusinessRichClient_$Runtime.bat）
```

ただし**ランタイム固有の分岐は残す**：**確認パス**は net48＝`Build_net48\` 直下／core＝`Build_netcore100\<TFM>\`
（`net10.0\`・`net10.0-windows7.0\`）配下。**RichClient のビルド方式**は net48＝非SDK sln を `& $msb …/t:build`
（restore なし・obj パージ要）／core＝`.bat`。**core の欠落**は `net10.0-windows7.0\` が RichClient を回して初めて
`Business`/`Dam*` が揃う。以下は分かりやすさのため別々に載せるが、実運用は `-Runtime` 1本に畳んでよい。

- `setup-build.ps1` — 本スキル ①②③（ZIP取得 → net48 基盤ビルド → ベンダ）。短パス `C:\otr` でビルド、
  `OpenTouryo.Business.dll` の実在で成否判定。**親クラス2 をカスタマイズするなら任意ブロック**（overlay 適用＋
  2CS の `Business.RichClient` ビルド）を有効化する。
- `build-app.ps1` — アプリ側の取り出し後ビルド（`opentouryo-project-setup` ④⑤）。**取り出した sln を全部、この 1 本で建てる**
  （サンプルごとに別のスクリプト〔`build-webforms.ps1`・`build-wsclientwin.ps1` など〕を足さない。実測：毎回足された）。
  **サンプルを取り出したら、その sln をリストに 1 行足す**（Web 以外も。WSClient は `_all.sln`。WS ホストの packages の別途 restore も、ここに足す＝`samples/webservices.md`）。
  リストにある sln のうち、あるものだけを建てる。net48 は `nuget restore` → msbuild、core は `dotnet build`
  （`WSServer_sample`/`WSIFType_sample` は ProjectReference＝同ソリューションで同時に建つ）。vswhere で msbuild 解決。
  **開発支援ツールを取り出しているなら任意ブロック**（DaoGen/DPQuery のビルド）で欠落参照を早期に炙り出す。

## `setup-build.ps1`（ZIP取得 → net48 基盤ビルド → ベンダ）

```powershell
# Download archive/<ref>.zip -> build net48 base -> vendor to
# OpenTouryoAssemblies\Build_net48. Idempotent; re-run to refresh a tag.
$ErrorActionPreference = 'Stop'
$repo    = Split-Path -Parent $PSScriptRoot   # scripts\ に置く前提＝親がリポジトリ ルート
$ref     = '03-20'                       # fixed tag; set per project (ask the user which tag; not a default)
# Base build runs from a SHORT root (C:\otr), not <repo>\Temp: the legacy
# net48 Business build writes a very long generated .resources filename;
# under a deep repo path the fully-qualified path exceeds MAX_PATH (MSB3553).
# Only scratch/build output lives here; vendored DLLs land in <repo>.
$work    = 'C:\otr'
$zip     = Join-Path $work "OpenTouryo-$ref.zip"
$extract = Join-Path $work "OpenTouryo-$ref"
$cs      = Join-Path $extract 'root\programs\CS'
$vendor  = Join-Path $repo 'OpenTouryoAssemblies\Build_net48'
$overlay = Join-Path $repo 'base2-overlay'   # present only when customizing 親クラス2

# --- 1. ZIP acquisition (not git clone) ---
# ★ pristine-build guard: an extract tree that a PREVIOUS run OVERLAID (base2)
#   is reused as-is here and silently vendors a NON-pristine DLL (old OLE/ODBC or
#   handler removals persist; the diff never shows in build output). C:\otr is shared
#   by several repos and "was it overlaid?" cannot be judged (Copy-Item keeps the
#   timestamps), so ALWAYS re-extract. The overlay (if any) is re-applied in 1b.
#   ★ 作り直す前に、展開ツリーで直接直した親クラス2 を base2-overlay\ に写してあること（写していない改変は消える）。
$Fresh      = $true    # 毎回作り直す（既定。SKILL §1）。リポに前の回のスクリプトがあり -Fresh がスイッチ（既定 off）なら、-Fresh を付けて呼ぶ（実測）
$Redownload = $false   # ★ moving ref (develop) 用：set $true で <ref>.zip を消してから取得（展開ツリーも道連れ）。
                       #   計画が「既存」の ZIP を使うと言うときは $false のまま（ハッシュは build-ref.txt に残る）
New-Item -ItemType Directory -Force -Path $work | Out-Null
# ★「作業ツリーの作り直し」($Fresh) と「ZIP の取り直し」($Redownload) は別操作。
#   develop のような moving ref は $Redownload を付けないと、上流が動いても古い ZIP が使われ続ける
#   （0 エラーでビルド・ベンダは通り「再取得した」と誤報告になる）。固定タグは不変なので $false でよい。
if ($Redownload) { Remove-Item $zip, $extract -Recurse -Force -ErrorAction SilentlyContinue }
if ($Fresh -and (Test-Path $extract)) { Remove-Item $extract -Recurse -Force }
if (-not (Test-Path $extract)) {
    if (-not (Test-Path $zip)) {
        # WebClient.DownloadFile() defaults to an old TLS and gets 404 from GitHub
        # codeload (a HEAD returns 200, so it looks like the URL is fine -> misleading).
        # Force TLS 1.2 and use Invoke-WebRequest instead.
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://github.com/OpenTouryoProject/OpenTouryo/archive/$ref.zip" -OutFile $zip
    }
    Expand-Archive -Path $zip -DestinationPath $work -Force
}
$zipHash = (Get-FileHash $zip -Algorithm SHA256).Hash.Substring(0,12)   # ref=develop は成果物を同定しないので build-ref.txt に残す

# --- 1b. apply base2 overlay BEFORE building (NOT optional: if base2-overlay\ exists it MUST be applied) ---
# If this repo customizes the framework Business layer, its edited *.cs live in
# base2-overlay\ as FILE-LEVEL copies (not patches). Overwrite the extract tree
# with them before the build. Copy-Item preserves bytes incl UTF-8 BOM (the base
# sources are UTF-8 BOM with Japanese comments); xcopy on a folder would also
# prompt F/D. Requires a FIXED $ref (develop moves the base under the overlay).
if (Test-Path $overlay) {
    Copy-Item -Path (Join-Path $overlay '*') -Destination $cs -Recurse -Force
}

# --- 2. Base build (net48 only: the two bats the skill specifies) ---
# pause at bat end -> feed NUL; run from CS so relative paths resolve.
Push-Location $cs
try {
    cmd /c ".\2_Build_NuGet_net48.bat < nul"
    if ($LASTEXITCODE -ne 0) { throw "2_Build_NuGet_net48 failed ($LASTEXITCODE)" }
    cmd /c ".\3_Build_Business_net48.bat < nul"
    if ($LASTEXITCODE -ne 0) { throw "3_Build_Business_net48 failed ($LASTEXITCODE)" }
} finally { Pop-Location }

# --- 2b. build Business.RichClient — the bats DON'T (needed for 2CS / rich client) ---
# 3_Build_Business_net48 builds Business + CustomControl only. The 2CS classes
# (MyBaseLogic2CS / MyFcBaseLogic2CS = OpenTouryo.Business.RichClient) live in a
# separate sln that no 2_/3_ script builds. This DLL is a *plain dependency* of the
# 2CS (2CSClientWin/WPF) and 3-tier rich-client (WSClient_*) SAMPLES — required
# whenever such a sample is used, INDEPENDENT of base2 customization. Without it
# those samples fail with CS0246. (Run the same script with -RichClient; do NOT add a separate script.)
$needRichClient = $true    # set true when the target sample is 2CS / rich client, OR base2 customizes 2CS (= -RichClient)
if ($needRichClient -or (Test-Path $overlay)) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $msb = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild `
            -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
    $brc = Join-Path $cs 'Frameworks\Infrastructure\BusinessRichClient_net48.sln'
    # This sln is NON-SDK, HintPath-only (no PackageReference). `/t:restore` FAILS with
    # "Microsoft.NuGet.targets ... does not reference .NETFramework,Version=v4.8" -> build WITHOUT restore.
    # Also: the net48 & netcore RichClient csproj SHARE one obj\ . A prior netcore SDK restore
    # leaves obj\project.assets.json / obj\*.nuget.* that break THIS net48 build with the same
    # error -> purge them first. (This is why RichClient was built in isolation at C:\otr\rc.)
    # NOTE the paths: RichClient lives under Business\ AND CustomControl\ (verified as-built) --
    # NOT directly under Infrastructure\. Both obj\ dirs must be purged.
    foreach ($rcObj in @(
        (Join-Path $cs 'Frameworks\Infrastructure\Business\RichClient\obj'),
        (Join-Path $cs 'Frameworks\Infrastructure\CustomControl\RichClient\obj'))) {
        if (Test-Path $rcObj) {
            Get-ChildItem $rcObj -Filter 'project.assets.json' -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue
            Get-ChildItem $rcObj -Filter '*.nuget.*'          -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue
        }
    }
    & $msb $brc /t:build /p:Configuration=Release /nologo /v:m   # NO restore (non-SDK sln); build only
    if ($LASTEXITCODE -ne 0) { throw "BusinessRichClient build failed ($LASTEXITCODE)" }
}

# --- 3. Vendor -> OpenTouryoAssemblies\Build_net48 ---
$src = Join-Path $cs 'Frameworks\Infrastructure\Build_net48'
if (-not (Test-Path $src)) { throw "Build output not found: $src" }
New-Item -ItemType Directory -Force -Path $vendor | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $vendor -Recurse -Force
# The .bat wrappers end with `pause` and swallow msbuild's exit code, so
# confirm the build actually produced the Business DLL (most prone to fail,
# e.g. MSB3553 MAX_PATH under a deep working tree).
if (-not (Test-Path (Join-Path $vendor 'OpenTouryo.Business.dll'))) {
    throw "Base build did not produce OpenTouryo.Business.dll (check the build output above)."
}
# When RichClient was built (2CS / rich client target, OR base2 customizes 2CS), the
# BusinessRichClient_net48.sln produces BOTH Business.RichClient AND CustomControl.RichClient
# (2 projects in one sln). Verify BOTH were vendored -- a prior round vendored only
# Business.RichClient and CustomControl.RichClient.dll was silently missing.
if ($needRichClient -or (Test-Path $overlay)) {
    foreach ($rc in 'OpenTouryo.Business.RichClient.dll','OpenTouryo.CustomControl.RichClient.dll') {
        if (-not (Test-Path (Join-Path $vendor $rc))) {
            throw "RichClient build/vendor incomplete: $rc missing (BusinessRichClient_net48.sln builds both)."
        }
    }
}
Get-ChildItem $vendor -Filter 'OpenTouryo.*.dll' | Select-Object -ExpandProperty Name

# build-ref.txt に「何を焼いたか」を残す（develop は ref だけでは同定できない＝zip ハッシュを併記）
$rc = ($needRichClient -or (Test-Path $overlay))
"{0}`tnet48`tref={1}`trichclient={2}`tzip={3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $ref, $rc, $zipHash |
    Add-Content -Path (Join-Path $repo 'OpenTouryoAssemblies\build-ref.txt')
```

## net10.0 の部分（`-Runtime netcore100`。基盤ビルド → ベンダ。分かりやすさのため別に載せる＝別のファイルにしない）

net48 版と同型で、回すバッチが `*_netcore100` になる。**混在ランタイム repo（net48 は既にベンダ済みで
net10.0 だけ後から足す）では、既存の ZIP 展開ツリーを再 DL せず流用し、netcore のバッチだけ回す**。
ベンダ先 `Build_netcore100\` は **TFM サブフォルダ（`net10.0\` と `net10.0-windows7.0\`）を両方含む**ので丸ごとコピーする。

```powershell
$ErrorActionPreference = 'Stop'
$repo    = Split-Path -Parent $PSScriptRoot   # scripts\ に置く前提＝親がリポジトリ ルート
$ref     = '03-20'                       # net48 と同じタグに揃える（ask the user; not a default）
$work    = 'C:\otr'
$extract = Join-Path $work "OpenTouryo-$ref"
$cs      = Join-Path $extract 'root\programs\CS'
$vendor  = Join-Path $repo 'OpenTouryoAssemblies\Build_netcore100'
$needRichClient = $true   # 標的が 2CS / rich client（TFM net10.0-windows7.0）なら true。Web/MVC/Bat/CLI は false
# ★ net48 と同じ2つ。**同じセットアップで net48 を先に走らせたときだけ $Fresh=$false**（net48 が作り直したツリーを流用する）。
#   net10.0 だけの repo（net48 を走らせない）では $Fresh=$true のまま（共有の C:\otr に別リポの overlay が残りうる・実測）。
#   moving ref は $Redownload（計画が「既存」の ZIP を使うと言うときは $false のまま）。
$Fresh      = $true
$Redownload = $false
$zip = Join-Path $work "OpenTouryo-$ref.zip"

# --- 1. 既存 extract を流用（無ければ ZIP 取得）。net48 で展開済みなら再 DL しない ---
New-Item -ItemType Directory -Force -Path $work | Out-Null
if ($Redownload) { Remove-Item $zip, $extract -Recurse -Force -ErrorAction SilentlyContinue }
if ($Fresh -and (Test-Path $extract)) { Remove-Item $extract -Recurse -Force }
if (-not (Test-Path $cs)) {
    if (-not (Test-Path $zip)) {
        # See setup-build.ps1: WebClient's old TLS default 404s on GitHub codeload.
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://github.com/OpenTouryoProject/OpenTouryo/archive/$ref.zip" -OutFile $zip
    }
    Expand-Archive -Path $zip -DestinationPath $work -Force
}

# --- 2. 基盤ビルド（net10.0 のバッチだけ。SDK の dotnet build を使う）---
Push-Location $cs
try {
    cmd /c ".\2_Build_NuGet_netcore100.bat    < nul"
    if ($LASTEXITCODE -ne 0) { throw "2_Build_NuGet_netcore100 failed ($LASTEXITCODE)" }
    cmd /c ".\3_Build_Business_netcore100.bat < nul"
    if ($LASTEXITCODE -ne 0) { throw "3_Build_Business_netcore100 failed ($LASTEXITCODE)" }

    # 2b. RichClient (2CS / rich client の netcore サンプルで必須。-RichClient のとき)。
    # ★ netcore は net10.0-windows7.0\ に Business / Dam* / Business.RichClient が「ここで初めて」出る
    #    （3_Build_Business_netcore100 直後は無い）。フォルダ丸ごと再ベンダするため、この後ベンダで上書きされる。
    if ($needRichClient) {   # 標的が 2CS / rich client（TFM net10.0-windows7.0）なら true
        cmd /c ".\3_Build_BusinessRichClient_netcore100.bat < nul"
        if ($LASTEXITCODE -ne 0) { throw "3_Build_BusinessRichClient_netcore100 failed ($LASTEXITCODE)" }
    }
} finally { Pop-Location }

# --- 3. ベンダ（net10.0\ と net10.0-windows7.0\ の両サブフォルダを丸ごと）---
# RichClient を回した場合、net10.0-windows7.0\ に Business/Dam*/Business.RichClient が揃うので、
# 個別 DLL を拾わず「フォルダ丸ごと」コピーする（拾い漏らすと OpenTouryo.Business で CS0246）。
$src = Join-Path $cs 'Frameworks\Infrastructure\Build_netcore100'
if (-not (Test-Path $src)) { throw "Build output not found: $src" }
New-Item -ItemType Directory -Force -Path $vendor | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $vendor -Recurse -Force
if (-not (Test-Path (Join-Path $vendor 'net10.0\OpenTouryo.Business.dll'))) {
    throw "netcore base build did not produce net10.0\OpenTouryo.Business.dll (check output)."
}
# 2CS / rich client 標的なら Windows TFM 側にも Business が在ることを確認（RichClient ビルド漏れ検知）。
if ($needRichClient -and
    -not (Test-Path (Join-Path $vendor 'net10.0-windows7.0\OpenTouryo.Business.dll'))) {
    throw "RichClient sample but net10.0-windows7.0\OpenTouryo.Business.dll missing (run 3_Build_BusinessRichClient_netcore100)."
}
# build-ref.txt（net48 版と同じ。develop は zip ハッシュを併記）
$zipHash = $(if (Test-Path $zip) { (Get-FileHash $zip -Algorithm SHA256).Hash.Substring(0,12) } else { 'unknown' })
"{0}`tnetcore100`tref={1}`trichclient={2}`tzip={3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $ref, $needRichClient, $zipHash |
    Add-Content -Path (Join-Path $repo 'OpenTouryoAssemblies\build-ref.txt')
```

> **★ 詳細ログの「この参照を解決できませんでした」は失敗ではない（実測）**：ビルドの詳細ログ（参照の解決）に、
> HintPath 参照した DLL の**依存関係**（`Oracle.ManagedDataAccess`・`MySql.Data`・`Npgsql`・`Microsoft.Data.SqlClient`・
> `Microsoft.Extensions.Configuration.*`・`BouncyCastle.Crypto` など）が「解決できませんでした」と多数出るが、各ビルドの末尾は
> 「ビルドに成功しました」「0 エラー」で DLL も揃う。**成否は末尾のエラー数と生成物 DLL の実在で判定する**（§3）。

> **既知の警告（本体側・版依存）**：core サンプル（例 Core MVC）が参照する `log4net` の版により挙動が変わる。
> **`3.2.0` ではビルドで `NU1902`（脆弱性・中）** が出ることがある（**ビルドは通る**）。**`3.3.0` 以降は解消＝0 警告**
> （実測：develop の Core MVC は `3.3.0`）。いずれにせよ**セットアップ側で無理に差し替えない**（本体の版に従う。
> 出ても無害・出なくても正常＝どちらでも「おかしい」と迷わない）。

## `build-app.ps1`（restore → 取り出した Web の sln を建てる → ツール）

**参照方式（更新）**：`WSServer_sample`/`WSIFType_sample` は **ProjectReference**（サンプル自身の B・D層/型＝P・B・D 並行開発。
`samples/webservices.md`）。よって**WS を別ビルドして `WS_sample\Build\` へ DLL コピーする旧手順は不要**＝WebForms
ソリューションに WS 2プロジェクトを含めて一括ビルドすれば WS も同時に建つ。`MySql.Data`/`Oracle`（3rd-party）だけは
DLL 参照のままベンダ先 `Build_net48\` を指す（`references/reference-rewrite.md`）。

**★ restore 方式は sln ごとに違う＝1つに決め打ちしない**：

| sln の形 | 復元方式 |
| --- | --- |
| `packages.config` 有（非SDK net48・WebForms 等） | `nuget restore <sln>`（`-MSBuildPath` 明示） |
| **`packages.config` 無 ＋ `PackageReference`（非SDK net48・2CS 等）** | `msbuild <sln> /t:restore,build`（`nuget restore` では復元されず `Microsoft.Data.SqlClient` 等が解決不能） |
| SDK（core） | `dotnet build`（restore 込み） |

下の雛形の net48 の Web（WebForms・MVC）は `packages.config` 前提。**2CS 等 `PackageReference` のみの sln を足すときは `msbuild /t:restore,build` に切り替える**
（DaoGen/DPQuery ツールが既にその方式＝下の任意ブロック）。

```powershell
# Build the Web samples taken out (only the .sln that exist) against the vendored
# OpenTouryo base DLLs. Reproducible from a fresh clone:
#   1. net48: nuget restore + msbuild / net10.0: dotnet build (WSServer/WSIFType
#      are ProjectReferences in the .sln -> built in-solution; no copy to Build\)
#   2. (optional) build the dev tools taken out under OT_Tools\
# Prereq: run setup-build.ps1 once first (populates OpenTouryoAssemblies\).
# Prereq: the .sln includes WSIFType_sample/WSServer_sample and the WebForms
#   csproj references them via <ProjectReference> (DLL HintPath to WS_sample\Build
#   removed); OpenTouryo.* -> OpenTouryoAssemblies\Build_net48 (all projects);
#   MySql.Data/Oracle.ManagedDataAccess -> the vendor folder. See webservices.md.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot   # scripts\ に置く前提＝親がリポジトリ ルート

# --- resolve msbuild (VS 2019/2022/18) via vswhere ---
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msb = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild `
        -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
if (-not $msb) { throw "MSBuild not found (install VS Build Tools / Community)" }

# nuget.exe: tools\nuget.exe if the repo has one, else the one in the OpenTouryo ZIP
# (root\programs\nuget.exe in the extract tree of step 3).
$nuget = Join-Path $repo 'tools\nuget.exe'
if (-not (Test-Path $nuget)) {
    $nuget = Get-ChildItem 'C:\otr\OpenTouryo-*\root\programs\nuget.exe' -EA SilentlyContinue |
             Select-Object -First 1 -ExpandProperty FullName
}
if (-not $nuget) { throw "nuget.exe not found (tools\ or C:\otr\OpenTouryo-<ref>\root\programs\)" }

# --- 1. restore + build the Web solutions that were taken out ---
# Add one line per sample you take out (not only Web: e.g. WSClient's _all.sln).
foreach ($rel in 'WebForms_Sample\WebForms_Sample.sln', 'MVC_Sample\MVC_Sample.sln') {   # net48 (packages.config)
    $wfSln = Join-Path $repo $rel
    if (-not (Test-Path $wfSln)) { continue }
# nuget.exe auto-detects an MSBuild and may grab the SSMS-bundled one -> `MSB4226`
# (Microsoft.WebApplication.targets missing) on Web slns. It's only an error MESSAGE
# (packages.config still restores, build succeeds) but reads as failure. Pin MSBuild
# to the vswhere-resolved one.
    & $nuget restore $wfSln -MSBuildPath (Split-Path $msb)   # msbuild /t:restore won't restore packages.config
    if ($LASTEXITCODE -ne 0) { throw "nuget restore failed: $rel ($LASTEXITCODE)" }
    & $msb $wfSln /p:Configuration=Debug /nologo /v:m
    if ($LASTEXITCODE -ne 0) { throw "build failed: $rel ($LASTEXITCODE)" }
}
foreach ($rel in 'MVC_Sample_Core\MVC_Sample.sln') {   # net10.0 (SDK): dotnet build restores
    $sln = Join-Path $repo $rel
    if (-not (Test-Path $sln)) { continue }
    dotnet build $sln -nologo -v q
    if ($LASTEXITCODE -ne 0) { throw "build failed: $rel ($LASTEXITCODE)" }
}

# --- 2. (optional) build the dev tools (DaoGen_Tool / DPQuery_Tool) ---
# Taken out from Frameworks\Tools and grouped under OT_Tools\. Their csproj
# MIX <Reference>+HintPath (OpenTouryo.* / MySql.Data / Oracle -> rewrite to the
# vendor folder in ⑤; 2 levels deep => ..\..\) with <PackageReference>
# (Microsoft.Data.SqlClient etc.). PackageReference needs a restore even on net48
# (no packages.config); skipping it -> CS0234 on `using Microsoft.Data.SqlClient;`.
# Building them here surfaces that at setup time. (HintPaths already rewritten.)
# net48 and Core csproj share obj\ in the same folder -> ALWAYS restore before build
# (the last restore wins; building the other without restore fails. measured).
foreach ($tool in 'DaoGen_Tool','DPQuery_Tool') {
    $toolSln = Join-Path $repo "OT_Tools\$tool\$tool.sln"
    if (Test-Path $toolSln) {
        & $msb $toolSln /t:restore,build /p:Configuration=Debug /nologo /v:m
        if ($LASTEXITCODE -ne 0) { throw "$tool build failed ($LASTEXITCODE)" }
    }
    $coreSln = Join-Path $repo "OT_Tools\$tool\${tool}Core.sln"
    if (Test-Path $coreSln) {
        dotnet build $coreSln -nologo -v q   # no --no-restore
        if ($LASTEXITCODE -ne 0) { throw "${tool}Core build failed ($LASTEXITCODE)" }
    }
}
Write-Host "Build OK." -ForegroundColor Green
```

（ビルド後、実際に動くことの確認＝IIS Express でのスモークは `opentouryo-project-setup-config` の
`references/run-verify.md`。）
