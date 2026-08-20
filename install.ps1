<#
.SYNOPSIS
    WhatMark? installer for Windows.

.DESCRIPTION
    Sets up everything needed:
      1. checks Python 3.10+
      2. checks Ollama, installs it if missing
      3. checks the mistral model, pulls it if missing
      4. copies the skill to %USERPROFILE%\.claude\skills\whatmark
      5. creates the workspace C:\ClaudeText

.PARAMETER Yes
    Skip confirmation prompts before installing Ollama or pulling the model.

.PARAMETER Model
    Ollama model to install. Default: mistral

.PARAMETER Workspace
    Working folder. Default: C:\ClaudeText

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Yes -Model llama3.2
#>

[CmdletBinding()]
param(
    [switch]$Yes,
    [string]$Model = "mistral",
    [string]$Workspace = "C:\ClaudeText"
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------- helpers

function Write-Step { param($m) Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "    [ok] $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "    [!]  $m" -ForegroundColor Yellow }

function Die {
    param($Message, $Hint)
    Write-Host "`n[ERROR] $Message" -ForegroundColor Red
    if ($Hint) { Write-Host "        $Hint" -ForegroundColor Yellow }
    Write-Host ""
    exit 1
}

function Confirm-Action {
    param($Message)
    if ($Yes) { return $true }
    $r = Read-Host "    $Message [y/N]"
    return $r -match '^[yY]$'
}

function Test-Command { param($n) $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

$RepoZipUrl = "https://github.com/Uriel-SG/whatmark-skill/archive/refs/heads/main.zip"
$CheckoutDir = if ($env:WHATMARK_CHECKOUT_DIR) { $env:WHATMARK_CHECKOUT_DIR } else { Join-Path $HOME "whatmark-skill" }

Write-Host ""
Write-Host "  WhatMark? - installer" -ForegroundColor White
Write-Host "  ---------------------" -ForegroundColor DarkGray

# When the script is cloned by hand, "skill\" sits right next to it
# ($PSScriptRoot). When it comes from a one-liner (irm ... | iex) instead,
# $PSScriptRoot is empty: there's no file on disk to anchor to, the whole
# repository needs to be downloaded first.
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "skill\SKILL.md"))) {
    $RepoRoot = $PSScriptRoot
}
else {
    Write-Step "Downloading the repository"

    if (Test-Path (Join-Path $CheckoutDir "skill\SKILL.md")) {
        Write-Ok "checkout already present in $CheckoutDir"
    }
    else {
        $zipPath = Join-Path $env:TEMP "whatmark-skill.zip"
        $extractDir = Join-Path $env:TEMP "whatmark-skill-extract"

        Invoke-WebRequest -Uri $RepoZipUrl -OutFile $zipPath -UseBasicParsing

        if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

        $extractedRoot = Get-ChildItem $extractDir | Select-Object -First 1
        New-Item -ItemType Directory -Force -Path $CheckoutDir | Out-Null
        Copy-Item -Path (Join-Path $extractedRoot.FullName "*") -Destination $CheckoutDir -Recurse -Force
        Remove-Item $zipPath, $extractDir -Recurse -Force

        Write-Ok "downloaded to $CheckoutDir"
    }

    $RepoRoot = $CheckoutDir
}

Write-Host ""
if (-not (Confirm-Action "This skill requires Ollama and Mistral installed; if they are not already present, they will be installed automatically. Do you want to proceed?")) {
    Die "Installation cancelled."
}

# ---------------------------------------------------------------- 1. Python

Write-Step "Checking Python"

$pyCmd = $null
foreach ($c in @("py", "python", "python3")) {
    if (Test-Command $c) {
        try {
            $v = & $c --version 2>&1
            if ($v -match "Python (\d+)\.(\d+)") {
                if ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -ge 10) {
                    $pyCmd = $c
                    Write-Ok "$v  (command: $c)"
                    break
                }
            }
        } catch { }
    }
}

if (-not $pyCmd) {
    Die "Python 3.10 or newer not found." `
        "Install it from https://www.python.org/downloads/ or the Microsoft Store, then re-run this script. Remember to check 'Add Python to PATH'."
}

# ---------------------------------------------------------------- 2. Ollama

Write-Step "Checking Ollama installation..."

if (Test-Command "ollama") {
    Write-Ok "already installed"
} else {
    Write-Warn "not found"

    if (-not (Confirm-Action "Install Ollama now?")) {
        Die "Installation cancelled." `
            "WhatMark? cannot work without Ollama. Download it from https://ollama.com/download"
    }

    Write-Step "Installing Ollama"

    $installed = $false

    if (Test-Command "winget") {
        try {
            winget install --id Ollama.Ollama -e --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) { $installed = $true }
        } catch {
            Write-Warn "winget failed: $($_.Exception.Message)"
        }
    }

    if (-not $installed) {
        Die "Could not install Ollama automatically." `
            "Download the installer from https://ollama.com/download, run it, then re-run this script."
    }

    # The current session's PATH doesn't see ollama yet
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path", "User")

    if (-not (Test-Command "ollama")) {
        Die "Ollama was installed but is not on the PATH of this session." `
            "Close and reopen PowerShell, then re-run this script."
    }
    Write-Ok "installed"
}

# ---------------------------------------------------------------- 3. service

Write-Step "Checking that Ollama is running"

function Test-OllamaUp {
    try {
        $null = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 5
        return $true
    } catch { return $false }
}

if (-not (Test-OllamaUp)) {
    Write-Warn "service not running, starting it in the background"
    try {
        Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
    } catch {
        Die "Could not start 'ollama serve': $($_.Exception.Message)" `
            "Try starting Ollama manually from the Start menu."
    }

    $up = $false
    foreach ($i in 1..20) {
        Start-Sleep -Seconds 1
        if (Test-OllamaUp) { $up = $true; break }
    }
    if (-not $up) {
        Die "Ollama is not responding on http://127.0.0.1:11434 after 20 seconds." `
            "Check that port 11434 isn't taken by another process: netstat -ano | findstr 11434"
    }
}
Write-Ok "responding on http://127.0.0.1:11434"

# ---------------------------------------------------------------- 4. model

Write-Step "Checking model '$Model' installation..."

try {
    $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 10
    $names = @($tags.models | ForEach-Object { $_.name })
} catch {
    Die "Could not read the model list: $($_.Exception.Message)"
}

$has = $names | Where-Object { $_ -eq $Model -or $_ -like "$Model`:*" }

if ($has) {
    Write-Ok "already present ($has)"
} else {
    Write-Warn "not found"

    if (-not (Confirm-Action "Install model '$Model' now?")) {
        Die "Download cancelled." `
            "You can do it later with:  ollama pull $Model"
    }

    Write-Step "Installing model '$Model'"

    ollama pull $Model
    if ($LASTEXITCODE -ne 0) {
        Die "Model download failed (exit code $LASTEXITCODE)." `
            "Check your network connection and free disk space, then retry with:  ollama pull $Model"
    }
    Write-Ok "installed"
}

# ---------------------------------------------------------------- 5. skill

Write-Step "Installing the skill"

$src = Join-Path $RepoRoot "skill"
if (-not (Test-Path $src)) {
    Die "'skill' folder not found in $RepoRoot." `
        "The repository download may be incomplete: try again."
}

$dest = Join-Path $env:USERPROFILE ".claude\skills\whatmark"

try {
    New-Item -ItemType Directory -Force -Path (Join-Path $dest "scripts") | Out-Null
    Copy-Item (Join-Path $src "SKILL.md") $dest -Force
    Copy-Item (Join-Path $src "scripts\*.py") (Join-Path $dest "scripts") -Force
} catch {
    Die "Failed to copy files: $($_.Exception.Message)" `
        "Check permissions on $dest"
}

foreach ($f in @("SKILL.md", "scripts\ollama_translate.py", "scripts\compare_texts.py")) {
    if (-not (Test-Path (Join-Path $dest $f))) { Die "Missing file after copy: $f" }
}
Write-Ok $dest

# ---------------------------------------------------------------- 6. workspace

Write-Step "Workspace"

try {
    New-Item -ItemType Directory -Force -Path $Workspace | Out-Null
    $probe = Join-Path $Workspace ".write_test"
    "ok" | Out-File -FilePath $probe -Encoding utf8
    Remove-Item $probe -Force
} catch {
    Die "Could not create or write to $Workspace : $($_.Exception.Message)" `
        "Choose a different folder with -Workspace, or run PowerShell as Administrator."
}
Write-Ok $Workspace

if ($Workspace -ne "C:\ClaudeText") {
    [Environment]::SetEnvironmentVariable("WHATMARK_DIR", $Workspace, "User")
    Write-Ok "WHATMARK_DIR variable set (active on next terminal restart)"
}

# ---------------------------------------------------------------- 7. verify

Write-Step "Final check"

try {
    $out = & $pyCmd (Join-Path $dest "scripts\compare_texts.py") --help 2>&1
    if ($LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE" }
    Write-Ok "scripts respond correctly"
} catch {
    Die "The Python scripts don't run: $_" `
        "Check that '$pyCmd' works from this shell."
}

Write-Host ""
Write-Host "  Installation complete." -ForegroundColor Green
Write-Host ""
Write-Host "  Skill      : $dest"
Write-Host "  Workspace  : $Workspace"
Write-Host "  Model      : $Model"
Write-Host ""
Write-Host "  Restart Claude Code, then type:" -ForegroundColor White
Write-Host "      /whatmark a 400-word post about Zero Trust" -ForegroundColor Cyan
Write-Host ""
