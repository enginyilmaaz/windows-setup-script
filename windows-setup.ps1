#Requires -Version 5.1
<#
.SYNOPSIS
    Windows Post-Installation Setup Script
.DESCRIPTION
    Automates Windows 10/11 post-installation setup with modular options.
    Windows-native counterpart of ubuntu-setup.sh (https://github.com/enginyilmaaz/ubuntu-setup-script).
.NOTES
    Version : 1.2.1
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
# Version: 1.2.1
# Author: enginyilmaaz
# Description: Automates Windows post-installation setup with modular options
#===============================================================================

$script:SCRIPT_VERSION  = '1.8.3'
$script:SCRIPT_REVISION = '38'
$script:SCRIPT_DATE     = '2026-08-11'

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
    Gh         = $false; Postman = $false; FileZilla = $false; NotepadPP = $false
    ShareX     = $false; Firefox = $false; WhatsApp = $false
    WinRAR     = $false; Spotify = $false; PowerManager = $false; RevoPro = $false
    # AI CLI
    Claude     = $false; Codex = $false; Kimi = $false; Grok = $false
    Gemini     = $false; Qwen = $false; Opencode = $false
    AiCli      = $false
    # remote
    Vnc        = $false; AnyDesk = $false; RustDesk = $false; TeamViewer = $false
    Remote     = $false
    # windows-native groups (were GNOME tweaks / debloat)
    Tweaks     = $false; Debloat = $false; UiTweaks = $false
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
        'notepad++'   { $flags.NotepadPP = $true }
        'notepadpp'   { $flags.NotepadPP = $true }
        'npp'         { $flags.NotepadPP = $true }
        'sharex'      { $flags.ShareX = $true }
        'firefox'     { $flags.Firefox = $true }
        'whatsapp'    { $flags.WhatsApp = $true }
        'winrar'      { $flags.WinRAR = $true }
        'spotify'     { $flags.Spotify = $true }
        'power-manager' { $flags.PowerManager = $true }
        'powermanager'  { $flags.PowerManager = $true }
        'wapm'          { $flags.PowerManager = $true }
        'revo'        { $flags.RevoPro = $true }
        'revopro'     { $flags.RevoPro = $true }
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
        'uitweaks'    { $flags.UiTweaks = $true }
        'ui'          { $flags.UiTweaks = $true }
        'explorer'    { $flags.UiTweaks = $true }
        'regtweaks'   { $flags.UiTweaks = $true }
        'reg-tweaks'  { $flags.UiTweaks = $true }
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
    # NOTE: interactive/GUI installers (Vlc, Firefox, WhatsApp) are left OUT of --all
    # so the unattended run doesn't block on their setup windows; pick them individually.
    foreach ($k in @('NodeJs','Python','Docker','Chrome','VSCode','DBeaver','Cloudflared','Gh','Postman','FileZilla','NotepadPP','ShareX','WinRAR','PowerManager','RevoPro','AiCli','Remote')) {
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
  --glm-opencode    OpenCode preconfigured for z.ai GLM

REMOTE SUPPORT:
  --vnc             RealVNC Connect
  --anydesk         AnyDesk
  --rustdesk        RustDesk
  --teamviewer      TeamViewer

WINDOWS TWEAKS / DEBLOAT:
  --tweaks          Windows desktop tweaks + settings (submenu)
  --uitweaks        Explorer / nav pane / context-menu / registry tweaks (submenu)
                    (aliases: --ui, --explorer, --reg-tweaks; each entry can be
                     applied [x] or reverted [r] from the submenu)
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
# Catalog - the single data model the menu AND the flag dispatcher both read.
# Each record names an Install/Apply function and a Detect function that live in
# the other fragments. Keep the function names here in sync with those fragments.
#===============================================================================

# Top-level dev tools (each toggles an install)
$script:DevTools = @(
    @{ Key='nodejs';      Flag='NodeJs';      Label='Node.js (nvm-windows)';  Install='Install-NodeJs';      Detect='Test-NodeJsInstalled'; Marker='Get-NodeJsMarker' }
    @{ Key='python';      Flag='Python';      Label='Python 3';               Install='Install-Python';      Detect='Test-PythonInstalled' }
    @{ Key='docker';      Flag='Docker';      Label='Docker Desktop';         Install='Install-Docker';      Detect='Test-DockerInstalled' }
    @{ Key='chrome';      Flag='Chrome';      Label='Google Chrome';          Install='Install-Chrome';      Detect='Test-ChromeInstalled' }
    @{ Key='vscode';      Flag='VSCode';      Label='Visual Studio Code';     Install='Install-VSCode';      Detect='Test-VSCodeInstalled'; SubMenu='vscode' }
    @{ Key='dbeaver';     Flag='DBeaver';     Label='DBeaver Community';      Install='Install-DBeaver';     Detect='Test-DBeaverInstalled' }
    @{ Key='vlc';         Flag='Vlc';         Label='VLC Media Player';       Install='Install-Vlc';         Detect='Test-VlcInstalled' }
    @{ Key='notepad++';   Flag='NotepadPP';   Label='Notepad++';              Install='Install-NotepadPP';   Detect='Test-NotepadPPInstalled' }
    @{ Key='sharex';      Flag='ShareX';      Label='ShareX';                 Install='Install-ShareX';      Detect='Test-ShareXInstalled' }
    @{ Key='firefox';     Flag='Firefox';     Label='Firefox (installer GUI)';Install='Install-Firefox';     Detect='Test-FirefoxInstalled' }
    @{ Key='whatsapp';    Flag='WhatsApp';    Label='WhatsApp (Store)';       Install='Install-WhatsApp';    Detect='Test-WhatsAppInstalled' }
    @{ Key='winrar';      Flag='WinRAR';      Label='WinRAR';                 Install='Install-WinRAR';      Detect='Test-WinRARInstalled' }
    @{ Key='spotify';     Flag='Spotify';     Label='Spotify (Store)';        Install='Install-Spotify';     Detect='Test-SpotifyInstalled' }
    @{ Key='power-manager'; Flag='PowerManager'; Label='Windows Auto Power Manager'; Install='Install-PowerManager'; Detect='Test-PowerManagerInstalled' }
    @{ Key='revo';        Flag='RevoPro';     Label='Revo Uninstaller Pro';   Install='Install-RevoPro';     Detect='Test-RevoProInstalled' }
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
    @{ Key='opencode'; Flag='Opencode'; Label='GLM with OpenCode';       Install='Install-GlmOpencode';  Detect='Test-GlmOpencodeInstalled' }
)

# Remote support tools (submenu group)
$script:RemoteTools = @(
    @{ Key='vnc';        Flag='Vnc';        Label='RealVNC Connect'; Install='Install-RealVNC';    Detect='Test-RealVNCInstalled' }
    @{ Key='anydesk';    Flag='AnyDesk';    Label='AnyDesk';         Install='Install-AnyDesk';    Detect='Test-AnyDeskInstalled' }
    @{ Key='rustdesk';   Flag='RustDesk';   Label='RustDesk';        Install='Install-RustDesk';   Detect='Test-RustDeskInstalled' }
    @{ Key='teamviewer'; Flag='TeamViewer'; Label='TeamViewer';      Install='Install-TeamViewer'; Detect='Test-TeamViewerInstalled' }
)

# Windows tweaks (submenu group) - Windows-native equivalents of the GNOME tweaks
$script:WindowsTweaks = @(
    @{ Key='update-system';    Label='Update System (winget upgrade --all)'; Apply='Update-WindowsSystem' }
    @{ Key='script-launcher';  Label='Script Launcher (right-click menu)';   Apply='Set-ScriptLauncherContextMenu' }
    @{ Key='openssh';          Label='OpenSSH Server';                       Apply='Enable-OpenSSHServer' }
    @{ Key='hostname';         Label='Change Hostname';                      Apply='Set-ComputerHostname'; NeedsInput='hostname' }
    @{ Key='screen-never-off'; Label='Screen Off: Never';                    Apply='Disable-ScreenTimeout' }
    @{ Key='show-hidden';      Label='Show Hidden Files + Extensions';       Apply='Show-HiddenFiles' }
    @{ Key='keyboard-tr-q';    Label='Keyboard: Turkish Q';                  Apply='Add-KeyboardTurkishQ' }
    @{ Key='keyboard-en-q';    Label='Keyboard: English Q';                  Apply='Add-KeyboardEnglishQ' }
    @{ Key='english-language'; Label='English Language (en-US)';             Apply='Set-DisplayLanguageEnglish' }
    @{ Key='auto-login';       Label='Auto-Login on boot';                   Apply='Enable-AutoLogin' }
    @{ Key='tray-icons';       Label='Always Show All Tray Icons';           Apply='Set-AlwaysShowTrayIcons' }
    @{ Key='taskbar';          Label='Taskbar Tweaks';                       Apply='Set-TaskbarTweaks' }
    @{ Key='taskbar-left';     Label='Taskbar/Start: align left';            Apply='Set-TaskbarAlignLeft' }
    @{ Key='search-icon';      Label='Taskbar Search: icon only';            Apply='Set-SearchBoxIcon' }
    @{ Key='disable-search';   Label='Disable Windows Search (WSearch service)'; Apply='Disable-WindowsSearchService' }
    @{ Key='disable-updates';  Label='Disable Windows Updates';              Apply='Disable-WindowsUpdates' }
    @{ Key='error-reporting';  Label='Activate Error Reporting';             Apply='Enable-WindowsErrorReporting' }
    @{ Key='enable-restore';   Label='Enable System Restore';                Apply='Enable-SystemRestore' }
    @{ Key='windhawk';         Label='Install Windhawk + taskbar mods (2.0-alpha)'; Apply='Install-Windhawk' }
    @{ Key='camera';           Label='Install Camera App';                   Apply='Install-CameraApp' }
    @{ Key='install-webview2'; Label='Install: Edge WebView2 Runtime';       Apply='Install-EdgeWebView2' }
    @{ Key='install-edge';     Label='Install: Microsoft Edge';              Apply='Install-EdgeBrowser' }
    @{ Key='storage-sense';    Label='Cleanup: Storage Sense';               Apply='Enable-StorageSense' }
    # RealVNC "dot cursor" fix - only shown when RealVNC is installed (ShowIf)
    @{ Key='vnc-cursor';       Label='RealVNC: normal cursor (fix headless dot)'; Apply='Set-RealVncAlwaysShowCursor'; ShowIf='Test-RealVNCInstalled' }
    # Node.js switch tweaks - shown conditionally (ShowIf) based on current state
    @{ Key='switch-node-nvm';    Label='Node.js: switch to NVM';              Apply='Switch-NodeToNvm';    ShowIf='Test-NodeIsNonNvm' }
    @{ Key='switch-node-native'; Label='Node.js: switch to native (non-NVM)'; Apply='Switch-NodeToNative'; ShowIf='Test-NvmInstalled' }
)

# Explorer / UI tweaks (own submenu group) - the .reg + .cmd collection, ported to
# native registry/service calls. Every entry is a TWO-WAY toggle: Apply does the
# thing, Revert undoes it. Revert=$null marks a one-shot action (nothing to undo).
$script:UiTweaks = @(
    @{ Key='thispc-folders';     Label='This PC: remove the 6 user folders';           Apply='Remove-ThisPcUserFolders';     Revert='Restore-ThisPcUserFolders' }
    @{ Key='thispc-3d';          Label='This PC: remove 3D Objects';                   Apply='Remove-3DObjectsFolder';       Revert='Restore-3DObjectsFolder' }
    @{ Key='nav-network';        Label='Nav pane: remove Network';                     Apply='Remove-NavPaneNetwork';        Revert='Restore-NavPaneNetwork' }
    @{ Key='nav-homegroup';      Label='Nav pane: remove HomeGroup';                   Apply='Remove-NavPaneHomeGroup';      Revert='Restore-NavPaneHomeGroup' }
    @{ Key='nav-drives';         Label='Nav pane: remove duplicate removable drives';  Apply='Remove-NavPaneDrives';         Revert='Restore-NavPaneDrives' }
    @{ Key='nav-gallery';        Label='Nav pane: remove Gallery (Win11)';             Apply='Remove-NavPaneGallery';        Revert='Restore-NavPaneGallery' }
    @{ Key='nav-home';           Label='Nav pane: remove Home (Win11)';                Apply='Remove-NavPaneHome';           Revert='Restore-NavPaneHome' }
    @{ Key='quick-access';       Label='Quick Access: hide frequent folders';          Apply='Hide-QuickAccessFrequent';     Revert='Show-QuickAccessFrequent' }
    @{ Key='classic-context';    Label='Win11: classic (full) right-click menu';       Apply='Enable-ClassicContextMenu';    Revert='Disable-ClassicContextMenu' }
    @{ Key='ctx-share';          Label="Context menu: remove 'Share with'";            Apply='Remove-ShareContextMenu';      Revert='Restore-ShareContextMenu' }
    @{ Key='ctx-sharing-tab';    Label='Properties: remove the Sharing tab';           Apply='Remove-SharingPropertyTab';    Revert='Restore-SharingPropertyTab' }
    @{ Key='ctx-prev-versions';  Label="Remove 'Previous Versions' (menu + tab)";      Apply='Remove-PreviousVersions';      Revert='Restore-PreviousVersions' }
    @{ Key='action-center';      Label='Disable Action Center / notifications';        Apply='Disable-ActionCenter';         Revert='Enable-ActionCenter' }
    @{ Key='lock-screen';        Label='Disable the lock screen';                      Apply='Disable-LockScreen';           Revert='Enable-LockScreen' }
    @{ Key='search-suggestions'; Label='Disable search box web suggestions';           Apply='Disable-SearchBoxSuggestions'; Revert='Enable-SearchBoxSuggestions' }
    @{ Key='numlock';            Label='NumLock on at boot';                           Apply='Enable-NumLockAtBoot';         Revert='Disable-NumLockAtBoot' }
    @{ Key='superfetch';         Label='Disable Superfetch (SysMain) + Prefetch';      Apply='Disable-SuperfetchPrefetch';   Revert='Enable-SuperfetchPrefetch' }
    @{ Key='photo-viewer';       Label='Restore the classic Windows Photo Viewer';     Apply='Restore-WindowsPhotoViewer';   Revert='Remove-WindowsPhotoViewer' }
    @{ Key='icon-cache';         Label='Rebuild the icon cache (one-shot)';            Apply='Reset-IconCache';              Revert=$null }
    @{ Key='dns-flush';          Label='Flush DNS + renew the IP lease (one-shot)';    Apply='Clear-DnsCache';               Revert=$null }
)

# CLI aliases (own submenu group). cckimi/ccglm auto-bundle their *-token setter.
$script:CliAliases = @(
    @{ Key='ccskip'; Label='ccskip  (Claude skip-permissions, Opus 4.8)' }
    @{ Key='cxskip'; Label='cxskip  (Claude skip-permissions, Opus 5)' }
    @{ Key='cckimi'; Label='cckimi  (Claude Code on the Kimi backend)  [+ cckimi-token]' }
    @{ Key='ccglm';  Label='ccglm   (Claude Code on the Z.AI GLM backend)  [+ ccglm-token]' }
)

# VS Code extensions (VS Code submenu) - IDs mirror the source install_vscode_extensions
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
    param([switch]$Force)
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
        -WingetId 'CoreyButler.NVMforWindows' -ChocoId 'nvm' -ForceReinstall:$Force `
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
# Node.js: NVM (nvm-windows) vs native (non-NVM) detection + switching
#===============================================================================

# Is nvm-windows present? (command, NVM_HOME, or the known install locations)
function Test-NvmInstalled {
    if (Test-Command 'nvm') { return $true }
    $cands = @()
    if ($env:NVM_HOME)     { $cands += (Join-Path $env:NVM_HOME 'nvm.exe') }
    if ($env:APPDATA)      { $cands += (Join-Path $env:APPDATA 'nvm\nvm.exe') }
    if ($env:ProgramFiles) { $cands += (Join-Path $env:ProgramFiles 'nvm\nvm.exe') }
    foreach ($p in $cands) { if (Test-Path -LiteralPath $p) { return $true } }
    return $false
}

# Is Node.js present at all? (command or a registered native install)
function Test-NodePresent {
    if (Test-Command 'node') { return $true }
    return (Test-App -DisplayNameLike '*Node.js*')
}

# Node exists but is NOT managed by nvm (native / non-nvm) -> tweak ShowIf.
function Test-NodeIsNonNvm {
    return ((Test-NodePresent) -and -not (Test-NvmInstalled))
}

# Menu marker for the NodeJS row: '' / 'installed (nvm)' / 'installed (non-nvm)'.
function Get-NodeJsMarker {
    if (Test-NvmInstalled) { return 'installed (nvm)' }
    if (Test-NodePresent)  { return 'installed (non-nvm)' }
    return ''
}

# Uninstall a native (non-nvm) Node.js: winget ids + MSI fallback.
function Uninstall-NativeNode {
    Write-LogInfo "Removing native Node.js..."
    if (Test-Winget) {
        winget uninstall --id 'OpenJS.NodeJS'     -e --silent --accept-source-agreements 2>$null
        winget uninstall --id 'OpenJS.NodeJS.LTS' -e --silent --accept-source-agreements 2>$null
    }
    foreach ($k in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
        Get-ItemProperty $k -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like 'Node.js*' -and $_.UninstallString } |
            ForEach-Object {
                if ($_.UninstallString -match 'msiexec' -and $_.PSChildName -match '^\{.*\}$') {
                    Start-Process 'msiexec.exe' -ArgumentList "/x $($_.PSChildName) /qn /norestart" -Wait -ErrorAction SilentlyContinue
                }
            }
    }
    Write-LogSuccess "Native Node.js removal attempted."
}

# Uninstall nvm-windows (also removes the nvm-managed node versions).
function Uninstall-Nvm {
    Write-LogInfo "Removing nvm-windows..."
    if (Test-Winget) { winget uninstall --id 'CoreyButler.NVMforWindows' -e --silent --accept-source-agreements 2>$null }
    foreach ($k in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
        Get-ItemProperty $k -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like '*NVM for Windows*' -and $_.UninstallString } |
            ForEach-Object {
                $exe = ($_.UninstallString -replace '"', '')
                if ($exe -and (Test-Path -LiteralPath $exe)) {
                    Start-Process $exe -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait -ErrorAction SilentlyContinue
                }
            }
    }
    Write-LogSuccess "nvm-windows removal attempted."
}

# Install a native (non-nvm) Node.js LTS (no -Detect => always installs).
function Install-NativeNode {
    return Install-App -Name 'Node.js (native LTS)' `
        -WingetId 'OpenJS.NodeJS.LTS' -ChocoId 'nodejs-lts' `
        -PostInstall { Write-LogWarning "Open a NEW terminal so the native 'node' is on PATH." }
}

# Switch native (non-nvm) Node.js -> nvm-managed: remove native, install nvm + node 22.
function Switch-NodeToNvm {
    Write-LogStep "Switching Node.js to NVM"
    if (Test-NvmInstalled) { Write-LogInfo "nvm-windows is already installed; nothing to switch."; return $true }
    Uninstall-NativeNode
    Install-NodeJs -Force | Out-Null
    Write-LogSuccess "Switched Node.js to nvm-windows (open a new terminal)."
    return $true
}

# Switch nvm-managed Node.js -> native (non-nvm): remove nvm, install native LTS.
function Switch-NodeToNative {
    Write-LogStep "Switching Node.js to native (non-NVM)"
    if (-not (Test-NvmInstalled)) { Write-LogInfo "nvm-windows is not installed; nothing to switch."; return $true }
    Uninstall-Nvm
    Install-NativeNode | Out-Null
    Write-LogSuccess "Switched Node.js to a native install (open a new terminal)."
    return $true
}

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
# Interactive winget install - opens the app's own setup window and waits for it.
# Used for apps the user wants to click through (kept out of --all).
function Install-WingetInteractive {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Id, [string]$Source, [scriptblock]$Detect)
    Write-LogInfo "$Name : opening the installer window - finish it there..."
    if (-not (Test-Command 'winget')) { Write-LogWarning "winget is not available for $Name."; return $false }
    if ($Source) { winget install --id $Id -e --source $Source --interactive --accept-source-agreements --accept-package-agreements 2>$null }
    else         { winget install --id $Id -e --interactive --accept-source-agreements --accept-package-agreements 2>$null }
    if (& $Detect) { Write-LogSuccess "$Name installed."; return $true }
    Write-LogWarning "$Name install not detected (the installer may have been cancelled)."
    return $false
}
function Install-Vlc { Install-WingetInteractive -Name 'VLC Media Player' -Id 'VideoLAN.VLC' -Detect { Test-VlcInstalled } }
function Test-VlcInstalled { Test-App -Command 'vlc' -DisplayNameLike '*VLC media player*' }

function Install-NotepadPP {
    return Install-App -Name 'Notepad++' `
        -Detect { Test-App -DisplayNameLike '*Notepad++*' } `
        -WingetId 'Notepad++.Notepad++' -ChocoId 'notepadplusplus'
}
function Test-NotepadPPInstalled { Test-App -DisplayNameLike '*Notepad++*' }

function Install-ShareX {
    return Install-App -Name 'ShareX' `
        -Detect { Test-App -DisplayNameLike '*ShareX*' } `
        -WingetId 'ShareX.ShareX' -ChocoId 'sharex'
}
function Test-ShareXInstalled { Test-App -DisplayNameLike '*ShareX*' }

function Install-Firefox { Install-WingetInteractive -Name 'Mozilla Firefox' -Id 'Mozilla.Firefox' -Detect { Test-FirefoxInstalled } }
function Test-FirefoxInstalled { Test-App -DisplayNameLike '*Mozilla Firefox*' }

function Install-WhatsApp { Install-WingetInteractive -Name 'WhatsApp' -Id '9NKSQGP7F2NH' -Source 'msstore' -Detect { Test-WhatsAppInstalled } }
function Test-WhatsAppInstalled { [bool](Get-AppxPackage -Name '*WhatsApp*' -ErrorAction SilentlyContinue) }

function Install-WinRAR {
    return Install-App -Name 'WinRAR' `
        -Detect { Test-App -DisplayNameLike '*WinRAR*' } `
        -WingetId 'RARLab.WinRAR' -ChocoId 'winrar'
}
function Test-WinRARInstalled { Test-App -DisplayNameLike '*WinRAR*' }

function Install-Spotify { Install-WingetInteractive -Name 'Spotify' -Id '9NCBCSZSJRSB' -Source 'msstore' -Detect { Test-SpotifyInstalled } }
function Test-SpotifyInstalled { [bool](Get-AppxPackage -Name '*Spotify*' -ErrorAction SilentlyContinue) -or (Test-App -DisplayNameLike '*Spotify*') }

# Windows Auto Power Manager (the user's own tool) - install the latest GitHub
# release .exe silently. Asset is picked by extension so new releases keep working.
function Install-PowerManager {
    return Install-App -Name 'Windows Auto Power Manager' `
        -Detect { Test-PowerManagerInstalled } `
        -Direct {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
            $rel = Invoke-RestMethod 'https://api.github.com/repos/enginyilmaaz/windows-auto-power-manager/releases/latest' -Headers @{ 'User-Agent' = 'windows-setup' }
            $asset = $rel.assets | Where-Object { $_.name -like '*.exe' } | Select-Object -First 1
            if (-not $asset) { throw 'no .exe asset in the latest release' }
            $f = Get-FileDownload -Url $asset.browser_download_url
            if (-not $f) { throw 'download failed' }
            # Inno Setup silent switches (the installer is a *_Setup_*.exe).
            Start-Process -FilePath $f -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-' -Wait
        }
}
function Test-PowerManagerInstalled { Test-App -DisplayNameLike '*Auto Power Manager*' }

function Install-RevoPro {
    return Install-App -Name 'Revo Uninstaller Pro' `
        -Detect { Test-App -DisplayNameLike '*Revo Uninstaller*' } `
        -WingetId 'RevoUninstaller.RevoUninstallerPro' -ChocoId 'revouninstaller'
}
function Test-RevoProInstalled { Test-App -DisplayNameLike '*Revo Uninstaller*' }

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
# RealVNC rebranded "VNC Server" -> "RealVNC Connect" (registry DisplayName is now
# e.g. "RealVNC Connect 8.4.1"), so a single '*VNC Server*' match misses current
# installs. Match both eras by DisplayName, plus the winget id and the inbound
# service (rvncserver) as fallbacks.
function Test-RealVNCInstalled {
    if (Test-App -DisplayNameLike '*RealVNC*' -WingetId 'RealVNC.VNCServer') { return $true }
    foreach ($n in (Get-InstalledDisplayNames)) {
        if ($n -like '*VNC Server*' -or $n -like '*VNC Connect*') { return $true }
    }
    if (Get-Service -Name 'rvncserver' -ErrorAction SilentlyContinue) { return $true }
    return $false
}

function Install-RealVNC {
    return Install-App -Name 'RealVNC Connect (Server)' `
        -Detect { Test-RealVNCInstalled } `
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
# Windows-native counterpart of the Ubuntu script's 20 GNOME tweaks (sec. 4.4) plus
# the backup/restore flow (sec. 4.6). Only function definitions live here; the shared
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
    'HKLM\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName',  # hostname
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Search',            # taskbar search box mode
    'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate',           # disable updates policy
    # --- Explorer / UI tweaks (the ported .reg pack) --------------------------
    # Only the exact keys these tweaks touch: HKCU\Software\Classes\CLSID as a
    # whole is far too large to export on every run.
    'HKCU\Software\Classes\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}',   # nav pane: Network
    'HKCU\Software\Classes\CLSID\{B4FB3F98-C1EA-428d-A78A-D1F5659CBA93}',   # nav pane: HomeGroup
    'HKCU\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}',   # nav pane: Gallery (Win11)
    'HKCU\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}',   # nav pane: Home (Win11)
    'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}',   # Win11 classic context menu
    'HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer',                    # action center + search suggestions (user)
    'HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer',                    # action center (machine)
    'HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization',             # lock screen
    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace',              # This PC folders / 3D Objects
    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders', # nav pane: removable drives
    'HKLM\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations',                # classic Photo Viewer
    'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters',# prefetch
    'HKU\.DEFAULT\Control Panel\Keyboard'                               # NumLock at the logon screen
)

#===============================================================================
# BACKUP / RESTORE (sec. 4.6) - System Restore point + registry export
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

# Both tweak groups back up before touching anything; run it at most once per
# session so a combined run does not create two restore points.
$script:TweakBackupDone = $false
function Save-TweakBackupOnce {
    if ($script:TweakBackupDone) { return }
    $script:TweakBackupDone = $true
    Save-TweakBackup | Out-Null
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
# TWEAK APPLY FUNCTIONS (sec. 4.4) - each = one row of the mapping table
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

# Is a given alias currently installed? (its .cmd exists in the aliases folder)
function Test-AliasInstalled {
    param([string]$Key)
    if (-not $env:USERPROFILE) { return $false }
    return (Test-Path -LiteralPath (Join-Path (Join-Path $env:USERPROFILE 'apps\aliases') "$Key.cmd"))
}

# Remove EVERY copy of an alias command: the in-session function/alias, plus files named
# <name> or <name>.cmd/.bat/.ps1 in ANY PATH directory (also ~/.local/bin & apps\aliases).
# It never touches .exe, so real binaries (e.g. the 'claude' executable) are safe.
function Remove-AliasEverywhere {
    param([string]$Name)
    Remove-Item -LiteralPath ('function:\' + $Name) -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath ('alias:\' + $Name) -Force -ErrorAction SilentlyContinue
    $dirs = New-Object System.Collections.Generic.List[string]
    foreach ($d in ([string]$env:Path -split ';')) { if ($d) { [void]$dirs.Add($d) } }
    if ($env:USERPROFILE) {
        [void]$dirs.Add((Join-Path $env:USERPROFILE '.local\bin'))
        [void]$dirs.Add((Join-Path $env:USERPROFILE 'apps\aliases'))
    }
    $seen = @{}
    foreach ($d in $dirs) {
        $key = ($d.TrimEnd('\')).ToLower()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        foreach ($ext in @('', '.cmd', '.bat', '.ps1')) {
            $p = Join-Path $d ($Name + $ext)
            if (Test-Path -LiteralPath $p -PathType Leaf) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
        }
    }
}

# CLI Aliases: install ccskip / cxskip / cckimi / ccglm (Claude/Codex helpers) plus
# cckimi-token / ccglm-token as standalone .cmd commands under %USERPROFILE%\apps\aliases
# and add that folder to PATH, so they work from ANY shell (cmd, PowerShell, Run). Pure
# batch, one self-contained .cmd each - no .ps1. Env vars are scoped via setlocal to that
# cmd process, so they don't leak into the caller. Mirrors setup_cli_shortcuts.
function Set-CliAliases {
    $aliasDir = Join-Path $env:USERPROFILE 'apps\aliases'
    Write-LogInfo "Installing CLI alias .cmd commands into $aliasDir and adding it to PATH..."
    try {
        New-Item -ItemType Directory -Path $aliasDir -Force | Out-Null

        # Migration: drop the old PS-profile smai-aliases block if a previous version wrote it.
        $profilePath = $PROFILE.CurrentUserAllHosts
        if ($profilePath -and (Test-Path -LiteralPath $profilePath)) {
            $raw = Get-Content -LiteralPath $profilePath -Raw -ErrorAction SilentlyContinue
            if ($raw -and $raw -match '# BEGIN smai-aliases') {
                $clean = [regex]::Replace($raw, '(?ms)^# BEGIN smai-aliases.*?^# END smai-aliases\r?\n?', '')
                Set-Content -LiteralPath $profilePath -Value $clean.TrimEnd() -Encoding UTF8
            }
        }

        $cmds = [ordered]@{}
        $cmds['ccskip'] = @'
@echo off
call claude --dangerously-skip-permissions --effort max --model claude-opus-4-8 %*
'@
        $cmds['cxskip'] = @'
@echo off
call claude --dangerously-skip-permissions --effort max --model claude-opus-5 %*
'@
        $cmds['cckimi'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.kimi_token"
set "token="
if exist "%TOKENFILE%" set /p token=<"%TOKENFILE%"
if not "%token%"=="" goto :run
set /p token=cckimi: no API key found. Enter your Kimi API key:
if "%token%"=="" (
    echo cckimi: no key entered, aborting.
    exit /b 1
)
>"%TOKENFILE%" echo %token%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo cckimi: key saved to %TOKENFILE% (current-user only).
:run
set "ANTHROPIC_BASE_URL=https://api.kimi.com/coding/"
set "ANTHROPIC_AUTH_TOKEN=%token%"
set "ANTHROPIC_MODEL=kimi-k3[1m]"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=kimi-k3[1m]"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=kimi-k2.7-code"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=kimi-k2.7-code"
set "ANTHROPIC_DEFAULT_FABLE_MODEL=kimi-k2.7-code-highspeed"
set "CLAUDE_CODE_SUBAGENT_MODEL=kimi-k3[1m]"
set "ENABLE_TOOL_SEARCH=false"
set "CLAUDE_CODE_AUTO_COMPACT_WINDOW=1048576"
set "CLAUDE_CODE_EFFORT_LEVEL=max"
call claude --dangerously-skip-permissions --effort max %*
'@
        $cmds['ccglm'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.zai_token"
set "token="
if exist "%TOKENFILE%" set /p token=<"%TOKENFILE%"
if not "%token%"=="" goto :run
set /p token=ccglm: no API key found. Enter your Z.AI API key:
if "%token%"=="" (
    echo ccglm: no key entered, aborting.
    exit /b 1
)
>"%TOKENFILE%" echo %token%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo ccglm: key saved to %TOKENFILE% (current-user only).
:run
set "ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic"
set "ANTHROPIC_AUTH_TOKEN=%token%"
set "ANTHROPIC_MODEL=glm-5.2[1m]"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5.2[1m]"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=glm-4.6"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air"
set "ANTHROPIC_DEFAULT_FABLE_MODEL=glm-4.7-flashx"
set "CLAUDE_CODE_SUBAGENT_MODEL=glm-5.2[1m]"
set "CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000"
set "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
set "API_TIMEOUT_MS=3000000"
call claude --dangerously-skip-permissions %*
'@
        $cmds['cckimi-token'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.kimi_token"
set "key=%~1"
if "%key%"=="" set /p key=cckimi-token - paste API key:
if "%key%"=="" (
    echo cckimi-token: no key given.
    exit /b 1
)
>"%TOKENFILE%" echo %key%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo cckimi-token: key written to %TOKENFILE% (current-user only).
'@
        $cmds['ccglm-token'] = @'
@echo off
setlocal
set "TOKENFILE=%USERPROFILE%\.zai_token"
set "key=%~1"
if "%key%"=="" set /p key=ccglm-token - paste API key:
if "%key%"=="" (
    echo ccglm-token: no key given.
    exit /b 1
)
>"%TOKENFILE%" echo %key%
icacls "%TOKENFILE%" /inheritance:r /grant:r "%USERNAME%:(R,W)" >nul 2>&1
echo ccglm-token: key written to %TOKENFILE% (current-user only).
'@

        # Build the install set from the SELECTED aliases; auto-bundle the *-token setters.
        $sel = @($script:SelectedAliases)
        $install = @{}
        foreach ($k in $sel) { if ($cmds.Contains($k)) { $install[$k] = $true } }
        if ($install['cckimi']) { $install['cckimi-token'] = $true }   # cckimi -> also cckimi-token
        if ($install['ccglm'])  { $install['ccglm-token']  = $true }   # ccglm  -> also ccglm-token

        # If any selected alias is already installed, ask once before overwriting them.
        $already = @($cmds.Keys | Where-Object { $install[$_] -and (Test-AliasInstalled $_) })
        $overwrite = $true
        if ($already.Count -gt 0) {
            Set-MenuCursorVisible $true
            Write-Host ""
            $ans = Read-Host ("These aliases are already installed: {0}. Overwrite? (y/n)" -f ($already -join ', '))
            $overwrite = ($ans -match '^[Yy]')
            if (-not $overwrite) { Write-LogInfo "Keeping the existing copies of: $($already -join ', ')" }
        }

        # Remove discontinued aliases everywhere (all PATH dirs incl. ~/.local/bin + session).
        foreach ($n in @('claude-skip', 'codex-skip')) { Remove-AliasEverywhere $n }
        # Install-action model: only the SELECTED aliases are (re)installed. Non-selected ones
        # are left untouched (checking installs; the marker just shows what's already installed).
        foreach ($name in $cmds.Keys) {
            if (-not $install[$name]) { continue }
            # Already installed + user declined overwrite -> keep the existing copy.
            if (-not $overwrite -and (Test-AliasInstalled $name)) { continue }
            Remove-AliasEverywhere $name   # clean any straggler copies (incl ~/.local/bin) first
            # Write fresh (CRLF + ASCII, no BOM) so cmd.exe handles labels/goto correctly.
            $body = ($cmds[$name] -replace "`r`n", "`n") -replace "`n", "`r`n"
            if (-not $body.EndsWith("`r`n")) { $body += "`r`n" }
            [System.IO.File]::WriteAllText((Join-Path $aliasDir "$name.cmd"), $body, [System.Text.Encoding]::ASCII)
        }

        # Add the aliases folder to the User PATH (persisted) + the current session.
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User'); if (-not $userPath) { $userPath = '' }
        if (($userPath -split ';') -notcontains $aliasDir) {
            $trimmed = $userPath.TrimEnd(';')
            $newPath = if ($trimmed) { $trimmed + ';' + $aliasDir } else { $aliasDir }
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        }
        $cur = [string]$env:Path
        if (($cur -split ';') -notcontains $aliasDir) { $env:Path = ($cur.TrimEnd(';') + ';' + $aliasDir).TrimStart(';') }

        $installed = @($cmds.Keys | Where-Object { $install[$_] })
        Write-LogSuccess ("CLI aliases (.cmd) installed to $aliasDir and added to PATH: {0} (open a new terminal to use them)." -f ($installed -join ', '))
        return $true
    } catch {
        Write-LogWarning "Could not install CLI aliases: $($_.Exception.Message)"
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

# Taskbar/Start: align left only (TaskbarAl=0). Focused single-purpose tweak
# (the combined Set-TaskbarTweaks also changes grouping/size).
function Set-TaskbarAlignLeft {
    Write-LogInfo "Aligning the taskbar and Start button to the left..."
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    try {
        if (-not (Test-Path -LiteralPath $adv)) { New-Item -Path $adv -Force | Out-Null }
        New-ItemProperty -LiteralPath $adv -Name 'TaskbarAl' -Value 0 -PropertyType DWord -Force | Out-Null  # 0=left, 1=centre
        $p = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($p) { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }
        Write-LogSuccess "Taskbar/Start aligned left (Explorer restarted)."
        return $true
    } catch {
        Write-LogWarning "Could not align the taskbar left: $($_.Exception.Message)"
        return $false
    }
}

# Taskbar Search: show as a small icon only (SearchboxTaskbarMode: 0=hidden,
# 1=icon, 2=box, 3=box+label).
function Set-SearchBoxIcon {
    Write-LogInfo "Setting the taskbar search to icon-only..."
    $sk = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
    try {
        if (-not (Test-Path -LiteralPath $sk)) { New-Item -Path $sk -Force | Out-Null }
        New-ItemProperty -LiteralPath $sk -Name 'SearchboxTaskbarMode' -Value 1 -PropertyType DWord -Force | Out-Null
        $p = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($p) { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }
        Write-LogSuccess "Taskbar search set to icon-only (Explorer restarted)."
        return $true
    } catch {
        Write-LogWarning "Could not change the search box mode: $($_.Exception.Message)"
        return $false
    }
}

# Disable Windows Search: stop + disable the WSearch indexer service. Start-menu
# search still works, but content indexing (and its disk/CPU use) stops.
function Disable-WindowsSearchService {
    Write-LogInfo "Disabling the Windows Search (WSearch) indexer service..."
    try {
        $s = Get-Service -Name 'WSearch' -ErrorAction SilentlyContinue
        if (-not $s) { Write-LogInfo "The WSearch service is not present on this system."; return $true }
        if ($s.Status -eq 'Running') { Stop-Service -Name 'WSearch' -Force -ErrorAction SilentlyContinue }
        Set-Service -Name 'WSearch' -StartupType Disabled -ErrorAction SilentlyContinue
        Write-LogSuccess "Windows Search indexing disabled. Re-enable later with: sc config WSearch start=delayed-auto"
        return $true
    } catch {
        Write-LogWarning "Could not disable Windows Search: $($_.Exception.Message)"
        return $false
    }
}

# Disable Windows Updates: set the NoAutoUpdate policy and stop+disable the
# update services. SECURITY: this halts security patches - re-enable periodically.
function Disable-WindowsUpdates {
    Write-LogWarning "Disabling Windows Update stops SECURITY patches - re-enable it periodically to stay protected."
    Write-LogInfo "Disabling Windows automatic updates (policy + services)..."
    try {
        $au = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
        if (-not (Test-Path -LiteralPath $au)) { New-Item -Path $au -Force | Out-Null }
        New-ItemProperty -LiteralPath $au -Name 'NoAutoUpdate' -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -LiteralPath $au -Name 'AUOptions'    -Value 1 -PropertyType DWord -Force | Out-Null  # 1 = never check
        foreach ($svc in @('wuauserv', 'UsoSvc')) {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s) {
                if ($s.Status -eq 'Running') { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue }
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            }
        }
        Write-LogSuccess "Windows automatic updates disabled. Re-enable with: sc config wuauserv start=demand (+ remove the NoAutoUpdate policy)."
        return $true
    } catch {
        Write-LogWarning "Could not fully disable Windows Update: $($_.Exception.Message)"
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

# Install the Edge WebView2 Runtime (winget). Lets you put WebView2 back if a
# debloat pass removed it - many apps (Teams, widgets, installers) need it.
function Install-EdgeWebView2 {
    Write-LogInfo "Installing the Microsoft Edge WebView2 Runtime..."
    if (Test-Command 'winget') {
        $ok = Invoke-WithRetry -Description 'Edge WebView2 Runtime (winget)' -Action {
            winget install --id Microsoft.EdgeWebView2Runtime -e --silent --accept-package-agreements --accept-source-agreements
        }
        if ($ok) { Write-LogSuccess "Edge WebView2 Runtime installed."; return $true }
    }
    Write-LogWarning "Could not install the WebView2 Runtime via winget."
    return $false
}

# (Re)install the Microsoft Edge browser (winget). Counterpart to the Edge
# debloat item, for when you want it back.
function Install-EdgeBrowser {
    Write-LogInfo "Installing Microsoft Edge..."
    if (Test-Command 'winget') {
        $ok = Invoke-WithRetry -Description 'Microsoft Edge (winget)' -Action {
            winget install --id Microsoft.Edge -e --silent --accept-package-agreements --accept-source-agreements
        }
        if ($ok) { Write-LogSuccess "Microsoft Edge installed."; return $true }
    }
    Write-LogWarning "Could not install Microsoft Edge via winget."
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

# Install Windhawk + three taskbar mods. Uses the latest GitHub release (2.0+),
# which ships windhawk-cli.exe - the winget build (1.7.x stable) has no CLI, so we
# can't drive mods from it. The script is already elevated, so the CLI calls need
# no extra UAC. taskbar-grouping is installed with its defaults (leave groups to
# configure in the UI); start-menu-size and taskbar-volume-control get preset.
function Install-Windhawk {
    $cli = 'C:\Program Files\Windhawk\windhawk-cli.exe'
    if (-not (Test-Path $cli)) {
        Write-LogInfo "Installing Windhawk (latest release with the CLI)..."
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
            $rel = Invoke-RestMethod 'https://api.github.com/repos/ramensoftware/windhawk/releases?per_page=1' -Headers @{ 'User-Agent' = 'windows-setup' }
            $asset = $rel[0].assets | Where-Object { $_.name -eq 'windhawk_setup.exe' } | Select-Object -First 1
            if (-not $asset) { throw 'setup asset not found' }
            $f = Get-FileDownload -Url $asset.browser_download_url
            if (-not $f) { throw 'download failed' }
            Write-LogInfo "  Installing $($rel[0].tag_name) silently (also fetches its compiler; give it a minute)..."
            Start-Process -FilePath $f -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/FORCECLOSEAPPLICATIONS' -Wait
        } catch {
            Write-LogWarning "Could not install Windhawk: $($_.Exception.Message)"
            return $false
        }
    }
    for ($i = 0; $i -lt 30 -and -not (Test-Path $cli); $i++) { Start-Sleep -Seconds 2 }
    if (-not (Test-Path $cli)) { Write-LogWarning "Windhawk installed but windhawk-cli.exe not found (needs a 2.0+ release)."; return $false }

    Write-LogInfo "  Installing taskbar mods (each compiles locally; please wait)..."
    foreach ($m in 'taskbar-grouping', 'start-menu-size', 'taskbar-volume-control') {
        & $cli mod install $m --quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-LogInfo "  installed: $m" } else { Write-LogWarning "  mod install '$m' failed (exit $LASTEXITCODE)" }
    }
    & $cli mod settings set start-menu-size width=750 height=750 searchWidth=0 searchHeight=0 2>&1 | Out-Null
    & $cli mod settings set taskbar-volume-control volumeIndicator=modern scrollArea=taskbar middleClickToMute=0 ctrlScrollVolumeChange=0 noAutomaticMuteToggle=0 volumeChangeStep=2 oldTaskbarOnWin11=0 2>&1 | Out-Null
    Write-LogSuccess "Windhawk + taskbar mods installed (taskbar-grouping left at defaults)."
    return $true
}

# Enable System Restore (system protection) on the system drive, clear any policy
# that disabled it, and cap the shadow storage at 10GB.
function Enable-SystemRestore {
    Write-LogInfo "Enabling System Restore (system protection) on $env:SystemDrive..."
    try {
        $pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore'
        if (Test-Path $pol) {
            Remove-ItemProperty -LiteralPath $pol -Name 'DisableSR'     -ErrorAction SilentlyContinue
            Remove-ItemProperty -LiteralPath $pol -Name 'DisableConfig' -ErrorAction SilentlyContinue
        }
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        & vssadmin.exe resize shadowstorage /for=$env:SystemDrive /on=$env:SystemDrive /maxsize=10GB > $null 2>&1
        Write-LogSuccess "System Restore enabled on $env:SystemDrive (shadow storage capped at 10GB)."
        return $true
    } catch {
        Write-LogWarning "Could not enable System Restore: $($_.Exception.Message)"
        return $false
    }
}

# Disable System Restore AND delete every restore point / shadow copy (used by the
# debloat item). Irreversible - the deleted restore points cannot be recovered.
function Disable-SystemRestoreAndPurge {
    Write-LogWarning "Disabling System Restore and DELETING all restore points / shadow copies (irreversible)."
    try {
        Disable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        & vssadmin.exe delete shadows /all /quiet > $null 2>&1
        $pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore'
        if (-not (Test-Path $pol)) { New-Item -Path $pol -Force | Out-Null }
        New-ItemProperty -LiteralPath $pol -Name 'DisableSR'     -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -LiteralPath $pol -Name 'DisableConfig' -Value 1 -PropertyType DWord -Force | Out-Null
        Write-LogSuccess "System Restore disabled; all restore points deleted."
        return $true
    } catch {
        Write-LogWarning "Could not fully disable/purge System Restore: $($_.Exception.Message)"
        return $false
    }
}

# Is System Restore disabled? (drives the debloat 'removed' marker.)
function Test-SystemRestoreDisabled {
    try {
        $pol = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore' -Name 'DisableSR' -ErrorAction SilentlyContinue).DisableSR
        if ($pol -eq 1) { return $true }
        $v = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'RPSessionInterval' -ErrorAction SilentlyContinue).RPSessionInterval
        return ($v -ne 1)
    } catch { return $false }
}

# RealVNC "dot cursor" fix. On a headless host (no physical mouse/monitor) Windows
# collapses the pointer to a small dot, which is what RealVNC then streams. Setting
# RealVNC Server's AlwaysShowCursor parameter makes it render the normal arrow
# regardless. This is the vendor-documented fix - no virtual mouse / HID driver
# needed. The parameter lives under HKLM\SOFTWARE\RealVNC\vncserver (service mode).
$script:REALVNC_CFG_KEY = 'HKLM:\SOFTWARE\RealVNC\vncserver'

function Set-RealVncAlwaysShowCursor {
    Write-LogInfo "RealVNC: enabling AlwaysShowCursor (replaces the headless 'dot' with the normal cursor)..."
    Write-LogWarning "The RealVNC service is restarted to apply this - your current VNC session may blink/drop for a second and then reconnect."
    try {
        if (-not (Test-Path -LiteralPath $script:REALVNC_CFG_KEY)) { New-Item -Path $script:REALVNC_CFG_KEY -Force | Out-Null }
        New-ItemProperty -LiteralPath $script:REALVNC_CFG_KEY -Name 'AlwaysShowCursor' -Value 1 -PropertyType DWord -Force | Out-Null
        $svc = Get-Service -Name 'rvncserver' -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') {
            Restart-Service -Name 'rvncserver' -Force -ErrorAction SilentlyContinue
            Write-LogInfo "  RealVNC Connect service restarted."
        }
        Write-LogSuccess "RealVNC will now show the normal cursor. Reconnect the viewer if the dot is still cached."
        return $true
    } catch {
        Write-LogWarning "Could not set AlwaysShowCursor: $($_.Exception.Message)"
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
            'taskbar-left' {
                $v = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -ErrorAction SilentlyContinue).TaskbarAl
                return ($v -eq 0)
            }
            'search-icon' {
                $v = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -ErrorAction SilentlyContinue).SearchboxTaskbarMode
                return ($v -eq 1)
            }
            'disable-search' {
                $s = Get-Service -Name 'WSearch' -ErrorAction SilentlyContinue
                return ($null -ne $s -and $s.StartType -eq 'Disabled')
            }
            'disable-updates' {
                $v = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -ErrorAction SilentlyContinue).NoAutoUpdate
                return ($v -eq 1)
            }
            'error-reporting' {
                $v = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -ErrorAction SilentlyContinue).Disabled
                return ($v -eq 0)
            }
            'enable-restore' {
                $pol = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore' -Name 'DisableSR' -ErrorAction SilentlyContinue).DisableSR
                if ($pol -eq 1) { return $false }
                $v = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'RPSessionInterval' -ErrorAction SilentlyContinue).RPSessionInterval
                return ($v -eq 1)
            }
            'windhawk' {
                return (Test-App -Command 'windhawk' -DisplayNameLike '*Windhawk*')
            }
            'camera' {
                return [bool](Get-AppxPackage -Name 'Microsoft.WindowsCamera' -ErrorAction SilentlyContinue)
            }
            'install-webview2' {
                if (Test-Path "${env:ProgramFiles(x86)}\Microsoft\EdgeWebView\Application") { return $true }
                return (Test-App -DisplayNameLike '*WebView2 Runtime*')
            }
            'install-edge' {
                $p1 = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
                $p2 = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
                return ((Test-Path $p1) -or (Test-Path $p2))
            }
            'vnc-cursor' {
                $v = (Get-ItemProperty -LiteralPath $script:REALVNC_CFG_KEY -Name 'AlwaysShowCursor' -ErrorAction SilentlyContinue).AlwaysShowCursor
                return ($v -eq 1)
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
# EXPLORER / UI TWEAKS - the .reg + .cmd collection, ported to native calls.
#
# Design notes:
#   * Every tweak is a two-way toggle (Apply / Revert) because the source pack
#     shipped both directions (KALDIR/GERI YUKLE, Disable/Enable, Add/Remove).
#   * Tweaks that DELETE registry keys export them to
#     $script:BACKUP_DIR\ui-tweaks\<key>\ first, so Revert re-imports the exact
#     original instead of guessing at Windows' default values. If a key was
#     deleted outside this script there is nothing to import and Revert says so.
#   * reg.exe is used for delete/export (it is literal about key names such as
#     the HKCR "*" class); the PowerShell registry provider is used for reads and
#     value writes because it is far faster in the detection loop.
#===============================================================================

$script:UI_TWEAK_BACKUP_ROOT = Join-Path $script:BACKUP_DIR 'ui-tweaks'

# reg.exe hive notation -> PowerShell provider path (covers HKCR / HKU too).
function ConvertTo-RegProviderPath {
    param([Parameter(Mandatory)][string]$RegPath)
    $p = $RegPath
    $p = $p -replace '^HKLM\\', 'HKEY_LOCAL_MACHINE\'
    $p = $p -replace '^HKCU\\', 'HKEY_CURRENT_USER\'
    $p = $p -replace '^HKCR\\', 'HKEY_CLASSES_ROOT\'
    $p = $p -replace '^HKU\\',  'HKEY_USERS\'
    return "Registry::$p"
}

function Test-UiRegKey {
    param([Parameter(Mandatory)][string]$RegPath)
    try { return [bool](Test-Path -LiteralPath (ConvertTo-RegProviderPath $RegPath)) } catch { return $false }
}

# Read a single value; $null when the key or the value is absent.
function Get-UiRegValue {
    param([Parameter(Mandatory)][string]$RegPath, [Parameter(Mandatory)][string]$Name)
    try {
        $prov = ConvertTo-RegProviderPath $RegPath
        if (-not (Test-Path -LiteralPath $prov)) { return $null }
        return (Get-ItemProperty -LiteralPath $prov -Name $Name -ErrorAction SilentlyContinue).$Name
    } catch { return $null }
}

# Write a single value, creating the key when needed.
function Set-UiRegValue {
    param(
        [Parameter(Mandatory)][string]$RegPath,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet('DWord', 'String')][string]$Type = 'DWord'
    )
    try {
        $prov = ConvertTo-RegProviderPath $RegPath
        if (-not (Test-Path -LiteralPath $prov)) { New-Item -Path $prov -Force | Out-Null }
        New-ItemProperty -LiteralPath $prov -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        return $true
    } catch {
        Write-LogWarning "Could not set $RegPath\$Name : $($_.Exception.Message)"
        return $false
    }
}

# Delete a single value (no-op when it is already gone).
function Remove-UiRegValue {
    param([Parameter(Mandatory)][string]$RegPath, [Parameter(Mandatory)][string]$Name)
    try {
        $prov = ConvertTo-RegProviderPath $RegPath
        if (Test-Path -LiteralPath $prov) { Remove-ItemProperty -LiteralPath $prov -Name $Name -ErrorAction SilentlyContinue }
        return $true
    } catch { return $false }
}

# Create a key, optionally with a default ("@=") value.
function New-UiRegKey {
    param([Parameter(Mandatory)][string]$RegPath, [string]$DefaultValue)
    try {
        $prov = ConvertTo-RegProviderPath $RegPath
        if (-not (Test-Path -LiteralPath $prov)) { New-Item -Path $prov -Force | Out-Null }
        if ($PSBoundParameters.ContainsKey('DefaultValue')) {
            New-ItemProperty -LiteralPath $prov -Name '(default)' -Value $DefaultValue -PropertyType String -Force | Out-Null
        }
        return $true
    } catch {
        Write-LogWarning "Could not create $RegPath : $($_.Exception.Message)"
        return $false
    }
}

# Export a key under the tweak's backup folder, then delete it recursively.
# Idempotent: a key that is already gone is a silent success.
function Remove-UiRegKey {
    param([Parameter(Mandatory)][string]$TweakKey, [Parameter(Mandatory)][string]$RegPath)
    & reg.exe query $RegPath > $null 2>&1
    if ($LASTEXITCODE -ne 0) { return $true }

    try {
        $dir = Join-Path $script:UI_TWEAK_BACKUP_ROOT $TweakKey
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $file = Join-Path $dir (($RegPath -replace '[\\:\*\s\{\}]', '_') + '.reg')
        & reg.exe export $RegPath $file /y > $null 2>&1
    } catch {
        Write-LogWarning "  Could not export $RegPath before deleting it: $($_.Exception.Message)"
    }

    & reg.exe delete $RegPath /f > $null 2>&1
    if ($LASTEXITCODE -eq 0) { return $true }
    Write-LogWarning "Could not delete $RegPath (the key may be owned by TrustedInstaller)."
    return $false
}

# Re-import everything this script exported for a tweak. $false when there is
# no export to restore from.
function Restore-UiRegBackup {
    param([Parameter(Mandatory)][string]$TweakKey)
    $dir = Join-Path $script:UI_TWEAK_BACKUP_ROOT $TweakKey
    if (-not (Test-Path -LiteralPath $dir)) { return $false }
    $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.reg' -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { return $false }
    $ok = $false
    foreach ($f in $files) {
        & reg.exe import $f.FullName > $null 2>&1
        if ($LASTEXITCODE -eq 0) { $ok = $true } else { Write-LogWarning "  Could not import $($f.Name)" }
    }
    return $ok
}

# Explorer picks up namespace / context-menu changes only after a restart.
# Windows relaunches it automatically when it is killed from an elevated shell.
function Restart-Explorer {
    try {
        if (Get-Process -Name explorer -ErrorAction SilentlyContinue) {
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

#-------------------------------------------------------------------------------
# This PC - the six user folders and 3D Objects
#-------------------------------------------------------------------------------
# Both the Windows 8.1-era and the Windows 10-era CLSID exist for most folders;
# the source .reg pack deletes both, so we do too.
$script:THISPC_FOLDER_CLSIDS = @(
    '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}'   # Desktop
    '{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}'   # Documents
    '{d3162b92-9365-467a-956b-92703aca08af}'   # Documents (alt)
    '{374DE290-123F-4565-9164-39C4925E467B}'   # Downloads
    '{088e3905-0323-4b02-9826-5d99428e115f}'   # Downloads (alt)
    '{1CF1260C-4DD0-4ebb-811F-33C572699FDE}'   # Music
    '{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}'   # Music (alt)
    '{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}'   # Pictures
    '{24ad3ad4-a569-4530-98e1-ab02f9417aa8}'   # Pictures (alt)
    '{A0953C92-50DC-43bf-BE83-3742FED03C9C}'   # Videos
    '{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}'   # Videos (alt)
)
$script:THISPC_3D_CLSID    = '{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}'
$script:MYCOMPUTER_NS_ROOTS = @(
    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace'
    'HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace'
)

function Remove-ThisPcUserFolders {
    Write-LogInfo "Removing Desktop/Documents/Downloads/Music/Pictures/Videos from This PC..."
    foreach ($root in $script:MYCOMPUTER_NS_ROOTS) {
        foreach ($clsid in $script:THISPC_FOLDER_CLSIDS) {
            Remove-UiRegKey -TweakKey 'thispc-folders' -RegPath "$root\$clsid" | Out-Null
        }
    }
    Restart-Explorer
    Write-LogSuccess "This PC now shows drives only (Explorer restarted)."
    return $true
}

function Restore-ThisPcUserFolders {
    Write-LogInfo "Restoring the user folders under This PC..."
    if (-not (Restore-UiRegBackup 'thispc-folders')) {
        # No export to import (tweak applied outside this script): recreate the
        # namespace keys - Explorer only needs the key itself to exist.
        foreach ($root in $script:MYCOMPUTER_NS_ROOTS) {
            foreach ($clsid in $script:THISPC_FOLDER_CLSIDS) { New-UiRegKey "$root\$clsid" | Out-Null }
        }
    }
    Restart-Explorer
    Write-LogSuccess "This PC lists the user folders again (Explorer restarted)."
    return $true
}

function Remove-3DObjectsFolder {
    Write-LogInfo "Removing the 3D Objects folder from This PC..."
    foreach ($root in $script:MYCOMPUTER_NS_ROOTS) {
        Remove-UiRegKey -TweakKey 'thispc-3d' -RegPath "$root\$($script:THISPC_3D_CLSID)" | Out-Null
    }
    Restart-Explorer
    Write-LogSuccess "3D Objects removed from This PC (Explorer restarted)."
    return $true
}

function Restore-3DObjectsFolder {
    Write-LogInfo "Restoring the 3D Objects folder under This PC..."
    if (-not (Restore-UiRegBackup 'thispc-3d')) {
        foreach ($root in $script:MYCOMPUTER_NS_ROOTS) { New-UiRegKey "$root\$($script:THISPC_3D_CLSID)" | Out-Null }
    }
    Restart-Explorer
    Write-LogSuccess "3D Objects restored (Explorer restarted)."
    return $true
}

#-------------------------------------------------------------------------------
# Navigation pane entries (Network / HomeGroup / Gallery / Home)
#-------------------------------------------------------------------------------
# All four share one shape: a per-user CLSID key whose System.IsPinnedToNameSpaceTree
# value decides whether Explorer shows the entry.
$script:NAV_CLSID_NETWORK   = '{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}'
$script:NAV_CLSID_HOMEGROUP = '{B4FB3F98-C1EA-428d-A78A-D1F5659CBA93}'
$script:NAV_CLSID_GALLERY   = '{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'
$script:NAV_CLSID_HOME      = '{f874310e-b6b7-47dc-bc84-b9e6b38f5903}'

function Set-NavPaneItem {
    param(
        [Parameter(Mandatory)][string]$Clsid,
        [Parameter(Mandatory)][bool]$Pinned,
        [string]$DefaultValue
    )
    $path = "HKCU\Software\Classes\CLSID\$Clsid"
    if ($DefaultValue) { New-UiRegKey $path $DefaultValue | Out-Null }
    $v = 0; if ($Pinned) { $v = 1 }
    $ok = Set-UiRegValue -RegPath $path -Name 'System.IsPinnedToNameSpaceTree' -Value $v -Type DWord
    Restart-Explorer
    return $ok
}

function Test-NavPaneHidden {
    param([Parameter(Mandatory)][string]$Clsid)
    $v = Get-UiRegValue -RegPath "HKCU\Software\Classes\CLSID\$Clsid" -Name 'System.IsPinnedToNameSpaceTree'
    return ($null -ne $v -and [int]$v -eq 0)
}

function Remove-NavPaneNetwork {
    Write-LogInfo "Hiding Network in the Explorer navigation pane..."
    $ok = Set-NavPaneItem -Clsid $script:NAV_CLSID_NETWORK -Pinned $false
    if ($ok) { Write-LogSuccess "Network hidden (Explorer restarted)." }
    return $ok
}
function Restore-NavPaneNetwork {
    Write-LogInfo "Showing Network in the Explorer navigation pane..."
    $ok = Set-NavPaneItem -Clsid $script:NAV_CLSID_NETWORK -Pinned $true
    if ($ok) { Write-LogSuccess "Network shown (Explorer restarted)." }
    return $ok
}

function Remove-NavPaneHomeGroup {
    Write-LogInfo "Hiding HomeGroup in the Explorer navigation pane..."
    $ok = Set-NavPaneItem -Clsid $script:NAV_CLSID_HOMEGROUP -Pinned $false
    if ($ok) { Write-LogSuccess "HomeGroup hidden (Explorer restarted). Note: Windows 11 has no HomeGroup, so this is a no-op there." }
    return $ok
}
function Restore-NavPaneHomeGroup {
    Write-LogInfo "Showing HomeGroup in the Explorer navigation pane..."
    $ok = Set-NavPaneItem -Clsid $script:NAV_CLSID_HOMEGROUP -Pinned $true
    if ($ok) { Write-LogSuccess "HomeGroup shown (Explorer restarted)." }
    return $ok
}

function Remove-NavPaneGallery {
    Write-LogInfo "Hiding Gallery in the Explorer navigation pane (Windows 11)..."
    $ok = Set-NavPaneItem -Clsid $script:NAV_CLSID_GALLERY -Pinned $false
    if ($ok) { Write-LogSuccess "Gallery hidden (Explorer restarted)." }
    return $ok
}
function Restore-NavPaneGallery {
    Write-LogInfo "Showing Gallery in the Explorer navigation pane (Windows 11)..."
    $ok = Set-NavPaneItem -Clsid $script:NAV_CLSID_GALLERY -Pinned $true
    if ($ok) { Write-LogSuccess "Gallery shown (Explorer restarted)." }
    return $ok
}

function Remove-NavPaneHome {
    Write-LogInfo "Hiding Home in the Explorer navigation pane (Windows 11)..."
    $ok = Set-NavPaneItem -Clsid $script:NAV_CLSID_HOME -Pinned $false -DefaultValue 'CLSID_MSGraphHomeFolder'
    if ($ok) { Write-LogSuccess "Home hidden (Explorer restarted)." }
    return $ok
}
function Restore-NavPaneHome {
    Write-LogInfo "Showing Home in the Explorer navigation pane (Windows 11)..."
    $ok = Set-NavPaneItem -Clsid $script:NAV_CLSID_HOME -Pinned $true -DefaultValue 'CLSID_MSGraphHomeFolder'
    if ($ok) { Write-LogSuccess "Home shown (Explorer restarted)." }
    return $ok
}

#-------------------------------------------------------------------------------
# Navigation pane: the duplicate removable-drive entries (DelegateFolders)
#-------------------------------------------------------------------------------
$script:NAV_DRIVES_KEYS = @(
    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}'
    'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}'
)

function Remove-NavPaneDrives {
    Write-LogInfo "Removing the duplicate removable-drive entries from the navigation pane..."
    foreach ($k in $script:NAV_DRIVES_KEYS) { Remove-UiRegKey -TweakKey 'nav-drives' -RegPath $k | Out-Null }
    Restart-Explorer
    Write-LogSuccess "Removable drives are no longer listed twice (Explorer restarted)."
    return $true
}
function Restore-NavPaneDrives {
    Write-LogInfo "Restoring the removable-drive entries in the navigation pane..."
    if (-not (Restore-UiRegBackup 'nav-drives')) {
        foreach ($k in $script:NAV_DRIVES_KEYS) { New-UiRegKey $k 'Removable Drives' | Out-Null }
    }
    Restart-Explorer
    Write-LogSuccess "Removable drives restored (Explorer restarted)."
    return $true
}

#-------------------------------------------------------------------------------
# Quick Access: frequent folders
#-------------------------------------------------------------------------------
$script:QUICK_ACCESS_KEY = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer'

function Hide-QuickAccessFrequent {
    Write-LogInfo "Hiding frequently-used folders in Quick Access..."
    $ok = Set-UiRegValue -RegPath $script:QUICK_ACCESS_KEY -Name 'ShowFrequent' -Value 0
    Restart-Explorer
    if ($ok) { Write-LogSuccess "Frequent folders hidden (Explorer restarted)." }
    return $ok
}
function Show-QuickAccessFrequent {
    Write-LogInfo "Showing frequently-used folders in Quick Access..."
    $ok = Set-UiRegValue -RegPath $script:QUICK_ACCESS_KEY -Name 'ShowFrequent' -Value 1
    Restart-Explorer
    if ($ok) { Write-LogSuccess "Frequent folders shown (Explorer restarted)." }
    return $ok
}

#-------------------------------------------------------------------------------
# Windows 11: classic (Windows 10 style) right-click menu
#-------------------------------------------------------------------------------
$script:CLASSIC_CTX_KEY = 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'

function Enable-ClassicContextMenu {
    Write-LogInfo "Restoring the classic (full) right-click menu..."
    $ok = New-UiRegKey "$($script:CLASSIC_CTX_KEY)\InprocServer32" ''
    Restart-Explorer
    if ($ok) { Write-LogSuccess "Classic context menu restored (Explorer restarted)." }
    return $ok
}
function Disable-ClassicContextMenu {
    Write-LogInfo "Restoring the Windows 11 compact right-click menu..."
    try {
        $prov = ConvertTo-RegProviderPath $script:CLASSIC_CTX_KEY
        if (Test-Path -LiteralPath $prov) { Remove-Item -LiteralPath $prov -Recurse -Force -ErrorAction Stop }
        Restart-Explorer
        Write-LogSuccess "Windows 11 context menu restored (Explorer restarted)."
        return $true
    } catch {
        Write-LogWarning "Could not remove the classic-context-menu key: $($_.Exception.Message)"
        return $false
    }
}

#-------------------------------------------------------------------------------
# Shell-extension removals (Share with / Sharing tab / Previous Versions)
#-------------------------------------------------------------------------------
$script:CTX_SHARE_KEYS = @(
    'HKCR\*\shellex\ContextMenuHandlers\Sharing'
    'HKCR\Directory\Background\shellex\ContextMenuHandlers\Sharing'
    'HKCR\Directory\shellex\ContextMenuHandlers\Sharing'
    'HKCR\Drive\shellex\ContextMenuHandlers\Sharing'
    'HKCR\LibraryFolder\background\shellex\ContextMenuHandlers\Sharing'
    'HKCR\UserLibraryFolder\shellex\ContextMenuHandlers\Sharing'
)
$script:CTX_SHARING_TAB_KEYS = @(
    'HKCR\Directory\shellex\PropertySheetHandlers\Sharing'
    'HKCR\Drive\shellex\PropertySheetHandlers\Sharing'
)
$script:CTX_PREVVER_KEYS = @(
    'HKCR\AllFilesystemObjects\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'
    'HKCR\CLSID\{450D8FBA-AD25-11D0-98A8-0800361B1103}\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'
    'HKCR\Directory\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'
    'HKCR\Drive\shellex\ContextMenuHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'
    'HKCR\AllFilesystemObjects\shellex\PropertySheetHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'
    'HKCR\CLSID\{450D8FBA-AD25-11D0-98A8-0800361B1103}\shellex\PropertySheetHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'
    'HKCR\Directory\shellex\PropertySheetHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'
    'HKCR\Drive\shellex\PropertySheetHandlers\{596AB062-B4D2-4215-9F74-E9109B0A8153}'
)

function Remove-ShellExKeys {
    param([Parameter(Mandatory)][string]$TweakKey, [Parameter(Mandatory)][string[]]$Keys)
    $ok = $true
    foreach ($k in $Keys) {
        if (-not (Remove-UiRegKey -TweakKey $TweakKey -RegPath $k)) { $ok = $false }
    }
    Restart-Explorer
    return $ok
}

function Restore-ShellExKeys {
    param([Parameter(Mandatory)][string]$TweakKey)
    if (Restore-UiRegBackup $TweakKey) {
        Restart-Explorer
        return $true
    }
    Write-LogWarning "No export found under $($script:UI_TWEAK_BACKUP_ROOT)\$TweakKey - these shell-extension keys can only be put back from a backup taken when the tweak was applied."
    return $false
}

function Remove-ShareContextMenu {
    Write-LogInfo "Removing the 'Share with' entry from the right-click menu..."
    $ok = Remove-ShellExKeys -TweakKey 'ctx-share' -Keys $script:CTX_SHARE_KEYS
    if ($ok) { Write-LogSuccess "'Share with' removed from the context menu (Explorer restarted)." }
    return $ok
}
function Restore-ShareContextMenu {
    Write-LogInfo "Restoring the 'Share with' context-menu entry..."
    $ok = Restore-ShellExKeys -TweakKey 'ctx-share'
    if ($ok) { Write-LogSuccess "'Share with' restored (Explorer restarted)." }
    return $ok
}

function Remove-SharingPropertyTab {
    Write-LogInfo "Removing the Sharing tab from the Properties window..."
    $ok = Remove-ShellExKeys -TweakKey 'ctx-sharing-tab' -Keys $script:CTX_SHARING_TAB_KEYS
    if ($ok) { Write-LogSuccess "Sharing tab removed (Explorer restarted)." }
    return $ok
}
function Restore-SharingPropertyTab {
    Write-LogInfo "Restoring the Sharing tab in the Properties window..."
    $ok = Restore-ShellExKeys -TweakKey 'ctx-sharing-tab'
    if ($ok) { Write-LogSuccess "Sharing tab restored (Explorer restarted)." }
    return $ok
}

function Remove-PreviousVersions {
    Write-LogInfo "Removing 'Previous Versions' from the context menu and the Properties window..."
    $ok = Remove-ShellExKeys -TweakKey 'ctx-prev-versions' -Keys $script:CTX_PREVVER_KEYS
    if ($ok) { Write-LogSuccess "'Previous Versions' removed (Explorer restarted)." }
    return $ok
}
function Restore-PreviousVersions {
    Write-LogInfo "Restoring 'Previous Versions'..."
    $ok = Restore-ShellExKeys -TweakKey 'ctx-prev-versions'
    if ($ok) { Write-LogSuccess "'Previous Versions' restored (Explorer restarted)." }
    return $ok
}

#-------------------------------------------------------------------------------
# Action Center / notification centre
#-------------------------------------------------------------------------------
$script:ACTION_CENTER_KEY_HKCU = 'HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer'
$script:ACTION_CENTER_KEY_HKLM = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer'

function Disable-ActionCenter {
    Write-LogInfo "Disabling the Action Center / notification centre..."
    $a = Set-UiRegValue -RegPath $script:ACTION_CENTER_KEY_HKCU -Name 'DisableNotificationCenter' -Value 1
    $b = Set-UiRegValue -RegPath $script:ACTION_CENTER_KEY_HKLM -Name 'DisableNotificationCenter' -Value 1
    Restart-Explorer
    if ($a -and $b) { Write-LogSuccess "Action Center disabled (Explorer restarted; sign out if the icon lingers)." }
    return ($a -and $b)
}
function Enable-ActionCenter {
    Write-LogInfo "Re-enabling the Action Center / notification centre..."
    Remove-UiRegValue -RegPath $script:ACTION_CENTER_KEY_HKCU -Name 'DisableNotificationCenter' | Out-Null
    Remove-UiRegValue -RegPath $script:ACTION_CENTER_KEY_HKLM -Name 'DisableNotificationCenter' | Out-Null
    Restart-Explorer
    Write-LogSuccess "Action Center re-enabled (Explorer restarted)."
    return $true
}

#-------------------------------------------------------------------------------
# Lock screen
#-------------------------------------------------------------------------------
$script:LOCKSCREEN_POLICY_KEY = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization'
$script:LOCKSCREEN_SESSION_KEY = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\SessionData'

function Disable-LockScreen {
    Write-LogInfo "Disabling the lock screen for all users..."
    $ok = Set-UiRegValue -RegPath $script:LOCKSCREEN_POLICY_KEY -Name 'NoLockScreen' -Value 1
    if ($ok) { Write-LogSuccess "Lock screen disabled (takes effect at the next lock/sign-in)." }
    return $ok
}
function Enable-LockScreen {
    Write-LogInfo "Re-enabling the lock screen..."
    Remove-UiRegValue -RegPath $script:LOCKSCREEN_POLICY_KEY -Name 'NoLockScreen' | Out-Null
    Set-UiRegValue -RegPath $script:LOCKSCREEN_SESSION_KEY -Name 'AllowLockScreen' -Value 1 | Out-Null
    Write-LogSuccess "Lock screen re-enabled."
    return $true
}

#-------------------------------------------------------------------------------
# Search box: web suggestions
#-------------------------------------------------------------------------------
$script:SEARCH_POLICY_KEY = 'HKCU\Software\Policies\Microsoft\Windows\Explorer'

function Disable-SearchBoxSuggestions {
    Write-LogInfo "Disabling web suggestions in the search box..."
    $ok = Set-UiRegValue -RegPath $script:SEARCH_POLICY_KEY -Name 'DisableSearchBoxSuggestions' -Value 1
    Restart-Explorer
    if ($ok) { Write-LogSuccess "Search box web suggestions disabled (Explorer restarted)." }
    return $ok
}
function Enable-SearchBoxSuggestions {
    Write-LogInfo "Re-enabling web suggestions in the search box..."
    $ok = Set-UiRegValue -RegPath $script:SEARCH_POLICY_KEY -Name 'DisableSearchBoxSuggestions' -Value 0
    Restart-Explorer
    if ($ok) { Write-LogSuccess "Search box web suggestions re-enabled (Explorer restarted)." }
    return $ok
}

#-------------------------------------------------------------------------------
# NumLock at boot
#-------------------------------------------------------------------------------
# .DEFAULT covers the logon screen only; without the matching HKCU value the
# state flips back right after sign-in, which is why both are written here.
$script:NUMLOCK_KEY_DEFAULT = 'HKU\.DEFAULT\Control Panel\Keyboard'
$script:NUMLOCK_KEY_USER    = 'HKCU\Control Panel\Keyboard'

function Enable-NumLockAtBoot {
    Write-LogInfo "Turning NumLock on at the logon screen and after sign-in..."
    $a = Set-UiRegValue -RegPath $script:NUMLOCK_KEY_DEFAULT -Name 'InitialKeyboardIndicators' -Value '2' -Type String
    $b = Set-UiRegValue -RegPath $script:NUMLOCK_KEY_USER    -Name 'InitialKeyboardIndicators' -Value '2' -Type String
    if ($a -and $b) {
        Write-LogSuccess "NumLock will be on at boot."
        Write-LogInfo "If Fast Startup is enabled, shut down fully once (or disable it) for this to stick."
    }
    return ($a -and $b)
}
function Disable-NumLockAtBoot {
    Write-LogInfo "Turning NumLock off at the logon screen and after sign-in..."
    $a = Set-UiRegValue -RegPath $script:NUMLOCK_KEY_DEFAULT -Name 'InitialKeyboardIndicators' -Value '0' -Type String
    $b = Set-UiRegValue -RegPath $script:NUMLOCK_KEY_USER    -Name 'InitialKeyboardIndicators' -Value '0' -Type String
    if ($a -and $b) { Write-LogSuccess "NumLock will be off at boot." }
    return ($a -and $b)
}

#-------------------------------------------------------------------------------
# Superfetch (SysMain) + Prefetch
#-------------------------------------------------------------------------------
$script:PREFETCH_KEY = 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters'

function Disable-SuperfetchPrefetch {
    Write-LogInfo "Disabling Superfetch (SysMain) and Prefetch..."
    try {
        $svc = Get-Service -Name SysMain -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -eq 'Running') { Stop-Service -Name SysMain -Force -ErrorAction SilentlyContinue }
            Set-Service -Name SysMain -StartupType Disabled -ErrorAction SilentlyContinue
        } else {
            Write-LogInfo "  The SysMain service is not present on this system; only the Prefetch policy is applied."
        }
    } catch {
        Write-LogWarning "Could not stop/disable SysMain: $($_.Exception.Message)"
    }

    $ok = Set-UiRegValue -RegPath $script:PREFETCH_KEY -Name 'EnablePrefetcher' -Value 0

    try {
        $pf = Join-Path $env:SystemRoot 'Prefetch'
        if (Test-Path -LiteralPath $pf) {
            Get-ChildItem -LiteralPath $pf -File -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    } catch { }

    if ($ok) {
        Write-LogSuccess "Superfetch and Prefetch disabled; the Prefetch cache was cleared."
        Write-LogInfo "Recommended on SSD/NVMe only - on a spinning disk this can slow app launches."
    }
    return $ok
}

function Enable-SuperfetchPrefetch {
    Write-LogInfo "Re-enabling Superfetch (SysMain) and Prefetch..."
    try {
        $svc = Get-Service -Name SysMain -ErrorAction SilentlyContinue
        if ($svc) {
            Set-Service -Name SysMain -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name SysMain -ErrorAction SilentlyContinue
        }
    } catch {
        Write-LogWarning "Could not start SysMain: $($_.Exception.Message)"
    }
    $ok = Set-UiRegValue -RegPath $script:PREFETCH_KEY -Name 'EnablePrefetcher' -Value 3
    if ($ok) { Write-LogSuccess "Superfetch and Prefetch re-enabled." }
    return $ok
}

#-------------------------------------------------------------------------------
# Classic Windows Photo Viewer
#-------------------------------------------------------------------------------
$script:PHOTOVIEWER_KEY = 'HKLM\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations'
$script:PHOTOVIEWER_EXT = @('.tif', '.tiff', '.png', '.bmp', '.jpeg', '.jpg', '.ico')

function Restore-WindowsPhotoViewer {
    Write-LogInfo "Re-registering the classic Windows Photo Viewer for common image types..."
    $ok = $true
    foreach ($ext in $script:PHOTOVIEWER_EXT) {
        if (-not (Set-UiRegValue -RegPath $script:PHOTOVIEWER_KEY -Name $ext -Value 'PhotoViewer.FileAssoc.Tiff' -Type String)) { $ok = $false }
    }
    if ($ok) {
        Write-LogSuccess "Windows Photo Viewer registered for: $($script:PHOTOVIEWER_EXT -join ', ')"
        Write-LogInfo "It now appears under right-click > Open with; pick it once per file type (or in Settings > Default apps)."
    }
    return $ok
}
function Remove-WindowsPhotoViewer {
    Write-LogInfo "Unregistering the classic Windows Photo Viewer..."
    foreach ($ext in $script:PHOTOVIEWER_EXT) {
        Remove-UiRegValue -RegPath $script:PHOTOVIEWER_KEY -Name $ext | Out-Null
    }
    Write-LogSuccess "Windows Photo Viewer file associations removed."
    return $true
}

#-------------------------------------------------------------------------------
# One-shot maintenance actions (no revert)
#-------------------------------------------------------------------------------
function Reset-IconCache {
    Write-LogInfo "Rebuilding the Explorer icon cache (Explorer restarts - save your work first)..."
    try { & ie4uinit.exe -show 2>$null | Out-Null } catch { }
    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        $lad = $env:LOCALAPPDATA
        Remove-Item -LiteralPath (Join-Path $lad 'IconCache.db') -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path (Join-Path $lad 'Microsoft\Windows\Explorer') -Filter 'iconcache*' -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    } catch {
        Write-LogWarning "Icon cache cleanup hit an error: $($_.Exception.Message)"
    }
    try { Start-Process explorer.exe -ErrorAction SilentlyContinue } catch { }
    Write-LogSuccess "Icon cache rebuilt (Explorer restarted)."
    return $true
}

function Clear-DnsCache {
    Write-LogWarning "This releases and renews the DHCP lease - a remote session (RDP/VNC/AnyDesk/RustDesk) may drop for a few seconds."
    Write-LogInfo "Flushing the DNS resolver cache and renewing the IP lease..."
    try {
        & ipconfig.exe /flushdns | Out-Null
        & ipconfig.exe /release  | Out-Null
        & ipconfig.exe /renew    | Out-Null
        Write-LogSuccess "DNS cache flushed and the IP lease renewed."
        return $true
    } catch {
        Write-LogWarning "Could not flush/renew: $($_.Exception.Message)"
        return $false
    }
}

#===============================================================================
# DETECTION - Test-UiTweakApplied (drives the [applied] marker in the submenu).
# One-shot actions are never "applied". Defensive: any error returns $false.
#===============================================================================
function Test-UiTweakApplied {
    param([Parameter(Mandatory)][string]$Key)
    try {
        switch ($Key) {
            'icon-cache' { return $false }   # transient
            'dns-flush'  { return $false }   # transient

            'thispc-folders' {
                foreach ($root in $script:MYCOMPUTER_NS_ROOTS) {
                    foreach ($clsid in $script:THISPC_FOLDER_CLSIDS) {
                        if (Test-UiRegKey "$root\$clsid") { return $false }
                    }
                }
                return $true
            }
            'thispc-3d' {
                foreach ($root in $script:MYCOMPUTER_NS_ROOTS) {
                    if (Test-UiRegKey "$root\$($script:THISPC_3D_CLSID)") { return $false }
                }
                return $true
            }
            'nav-network'   { return (Test-NavPaneHidden $script:NAV_CLSID_NETWORK) }
            'nav-homegroup' { return (Test-NavPaneHidden $script:NAV_CLSID_HOMEGROUP) }
            'nav-gallery'   { return (Test-NavPaneHidden $script:NAV_CLSID_GALLERY) }
            'nav-home'      { return (Test-NavPaneHidden $script:NAV_CLSID_HOME) }
            'nav-drives' {
                foreach ($k in $script:NAV_DRIVES_KEYS) { if (Test-UiRegKey $k) { return $false } }
                return $true
            }
            'quick-access' {
                $v = Get-UiRegValue -RegPath $script:QUICK_ACCESS_KEY -Name 'ShowFrequent'
                return ($null -ne $v -and [int]$v -eq 0)
            }
            'classic-context' {
                $prov = ConvertTo-RegProviderPath "$($script:CLASSIC_CTX_KEY)\InprocServer32"
                if (-not (Test-Path -LiteralPath $prov)) { return $false }
                $v = (Get-Item -LiteralPath $prov -ErrorAction SilentlyContinue).GetValue('')
                return ($null -ne $v -and [string]$v -eq '')
            }
            'ctx-share' {
                foreach ($k in $script:CTX_SHARE_KEYS) { if (Test-UiRegKey $k) { return $false } }
                return $true
            }
            'ctx-sharing-tab' {
                foreach ($k in $script:CTX_SHARING_TAB_KEYS) { if (Test-UiRegKey $k) { return $false } }
                return $true
            }
            'ctx-prev-versions' {
                foreach ($k in $script:CTX_PREVVER_KEYS) { if (Test-UiRegKey $k) { return $false } }
                return $true
            }
            'action-center' {
                $v = Get-UiRegValue -RegPath $script:ACTION_CENTER_KEY_HKLM -Name 'DisableNotificationCenter'
                return ($null -ne $v -and [int]$v -eq 1)
            }
            'lock-screen' {
                $v = Get-UiRegValue -RegPath $script:LOCKSCREEN_POLICY_KEY -Name 'NoLockScreen'
                return ($null -ne $v -and [int]$v -eq 1)
            }
            'search-suggestions' {
                $v = Get-UiRegValue -RegPath $script:SEARCH_POLICY_KEY -Name 'DisableSearchBoxSuggestions'
                return ($null -ne $v -and [int]$v -eq 1)
            }
            'numlock' {
                $v = Get-UiRegValue -RegPath $script:NUMLOCK_KEY_DEFAULT -Name 'InitialKeyboardIndicators'
                return ([string]$v -eq '2')
            }
            'superfetch' {
                $v = Get-UiRegValue -RegPath $script:PREFETCH_KEY -Name 'EnablePrefetcher'
                return ($null -ne $v -and [int]$v -eq 0)
            }
            'photo-viewer' {
                $v = Get-UiRegValue -RegPath $script:PHOTOVIEWER_KEY -Name '.png'
                return ([string]$v -eq 'PhotoViewer.FileAssoc.Tiff')
            }
            default { return $false }
        }
    } catch {
        return $false
    }
}

#===============================================================================
# Debloat - remove pre-installed Windows bloat.
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
    @{ Key='sysrestore';    Label='System Restore: disable + delete all restore points'; Kind='Script'; Remove='Disable-SystemRestoreAndPurge'; DetectFn='Test-SystemRestoreDisabled' }
    # --- Microsoft Store / UWP bloat (Appx) -----------------------------------
    # Xbox split into granular pieces (was one broad '*Xbox*') so each is optional.
    @{ Key='xbox-app';      Label='Xbox app';                  Kind='Appx'; Id='Microsoft.GamingApp';               ProvisionedToo=$true }
    @{ Key='xbox-gamebar';  Label='Xbox Game Bar';             Kind='Appx'; Id='Microsoft.XboxGamingOverlay';       ProvisionedToo=$true }
    @{ Key='xbox-speech';   Label='Game Speech Window';        Kind='Appx'; Id='Microsoft.XboxSpeechToTextOverlay'; ProvisionedToo=$true }
    @{ Key='xbox-live';     Label='Xbox Live (TCUI)';          Kind='Appx'; Id='Microsoft.Xbox.TCUI';               ProvisionedToo=$true }
    @{ Key='xbox-identity'; Label='Xbox Identity Provider';    Kind='Appx'; Id='Microsoft.XboxIdentityProvider';    ProvisionedToo=$true }
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
    # --- More modern Windows apps (Appx) - exact package names ----------------
    @{ Key='devhome';       Label='Dev Home';                  Kind='Appx'; Id='Microsoft.Windows.DevHome';         ProvisionedToo=$true }
    @{ Key='office365';     Label='Microsoft 365 / Office (Copilot)'; Kind='Appx'; Id='Microsoft.MicrosoftOfficeHub'; ProvisionedToo=$true }
    @{ Key='bing';          Label='Bing Search';               Kind='Appx'; Id='Microsoft.BingSearch';              ProvisionedToo=$true }
    @{ Key='stickynotes';   Label='Sticky Notes';              Kind='Appx'; Id='Microsoft.MicrosoftStickyNotes';    ProvisionedToo=$true }
    @{ Key='teams-new';     Label='Teams (new / work)';        Kind='Appx'; Id='MSTeams';                           ProvisionedToo=$true }
    @{ Key='todo';          Label='Microsoft To Do';           Kind='Appx'; Id='Microsoft.Todos';                   ProvisionedToo=$true }
    @{ Key='outlook-new';   Label='Outlook for Windows (new)'; Kind='Appx'; Id='Microsoft.OutlookForWindows';       ProvisionedToo=$true }
    @{ Key='paint';         Label='Paint';                     Kind='Appx'; Id='Microsoft.Paint';                   ProvisionedToo=$true }
    @{ Key='powerautomate'; Label='Power Automate (Desktop)';  Kind='Appx'; Id='Microsoft.PowerAutomateDesktop';    ProvisionedToo=$true }
    @{ Key='linkedin';      Label='LinkedIn';                  Kind='Appx'; Id='*LinkedIn*';                        ProvisionedToo=$true }
    @{ Key='photos';        Label='Photos';                    Kind='Appx'; Id='Microsoft.Windows.Photos';          ProvisionedToo=$true }
    @{ Key='clock';         Label='Clock (Alarms & Clock)';    Kind='Appx'; Id='Microsoft.WindowsAlarms';           ProvisionedToo=$true }
    @{ Key='calculator';    Label='Calculator';                Kind='Appx'; Id='Microsoft.WindowsCalculator';       ProvisionedToo=$true }
    @{ Key='soundrecorder'; Label='Sound Recorder';            Kind='Appx'; Id='Microsoft.WindowsSoundRecorder';    ProvisionedToo=$true }
    @{ Key='camera-app';    Label='Camera (Windows Camera app)'; Kind='Appx'; Id='Microsoft.WindowsCamera';         ProvisionedToo=$true }
    @{ Key='mobiledevices'; Label='Mobile devices (Cross Device)'; Kind='Appx'; Id='MicrosoftWindows.CrossDevice';  ProvisionedToo=$true }
    @{ Key='widgets-rt';    Label='Widgets Platform Runtime';  Kind='Appx'; Id='Microsoft.WidgetsPlatformRuntime';  ProvisionedToo=$true }
    @{ Key='webexperience'; Label='Web Experience Pack (Widgets host)'; Kind='Appx'; Id='MicrosoftWindows.Client.WebExperience'; ProvisionedToo=$true }
    @{ Key='snippingtool';  Label='Snipping Tool';               Kind='Appx'; Id='Microsoft.ScreenSketch';            ProvisionedToo=$true }
    @{ Key='startexp';      Label='Start Experiences App';       Kind='Appx'; Id='Microsoft.StartExperiencesApp';     ProvisionedToo=$true }
    @{ Key='storepurchase'; Label='Store Purchase / Experience Host'; Kind='Appx'; Id='Microsoft.StorePurchaseApp';  ProvisionedToo=$true }
    # Media/image codec extensions (VP9/HEVC/HEIF/WebP/AV1/...). WARNING: removing
    # these can break video/image playback (e.g. HEIF photos, HEVC/VP9 video).
    @{ Key='media-ext';     Label='Media/image codec extensions (VP9/HEVC/HEIF/WebP/AV1) - breaks some playback'; Kind='Appx'; Id='*Extension*'; ProvisionedToo=$true }
    # --- Dev tools / browsers this script installs (DevTool) -------------------
    # Detect = the app's own installed-check (robust vs. winget-list truncation).
    @{ Key='rm-chrome';     Label='Google Chrome';             Kind='DevTool'; Id='Google.Chrome';               Detect='Test-ChromeInstalled' }
    @{ Key='rm-nodejs';     Label='Node.js (nvm-windows)';     Kind='DevTool'; Id='CoreyButler.NVMforWindows';   Detect='Test-NvmInstalled' }
    @{ Key='rm-docker';     Label='Docker Desktop';            Kind='DevTool'; Id='Docker.DockerDesktop';        Detect='Test-DockerInstalled' }
    @{ Key='rm-vscode';     Label='Visual Studio Code';        Kind='DevTool'; Id='Microsoft.VisualStudioCode';  Detect='Test-VSCodeInstalled' }
    @{ Key='rm-dbeaver';    Label='DBeaver';                   Kind='DevTool'; Id='DBeaver.DBeaver';             Detect='Test-DBeaverInstalled' }
    @{ Key='rm-postman';    Label='Postman';                   Kind='DevTool'; Id='Postman.Postman';             Detect='Test-PostmanInstalled' }
    @{ Key='rm-filezilla';  Label='FileZilla';                 Kind='DevTool'; Id='TimKosse.FileZilla.Client';   Detect='Test-FileZillaInstalled' }
    @{ Key='rm-gh';         Label='GitHub CLI';                Kind='DevTool'; Id='GitHub.cli';                  Detect='Test-GhInstalled' }
    @{ Key='rm-cloudflared';Label='Cloudflare Tunnel';         Kind='DevTool'; Id='Cloudflare.cloudflared';      Detect='Test-CloudflaredInstalled' }
    # --- Remote tools (DevTool) ----------------------------------------------
    @{ Key='rm-anydesk';    Label='AnyDesk';                   Kind='DevTool'; Id='AnyDeskSoftwareGmbH.AnyDesk'; Detect='Test-AnyDeskInstalled' }
    @{ Key='rm-rustdesk';   Label='RustDesk';                  Kind='DevTool'; Id='RustDesk.RustDesk';           Detect='Test-RustDeskInstalled' }
    @{ Key='rm-teamviewer'; Label='TeamViewer';                Kind='DevTool'; Id='TeamViewer.TeamViewer';       Detect='Test-TeamViewerInstalled' }
    @{ Key='rm-realvnc';    Label='RealVNC';                   Kind='DevTool'; Id='RealVNC.VNCServer';            Detect='Test-RealVNCInstalled' }
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
            'DevTool' {
                # winget list truncates long Ids and lists MSI/EXE apps under their
                # ARP product code, so a bare winget-id match reports installed apps
                # as "removed". Prefer the app's own Test-*Installed detector, which
                # also checks the command + the registry display name.
                if ($Item.Detect -and (Get-Command $Item.Detect -ErrorAction SilentlyContinue)) {
                    return (-not (& $Item.Detect))
                }
                return (-not (Test-App -WingetId $Item.Id))
            }
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
    Write-LogStep "Debloat - removing selected items"
    if (-not $script:SelectedDebloat -or $script:SelectedDebloat.Count -eq 0) {
        Write-LogInfo "No debloat items selected."
        return
    }
    foreach ($key in $script:SelectedDebloat) {
        $item = $script:DebloatItems | Where-Object { $_.Key -eq $key } | Select-Object -First 1
        if ($item) { Remove-BloatItem -Item $item | Out-Null }
    }
}

# OneDrive remover (that-guy-scott/remove-onedrive) VENDORED inline below. It is
# self-contained PowerShell (no runtime downloads); only the 3 em dashes in its
# comments were changed to ASCII so this file stays ASCII/BOM-safe - the logic is
# the upstream script verbatim. Written to a temp file and run -Force -NoReboot;
# the native method below stays as a fallback.
$script:EMBED_ONEDRIVE = @'
<#
.SYNOPSIS
    Completely removes OneDrive from Windows 11 and restores local folder control.

.DESCRIPTION
    This script will:
    - Uninstall OneDrive application (personal and business)
    - Fix folder redirection for Documents, Desktop, and Pictures
    - Remove OneDrive from File Explorer
    - Block OneDrive from reinstalling
    - Optionally backup OneDrive files before removal

.NOTES
    Version:        2.0
    Author:         OneDrive Removal Script
    Creation Date:  2025
    Requires:       PowerShell 5.1+, Windows 11, Administrator privileges

.PARAMETER BackupPath
    Custom path for OneDrive backup. Default is user profile with timestamp.

.PARAMETER NoBackup
    Skip the backup prompt and do not create a backup.

.PARAMETER NoReboot
    Skip the reboot prompt at the end.

.PARAMETER Silent
    Run in silent mode with minimal output (shows only errors and warnings).
    Safety prompts still appear unless -Force is also specified.

.PARAMETER Force
    Skip the confirmation prompt. Required for fully unattended operation.

.EXAMPLE
    .\Remove-OneDrive.ps1

    Runs the script interactively with prompts for backup and confirmation.

.EXAMPLE
    .\Remove-OneDrive.ps1 -NoBackup -NoReboot

    Runs the script without backup or reboot prompts.

.EXAMPLE
    .\Remove-OneDrive.ps1 -BackupPath "D:\Backups" -Silent -Force

    Creates backup in D:\Backups and runs silently without confirmation prompt.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$BackupPath,

    [Parameter(Mandatory=$false)]
    [switch]$NoBackup,

    [Parameter(Mandatory=$false)]
    [switch]$NoReboot,

    [Parameter(Mandatory=$false)]
    [switch]$Silent,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Note: Admin elevation is handled programmatically in the script
# Do not use -RunAsAdministrator as it prevents custom elevation logic

# ---------------------------------------------
# Configuration
# ---------------------------------------------
$ErrorActionPreference = "Continue"
$script:SilentMode = $Silent.IsPresent
$script:LogFile = "$env:TEMP\Remove-OneDrive_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Cloud-only file attribute flags
$FILE_ATTRIBUTE_OFFLINE = 0x1000
$FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS = 0x400000

# ---------------------------------------------
# Helper Functions
# ---------------------------------------------

function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"

    try {
        Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
    }
    catch {
        # Silently fail if logging doesn't work
    }
}

function Write-Status {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )

    # Log all messages
    Write-Log "$Type : $Message"

    # In silent mode, only show warnings and errors
    if ($script:SilentMode -and $Type -in @("Info", "Success")) {
        return
    }

    switch ($Type) {
        "Info"    { Write-Host "[*] $Message" -ForegroundColor Cyan }
        "Success" { Write-Host "[+] $Message" -ForegroundColor Green }
        "Warning" { Write-Host "[!] $Message" -ForegroundColor Yellow }
        "Error"   { Write-Host "[-] $Message" -ForegroundColor Red }
    }
}

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminElevation {
    Write-Status "This script requires administrator privileges." "Warning"
    Write-Status "Attempting to restart with elevated permissions..." "Info"

    try {
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        foreach ($key in $PSBoundParameters.Keys) {
            $val = $PSBoundParameters[$key]
            if ($val -is [switch]) {
                if ($val) { $argList += " -$key" }
            } else {
                $argList += " -$key `"$val`""
            }
        }
        Start-Process powershell.exe $argList -Verb RunAs
        exit
    }
    catch {
        Write-Status "Failed to elevate privileges. Please run PowerShell as Administrator manually." "Error"
        exit 1
    }
}

function Test-CloudOnlyFile {
    param([System.IO.FileInfo]$File)

    $attrs = [int]$File.Attributes
    return (($attrs -band $FILE_ATTRIBUTE_OFFLINE) -ne 0) -or (($attrs -band $FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS) -ne 0)
}

function Find-OneDrivePaths {
    Write-Status "Scanning for OneDrive folders..." "Info"

    $paths = @()
    $candidates = Get-ChildItem -Path $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "OneDrive" -or $_.Name -like "OneDrive - *" } |
        Where-Object { $_.Name -notlike "OneDrive_Backup_*" -and $_.Name -notlike "OneDrive_Conflicts*" }

    foreach ($dir in $candidates) {
        $paths += $dir.FullName
        Write-Status "Found OneDrive folder: $($dir.FullName)" "Info"
    }

    if ($paths.Count -eq 0) {
        Write-Status "No OneDrive folders found." "Info"
    }

    return $paths
}

function Backup-OneDriveFolders {
    param(
        [string]$CustomBackupPath,
        [string[]]$OneDrivePaths
    )

    Write-Status "Backing up OneDrive folders..." "Info"

    if ($CustomBackupPath) {
        $backupRoot = Join-Path $CustomBackupPath "OneDrive_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    } else {
        $backupRoot = "$env:USERPROFILE\OneDrive_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }

    $backedUp = $false

    foreach ($oneDrivePath in $OneDrivePaths) {
        if (Test-Path $oneDrivePath) {
            try {
                # Check available disk space
                $oneDriveSize = (Get-ChildItem -Path $oneDrivePath -Recurse -Force -ErrorAction SilentlyContinue |
                                Measure-Object -Property Length -Sum).Sum
                $targetDrive = Get-Item $backupRoot -ErrorAction SilentlyContinue
                if (-not $targetDrive) {
                    $targetDrive = Get-Item (Split-Path $backupRoot -Parent) -ErrorAction SilentlyContinue
                }
                if ($targetDrive) {
                    $drive = Get-PSDrive -Name $targetDrive.PSDrive.Name -ErrorAction SilentlyContinue
                    if ($drive -and $drive.Free -lt ($oneDriveSize * 1.1)) {
                        Write-Status "Insufficient disk space for backup of $oneDrivePath. Need $([math]::Round($oneDriveSize/1GB, 2))GB" "Error"
                        continue
                    }
                }

                $folderName = Split-Path $oneDrivePath -Leaf
                $backupPath = Join-Path $backupRoot $folderName
                Write-Status "Creating backup at: $backupPath" "Info"
                Copy-Item -Path $oneDrivePath -Destination $backupPath -Recurse -Force -ErrorAction Stop
                Write-Status "Backup of $folderName completed." "Success"
                $backedUp = $true
            }
            catch {
                Write-Status "Backup failed for $oneDrivePath : $_" "Error"
            }
        }
    }

    if ($backedUp) {
        Write-Status "Backup completed successfully!" "Success"
        return $backupRoot
    }
    return $null
}

function Stop-OneDriveProcesses {
    Write-Status "Stopping OneDrive processes..." "Info"

    $processes = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue

    if ($processes) {
        $processes | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        # Verify they stopped
        $remaining = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
        if ($remaining) {
            Write-Status "Some OneDrive processes could not be stopped." "Warning"
            return $false
        }
        Write-Status "OneDrive processes stopped." "Success"
    }
    else {
        Write-Status "No OneDrive processes running." "Info"
    }
    return $true
}

function Uninstall-OneDrive {
    Write-Status "Uninstalling OneDrive..." "Info"

    # Try winget first (modern method)
    try {
        $wingetResult = winget uninstall "Microsoft OneDrive" --silent --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "OneDrive uninstalled via winget." "Success"
            Write-Log "Winget output: $wingetResult"
            return $true
        }
        Write-Log "Winget output: $wingetResult"
    }
    catch {
        Write-Status "Winget uninstall failed, trying alternative method..." "Warning"
    }

    # Fallback to OneDriveSetup.exe
    $setupPaths = @(
        "$env:SystemRoot\System32\OneDriveSetup.exe",
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    )

    foreach ($setupPath in $setupPaths) {
        if (Test-Path $setupPath) {
            try {
                Write-Status "Running uninstaller: $setupPath" "Info"
                $process = Start-Process -FilePath $setupPath -ArgumentList "/uninstall" -Wait -NoNewWindow -PassThru
                if ($process.ExitCode -eq 0) {
                    Write-Status "OneDrive uninstalled successfully." "Success"
                    return $true
                }
                Write-Status "Uninstaller exited with code $($process.ExitCode)." "Error"
            }
            catch {
                Write-Status "Failed to run uninstaller: $_" "Error"
            }
        }
    }

    Write-Status "Could not find OneDrive uninstaller. It may already be uninstalled." "Warning"
    return $false
}

function Move-OneDriveFilesToLocal {
    param(
        [string[]]$OneDrivePaths
    )

    Write-Status "Moving files from OneDrive folders to local folders..." "Info"

    $counts = @{ Moved = 0; Conflicted = 0; CloudOnly = 0; Failed = 0 }
    $conflictsPath = "$env:USERPROFILE\OneDrive_Conflicts"

    foreach ($oneDrivePath in $OneDrivePaths) {
        $oneDriveRootName = Split-Path $oneDrivePath -Leaf
        $subFolders = @(
            @{OneDrive = "$oneDrivePath\Documents"; Local = "$env:USERPROFILE\Documents"},
            @{OneDrive = "$oneDrivePath\Desktop"; Local = "$env:USERPROFILE\Desktop"},
            @{OneDrive = "$oneDrivePath\Pictures"; Local = "$env:USERPROFILE\Pictures"}
        )

        foreach ($folder in $subFolders) {
            # Ensure local folder exists
            if (-not (Test-Path $folder.Local)) {
                New-Item -ItemType Directory -Path $folder.Local -Force | Out-Null
                Write-Status "Created local folder: $($folder.Local)" "Info"
            }

            # Move files if OneDrive folder exists
            if (Test-Path $folder.OneDrive) {
                try {
                    $items = Get-ChildItem -Path $folder.OneDrive -Force -ErrorAction SilentlyContinue

                    if ($items) {
                        foreach ($item in $items) {
                            # Check for cloud-only placeholder files
                            if (-not $item.PSIsContainer -and (Test-CloudOnlyFile $item)) {
                                Write-Status "Skipping cloud-only file: $($item.Name) (download from OneDrive web first)" "Warning"
                                $counts.CloudOnly++
                                continue
                            }

                            $destination = Join-Path $folder.Local $item.Name

                            if (Test-Path $destination) {
                                if (-not $item.PSIsContainer) {
                                    $sourceFile = Get-Item $item.FullName
                                    $destFile = Get-Item $destination

                                    if ($sourceFile.LastWriteTime -gt $destFile.LastWriteTime) {
                                        # Source is newer - update destination, remove source
                                        Write-Status "Updating newer file: $($item.Name)" "Info"
                                        Copy-Item -Path $item.FullName -Destination $folder.Local -Force -ErrorAction Stop
                                        Remove-Item -Path $item.FullName -Force
                                        $counts.Moved++
                                    } else {
                                        # Destination is newer - save source to conflicts folder
                                        Write-Status "Conflict (destination newer): $($item.Name)" "Warning"
                                        $conflictDest = Join-Path (Join-Path $conflictsPath $oneDriveRootName) (Split-Path $folder.OneDrive -Leaf)
                                        if (-not (Test-Path $conflictDest)) {
                                            New-Item -ItemType Directory -Path $conflictDest -Force | Out-Null
                                        }
                                        Move-Item -Path $item.FullName -Destination $conflictDest -Force
                                        $counts.Conflicted++
                                    }
                                } else {
                                    # Directory - merge contents then remove source
                                    Write-Status "Merging directory: $($item.Name)" "Info"
                                    Copy-Item -Path $item.FullName -Destination $folder.Local -Recurse -Force -ErrorAction Stop
                                    Remove-Item -Path $item.FullName -Recurse -Force
                                    $counts.Moved++
                                }
                            }
                            else {
                                Write-Status "Moving: $($item.Name)" "Info"
                                Move-Item -Path $item.FullName -Destination $folder.Local -Force
                                $counts.Moved++
                            }
                        }
                    }
                }
                catch {
                    Write-Status "Error moving files from $($folder.OneDrive): $_" "Error"
                    $counts.Failed++
                }
            }
        }
    }

    # Summary
    Write-Status "File migration summary: $($counts.Moved) moved, $($counts.Conflicted) conflicted, $($counts.CloudOnly) cloud-only skipped, $($counts.Failed) failed" "Info"

    if ($counts.Conflicted -gt 0) {
        Write-Status "Conflicting files saved to: $conflictsPath" "Warning"
    }
    if ($counts.CloudOnly -gt 0) {
        Write-Status "Cloud-only files were skipped. Download them from onedrive.live.com before deleting OneDrive folders." "Warning"
    }

    return $counts
}

function Fix-FolderRedirection {
    Write-Status "Fixing folder redirection in registry..." "Info"

    $userShellFoldersPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    $shellFoldersPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"

    $redirections = @(
        @{Name = "Personal"; ExpandPath = "%USERPROFILE%\Documents"; ResolvedPath = "$env:USERPROFILE\Documents"; Description = "Documents"},
        @{Name = "Desktop"; ExpandPath = "%USERPROFILE%\Desktop"; ResolvedPath = "$env:USERPROFILE\Desktop"; Description = "Desktop"},
        @{Name = "My Pictures"; ExpandPath = "%USERPROFILE%\Pictures"; ResolvedPath = "$env:USERPROFILE\Pictures"; Description = "Pictures"}
    )

    $success = $true

    foreach ($redirect in $redirections) {
        try {
            # User Shell Folders uses expandable strings with %USERPROFILE%
            Set-ItemProperty -Path $userShellFoldersPath -Name $redirect.Name -Value $redirect.ExpandPath -Type ExpandString -Force
            # Shell Folders uses resolved paths
            Set-ItemProperty -Path $shellFoldersPath -Name $redirect.Name -Value $redirect.ResolvedPath -Type String -Force
            Write-Status "Fixed redirection for $($redirect.Description)" "Success"
        }
        catch {
            Write-Status "Failed to fix redirection for $($redirect.Description): $_" "Error"
            $success = $false
        }
    }

    # Clean up OneDrive-related registry keys
    Write-Status "Cleaning up OneDrive registry entries..." "Info"

    $oneDriveRegPaths = @(
        "HKCU:\Software\Microsoft\OneDrive",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    )

    foreach ($regPath in $oneDriveRegPaths) {
        if (Test-Path $regPath) {
            try {
                Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Status "Removed registry key: $regPath" "Success"
            }
            catch {
                Write-Status "Could not remove registry key: $regPath" "Warning"
            }
        }
    }

    return $success
}

function Block-OneDriveReinstallation {
    Write-Status "Blocking OneDrive from reinstalling..." "Info"

    $policyPath = "HKLM:\Software\Policies\Microsoft\Windows\OneDrive"

    try {
        # Create policy key if it doesn't exist
        if (-not (Test-Path $policyPath)) {
            New-Item -Path $policyPath -Force | Out-Null
        }

        # Disable OneDrive file sync
        Set-ItemProperty -Path $policyPath -Name "DisableFileSync" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $policyPath -Name "DisableFileSyncNGSC" -Value 1 -Type DWord -Force

        Write-Status "OneDrive reinstallation blocked via registry policy." "Success"
        return $true
    }
    catch {
        Write-Status "Failed to set registry policy: $_" "Error"
        return $false
    }
}

function Remove-OneDriveFromExplorer {
    Write-Status "Removing OneDrive from File Explorer..." "Info"

    $clsids = @(
        "Registry::HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}",
        "Registry::HKEY_CLASSES_ROOT\WOW6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    )

    foreach ($clsid in $clsids) {
        if (Test-Path $clsid) {
            try {
                Remove-Item -Path $clsid -Recurse -Force -ErrorAction SilentlyContinue
                Write-Status "Removed OneDrive CLSID from registry." "Success"
            }
            catch {
                Write-Status "Could not remove CLSID (may require ownership change): $_" "Warning"
            }
        }
    }
    return $true
}

function Restart-Explorer {
    Write-Status "Restarting Windows Explorer to apply changes..." "Info"

    try {
        Stop-Process -Name explorer -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        Start-Process explorer.exe
        Write-Status "Explorer restarted successfully." "Success"
        return $true
    }
    catch {
        Write-Status "Failed to restart Explorer: $_" "Error"
        return $false
    }
}

function Remove-OneDriveStartupEntry {
    Write-Status "Removing OneDrive from startup..." "Info"

    $startupPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach ($path in $startupPaths) {
        try {
            $oneDriveRun = Get-ItemProperty -Path $path -Name "OneDrive" -ErrorAction SilentlyContinue
            if ($oneDriveRun) {
                Remove-ItemProperty -Path $path -Name "OneDrive" -Force
                Write-Status "Removed OneDrive from startup registry." "Success"
            }
        }
        catch {
            # Silently continue if entry doesn't exist
        }
    }
    return $true
}

function Remove-OneDriveFolder {
    param(
        [string[]]$OneDrivePaths
    )

    Write-Status "Checking for empty OneDrive folders..." "Info"

    foreach ($oneDrivePath in $OneDrivePaths) {
        if (Test-Path $oneDrivePath) {
            $items = Get-ChildItem -Path $oneDrivePath -Force -ErrorAction SilentlyContinue

            if (-not $items -or $items.Count -eq 0) {
                try {
                    Remove-Item -Path $oneDrivePath -Force -Recurse -ErrorAction Stop
                    Write-Status "Removed empty OneDrive folder: $oneDrivePath" "Success"
                }
                catch {
                    Write-Status "Could not remove OneDrive folder $oneDrivePath : $_" "Warning"
                }
            }
            else {
                Write-Status "OneDrive folder is not empty, skipping: $oneDrivePath" "Warning"
                Write-Status "You can manually delete it later: $oneDrivePath" "Info"
            }
        }
    }
    return $true
}

# ---------------------------------------------
# Main Script
# ---------------------------------------------

function Main {
    Clear-Host

    Write-Host @"
+============================================================+
|                                                            |
|        OneDrive Complete Removal Script for Windows 11     |
|                                                            |
+============================================================+
"@ -ForegroundColor Magenta

    Write-Host ""
    Write-Status "This script will completely remove OneDrive from your system." "Info"
    Write-Status "It will:" "Info"
    Write-Host "  * Uninstall OneDrive application"
    Write-Host "  * Move files from OneDrive folders to local folders"
    Write-Host "  * Fix folder redirection (Documents, Desktop, Pictures)"
    Write-Host "  * Remove OneDrive from File Explorer"
    Write-Host "  * Block OneDrive from reinstalling"
    Write-Host ""

    # Check for admin privileges
    if (-not (Test-AdminPrivileges)) {
        Request-AdminElevation
    }

    # Detect OneDrive folders
    $oneDrivePaths = Find-OneDrivePaths

    if ($oneDrivePaths.Count -gt 0) {
        Write-Host ""
        Write-Status "The following OneDrive folders will be processed:" "Info"
        foreach ($p in $oneDrivePaths) {
            Write-Host "  * $p"
        }
        Write-Host ""
    }

    # Confirmation (skipped with -Force)
    if (-not $Force) {
        $confirm = Read-Host "Do you want to proceed? (Y/N)"
        if ($confirm -ne "Y" -and $confirm -ne "y") {
            Write-Status "Operation cancelled by user." "Warning"
            exit 0
        }
    }

    Write-Host ""

    # Ask about backup (skipped with -NoBackup)
    if (-not $NoBackup -and $oneDrivePaths.Count -gt 0) {
        if ($Force) {
            # Force mode with no -NoBackup: create backup automatically
            $backupResult = Backup-OneDriveFolders -CustomBackupPath $BackupPath -OneDrivePaths $oneDrivePaths
            if ($backupResult) {
                Write-Status "Backup saved to: $backupResult" "Success"
            }
        } else {
            $backup = Read-Host "Do you want to backup your OneDrive folder first? (Y/N - Recommended)"
            if ($backup -eq "Y" -or $backup -eq "y") {
                $backupResult = Backup-OneDriveFolders -CustomBackupPath $BackupPath -OneDrivePaths $oneDrivePaths
                if ($backupResult) {
                    Write-Status "Backup saved to: $backupResult" "Success"
                }
            }
        }
    }

    Write-Host ""
    Write-Status "Starting OneDrive removal process..." "Info"
    Write-Log "Starting OneDrive removal process"
    Write-Host ""

    # Execute removal steps and track results
    $stepResults = @{}

    # 1. Stop processes
    $stepResults["StopProcesses"] = Stop-OneDriveProcesses

    # 2. Remove startup entry
    $stepResults["RemoveStartup"] = Remove-OneDriveStartupEntry

    # 3. Uninstall BEFORE moving files (so OneDrive can't sync/lock during migration)
    $stepResults["Uninstall"] = Uninstall-OneDrive

    # 4. Move files to local folders (after uninstall)
    $migrationCounts = Move-OneDriveFilesToLocal -OneDrivePaths $oneDrivePaths
    $stepResults["MoveFiles"] = ($migrationCounts.Failed -eq 0)

    # 5. Fix folder redirection
    $stepResults["FixRedirection"] = Fix-FolderRedirection

    # 6. Block reinstallation
    $stepResults["BlockReinstall"] = Block-OneDriveReinstallation

    # 7. Remove from Explorer
    $stepResults["RemoveFromExplorer"] = Remove-OneDriveFromExplorer

    # 8. Clean up empty folders
    $stepResults["RemoveFolder"] = Remove-OneDriveFolder -OneDrivePaths $oneDrivePaths

    # 9. Restart Explorer
    $stepResults["RestartExplorer"] = Restart-Explorer

    # Determine overall result
    $failedSteps = $stepResults.GetEnumerator() | Where-Object { $_.Value -eq $false } | ForEach-Object { $_.Key }
    $criticalFailures = $failedSteps | Where-Object { $_ -in @("Uninstall", "MoveFiles", "FixRedirection") }

    # Summary
    Write-Host ""

    if ($criticalFailures) {
        Write-Host @"
+============================================================+
|                   REMOVAL PARTIALLY FAILED                  |
+============================================================+
"@ -ForegroundColor Red

        Write-Host ""
        Write-Status "OneDrive removal encountered critical failures:" "Error"
        foreach ($step in $failedSteps) {
            Write-Status "  Failed: $step" "Error"
        }
        Write-Host ""
        Write-Status "Your system may be in an intermediate state." "Warning"
        Write-Status "Check the log file for details: $script:LogFile" "Warning"
        Write-Status "See the README for rollback instructions if needed." "Warning"
    }
    elseif ($failedSteps) {
        Write-Host @"
+============================================================+
|                REMOVAL COMPLETED WITH WARNINGS              |
+============================================================+
"@ -ForegroundColor Yellow

        Write-Host ""
        Write-Status "OneDrive was removed but some non-critical steps had issues:" "Warning"
        foreach ($step in $failedSteps) {
            Write-Status "  Warning: $step" "Warning"
        }
    }
    else {
        Write-Host @"
+============================================================+
|                      REMOVAL COMPLETE                       |
+============================================================+
"@ -ForegroundColor Green

        Write-Host ""
        Write-Status "OneDrive has been completely removed!" "Success"
    }

    Write-Host ""
    Write-Status "Your files are now in local folders:" "Info"
    Write-Host "  * Documents: $env:USERPROFILE\Documents"
    Write-Host "  * Desktop:   $env:USERPROFILE\Desktop"
    Write-Host "  * Pictures:  $env:USERPROFILE\Pictures"

    if ($migrationCounts.CloudOnly -gt 0) {
        Write-Host ""
        Write-Status "$($migrationCounts.CloudOnly) cloud-only files were skipped. Download them from onedrive.live.com" "Warning"
    }
    if ($migrationCounts.Conflicted -gt 0) {
        Write-Host ""
        Write-Status "$($migrationCounts.Conflicted) conflicting files saved to: $env:USERPROFILE\OneDrive_Conflicts" "Warning"
    }

    Write-Host ""
    Write-Status "Next steps:" "Info"
    Write-Host "  1. Restart your computer to ensure all changes take effect"
    Write-Host "  2. Verify your files are in the correct locations"
    Write-Host ""
    Write-Status "Log file saved to: $script:LogFile" "Info"
    Write-Host ""

    if (-not $NoReboot) {
        if ($Force) {
            Write-Status "Restarting computer in 10 seconds..." "Info"
            Write-Log "Auto-restart initiated (Force mode)"
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        } else {
            $reboot = Read-Host "Would you like to restart now? (Y/N)"
            if ($reboot -eq "Y" -or $reboot -eq "y") {
                Write-Status "Restarting computer in 10 seconds..." "Info"
                Write-Log "User initiated system restart"
                Start-Sleep -Seconds 10
                Restart-Computer -Force
            }
            else {
                Write-Status "Please restart your computer when convenient." "Info"
            }
        }
    }
    else {
        Write-Status "Please restart your computer when convenient." "Info"
    }

    Write-Log "OneDrive removal completed"
}

# Execute main function
Main

'@

function Remove-OneDrive {
    Write-LogInfo "OneDrive: running the vendored remover (that-guy-scott/remove-onedrive)..."
    try {
        $tmp = Join-Path $env:TEMP 'vendored-Remove-OneDrive.ps1'
        [System.IO.File]::WriteAllText($tmp, $script:EMBED_ONEDRIVE)
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tmp -Force -NoReboot
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        if (Test-OneDriveRemoved) { Write-LogSuccess "OneDrive removed (vendored tool)."; return $true }
        Write-LogWarning "Vendored tool ran but OneDrive is still present; trying the native method."
    } catch {
        Write-LogWarning "Vendored OneDrive tool error: $($_.Exception.Message); trying the native method."
    }
    return (Remove-OneDriveNative)
}

#===============================================================================
# OneDrive removal - native fallback (canonical method used by popular debloat
# tools): kill the client, run the built-in OneDriveSetup /uninstall, drop
# scheduled tasks, unpin from Explorer, and delete leftover folders.
#===============================================================================
function Remove-OneDriveNative {
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
# Microsoft Edge removal (self-contained; NO third-party downloads).
# The removal LOGIC is ported from ShadowWhisperer/Remove-MS-Edge (Both.bat):
# uninstall Edge, strip AppX, delete update tasks/services/folders, and clean the
# registry + System32 stubs. WebView2 is deliberately KEPT (many apps need it), so
# the WebView uninstall/folder-delete steps are skipped. Their tool ships its own
# setup.exe; we use
# the SYSTEM's own setup.exe instead (after the EdgeUpdateDev\AllowUninstall
# unblock), so nothing is downloaded. The heavy AppX registry-surgery and the
# malformed-key fixer from the .bat are intentionally omitted (too risky to port);
# Remove-AppxPackage covers the common case. Opt-in from the Debloat sub-menu.
#===============================================================================
function Remove-MicrosoftEdge {
    Write-LogWarning "Force-removing Microsoft Edge (WebView2 is deliberately KEPT; Windows can reinstall Edge)."
    $pf86 = ${env:ProgramFiles(x86)}; if (-not $pf86) { $pf86 = $env:ProgramFiles }

    # Run every Installer\setup.exe found under $root with $setupArgs (best-effort).
    $runSetup = {
        param([string]$root, [string]$setupArgs)
        if (-not (Test-Path $root)) { return }
        Get-ChildItem -Path $root -Recurse -Filter 'setup.exe' -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like '*\Installer\setup.exe' } |
            ForEach-Object { try { Start-Process -FilePath $_.FullName -ArgumentList $setupArgs -Wait -ErrorAction SilentlyContinue } catch { } }
    }

    try {
        # 1) Unblock uninstall + stop every Edge-related process
        try {
            New-Item -Path 'HKLM:\SOFTWARE\Microsoft\EdgeUpdateDev' -Force -ErrorAction SilentlyContinue | Out-Null
            New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\EdgeUpdateDev' -Name 'AllowUninstall' -Value '' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
        } catch { }
        foreach ($proc in @('msedge','msedgewebview2','MicrosoftEdgeUpdate','WebViewHost','identity_helper','elevation_service')) {
            Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }

        # 2) Uninstall Edge - registered UninstallString first, else system setup.exe
        Write-LogInfo "Removing Edge..."
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
                    if ($rest -notmatch '--system-level')    { $rest = ($rest + ' --system-level').Trim() }
                    try { Start-Process -FilePath $exe -ArgumentList $rest -Wait -ErrorAction SilentlyContinue; $done = $true } catch { }
                }
            }
        }
        if (-not $done) { & $runSetup "$pf86\Microsoft\Edge\Application" '--uninstall --system-level --force-uninstall' }

        # 3) WebView2 is intentionally KEPT (many apps depend on it) - not uninstalled.

        # 4) Strip Edge AppX packages (all users + provisioned)
        Write-LogInfo "Removing Edge AppX packages..."
        try {
            Get-AppxPackage -AllUsers -Name '*MicrosoftEdge*' -ErrorAction SilentlyContinue |
                ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like '*MicrosoftEdge*' } |
                ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
        } catch { }

        # 5) Delete leftover folders (NOT EdgeWebView - WebView2 is kept)
        foreach ($d in @("$pf86\Microsoft\Edge","$pf86\Microsoft\EdgeCore","$pf86\Microsoft\EdgeUpdate",
                         "$pf86\Microsoft\Temp","$env:ProgramData\Microsoft\EdgeUpdate")) {
            Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
        }

        # 6) Remove Edge update scheduled tasks
        try {
            Get-ScheduledTask -ErrorAction SilentlyContinue |
                Where-Object { $_.TaskName -like '*MicrosoftEdge*' -or $_.TaskName -like '*edgeupdate*' -or $_.TaskName -like '*Edge Update*' } |
                Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
        } catch { }

        # 7) Remove Edge update / elevation services
        foreach ($svc in @('edgeupdate','edgeupdatem','MicrosoftEdgeElevationService')) {
            try {
                $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
                if ($s) { if ($s.Status -eq 'Running') { Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue }; & sc.exe delete $svc > $null 2>&1 }
            } catch { }
        }

        # 8) takeown + delete the SystemApps / WindowsApps Edge directories
        foreach ($globroot in @("$env:SystemRoot\SystemApps","$env:ProgramFiles\WindowsApps")) {
            if (Test-Path $globroot) {
                Get-ChildItem -Path $globroot -Directory -Filter 'Microsoft.MicrosoftEdge*' -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        & takeown.exe /f $_.FullName /r /d y > $null 2>&1
                        & icacls.exe $_.FullName /grant "$($env:UserName):F" /t /c > $null 2>&1
                        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    } catch { }
                }
            }
        }

        # 9) Extra registry keys (ported reg-delete list)
        foreach ($k in @(
                'HKLM\SOFTWARE\Classes\AppID\MicrosoftEdgeUpdate.exe',
                'HKLM\SOFTWARE\Classes\AppID\{1FCBE96C-1697-43AF-9140-2897C7C69767}',
                'HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components\{9459C573-B17A-45AE-9F64-1857B5D58CEE}',
                'HKLM\SOFTWARE\Microsoft\Edge','HKLM\SOFTWARE\Microsoft\EdgeUpdate','HKLM\SOFTWARE\Microsoft\MicrosoftEdge',
                'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\MicrosoftEdgeUpdate.exe',
                'HKLM\SOFTWARE\Microsoft\Internet Explorer\EdgeDebugActivation',
                'HKLM\SOFTWARE\Microsoft\Internet Explorer\EdgeIntegration',
                'HKLM\SOFTWARE\WOW6432Node\Microsoft\Edge','HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate',
                'HKLM\SOFTWARE\WOW6432Node\Microsoft\MicrosoftEdge')) {
            & reg.exe delete $k /f > $null 2>&1
        }

        # 10) takeown + delete the System32 MicrosoftEdge*.exe stubs
        Get-ChildItem -Path "$env:SystemRoot\System32" -Filter 'MicrosoftEdge*.exe' -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                & takeown.exe /f $_.FullName > $null 2>&1
                & icacls.exe $_.FullName /grant "$($env:UserName):F" /c > $null 2>&1
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            } catch { }
        }

        # 11) Shortcuts + Run entries
        Remove-Item -LiteralPath "$env:PUBLIC\Desktop\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk" -Force -ErrorAction SilentlyContinue
        $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $ri = Get-Item -Path $run -ErrorAction SilentlyContinue
        if ($ri) {
            foreach ($name in $ri.Property) {
                if ($name -like 'MicrosoftEdgeAutoLaunch*' -or $name -eq 'Microsoft Edge Update') {
                    Remove-ItemProperty -Path $run -Name $name -ErrorAction SilentlyContinue
                }
            }
        }

        if (Test-EdgeRemoved) { Write-LogSuccess "Edge removed."; return $true }
        Write-LogWarning "Edge uninstall ran but msedge.exe is still present (Windows may be re-protecting it); reboot and re-run if needed."
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
# Interactive TUI menu - flicker-free, birebir with the source's arrow-key menu.
#
# Performance notes (these were the reported lag/flicker causes):
#   * We redraw by moving the cursor to (0,0) and OVERWRITING padded lines every
#     frame - NEVER Clear-Host per keypress. Clear-Host happens only on entry and
#     when returning from a sub-menu.
#   * Status markers (installed/applied/removed) are computed ONCE before the loop
#     (detection hits winget/registry and is slow), never per frame.
#===============================================================================

# Menu-driven selection state (also consumed by the flag dispatcher)
$script:SelectedTweaks      = @()
$script:SelectedDebloat     = @()
$script:SelectedVSCodeExt   = @()
# Explorer/UI tweaks are two-way, so the selection carries a direction:
# key -> 'apply' | 'revert'.
$script:SelectedUiTweaks    = @{}
$script:SelectedAliases     = @()
$script:AliasesTouched      = $false
$script:VSCodeApplySettings = $true
$script:HostnameValue       = $null
$script:_MainRows           = $null

function Set-MenuCursorVisible { param([bool]$Visible) try { [System.Console]::CursorVisible = $Visible } catch { } }

# Smooth spinner: a background runspace animates "<Text>. .. ..." on the current line
# (via `r, so it stays aligned at column 0) while the main thread does slow work.
# The worker only touches [System.Console]::Write; the caller must stay silent meanwhile.
function Start-Spinner {
    param([string]$Text = 'Working')
    try {
        $sync = [hashtable]::Synchronized(@{ Stop = $false })
        $psr = [powershell]::Create()
        [void]$psr.AddScript({
            param($sync, $text)
            try { [System.Console]::CursorVisible = $false } catch { }
            $frames = @('.  ', '.. ', '...')
            $i = 0
            while (-not $sync.Stop) {
                try { [System.Console]::Write("`r" + $text + $frames[$i % $frames.Length]) } catch { }
                Start-Sleep -Milliseconds 120
                $i++
            }
        })
        [void]$psr.AddArgument($sync)
        [void]$psr.AddArgument($Text)
        $handle = $psr.BeginInvoke()
        return @{ Ps = $psr; Handle = $handle; Sync = $sync; Width = ($Text.Length + 6) }
    } catch {
        # Runspaces unavailable: fall back to a plain static line.
        try { [System.Console]::Write("`r" + $Text + '...') } catch { }
        return $null
    }
}

function Stop-Spinner {
    param($Spinner)
    if ($Spinner) {
        try { $Spinner.Sync.Stop = $true } catch { }
        try { [void]$Spinner.Ps.EndInvoke($Spinner.Handle) } catch { }
        try { $Spinner.Ps.Dispose() } catch { }
    }
    try { [System.Console]::Write("`r" + (' ' * 44) + "`r") } catch { }
    Set-MenuCursorVisible $true
}

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
#               SelectedCheck (optional scriptblock -> bool for derived rows),
#               Tri + State   (tri-state rows: 0 = off, 1 = apply, 2 = revert),
#               NoRevert      (tri-state row with nothing to undo: skips state 2)
#-------------------------------------------------------------------------------
# ANSI SGR color codes (ConsoleColor name -> code) for the single-write renderer.
$script:_ansi = @{ Cyan = '36'; Green = '32'; Yellow = '33'; Blue = '34'; Gray = '37'; DarkGray = '90'; White = '97'; Red = '31' }
$script:_vtEnabled = $null

# Enable the console's virtual-terminal processing (so ANSI escapes render). Cached.
function Enable-VirtualTerminal {
    if ($null -ne $script:_vtEnabled) { return $script:_vtEnabled }
    $script:_vtEnabled = $false
    try {
        if (-not ([System.Management.Automation.PSTypeName]'WsVt.Kernel').Type) {
            Add-Type -Namespace WsVt -Name Kernel -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError=true)] public static extern System.IntPtr GetStdHandle(int n);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetConsoleMode(System.IntPtr h, out uint m);
[DllImport("kernel32.dll", SetLastError=true)] public static extern bool SetConsoleMode(System.IntPtr h, uint m);
'@ -ErrorAction Stop
        }
        $h = [WsVt.Kernel]::GetStdHandle(-11)   # STD_OUTPUT_HANDLE
        $m = [uint32]0
        if ([WsVt.Kernel]::GetConsoleMode($h, [ref]$m)) {
            $script:_vtEnabled = [WsVt.Kernel]::SetConsoleMode($h, ($m -bor 0x0004))  # ENABLE_VIRTUAL_TERMINAL_PROCESSING
        }
    } catch { $script:_vtEnabled = $false }
    return $script:_vtEnabled
}

# Render one line (segment list) as ANSI, truncated to the width, ending with erase-to-EOL.
function Get-AnsiLine {
    param([object[]]$Segs, [int]$Width)
    $e = [char]27
    $sb = New-Object System.Text.StringBuilder
    $len = 0; $max = [Math]::Max(1, $Width - 1)
    foreach ($s in $Segs) {
        if ($len -ge $max) { break }
        $t = [string]$s.t
        if ($t.Length -eq 0) { continue }
        if (($len + $t.Length) -gt $max) { $t = $t.Substring(0, ($max - $len)) }
        $len += $t.Length
        if ($s.c -and $script:_ansi.ContainsKey($s.c)) {
            [void]$sb.Append($e).Append('[').Append($script:_ansi[$s.c]).Append('m').Append($t).Append($e).Append('[0m')
        } else {
            [void]$sb.Append($t)
        }
    }
    [void]$sb.Append($e).Append('[K')   # erase to end of line (clears any leftover)
    return $sb.ToString()
}

function Invoke-SelectMenu {
    param(
        [object[]]$Header = @(),
        [string]$Banner = '',
        [System.Collections.ArrayList]$Rows,
        [scriptblock]$Summary,
        [scriptblock]$OnSelectAll,
        [scriptblock]$OnSelectNone,
        [switch]$TriMode,
        [switch]$SubMenu
    )
    $cursor = 0
    $scrollTop = 0
    $numBuf = ''
    $needClear = $false
    $vt = Enable-VirtualTerminal
    $e = [char]27
    Set-MenuCursorVisible $false
    Clear-Host
    try {
        while ($true) {
            # --- Scrolling viewport: render only the rows that fit on screen, and
            #     scroll the window to keep the cursor visible. Prevents a long list
            #     (e.g. 50+ debloat items) from overflowing and scrolling the header
            #     off the top of the terminal. Row-window height is kept constant so
            #     the frame never grows past the window (no terminal scroll).
            $winH = 30; try { $winH = [System.Console]::WindowHeight } catch { }
            $topChrome = $Header.Count + 5   # header + ===/banner/=== + blank + scroll-up marker
            $botChrome = 4                    # scroll-down marker + --- + summary + hint
            $viewport = $winH - $topChrome - $botChrome - 1
            if ($viewport -lt 3) { $viewport = 3 }
            if ($viewport -gt $Rows.Count) { $viewport = $Rows.Count }
            if ($cursor -lt $scrollTop) { $scrollTop = $cursor }
            elseif ($cursor -ge ($scrollTop + $viewport)) { $scrollTop = $cursor - $viewport + 1 }
            $maxTop = [Math]::Max(0, $Rows.Count - $viewport)
            if ($scrollTop -gt $maxTop) { $scrollTop = $maxTop }
            if ($scrollTop -lt 0) { $scrollTop = 0 }

            # Build the whole frame as an ordered list of segment-lines.
            $lines = New-Object System.Collections.ArrayList
            foreach ($h in $Header) { [void]$lines.Add(@($h)) }
            [void]$lines.Add(@(@{ t = '  ==============================================================='; c = 'Green' }))
            [void]$lines.Add(@(@{ t = ("   {0}" -f $Banner); c = 'Green' }))
            [void]$lines.Add(@(@{ t = '  ==============================================================='; c = 'Green' }))
            [void]$lines.Add(@(@{ t = '' }))
            # scroll-up marker (always present so the row window keeps a constant height)
            if ($scrollTop -gt 0) { [void]$lines.Add(@(@{ t = ("      ^^^  {0} more above" -f $scrollTop); c = 'DarkGray' })) }
            else                  { [void]$lines.Add(@(@{ t = '' })) }
            $viewEnd = [Math]::Min($Rows.Count, $scrollTop + $viewport)
            for ($i = $scrollTop; $i -lt $viewEnd; $i++) {
                $r = $Rows[$i]
                $sel = if ($r.SelectedCheck) { [bool](& $r.SelectedCheck) } else { [bool]$r.Selected }
                $segs = @()
                if ($i -eq $cursor) { $segs += @{ t = ' > '; c = 'Cyan' } } else { $segs += @{ t = '   ' } }
                $segs += @{ t = ('[{0,2}] ' -f $r.Num); c = 'Blue' }
                if ($r.IsGroup) {
                    $segs += @{ t = $(if ($sel) { '[+] ' } else { '[ ] ' }); c = $(if ($sel) { 'Green' } else { 'DarkGray' }) }
                    $segs += @{ t = $r.Label; c = $(if ($sel) { 'Green' } else { 'White' }) }
                } elseif ($r.Tri) {
                    # Tri-state: 0 = leave alone, 1 = apply, 2 = revert.
                    $st = [int]$r.State
                    if     ($st -eq 1) { $segs += @{ t = '[x] '; c = 'Green'  }; $segs += @{ t = $r.Label; c = 'Green'  } }
                    elseif ($st -eq 2) { $segs += @{ t = '[r] '; c = 'Yellow' }; $segs += @{ t = $r.Label; c = 'Yellow' } }
                    else               { $segs += @{ t = '[ ] '; c = 'Gray'   }; $segs += @{ t = $r.Label; c = 'White'  } }
                } else {
                    $segs += @{ t = $(if ($sel) { '[x] ' } else { '[ ] ' }); c = $(if ($sel) { 'Green' } else { 'Gray' }) }
                    $segs += @{ t = $r.Label; c = $(if ($sel) { 'Green' } else { 'White' }) }
                }
                if ($r.Desc)   { $segs += @{ t = (' - ' + $r.Desc); c = 'DarkGray' } }
                if ($r.Marker) { $segs += @{ t = ('  **' + $r.Marker); c = 'Yellow' } }
                [void]$lines.Add($segs)
            }
            # scroll-down marker + position, always present to keep the height constant
            $below = $Rows.Count - $viewEnd
            $pos = ("[item {0}/{1}]" -f ($cursor + 1), $Rows.Count)
            if ($below -gt 0) { [void]$lines.Add(@(@{ t = ("      vvv  {0} more below     {1}" -f $below, $pos); c = 'DarkGray' })) }
            else              { [void]$lines.Add(@(@{ t = ("      {0}" -f $pos); c = 'DarkGray' })) }
            [void]$lines.Add(@(@{ t = '  ---------------------------------------------------------------'; c = 'Yellow' }))
            if ($Summary) { [void]$lines.Add(@(@{ t = ('  ' + (& $Summary)); c = 'Green' })) } else { [void]$lines.Add(@(@{ t = '' })) }
            # In a sub-menu, both c and q/ESC return to the parent AND keep the current
            # selection (there is no "cancel" - you are building up a larger selection).
            if ($SubMenu) {
                if ($TriMode) { $hint = '   UP/DN/PgUp/PgDn move  0-9 jump  SPACE [ ]->[x] apply->[r] revert  a all  n none  c/ESC/q back & keep' }
                else          { $hint = '   UP/DN/PgUp/PgDn move  0-9 jump  SPACE toggle  a all  n none  c/ESC/q back & keep' }
            } else {
                $hint = '   UP/DN/PgUp/PgDn move  0-9 jump  SPACE toggle  ENTER sub-menu  a all  n none  c confirm  q quit'
            }
            if ($numBuf) { $hint += "    #$numBuf" }
            [void]$lines.Add(@(@{ t = $hint; c = 'DarkGray' }))

            if ($vt) {
                # Single write: home the cursor, paint every line, erase everything below.
                # One Console.Out.Write == no per-line flushing -> no flicker / "reload".
                $w = 100; try { $w = [System.Console]::WindowWidth } catch { }
                $sb = New-Object System.Text.StringBuilder
                [void]$sb.Append($e).Append('[H')
                foreach ($ln in $lines) { [void]$sb.Append((Get-AnsiLine $ln $w)).Append("`r`n") }
                [void]$sb.Append($e).Append('[J')
                [System.Console]::Out.Write($sb.ToString())
            } else {
                # Fallback (no VT): cursor-home + per-line write; clear on entry / after a submenu.
                if ($needClear) { Clear-Host; $needClear = $false }
                try { [System.Console]::SetCursorPosition(0, 0) } catch { Clear-Host }
                foreach ($ln in $lines) { Write-PadLine $ln }
            }

            $k   = [System.Console]::ReadKey($true)
            $key = $k.Key
            $ch  = [char]::ToLower([char]$k.KeyChar)
            $kc  = [char]$k.KeyChar

            # Type a number (multi-digit) to jump the cursor to that item; then SPACE/ENTER toggles.
            if ($kc -ge '0' -and $kc -le '9') {
                $numBuf += $kc
                $t = [int]$numBuf
                if ($t -lt 1 -or $t -gt $Rows.Count) { $numBuf = [string]$kc; $t = [int]$numBuf }
                if ($t -ge 1 -and $t -le $Rows.Count) { $cursor = $t - 1 } else { $numBuf = '' }
                continue
            }
            $numBuf = ''

            if ($key -eq 'UpArrow'   -or $ch -eq 'k') { if ($cursor -gt 0) { $cursor-- } }
            elseif ($key -eq 'DownArrow' -or $ch -eq 'j') { if ($cursor -lt $Rows.Count - 1) { $cursor++ } }
            elseif ($key -eq 'PageUp')   { $cursor = [Math]::Max(0, $cursor - $viewport) }
            elseif ($key -eq 'PageDown') { $cursor = [Math]::Min($Rows.Count - 1, $cursor + $viewport) }
            elseif ($key -eq 'Home')     { $cursor = 0 }
            elseif ($key -eq 'End')      { $cursor = $Rows.Count - 1 }
            elseif ($key -eq 'Spacebar' -or $key -eq 'Enter') {
                $r = $Rows[$cursor]
                if ($r.OnEnter) {
                    & $r.OnEnter; $needClear = $true
                } elseif ($r.Tri) {
                    # off -> apply -> revert -> off (rows with nothing to undo skip revert)
                    $st = ([int]$r.State + 1) % 3
                    if ($st -eq 2 -and $r.NoRevert) { $st = 0 }
                    $r.State = $st
                } else {
                    $r.Selected = -not $r.Selected
                }
            }
            elseif ($ch -eq 'a') { foreach ($r in $Rows) { if (-not $r.IsGroup) { if ($r.Tri) { $r.State = 1 } else { $r.Selected = $true } } }; if ($OnSelectAll) { & $OnSelectAll } }
            elseif ($ch -eq 'n') { foreach ($r in $Rows) { if (-not $r.IsGroup) { if ($r.Tri) { $r.State = 0 } else { $r.Selected = $false } } }; if ($OnSelectNone) { & $OnSelectNone } }
            elseif ($ch -eq 'c') { return 'confirm' }
            elseif ($ch -eq 'q' -or $key -eq 'Escape') { return 'quit' }
        }
    } finally {
        Set-MenuCursorVisible $true
        if ($vt) { try { [System.Console]::Out.Write("$e[0m") } catch { } }
    }
}

#-------------------------------------------------------------------------------
# Sub-menus - each precomputes markers once, runs the engine, writes back on confirm.
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
    # Persist on any exit (c or q/ESC) so backing out of the sub-menu keeps choices.
    [void](Invoke-SelectMenu -Banner 'Remote Support Tools' -Rows $rows -SubMenu)
    foreach ($r in $rows) { $flags[$r.Ref.Flag] = [bool]$r.Selected }
}

function Show-AiCliSubmenu {
    $rows = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($t in $script:AiCliTools) {
        $n++
        $mk = ''; if (& $t.Detect) { $mk = 'installed' }
        [void]$rows.Add(@{ Num = $n; Label = $t.Label; Desc = ''; Marker = $mk; Selected = [bool]$flags[$t.Flag]; IsGroup = $false; OnEnter = $null; Ref = $t })
    }
    [void](Invoke-SelectMenu -Banner 'AI CLI Tools' -Rows $rows -SubMenu)
    foreach ($r in $rows) { $flags[$r.Ref.Flag] = [bool]$r.Selected }
}

function Show-TweaksSubmenu {
    $rows = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($t in $script:WindowsTweaks) {
        if ($t.ShowIf -and -not (& $t.ShowIf)) { continue }   # conditional tweaks (e.g. Node switch)
        $n++
        $mk = ''; if (Test-TweakApplied -Key $t.Key) { $mk = 'applied' }
        [void]$rows.Add(@{ Num = $n; Label = $t.Label; Desc = ''; Marker = $mk; Selected = ($script:SelectedTweaks -contains $t.Key); IsGroup = $false; OnEnter = $null; Kind = 'tweak'; Ref = $t })
    }
    # CLI aliases - individually selectable here; cckimi/ccglm auto-add their -token setter.
    foreach ($a in $script:CliAliases) {
        $n++
        $mk = if (Test-AliasInstalled $a.Key) { 'installed' } else { '' }
        # Default UNCHECKED (like the tweaks): the marker shows what's installed; checking = (re)install.
        $sel = ($script:SelectedAliases -contains $a.Key)
        [void]$rows.Add(@{ Num = $n; Label = ('CLI alias: ' + $a.Label); Desc = ''; Marker = $mk; Selected = $sel; IsGroup = $false; OnEnter = $null; Kind = 'alias'; Ref = $a })
    }
    [void](Invoke-SelectMenu -Banner 'Windows Tweaks + CLI Aliases' -Rows $rows -SubMenu)
    $script:SelectedTweaks  = @($rows | Where-Object { $_.Kind -eq 'tweak' -and $_.Selected } | ForEach-Object { $_.Ref.Key })
    $script:SelectedAliases = @($rows | Where-Object { $_.Kind -eq 'alias' -and $_.Selected } | ForEach-Object { $_.Ref.Key })
    $script:AliasesTouched = $true
    $flags.Tweaks = ($script:SelectedTweaks.Count -gt 0)
    if (($script:SelectedTweaks -contains 'hostname') -and -not $script:HostnameValue) {
        Set-MenuCursorVisible $true
        $script:HostnameValue = Read-Host "`n  Enter the new computer hostname"
    }
}

# Explorer / UI tweaks - tri-state rows: [ ] leave alone, [x] apply, [r] revert.
function Show-UiTweaksSubmenu {
    $rows = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($t in $script:UiTweaks) {
        $n++
        $mk = ''; if (Test-UiTweakApplied -Key $t.Key) { $mk = 'applied' }
        $st = 0
        if ($script:SelectedUiTweaks.ContainsKey($t.Key)) {
            if ($script:SelectedUiTweaks[$t.Key] -eq 'revert') { $st = 2 } else { $st = 1 }
        }
        [void]$rows.Add(@{ Num = $n; Label = $t.Label; Desc = ''; Marker = $mk; IsGroup = $false; OnEnter = $null;
                           Tri = $true; NoRevert = (-not $t.Revert); State = $st; Ref = $t })
    }
    [void](Invoke-SelectMenu -Banner 'Explorer & UI Tweaks    [x] = apply    [r] = revert' -Rows $rows -TriMode -SubMenu)
    $sel = @{}
    foreach ($r in $rows) {
        if     ([int]$r.State -eq 1) { $sel[$r.Ref.Key] = 'apply' }
        elseif ([int]$r.State -eq 2) { $sel[$r.Ref.Key] = 'revert' }
    }
    $script:SelectedUiTweaks = $sel
    $flags.UiTweaks = ($sel.Count -gt 0)
}

function Show-DebloatSubmenu {
    $rows = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($t in $script:DebloatItems) {
        $n++
        $mk = ''; if (Test-BloatRemoved -Item $t) { $mk = 'removed' }
        [void]$rows.Add(@{ Num = $n; Label = $t.Label; Desc = ''; Marker = $mk; Selected = ($script:SelectedDebloat -contains $t.Key); IsGroup = $false; OnEnter = $null; Ref = $t })
    }
    [void](Invoke-SelectMenu -Banner 'Debloat (remove pre-installed apps)' -Rows $rows -SubMenu)
    $script:SelectedDebloat = @($rows | Where-Object { $_.Selected } | ForEach-Object { $_.Ref.Key })
    $flags.Debloat = ($script:SelectedDebloat.Count -gt 0)
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
    [void](Invoke-SelectMenu -Banner 'Visual Studio Code' -Rows $rows -SubMenu)
    $script:VSCodeApplySettings = [bool]($rows | Where-Object { $_.Kind -eq 'settings' } | Select-Object -First 1).Selected
    $script:SelectedVSCodeExt   = @($rows | Where-Object { $_.Kind -eq 'ext' -and $_.Selected } | ForEach-Object { $_.Ref.Id })
    $installSel = [bool]($rows | Where-Object { $_.Kind -eq 'install' } | Select-Object -First 1).Selected
    # "Apply settings" alone is a modifier, not a reason to flag VS Code for install -
    # otherwise merely opening this sub-menu (settings pre-checked) would enable it.
    $flags.VSCode = ($installSel -or $script:SelectedVSCodeExt.Count -gt 0)
}

#-------------------------------------------------------------------------------
# Main interactive menu (birebir: one flat numbered list, groups expand on ENTER)
#-------------------------------------------------------------------------------
function Show-InteractiveMenu {
    Reset-DetectionCache
    Write-Host ""

    $dev = @{}
    foreach ($d in $script:DevTools) { $dev[$d.Key] = $d }

    # Precompute group markers ONCE (detection is slow) with a smooth background spinner.
    $sp = Start-Spinner 'Scanning installed software'
    $rmInst = @($script:RemoteTools  | Where-Object { & $_.Detect }).Count
    $aiInst = @($script:AiCliTools   | Where-Object { & $_.Detect }).Count
    $twInst = @($script:WindowsTweaks| Where-Object { Test-TweakApplied -Key $_.Key }).Count
    $uiInst = @($script:UiTweaks     | Where-Object { Test-UiTweakApplied -Key $_.Key }).Count
    $dbInst = @($script:DebloatItems | Where-Object { Test-BloatRemoved -Item $_ }).Count
    $vsInst = if (Test-VSCodeInstalled) { 'installed' } else { '' }
    Stop-Spinner $sp

    # Birebir order + descriptions
    $order = @(
        @{ k='remote';      group='remote';  label='Remote Support Tools'; desc='RealVNC, AnyDesk, RustDesk, TeamViewer (Enter to expand)'; marker=(Get-GroupMarkerText $rmInst $script:RemoteTools.Count 'installed') }
        @{ k='nodejs';                        label='NodeJS';       desc='nvm-windows + Node.js 22 + Yarn' }
        @{ k='chrome';                        label='Chrome';       desc='Google Chrome' }
        @{ k='vscode';      group='vscode';  label='VS Code';      desc='Visual Studio Code (Enter: extensions & settings)'; marker=$vsInst }
        @{ k='python';                        label='Python';       desc='Python 3' }
        @{ k='tweaks';      group='tweaks';  label='Tweaks';       desc='Windows tweaks (Enter to expand)'; marker=(Get-GroupMarkerText $twInst $script:WindowsTweaks.Count 'applied') }
        @{ k='uitweaks';    group='uitweaks';label='Explorer & UI'; desc='This PC / nav pane / context menu / registry tweaks (Enter to expand)'; marker=(Get-GroupMarkerText $uiInst $script:UiTweaks.Count 'applied') }
        @{ k='dbeaver';                       label='DBeaver';      desc='DBeaver CE (database tool)' }
        @{ k='vlc';                           label='VLC';          desc='VLC Media Player' }
        @{ k='notepad++';                     label='Notepad++';    desc='Notepad++ text editor' }
        @{ k='sharex';                        label='ShareX';       desc='ShareX screen capture' }
        @{ k='firefox';                       label='Firefox';      desc='Firefox (opens the installer window)' }
        @{ k='whatsapp';                      label='WhatsApp';     desc='WhatsApp (Microsoft Store)' }
        @{ k='winrar';                        label='WinRAR';       desc='WinRAR archiver' }
        @{ k='spotify';                       label='Spotify';      desc='Spotify (Microsoft Store)' }
        @{ k='power-manager';                 label='Power Manager';desc='Windows Auto Power Manager (latest release)' }
        @{ k='revo';                          label='Revo Pro';     desc='Revo Uninstaller Pro' }
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
                'uitweaks'{ { Show-UiTweaksSubmenu } }
                'aicli'   { { Show-AiCliSubmenu } }
                'debloat' { { Show-DebloatSubmenu } }
            }
            $check = switch ($g) {
                'remote'  { { @($script:RemoteTools | Where-Object { $flags[$_.Flag] }).Count -gt 0 } }
                'vscode'  { { [bool]$flags.VSCode -or $script:SelectedVSCodeExt.Count -gt 0 } }
                'tweaks'  { { $script:SelectedTweaks.Count -gt 0 -or $script:SelectedAliases.Count -gt 0 } }
                'uitweaks'{ { $script:SelectedUiTweaks.Count -gt 0 } }
                'aicli'   { { @($script:AiCliTools | Where-Object { $flags[$_.Flag] }).Count -gt 0 } }
                'debloat' { { $script:SelectedDebloat.Count -gt 0 } }
            }
            [void]$rows.Add(@{ Num=$n; Label=$o.label; Desc=$o.desc; Marker=$o.marker; IsGroup=$true; OnEnter=$onEnter; SelectedCheck=$check })
        } else {
            $d = $dev[$o.k]
            if ($d.Marker) { $mk = & $d.Marker } else { $mk = ''; if (& $d.Detect) { $mk = 'installed' } }
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
        if ($script:SelectedUiTweaks.Count) { $parts += "UI[$($script:SelectedUiTweaks.Count)]" }
        if ($script:SelectedDebloat.Count) { $parts += "Debloat[$($script:SelectedDebloat.Count)]" }
        if ($script:SelectedAliases.Count) { $parts += "Aliases[$($script:SelectedAliases.Count)]" }
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
        $script:SelectedAliases = @($script:CliAliases | ForEach-Object { $_.Key }); $script:AliasesTouched = $true
        # Reversible UI tweaks only: "select all" must not fire the one-shot
        # actions (rebuild icon cache kills Explorer, DNS renew drops the link).
        $ui = @{}
        foreach ($t in $script:UiTweaks) { if ($t.Revert) { $ui[$t.Key] = 'apply' } }
        $script:SelectedUiTweaks = $ui
        $flags.Tweaks = $true; $flags.Debloat = $true; $flags.VSCode = $true; $flags.UiTweaks = $true
    }
    $selectNone = {
        foreach ($t in $script:AiCliTools)  { $flags[$t.Flag] = $false }
        foreach ($t in $script:RemoteTools) { $flags[$t.Flag] = $false }
        $script:SelectedTweaks = @(); $script:SelectedDebloat = @(); $script:SelectedVSCodeExt = @()
        $script:SelectedAliases = @(); $script:AliasesTouched = $true
        $script:SelectedUiTweaks = @{}
        $flags.Tweaks = $false; $flags.Debloat = $false; $flags.VSCode = $false; $flags.UiTweaks = $false
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
# Dispatch - run installs/tweaks/debloat from $flags + $script:Selected* lists.
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
    Save-TweakBackupOnce

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
# Apply / revert the selected Explorer-UI tweaks (backs up first)
#-------------------------------------------------------------------------------
function Invoke-UiTweaks {
    if (-not $script:SelectedUiTweaks -or $script:SelectedUiTweaks.Count -eq 0) {
        # CLI path: --uitweaks with no prior selection -> open the submenu to choose
        Show-UiTweaksSubmenu
    }
    if (-not $script:SelectedUiTweaks -or $script:SelectedUiTweaks.Count -eq 0) { return }

    Write-LogStep "Applying Explorer / UI tweaks"
    Save-TweakBackupOnce

    # Iterate the catalog (not the hashtable) so the order stays deterministic.
    foreach ($t in $script:UiTweaks) {
        if (-not $script:SelectedUiTweaks.ContainsKey($t.Key)) { continue }
        $verb = 'Tweak'; $fn = $t.Apply
        if ($script:SelectedUiTweaks[$t.Key] -eq 'revert') { $verb = 'Revert'; $fn = $t.Revert }
        if (-not $fn) { continue }
        try {
            $ok = & $fn
            Add-Summary "${verb}: $($t.Label)" ([bool]$ok)
        } catch {
            Write-LogWarning "$($t.Label) failed: $($_.Exception.Message)"
            Add-Summary "${verb}: $($t.Label)" $false
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

    # Windows tweaks / Explorer-UI tweaks / debloat
    if ($flags.Tweaks)   { Invoke-Tweaks }
    if ($flags.UiTweaks) { Invoke-UiTweaks }
    if ($flags.Debloat) {
        if (-not $script:SelectedDebloat -or $script:SelectedDebloat.Count -eq 0) { Show-DebloatSubmenu }
        Invoke-Debloat
    }

    # CLI aliases - install the selected ones (+ auto-bundled tokens). Non-selected untouched.
    if ($script:SelectedAliases -and $script:SelectedAliases.Count -gt 0) {
        if (Set-CliAliases) { Add-Summary ("CLI aliases: " + (@($script:SelectedAliases) -join ', ')) }
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
# CLI login helpers (mirrors run_cli_logins) - best-effort, interactive
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


