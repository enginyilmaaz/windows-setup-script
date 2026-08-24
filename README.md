# Windows Post-Installation Setup Script

A comprehensive, modular PowerShell script that automates Windows 10/11 post-installation setup. Install your favorite tools, tweak the desktop, debloat the system, and get a fresh Windows machine ready for development in minutes — from a single command.

The Windows-native counterpart of the [Ubuntu Post-Installation Setup Script](https://github.com/enginyilmaaz/ubuntu-setup-script).

**Version:** 1.2.3

## 🚀 Quick Start

Run straight from the Gist — **no cloning required**. Open **Windows Terminal / PowerShell as Administrator** (the script also self-elevates):

```powershell
# Recommended — interactive menu (pick & choose)
irm https://bit.ly/windows-ey | iex

# Or install everything at once
& ([scriptblock]::Create((irm 'https://bit.ly/windows-ey'))) --all
```

<details>
<summary>Full Gist URL (use this if the short link is unavailable)</summary>

```powershell
# Interactive menu
irm https://gist.githubusercontent.com/enginyilmaaz/5dc585f42032cc2d2736433590555484/raw/windows-setup.ps1 | iex

# Everything
& ([scriptblock]::Create((irm 'https://gist.githubusercontent.com/enginyilmaaz/5dc585f42032cc2d2736433590555484/raw/windows-setup.ps1'))) --all
```
</details>

> The interactive menu reads keys directly from the console, so it works correctly even through `irm | iex`.

## 🔗 Links

| | URL |
|------|-----|
| **Gist** (quick install) | https://gist.github.com/enginyilmaaz/5dc585f42032cc2d2736433590555484 |
| **Repository** (source) | https://github.com/enginyilmaaz/windows-setup-script |

## ✨ Capabilities

Everything below is reachable through the interactive menu (`--menu`) or directly via its flag.

### 🧰 Core Apps & Tools

| Flag | Installs |
|------|----------|
| `--all` | Install everything (non-interactive) |
| `--menu` | Interactive menu to pick & choose |
| `--nodejs` | Node.js (via nvm-windows) + Yarn |
| `--python` | Python 3 |
| `--docker` | Docker Desktop |
| `--chrome` | Google Chrome |
| `--vscode` | Visual Studio Code (+ extensions submenu) |
| `--dbeaver` | DBeaver Community (database tool) |
| `--vlc` | VLC Media Player (opens the installer window) |
| `--cloudflared` | Cloudflare Tunnel client |
| `--git` | Git for Windows (version control) |
| `--gh` | GitHub CLI (`gh`) |
| `--postman` | Postman |
| `--filezilla` | FileZilla (FTP/SFTP client) |
| `--localsend` | LocalSend (local network file sharing) |
| `--notepad++` | Notepad++ text editor |
| `--sharex` | ShareX screen capture |
| `--firefox` | Firefox (opens the installer window) |
| `--whatsapp` | WhatsApp (Microsoft Store) |
| `--winrar` | WinRAR archiver |
| `--spotify` | Spotify (Microsoft Store) |
| `--power-manager` | Windows Auto Power Manager (latest GitHub release, silent) |
| `--revo` | Revo Uninstaller Pro |
| `--tweaks` | Windows desktop tweaks (submenu) |
| `--debloat` | Remove pre-installed bloat (submenu) |
| `--login` | CLI login helpers |
| `--skip-update` | Skip the self-update check |

> **Package strategy:** each tool is installed by **downloading the official installer / GitHub release directly** first, falling back to **winget**, then **Chocolatey** — so you always get the vendor's build when possible.

### 🤖 AI CLI Tools

| Flag | Tool |
|------|------|
| `--claude` | **Claude Code** — Anthropic CLI |
| `--codex` | **Codex** — OpenAI CLI (`@openai/codex`) |
| `--kimi` | **Kimi Code** — Moonshot AI CLI |
| `--grok` | **Grok** — xAI CLI |
| `--gemini` | **Gemini CLI** — Google |
| `--qwen` | **Qwen Code** — Alibaba |
| `--glm-opencode` | **GLM With OpenCode** — OpenCode pre-configured for z.ai GLM |

### 🖥️ Remote Support Tools

| Flag | Tool |
|------|------|
| `--vnc` | RealVNC Connect (the remote method used here) |
| `--anydesk` | AnyDesk |
| `--rustdesk` | RustDesk (open source) |
| `--teamviewer` | TeamViewer |

### 🎨 Windows Tweaks (`--tweaks`)

<details>
<summary>Desktop tweaks &amp; settings — click to expand</summary>

| Tweak | What it does |
|-------|--------------|
| Update System | `winget upgrade --all` |
| Script Launcher | Right-click context menu (Claude, Codex, VS Code) |
| OpenSSH Server | Install + auto-start SSH server (port 22) |
| Change Hostname | Set the computer's hostname |
| Screen Off: Never | Disable display timeout + sleep |
| Show Hidden Files | Show hidden files + file extensions |
| Keyboard: Turkish Q | Add Turkish-Q keyboard layout |
| Keyboard: English Q | Add English (US) keyboard layout |
| English Language | Set display language to English (US) |
| Auto-Login | Auto-login to Windows on boot |
| Always Show Tray Icons | Show all notification-area icons |
| Taskbar Tweaks | Taskbar alignment/size adjustments |
| Taskbar/Start: align left | Move the Start button + taskbar icons to the left (`TaskbarAl=0`) |
| Taskbar Search: icon only | Show the taskbar search as a compact icon (`SearchboxTaskbarMode=1`) |
| Disable Windows Search | Stop + disable the `WSearch` indexer service |
| Disable Windows Updates | Set the `NoAutoUpdate` policy and disable the update services (⚠️ stops security patches) |
| Windows Update: never auto-restart | Set `NoAutoRebootWithLoggedOnUsers` so updates still install but the PC never reboots on its own — waits for a manual restart |
| Disable Hyper-V | `bcdedit hypervisorlaunchtype off` + disable Hyper-V / Virtual Machine Platform features (⚠️ breaks WSL2 & Windows Sandbox; reboot) |
| VMware/VirtualBox setup | Disable Hyper-V **+** VBS **+** Memory Integrity (HVCI) **+** Credential Guard so VMware/VirtualBox get full VT-x (⚠️ weakens Win11 security; reboot) |
| Activate Error Reporting | Enable Windows Error Reporting |
| Enable System Restore | Turn on system protection for the system drive (shadow storage capped at 10GB) |
| Install Windhawk + taskbar mods | Install Windhawk (latest GitHub release, 2.0+, which ships `windhawk-cli.exe`) and the `taskbar-grouping`, `start-menu-size`, and `taskbar-volume-control` mods via the CLI (runs under the script's own elevation — no extra UAC) |
| Install Camera App | Install the Windows Camera app |
| Install: Edge WebView2 Runtime | (Re)install `Microsoft.EdgeWebView2Runtime` via winget |
| Install: Microsoft Edge | (Re)install `Microsoft.Edge` via winget |
| Cleanup: Storage Sense | Auto-clean temp files & recycle bin |
| RealVNC: normal cursor | Fix the RealVNC "dot" cursor on a headless / mouse-less host by enabling RealVNC Server's `AlwaysShowCursor` (shown only when RealVNC is installed) |
| Node.js: switch to NVM | Replace a native Node.js with nvm-windows (shown only when Node is non-NVM) |
| Node.js: switch to native | Replace nvm-windows with a native Node.js LTS (shown only when NVM is installed) |

</details>

> Before applying tweaks, the script creates a **System Restore point** and exports the touched registry keys to `%USERPROFILE%\.windows_setup_conf_backup`.

### 🗂️ Explorer &amp; UI Tweaks (`--uitweaks`)

Registry/shell tweaks for File Explorer, the navigation pane and the context menu — ported from the classic `.reg` / `.cmd` tweak packs to native PowerShell. Aliases: `--ui`, `--explorer`, `--reg-tweaks`.

Every entry is a **two-way toggle**. In the submenu, **SPACE** cycles each row `[ ]` leave alone → `[x]` apply → `[r]` revert.

<details>
<summary>Explorer, context-menu &amp; system tweaks — click to expand</summary>

| Tweak | Apply | Revert |
|-------|-------|--------|
| This PC: user folders | Remove Desktop/Documents/Downloads/Music/Pictures/Videos | Put them back |
| This PC: 3D Objects | Remove the 3D Objects folder | Put it back |
| Nav pane: Network | Hide Network | Show Network |
| Nav pane: HomeGroup | Hide HomeGroup (Windows 10) | Show HomeGroup |
| Nav pane: removable drives | Remove the duplicate drive entries | Restore them |
| Nav pane: Gallery | Hide Gallery (Windows 11) | Show Gallery |
| Nav pane: Home | Hide Home (Windows 11) | Show Home |
| Quick Access | Hide recently-used files **and** frequently-used folders | Show them |
| Explorer: open to This PC | Open File Explorer at **This PC** instead of Quick Access / Home | Back to Quick Access / Home |
| Quick Access: Desktop | Pin the Desktop folder to Quick Access | Unpin it |
| Win11 context menu | Restore the classic (full) right-click menu | Back to the compact Win11 menu |
| Context menu: Share with | Remove the `Sharing` shell handlers | Re-import from backup |
| Properties: Sharing tab | Remove the Sharing property sheet | Re-import from backup |
| Previous Versions | Remove the context-menu entry **and** the Properties tab | Re-import from backup |
| Action Center | Disable the notification centre (policy) | Re-enable |
| Lock screen | Disable for all users (policy) | Re-enable |
| Search box | Disable web suggestions | Re-enable |
| Search web results | Turn off Bing/web + Store/cloud results in Start search (local search stays) | Re-enable |
| NumLock | On at the logon screen **and** after sign-in | Off |
| Superfetch / Prefetch | Stop + disable `SysMain`, `EnablePrefetcher=0`, clear the Prefetch cache | Re-enable (`start=auto`, `EnablePrefetcher=3`) |
| Windows Photo Viewer | Re-register it for `.tif .tiff .png .bmp .jpeg .jpg .ico` | Unregister |
| Rebuild icon cache | One-shot: `ie4uinit -show`, drop `IconCache.db`, restart Explorer | — |
| Flush DNS | One-shot: `ipconfig /flushdns` + `/release` + `/renew` | — |

</details>

> Tweaks that **delete** registry keys export them to `%USERPROFILE%\.windows_setup_conf_backup\ui-tweaks\<tweak>\` first, so *revert* re-imports the exact original instead of guessing at Windows' defaults. A key deleted outside this script has no export to restore from, and the revert says so rather than inventing values.

> ⚠️ **Flush DNS** releases and renews the DHCP lease — a remote session (RDP/VNC/AnyDesk/RustDesk) may drop for a few seconds. **Rebuild icon cache** restarts Explorer. Neither is included when you press `a` (select all).

### 🧹 Debloat (`--debloat`)

Remove pre-installed Windows apps and (optionally) the dev tools/browsers this script installs. The removable list is fully customizable — edit `$script:DebloatItems` at the top of the debloat section.

<details>
<summary>What can be removed — click to expand</summary>

- **Special (force-removed, self-contained — no runtime third-party downloads):**
  - **OneDrive** → the [`that-guy-scott/remove-onedrive`](https://github.com/that-guy-scott/remove-onedrive) script is **vendored inline** and run `-Force -NoReboot` (with a native fallback). Only the 3 em dashes in its comments were changed to ASCII; the logic is the upstream script verbatim.
  - **System Restore** → *(disable + delete all restore points)*: `Disable-ComputerRestore` + `vssadmin delete shadows /all` + a `DisableSR` policy. ⚠️ Deleted restore points are unrecoverable. (Re-enable with the **Enable System Restore** tweak.)
  - **Microsoft Edge** → the [`ShadowWhisperer/Remove-MS-Edge`](https://github.com/ShadowWhisperer/Remove-MS-Edge) removal **logic ported natively** (uninstall + AppX + update services/tasks + registry + System32 stubs), using the system's own `setup.exe` so nothing is downloaded. **WebView2 is deliberately kept** (many apps need it). To put things back, use the `Install: Microsoft Edge` / `Install: Edge WebView2 Runtime` tweaks.
- **UWP bloat:** Xbox app / Game Bar / Game Speech / Xbox Live / Xbox Identity Provider, Get Help, Tips, Feedback Hub, Maps, Weather, News, Solitaire Collection, Groove Music, Movies & TV, People, Phone Link, Clipchamp, consumer Teams, Copilot, Quick Assist
- **More modern apps:** Dev Home, Microsoft 365 / Office, Bing Search, Sticky Notes, Teams (new), To Do, Outlook for Windows, Paint, Power Automate, LinkedIn, Photos, Clock, Calculator, Sound Recorder, Camera, Mobile devices (Cross Device), Widgets Platform Runtime, Web Experience Pack, Snipping Tool, Start Experiences App, Store Purchase App
- **Media/image codec extensions:** VP9 / HEVC / HEIF / WebP / AV1 / … (⚠️ removing these can break video/image playback)
- **Media Features:** disable the `WindowsMediaPlayer` optional feature (Windows Media Player Legacy)
- **Dev tools / browsers:** Chrome, Node.js, Docker, VS Code, DBeaver, Postman, FileZilla, GitHub CLI, cloudflared
- **Remote tools:** AnyDesk, RustDesk, TeamViewer, RealVNC

</details>

> ⚠️ **Edge** is protected by Windows; force-removal can affect WebView-dependent apps and Windows may reinstall it on major updates. It is strictly opt-in from the Debloat sub-menu.

### 🧰 Services (`--services`)

Tri-state submenu (`[x]` = disable, `[r]` = re-enable to the default start type) for ~47 Windows services that are **safe to turn off** — disabling one only stops that feature, never core networking / audio / notifications / time / MS-account. Grouped: telemetry & diagnostics, security/legacy, Xbox, print/scan/fax, and sensors/biometric/location/payments. Core services (networking, audio, updates, connected-devices, per-user `_LUID` services) are deliberately **not** listed. Edit `$script:ServiceItems` to customise. Nothing here is selected by `a` (all).

## 🎛️ Interactive Menu

Run without flags (or with `--menu`) for a keyboard-driven menu:

```powershell
irm https://bit.ly/windows-ey | iex
```

Navigate with **↑↓** (or **PgUp/PgDn/Home/End** for long lists — the list scrolls in a fixed viewport so the header stays put), toggle with **SPACE**, `a` = all, `n` = none, `c`/`ESC` = save & continue, `q` = discard. Grouped items (AI CLI Tools, Remote Support Tools, Windows Tweaks, Explorer & UI, Debloat, VS Code) open their own submenus. In the **Explorer & UI** submenu, SPACE cycles three states instead of two: `[ ]` → `[x]` apply → `[r]` revert.

### 🔑 CLI Aliases

Global `.cmd` commands installed into `%USERPROFILE%\apps\aliases\` (added to PATH, so they work from any shell). Pick them individually inside the **Windows Tweaks** submenu:

- `ccskip` / `cxskip` — Claude Code on your normal Anthropic login, skip-permissions (pinned to Opus 4.8 / Opus 5)
- `cckimi` / `ccglm` — Claude Code on the Kimi / Z.AI-GLM backends (selecting one **auto-installs** its `cckimi-token` / `ccglm-token` key setter)
- `ccor` — Claude Code on the **OpenRouter** gateway (also auto-installs `ccor-token` and `ccor-model`). Defaults to the free `stealth/ox-alpha` (1M ctx, built for coding); switch any time with `ccor-model <id>` using an id from [openrouter.ai/models](https://openrouter.ai/models) — the choice is cached in `%USERPROFILE%\.openrouter_model`.

## 💾 Backup & Restore

The script backs up settings (System Restore point + registry export) before making changes.

```powershell
# Show current backups
& ([scriptblock]::Create((irm 'https://bit.ly/windows-ey'))) --show-backup

# Restore previous settings
& ([scriptblock]::Create((irm 'https://bit.ly/windows-ey'))) --restore
```

## 🔄 Self-Update

On start, the script checks the Gist for a newer revision (compares its own `SCRIPT_REVISION`). If a newer one exists, it offers to download and re-launch it automatically — so `irm | iex` always ends up running the latest version.

- Skip it with `--skip-update`, or by setting the environment variable `SKIP_UPDATE_CHECK=1`.
- The check is automatically skipped when running from a local git checkout (so development copies are never overwritten).

## 🔀 Combining Flags

Install only what you need:

```powershell
& ([scriptblock]::Create((irm 'https://bit.ly/windows-ey'))) --nodejs --docker --vscode --chrome
```

## ⚠️ Error Handling

The script uses an interactive error handler. If any step fails, you're prompted to either continue or abort — no silent failures.

## 📋 Requirements

- Windows 10 / 11
- Administrator access (the script self-elevates)
- Internet connection
- `winget` (App Installer) recommended; Chocolatey is bootstrapped automatically when needed

## License

MIT
