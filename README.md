# Windows Post-Installation Setup Script

A comprehensive, modular PowerShell script that automates Windows 10/11 post-installation setup. Install your favorite tools, tweak the desktop, debloat the system, and get a fresh Windows machine ready for development in minutes — from a single command.

The Windows-native counterpart of the [Ubuntu Post-Installation Setup Script](https://github.com/enginyilmaaz/ubuntu-setup-script).

**Version:** 1.0.0

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
| `--vlc` | VLC Media Player |
| `--cloudflared` | Cloudflare Tunnel client |
| `--gh` | GitHub CLI (`gh`) |
| `--postman` | Postman |
| `--filezilla` | FileZilla (FTP/SFTP client) |
| `--tweaks` | Windows desktop tweaks (submenu) |
| `--debloat` | Remove pre-installed bloat (submenu) |
| `--login` | CLI login helpers |

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
| `--glm` | **GLM Code** — z.ai coding helper |
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
| CLI Aliases | PowerShell profile functions (`claude-skip`, etc.) |
| Screen Off: Never | Disable display timeout + sleep |
| Show Hidden Files | Show hidden files + file extensions |
| Keyboard: Turkish Q | Add Turkish-Q keyboard layout |
| Keyboard: English Q | Add English (US) keyboard layout |
| English Language | Set display language to English (US) |
| Auto-Login | Auto-login to Windows on boot |
| Always Show Tray Icons | Show all notification-area icons |
| Taskbar Tweaks | Taskbar alignment/size adjustments |
| Activate Error Reporting | Enable Windows Error Reporting |
| Install Camera App | Install the Windows Camera app |
| Cleanup: Storage Sense | Auto-clean temp files & recycle bin |

</details>

> Before applying tweaks, the script creates a **System Restore point** and exports the touched registry keys to `%USERPROFILE%\.windows_setup_conf_backup`.

### 🧹 Debloat (`--debloat`)

Remove pre-installed Windows apps and (optionally) the dev tools/browsers this script installs. The removable list is fully customizable — edit `$script:DebloatItems` at the top of the debloat section.

<details>
<summary>What can be removed — click to expand</summary>

- **UWP bloat:** Xbox, Get Help, Tips, Feedback Hub, Maps, Weather, News, Solitaire Collection, Groove Music, Movies & TV, People, Phone Link, Clipchamp, consumer Teams, Copilot, Quick Assist
- **Dev tools / browsers:** Chrome, Node.js, Docker, VS Code, DBeaver, Postman, FileZilla, GitHub CLI, cloudflared
- **Remote tools:** AnyDesk, RustDesk, TeamViewer, RealVNC

</details>

## 🎛️ Interactive Menu

Run without flags (or with `--menu`) for a keyboard-driven menu:

```powershell
irm https://bit.ly/windows-ey | iex
```

Navigate with **↑↓**, toggle with **SPACE**, `a` = all, `n` = none, `c`/`ESC` = save & continue, `q` = discard. Grouped items (AI CLI Tools, Remote Support Tools, Windows Tweaks, Debloat, VS Code) open their own submenus.

## 💾 Backup & Restore

The script backs up settings (System Restore point + registry export) before making changes.

```powershell
# Show current backups
& ([scriptblock]::Create((irm 'https://bit.ly/windows-ey'))) --show-backup

# Restore previous settings
& ([scriptblock]::Create((irm 'https://bit.ly/windows-ey'))) --restore
```

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
