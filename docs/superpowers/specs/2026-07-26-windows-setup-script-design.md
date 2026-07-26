# Windows Post-Installation Setup Script — Design Spec

**Date:** 2026-07-26
**Status:** Approved (design) — implementation pending
**Target file:** `windows-setup.ps1`
**Source of truth:** `../ubuntu-setup-script/ubuntu-setup.sh` (v2.5.0, rev-153, 6486 lines, 104 functions)

---

## 1. Goal & Non-Goals

**Goal:** Produce a Windows-native, one-to-one (*birebir*) counterpart of the Ubuntu post-installation
setup script. Same structure, same interactive menu, same flag surface, same "install-from-a-single-command"
experience — implemented in PowerShell and adapted to Windows 10/11.

**Non-Goals:**
- Literal line-by-line translation of Linux-only logic. ~40% of the source (GNOME, apt/snap, Wayland,
  ibus, XKB, Jetson/ARM) has no Windows equivalent and is replaced by Windows-native equivalents or dropped.
- Cross-version support below Windows 10 (winget/Appx/OpenSSH capability assumptions).
- **RDP is explicitly out of scope.** Remote access on Windows is handled by RealVNC (Remote tools group).
  The Ubuntu `enable_rdp_server` / `disable_wayland` tweaks are NOT ported.

## 2. Decisions (locked)

| # | Decision |
|---|----------|
| 1 | Linux-only sections → **Windows-native equivalents** (Windows Tweaks + Windows Debloat), same menu shape. |
| 2 | Package install order: **① direct download from official source / GitHub release + silent install → ② winget → ③ choco**. |
| 3 | Interactive menu → **birebir TUI replication** (arrow keys + space toggle + submenus + status markers). |
| 4 | Delivery → **new public gist** under `enginyilmaaz` (`windows-setup.ps1` + `README.md`) + push to `windows-setup-script` repo. Install via `irm <url> \| iex`. bit.ly short link set up by the user. |
| 5 | Node → **nvm-windows** (closest to source's NVM). |
| 6 | Backup → **System Restore point (`Checkpoint-Computer`) + registry export** of touched keys. |
| 7 | Weak/absent mappings (IBus fix, Virtual Screen 1080p, Jetson/ARM snapd, GNOME extension framework) → **dropped**. |
| 8 | **Debloat item list is supplied by the user** ("en son"). Framework is built now; the concrete removable list is a data input the user finalizes. A sensible starter set is included and clearly marked as user-editable. |

## 3. Architecture

### 3.1 Single-file PowerShell
One self-contained `windows-setup.ps1`, mirroring the single `ubuntu-setup.sh`. No external module dependencies
beyond what ships with Windows 10/11 (`Appx`, `DISM`, `powercfg`, `winget`).

### 3.2 Elevation (sudo analog)
On start, if not running elevated, relaunch self as Administrator via
`Start-Process pwsh/powershell -Verb RunAs` preserving `$args`. When run through `irm | iex` (no file on disk),
re-fetch the script into the elevated process. Interactive menu and installs require admin.

### 3.3 Argument parsing
Manual parse of `$args` with a `switch`, mirroring the source `case` block, so `--flag` style is preserved
verbatim (not PowerShell `-Switch` params). Invocation with args:
`& ([scriptblock]::Create((irm '<url>'))) --menu`.

**Flag surface (1:1 with source, minus RDP/Jetson-only):**
`--all --menu --help --version` ·
`--nodejs --python --docker --chrome --vscode --dbeaver --vlc --cloudflared --gh --postman --filezilla` ·
`--claude --codex --kimi --grok --gemini --qwen --glm --glm-opencode` (group: `--aicli`) ·
`--vnc/--realvnc --anydesk --rustdesk --teamviewer` (group: `--remote`) ·
`--tweaks` (was `--gnome`) · `--debloat` · `--login` ·
`--show-backup` · `--restore` (were `--show-backup-gnome` / `--restore-gnome-desktop`).
Dropped: `--jetson-fix`, `--remove-firefox` folds into Debloat.

### 3.4 Install strategy — `Install-App` contract
Central helper used by every installer:

```
Install-App -Name <display> `
            -Detect { <scriptblock returns $true if already installed> } `
            -Direct { <download official installer + silent-install> } `   # ① preferred
            -WingetId <id> `                                               # ② fallback
            -ChocoId  <id> `                                               # ③ fallback
            [-PostInstall { ... }]
```
Order: if `-Detect` true → skip (offer reinstall in menu flow). Else try `Direct`; on failure try `winget`;
on failure try `choco` (bootstrapping choco once if absent). Every attempt goes through `Invoke-WithRetry`
(3 attempts, 5s delay — mirrors `retry_command`). Silent-install flag cheatsheet lives beside each installer.

### 3.5 Logging / error handling / retry (1:1 with source)
- `Write-Log*` = `log_info/step/success/warning/error` (colored `Write-Host`).
- `Invoke-ErrorHandler` = `handle_error`: interactive continue/abort prompt (reads from console; works under
  `irm | iex`). No `set -e` analog — errors handled interactively.
- `Invoke-WithRetry`, `Get-FileDownload` (retry+resume) = `retry_command` / `retry_curl_download` / `download_file`.

## 4. Feature mapping

### 4.1 Dev tools (🟢 same tools)
| Tool | ① Direct source | ② winget | ③ choco | Silent |
|------|-----------------|----------|---------|--------|
| Node (nvm-windows) | github coreybutler/nvm-windows `nvm-setup.exe` → `nvm install lts` | `CoreyButler.NVMforWindows` | `nvm` | `/SILENT` |
| Python | python.org latest | `Python.Python.3.12` | `python` | `/quiet InstallAllUsers=1 PrependPath=1` |
| Docker Desktop | desktop.docker.com installer | `Docker.DockerDesktop` | `docker-desktop` | `install --quiet` |
| Chrome | dl.google.com standalone | `Google.Chrome` | `googlechrome` | `/silent /install` |
| VS Code (+ext) | update.code.visualstudio.com user setup | `Microsoft.VisualStudioCode` | `vscode` | `/verysilent /mergetasks=!runcode` |
| DBeaver | github dbeaver/dbeaver | `DBeaver.DBeaver` | `dbeaver` | `/S` |
| VLC | videolan.org win64 | `VideoLAN.VLC` | `vlc` | `/S` |
| cloudflared | github cloudflare/cloudflared exe | `Cloudflare.cloudflared` | `cloudflared` | place on PATH |
| gh | github cli/cli msi | `GitHub.cli` | `gh` | `msiexec /qn` |
| Postman | dl.pstmn.io win64 | `Postman.Postman` | `postman` | `--silent` |
| FileZilla | filezilla-project.org | `TimKosse.FileZilla.Client` | `filezilla` | `/S` |

VS Code extensions (via `code --install-extension`, 1:1 with source): Claude Code, Codex/ChatGPT, Python,
Pylance, GitLens, Prettier, ESLint, Docker, Material Icon Theme + "apply settings/tweaks" option.
`jtop` (Jetson) is **dropped**.

### 4.2 AI CLI tools (🟢 mostly cross-platform)
| Tool | Windows install |
|------|-----------------|
| Claude Code | native Windows installer `irm https://claude.ai/install.ps1 \| iex` (verify at impl); npm `@anthropic-ai/claude-code` fallback. Also `install_claude_plugins`. |
| Codex | npm `@openai/codex` |
| Kimi | npm (Moonshot AI CLI) |
| Grok | xAI official installer / npm |
| Gemini | npm `@google/gemini-cli` |
| Qwen | npm (Qwen Code) |
| GLM | z.ai `chelper` |
| GLM+OpenCode | OpenCode (opencode.ai) + write `~/.config/opencode/opencode.json` (GLM-5.2) |
All npm-based ones ensure Node first (mirrors source). Exact package names verified against source at impl time.

### 4.3 Remote tools (🟢 same tools; RealVNC is the remote method)
RealVNC (`RealVNC.VNCServer`/`VNCViewer` or realvnc.com direct), AnyDesk (`AnyDeskSoftwareGmbH.AnyDesk`),
RustDesk (github release / `RustDesk.RustDesk`), TeamViewer (`TeamViewer.TeamViewer`). Update-available markers
preserved via `Remote-UpdateAvailable` detection (winget `--include-unknown` compare).

### 4.4 Windows Tweaks (🟡 replaces the 20 GNOME tweaks)
| Source GNOME tweak | Windows equivalent | Method |
|--------------------|--------------------|--------|
| Update System | `winget upgrade --all --silent` | winget |
| Script Launcher (right-click) | Explorer background context-menu entries (Claude/Codex/VS Code here) | `HKCU\Software\Classes\Directory\Background\shell\*` |
| OpenSSH Server | Install + auto-start sshd (port 22) | `Add-WindowsCapability OpenSSH.Server`, `Set-Service sshd -StartupType Automatic`, firewall rule |
| Change Hostname | Rename computer (value collected pre-install) | `Rename-Computer` (reboot noted) |
| CLI Aliases | PowerShell profile functions (`claude-skip`, `codex-skip`, …) | append to `$PROFILE` |
| Screen Off: Never | Never turn off display / never sleep | `powercfg -change monitor-timeout-* 0`, standby 0, disable hibernate |
| Show Hidden Files | Show hidden files + file extensions | Explorer `Advanced\Hidden=1`, `HideFileExt=0` |
| Keyboard: Turkish Q | Add Turkish-Q input | `Set-WinUserLanguageList` (add `tr-TR`) |
| Keyboard: English Q | Add English(US) input | `Set-WinUserLanguageList` (add `en-US`) |
| English Language | UI/display language en-US | `Set-WinUILanguageOverride`, `Set-WinSystemLocale` |
| GDM Auto-Login | Windows auto-login on boot | `Winlogon\AutoAdminLogon=1` (+ DefaultUserName/Password; password caveat surfaced) |
| Tray Icons: Reloaded | Always show all tray icons | `EnableAutoTray=0` |
| Dash to Dock | Taskbar tweaks (align/combine/size) | Explorer `Advanced` registry |
| Activate Apport | Enable Windows Error Reporting | `HKLM\...\Windows Error Reporting\Disabled=0` |
| Install Camera (Cheese) | Windows Camera app | winget / built-in |
| Cleanup Period: 2Y | Storage Sense auto-clean temp/recycle | `StorageSense` registry policy |
| **Disable Wayland → RDP** | **DROPPED** (remote = RealVNC) | — |
| Extensions / Tweaks tool / Browser Connector | **DROPPED** (no analog) | — |
| IBus Leak Fix / Virtual Screen 1080p | **DROPPED** (no analog) | — |

### 4.5 Windows Debloat (🟡 replaces Ubuntu debloat — **item list supplied by user**)
**Framework (built now):** each removable is a record
`@{ Name; Kind = 'Appx'|'Winget'|'Feature'|'DevTool'; Id; ProvisionedToo=$bool }`.
Removal engine:
- `Appx` → `Get-AppxPackage -AllUsers <id> | Remove-AppxPackage` (+ `Get-AppxProvisionedPackage | Remove-…` when `ProvisionedToo`)
- `Winget` → `winget uninstall --silent`
- `Feature` → `Disable-WindowsOptionalFeature` / capability removal
- `DevTool` → uninstall the same dev tools this script installs (mirrors source "remove dev tools")

**Detection** (`Bloat-IsRemoved`) drives the `[removed]` marker in the submenu, mirroring `bloat_is_done`.

**Starter set (USER TO FINALIZE):** Xbox apps, Cortana, OneDrive, Copilot, Weather, News, Maps, Solitaire
Collection, Candy Crush (any preinstalled), Groove Music, Movies & TV, 3D Viewer / Paint 3D, Mixed Reality
Portal, Feedback Hub, Get Help, Tips, People, Your Phone/Phone Link, consumer Teams, Quick Assist, Clipchamp;
plus the DevTool/browsers group (Chrome, Node, Docker, VS Code, DBeaver, Postman, FileZilla, cloudflared, gh,
Firefox). **The user provides the authoritative removable list before this section is finalized.**

### 4.6 Backup / Restore (🟡 GNOME backup analog)
- Before applying any tweak: `Checkpoint-Computer -Description "windows-setup <ts>"` **and** `reg export`
  of each touched key into `%USERPROFILE%\.windows_setup_conf_backup\<timestamp>\*.reg`.
- `--show-backup` → list backups (timestamps + restore points), like `show_gnome_backup` / `show_all_backups`.
- `--restore` → interactive restore: re-import latest `.reg` set and/or point user to a System Restore point,
  mirroring `restore_gnome_settings` / `restore_backup_interactive` / `take_new_backup`.

## 5. Interactive menu (birebir TUI)
`[Console]::ReadKey($true)` loop. Keys: **↑/↓** move, **SPACE** toggle, **a** all, **n** none,
**c/ESC** save & continue, **q** discard — identical to source. Grouped items open submenus:
**AI CLI Tools · Remote Support Tools · Windows Tweaks · Debloat · VS Code**, each preserving prior picks
across reopens (globals mirror `AICLI_SUB_*`, `*_SUB_*`). Status markers per row via detection helpers:
`[installed]`, `[update available]`, `[removed]` — mirrors `gnome_tweak_applied` / `remote_update_available` /
`aicli_installed` / `bloat_is_done` / `vscode_ext_installed`. System-info header (`Show-SystemHeader`) shows
Windows edition/build/host/user.

## 6. Delivery
- New **public gist** (`enginyilmaaz`) with `windows-setup.ps1` + `README.md` (Ubuntu-README style, adapted).
- Push same files to `github.com/enginyilmaaz/windows-setup-script` (`main`, single branch → direct push OK).
- Install commands:
  ```powershell
  # menu
  irm https://bit.ly/windows-ey | iex
  # or with args
  & ([scriptblock]::Create((irm 'https://bit.ly/windows-ey'))) --all
  ```
- bit.ly short link (`bit.ly/windows-ey` or similar) created by the user; README carries the full gist raw URL fallback.

## 7. Function map (source → target, condensed)
- Core: `log_*`→`Write-Log*`, `handle_error`→`Invoke-ErrorHandler`, `retry_*`/`download_file`→`Invoke-WithRetry`/`Get-FileDownload`, `command_exists`/`package_installed`→`Test-Command`/`Test-App`.
- Installers: `install_<x>`→`Install-<X>` via `Install-App`. `install_prerequisites`→`Install-Prerequisites` (ensure winget, optionally bootstrap choco).
- Tweaks: `install_gnome_*`/`configure_dash_to_dock`/`enable_ssh_server`/`setup_cli_shortcuts`/`enable_autologin`/… → `Set-*Tweak` family (§4.4). `disable_wayland`/`enable_rdp_server`/`fix_jetson_snapd`/`setup_virtual_screen`→**dropped**.
- Backup: `backup_gnome_settings`/`restore_*`/`take_new_backup`/`show_*_backup`→`Backup-Registry`/`Restore-Backup`/`Show-Backups`.
- Debloat: `debloat_system`/`remove_application`/`remove_firefox`→`Invoke-Debloat`/`Remove-BloatItem`.
- Menu: `show_interactive_install_menu`/`show_full_menu`/`show_*_submenu`/`menu_*`→`Show-*Menu`/`Show-*Submenu`.
- Dispatch: `run_installations`/`check_already_installed`/`run_cli_logins`/`print_summary`/`main`→same names.

## 8. Open items (resolve during implementation)
1. Exact npm package ids for Kimi/Grok/Qwen/GLM — read from source install functions.
2. Claude Code native Windows installer URL — verify (`install.ps1`) vs npm.
3. RealVNC exact winget/download artifact (Server vs Viewer vs Connect).
4. Auto-login password handling — prompt + caveat, or skip password (interactive login).
5. **Debloat authoritative list — awaiting user.**

## 9. Implementation phases
1. **Skeleton:** header/version, arg parse, elevation, logging, error handler, retry, `Install-App`, `Get-FileDownload`, `--help`, `--version`. Syntax-check with `pwsh -NoProfile -Command`.
2. **Dev tools** installers (§4.1) + detection.
3. **AI CLI** installers (§4.2) + submenu data.
4. **Remote** installers (§4.3) + update markers.
5. **Windows Tweaks** (§4.4) + backup-before-change (§4.6).
6. **Debloat** framework (§4.5) — finalize list with user.
7. **Interactive TUI menu** (§5) + all submenus + status detection + system header.
8. **Dispatch/summary**, `check_already_installed`, CLI logins.
9. **README** + gist publish + repo push.

Each phase: `pwsh` syntax-check (Linux) — runtime behavior can't be fully exercised off-Windows, so Windows-only
calls are guarded and documented; user does the on-Windows smoke test.
