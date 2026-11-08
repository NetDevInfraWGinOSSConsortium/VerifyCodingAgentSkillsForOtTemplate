<#
.SYNOPSIS
    検証用リポジトリを、このテンプレート（VerifyCodingAgentSkillsForOtTemplate）から作る。

.DESCRIPTION
    GitHub の「Use this template」（gh repo create --template）で、独立した履歴の新しいリポジトリを作る。
    テンプレートに「Template repository」の印が無いときは、履歴ごと写す（-AllowMirror を付けたときだけ）。
    フォークでも、テンプレートのクローンでもない（テンプレートは一切変更しない）。

    安全のため次を守る。
      - 公開・非公開は必ず指定する（-Visibility。既定は無い）
      - 作る前に、作り先のリポジトリと手元のフォルダが無いことを確かめる（既にあれば止まる。空のリポジトリだけ再利用する）
      - 作る GitHub のアカウントを表示する。-WhatIf で、何をするかだけを表示できる
      - トークンをコマンド行や URL に書かない（git の push は gh の資格情報を一時的に使う）

    前提：GitHub CLI（gh）でログイン済みで、作り先の組織にリポジトリを作る権限があること。
    秘密情報（トークン・パスワード）はこのスクリプトに書かない。

.EXAMPLE
    ./New-VerifyRepo.ps1 -Name VerifyCaTddForOT3 -Visibility Public -Clone -WhatIf
    何をするかだけを表示する。

.EXAMPLE
    ./New-VerifyRepo.ps1 -Name VerifyCaTddForOT3 -Visibility Public -Clone -CloneParent D:\git\local\OpenTouryoProject
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Name,

    [Parameter(Mandatory)]
    [ValidateSet('Public', 'Private')]
    [string]$Visibility,

    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$Owner = 'OpenTouryoProject',

    [ValidatePattern('^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$')]
    [string]$Template = 'NetDevInfraWGinOSSConsortium/VerifyCodingAgentSkillsForOtTemplate',

    # テンプレートに「Template repository」の印が無いとき、履歴ごと写すことを許す
    [switch]$AllowMirror,

    [switch]$Clone,

    # クローンする親フォルダ（既定はカレント）
    [string]$CloneParent = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Destination = "$Owner/$Name"

function Invoke-Gh {
    # gh の失敗を例外にする（native command の終了コードは $ErrorActionPreference では止まらない）
    param([string[]]$GhArgs, [switch]$AllowFailure)
    $out = & gh @GhArgs 2>&1
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
        throw "gh $($GhArgs -join ' ') が失敗した: $out"
    }
    return $out
}

# ---- 事前の確かめ（何も作らない） ----

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI（gh）が見つからない。https://cli.github.com/ から入れる。'
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git が見つからない。'
}

$login = (Invoke-Gh @('api', 'user', '--jq', '.login')) -join ''
Write-Host "GitHub のアカウント: $login（gh の現在のアカウント。違うなら gh auth switch）"
Write-Host "作り先: $Destination（$Visibility）"
Write-Host "テンプレート: $Template"

$isTemplate = (Invoke-Gh @('repo', 'view', $Template, '--json', 'isTemplate', '--jq', '.isTemplate')) -join ''

$destInfo = Invoke-Gh @('repo', 'view', $Destination, '--json', 'isEmpty', '--jq', '.isEmpty') -AllowFailure
$destExists = ($LASTEXITCODE -eq 0)
if ($destExists -and (($destInfo -join '') -ne 'true')) {
    throw "作り先が既にあり、空ではない: $Destination"
}
if ($destExists) { Write-Warning "作り先は既にあり、空なので再利用する: $Destination" }

$cloneDir = Join-Path $CloneParent $Name
if ($Clone -and (Test-Path $cloneDir)) {
    throw "クローン先のフォルダが既にある: $cloneDir（リポジトリを作る前に止めた）"
}

$useTemplate = ($isTemplate -eq 'true') -and -not $destExists
if (-not $useTemplate -and -not $AllowMirror) {
    throw ("テンプレートの印が無い（isTemplate=$isTemplate）か、空の作り先を再利用するため、「Use this template」で作れない。" +
           "テンプレートの Settings で「Template repository」を有効にするか、履歴ごと写してよければ -AllowMirror を付ける。")
}

# ---- 作る ----

$visFlag = if ($Visibility -eq 'Private') { '--private' } else { '--public' }

if ($useTemplate) {
    if ($PSCmdlet.ShouldProcess($Destination, "テンプレート $Template から作る（$Visibility）")) {
        Invoke-Gh @('repo', 'create', $Destination, '--template', $Template, $visFlag) | Out-Null
    }
}
else {
    Write-Warning 'テンプレートの履歴ごと写す（-AllowMirror）。'
    if ($PSCmdlet.ShouldProcess($Destination, "テンプレート $Template の履歴ごと写す（$Visibility）")) {
        $work = Join-Path ([IO.Path]::GetTempPath()) ("${Name}_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $work | Out-Null
        try {
            $src = Join-Path $work 'src.git'
            # gh の資格情報を一時的に使う（保存済みの別アカウントの資格情報やトークンを URL に書くことを避ける）
            $cred = @('-c', 'credential.helper=', '-c', 'credential.helper=!gh auth git-credential')
            & git @cred clone --bare "https://github.com/$Template.git" $src
            if ($LASTEXITCODE -ne 0) { throw 'git clone --bare が失敗した。' }

            if (-not $destExists) { Invoke-Gh @('repo', 'create', $Destination, $visFlag) | Out-Null }

            # ブランチとタグだけ（refs/pull/* は GitHub が拒否する）。作り先は空であることを上で確かめている
            & git @cred -C $src push "https://github.com/$Destination.git" 'refs/heads/*:refs/heads/*' 'refs/tags/*:refs/tags/*'
            if ($LASTEXITCODE -ne 0) { throw 'git push が失敗した。' }
        }
        finally {
            Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
        }
    }
}

if ($Clone -and $PSCmdlet.ShouldProcess($cloneDir, 'クローンする')) {
    Push-Location $CloneParent
    try { Invoke-Gh @('repo', 'clone', $Destination) | Out-Null }
    finally { Pop-Location }
}

Write-Host ''
Write-Host "完了: https://github.com/$Destination"
Write-Host @"

作った後に人が行うこと（このスクリプトは行わない）:
  1. git -C <クローン先> config core.hooksPath .githooks   （期待値の変更の検出器の段 2。クローンごとの設定）
  2. tools\ExpectationGuard\ExpectationGuard.Tests\Run-Tests.ps1 で判定の用例を回す
  3. 最新のアセットを入れ直す（OpenTouryoCodingAgentAssets の install.ps1 -Product claude -IncludeTutorial -IncludeQualityGuard）
  4. README.md の「前提」を、この環境に書き換える
  5. 環境変数（OT_RESOURCE_ROOT* など）は利用者ごとに 1 つ。別の検証用リポジトリを指していないか確かめる（リセット手順.md）
"@
