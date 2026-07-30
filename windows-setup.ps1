#Requires -Version 5.1
<#
.SYNOPSIS
    Windows Post-Installation Setup Script
.DESCRIPTION
    Automates Windows 10/11 post-installation setup with modular options.
    Windows-native counterpart of ubuntu-setup.sh (https://github.com/enginyilmaaz/ubuntu-setup-script).
.NOTES
    Version : 1.2.0
    Author  : enginyilmaaz
    License : MIT

    Usage:
      irm https://bit.ly/windows-ey | iex                                  # interactive menu
      & ([scriptblock]::Create((irm 'https://bit.ly/windows-ey'))) --all   # install everything
      .\windows-setup.ps1 --nodejs --vscode                                # install specific apps
      .\windows-setup.ps1 --help                                           # show all options
#>

#===============================================================================
# Windows Post-Installation Setup Script
# Version: 1.2.0
# Author: enginyilmaaz
# Description: Automates Windows post-installation setup with modular options
#===============================================================================

$script:SCRIPT_VERSION  = '1.2.0'
$script:SCRIPT_REVISION = '5'
$script:SCRIPT_DATE     = '2026-07-27'

# Canonical self URL (used to re-fetch when re-launching elevated under `irm | iex`)
$script:SELF_URL = 'https://bit.ly/windows-ey'

# Gist identity (used by the self-update check)
$script:GIST_ID   = '5dc585f42032cc2d2736433590555484'
$script:GIST_FILE = 'windows-setup.ps1'

# Raw args as received (preserved for elevation relaunch)
$script:RAW_ARGS = @($args)

# User home (USERPROFILE on Windows; HOME fallback keeps the script testable off-Windows)
$script:USER_HOME = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }

# Backup directory (System Restore point + touched-registry exports live here)
$script:BACKUP_DIR = Join-Path $script:USER_HOME '.windows_setup_conf_backup'

# NOTE: We intentionally do NOT stop on every error. Errors are handled
# interactively via Invoke-ErrorHandler so the user can continue or abort.
$ErrorActionPreference = 'Continue'

#===============================================================================
# Command line flags - all default to $false
#===============================================================================
$flags = @{
    All        = $false
    # dev tools
    NodeJs     = $false; Python = $false; Docker = $false; Chrome = $false
    VSCode     = $false; DBeaver = $false; Vlc = $false; Cloudflared = $false
    Gh         = $false; Postman = $false; FileZilla = $false
    # AI CLI
    Claude     = $false; Codex = $false; Kimi = $false; Grok = $false
    Gemini     = $false; Qwen = $false; Glm = $false; Opencode = $false
    AiCli      = $false
    # remote
    Vnc        = $false; AnyDesk = $false; RustDesk = $false; TeamViewer = $false
    Remote     = $false
    # windows-native groups (were GNOME tweaks / debloat)
    Tweaks     = $false; Debloat = $false
    # helpers / special commands
    Login      = $false; SkipUpdate = $false
    ShowBackup = $false; Restore = $false
    ShowHelp   = $false; ShowMenu = $false; ShowVersion = $false
}

#===============================================================================
# Parse command line arguments
# Accepts --menu, -menu, /menu, --Menu (leading -/ stripped, case-insensitive)
#===============================================================================
foreach ($arg in $script:RAW_ARGS) {
    $a = ([string]$arg).TrimStart('-', '/').ToLowerInvariant()
    switch ($a) {
        'all'         { $flags.All = $true }
        'menu'        { $flags.ShowMenu = $true }
        'help'        { $flags.ShowHelp = $true }
        'h'           { $flags.ShowHelp = $true }
        'version'     { $flags.ShowVersion = $true }
        'v'           { $flags.ShowVersion = $true }
        # dev tools
        'nodejs'      { $flags.NodeJs = $true }
        'node'        { $flags.NodeJs = $true }
        'python'      { $flags.Python = $true }
        'docker'      { $flags.Docker = $true }
        'chrome'      { $flags.Chrome = $true }
        'vscode'      { $flags.VSCode = $true }
        'dbeaver'     { $flags.DBeaver = $true }
        'vlc'         { $flags.Vlc = $true }
        'cloudflared' { $flags.Cloudflared = $true }
        'gh'          { $flags.Gh = $true }
        'postman'     { $flags.Postman = $true }
        'filezilla'   { $flags.FileZilla = $true }
        # AI CLI
        'claude'      { $flags.Claude = $true }
        'codex'       { $flags.Codex = $true }
        'kimi'        { $flags.Kimi = $true }
        'grok'        { $flags.Grok = $true }
        'gemini'      { $flags.Gemini = $true }
        'qwen'        { $flags.Qwen = $true }
        'glm'         { $flags.Glm = $true }
        'glm-opencode' { $flags.Opencode = $true }
        'opencode'    { $flags.Opencode = $true }
        'aicli'       { $flags.AiCli = $true }
        # remote
        'vnc'         { $flags.Vnc = $true }
        'realvnc'     { $flags.Vnc = $true }
        'anydesk'     { $flags.AnyDesk = $true }
        'rustdesk'    { $flags.RustDesk = $true }
        'teamviewer'  { $flags.TeamViewer = $true }
        'remote'      { $flags.Remote = $true }
        # windows-native groups
        'tweaks'      { $flags.Tweaks = $true }
        'gnome'       { $flags.Tweaks = $true }   # source alias, kept for muscle memory
        'debloat'     { $flags.Debloat = $true }
        # helpers / special
        'login'       { $flags.Login = $true }
        'skip-update' { $flags.SkipUpdate = $true }
        'no-update'   { $flags.SkipUpdate = $true }
        'show-backup' { $flags.ShowBackup = $true }
        'restore'     { $flags.Restore = $true }
        ''            { }  # ignore stray separators
        default       { Write-Host "Unknown option: $arg" -ForegroundColor Yellow }
    }
}

# If --all is set, enable all installations (groups expand in run logic)
if ($flags.All) {
    foreach ($k in @('NodeJs','Python','Docker','Chrome','VSCode','DBeaver','Vlc','Cloudflared','Gh','Postman','FileZilla','AiCli','Remote')) {
        $flags[$k] = $true
    }
}

# No actionable flag at all -> default to the interactive menu
$script:AnyActionFlag = ($flags.Values -contains $true)
if (-not $script:AnyActionFlag) { $flags.ShowMenu = $true }

#===============================================================================
# Colors / logging (mirrors log_info/step/success/warning/error)
#===============================================================================
function Write-LogInfo    { param([string]$Message) Write-Host "[INFO] "    -ForegroundColor Blue   -NoNewline; Write-Host $Message }
function Write-LogSuccess { param([string]$Message) Write-Host "[SUCCESS] " -ForegroundColor Green  -NoNewline; Write-Host $Message }
function Write-LogWarning { param([string]$Message) Write-Host "[WARNING] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
function Write-LogError   { param([string]$Message) Write-Host "[ERROR] "   -ForegroundColor Red    -NoNewline; Write-Host $Message }
function Write-LogStep {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[STEP] " -ForegroundColor Cyan -NoNewline; Write-Host $Message
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

#===============================================================================
# Interactive error handler - asks user whether to continue or abort
# Usage: if (-not (Do-Thing)) { Invoke-ErrorHandler "Description of what failed" }
# Returns $true if the user chose to continue; exits the script otherwise.
#===============================================================================
function Invoke-ErrorHandler {
    param([string]$ErrorMessage)
    Write-Host ""
    Write-Host ("-" * 63) -ForegroundColor Red
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline; Write-Host $ErrorMessage
    Write-Host ("-" * 63) -ForegroundColor Red
    Write-Host ""
    $reply = Read-Host "Do you want to continue? (y/n)"
    if ($reply -notmatch '^[Yy]') {
        Write-LogError "Script aborted by user."
        exit 1
    }
    Write-LogInfo "Continuing despite error..."
    return $true
}

#===============================================================================
# Helper: is the current process elevated (Administrator)?
#===============================================================================
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Path to the best available PowerShell host (pwsh preferred, else Windows PowerShell)
function Get-PowerShellPath {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) { return $pwsh.Source }
    return (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe')
}

#===============================================================================
# Elevation (sudo analog): relaunch self as Administrator, preserving args.
# Works both from a file (-File) and from `irm | iex` (re-fetch via SELF_URL).
#===============================================================================
function Invoke-Elevation {
    if (Test-Admin) { return }
    Write-LogWarning "Administrator privileges are required. Relaunching as Administrator..."
    $argLine = ($script:RAW_ARGS -join ' ').Trim()
    $ps = Get-PowerShellPath
    try {
        if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
            $spArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            if ($argLine) { $spArgs += " $argLine" }
        } else {
            if ($argLine) {
                $inner = "& ([scriptblock]::Create((irm '$($script:SELF_URL)'))) $argLine"
            } else {
                $inner = "irm '$($script:SELF_URL)' | iex"
            }
            $spArgs = "-NoProfile -ExecutionPolicy Bypass -Command `"$inner`""
        }
        Start-Process -FilePath $ps -Verb RunAs -ArgumentList $spArgs | Out-Null
    } catch {
        Write-LogError "Elevation was cancelled or failed. Please run this script as Administrator."
        exit 1
    }
    exit 0
}

#===============================================================================
# Retry helper (mirrors retry_command): 3 attempts, 5s delay.
# Returns $true on success, $false after all attempts fail.
#===============================================================================
function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [string]$Description = 'operation',
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 5
    )
    for ($i = 1; $i -le $MaxAttempts; $i++) {
        try {
            & $Action
            if ($LASTEXITCODE -eq $null -or $LASTEXITCODE -eq 0) { return $true }
            Write-LogWarning "$Description failed (exit $LASTEXITCODE) - attempt $i/$MaxAttempts"
        } catch {
            Write-LogWarning "$Description failed ($($_.Exception.Message)) - attempt $i/$MaxAttempts"
        }
        if ($i -lt $MaxAttempts) { Start-Sleep -Seconds $DelaySeconds }
    }
    return $false
}

#===============================================================================
# Download helper (mirrors download_file / retry_curl_download): retry + resume.
# Returns the local path on success, $null on failure.
#===============================================================================
function Get-FileDownload {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$OutFile
    )
    if (-not $OutFile) {
        $name = [System.IO.Path]::GetFileName(([Uri]$Url).AbsolutePath)
        if (-not $name) { $name = "download_$([Guid]::NewGuid().ToString('N')).tmp" }
        $OutFile = Join-Path $env:TEMP $name
    }
    $ok = Invoke-WithRetry -Description "download $Url" -Action {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -MaximumRedirection 5
    }
    if ($ok -and (Test-Path -LiteralPath $OutFile)) { return $OutFile }
    return $null
}

#===============================================================================
# Detection helpers
#===============================================================================
function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# --- Detection caches -------------------------------------------------------
# Detection is called dozens of times when the menu opens; without caching that
# means dozens of slow `winget list` spawns + registry scans (the source of the
# menu lag). We snapshot both ONCE and reuse. Reset after installs so a later
# summary re-reads fresh state.
$script:_WingetListText = $null
$script:_InstalledNames = $null

function Reset-DetectionCache {
    $script:_WingetListText = $null
    $script:_InstalledNames = $null
}

function Get-WingetListText {
    if ($null -ne $script:_WingetListText) { return $script:_WingetListText }
    $script:_WingetListText = ''
    if (Test-Command 'winget') {
        try { $script:_WingetListText = (winget list --accept-source-agreements 2>$null | Out-String) } catch { }
    }
    return $script:_WingetListText
}

function Get-InstalledDisplayNames {
    if ($null -ne $script:_InstalledNames) { return $script:_InstalledNames }
    $names = New-Object System.Collections.ArrayList
    foreach ($k in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
        try {
            Get-ItemProperty $k -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName } |
                ForEach-Object { [void]$names.Add([string]$_.DisplayName) }
        } catch { }
    }
    $script:_InstalledNames = $names
    return $script:_InstalledNames
}

# Is an app present? Checks a command name and/or a display-name match and/or a winget id.
# Uses cached registry + winget snapshots so it is cheap to call many times.
function Test-App {
    param([string]$Command, [string]$WingetId, [string]$DisplayNameLike)
    if ($Command -and (Test-Command $Command)) { return $true }
    if ($DisplayNameLike) {
        foreach ($n in (Get-InstalledDisplayNames)) { if ($n -like $DisplayNameLike) { return $true } }
    }
    if ($WingetId) {
        $wl = Get-WingetListText
        if ($wl -and ($wl -match [regex]::Escape($WingetId))) { return $true }
    }
    return $false
}

#===============================================================================
# Prerequisites: ensure winget is present; lazily bootstrap Chocolatey when needed.
#===============================================================================
function Test-Winget { Test-Command 'winget' }

function Install-Choco {
    if (Test-Command 'choco') { return $true }
    Write-LogInfo "Bootstrapping Chocolatey..."
    $ok = Invoke-WithRetry -Description 'install Chocolatey' -Action {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
    if ($ok) { $env:Path += ";$env:ProgramData\chocolatey\bin" }
    return $ok
}

function Install-Prerequisites {
    if (-not (Test-Winget)) {
        Write-LogWarning "winget (App Installer) not found. Some installs will fall back to direct download / Chocolatey."
    }
}

#===============================================================================
# Install-App: the central installer.
#   Order: -Detect (skip if installed) -> -Direct -> winget -> choco
# Every attempt is wrapped in Invoke-WithRetry.
#===============================================================================
function Install-App {
    param(
        [Parameter(Mandatory)][string]$Name,
        [scriptblock]$Detect,
        [scriptblock]$Direct,
        [string]$WingetId,
        [string]$ChocoId,
        [scriptblock]$PostInstall,
        [switch]$ForceReinstall
    )
    Write-LogStep "Installing $Name"

    if ($Detect -and (& $Detect) -and -not $ForceReinstall) {
        Write-LogInfo "$Name is already installed - skipping."
        return $true
    }

    $installed = $false

    # (1) Direct official download + silent install
    if ($Direct) {
        Write-LogInfo "${Name}: trying direct download from the official source..."
        if (Invoke-WithRetry -Description "$Name (direct)" -Action $Direct) { $installed = $true }
    }

    # (2) winget
    if (-not $installed -and $WingetId -and (Test-Winget)) {
        Write-LogInfo "${Name}: trying winget ($WingetId)..."
        $installed = Invoke-WithRetry -Description "$Name (winget)" -Action {
            winget install --id $WingetId -e --silent --accept-package-agreements --accept-source-agreements
        }
    }

    # (3) choco
    if (-not $installed -and $ChocoId) {
        if (Install-Choco) {
            Write-LogInfo "${Name}: trying Chocolatey ($ChocoId)..."
            $installed = Invoke-WithRetry -Description "$Name (choco)" -Action {
                choco install $ChocoId -y --no-progress
            }
        }
    }

    if ($installed) {
        if ($PostInstall) { & $PostInstall }
        Write-LogSuccess "$Name installed."
        return $true
    }

    Invoke-ErrorHandler "Failed to install $Name (direct, winget and choco all failed)."
    return $false
}

#===============================================================================
# Help
#===============================================================================
function Show-Help {
    Write-Host @"
Windows Post-Installation Setup Script v$($script:SCRIPT_VERSION)

USAGE:
  irm https://bit.ly/windows-ey | iex                                # interactive menu
  & ([scriptblock]::Create((irm 'https://bit.ly/windows-ey'))) --all # everything
  .\windows-setup.ps1 [options]

GENERAL:
  --menu            Interactive menu to pick & choose (default when no flags)
  --all             Install everything (non-interactive)
  --help            Show this help
  --version         Show version

DEV TOOLS:
  --nodejs          Node.js (via nvm-windows)
  --python          Python 3
  --docker          Docker Desktop
  --chrome          Google Chrome
  --vscode          Visual Studio Code (+ extensions submenu)
  --dbeaver         DBeaver Community
  --vlc             VLC Media Player
  --cloudflared     Cloudflare Tunnel client
  --gh              GitHub CLI
  --postman         Postman
  --filezilla       FileZilla

AI CLI TOOLS:
  --claude          Claude Code (Anthropic)
  --codex           Codex (OpenAI)
  --kimi            Kimi Code (Moonshot AI)
  --grok            Grok (xAI)
  --gemini          Gemini CLI (Google)
  --qwen            Qwen Code (Alibaba)
  --glm             GLM Code (z.ai)
  --glm-opencode    OpenCode preconfigured for z.ai GLM

REMOTE SUPPORT:
  --vnc             RealVNC Connect
  --anydesk         AnyDesk
  --rustdesk        RustDesk
  --teamviewer      TeamViewer

WINDOWS TWEAKS / DEBLOAT:
  --tweaks          Windows desktop tweaks + settings (submenu)
  --debloat         Remove pre-installed Windows bloat (submenu)

HELPERS:
  --login           CLI login helpers
  --skip-update     Skip the self-update check
  --show-backup     Show current settings backup
  --restore         Restore previous settings

Repository: https://github.com/enginyilmaaz/windows-setup-script
"@
}

function Show-Version {
    Write-Host "Windows Post-Installation Setup Script v$($script:SCRIPT_VERSION) (rev-$($script:SCRIPT_REVISION), $($script:SCRIPT_DATE))"
}

#===============================================================================
# Catalog — the single data model the menu AND the flag dispatcher both read.
# Each record names an Install/Apply function and a Detect function that live in
# the other fragments. Keep the function names here in sync with those fragments.
#===============================================================================

# Top-level dev tools (each toggles an install)
$script:DevTools = @(
    @{ Key='nodejs';      Flag='NodeJs';      Label='Node.js (nvm-windows)';  Install='Install-NodeJs';      Detect='Test-NodeJsInstalled' }
    @{ Key='python';      Flag='Python';      Label='Python 3';               Install='Install-Python';      Detect='Test-PythonInstalled' }
    @{ Key='docker';      Flag='Docker';      Label='Docker Desktop';         Install='Install-Docker';      Detect='Test-DockerInstalled' }
    @{ Key='chrome';      Flag='Chrome';      Label='Google Chrome';          Install='Install-Chrome';      Detect='Test-ChromeInstalled' }
    @{ Key='vscode';      Flag='VSCode';      Label='Visual Studio Code';     Install='Install-VSCode';      Detect='Test-VSCodeInstalled'; SubMenu='vscode' }
    @{ Key='dbeaver';     Flag='DBeaver';     Label='DBeaver Community';      Install='Install-DBeaver';     Detect='Test-DBeaverInstalled' }
    @{ Key='vlc';         Flag='Vlc';         Label='VLC Media Player';       Install='Install-Vlc';         Detect='Test-VlcInstalled' }
    @{ Key='cloudflared'; Flag='Cloudflared'; Label='Cloudflare Tunnel';      Install='Install-Cloudflared'; Detect='Test-CloudflaredInstalled' }
    @{ Key='gh';          Flag='Gh';          Label='GitHub CLI';             Install='Install-Gh';          Detect='Test-GhInstalled' }
    @{ Key='postman';     Flag='Postman';     Label='Postman';                Install='Install-Postman';     Detect='Test-PostmanInstalled' }
    @{ Key='filezilla';   Flag='FileZilla';   Label='FileZilla';              Install='Install-FileZilla';   Detect='Test-FileZillaInstalled' }
)

# AI CLI tools (submenu group)
$script:AiCliTools = @(
    @{ Key='claude';   Flag='Claude';   Label='Claude Code (Anthropic)'; Install='Install-Claude';       Detect='Test-ClaudeInstalled' }
    @{ Key='codex';    Flag='Codex';    Label='Codex (OpenAI)';          Install='Install-Codex';        Detect='Test-CodexInstalled' }
    @{ Key='kimi';     Flag='Kimi';     Label='Kimi Code (Moonshot AI)'; Install='Install-Kimi';         Detect='Test-KimiInstalled' }
    @{ Key='grok';     Flag='Grok';     Label='Grok (xAI)';              Install='Install-Grok';         Detect='Test-GrokInstalled' }
    @{ Key='gemini';   Flag='Gemini';   Label='Gemini CLI (Google)';     Install='Install-Gemini';       Detect='Test-GeminiInstalled' }
    @{ Key='qwen';     Flag='Qwen';     Label='Qwen Code (Alibaba)';     Install='Install-Qwen';         Detect='Test-QwenInstalled' }
    @{ Key='glm';      Flag='Glm';      Label='GLM Code (z.ai)';         Install='Install-Glm';          Detect='Test-GlmInstalled' }
    @{ Key='opencode'; Flag='Opencode'; Label='GLM with OpenCode';       Install='Install-GlmOpencode';  Detect='Test-GlmOpencodeInstalled' }
)

# Remote support tools (submenu group)
$script:RemoteTools = @(
    @{ Key='vnc';        Flag='Vnc';        Label='RealVNC Connect'; Install='Install-RealVNC';    Detect='Test-RealVNCInstalled' }
    @{ Key='anydesk';    Flag='AnyDesk';    Label='AnyDesk';         Install='Install-AnyDesk';    Detect='Test-AnyDeskInstalled' }
    @{ Key='rustdesk';   Flag='RustDesk';   Label='RustDesk';        Install='Install-RustDesk';   Detect='Test-RustDeskInstalled' }
    @{ Key='teamviewer'; Flag='TeamViewer'; Label='TeamViewer';      Install='Install-TeamViewer'; Detect='Test-TeamViewerInstalled' }
)

# Windows tweaks (submenu group) — Windows-native equivalents of the GNOME tweaks
$script:WindowsTweaks = @(
    @{ Key='update-system';    Label='Update System (winget upgrade --all)'; Apply='Update-WindowsSystem' }
    @{ Key='script-launcher';  Label='Script Launcher (right-click menu)';   Apply='Set-ScriptLauncherContextMenu' }
    @{ Key='openssh';          Label='OpenSSH Server';                       Apply='Enable-OpenSSHServer' }
    @{ Key='hostname';         Label='Change Hostname';                      Apply='Set-ComputerHostname'; NeedsInput='hostname' }
    @{ Key='cli-aliases';      Label='CLI Aliases (claude-skip, etc.)';      Apply='Set-CliAliases' }
    @{ Key='screen-never-off'; Label='Screen Off: Never';                    Apply='Disable-ScreenTimeout' }
    @{ Key='show-hidden';      Label='Show Hidden Files + Extensions';       Apply='Show-HiddenFiles' }
    @{ Key='keyboard-tr-q';    Label='Keyboard: Turkish Q';                  Apply='Add-KeyboardTurkishQ' }
    @{ Key='keyboard-en-q';    Label='Keyboard: English Q';                  Apply='Add-KeyboardEnglishQ' }
    @{ Key='english-language'; Label='English Language (en-US)';             Apply='Set-DisplayLanguageEnglish' }
    @{ Key='auto-login';       Label='Auto-Login on boot';                   Apply='Enable-AutoLogin' }
    @{ Key='tray-icons';       Label='Always Show All Tray Icons';           Apply='Set-AlwaysShowTrayIcons' }
    @{ Key='taskbar';          Label='Taskbar Tweaks';                       Apply='Set-TaskbarTweaks' }
    @{ Key='error-reporting';  Label='Activate Error Reporting';             Apply='Enable-WindowsErrorReporting' }
    @{ Key='camera';           Label='Install Camera App';                   Apply='Install-CameraApp' }
    @{ Key='storage-sense';    Label='Cleanup: Storage Sense';               Apply='Enable-StorageSense' }
)

# VS Code extensions (VS Code submenu) — IDs mirror the source install_vscode_extensions
$script:VSCodeExtensions = @(
    @{ Key='claude';    Id='anthropic.claude-code';                   Label='Claude Code' }
    @{ Key='codex';     Id='openai.chatgpt';                          Label='Codex / ChatGPT' }
    @{ Key='python';    Id='ms-python.python';                        Label='Python' }
    @{ Key='pylance';   Id='ms-python.vscode-pylance';                Label='Pylance' }
    @{ Key='gitlens';   Id='eamodio.gitlens';                         Label='GitLens' }
    @{ Key='prettier';  Id='esbenp.prettier-vscode';                  Label='Prettier' }
    @{ Key='eslint';    Id='dbaeumer.vscode-eslint';                  Label='ESLint' }
    @{ Key='docker';    Id='ms-azuretools.vscode-docker';             Label='Docker' }
    @{ Key='icons';     Id='PKief.material-icon-theme';               Label='Material Icon Theme' }
)

#===============================================================================
# DEV TOOLS installers (Windows counterpart of ubuntu-setup.sh dev tools)
#
# Fragment file: ONLY function definitions. No #Requires / no main / no arg parse.
# Relies on shared helpers already defined in windows-setup.ps1:
#   Write-Log* / Invoke-WithRetry / Get-FileDownload / Test-Command / Test-App /
#   Install-App / $script:USER_HOME / $script:BACKUP_DIR
# PowerShell 5.1 compatible (no ternary / ?? / && / -Parallel).
#===============================================================================

#===============================================================================
# 1. Node.js 22 (via nvm-windows) + Yarn   [source: install_nvm_nodejs, Node 22]
#===============================================================================
function Install-NodeJs {
    return Install-App -Name 'Node.js 22 (nvm-windows) + Yarn' `
        -Detect {
            if (-not (Test-Command 'node')) { return $false }
            $v = & node -v 2>$null
            return ([string]$v -like 'v22*')
        } `
        -Direct {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
            $rel = Invoke-RestMethod 'https://api.github.com/repos/coreybutler/nvm-windows/releases/latest' -Headers @{ 'User-Agent' = 'windows-setup' }
            $asset = $rel.assets | Where-Object { $_.name -eq 'nvm-setup.exe' } | Select-Object -First 1
            if (-not $asset) { $asset = $rel.assets | Where-Object { $_.name -like '*nvm-setup*.exe' } | Select-Object -First 1 }
            if (-not $asset) { throw 'nvm-setup.exe asset not found' }
            $f = Get-FileDownload -Url $asset.browser_download_url
            if (-not $f) { throw 'download failed' }
            $p = Start-Process -FilePath $f -ArgumentList '/SILENT' -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "installer exit $($p.ExitCode)" }
        } `
        -WingetId 'CoreyButler.NVMforWindows' -ChocoId 'nvm' `
        -PostInstall {
            # Refresh env (vars + PATH) from the registry so NVM_HOME / nvm are visible now.
            foreach ($scope in @('Machine', 'User')) {
                $vars = [Environment]::GetEnvironmentVariables($scope)
                foreach ($name in $vars.Keys) {
                    if ($name -ieq 'Path') { continue }
                    [Environment]::SetEnvironmentVariable($name, $vars[$name], 'Process')
                }
            }
            $mp = [Environment]::GetEnvironmentVariable('Path', 'Machine')
            $up = [Environment]::GetEnvironmentVariable('Path', 'User')
            $env:Path = (@($mp, $up) | Where-Object { $_ }) -join ';'

            # Resolve nvm.exe robustly (NVM_HOME, %APPDATA%\nvm, Program Files, PATH).
            $nvmExe = $null
            foreach ($cand in @(
                    (Join-Path ([string]$env:NVM_HOME) 'nvm.exe'),
                    (Join-Path ([string]$env:APPDATA) 'nvm\nvm.exe'),
                    (Join-Path ([string]$env:ProgramFiles) 'nvm\nvm.exe'))) {
                if ($cand -and (Test-Path -LiteralPath $cand)) { $nvmExe = $cand; break }
            }
            if (-not $nvmExe) {
                $c = Get-Command nvm -ErrorAction SilentlyContinue
                if ($c) { $nvmExe = $c.Source }
            }

            if ($nvmExe) {
                Write-LogInfo "Installing Node.js 22 via nvm ($nvmExe)..."
                & $nvmExe install 22
                & $nvmExe use 22
                & $nvmExe alias default 22
                # Re-refresh PATH so the new node symlink dir (NVM_SYMLINK) is picked up.
                $mp = [Environment]::GetEnvironmentVariable('Path', 'Machine')
                $up = [Environment]::GetEnvironmentVariable('Path', 'User')
                $env:Path = (@($mp, $up) | Where-Object { $_ }) -join ';'

                if (Test-Command 'npm') {
                    Write-LogInfo "Installing Yarn globally (npm install -g yarn)..."
                    npm install -g yarn
                    if ($LASTEXITCODE -ne 0) { Write-LogWarning "Yarn installation failed; run 'npm install -g yarn' in a new terminal." }
                } else {
                    Write-LogWarning "npm not on PATH yet. Open a NEW terminal, then run: npm install -g yarn"
                }
                Write-LogWarning "If 'node' / 'nvm' are not recognized, open a NEW terminal (PATH was updated)."
            } else {
                Write-LogWarning "nvm.exe not found after install. Open a NEW terminal, then run:"
                Write-LogWarning "  nvm install 22 ; nvm use 22 ; nvm alias default 22 ; npm install -g yarn"
            }
        }
}
function Test-NodeJsInstalled { Test-Command 'node' }

#===============================================================================
# 7. Python 3   [source: install_python]  -- winget primary (no stable latest URL)
#===============================================================================
function Install-Python {
    return Install-App -Name 'Python 3' `
        -Detect { (Test-Command 'python') -or (Test-Command 'py') } `
        -WingetId 'Python.Python.3.12' -ChocoId 'python'
}
function Test-PythonInstalled { (Test-Command 'python') -or (Test-Command 'py') }

#===============================================================================
# 12. Docker Desktop   [source: install_docker]
#===============================================================================
function Install-Docker {
    return Install-App -Name 'Docker Desktop' `
        -Detect { Test-App -Command 'docker' -DisplayNameLike '*Docker Desktop*' } `
        -Direct {
            $out = Join-Path $env:TEMP 'DockerDesktopInstaller.exe'
            $f = Get-FileDownload -Url 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe' -OutFile $out
            if (-not $f) { throw 'download failed' }
            $p = Start-Process -FilePath $f -ArgumentList 'install', '--quiet', '--accept-license' -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "installer exit $($p.ExitCode)" }
        } `
        -WingetId 'Docker.DockerDesktop' -ChocoId 'docker-desktop'
}
function Test-DockerInstalled { Test-App -Command 'docker' -DisplayNameLike '*Docker Desktop*' }

#===============================================================================
# 3. Google Chrome (+ search-engine policy + recommended extensions)
#    [source: install_chrome / configure_chromium_search_engines / open_browser_extensions]
#===============================================================================
function Install-Chrome {
    return Install-App -Name 'Google Chrome' `
        -Detect { Test-App -Command 'chrome' -DisplayNameLike '*Google Chrome*' } `
        -Direct {
            $f = Get-FileDownload -Url 'https://dl.google.com/chrome/install/standalone/ChromeStandaloneSetup64.exe'
            if (-not $f) { throw 'download failed' }
            $p = Start-Process -FilePath $f -ArgumentList '/silent', '/install' -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "installer exit $($p.ExitCode)" }
        } `
        -WingetId 'Google.Chrome' -ChocoId 'googlechrome' `
        -PostInstall {
            Set-ChromeSearchEngines
            Open-BrowserExtensions
        }
}
function Test-ChromeInstalled { Test-App -Command 'chrome' -DisplayNameLike '*Google Chrome*' }

# Configure Chrome search engines via managed policy (Google default + DuckDuckGo/Bing/Yahoo).
# Windows equivalent of the Linux managed-policy JSON: HKLM\SOFTWARE\Policies\Google\Chrome.
function Set-ChromeSearchEngines {
    Write-LogInfo "Configuring Chrome search engines (Google default + DuckDuckGo, Bing, Yahoo)..."
    $key = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
    try {
        if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }

        # Default search provider (well-established, stable Chrome policy keys).
        New-ItemProperty -Path $key -Name 'DefaultSearchProviderEnabled'   -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $key -Name 'DefaultSearchProviderName'       -Value 'Google' -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $key -Name 'DefaultSearchProviderSearchURL'  -Value 'https://www.google.com/search?q={searchTerms}' -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $key -Name 'DefaultSearchProviderSuggestURL' -Value 'https://www.google.com/complete/search?output=chrome&q={searchTerms}' -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $key -Name 'DefaultSearchProviderKeyword'    -Value 'google.com' -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $key -Name 'DefaultSearchProviderIconURL'    -Value 'https://www.google.com/favicon.ico' -PropertyType String -Force | Out-Null

        # ManagedSearchEngines: adds DuckDuckGo/Bing/Yahoo as selectable engines.
        # NOTE (uncertain): this policy is newer (Chrome 132+) and is stored as a
        # JSON string; older Chrome ignores it. Default provider above is the reliable part.
        $managed = @(
            @{ name = 'Google';     keyword = 'google.com';     search_url = 'https://www.google.com/search?q={searchTerms}'; is_default = $true },
            @{ name = 'DuckDuckGo'; keyword = 'duckduckgo.com'; search_url = 'https://duckduckgo.com/?q={searchTerms}' },
            @{ name = 'Bing';       keyword = 'bing.com';       search_url = 'https://www.bing.com/search?q={searchTerms}' },
            @{ name = 'Yahoo';      keyword = 'yahoo.com';      search_url = 'https://search.yahoo.com/search?p={searchTerms}' }
        )
        $json = $managed | ConvertTo-Json -Compress -Depth 5
        New-ItemProperty -Path $key -Name 'ManagedSearchEngines' -Value $json -PropertyType String -Force | Out-Null

        Write-LogSuccess "Chrome search engines configured (Google default + DuckDuckGo, Bing, Yahoo)"
    } catch {
        Write-LogWarning "Could not fully configure Chrome search-engine policy: $($_.Exception.Message)"
    }
}

# Open recommended browser extensions after install (uBlock Origin + Claude).
function Open-BrowserExtensions {
    $extensions = @(
        'https://chromewebstore.google.com/detail/ublock/epcnnfbjfcgphgdmggkamkmgojdagdnn',
        'https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn'
    )
    Write-LogInfo "Opening recommended browser extensions for install..."
    Write-LogInfo "Please click 'Add to Chrome' for each extension tab"

    # Locate chrome.exe (fall back to the default browser via Start-Process url).
    $chrome = $null
    $pf    = [Environment]::GetEnvironmentVariable('ProgramFiles')
    $pfx86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $lad   = [Environment]::GetEnvironmentVariable('LOCALAPPDATA')
    $cands = @()
    if ($pf)    { $cands += (Join-Path $pf    'Google\Chrome\Application\chrome.exe') }
    if ($pfx86) { $cands += (Join-Path $pfx86 'Google\Chrome\Application\chrome.exe') }
    if ($lad)   { $cands += (Join-Path $lad   'Google\Chrome\Application\chrome.exe') }
    foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { $chrome = $c; break } }

    foreach ($url in $extensions) {
        try {
            if ($chrome) { Start-Process -FilePath $chrome -ArgumentList $url | Out-Null }
            else { Start-Process $url | Out-Null }
        } catch {
            Write-LogWarning "Could not open $url"
        }
        Start-Sleep -Seconds 1
    }
    Write-LogSuccess "Extension pages opened in browser (uBlock, Claude)"
}

#===============================================================================
# 6. Visual Studio Code (+ extensions + user settings)
#    [source: install_vscode / install_vscode_extensions / configure_vscode_settings]
#===============================================================================
function Install-VSCode {
    return Install-App -Name 'Visual Studio Code' `
        -Detect { Test-App -Command 'code' -DisplayNameLike '*Visual Studio Code*' } `
        -Direct {
            $out = Join-Path $env:TEMP 'VSCodeUserSetup-x64.exe'
            $f = Get-FileDownload -Url 'https://update.code.visualstudio.com/latest/win32-x64-user/stable' -OutFile $out
            if (-not $f) { throw 'download failed' }
            $p = Start-Process -FilePath $f -ArgumentList '/verysilent', '/suppressmsgboxes', '/mergetasks=!runcode,addcontextmenufiles,addcontextmenufolders,addtopath' -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "installer exit $($p.ExitCode)" }
        } `
        -WingetId 'Microsoft.VisualStudioCode' -ChocoId 'vscode' `
        -PostInstall {
            # Refresh PATH so the 'code' CLI is usable in this session.
            $mp = [Environment]::GetEnvironmentVariable('Path', 'Machine')
            $up = [Environment]::GetEnvironmentVariable('Path', 'User')
            $env:Path = (@($mp, $up) | Where-Object { $_ }) -join ';'
            Install-VSCodeExtensions
            Set-VSCodeSettings
        }
}
function Test-VSCodeInstalled { Test-App -Command 'code' -DisplayNameLike '*Visual Studio Code*' }

# Install the exact extension set from the source (install_vscode_extensions).
function Install-VSCodeExtensions {
    param([string[]]$Ids)
    Write-LogInfo "Installing VS Code extensions..."

    # Resolve the 'code' CLI (code.cmd) even if PATH is not refreshed yet.
    $code = $null
    $c = Get-Command code -ErrorAction SilentlyContinue
    if ($c) { $code = $c.Source }
    if (-not $code) {
        foreach ($p in @(
                (Join-Path ([string]$env:LOCALAPPDATA) 'Programs\Microsoft VS Code\bin\code.cmd'),
                (Join-Path ([string]$env:ProgramFiles) 'Microsoft VS Code\bin\code.cmd'))) {
            if ($p -and (Test-Path -LiteralPath $p)) { $code = $p; break }
        }
    }
    if (-not $code) {
        Write-LogWarning "VS Code CLI (code) not found; skipping extensions."
        return
    }

    # EXACT ids from source (ubuntu-setup.sh 3995-4003).
    $extensions = @(
        @{ id = 'anthropic.claude-code';       label = 'Claude Code' },
        @{ id = 'openai.chatgpt';              label = 'Codex / ChatGPT' },
        @{ id = 'ms-python.python';            label = 'Python' },
        @{ id = 'ms-python.vscode-pylance';    label = 'Pylance' },
        @{ id = 'eamodio.gitlens';             label = 'GitLens' },
        @{ id = 'esbenp.prettier-vscode';      label = 'Prettier' },
        @{ id = 'dbaeumer.vscode-eslint';      label = 'ESLint' },
        @{ id = 'ms-azuretools.vscode-docker'; label = 'Docker' },
        @{ id = 'pkief.material-icon-theme';   label = 'Material Icon Theme' }
    )

    # If specific ids were requested (from the menu), install just those.
    if ($Ids -and $Ids.Count -gt 0) {
        $extensions = $Ids | ForEach-Object {
            $id = $_
            $m = $extensions | Where-Object { $_.id -eq $id } | Select-Object -First 1
            if ($m) { $m } else { @{ id = $id; label = $id } }
        }
    }

    $installed = @()
    try { $installed = & $code --list-extensions 2>$null } catch { $installed = @() }

    foreach ($ext in $extensions) {
        if ($installed -contains $ext.id) {
            Write-LogWarning "$($ext.label) extension already installed, skipping..."
        } else {
            Write-LogInfo "Installing $($ext.label) extension..."
            & $code --install-extension $ext.id --force 2>$null
            if ($LASTEXITCODE -ne 0) { Write-LogWarning "Could not install $($ext.label) extension" }
        }
    }
    Write-LogSuccess "VS Code extensions installation completed"
}

# Write the EXACT VS Code user settings from source to %APPDATA%\Code\User\settings.json.
# Merges into any existing settings (our keys win); never clobbers unrelated user keys.
function Set-VSCodeSettings {
    Write-LogInfo "Configuring VS Code user settings..."

    $appData = $env:APPDATA
    if (-not $appData) { $appData = Join-Path $script:USER_HOME 'AppData\Roaming' }
    $settingsDir  = Join-Path $appData 'Code\User'
    $settingsFile = Join-Path $settingsDir 'settings.json'
    if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null }

    $zwsp = [string][char]0x200B   # zero-width space key (matches source exactly)

    # Desired settings - byte-for-byte the source configure_vscode_settings block.
    $desired = [ordered]@{
        'editor.defaultFormatter'                    = 'vscode.typescript-language-features'
        'git.confirmSync'                            = $false
        'github.experimental.multipleAccounts'       = $true
        'editor.unicodeHighlight.allowedCharacters'  = ([ordered]@{ "$zwsp" = $true })
        'editor.codeActionsOnSave'                   = ([ordered]@{
                'source.fixAll.eslint'    = 'explicit'
                'source.fixAll.stylelint' = 'never'
                'source.fixAll.tslint'    = 'explicit'
            })
        'css.validate'                               = $true
        'less.validate'                              = $false
        'scss.validate'                              = $true
        'security.workspace.trust.untrustedFiles'    = 'open'
        '[scss]'                                     = ([ordered]@{ 'editor.defaultFormatter' = 'vscode.css-language-features' })
        '[javascript]'                               = ([ordered]@{ 'editor.defaultFormatter' = 'vscode.typescript-language-features' })
        '[html]'                                     = ([ordered]@{ 'editor.defaultFormatter' = 'vscode.html-language-features' })
        'editor.formatOnSave'                        = $true
        '[markdown]'                                 = ([ordered]@{ 'editor.rulers' = @(80) })
        'eslint.validate'                            = @('javascript', 'javascriptreact', 'markdown', 'typescript', 'typescriptreact')
        'stylelint.validate'                         = @('scss')
        '[typescript]'                               = ([ordered]@{ 'editor.defaultFormatter' = 'vscode.typescript-language-features' })
        '[json]'                                     = ([ordered]@{ 'editor.defaultFormatter' = 'vscode.typescript-language-features' })
        'workbench.colorTheme'                       = 'Visual Studio Light'
        'editor.fontSize'                            = 13
        'editor.minimap.enabled'                     = $false
        'telemetry.telemetryLevel'                   = 'off'
        'git.suggestSmartCommit'                     = $false
        'extensions.ignoreRecommendations'           = $true
        'workbench.layoutControl.enabled'            = $false
        'window.customTitleBarVisibility'            = 'windowed'
        'window.titleBarStyle'                       = 'custom'
        'githubPullRequests.fileListLayout'          = 'flat'
        'workbench.editor.enablePreview'             = $false
        'workbench.startupEditor'                    = 'none'
        'editor.unicodeHighlight.ambiguousCharacters' = $false
        'workbench.editor.centeredLayoutAutoResize'  = $false
        'githubPullRequests.pullBranch'              = 'never'
        'diffEditor.ignoreTrimWhitespace'            = $false
        'diffEditor.hideUnchangedRegions.enabled'    = $true
        'terminal.integrated.env.linux'              = ([ordered]@{})
        'git.openRepositoryInParentFolders'          = 'never'
        'gitblame.inlineMessageEnabled'              = $true
        'githubPullRequests.createOnPublishBranch'   = 'never'
        'terminal.integrated.stickyScroll.enabled'   = $false
        'claudeCode.selectedModel'                   = 'default'
        'editor.stickyScroll.enabled'                = $false
        'editor.stickyScroll.scrollWithEditor'       = $false
        'workbench.tree.enableStickyScroll'          = $false
        'workbench.settings.showAISearchToggle'      = $false
        'chatgpt.cliExecutable'                      = ''
        'chat.disableAIFeatures'                     = $true
        'claudeCode.preferredLocation'               = 'panel'
        'claudeCode.allowDangerouslySkipPermissions' = $true
        'claudeCode.initialPermissionMode'           = 'bypassPermissions'
        'git.autofetch'                              = $true
        'gitblame.revsFile'                          = @()
    }

    # Merge: start from existing (if it parses), then overlay our keys.
    $final = [ordered]@{}
    if (Test-Path -LiteralPath $settingsFile) {
        $raw = $null
        try { $raw = Get-Content -Raw -LiteralPath $settingsFile -ErrorAction Stop } catch { $raw = $null }
        $existing = $null
        if ($raw) { try { $existing = $raw | ConvertFrom-Json -ErrorAction Stop } catch { $existing = $null } }
        if ($existing) {
            foreach ($prop in $existing.PSObject.Properties) { $final[$prop.Name] = $prop.Value }
        } elseif ($raw) {
            # Existing file has comments/trailing commas (JSONC) - back it up, don't lose it.
            try {
                if (-not (Test-Path $script:BACKUP_DIR)) { New-Item -ItemType Directory -Force -Path $script:BACKUP_DIR | Out-Null }
                $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                Copy-Item -LiteralPath $settingsFile -Destination (Join-Path $script:BACKUP_DIR "vscode-settings.$stamp.json") -Force
                Write-LogWarning "Existing settings.json could not be parsed (comments?); backed up before rewriting."
            } catch {
                Write-LogWarning "Existing settings.json could not be parsed and backup failed; it will be overwritten."
            }
        }
    }
    foreach ($k in $desired.Keys) { $final[$k] = $desired[$k] }

    $json = $final | ConvertTo-Json -Depth 20
    # PowerShell 5.1 renders an empty array property as "" - restore it to [] for revsFile.
    $json = $json -replace '("gitblame\.revsFile"\s*:\s*)""', '$1[]'

    [System.IO.File]::WriteAllText($settingsFile, $json, (New-Object System.Text.UTF8Encoding($false)))
    Write-LogSuccess "VS Code user settings configured ($settingsFile)"
}

#===============================================================================
# 9. DBeaver Community   [source: install_dbeaver]
#===============================================================================
function Install-DBeaver {
    return Install-App -Name 'DBeaver Community' `
        -Detect { Test-App -Command 'dbeaver' -DisplayNameLike '*DBeaver*' } `
        -Direct {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
            $rel = Invoke-RestMethod 'https://api.github.com/repos/dbeaver/dbeaver/releases/latest' -Headers @{ 'User-Agent' = 'windows-setup' }
            $asset = $rel.assets | Where-Object { $_.name -like '*-x86_64-setup.exe' } | Select-Object -First 1
            if (-not $asset) { throw 'asset not found' }
            $f = Get-FileDownload -Url $asset.browser_download_url
            if (-not $f) { throw 'download failed' }
            $p = Start-Process -FilePath $f -ArgumentList '/S' -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "installer exit $($p.ExitCode)" }
        } `
        -WingetId 'DBeaver.DBeaver' -ChocoId 'dbeaver'
}
function Test-DBeaverInstalled { Test-App -Command 'dbeaver' -DisplayNameLike '*DBeaver*' }

#===============================================================================
# 10. VLC Media Player   [source: install_vlc]  -- winget primary (versioned URL)
#===============================================================================
function Install-Vlc {
    return Install-App -Name 'VLC Media Player' `
        -Detect { Test-App -Command 'vlc' -DisplayNameLike '*VLC media player*' } `
        -WingetId 'VideoLAN.VLC' -ChocoId 'vlc'
}
function Test-VlcInstalled { Test-App -Command 'vlc' -DisplayNameLike '*VLC media player*' }

#===============================================================================
# 11. Cloudflared (Cloudflare Tunnel client)   [source: install_cloudflared]
#===============================================================================
function Install-Cloudflared {
    return Install-App -Name 'Cloudflared' `
        -Detect { Test-CloudflaredInstalled } `
        -Direct {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
            $rel = Invoke-RestMethod 'https://api.github.com/repos/cloudflare/cloudflared/releases/latest' -Headers @{ 'User-Agent' = 'windows-setup' }
            $asset = $rel.assets | Where-Object { $_.name -eq 'cloudflared-windows-amd64.exe' } | Select-Object -First 1
            if (-not $asset) { throw 'asset not found' }
            $f = Get-FileDownload -Url $asset.browser_download_url
            if (-not $f) { throw 'download failed' }

            $destDir = Join-Path $env:ProgramFiles 'cloudflared'
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
            $dest = Join-Path $destDir 'cloudflared.exe'
            Copy-Item -LiteralPath $f -Destination $dest -Force
            if (-not (Test-Path -LiteralPath $dest)) { throw 'copy failed' }

            # Add the install dir to the machine PATH (persist) + current session.
            $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
            if (($machinePath -split ';') -notcontains $destDir) {
                [Environment]::SetEnvironmentVariable('Path', ($machinePath.TrimEnd(';') + ';' + $destDir), 'Machine')
            }
            $env:Path = $env:Path.TrimEnd(';') + ';' + $destDir
        } `
        -WingetId 'Cloudflare.cloudflared' -ChocoId 'cloudflared'
}
function Test-CloudflaredInstalled {
    if (Test-Command 'cloudflared') { return $true }
    return (Test-Path -LiteralPath (Join-Path ([string]$env:ProgramFiles) 'cloudflared\cloudflared.exe'))
}

#===============================================================================
# GitHub CLI (gh)   [source: install_gh]
#===============================================================================
function Install-Gh {
    return Install-App -Name 'GitHub CLI (gh)' `
        -Detect { Test-App -Command 'gh' -DisplayNameLike '*GitHub CLI*' } `
        -Direct {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
            $rel = Invoke-RestMethod 'https://api.github.com/repos/cli/cli/releases/latest' -Headers @{ 'User-Agent' = 'windows-setup' }
            $asset = $rel.assets | Where-Object { $_.name -like '*windows_amd64.msi' } | Select-Object -First 1
            if (-not $asset) { throw 'asset not found' }
            $f = Get-FileDownload -Url $asset.browser_download_url
            if (-not $f) { throw 'download failed' }
            $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i', "`"$f`"", '/qn', '/norestart' -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "msiexec exit $($p.ExitCode)" }
        } `
        -WingetId 'GitHub.cli' -ChocoId 'gh'
}
function Test-GhInstalled { Test-App -Command 'gh' -DisplayNameLike '*GitHub CLI*' }

#===============================================================================
# Postman   [source: install_postman]
#===============================================================================
function Install-Postman {
    return Install-App -Name 'Postman' `
        -Detect { Test-App -Command 'postman' -DisplayNameLike '*Postman*' } `
        -Direct {
            $out = Join-Path $env:TEMP 'Postman-win64-Setup.exe'
            $f = Get-FileDownload -Url 'https://dl.pstmn.io/download/latest/win64' -OutFile $out
            if (-not $f) { throw 'download failed' }
            # Postman ships a Squirrel installer - it installs per-user unattended by default.
            $p = Start-Process -FilePath $f -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "installer exit $($p.ExitCode)" }
        } `
        -WingetId 'Postman.Postman' -ChocoId 'postman'
}
function Test-PostmanInstalled { Test-App -Command 'postman' -DisplayNameLike '*Postman*' }

#===============================================================================
# FileZilla   [source: install_filezilla]  -- winget primary (versioned URL)
#===============================================================================
function Install-FileZilla {
    return Install-App -Name 'FileZilla' `
        -Detect { Test-App -Command 'filezilla' -DisplayNameLike '*FileZilla*' } `
        -WingetId 'TimKosse.FileZilla.Client' -ChocoId 'filezilla'
}
function Test-FileZillaInstalled { Test-App -Command 'filezilla' -DisplayNameLike '*FileZilla*' }

#===============================================================================
# AI CLI TOOLS installers (Windows-native port of ubuntu-setup.sh AI CLI section)
#   Ported functions: install_claude_code / install_claude_plugins / install_codex /
#   install_kimi / install_grok / install_gemini / install_qwen / install_glm /
#   install_glm_opencode
#
# Depends on shared helpers already defined in windows-setup.ps1:
#   Write-Log*, Install-App, Test-App, Test-Command, Invoke-WithRetry,
#   Invoke-ErrorHandler, and Install-NodeJs (Node.js fragment).
# Fragment = function definitions ONLY (no top-level executable code).
#===============================================================================

#-------------------------------------------------------------------------------
# Private helper: refresh the current session PATH from the registry (Machine+User)
# and prepend the per-user bin dirs the CLI installers commonly drop binaries into,
# so a freshly-installed tool is detectable in the same run (Windows analog of the
# source's PATH export + `hash -r`).
#-------------------------------------------------------------------------------
function Update-AiCliSessionPath {
    try {
        $machine = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
        $user    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $merged  = @($machine, $user) | Where-Object { $_ }
        if ($merged) { $env:Path = ($merged -join ';') }
    } catch { }

    $candidateBins = @(
        (Join-Path $env:USERPROFILE '.local\bin'),
        (Join-Path $env:USERPROFILE '.claude\bin'),
        (Join-Path $env:USERPROFILE '.grok\bin'),
        (Join-Path $env:USERPROFILE '.opencode\bin')
    )
    foreach ($d in $candidateBins) {
        if ((Test-Path -LiteralPath $d) -and ($env:Path -notlike "*$d*")) {
            $env:Path = "$d;$env:Path"
        }
    }
}

#-------------------------------------------------------------------------------
# Private helper: preconfigure OpenCode to default to z.ai GLM (no secret stored).
# Writes $env:USERPROFILE\.config\opencode\opencode.json with the EXACT provider
# block from the source. If a config already exists it is NOT clobbered:
#   - already has a "zai" provider  -> left as-is
#   - no "zai" provider             -> the zai provider is MERGED in, preserving
#                                      every other existing key
#-------------------------------------------------------------------------------
function Set-OpencodeGlmConfig {
    $ocDir = Join-Path $env:USERPROFILE '.config\opencode'
    $ocCfg = Join-Path $ocDir 'opencode.json'
    if (-not (Test-Path -LiteralPath $ocDir)) {
        New-Item -ItemType Directory -Force -Path $ocDir | Out-Null
    }

    # EXACT config from ubuntu-setup.sh (single-quoted here-string => no expansion,
    # so $schema and {env:ZAI_API_KEY} are preserved verbatim).
    $exactJson = @'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "zai": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Z.ai (GLM)",
      "options": {
        "baseURL": "https://api.z.ai/api/coding/paas/v4",
        "apiKey": "{env:ZAI_API_KEY}"
      },
      "models": {
        "glm-5.2": { "name": "GLM-5.2" },
        "glm-5-turbo": { "name": "GLM-5-Turbo" }
      }
    }
  },
  "model": "zai/glm-5.2"
}
'@

    if (-not (Test-Path -LiteralPath $ocCfg)) {
        [System.IO.File]::WriteAllText($ocCfg, $exactJson)
        Write-LogSuccess "OpenCode configured: default model = z.ai GLM-5.2"
        return
    }

    $raw = Get-Content -LiteralPath $ocCfg -Raw
    if ($raw -match '"zai"') {
        Write-LogInfo "OpenCode already has a z.ai provider configured, leaving it as-is."
        return
    }

    # Merge the zai provider WITHOUT clobbering any existing key.
    try {
        $cfg = $raw | ConvertFrom-Json
        $zai = [pscustomobject]@{
            npm     = '@ai-sdk/openai-compatible'
            name    = 'Z.ai (GLM)'
            options = [pscustomobject]@{
                baseURL = 'https://api.z.ai/api/coding/paas/v4'
                apiKey  = '{env:ZAI_API_KEY}'
            }
            models  = [pscustomobject]@{
                'glm-5.2'     = [pscustomobject]@{ name = 'GLM-5.2' }
                'glm-5-turbo' = [pscustomobject]@{ name = 'GLM-5-Turbo' }
            }
        }
        if (-not $cfg.PSObject.Properties['provider']) {
            $cfg | Add-Member -NotePropertyName 'provider' -NotePropertyValue ([pscustomobject]@{}) -Force
        }
        $cfg.provider | Add-Member -NotePropertyName 'zai' -NotePropertyValue $zai -Force
        if ((-not $cfg.PSObject.Properties['model']) -or [string]::IsNullOrEmpty([string]$cfg.model)) {
            $cfg | Add-Member -NotePropertyName 'model' -NotePropertyValue 'zai/glm-5.2' -Force
        }
        $json = $cfg | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($ocCfg, $json)
        Write-LogSuccess "OpenCode configured: added z.ai GLM provider (existing keys preserved)"
    } catch {
        Write-LogWarning "Existing opencode.json found - not overwriting it ($($_.Exception.Message))."
        Write-LogInfo "  To default to GLM-5.2, add a 'zai' provider: https://docs.z.ai/scenario-example/develop-tools/opencode"
    }
}

#===============================================================================
# Claude Code (Anthropic) - native Windows installer, npm fallback
#===============================================================================
function Install-Claude {
    return Install-App -Name 'Claude Code (Anthropic)' `
        -Detect { Test-Command 'claude' } `
        -Direct {
            # Clean up any old npm-based install so it does not shadow the native one.
            if (Test-Command 'npm') {
                try { npm uninstall -g '@anthropic-ai/claude-code' 2>&1 | Out-Null } catch { }
            }

            # (1) Native Windows installer:  irm https://claude.ai/install.ps1 | iex
            Write-LogInfo "Installing Claude Code via native installer..."
            try {
                Invoke-Expression (Invoke-RestMethod -Uri 'https://claude.ai/install.ps1')
            } catch {
                Write-LogWarning "Native Claude installer failed: $($_.Exception.Message)"
            }
            Update-AiCliSessionPath

            # (2) npm fallback if the native installer did not put 'claude' on PATH.
            if (-not (Test-Command 'claude')) {
                Write-LogWarning "Native installer did not yield 'claude'; trying npm fallback..."
                if (-not (Test-Command 'npm')) { Install-NodeJs }
                npm install -g '@anthropic-ai/claude-code'
                if ($LASTEXITCODE -ne 0) { throw 'npm fallback failed' }
                Update-AiCliSessionPath
            }

            if (-not (Test-Command 'claude')) { throw 'claude not found on PATH after install' }
            # Neutralize any stray exit code left by the remote installer so the
            # retry wrapper sees success now that 'claude' is confirmed present.
            $global:LASTEXITCODE = 0
        } `
        -PostInstall {
            Write-LogInfo "Claude Code plugins will be installed after login step"
        }
}
function Test-ClaudeInstalled { Test-Command 'claude' }

#===============================================================================
# Claude Code plugins (post-login step; requires auth)
#   Mirrors install_claude_plugins: skip if 'claude' missing or not authenticated,
#   otherwise install the fixed plugin set from claude-plugins-official.
#===============================================================================
function Install-ClaudePlugins {
    Update-AiCliSessionPath

    if (-not (Test-Command 'claude')) {
        Write-LogWarning "Claude plugins skipped: 'claude' command not found"
        return $false
    }

    # Require authentication (mirror: claude auth status).
    $authed = $false
    try {
        & claude auth status *> $null
        if ($LASTEXITCODE -eq 0) { $authed = $true }
    } catch { $authed = $false }

    if (-not $authed) {
        Write-LogWarning "Claude plugins skipped: not authenticated"
        Write-LogInfo "Login first, then run plugins manually:"
        Write-LogInfo "  claude plugin install frontend-design@claude-plugins-official"
        return $false
    }

    Write-LogInfo "Installing Claude Code plugins..."

    $claudePlugins = @(
        'playwright',
        'security-guidance',
        'frontend-design',
        'code-review',
        'superpowers',
        'code-simplifier'
    )

    $failCount = 0
    foreach ($pluginName in $claudePlugins) {
        Write-LogInfo "  Installing plugin: $pluginName ..."
        $pluginOutput = & claude plugin install "${pluginName}@claude-plugins-official" --scope user 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "  [OK] $pluginName installed"
        } else {
            $failCount++
            Write-LogWarning "  [FAIL] $pluginName failed (exit: $LASTEXITCODE)"
            Write-LogWarning "    Output: $pluginOutput"
        }
    }

    if ($failCount -gt 0) {
        Write-LogWarning "$failCount plugin(s) failed. Install manually:"
        foreach ($p in $claudePlugins) {
            Write-LogInfo "  claude plugin install ${p}@claude-plugins-official"
        }
        return $false
    }

    Write-LogSuccess "All Claude Code plugins installed successfully"
    return $true
}

#===============================================================================
# Codex CLI (OpenAI) - npm @openai/codex
#===============================================================================
function Install-Codex {
    return Install-App -Name 'Codex CLI (OpenAI)' `
        -Detect { Test-Command 'codex' } `
        -Direct {
            if (-not (Test-Command 'npm')) { Install-NodeJs }
            npm install -g '@openai/codex'
            if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }
        }
}
function Test-CodexInstalled { Test-Command 'codex' }

#===============================================================================
# Kimi Code CLI (Moonshot AI) - npm @moonshot-ai/kimi-code
#===============================================================================
function Install-Kimi {
    return Install-App -Name 'Kimi Code CLI (Moonshot AI)' `
        -Detect { Test-Command 'kimi' } `
        -Direct {
            if (-not (Test-Command 'npm')) { Install-NodeJs }
            npm install -g '@moonshot-ai/kimi-code'
            if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }
        }
}
function Test-KimiInstalled { Test-Command 'kimi' }

#===============================================================================
# Grok CLI (xAI) - official installer
#   Source uses:  curl -fsSL https://x.ai/cli/install.sh | bash
#   Windows-native guess: the .ps1 sibling. UNVERIFIED - see report.
#===============================================================================
function Install-Grok {
    return Install-App -Name 'Grok CLI (xAI)' `
        -Detect { Test-Command 'grok' } `
        -Direct {
            # UNVERIFIED Windows installer URL (Linux source: https://x.ai/cli/install.sh).
            Invoke-Expression (Invoke-RestMethod -Uri 'https://x.ai/cli/install.ps1')
            Update-AiCliSessionPath
            if (-not (Test-Command 'grok')) { throw 'grok not found on PATH after xAI installer' }
            $global:LASTEXITCODE = 0
        }
}
function Test-GrokInstalled { Test-Command 'grok' }

#===============================================================================
# Gemini CLI (Google) - npm @google/gemini-cli
#===============================================================================
function Install-Gemini {
    return Install-App -Name 'Gemini CLI (Google)' `
        -Detect { Test-Command 'gemini' } `
        -Direct {
            if (-not (Test-Command 'npm')) { Install-NodeJs }
            npm install -g '@google/gemini-cli'
            if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }
        }
}
function Test-GeminiInstalled { Test-Command 'gemini' }

#===============================================================================
# Qwen Code CLI (Alibaba) - npm @qwen-code/qwen-code
#===============================================================================
function Install-Qwen {
    return Install-App -Name 'Qwen Code CLI (Alibaba)' `
        -Detect { Test-Command 'qwen' } `
        -Direct {
            if (-not (Test-Command 'npm')) { Install-NodeJs }
            npm install -g '@qwen-code/qwen-code'
            if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }
        }
}
function Test-QwenInstalled { Test-Command 'qwen' }

#===============================================================================
# GLM Code helper (z.ai) - npm @z_ai/coding-helper  (command: chelper)
#===============================================================================
function Install-Glm {
    return Install-App -Name 'GLM Code helper (z.ai)' `
        -Detect { Test-Command 'chelper' } `
        -Direct {
            if (-not (Test-Command 'npm')) { Install-NodeJs }
            npm install -g '@z_ai/coding-helper'
            if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }
        } `
        -PostInstall {
            Write-LogInfo "  GLM Code helper installed (run: chelper)"
            Write-LogInfo "  Subscribe + get API key: https://z.ai/subscribe"
        }
}
function Test-GlmInstalled { Test-Command 'chelper' }

#===============================================================================
# GLM With OpenCode (z.ai GLM-5.2)
#   Installs OpenCode (npm opencode-ai preferred, official installer fallback) and
#   preconfigures z.ai GLM-5.2 as the default model. No -Detect so the config step
#   always runs (even when OpenCode is already installed), mirroring the source.
#===============================================================================
function Install-GlmOpencode {
    return Install-App -Name 'GLM With OpenCode (z.ai GLM-5.2)' `
        -Direct {
            if (-not (Test-Command 'npm')) { Install-NodeJs }

            # 1) Install OpenCode (npm preferred, official installer as fallback).
            if (Test-Command 'opencode') {
                Write-LogWarning "OpenCode already installed, skipping install..."
            } else {
                npm install -g 'opencode-ai'
                if ($LASTEXITCODE -ne 0) {
                    Write-LogWarning "npm install failed, trying official installer..."
                    try {
                        # UNVERIFIED Windows installer URL (Linux source: https://opencode.ai/install).
                        Invoke-Expression (Invoke-RestMethod -Uri 'https://opencode.ai/install.ps1')
                    } catch {
                        Write-LogWarning "OpenCode installer failed: $($_.Exception.Message)"
                    }
                    Update-AiCliSessionPath
                }
            }

            if (-not (Test-Command 'opencode')) { throw 'OpenCode install failed (npm and installer)' }

            # 2) Preconfigure z.ai GLM-5.2 as the default model (no API key stored here).
            Set-OpencodeGlmConfig
            $global:LASTEXITCODE = 0
        } `
        -PostInstall {
            # 3) Auth is left to the user at runtime - this script stores no secret.
            Write-LogInfo "  Set your z.ai key (GLM Coding Plan) to start:"
            Write-LogInfo "    `$env:ZAI_API_KEY=<your-key>   (set a User env var to persist)"
            Write-LogInfo "  Subscribe + get API key: https://z.ai/subscribe"
            Write-LogInfo "  Then run: opencode   (defaults to GLM-5.2; use /models to switch)"
            Write-LogInfo "  Note: general (non-Coding-Plan) keys use baseURL .../api/paas/v4"
        }
}
function Test-GlmOpencodeInstalled { Test-Command 'opencode' }

#===============================================================================
# REMOTE SUPPORT TOOLS  (birebir port of ubuntu-setup.sh remote installers)
#
#   Source functions ported:
#     install_realvnc        -> Install-RealVNC   / Test-RealVNCInstalled
#     install_rustdesk       -> Install-RustDesk  / Test-RustDeskInstalled
#     install_anydesk        -> Install-AnyDesk   / Test-AnyDeskInstalled
#     install_teamviewer     -> Install-TeamViewer/ Test-TeamViewerInstalled
#     remote_update_available-> Test-RemoteUpdateAvailable -Key <string>
#
#   Relies on the shared helpers defined in windows-setup.ps1
#   (Install-App, Test-App, Test-Command, Get-FileDownload, Write-Log*).
#===============================================================================

#-------------------------------------------------------------------------------
# 1. RealVNC Connect (Server)  -- the remote method we use on Windows
#
# realvnc.com only exposes *versioned* download URLs (no stable "latest"), so we
# go winget-first and OMIT -Direct (per CONVENTIONS). RealVNC.VNCServer is the
# primary artifact; the VNC Viewer is additionally offered best-effort once the
# server is in place. choco fallback: realvnc.
#-------------------------------------------------------------------------------
function Test-RealVNCInstalled { Test-App -DisplayNameLike '*VNC Server*' }

function Install-RealVNC {
    return Install-App -Name 'RealVNC Connect (Server)' `
        -Detect { Test-App -DisplayNameLike '*VNC Server*' } `
        -WingetId 'RealVNC.VNCServer' `
        -ChocoId 'realvnc' `
        -PostInstall {
            # Also offer the VNC Viewer (best-effort; never fails the install).
            if (Test-Command 'winget') {
                Write-LogInfo 'RealVNC: also offering VNC Viewer (RealVNC.VNCViewer)...'
                winget install --id 'RealVNC.VNCViewer' -e --silent `
                    --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
            }
        }
}

#-------------------------------------------------------------------------------
# 1.5 RustDesk
#
# Source always installs the GitHub-latest build; mirror that with the GitHub
# "latest release" asset helper, matching the Windows x64 asset (*-x86_64.exe)
# and installing silently with --silent-install. On ANY failure we throw so
# Install-App falls through to winget (RustDesk.RustDesk) then choco (rustdesk).
#-------------------------------------------------------------------------------
function Test-RustDeskInstalled { Test-App -Command 'rustdesk' -DisplayNameLike '*RustDesk*' -WingetId 'RustDesk.RustDesk' }

function Install-RustDesk {
    return Install-App -Name 'RustDesk' `
        -Detect { Test-App -Command 'rustdesk' -DisplayNameLike '*RustDesk*' -WingetId 'RustDesk.RustDesk' } `
        -Direct {
            $rel = Invoke-RestMethod 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest' `
                -Headers @{ 'User-Agent' = 'windows-setup' }
            $asset = $rel.assets | Where-Object { $_.name -like '*-x86_64.exe' } | Select-Object -First 1
            if (-not $asset) { throw 'asset not found' }
            $f = Get-FileDownload -Url $asset.browser_download_url
            if (-not $f) { throw 'download failed' }
            $p = Start-Process -FilePath $f -ArgumentList '--silent-install' -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "installer exit $($p.ExitCode)" }
        } `
        -WingetId 'RustDesk.RustDesk' -ChocoId 'rustdesk'
}

#-------------------------------------------------------------------------------
# 1.6 AnyDesk
#
# Direct: AnyDesk's own EXE is also the installer, but it REQUIRES an --install
# <path> target. We download the stable-latest AnyDesk.exe and run it silently.
# The destination path (Program Files\AnyDesk) contains a space, so it must be
# quoted inside the argument string. winget: AnyDeskSoftwareGmbH.AnyDesk, choco:
# anydesk.
#-------------------------------------------------------------------------------
function Test-AnyDeskInstalled { Test-App -Command 'anydesk' -DisplayNameLike '*AnyDesk*' -WingetId 'AnyDeskSoftwareGmbH.AnyDesk' }

function Install-AnyDesk {
    return Install-App -Name 'AnyDesk' `
        -Detect { Test-App -Command 'anydesk' -DisplayNameLike '*AnyDesk*' -WingetId 'AnyDeskSoftwareGmbH.AnyDesk' } `
        -Direct {
            $f = Get-FileDownload -Url 'https://download.anydesk.com/AnyDesk.exe'
            if (-not $f) { throw 'download failed' }
            $dest = Join-Path $env:ProgramFiles 'AnyDesk'
            $p = Start-Process -FilePath $f `
                -ArgumentList "--install `"$dest`" --start-with-win --silent" -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "installer exit $($p.ExitCode)" }
        } `
        -WingetId 'AnyDeskSoftwareGmbH.AnyDesk' -ChocoId 'anydesk'
}

#-------------------------------------------------------------------------------
# 1.7 TeamViewer
#
# Direct: stable-latest x64 setup, silent /S. winget: TeamViewer.TeamViewer,
# choco: teamviewer.
#-------------------------------------------------------------------------------
function Test-TeamViewerInstalled { Test-App -Command 'teamviewer' -DisplayNameLike '*TeamViewer*' -WingetId 'TeamViewer.TeamViewer' }

function Install-TeamViewer {
    return Install-App -Name 'TeamViewer' `
        -Detect { Test-App -Command 'teamviewer' -DisplayNameLike '*TeamViewer*' -WingetId 'TeamViewer.TeamViewer' } `
        -Direct {
            $f = Get-FileDownload -Url 'https://download.teamviewer.com/download/TeamViewer_Setup_x64.exe'
            if (-not $f) { throw 'download failed' }
            $p = Start-Process -FilePath $f -ArgumentList '/S' -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "installer exit $($p.ExitCode)" }
        } `
        -WingetId 'TeamViewer.TeamViewer' -ChocoId 'teamviewer'
}

#-------------------------------------------------------------------------------
# Test-RemoteUpdateAvailable  (mirrors remote_update_available)
#
# Returns $true ONLY when the tool for the given sub-menu key is installed AND a
# newer version is available. Implemented via `winget upgrade --id <id>
# --include-unknown` output parsing (installers not tracked by winget report
# their installed version as "Unknown", which --include-unknown still compares).
# RustDesk always returns $false: the source installs GitHub-latest at run time,
# so it can never know offline whether a newer build exists. Fully defensive:
# returns $false when winget is absent or on any error.
#
# Keys: 'vnc' / 'realvnc', 'anydesk', 'rustdesk', 'teamviewer'.
#-------------------------------------------------------------------------------
function Test-RemoteUpdateAvailable {
    param([Parameter(Mandatory)][string]$Key)

    try {
        $k = $Key.Trim().ToLowerInvariant()

        $installed = $false
        $wingetId  = $null
        switch ($k) {
            'vnc'        { $installed = Test-RealVNCInstalled;    $wingetId = 'RealVNC.VNCServer' }
            'realvnc'    { $installed = Test-RealVNCInstalled;    $wingetId = 'RealVNC.VNCServer' }
            'anydesk'    { $installed = Test-AnyDeskInstalled;    $wingetId = 'AnyDeskSoftwareGmbH.AnyDesk' }
            'teamviewer' { $installed = Test-TeamViewerInstalled; $wingetId = 'TeamViewer.TeamViewer' }
            'rustdesk'   { return $false }   # GitHub-latest at run time -> never flagged
            default      { return $false }
        }

        # Source only flags a tool that is actually installed.
        if (-not $installed) { return $false }

        # Need winget to compare the installed version against what's available.
        if (-not (Test-Command 'winget')) { return $false }

        $out = winget upgrade --id $wingetId -e --include-unknown --accept-source-agreements 2>$null | Out-String
        if (-not $out) { return $false }

        # "No installed package ..." / "No available upgrade ..." => nothing to do.
        if ($out -match 'No (installed package|available upgrade)') { return $false }

        # An upgrade row echoes the exact id; its presence => an update is available.
        if ($out -match [regex]::Escape($wingetId)) { return $true }

        return $false
    } catch {
        return $false
    }
}

#===============================================================================
# Windows Tweaks + Backup/Restore fragment
#
# Windows-native counterpart of the Ubuntu script's 20 GNOME tweaks (§4.4) plus
# the backup/restore flow (§4.6). Only function definitions live here; the shared
# helpers (Write-Log*, Invoke-WithRetry, Test-Command, Install-App, $script:USER_HOME,
# $script:BACKUP_DIR, ...) are defined in windows-setup.ps1 and MUST NOT be redefined.
#
# PowerShell 5.1 compatible: no ternary / ?? / -Parallel / && / ||. Every registry
# and service call is guarded and logged. Idempotent: re-running is safe.
#===============================================================================

# Module-level list of the registry keys the tweaks below touch (reg.exe hive
# notation, NOT PowerShell drive notation). Save-TweakBackup exports each of these.
# NOTE: a couple overlap on purpose (Explorer contains Advanced) so each concern
# gets its own clearly-named .reg file. Keys that do not exist yet at backup time
# are simply skipped.
$script:TWEAK_REG_KEYS = @(
    'HKCU\Software\Classes\Directory\Background\shell',                 # script-launcher context menu
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', # show-hidden + taskbar tweaks
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer',          # tray icons (EnableAutoTray)
    'HKCU\Keyboard Layout\Preload',                                     # keyboard layouts
    'HKCU\Control Panel\International',                                  # locale / display language
    'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon',       # auto-login
    'HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting',          # error reporting
    'HKLM\SOFTWARE\Policies\Microsoft\Windows\StorageSense',            # storage sense policy
    'HKLM\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName'   # hostname
)

#===============================================================================
# BACKUP / RESTORE (§4.6) - System Restore point + registry export
#===============================================================================

# Create a System Restore point AND export every touched registry key into a new
# timestamped folder under $script:BACKUP_DIR. Returns the backup folder path.
# Mirrors backup_gnome_settings / take_new_backup.
function Save-TweakBackup {
    $ts = Get-Date -Format 'yyyyMMdd_HHmmss'

    # (1) System Restore point - best effort (can be rate-limited to 1/day or disabled).
    try {
        Write-LogInfo "Creating a System Restore point (this may be rate-limited or disabled)..."
        Checkpoint-Computer -Description "windows-setup $ts" -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-LogSuccess "System Restore point created."
    } catch {
        Write-LogWarning "Could not create a System Restore point: $($_.Exception.Message)"
    }

    # (2) Registry export of the touched keys.
    $backupPath = Join-Path $script:BACKUP_DIR "${ts}-tweaks"
    try {
        if (-not (Test-Path -LiteralPath $backupPath)) {
            New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        }
        Set-Content -LiteralPath (Join-Path $backupPath 'backup-timestamp') -Value $ts -Encoding ASCII

        foreach ($key in $script:TWEAK_REG_KEYS) {
            $safe = ($key -replace '[\\:\s]', '_')
            $file = Join-Path $backupPath "$safe.reg"
            & reg.exe query $key > $null 2>&1
            if ($LASTEXITCODE -eq 0) {
                & reg.exe export $key $file /y > $null 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-LogInfo "  Backed up: $key"
                } else {
                    Write-LogWarning "  Could not export: $key"
                }
            } else {
                Write-LogInfo "  Skipped (no existing key): $key"
            }
        }
        Write-LogSuccess "Registry backup saved to: $backupPath"
    } catch {
        Write-LogWarning "Registry backup failed: $($_.Exception.Message)"
    }

    return $backupPath
}

# List backup folders under $script:BACKUP_DIR (timestamps + contents) and any
# System Restore points. Mirrors show_all_backups / show_gnome_backup.
function Show-Backups {
    if (Get-Command Show-SystemHeader -ErrorAction SilentlyContinue) { Show-SystemHeader }

    Write-Host ""
    Write-Host "Existing Backups:" -ForegroundColor Green
    Write-Host "Location: $script:BACKUP_DIR" -ForegroundColor Yellow
    Write-Host ""

    if (Test-Path -LiteralPath $script:BACKUP_DIR) {
        $dirs = @(Get-ChildItem -LiteralPath $script:BACKUP_DIR -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending)
        if ($dirs.Count -gt 0) {
            foreach ($d in $dirs) {
                Write-Host "  $($d.Name)" -ForegroundColor Cyan
                $tsFile = Join-Path $d.FullName 'backup-timestamp'
                if (Test-Path -LiteralPath $tsFile) {
                    Write-Host "    Created: $(Get-Content -LiteralPath $tsFile -ErrorAction SilentlyContinue)"
                }
                Write-Host "    Files:"
                Get-ChildItem -LiteralPath $d.FullName -File -ErrorAction SilentlyContinue | ForEach-Object {
                    $kb = [math]::Round($_.Length / 1KB, 1)
                    Write-Host "      $($_.Name)  (${kb} KB)"
                }
                Write-Host ""
            }
        } else {
            Write-Host "No registry backups found." -ForegroundColor Yellow
        }
    } else {
        Write-Host "No backups found." -ForegroundColor Yellow
    }

    # System Restore points
    Write-Host ""
    Write-Host "System Restore points:" -ForegroundColor Green
    try {
        $rps = @(Get-ComputerRestorePoint -ErrorAction Stop)
        if ($rps.Count -gt 0) {
            foreach ($rp in $rps) {
                $when = $rp.CreationTime
                try { $when = [System.Management.ManagementDateTimeConverter]::ToDateTime($rp.CreationTime) } catch { }
                Write-Host "  [$($rp.SequenceNumber)] $($rp.Description) - $when"
            }
        } else {
            Write-Host "  (none)"
        }
    } catch {
        Write-LogWarning "Could not list restore points (System Restore may be disabled): $($_.Exception.Message)"
    }
    Write-Host ""
}

# Interactive restore: pick a backup folder, re-import its .reg files, and point
# the user at System Restore for a deeper rollback.
# Mirrors restore_gnome_settings / restore_backup_interactive.
function Restore-Backup {
    if (Get-Command Show-SystemHeader -ErrorAction SilentlyContinue) { Show-SystemHeader }

    Write-Host ""
    Write-Host "Restore from Backup:" -ForegroundColor Green
    Write-Host ""

    if (-not (Test-Path -LiteralPath $script:BACKUP_DIR)) {
        Write-LogWarning "No backups found at $script:BACKUP_DIR"
        return
    }

    $dirs = @(Get-ChildItem -LiteralPath $script:BACKUP_DIR -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending)
    if ($dirs.Count -eq 0) {
        Write-LogWarning "No registry backups found."
        return
    }

    for ($i = 0; $i -lt $dirs.Count; $i++) {
        Write-Host ("  [{0}]  {1}" -f ($i + 1), $dirs[$i].Name) -ForegroundColor Blue
        $tsFile = Join-Path $dirs[$i].FullName 'backup-timestamp'
        if (Test-Path -LiteralPath $tsFile) {
            Write-Host "        Created: $(Get-Content -LiteralPath $tsFile -ErrorAction SilentlyContinue)"
        }
    }
    Write-Host "  [b]  Back" -ForegroundColor Red
    Write-Host ""

    $choice = Read-Host "Select a backup to restore"
    if ($choice -match '^[bB]$') { return }

    $idx = 0
    if (-not [int]::TryParse($choice, [ref]$idx) -or $idx -lt 1 -or $idx -gt $dirs.Count) {
        Write-LogWarning "Invalid selection."
        return
    }

    $sel  = $dirs[$idx - 1]
    $regs = @(Get-ChildItem -LiteralPath $sel.FullName -Filter '*.reg' -File -ErrorAction SilentlyContinue)
    if ($regs.Count -eq 0) {
        Write-LogWarning "No .reg files found in $($sel.Name)."
        return
    }

    Write-Host ""
    Write-Host "This will re-import (merge) these registry files:" -ForegroundColor Yellow
    $regs | ForEach-Object { Write-Host "  $($_.Name)" }
    Write-Host ""
    $confirm = Read-Host "Proceed? (y/n)"
    if ($confirm -notmatch '^[Yy]') {
        Write-LogInfo "Restore cancelled."
        return
    }

    foreach ($r in $regs) {
        try {
            & reg.exe import $r.FullName > $null 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "Imported $($r.Name)"
            } else {
                Write-LogWarning "Failed to import $($r.Name) (exit $LASTEXITCODE)"
            }
        } catch {
            Write-LogWarning "Failed to import $($r.Name): $($_.Exception.Message)"
        }
    }

    Write-LogInfo "Registry values restored. Sign out / reboot (or restart Explorer) for changes to take effect."
    Write-LogWarning "Note: a .reg import MERGES values; it does not remove keys that a tweak newly created."
    Write-LogInfo "For a full rollback use System Restore: run 'rstrui.exe', or in PowerShell 'Get-ComputerRestorePoint' then 'Restore-Computer -RestorePoint <N>'."
}

#===============================================================================
# TWEAK APPLY FUNCTIONS (§4.4) - each = one row of the mapping table
#===============================================================================

# Update System: winget upgrade --all. Mirrors "sudo apt update && upgrade".
function Update-WindowsSystem {
    Write-LogInfo "Updating installed applications (winget upgrade --all)..."
    if (-not (Test-Command 'winget')) {
        Write-LogWarning "winget is not available; cannot upgrade apps. Skipping."
        return $false
    }
    try {
        winget upgrade --all --silent --include-unknown --accept-package-agreements --accept-source-agreements
        Write-LogSuccess "Application upgrade run completed. A reboot may be required for some updates."
        return $true
    } catch {
        Write-LogWarning "winget upgrade failed: $($_.Exception.Message)"
        return $false
    }
}

# Script Launcher: right-click (background) context-menu entries that open the
# clicked folder in Claude Code / Codex (in a PowerShell window) or VS Code.
# Mirrors the Nautilus MenuProvider from setup_cli_shortcuts. Uses %V (the
# background folder) under HKCU\...\Directory\Background\shell.
function Set-ScriptLauncherContextMenu {
    Write-LogInfo "Registering right-click 'Open in ...' context-menu entries (Claude / Codex / VS Code)..."

    # Resolve a PowerShell host to run the CLI tools in.
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        $psh = $pwshCmd.Source
    } else {
        $psh = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    }

    # Resolve VS Code executable (GUI - opens the folder directly).
    $codeExe = $null
    foreach ($c in @((Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\Code.exe'),
                     (Join-Path $env:ProgramFiles 'Microsoft VS Code\Code.exe'))) {
        if (Test-Path -LiteralPath $c) { $codeExe = $c; break }
    }
    if (-not $codeExe) {
        $codeCmd = Get-Command code -ErrorAction SilentlyContinue
        if ($codeCmd) { $codeExe = $codeCmd.Source }
    }
    if ($codeExe) {
        $vscodeCmd = '"{0}" "%V"' -f $codeExe
    } else {
        $vscodeCmd = '"{0}" -NoProfile -Command "code ''%V''"' -f $psh
    }

    $entries = @(
        @{ Key = 'SmaiClaude'; Label = 'Open in Claude Code';
           Cmd = ('"{0}" -NoExit -Command "Set-Location -LiteralPath ''%V''; claude --dangerously-skip-permissions --effort max"' -f $psh) },
        @{ Key = 'SmaiCodex';  Label = 'Open in Codex CLI';
           Cmd = ('"{0}" -NoExit -Command "Set-Location -LiteralPath ''%V''; codex --sandbox danger-full-access -c ''model_reasoning_effort=xhigh''"' -f $psh) },
        @{ Key = 'SmaiVSCode'; Label = 'Open in VS Code'; Cmd = $vscodeCmd }
    )

    foreach ($e in $entries) {
        try {
            $base = "HKCU:\Software\Classes\Directory\Background\shell\$($e.Key)"
            if (-not (Test-Path -LiteralPath $base)) { New-Item -Path $base -Force | Out-Null }
            Set-Item -LiteralPath $base -Value $e.Label

            $cmdKey = "$base\command"
            if (-not (Test-Path -LiteralPath $cmdKey)) { New-Item -Path $cmdKey -Force | Out-Null }
            Set-Item -LiteralPath $cmdKey -Value $e.Cmd

            Write-LogInfo "  Registered: $($e.Label)"
        } catch {
            Write-LogWarning "  Could not register $($e.Label): $($_.Exception.Message)"
        }
    }
    Write-LogSuccess "Script launcher context-menu entries registered."
    return $true
}

# OpenSSH Server: install the capability, auto-start sshd, open port 22.
# Mirrors enable_ssh_server.
function Enable-OpenSSHServer {
    Write-LogInfo "Enabling the OpenSSH server (sshd)..."

    # (1) Install the OpenSSH.Server capability if not already present.
    try {
        $cap = Get-WindowsCapability -Online -ErrorAction Stop |
                    Where-Object { $_.Name -like 'OpenSSH.Server*' } | Select-Object -First 1
        if ($cap -and $cap.State -ne 'Installed') {
            Write-LogInfo "Installing capability $($cap.Name)..."
            Add-WindowsCapability -Online -Name $cap.Name -ErrorAction Stop | Out-Null
        } elseif (-not $cap) {
            Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop | Out-Null
        } else {
            Write-LogInfo "OpenSSH server capability already installed."
        }
    } catch {
        Write-LogWarning "Could not install the OpenSSH server capability: $($_.Exception.Message)"
    }

    # (2) Set service to Automatic and start it.
    try {
        Set-Service -Name sshd -StartupType Automatic -ErrorAction Stop
        Start-Service -Name sshd -ErrorAction Stop
        Write-LogSuccess "sshd is running and set to start automatically."
    } catch {
        Write-LogWarning "Could not start/enable the sshd service: $($_.Exception.Message)"
    }

    # (3) Firewall rule for TCP 22.
    try {
        if (-not (Get-NetFirewallRule -Name 'sshd' -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -Name 'sshd' -DisplayName 'OpenSSH Server (sshd)' -Enabled True `
                -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction Stop | Out-Null
            Write-LogInfo "Firewall rule for TCP 22 created."
        }
    } catch {
        Write-LogWarning "Could not create the firewall rule for port 22: $($_.Exception.Message)"
    }
    return $true
}

# Change Hostname: rename the computer (value collected before install starts).
# Mirrors the GNOME_SUB_HOSTNAME flow. Reboot required.
function Set-ComputerHostname {
    param([Parameter(Mandatory)][string]$Name)

    Write-LogInfo "Setting the computer hostname to '$Name'..."
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-LogWarning "No hostname provided; skipping."
        return $false
    }
    if ($env:COMPUTERNAME -eq $Name) {
        Write-LogInfo "Hostname is already '$Name'; skipping."
        return $true
    }
    try {
        Rename-Computer -NewName $Name -Force -ErrorAction Stop
        Write-LogSuccess "Hostname set to '$Name'. A reboot is required for the change to take effect."
        return $true
    } catch {
        Write-LogWarning "Could not rename the computer: $($_.Exception.Message)"
        return $false
    }
}

# CLI Aliases: write claude-skip / ccskip / codex-skip / cxskip into the pwsh
# profile. Mirrors setup_cli_shortcuts (same alias names/commands, adapted to
# PowerShell functions since aliases cannot carry arguments).
function Set-CliAliases {
    Write-LogInfo "Adding CLI alias functions (claude-skip, ccskip, cckimi, ccglm, cckimi-token, ccglm-token, codex-skip, cxskip) to the PowerShell profile..."

    $profilePath = $PROFILE.CurrentUserAllHosts
    $dir = Split-Path -Parent $profilePath
    try {
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $existing = ''
        if (Test-Path -LiteralPath $profilePath) {
            $raw = Get-Content -LiteralPath $profilePath -Raw -ErrorAction SilentlyContinue
            if ($raw) { $existing = $raw }
        }

        # Strip any previous smai-aliases block (idempotent re-run).
        $pattern = '(?ms)^# BEGIN smai-aliases.*?^# END smai-aliases\r?\n?'
        $cleaned = [System.Text.RegularExpressions.Regex]::Replace($existing, $pattern, '')

        # Written verbatim into the profile (single-quoted here-string => no expansion here;
        # the $env/$token/@args inside expand later, in the user's session).
        $block = @'
# BEGIN smai-aliases
function claude-skip { claude --dangerously-skip-permissions --effort max @args }
function ccskip      { claude --dangerously-skip-permissions --effort max @args }
function codex-skip  { codex --sandbox danger-full-access -c 'model_reasoning_effort=xhigh' @args }
function cxskip      { codex --sandbox danger-full-access -c 'model_reasoning_effort=xhigh' @args }

# cckimi -> Claude Code on the Kimi backend (token in ~/.kimi_token)
function cckimi {
    $tf = Join-Path $HOME '.kimi_token'
    if (-not (Test-Path $tf)) { Write-Host "cckimi: token file not found: $tf" -ForegroundColor Red; return }
    $token = (Get-Content -Raw $tf).Trim()
    if (-not $token) { Write-Host "cckimi: token file is empty: $tf" -ForegroundColor Red; return }
    $vars = [ordered]@{
        ANTHROPIC_BASE_URL              = 'https://api.kimi.com/coding/'
        ANTHROPIC_AUTH_TOKEN            = $token
        ANTHROPIC_MODEL                 = 'kimi-k3[1m]'
        ANTHROPIC_DEFAULT_OPUS_MODEL    = 'kimi-k3[1m]'
        ANTHROPIC_DEFAULT_SONNET_MODEL  = 'kimi-k3[1m]'
        ANTHROPIC_DEFAULT_HAIKU_MODEL   = 'kimi-k3[1m]'
        ANTHROPIC_DEFAULT_FABLE_MODEL   = 'kimi-k3[1m]'
        CLAUDE_CODE_SUBAGENT_MODEL      = 'kimi-k3[1m]'
        ENABLE_TOOL_SEARCH              = 'false'
        CLAUDE_CODE_AUTO_COMPACT_WINDOW = '1048576'
        CLAUDE_CODE_EFFORT_LEVEL        = 'max'
    }
    $old = @{}
    foreach ($k in $vars.Keys) { $old[$k] = [Environment]::GetEnvironmentVariable($k); Set-Item -Path "env:$k" -Value $vars[$k] }
    try { claude --dangerously-skip-permissions --effort max @args }
    finally { foreach ($k in $vars.Keys) { if ($null -eq $old[$k]) { Remove-Item -Path "env:$k" -ErrorAction SilentlyContinue } else { Set-Item -Path "env:$k" -Value $old[$k] } } }
}

# ccglm -> Claude Code on the Z.AI GLM backend (token in ~/.zai_token)
function ccglm {
    $tf = Join-Path $HOME '.zai_token'
    if (-not (Test-Path $tf)) { Write-Host "ccglm: token file not found: $tf" -ForegroundColor Red; return }
    $token = (Get-Content -Raw $tf).Trim()
    if (-not $token) { Write-Host "ccglm: token file is empty. Write your Z.AI API key into: $tf" -ForegroundColor Red; return }
    $vars = [ordered]@{
        ANTHROPIC_BASE_URL                       = 'https://api.z.ai/api/anthropic'
        ANTHROPIC_AUTH_TOKEN                     = $token
        ANTHROPIC_MODEL                          = 'glm-5.2[1m]'
        ANTHROPIC_DEFAULT_OPUS_MODEL             = 'glm-5.2[1m]'
        ANTHROPIC_DEFAULT_SONNET_MODEL           = 'glm-5.2[1m]'
        ANTHROPIC_DEFAULT_HAIKU_MODEL            = 'glm-5.2[1m]'
        ANTHROPIC_DEFAULT_FABLE_MODEL            = 'glm-5.2[1m]'
        CLAUDE_CODE_SUBAGENT_MODEL               = 'glm-5.2[1m]'
        CLAUDE_CODE_AUTO_COMPACT_WINDOW          = '1000000'
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'
        API_TIMEOUT_MS                           = '3000000'
    }
    $old = @{}
    foreach ($k in $vars.Keys) { $old[$k] = [Environment]::GetEnvironmentVariable($k); Set-Item -Path "env:$k" -Value $vars[$k] }
    try { claude --dangerously-skip-permissions @args }
    finally { foreach ($k in $vars.Keys) { if ($null -eq $old[$k]) { Remove-Item -Path "env:$k" -ErrorAction SilentlyContinue } else { Set-Item -Path "env:$k" -Value $old[$k] } } }
}

# __cc_set_token <label> <token_file> [key] -- shared writer for the cc*-token helpers
function __cc_set_token {
    param([string]$Label, [string]$TokenFile, [string]$Key)
    if (-not $Key) { $Key = Read-Host "$Label - paste API key" }
    $Key = ($Key -replace '\s', '')
    if (-not $Key) { Write-Host "${Label}: no key given, $TokenFile left unchanged" -ForegroundColor Yellow; return }
    Set-Content -Path $TokenFile -Value $Key -NoNewline -Encoding ascii
    try { icacls $TokenFile /inheritance:r /grant:r "${env:USERNAME}:(R,W)" | Out-Null } catch { }
    Write-Host "${Label}: key written to $TokenFile ($($Key.Length) chars, current-user only)." -ForegroundColor Green
}
function cckimi-token { param([string]$Key) __cc_set_token 'cckimi' (Join-Path $HOME '.kimi_token') $Key }
function ccglm-token  { param([string]$Key) __cc_set_token 'ccglm'  (Join-Path $HOME '.zai_token')  $Key }
# END smai-aliases
'@

        $new = $cleaned.TrimEnd() + "`r`n`r`n" + $block + "`r`n"
        Set-Content -LiteralPath $profilePath -Value $new -Encoding UTF8
        Write-LogSuccess "Aliases added: claude-skip, ccskip, cckimi, ccglm, cckimi-token, ccglm-token, codex-skip, cxskip (open a new PowerShell session to use them)."
        return $true
    } catch {
        Write-LogWarning "Could not update the PowerShell profile: $($_.Exception.Message)"
        return $false
    }
}

# Screen Off: Never - disable display/standby timeouts and hibernate.
# Mirrors GNOME_SUB_SCREEN (idle-delay 0 + no auto-suspend).
function Disable-ScreenTimeout {
    Write-LogInfo "Disabling screen timeout, standby and hibernate..."
    try {
        & powercfg.exe /change monitor-timeout-ac 0  | Out-Null
        & powercfg.exe /change monitor-timeout-dc 0  | Out-Null
        & powercfg.exe /change standby-timeout-ac 0  | Out-Null
        & powercfg.exe /change standby-timeout-dc 0  | Out-Null
        & powercfg.exe /hibernate off                | Out-Null
        Write-LogSuccess "Display will never turn off and the system will not sleep/hibernate."
        return $true
    } catch {
        Write-LogWarning "Could not change power settings: $($_.Exception.Message)"
        return $false
    }
}

# Show Hidden Files: show hidden files + file extensions in Explorer.
# Mirrors GNOME_SUB_HIDDEN (show-hidden true).
function Show-HiddenFiles {
    Write-LogInfo "Enabling 'show hidden files' and 'show file extensions' in Explorer..."
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    try {
        if (-not (Test-Path -LiteralPath $adv)) { New-Item -Path $adv -Force | Out-Null }
        New-ItemProperty -LiteralPath $adv -Name 'Hidden'      -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -LiteralPath $adv -Name 'HideFileExt' -Value 0 -PropertyType DWord -Force | Out-Null

        $exp = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($exp) { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }
        Write-LogSuccess "Hidden files and file extensions are now shown (Explorer restarted)."
        return $true
    } catch {
        Write-LogWarning "Could not update Explorer settings: $($_.Exception.Message)"
        return $false
    }
}

# Keyboard: Turkish Q - add the tr-TR input with the Turkish-Q layout (0000041F).
# Mirrors GNOME_SUB_KB_TR (add 'tr' source).
function Add-KeyboardTurkishQ {
    Write-LogInfo "Adding the Turkish Q keyboard layout (tr-TR)..."
    try {
        $list = Get-WinUserLanguageList
        if (-not ($list | Where-Object { $_.LanguageTag -eq 'tr-TR' })) {
            $list.Add('tr-TR')
        }
        $tr = $list | Where-Object { $_.LanguageTag -eq 'tr-TR' } | Select-Object -First 1
        if ($tr -and ($tr.InputMethodTips -notcontains '041F:0000041F')) {
            $tr.InputMethodTips.Clear()
            $tr.InputMethodTips.Add('041F:0000041F')   # Turkish Q
        }
        Set-WinUserLanguageList $list -Force
        Write-LogSuccess "Turkish Q keyboard layout added."
        return $true
    } catch {
        Write-LogWarning "Could not add the Turkish keyboard layout: $($_.Exception.Message)"
        return $false
    }
}

# Keyboard: English Q - add the en-US input (standard US QWERTY, 00000409).
# Mirrors GNOME_SUB_KB_EN (add 'us' source).
function Add-KeyboardEnglishQ {
    Write-LogInfo "Adding the English (US) keyboard layout (en-US)..."
    try {
        $list = Get-WinUserLanguageList
        if (-not ($list | Where-Object { $_.LanguageTag -eq 'en-US' })) {
            $list.Add('en-US')
            Set-WinUserLanguageList $list -Force
        }
        Write-LogSuccess "English (US) keyboard layout added."
        return $true
    } catch {
        Write-LogWarning "Could not add the English keyboard layout: $($_.Exception.Message)"
        return $false
    }
}

# English Language: set the UI/display language and regional format to en-US.
# Mirrors GNOME_SUB_ENGLISH. Sign-out required.
function Set-DisplayLanguageEnglish {
    Write-LogInfo "Setting the display language and regional format to English (US)..."
    try {
        $list = Get-WinUserLanguageList
        if (-not ($list | Where-Object { $_.LanguageTag -eq 'en-US' })) {
            $list.Add('en-US')
            Set-WinUserLanguageList $list -Force
        }
    } catch {
        Write-LogWarning "Could not ensure en-US is in the language list: $($_.Exception.Message)"
    }
    try {
        Set-WinUILanguageOverride -Language en-US
        Write-LogInfo "UI language override set to en-US."
    } catch {
        Write-LogWarning "Could not set the UI language override: $($_.Exception.Message)"
    }
    try {
        Set-Culture en-US
        Write-LogInfo "Regional format (culture) set to en-US."
    } catch {
        Write-LogWarning "Could not set the culture: $($_.Exception.Message)"
    }
    Write-LogWarning "Sign out and back in for the display language change to take effect."
    return $true
}

# Auto-Login: enable Windows auto-login on boot via Winlogon.
# Mirrors enable_autologin. NOTE: the password is stored in PLAINTEXT in the
# registry - the caveat is surfaced and the password step can be skipped.
function Enable-AutoLogin {
    Write-LogInfo "Enabling Windows auto-login on boot..."

    # Determine the interactive user (prefer the owner of explorer.exe, since we
    # may be running elevated as a different admin account).
    $user   = $env:USERNAME
    $domain = $env:USERDOMAIN
    try {
        $exp = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -ErrorAction Stop | Select-Object -First 1
        if ($exp) {
            $own = Invoke-CimMethod -InputObject $exp -MethodName GetOwner -ErrorAction Stop
            if ($own.User)   { $user   = $own.User }
            if ($own.Domain) { $domain = $own.Domain }
        }
    } catch { }
    if (-not $domain) { $domain = $env:COMPUTERNAME }

    $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    try {
        New-ItemProperty -LiteralPath $wl -Name 'AutoAdminLogon'    -Value '1'     -PropertyType String -Force | Out-Null
        New-ItemProperty -LiteralPath $wl -Name 'DefaultUserName'   -Value $user   -PropertyType String -Force | Out-Null
        New-ItemProperty -LiteralPath $wl -Name 'DefaultDomainName' -Value $domain -PropertyType String -Force | Out-Null
    } catch {
        Write-LogWarning "Could not write the Winlogon auto-login values: $($_.Exception.Message)"
        return $false
    }

    Write-LogWarning "Auto-login stores the account password in PLAINTEXT at HKLM\...\Winlogon\DefaultPassword - any local administrator can read it. Only enable this where that risk is acceptable."
    try {
        $sec = Read-Host "Enter the password for '$user' to store for auto-login (press Enter to SKIP storing a password)" -AsSecureString
        $plain = ''
        if ($sec -and $sec.Length -gt 0) {
            $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
            try {
                $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            } finally {
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
        }
        if ($plain) {
            New-ItemProperty -LiteralPath $wl -Name 'DefaultPassword' -Value $plain -PropertyType String -Force | Out-Null
            $plain = $null
            Write-LogSuccess "Auto-login enabled for '$user' (password stored - see the caveat above)."
        } else {
            Remove-ItemProperty -LiteralPath $wl -Name 'DefaultPassword' -ErrorAction SilentlyContinue
            Write-LogWarning "Auto-login flag set for '$user' but NO password stored; Windows will still prompt at logon until a DefaultPassword is set."
        }
    } catch {
        Write-LogWarning "Could not store the auto-login password: $($_.Exception.Message)"
    }
    return $true
}

# Disable Auto-Login: turn off auto-login and remove the stored plaintext password.
# Mirrors disable_autologin.
function Disable-AutoLogin {
    Write-LogInfo "Disabling Windows auto-login..."
    $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    try {
        New-ItemProperty -LiteralPath $wl -Name 'AutoAdminLogon' -Value '0' -PropertyType String -Force | Out-Null
        Remove-ItemProperty -LiteralPath $wl -Name 'DefaultPassword' -ErrorAction SilentlyContinue
        Write-LogSuccess "Auto-login disabled; any stored plaintext password removed."
        return $true
    } catch {
        Write-LogWarning "Could not disable auto-login: $($_.Exception.Message)"
        return $false
    }
}

# Tray Icons: always show all notification-area icons (EnableAutoTray=0).
# Mirrors the "Tray Icons: Reloaded" tweak.
function Set-AlwaysShowTrayIcons {
    Write-LogInfo "Configuring the tray to always show all icons..."
    $exp = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    try {
        if (-not (Test-Path -LiteralPath $exp)) { New-Item -Path $exp -Force | Out-Null }
        New-ItemProperty -LiteralPath $exp -Name 'EnableAutoTray' -Value 0 -PropertyType DWord -Force | Out-Null

        $p = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($p) { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }
        Write-LogSuccess "All tray icons will now be shown (Explorer restarted)."
        Write-LogInfo "Note: on Windows 11 the notification-area overflow behaviour differs; this primarily affects Windows 10."
        return $true
    } catch {
        Write-LogWarning "Could not update the tray-icon setting: $($_.Exception.Message)"
        return $false
    }
}

# Taskbar tweaks: reasonable, documented defaults (align left, always combine,
# medium size). Mirrors the Dash-to-Dock tweak. TaskbarAl=0 is the detection
# sentinel (it differs from the Windows 11 default of centre).
function Set-TaskbarTweaks {
    Write-LogInfo "Applying taskbar tweaks (align left, always combine, medium size)..."
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    try {
        if (-not (Test-Path -LiteralPath $adv)) { New-Item -Path $adv -Force | Out-Null }
        New-ItemProperty -LiteralPath $adv -Name 'TaskbarAl'        -Value 0 -PropertyType DWord -Force | Out-Null  # 0=left, 1=centre (Win11)
        New-ItemProperty -LiteralPath $adv -Name 'TaskbarGlomLevel' -Value 0 -PropertyType DWord -Force | Out-Null  # 0=always combine + hide labels
        New-ItemProperty -LiteralPath $adv -Name 'TaskbarSi'        -Value 1 -PropertyType DWord -Force | Out-Null  # 0=small,1=medium,2=large (Win11)

        $p = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($p) { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }
        Write-LogSuccess "Taskbar tweaks applied (Explorer restarted)."
        return $true
    } catch {
        Write-LogWarning "Could not apply taskbar tweaks: $($_.Exception.Message)"
        return $false
    }
}

# Enable Windows Error Reporting (WER). Mirrors "Activate Apport".
function Enable-WindowsErrorReporting {
    Write-LogInfo "Enabling Windows Error Reporting..."
    $wer = 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'
    try {
        if (-not (Test-Path -LiteralPath $wer)) { New-Item -Path $wer -Force | Out-Null }
        New-ItemProperty -LiteralPath $wer -Name 'Disabled' -Value 0 -PropertyType DWord -Force | Out-Null
        Write-LogSuccess "Windows Error Reporting enabled."
        return $true
    } catch {
        Write-LogWarning "Could not enable Windows Error Reporting: $($_.Exception.Message)"
        return $false
    }
}

# Install the Windows Camera app. Mirrors "Install Camera (Cheese)". Windows
# Camera usually ships built-in; installs from the Microsoft Store if missing.
function Install-CameraApp {
    Write-LogInfo "Ensuring the Windows Camera app is installed..."
    try {
        if (Get-AppxPackage -Name 'Microsoft.WindowsCamera' -ErrorAction SilentlyContinue) {
            Write-LogInfo "Windows Camera is already installed (it ships with Windows)."
            return $true
        }
    } catch { }

    if (Test-Command 'winget') {
        $ok = Invoke-WithRetry -Description 'Windows Camera (winget msstore)' -Action {
            winget install --id 9WZDNCRFJBBG -e --source msstore --accept-package-agreements --accept-source-agreements
        }
        if ($ok) {
            Write-LogSuccess "Windows Camera installed."
            return $true
        }
    }
    Write-LogWarning "Could not install Windows Camera via winget; it is normally built into Windows (reinstall from the Microsoft Store if missing)."
    return $false
}

# Enable Storage Sense (policy) with periodic temp/recycle-bin cleanup.
# Mirrors "Cleanup Period: 2Y". Uses the Group Policy key so the behaviour is
# deterministic (this makes the Settings UI show these options as managed).
function Enable-StorageSense {
    Write-LogInfo "Enabling Storage Sense with periodic temp/recycle-bin cleanup..."
    $ss = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense'
    try {
        if (-not (Test-Path -LiteralPath $ss)) { New-Item -Path $ss -Force | Out-Null }
        New-ItemProperty -LiteralPath $ss -Name 'AllowStorageSenseGlobal'                  -Value 1  -PropertyType DWord -Force | Out-Null
        New-ItemProperty -LiteralPath $ss -Name 'ConfigStorageSenseGlobalCadence'          -Value 7  -PropertyType DWord -Force | Out-Null  # weekly
        New-ItemProperty -LiteralPath $ss -Name 'AllowStorageSenseTemporaryFilesCleanup'   -Value 1  -PropertyType DWord -Force | Out-Null
        New-ItemProperty -LiteralPath $ss -Name 'ConfigStorageSenseRecycleBinCleanupThreshold' -Value 30 -PropertyType DWord -Force | Out-Null  # 30 days
        Write-LogSuccess "Storage Sense enabled (weekly; recycle bin cleaned after 30 days)."
        return $true
    } catch {
        Write-LogWarning "Could not enable Storage Sense: $($_.Exception.Message)"
        return $false
    }
}

#===============================================================================
# DETECTION - Test-TweakApplied (mirrors gnome_tweak_applied)
# Returns $true if the tweak identified by -Key is currently applied.
# For keys that cannot be reliably detected (update-system, hostname,
# english-language) returns $false. Defensive: any error returns $false.
#===============================================================================
function Test-TweakApplied {
    param([Parameter(Mandatory)][string]$Key)
    try {
        switch ($Key) {
            'update-system'    { return $false }   # transient - not detectable
            'hostname'         { return $false }   # target name unknown here
            'english-language' { return $false }   # UI language not reliably detectable

            'script-launcher' {
                return [bool](Test-Path -LiteralPath 'HKCU:\Software\Classes\Directory\Background\shell\SmaiClaude')
            }
            'openssh' {
                $svc = Get-Service -Name sshd -ErrorAction SilentlyContinue
                return ($null -ne $svc -and $svc.Status -eq 'Running')
            }
            'cli-aliases' {
                $p = $PROFILE.CurrentUserAllHosts
                if (Test-Path -LiteralPath $p) {
                    $c = Get-Content -LiteralPath $p -Raw -ErrorAction SilentlyContinue
                    return ($null -ne $c -and $c -match '# BEGIN smai-aliases')
                }
                return $false
            }
            'screen-never-off' {
                $out = & powercfg.exe /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 2>$null
                $ac = $out | Where-Object { $_ -match 'Current AC Power Setting Index' } | Select-Object -First 1
                if ($ac -and ($ac -match '0x([0-9A-Fa-f]+)')) {
                    if ([Convert]::ToInt64($matches[1], 16) -eq 0) { return $true }
                }
                return $false
            }
            'show-hidden' {
                $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
                $h = (Get-ItemProperty -LiteralPath $adv -Name 'Hidden'      -ErrorAction SilentlyContinue).Hidden
                $e = (Get-ItemProperty -LiteralPath $adv -Name 'HideFileExt' -ErrorAction SilentlyContinue).HideFileExt
                return ($h -eq 1 -and $e -eq 0)
            }
            'keyboard-tr-q' {
                return ((Get-WinUserLanguageList).LanguageTag -contains 'tr-TR')
            }
            'keyboard-en-q' {
                return ((Get-WinUserLanguageList).LanguageTag -contains 'en-US')
            }
            'auto-login' {
                $v = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoAdminLogon' -ErrorAction SilentlyContinue).AutoAdminLogon
                return ($v -eq '1')
            }
            'tray-icons' {
                $v = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' -Name 'EnableAutoTray' -ErrorAction SilentlyContinue).EnableAutoTray
                return ($v -eq 0)
            }
            'taskbar' {
                $v = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -ErrorAction SilentlyContinue).TaskbarAl
                return ($v -eq 0)
            }
            'error-reporting' {
                $v = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -ErrorAction SilentlyContinue).Disabled
                return ($v -eq 0)
            }
            'camera' {
                return [bool](Get-AppxPackage -Name 'Microsoft.WindowsCamera' -ErrorAction SilentlyContinue)
            }
            'storage-sense' {
                $v = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense' -Name 'AllowStorageSenseGlobal' -ErrorAction SilentlyContinue).AllowStorageSenseGlobal
                return ($v -eq 1)
            }
            default { return $false }
        }
    } catch {
        return $false
    }
}

#===============================================================================
# Debloat — remove pre-installed Windows bloat.
#
# >>> USER-EDITABLE LIST <<<
# The authoritative removable list is finalized by the user. Everything below is
# a sensible STARTER set. Add/remove records in $script:DebloatItems. Each record:
#   @{ Key; Label; Kind='Appx'|'Winget'|'DevTool'|'Feature'; Id; ProvisionedToo=$true|$false }
#     Appx    -> Id is an AppxPackage name pattern (e.g. '*Xbox*'); removed for all users
#     Winget  -> Id is a winget package id; winget uninstall --silent
#     DevTool -> Id is a winget id / display-name of a tool this script installs
#     Feature -> Id is an optional-feature / capability name (Disable/Remove)
#   ProvisionedToo=$true also strips the provisioned (new-user) copy of an Appx.
#===============================================================================

$script:DebloatItems = @(
    # --- Special removals (custom logic; methods taken from the most-starred debloat tools) ---
    @{ Key='edge';          Label='Microsoft Edge (force uninstall)'; Kind='Script'; Remove='Remove-MicrosoftEdge'; DetectFn='Test-EdgeRemoved' }
    @{ Key='onedrive';      Label='OneDrive';                  Kind='Script'; Remove='Remove-OneDrive'; DetectFn='Test-OneDriveRemoved' }
    # --- Microsoft Store / UWP bloat (Appx) -----------------------------------
    @{ Key='xbox';          Label='Xbox apps';                 Kind='Appx'; Id='*Xbox*';                          ProvisionedToo=$true }
    @{ Key='gethelp';       Label='Get Help';                  Kind='Appx'; Id='*GetHelp*';                       ProvisionedToo=$true }
    @{ Key='tips';          Label='Tips';                      Kind='Appx'; Id='*Getstarted*';                    ProvisionedToo=$true }
    @{ Key='feedback';      Label='Feedback Hub';              Kind='Appx'; Id='*WindowsFeedbackHub*';            ProvisionedToo=$true }
    @{ Key='maps';          Label='Maps';                      Kind='Appx'; Id='*WindowsMaps*';                   ProvisionedToo=$true }
    @{ Key='weather';       Label='Weather';                   Kind='Appx'; Id='*BingWeather*';                   ProvisionedToo=$true }
    @{ Key='news';          Label='News';                      Kind='Appx'; Id='*BingNews*';                      ProvisionedToo=$true }
    @{ Key='solitaire';     Label='Solitaire Collection';      Kind='Appx'; Id='*MicrosoftSolitaireCollection*'; ProvisionedToo=$true }
    @{ Key='groove';        Label='Groove Music';              Kind='Appx'; Id='*ZuneMusic*';                     ProvisionedToo=$true }
    @{ Key='movies';        Label='Movies & TV';               Kind='Appx'; Id='*ZuneVideo*';                     ProvisionedToo=$true }
    @{ Key='people';        Label='People';                    Kind='Appx'; Id='*People*';                        ProvisionedToo=$true }
    @{ Key='phone';         Label='Phone Link';                Kind='Appx'; Id='*YourPhone*';                     ProvisionedToo=$true }
    @{ Key='clipchamp';     Label='Clipchamp';                 Kind='Appx'; Id='*Clipchamp*';                     ProvisionedToo=$true }
    @{ Key='teams';         Label='Teams (consumer)';          Kind='Appx'; Id='*MicrosoftTeams*';                ProvisionedToo=$true }
    @{ Key='copilot';       Label='Copilot';                   Kind='Appx'; Id='*Copilot*';                       ProvisionedToo=$true }
    @{ Key='quickassist';   Label='Quick Assist';              Kind='Appx'; Id='*QuickAssist*';                   ProvisionedToo=$true }
    # --- Dev tools / browsers this script installs (DevTool) -------------------
    @{ Key='rm-chrome';     Label='Google Chrome';             Kind='DevTool'; Id='Google.Chrome' }
    @{ Key='rm-nodejs';     Label='Node.js (nvm-windows)';     Kind='DevTool'; Id='CoreyButler.NVMforWindows' }
    @{ Key='rm-docker';     Label='Docker Desktop';            Kind='DevTool'; Id='Docker.DockerDesktop' }
    @{ Key='rm-vscode';     Label='Visual Studio Code';        Kind='DevTool'; Id='Microsoft.VisualStudioCode' }
    @{ Key='rm-dbeaver';    Label='DBeaver';                   Kind='DevTool'; Id='DBeaver.DBeaver' }
    @{ Key='rm-postman';    Label='Postman';                   Kind='DevTool'; Id='Postman.Postman' }
    @{ Key='rm-filezilla';  Label='FileZilla';                 Kind='DevTool'; Id='TimKosse.FileZilla.Client' }
    @{ Key='rm-gh';         Label='GitHub CLI';                Kind='DevTool'; Id='GitHub.cli' }
    @{ Key='rm-cloudflared';Label='Cloudflare Tunnel';         Kind='DevTool'; Id='Cloudflare.cloudflared' }
    # --- Remote tools (DevTool) ----------------------------------------------
    @{ Key='rm-anydesk';    Label='AnyDesk';                   Kind='DevTool'; Id='AnyDeskSoftwareGmbH.AnyDesk' }
    @{ Key='rm-rustdesk';   Label='RustDesk';                  Kind='DevTool'; Id='RustDesk.RustDesk' }
    @{ Key='rm-teamviewer'; Label='TeamViewer';                Kind='DevTool'; Id='TeamViewer.TeamViewer' }
    @{ Key='rm-realvnc';    Label='RealVNC';                   Kind='DevTool'; Id='RealVNC.VNCServer' }
)

#-------------------------------------------------------------------------------
# Is a debloat item already removed? (drives the [removed] marker; mirrors bloat_is_done)
#-------------------------------------------------------------------------------
function Test-BloatRemoved {
    param([Parameter(Mandatory)][hashtable]$Item)
    try {
        switch ($Item.Kind) {
            'Appx' {
                $pkg = Get-AppxPackage -AllUsers -Name $Item.Id -ErrorAction SilentlyContinue
                return (-not $pkg)
            }
            'Winget'  { return (-not (Test-App -WingetId $Item.Id)) }
            'DevTool' { return (-not (Test-App -WingetId $Item.Id)) }
            'Feature' {
                $f = Get-WindowsOptionalFeature -Online -FeatureName $Item.Id -ErrorAction SilentlyContinue
                if (-not $f) { return $true }
                return ($f.State -ne 'Enabled')
            }
            'Script'  { return [bool](& $Item.DetectFn) }
        }
    } catch { return $false }
    return $false
}

#-------------------------------------------------------------------------------
# Remove a single debloat item (dispatch by Kind). Returns $true on success.
#-------------------------------------------------------------------------------
function Remove-BloatItem {
    param([Parameter(Mandatory)][hashtable]$Item)
    Write-LogInfo "Removing: $($Item.Label)"
    try {
        switch ($Item.Kind) {
            'Appx' {
                Get-AppxPackage -AllUsers -Name $Item.Id -ErrorAction SilentlyContinue | ForEach-Object {
                    Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
                }
                if ($Item.ProvisionedToo) {
                    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                        Where-Object { $_.DisplayName -like $Item.Id } |
                        ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
                }
            }
            'Winget'  { if (Test-Winget) { winget uninstall --id $Item.Id -e --silent --accept-source-agreements 2>$null } }
            'DevTool' { if (Test-Winget) { winget uninstall --id $Item.Id -e --silent --accept-source-agreements 2>$null } }
            'Feature' { Disable-WindowsOptionalFeature -Online -FeatureName $Item.Id -NoRestart -ErrorAction SilentlyContinue | Out-Null }
            'Script'  { & $Item.Remove | Out-Null }
        }
        Write-LogSuccess "Removed: $($Item.Label)"
        return $true
    } catch {
        Write-LogWarning "Could not remove $($Item.Label): $($_.Exception.Message)"
        return $false
    }
}

#-------------------------------------------------------------------------------
# Run debloat for the selected keys ($script:SelectedDebloat holds keys).
#-------------------------------------------------------------------------------
function Invoke-Debloat {
    Write-LogStep "Debloat — removing selected items"
    if (-not $script:SelectedDebloat -or $script:SelectedDebloat.Count -eq 0) {
        Write-LogInfo "No debloat items selected."
        return
    }
    foreach ($key in $script:SelectedDebloat) {
        $item = $script:DebloatItems | Where-Object { $_.Key -eq $key } | Select-Object -First 1
        if ($item) { Remove-BloatItem -Item $item | Out-Null }
    }
}

#===============================================================================
# OneDrive removal (canonical method used by the popular debloat tools):
# kill the client, run the built-in OneDriveSetup /uninstall, drop scheduled
# tasks, unpin from Explorer, and delete leftover folders.
#===============================================================================
function Remove-OneDrive {
    Write-LogInfo "Removing OneDrive..."
    try {
        Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $setup = Join-Path $env:SystemRoot 'SysWOW64\OneDriveSetup.exe'
        if (-not (Test-Path $setup)) { $setup = Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe' }
        if (Test-Path $setup) {
            Start-Process -FilePath $setup -ArgumentList '/uninstall' -Wait -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        try { Get-ScheduledTask -TaskName '*OneDrive*' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue } catch { }
        # Unpin from the File Explorer sidebar (64-bit + 32-bit views)
        reg add "HKCR\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        reg add "HKCR\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f 2>&1 | Out-Null
        foreach ($p in @("$env:USERPROFILE\OneDrive", "$env:LOCALAPPDATA\Microsoft\OneDrive", "$env:PROGRAMDATA\Microsoft OneDrive", "$env:SystemDrive\OneDriveTemp")) {
            if ($p -and (Test-Path $p)) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
        }
        return $true
    } catch {
        Write-LogWarning "OneDrive removal issue: $($_.Exception.Message)"
        return $false
    }
}

function Test-OneDriveRemoved {
    return (-not (Test-Path (Join-Path $env:LOCALAPPDATA 'Microsoft\OneDrive\OneDrive.exe')))
}

#===============================================================================
# Microsoft Edge force-uninstall.
# Method from the most-starred debloat tools (Raphire/Win11Debloat + AveYo):
# unblock via EdgeUpdateDev\AllowUninstall, then run the registered
# UninstallString with --force-uninstall (fall back to the Application setup.exe).
# WARNING: Edge is protected; this can affect WebView-dependent apps and Windows
# may reinstall it. It is opt-in from the Debloat sub-menu.
#===============================================================================
function Remove-MicrosoftEdge {
    Write-LogWarning "Force-removing Microsoft Edge (may affect WebView-based apps; Windows can reinstall it)."
    try {
        try {
            New-Item -Path 'HKLM:\SOFTWARE\Microsoft\EdgeUpdateDev' -Force -ErrorAction SilentlyContinue | Out-Null
            New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\EdgeUpdateDev' -Name 'AllowUninstall' -Value '' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
        } catch { }
        foreach ($proc in @('msedge', 'msedgewebview2', 'MicrosoftEdgeUpdate', 'WebViewHost')) {
            Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        $done = $false
        foreach ($hive in @(
                'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge')) {
            $us = (Get-ItemProperty -Path $hive -ErrorAction SilentlyContinue).UninstallString
            if ($us) {
                $exe = $null; $rest = ''
                if     ($us -match '^"([^"]+)"\s*(.*)$') { $exe = $matches[1]; $rest = $matches[2] }
                elseif ($us -match '^(\S+)\s*(.*)$')     { $exe = $matches[1]; $rest = $matches[2] }
                if ($exe -and (Test-Path $exe)) {
                    if ($rest -notmatch '--force-uninstall') { $rest = ($rest + ' --force-uninstall').Trim() }
                    Start-Process -FilePath $exe -ArgumentList $rest -Wait -ErrorAction SilentlyContinue
                    $done = $true; break
                }
            }
        }
        if (-not $done) {
            foreach ($root in @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application", "$env:ProgramFiles\Microsoft\Edge\Application")) {
                if (Test-Path $root) {
                    $setup = Get-ChildItem -Path $root -Recurse -Filter 'setup.exe' -ErrorAction SilentlyContinue |
                             Where-Object { $_.FullName -like '*\Installer\setup.exe' } | Select-Object -First 1
                    if ($setup) {
                        Start-Process -FilePath $setup.FullName -ArgumentList '--uninstall --system-level --verbose-logging --force-uninstall' -Wait -ErrorAction SilentlyContinue
                        $done = $true; break
                    }
                }
            }
        }
        Remove-Item -LiteralPath "$env:PUBLIC\Desktop\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
        $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $ri = Get-Item -Path $run -ErrorAction SilentlyContinue
        if ($ri) {
            foreach ($name in $ri.Property) {
                if ($name -like 'MicrosoftEdgeAutoLaunch*' -or $name -eq 'Microsoft Edge Update') {
                    Remove-ItemProperty -Path $run -Name $name -ErrorAction SilentlyContinue
                }
            }
        }
        if ($done) { return $true }
        Write-LogWarning "Could not locate the Edge uninstaller."
        return $false
    } catch {
        Write-LogWarning "Edge removal issue: $($_.Exception.Message)"
        return $false
    }
}

function Test-EdgeRemoved {
    $p1 = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    $p2 = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    return ((-not (Test-Path $p1)) -and (-not (Test-Path $p2)))
}

#===============================================================================
# Interactive TUI menu — flicker-free, birebir with the source's arrow-key menu.
#
# Performance notes (these were the reported lag/flicker causes):
#   * We redraw by moving the cursor to (0,0) and OVERWRITING padded lines every
#     frame — NEVER Clear-Host per keypress. Clear-Host happens only on entry and
#     when returning from a sub-menu.
#   * Status markers (installed/applied/removed) are computed ONCE before the loop
#     (detection hits winget/registry and is slow), never per frame.
#===============================================================================

# Menu-driven selection state (also consumed by the flag dispatcher)
$script:SelectedTweaks      = @()
$script:SelectedDebloat     = @()
$script:SelectedVSCodeExt   = @()
$script:VSCodeApplySettings = $true
$script:HostnameValue       = $null
$script:_MainRows           = $null

function Set-MenuCursorVisible { param([bool]$Visible) try { [System.Console]::CursorVisible = $Visible } catch { } }

# Group marker text (mirrors group_marker): "" / "<word>" / "<inst>/<total> <word>"
function Get-GroupMarkerText {
    param([int]$Installed, [int]$Total, [string]$Word)
    if ($Installed -le 0) { return '' }
    if ($Installed -ge $Total) { return $Word }
    return "$Installed/$Total $Word"
}

# Write a single line as colored segments, padded with spaces to the console
# width so leftover characters from the previous frame are erased (no flicker).
function Write-PadLine {
    param([object[]]$Segs)
    $len = 0
    foreach ($s in $Segs) {
        $t = [string]$s.t
        if ($t.Length -gt 0) {
            if ($s.c) { Write-Host $t -ForegroundColor $s.c -NoNewline } else { Write-Host $t -NoNewline }
            $len += $t.Length
        }
    }
    $w = 80; try { $w = [System.Console]::WindowWidth } catch { }
    $pad = $w - 1 - $len
    if ($pad -gt 0) { Write-Host (' ' * $pad) -NoNewline }
    Write-Host ''
}

# Print the system header (used by non-menu screens like backup/restore).
function Show-SystemHeader {
    Write-Host ''
    foreach ($h in (Get-HeaderLines)) { Write-Host $h.t -ForegroundColor $h.c }
    Write-Host ''
}

# Precompute the system header lines once (Get-CimInstance is slow).
function Get-HeaderLines {
    $os = $null
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue } catch { }
    $edition = if ($os) { $os.Caption } else { 'Windows' }
    $build   = if ($os) { $os.Version } else { '' }
    return @(
        @{ t = ("   Windows Post-Installation Setup  v{0}" -f $script:SCRIPT_VERSION); c = 'Cyan' },
        @{ t = ("   {0}  (build {1})" -f $edition, $build); c = 'DarkGray' },
        @{ t = ("   Host: {0}    User: {1}" -f $env:COMPUTERNAME, $env:USERNAME); c = 'DarkGray' }
    )
}

#-------------------------------------------------------------------------------
# Generic flicker-free arrow-key menu engine (used by the main menu and every
# sub-menu). Mutates each row's .Selected. Returns 'confirm' or 'quit'.
#   Row fields: Num, Label, Desc, Marker, Selected, IsGroup, OnEnter,
#               SelectedCheck (optional scriptblock -> bool for derived rows)
#-------------------------------------------------------------------------------
function Invoke-SelectMenu {
    param(
        [object[]]$Header = @(),
        [string]$Banner = '',
        [System.Collections.ArrayList]$Rows,
        [scriptblock]$Summary,
        [scriptblock]$OnSelectAll,
        [scriptblock]$OnSelectNone
    )
    $cursor = 0
    $needClear = $false
    Set-MenuCursorVisible $false
    Clear-Host
    try {
        while ($true) {
            # In-place redraw when the frame fits the window (no flicker); otherwise
            # fall back to Clear-Host each frame (correct, some flicker on tall lists).
            $fh = $Header.Count + 4 + $Rows.Count + 3
            $wh = 25; try { $wh = [System.Console]::WindowHeight } catch { }
            $inPlace = ($fh -lt $wh)
            if ($needClear -or -not $inPlace) { Clear-Host; $needClear = $false }
            if ($inPlace) { try { [System.Console]::SetCursorPosition(0, 0) } catch { Clear-Host } }

            foreach ($h in $Header) { Write-PadLine @($h) }
            Write-PadLine @(@{ t = '  ==============================================================='; c = 'Green' })
            Write-PadLine @(@{ t = ("   {0}" -f $Banner); c = 'Green' })
            Write-PadLine @(@{ t = '  ==============================================================='; c = 'Green' })
            Write-PadLine @(@{ t = '' })

            for ($i = 0; $i -lt $Rows.Count; $i++) {
                $r = $Rows[$i]
                $sel = if ($r.SelectedCheck) { [bool](& $r.SelectedCheck) } else { [bool]$r.Selected }
                $segs = @()
                if ($i -eq $cursor) { $segs += @{ t = ' > '; c = 'Cyan' } } else { $segs += @{ t = '   ' } }
                $segs += @{ t = ('[{0,2}] ' -f $r.Num); c = 'Blue' }
                if ($r.IsGroup) {
                    $segs += @{ t = $(if ($sel) { '[+] ' } else { '[ ] ' }); c = $(if ($sel) { 'Green' } else { 'DarkGray' }) }
                } else {
                    $segs += @{ t = $(if ($sel) { '[x] ' } else { '[ ] ' }); c = $(if ($sel) { 'Green' } else { 'Gray' }) }
                }
                $segs += @{ t = $r.Label; c = $(if ($sel) { 'Green' } else { 'White' }) }
                if ($r.Desc)   { $segs += @{ t = (' - ' + $r.Desc); c = 'DarkGray' } }
                if ($r.Marker) { $segs += @{ t = ('  **' + $r.Marker); c = 'Yellow' } }
                Write-PadLine $segs
            }

            Write-PadLine @(@{ t = '  ---------------------------------------------------------------'; c = 'Yellow' })
            if ($Summary) { Write-PadLine @(@{ t = ('  ' + (& $Summary)); c = 'Green' }) } else { Write-PadLine @(@{ t = '' }) }
            Write-PadLine @(@{ t = '   UP/DN move  SPACE toggle  ENTER sub-menu  a all  n none  c confirm  q quit'; c = 'DarkGray' })

            $k   = [System.Console]::ReadKey($true)
            $key = $k.Key
            $ch  = [char]::ToLower([char]$k.KeyChar)

            if ($key -eq 'UpArrow'   -or $ch -eq 'k') { if ($cursor -gt 0) { $cursor-- } }
            elseif ($key -eq 'DownArrow' -or $ch -eq 'j') { if ($cursor -lt $Rows.Count - 1) { $cursor++ } }
            elseif ($key -eq 'Spacebar' -or $key -eq 'Enter') {
                $r = $Rows[$cursor]
                if ($r.OnEnter) { & $r.OnEnter; $needClear = $true } else { $r.Selected = -not $r.Selected }
            }
            elseif ($ch -eq 'a') { foreach ($r in $Rows) { if (-not $r.IsGroup) { $r.Selected = $true } }; if ($OnSelectAll) { & $OnSelectAll } }
            elseif ($ch -eq 'n') { foreach ($r in $Rows) { if (-not $r.IsGroup) { $r.Selected = $false } }; if ($OnSelectNone) { & $OnSelectNone } }
            elseif ($ch -eq 'c') { return 'confirm' }
            elseif ($ch -eq 'q' -or $key -eq 'Escape') { return 'quit' }
        }
    } finally {
        Set-MenuCursorVisible $true
    }
}

#-------------------------------------------------------------------------------
# Sub-menus — each precomputes markers once, runs the engine, writes back on confirm.
#-------------------------------------------------------------------------------
function Show-RemoteSubmenu {
    $rows = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($t in $script:RemoteTools) {
        $n++
        $mk = ''
        if (& $t.Detect) { $mk = if (Test-RemoteUpdateAvailable -Key $t.Key) { 'update available' } else { 'installed' } }
        [void]$rows.Add(@{ Num = $n; Label = $t.Label; Desc = ''; Marker = $mk; Selected = [bool]$flags[$t.Flag]; IsGroup = $false; OnEnter = $null; Ref = $t })
    }
    if ((Invoke-SelectMenu -Banner 'Remote Support Tools' -Rows $rows) -eq 'confirm') {
        foreach ($r in $rows) { $flags[$r.Ref.Flag] = [bool]$r.Selected }
    }
}

function Show-AiCliSubmenu {
    $rows = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($t in $script:AiCliTools) {
        $n++
        $mk = ''; if (& $t.Detect) { $mk = 'installed' }
        [void]$rows.Add(@{ Num = $n; Label = $t.Label; Desc = ''; Marker = $mk; Selected = [bool]$flags[$t.Flag]; IsGroup = $false; OnEnter = $null; Ref = $t })
    }
    if ((Invoke-SelectMenu -Banner 'AI CLI Tools' -Rows $rows) -eq 'confirm') {
        foreach ($r in $rows) { $flags[$r.Ref.Flag] = [bool]$r.Selected }
    }
}

function Show-TweaksSubmenu {
    $rows = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($t in $script:WindowsTweaks) {
        $n++
        $mk = ''; if (Test-TweakApplied -Key $t.Key) { $mk = 'applied' }
        [void]$rows.Add(@{ Num = $n; Label = $t.Label; Desc = ''; Marker = $mk; Selected = ($script:SelectedTweaks -contains $t.Key); IsGroup = $false; OnEnter = $null; Ref = $t })
    }
    if ((Invoke-SelectMenu -Banner 'Windows Tweaks' -Rows $rows) -eq 'confirm') {
        $script:SelectedTweaks = @($rows | Where-Object { $_.Selected } | ForEach-Object { $_.Ref.Key })
        if ($script:SelectedTweaks.Count -gt 0) { $flags.Tweaks = $true }
        if (($script:SelectedTweaks -contains 'hostname') -and -not $script:HostnameValue) {
            Set-MenuCursorVisible $true
            $script:HostnameValue = Read-Host "`n  Enter the new computer hostname"
        }
    }
}

function Show-DebloatSubmenu {
    $rows = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($t in $script:DebloatItems) {
        $n++
        $mk = ''; if (Test-BloatRemoved -Item $t) { $mk = 'removed' }
        [void]$rows.Add(@{ Num = $n; Label = $t.Label; Desc = ''; Marker = $mk; Selected = ($script:SelectedDebloat -contains $t.Key); IsGroup = $false; OnEnter = $null; Ref = $t })
    }
    if ((Invoke-SelectMenu -Banner 'Debloat (remove pre-installed apps)' -Rows $rows) -eq 'confirm') {
        $script:SelectedDebloat = @($rows | Where-Object { $_.Selected } | ForEach-Object { $_.Ref.Key })
        if ($script:SelectedDebloat.Count -gt 0) { $flags.Debloat = $true }
    }
}

function Show-VSCodeSubmenu {
    $rows = New-Object System.Collections.ArrayList
    [void]$rows.Add(@{ Num = 1; Label = 'Install Visual Studio Code'; Desc = ''; Marker = $(if (Test-VSCodeInstalled) { 'installed' } else { '' }); Selected = [bool]$flags.VSCode; IsGroup = $false; OnEnter = $null; Kind = 'install' })
    [void]$rows.Add(@{ Num = 2; Label = 'Apply recommended settings'; Desc = ''; Marker = ''; Selected = [bool]$script:VSCodeApplySettings; IsGroup = $false; OnEnter = $null; Kind = 'settings' })
    $n = 2
    foreach ($e in $script:VSCodeExtensions) {
        $n++
        [void]$rows.Add(@{ Num = $n; Label = ("Extension: {0}" -f $e.Label); Desc = ''; Marker = ''; Selected = ($script:SelectedVSCodeExt -contains $e.Id); IsGroup = $false; OnEnter = $null; Kind = 'ext'; Ref = $e })
    }
    if ((Invoke-SelectMenu -Banner 'Visual Studio Code' -Rows $rows) -eq 'confirm') {
        $script:VSCodeApplySettings = [bool]($rows | Where-Object { $_.Kind -eq 'settings' } | Select-Object -First 1).Selected
        $script:SelectedVSCodeExt   = @($rows | Where-Object { $_.Kind -eq 'ext' -and $_.Selected } | ForEach-Object { $_.Ref.Id })
        $installSel = [bool]($rows | Where-Object { $_.Kind -eq 'install' } | Select-Object -First 1).Selected
        if ($installSel -or $script:SelectedVSCodeExt.Count -gt 0 -or $script:VSCodeApplySettings) { $flags.VSCode = $true }
    }
}

#-------------------------------------------------------------------------------
# Main interactive menu (birebir: one flat numbered list, groups expand on ENTER)
#-------------------------------------------------------------------------------
function Show-InteractiveMenu {
    Reset-DetectionCache
    Write-Host ""
    Write-Host "  Scanning installed software..." -ForegroundColor DarkGray

    $dev = @{}
    foreach ($d in $script:DevTools) { $dev[$d.Key] = $d }

    # Precompute group markers ONCE (detection is slow)
    $rmInst = @($script:RemoteTools  | Where-Object { & $_.Detect }).Count
    $aiInst = @($script:AiCliTools   | Where-Object { & $_.Detect }).Count
    $twInst = @($script:WindowsTweaks| Where-Object { Test-TweakApplied -Key $_.Key }).Count
    $dbInst = @($script:DebloatItems | Where-Object { Test-BloatRemoved -Item $_ }).Count
    $vsInst = if (Test-VSCodeInstalled) { 'installed' } else { '' }

    # Birebir order + descriptions
    $order = @(
        @{ k='remote';      group='remote';  label='Remote Support Tools'; desc='RealVNC, AnyDesk, RustDesk, TeamViewer (Enter to expand)'; marker=(Get-GroupMarkerText $rmInst $script:RemoteTools.Count 'installed') }
        @{ k='nodejs';                        label='NodeJS';       desc='nvm-windows + Node.js 22 + Yarn' }
        @{ k='chrome';                        label='Chrome';       desc='Google Chrome' }
        @{ k='vscode';      group='vscode';  label='VS Code';      desc='Visual Studio Code (Enter: extensions & settings)'; marker=$vsInst }
        @{ k='python';                        label='Python';       desc='Python 3' }
        @{ k='tweaks';      group='tweaks';  label='Tweaks';       desc='Windows tweaks (Enter to expand)'; marker=(Get-GroupMarkerText $twInst $script:WindowsTweaks.Count 'applied') }
        @{ k='dbeaver';                       label='DBeaver';      desc='DBeaver CE (database tool)' }
        @{ k='vlc';                           label='VLC';          desc='VLC Media Player' }
        @{ k='cloudflared';                   label='Cloudflared';  desc='Cloudflare Tunnel client' }
        @{ k='docker';                        label='Docker';       desc='Docker Desktop' }
        @{ k='aicli';       group='aicli';   label='AI CLI Tools'; desc='Claude, Codex, Kimi, Grok, Gemini, Qwen, GLM (Enter to expand)'; marker=(Get-GroupMarkerText $aiInst $script:AiCliTools.Count 'installed') }
        @{ k='gh';                            label='GitHub CLI';   desc='GitHub CLI (gh)' }
        @{ k='postman';                       label='Postman';      desc='Postman (API testing)' }
        @{ k='filezilla';                     label='FileZilla';    desc='FileZilla (FTP/SFTP)' }
        @{ k='debloat';     group='debloat'; label='Debloat';      desc='Remove pre-installed apps (Enter to expand)'; marker=(Get-GroupMarkerText $dbInst $script:DebloatItems.Count 'removed') }
    )

    $rows = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($o in $order) {
        $n++
        if ($o.group) {
            $g = $o.group
            $onEnter = switch ($g) {
                'remote'  { { Show-RemoteSubmenu } }
                'vscode'  { { Show-VSCodeSubmenu } }
                'tweaks'  { { Show-TweaksSubmenu } }
                'aicli'   { { Show-AiCliSubmenu } }
                'debloat' { { Show-DebloatSubmenu } }
            }
            $check = switch ($g) {
                'remote'  { { @($script:RemoteTools | Where-Object { $flags[$_.Flag] }).Count -gt 0 } }
                'vscode'  { { [bool]$flags.VSCode -or $script:SelectedVSCodeExt.Count -gt 0 } }
                'tweaks'  { { $script:SelectedTweaks.Count -gt 0 } }
                'aicli'   { { @($script:AiCliTools | Where-Object { $flags[$_.Flag] }).Count -gt 0 } }
                'debloat' { { $script:SelectedDebloat.Count -gt 0 } }
            }
            [void]$rows.Add(@{ Num=$n; Label=$o.label; Desc=$o.desc; Marker=$o.marker; IsGroup=$true; OnEnter=$onEnter; SelectedCheck=$check })
        } else {
            $d = $dev[$o.k]
            $mk = ''; if (& $d.Detect) { $mk = 'installed' }
            [void]$rows.Add(@{ Num=$n; Label=$o.label; Desc=$o.desc; Marker=$mk; IsGroup=$false; OnEnter=$null; Selected=$false; Ref=$d })
        }
    }
    $script:_MainRows = $rows

    $summary = {
        $parts = @()
        foreach ($row in $script:_MainRows) { if (-not $row.IsGroup -and $row.Selected) { $parts += $row.Label } }
        $rm = @($script:RemoteTools  | Where-Object { $flags[$_.Flag] } | ForEach-Object { $_.Key });   if ($rm.Count) { $parts += "Remote[$($rm -join ',')]" }
        $ai = @($script:AiCliTools   | Where-Object { $flags[$_.Flag] } | ForEach-Object { $_.Key });   if ($ai.Count) { $parts += "AI[$($ai -join ',')]" }
        if ($script:SelectedTweaks.Count)  { $parts += "Tweaks[$($script:SelectedTweaks.Count)]" }
        if ($script:SelectedDebloat.Count) { $parts += "Debloat[$($script:SelectedDebloat.Count)]" }
        if ($flags.VSCode) { $parts += 'VSCode' }
        if ($parts.Count -gt 0) { return "Selected ($($parts.Count)): " + ($parts -join ', ') }
        return 'Selected: None'
    }

    $selectAll = {
        foreach ($t in $script:AiCliTools)  { $flags[$t.Flag] = $true }
        foreach ($t in $script:RemoteTools) { $flags[$t.Flag] = $true }
        $script:SelectedTweaks    = @($script:WindowsTweaks | ForEach-Object { $_.Key })
        $script:SelectedDebloat   = @($script:DebloatItems  | ForEach-Object { $_.Key })
        $script:SelectedVSCodeExt = @($script:VSCodeExtensions | ForEach-Object { $_.Id })
        $flags.Tweaks = $true; $flags.Debloat = $true; $flags.VSCode = $true
    }
    $selectNone = {
        foreach ($t in $script:AiCliTools)  { $flags[$t.Flag] = $false }
        foreach ($t in $script:RemoteTools) { $flags[$t.Flag] = $false }
        $script:SelectedTweaks = @(); $script:SelectedDebloat = @(); $script:SelectedVSCodeExt = @()
        $flags.Tweaks = $false; $flags.Debloat = $false; $flags.VSCode = $false
    }

    $result = Invoke-SelectMenu -Header (Get-HeaderLines) -Banner 'Select what to install / apply' `
        -Rows $rows -Summary $summary -OnSelectAll $selectAll -OnSelectNone $selectNone

    Set-MenuCursorVisible $true
    Clear-Host
    if ($result -ne 'confirm') { Write-LogInfo "Cancelled. Nothing was changed."; return }

    foreach ($row in $rows) { if (-not $row.IsGroup -and $row.Selected) { $flags[$row.Ref.Flag] = $true } }
    Reset-DetectionCache
    Invoke-Installations
}

#===============================================================================
# Dispatch — run installs/tweaks/debloat from $flags + $script:Selected* lists.
# Both the CLI (flag) path and the menu path converge here (mirrors run_installations).
#===============================================================================

$script:SummaryDone   = New-Object System.Collections.ArrayList
$script:SummarySkipped = New-Object System.Collections.ArrayList

function Add-Summary  { param([string]$Text, [bool]$Ok = $true)
    if ($Ok) { [void]$script:SummaryDone.Add($Text) } else { [void]$script:SummarySkipped.Add($Text) }
}

#-------------------------------------------------------------------------------
# Expand group flags (--aicli / --remote / --all) into per-item flags
#-------------------------------------------------------------------------------
function Expand-GroupFlags {
    if ($flags.AiCli)  { foreach ($t in $script:AiCliTools)  { $flags[$t.Flag] = $true } }
    if ($flags.Remote) { foreach ($t in $script:RemoteTools) { $flags[$t.Flag] = $true } }
}

#-------------------------------------------------------------------------------
# Apply the selected Windows tweaks (backs up first)
#-------------------------------------------------------------------------------
function Invoke-Tweaks {
    if (-not $script:SelectedTweaks -or $script:SelectedTweaks.Count -eq 0) {
        # CLI path: --tweaks with no prior selection -> open the submenu to choose
        Show-TweaksSubmenu
    }
    if (-not $script:SelectedTweaks -or $script:SelectedTweaks.Count -eq 0) { return }

    Write-LogStep "Applying Windows tweaks"
    Save-TweakBackup | Out-Null

    foreach ($key in $script:SelectedTweaks) {
        $tw = $script:WindowsTweaks | Where-Object { $_.Key -eq $key } | Select-Object -First 1
        if (-not $tw) { continue }
        try {
            if ($tw.Key -eq 'hostname') {
                if (-not $script:HostnameValue) { $script:HostnameValue = Read-Host "  Enter the new computer hostname" }
                if ($script:HostnameValue) { & $tw.Apply -Name $script:HostnameValue }
            } else {
                & $tw.Apply
            }
            Add-Summary "Tweak: $($tw.Label)"
        } catch {
            Write-LogWarning "Tweak '$($tw.Label)' failed: $($_.Exception.Message)"
            Add-Summary "Tweak: $($tw.Label)" $false
        }
    }
}

#-------------------------------------------------------------------------------
# Install a single catalog item (with vscode special-casing)
#-------------------------------------------------------------------------------
function Invoke-InstallItem {
    param([hashtable]$Item)
    try {
        if ($Item.Key -eq 'vscode') {
            $ok = & $Item.Install
            if ($ok) {
                $ids = @($script:SelectedVSCodeExt)
                if ($ids.Count -eq 0) { $ids = @($script:VSCodeExtensions | ForEach-Object { $_.Id }) }
                if (Get-Command Install-VSCodeExtensions -ErrorAction SilentlyContinue) { Install-VSCodeExtensions -Ids $ids }
                if ($script:VSCodeApplySettings -and (Get-Command Set-VSCodeSettings -ErrorAction SilentlyContinue)) { Set-VSCodeSettings }
            }
            Add-Summary $Item.Label ([bool]$ok)
        } else {
            $ok = & $Item.Install
            Add-Summary $Item.Label ([bool]$ok)
        }
    } catch {
        Write-LogWarning "$($Item.Label) failed: $($_.Exception.Message)"
        Add-Summary $Item.Label $false
    }
}

#-------------------------------------------------------------------------------
# Master orchestration
#-------------------------------------------------------------------------------
function Invoke-Installations {
    Expand-GroupFlags

    # Dev tools
    foreach ($d in $script:DevTools)    { if ($flags[$d.Flag]) { Invoke-InstallItem $d } }
    # AI CLI tools
    foreach ($t in $script:AiCliTools)  { if ($flags[$t.Flag]) { Invoke-InstallItem $t } }
    # Remote tools
    foreach ($t in $script:RemoteTools) { if ($flags[$t.Flag]) { Invoke-InstallItem $t } }

    # Windows tweaks / debloat
    if ($flags.Tweaks)  { Invoke-Tweaks }
    if ($flags.Debloat) {
        if (-not $script:SelectedDebloat -or $script:SelectedDebloat.Count -eq 0) { Show-DebloatSubmenu }
        Invoke-Debloat
    }

    Show-Summary
}

#-------------------------------------------------------------------------------
# Final summary (mirrors print_summary)
#-------------------------------------------------------------------------------
function Show-Summary {
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "   Summary" -ForegroundColor Cyan
    Write-Host "  ============================================================" -ForegroundColor Cyan
    if ($script:SummaryDone.Count -gt 0) {
        Write-Host "   Completed:" -ForegroundColor Green
        foreach ($s in $script:SummaryDone) { Write-Host "     + $s" -ForegroundColor Green }
    }
    if ($script:SummarySkipped.Count -gt 0) {
        Write-Host "   Skipped / failed:" -ForegroundColor Yellow
        foreach ($s in $script:SummarySkipped) { Write-Host "     - $s" -ForegroundColor Yellow }
    }
    if ($script:SummaryDone.Count -eq 0 -and $script:SummarySkipped.Count -eq 0) {
        Write-Host "   Nothing to do." -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-LogSuccess "Done. Some changes (hostname, keyboard, language, auto-login) may need a sign-out or reboot."
}

#-------------------------------------------------------------------------------
# CLI login helpers (mirrors run_cli_logins) — best-effort, interactive
#-------------------------------------------------------------------------------
function Invoke-CliLogins {
    Write-LogStep "CLI login helpers"
    if (Test-Command 'gh')     { Write-LogInfo "Launching 'gh auth login'...";  gh auth login }
    if (Test-Command 'claude') { Write-LogInfo "Run 'claude' once to sign in to Claude Code." }
    if (Test-Command 'codex')  { Write-LogInfo "Run 'codex' once to sign in to Codex." }
}

#-------------------------------------------------------------------------------
# Self-update check (mirrors check_for_update): compare local SCRIPT_REVISION with
# the latest revision in the Gist; on a newer rev, offer to download + re-launch.
# Skipped for git checkouts, with --skip-update, or when SKIP_UPDATE_CHECK=1.
#-------------------------------------------------------------------------------
function Invoke-UpdateCheck {
    if ($flags.SkipUpdate) { return }
    if ($env:SKIP_UPDATE_CHECK -eq '1') { return }
    if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
        $dir = Split-Path -Parent $PSCommandPath
        if ($dir -and (Test-Path (Join-Path $dir '.git'))) { return }
    }

    Write-Host "Checking for script updates..." -ForegroundColor Cyan
    $localRev = 0; [int]::TryParse([string]$script:SCRIPT_REVISION, [ref]$localRev) | Out-Null

    $remoteContent = $null
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
        $bust = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $api  = Invoke-RestMethod -Uri ("https://api.github.com/gists/{0}?_={1}" -f $script:GIST_ID, $bust) `
                    -Headers @{ 'Cache-Control' = 'no-cache'; 'Accept' = 'application/vnd.github+json'; 'User-Agent' = 'windows-setup' } `
                    -TimeoutSec 10
        $rawUrl = $api.files.($script:GIST_FILE).raw_url
        if ($rawUrl) {
            $remoteContent = Invoke-RestMethod -Uri $rawUrl -Headers @{ 'Cache-Control' = 'no-cache'; 'User-Agent' = 'windows-setup' } -TimeoutSec 30
            if ($remoteContent -is [array]) { $remoteContent = $remoteContent -join "`n" }
        }
    } catch {
        Write-Host "Could not reach the gist, continuing with rev-$localRev" -ForegroundColor Yellow
        return
    }
    if (-not $remoteContent) { Write-Host "Could not fetch latest, continuing with rev-$localRev" -ForegroundColor Yellow; return }

    $m = [regex]::Match([string]$remoteContent, "SCRIPT_REVISION\s*=\s*'?(\d+)'?")
    if (-not $m.Success) { Write-Host "Could not detect remote revision, continuing with rev-$localRev" -ForegroundColor Yellow; return }
    $remoteRev = [int]$m.Groups[1].Value

    if ($remoteRev -le $localRev) { Write-Host "You're on the latest rev-$localRev" -ForegroundColor Green; return }

    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Yellow
    Write-Host ("   Update available: rev-{0} -> rev-{1}" -f $localRev, $remoteRev) -ForegroundColor Yellow
    Write-Host "  ============================================================" -ForegroundColor Yellow
    Write-Host ""
    $ans = Read-Host "Download and run the latest version now? (y/n)"
    if ($ans -notmatch '^[Yy]') { Write-Host "Continuing with rev-$localRev" -ForegroundColor Yellow; return }

    $tmp = Join-Path $env:TEMP ("windows-setup-rev{0}.ps1" -f $remoteRev)
    try { Set-Content -Path $tmp -Value $remoteContent -Encoding UTF8 -ErrorAction Stop } catch { Write-Host "Failed to save the new script, continuing with rev-$localRev" -ForegroundColor Red; return }
    if (-not (Test-Path $tmp)) { Write-Host "Failed to save the new script, continuing with rev-$localRev" -ForegroundColor Red; return }

    $env:SKIP_UPDATE_CHECK = '1'
    Write-Host "Re-launching with rev-$remoteRev..." -ForegroundColor Green
    Write-Host ""
    $ps = Get-PowerShellPath
    & $ps -NoProfile -ExecutionPolicy Bypass -File $tmp @($script:RAW_ARGS)
    exit $LASTEXITCODE
}

#===============================================================================
# main
#===============================================================================
function main {
    if ($flags.ShowHelp)    { Show-Help;    return }
    if ($flags.ShowVersion) { Show-Version; return }

    # Self-update check (before elevation; skipped for git checkouts / --skip-update)
    Invoke-UpdateCheck

    # Everything below needs administrator rights.
    Invoke-Elevation
    Install-Prerequisites

    if ($flags.ShowBackup) { Show-Backups;   return }
    if ($flags.Restore)    { Restore-Backup; return }

    if ($flags.ShowMenu) {
        Show-InteractiveMenu
    } else {
        Invoke-Installations
    }

    if ($flags.Login) { Invoke-CliLogins }
}

main


