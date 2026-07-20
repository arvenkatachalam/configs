# Windows dotfiles

Native **Windows 11 + PowerShell 7** port of the macOS setup in [`../macos/`](../macos).
Tool/config equivalences are documented in [`MAPPING.md`](MAPPING.md).

## Prerequisites

- **Windows 10 21H2+/Windows 11**, **PowerShell 7** (`winget install Microsoft.PowerShell`).
- **App Installer** (provides `winget`) from the Microsoft Store.
- Optional but recommended: **Developer Mode** on (Settings → Privacy & security → For developers)
  so configs are deployed as symlinks instead of copies.
- Everything else (git, a C compiler via `zig`, Python, fonts) is installed by `bootstrap.ps1`.

## Quick start

```powershell
git clone https://github.com/arvenkatachalam/dotfiles.git ~/dotfiles
cd ~/dotfiles/windows
pwsh -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

Then restart the terminal and run `.\validate.ps1`.

## What `bootstrap.ps1` does

1. Installs **Scoop** + buckets (`main`, `extras`, `nerd-fonts`, `versions`) and the CLI tools.
2. `winget install` the GUI apps (Windows Terminal, PowerShell, VS Code, Cursor, Claude, yazi, …).
3. Installs PowerShell modules: **PSReadLine, PSFzf, posh-git**.
4. Installs npm globals (claude-code, gemini-cli, opencode, …) and VS Code extensions.
5. **Deploys configs** to their targets (symlink if Developer Mode/admin, else copy).

Useful flags: `-SkipPackages` (only redeploy configs), `-SkipDeploy` (only install), `-CopyOnly`.

## Deploy targets

| Source (this dir) | Target |
|---|---|
| `powershell/Microsoft.PowerShell_profile.ps1` | `$PROFILE` |
| `starship.toml` | `~/.config/starship.toml` |
| `alacritty/alacritty.toml` | `%APPDATA%\alacritty\alacritty.toml` |
| `zellij/config.kdl` | `%APPDATA%\zellij\config.kdl` |
| `glazewm/config.yaml` | `~/.glzr/glazewm/config.yaml` |
| `nvim/` | `%LOCALAPPDATA%\nvim\` |
| `git/ignore` | `~/.config/git/ignore` (+ `core.excludesfile`) |
| `claude/settings.json`, `claude/statusline-command.ps1` | `~/.claude/` |
| `btop/btop.conf` | `%APPDATA%\btop\btop.conf` |
| `windows-terminal/settings.fragment.json` | merged into WT `settings.json` |

## Manual steps after bootstrap

- **Terminal font**: set to `JetBrainsMono Nerd Font` (installed via Scoop) in Windows Terminal /
  Alacritty if not already applied.
- **Windows Terminal**: launch it once *before* the merge so its `settings.json` exists
  (bootstrap handles the merge; re-run `windows-terminal/merge-wt-settings.ps1` if needed).
- **GlazeWM autostart**: enable "Start on boot" from its tray icon, or add a shortcut to
  `shell:startup`. Reload config with `alt+shift+r`.
- **Neovim**: launch once to let lazy.nvim + Mason install, then `:checkhealth`.

## Validation

**Tier 1 — automated self-check** (run after bootstrap):

```powershell
pwsh -File .\validate.ps1          # add -SkipNvim to skip the slow nvim checks
```

Verifies each tool resolves, every config is deployed + parses, the profile dot-sources cleanly,
the fonts are present, the Claude status line renders, and `nvim :checkhealth` passes.

**Tier 2 — manual smoke test** (things that need a GUI/keyboard):

- [ ] Windows Terminal opens → PowerShell 7 default, Catppuccin colors, JetBrainsMono, ~70% acrylic,
      starship prompt renders.
- [ ] Alacritty opens with the theme/opacity and no errors.
- [ ] `ls` shows lsd output; `vim` opens nvim; `Ctrl+t` / `Ctrl+r` trigger fzf.
- [ ] **GlazeWM**: `alt+h/j/k/l` focus, `alt+shift+h/j/k/l` move, `alt+1..9` switch workspaces,
      `alt+shift+q` close, `alt+r` resize mode, `alt+shift+r` reload.
- [ ] Claude Code shows the Tokyo-Night status line (user, cwd, git, model, context %, time).
- [ ] `lazygit`, `zellij` (splits), `yazi`, `btop` launch.

## Notes

- **Claude statusline path**: if the status line is blank, edit `~/.claude/settings.json` and replace
  `%USERPROFILE%` with your absolute home path — see [`MAPPING.md`](MAPPING.md#caveats).
- Cross-platform configs (`nvim/`, `starship.toml`, `zellij/`, `git/ignore`) are **duplicated** from
  `../macos/` so this directory is self-contained. Keep them in sync when editing either side.
