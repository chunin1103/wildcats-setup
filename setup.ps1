# Wildcats AI Studio -- Environment Setup (Windows)
# Usage: powershell -ExecutionPolicy Bypass -File setup.ps1
# Or:    irm https://wildcats.global/setup.ps1 | iex

#Requires -Version 5.1

$ErrorActionPreference = "Continue"

# --- Self-elevate if not admin ------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  [Wildcats] This script needs Administrator privileges." -ForegroundColor Cyan
    Write-Host "  [Wildcats] Requesting elevation now..." -ForegroundColor Cyan
    Write-Host ""
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -Command `"irm https://wildcats.global/setup.ps1 | iex`""
        Write-Host "  [OK] Admin window opened. You can close this one." -ForegroundColor Green
        Write-Host ""
        exit 0
    } catch {
        Write-Host "  [X] Could not get admin privileges." -ForegroundColor Red
        Write-Host ""
        Write-Host "  Please open PowerShell as Administrator and try again:" -ForegroundColor Yellow
        Write-Host "    1. Click the Start button (bottom-left)" -ForegroundColor Yellow
        Write-Host "    2. Type 'PowerShell'" -ForegroundColor Yellow
        Write-Host "    3. Right-click 'Windows PowerShell'" -ForegroundColor Yellow
        Write-Host "    4. Click 'Run as Administrator'" -ForegroundColor Yellow
        Write-Host "    5. Click 'Yes' on the security prompt" -ForegroundColor Yellow
        Write-Host "    6. Paste the command again" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}

# --- Helpers ------------------------------------------------------------------

function Write-Banner {
    Write-Host ""
    Write-Host '  __        ___ _     _            _       ' -ForegroundColor Cyan
    Write-Host '  \ \      / (_) | __| | ___ __ _| |_ ___ ' -ForegroundColor Cyan
    Write-Host ('   \ \ /\ / /| | |/ _' + '` |/ __/ _' + '` | __/ __|') -ForegroundColor Cyan
    Write-Host ('    \ V  V / | | | (_| | (_| (_| | |_\__ \') -ForegroundColor Cyan
    Write-Host '     \_/\_/  |_|_|\__,_|\___\__,_|\__|___/' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '     A I   S T U D I O' -ForegroundColor Cyan
    Write-Host '     wildcats.global' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Setting up your AI development environment...' -ForegroundColor Cyan
    Write-Host ''
}

function Write-Info    { param([string]$Msg) Write-Host "  [Wildcats] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg) Write-Host "  [!] $Msg" -ForegroundColor Yellow }
function Write-Fail    { param([string]$Msg) Write-Host "  [X] $Msg" -ForegroundColor Red }

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Test-Command {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-WingetAvailable {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# --- Download Helper ----------------------------------------------------------

function Get-Installer {
    param(
        [string]$Url,
        [string]$FileName
    )
    $outPath = Join-Path $env:TEMP $FileName
    Write-Info "Downloading $FileName..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $Url -OutFile $outPath -UseBasicParsing
        return $outPath
    } catch {
        Write-Fail "Download failed: $_"
        return $null
    }
}

# --- Python -------------------------------------------------------------------

function Install-PythonIfNeeded {
    if (Test-Command "python") {
        $ver = python --version 2>&1
        if ($ver -match "Python 3\.") {
            Write-Success "Python already installed ($ver)"
            return $true
        }
    }

    Write-Info "Installing Python..."

    if ($script:HasWinget) {
        winget install Python.Python.3.13 --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
        Refresh-Path
    } else {
        # Direct download fallback
        $installer = Get-Installer "https://www.python.org/ftp/python/3.13.3/python-3.13.3-amd64.exe" "python-installer.exe"
        if (-not $installer) { return $false }
        Write-Info "Running Python installer (silent)..."
        Start-Process -FilePath $installer -ArgumentList "/quiet", "InstallAllUsers=0", "PrependPath=1", "Include_test=0" -Wait -NoNewWindow
        Refresh-Path
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
    }

    if (Test-Command "python") {
        $ver = python --version 2>&1
        Write-Success "Python installed ($ver)"
        return $true
    } else {
        Write-Fail "Python installation failed"
        Write-Fail "Manual install: https://www.python.org/downloads/"
        return $false
    }
}

# --- Node.js ------------------------------------------------------------------

function Install-NodeIfNeeded {
    if (Test-Command "node") {
        $ver = node --version 2>&1
        $major = [int]($ver -replace '^v(\d+).*', '$1')
        if ($major -ge 18) {
            Write-Success "Node.js already installed ($ver)"
            return $true
        } else {
            Write-Warn "Node.js $ver is too old (need v18+), upgrading..."
        }
    }

    Write-Info "Installing Node.js LTS..."

    if ($script:HasWinget) {
        winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
        Refresh-Path
    } else {
        # Direct download fallback -- Node.js LTS MSI installer
        $installer = Get-Installer "https://nodejs.org/dist/v22.16.0/node-v22.16.0-x64.msi" "node-lts.msi"
        if (-not $installer) { return $false }
        Write-Info "Running Node.js installer (silent)..."
        Start-Process msiexec.exe -ArgumentList "/i", "`"$installer`"", "/qn", "/norestart" -Wait -NoNewWindow
        Refresh-Path
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
    }

    if (Test-Command "node") {
        $ver = node --version 2>&1
        Write-Success "Node.js installed ($ver)"
        return $true
    } else {
        Write-Fail "Node.js installation failed"
        Write-Fail "Manual install: https://nodejs.org/"
        return $false
    }
}

# --- VS Code -----------------------------------------------------------------

function Install-VSCodeIfNeeded {
    if (Test-Command "code") {
        Write-Success "VS Code already installed"
        return $true
    }

    # Also check common install paths (code may not be in PATH yet)
    $vscodePaths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "$env:ProgramFiles\Microsoft VS Code\Code.exe"
    )
    foreach ($p in $vscodePaths) {
        if (Test-Path $p) {
            Write-Success "VS Code already installed (found at $p)"
            return $true
        }
    }

    Write-Info "Installing Visual Studio Code..."

    if ($script:HasWinget) {
        winget install Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
        Refresh-Path
    } else {
        # Direct download fallback
        $installer = Get-Installer "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user" "vscode-installer.exe"
        if (-not $installer) { return $false }
        Write-Info "Running VS Code installer (silent)..."
        Start-Process -FilePath $installer -ArgumentList "/verysilent", "/norestart", "/mergetasks=!runcode,addtopath" -Wait -NoNewWindow
        Refresh-Path
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
    }

    Refresh-Path
    if (Test-Command "code") {
        Write-Success "VS Code installed"
        return $true
    } else {
        # May need a new terminal for PATH
        Write-Warn "VS Code installed but may need a new terminal for 'code' command"
        return $true
    }
}

# --- Claude Code --------------------------------------------------------------

function Install-ClaudeCodeIfNeeded {
    if (Test-Command "claude") {
        $ver = claude --version 2>&1 | Select-Object -First 1
        Write-Success "Claude Code already installed ($ver)"
        return $true
    }

    Write-Info "Installing Claude Code (native installer)..."

    try {
        # Use the official native installer
        $installScript = Invoke-RestMethod -Uri "https://claude.ai/install.ps1" -UseBasicParsing
        Invoke-Expression $installScript
        Refresh-Path
    } catch {
        Write-Fail "Claude Code native installer failed: $_"
        Write-Fail "Try manually: irm https://claude.ai/install.ps1 | iex"
        return $false
    }

    Refresh-Path
    if (Test-Command "claude") {
        Write-Success "Claude Code installed"
        return $true
    } else {
        Write-Warn "Claude Code installed but may need a new terminal to use"
        return $true
    }
}

# --- Summary ------------------------------------------------------------------

function Write-Summary {
    param([string[]]$Failed)

    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host "    Wildcats AI Studio - Setup Complete" -ForegroundColor Cyan
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host ""

    $tools = @(
        @{ Cmd = "python"; Name = "Python" },
        @{ Cmd = "node";   Name = "Node.js" },
        @{ Cmd = "code";   Name = "VS Code" },
        @{ Cmd = "claude"; Name = "Claude Code" }
    )

    foreach ($tool in $tools) {
        if (Test-Command $tool.Cmd) {
            $ver = & $tool.Cmd --version 2>&1 | Select-Object -First 1
            Write-Host "  [OK] $($tool.Name)  " -ForegroundColor Green -NoNewline
            Write-Host "$ver" -ForegroundColor DarkGray
        } else {
            Write-Host "  [X]  $($tool.Name)  " -ForegroundColor Red -NoNewline
            Write-Host "not found" -ForegroundColor DarkGray
        }
    }

    Write-Host ""

    if ($Failed.Count -gt 0) {
        Write-Host "  Some tools failed to install: $($Failed -join ', ')" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Don't worry! Take a screenshot of this window" -ForegroundColor Yellow
        Write-Host "  and send it to your Wildcats contact for help." -ForegroundColor Yellow
        Write-Host ""
    }

    Write-Host "  NEXT STEP: " -ForegroundColor White -NoNewline
    Write-Host "Run " -NoNewline
    Write-Host "claude" -ForegroundColor Cyan -NoNewline
    Write-Host " in your terminal"
    Write-Host "  to authenticate with your Anthropic account."
    Write-Host ""
    Write-Host "  Questions? Visit wildcats.global" -ForegroundColor DarkGray
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host ""
}

# --- Main ---------------------------------------------------------------------

function Main {
    Write-Banner

    # Check for winget
    $script:HasWinget = Test-WingetAvailable
    if ($script:HasWinget) {
        Write-Info "Package manager: winget"
    } else {
        Write-Warn "winget not available -- using direct download installers"
    }

    Write-Host ""

    # Track failures
    $Failed = @()

    if (-not (Install-PythonIfNeeded))    { $Failed += "Python" }
    if (-not (Install-NodeIfNeeded))      { $Failed += "Node.js" }
    if (-not (Install-VSCodeIfNeeded))    { $Failed += "VS Code" }
    if (-not (Install-ClaudeCodeIfNeeded)) { $Failed += "Claude Code" }

    Write-Summary -Failed $Failed
}

Main
