# macOS → Windows tool & config mapping

How each tool from the macOS setup (`macos/Brewfile` + the dotfiles) maps to Windows.
Target environment: **native Windows 11 + PowerShell 7** (no WSL).

## Package managers

| macOS | Windows | Notes |
|---|---|---|
| Homebrew (formulae) | **Scoop** | CLI tools, per-user, no admin. Buckets: `main`, `extras`, `nerd-fonts`, `versions`. |
| Homebrew (casks) | **winget** | GUI apps; Microsoft-official, IT-friendly. |
| `brew bundle` | `windows/bootstrap.ps1` | Installs everything + deploys configs. |
| `brew bundle dump` | `scoop export > scoop.json`, `winget export -o winget.json` | Regenerate the inventory snapshots. |

## CLI tools (Brewfile formulae → Scoop, unless noted)

| macOS (brew) | Windows | Installer |
|---|---|---|
| node | `nodejs-lts` | scoop main |
| git | `git` | scoop main (also required by scoop) |
| neovim | `neovim` | scoop main |
| ripgrep | `ripgrep` | scoop main |
| fzf | `fzf` | scoop main |
| lsd | `lsd` | scoop main |
| starship | `starship` | scoop main |
| gh | `gh` | scoop main |
| fastfetch | `fastfetch` | scoop main |
| uv | `uv` | scoop main |
| tree-sitter-cli | `tree-sitter` | scoop main |
| zellij | `zellij` | scoop main — **native Windows since 0.44 (no WSL)** |
| luarocks | `luarocks` | scoop main |
| lazygit | `lazygit` | scoop extras |
| bitwarden-cli | `bitwarden-cli` | scoop extras |
| btop | **`btop-lhm`** | scoop extras — Windows btop w/ LibreHardwareMonitor |
| yazi | `yazi` | **winget `sxyazi.yazi`** — yazi docs advise against Scoop (Unicode) |
| tmux | — | no native Windows; use **zellij** (native) or Windows Terminal panes |
| cmatrix | — | no maintained Scoop pkg; `termatrix`/WSL if wanted (cosmetic) |
| gemini-cli | `@google/gemini-cli` | npm global |
| opencode | `opencode-ai` | npm global |
| claude-code (cask) | `@anthropic-ai/claude-code` | npm global |
| dotbot | `bootstrap.ps1` | symlink/copy deploy; `chezmoi` is an alternative |
| qmk | QMK MSYS | hobby; separate MSYS2 environment on Windows |
| llmfit | — | no Windows build known |

### Windows-only prerequisites added (for parity)

| Tool | Why | Installer |
|---|---|---|
| `zig` | C compiler for `nvim-treesitter` (macOS uses clang) | scoop main |
| `python` | `pynvim` + `debugpy` for Neovim | scoop main |
| `win32yank` | Neovim system-clipboard provider | scoop extras |
| `fd`, `zoxide` | fzf/yazi companions + `z` jumping | scoop main |

## GUI apps (Brewfile casks → winget)

| macOS cask | Windows (winget id) | Notes |
|---|---|---|
| ghostty | **Windows Terminal** + **Alacritty** | Ghostty has no official Windows build |
| aerospace | **GlazeWM** | i3-style tiling; keybinds reproduced |
| cursor | `Anysphere.Cursor` | |
| claude | `Anthropic.Claude` | id best-guess; `--ignore-unavailable` handles misses |
| claude-code | (npm, see above) | |
| calibre | `calibre.calibre` | |
| todoist-app | `Doist.Todoist` | |
| (VS Code exts host) | `Microsoft.VisualStudioCode` | extensions installed via `code --install-extension` |
| linearmouse | X-Mouse Button Control / PowerToys | no 1:1 equivalent |
| insta360-link-controller | Insta360 Link Controller (Windows) | vendor download; not on winget reliably |
| codex-app | — | availability varies |
| google-gemini | — | web app; no native desktop parity |
| timemachineeditor | Windows File History / built-in backup | macOS-only concept |
| Nerd Fonts (JBMono/Iosevka/Atkinson) | scoop `nerd-fonts` bucket (`JetBrainsMono-NF`, `Iosevka-NF`) | |

## Config files

| macOS config | Windows config | Deploy target |
|---|---|---|
| `zshrc` | `powershell/Microsoft.PowerShell_profile.ps1` | `$PROFILE` |
| `zsh/catppuccin-mocha.zsh` | PSReadLine `-Colors` block in the profile | (in profile) |
| `starship.toml` | `starship.toml` (verbatim) | `~/.config/starship.toml` |
| `ghostty/config` | `windows-terminal/settings.fragment.json` (+ merge script) | WT `settings.json` (merged) |
| `alacritty.toml` | `alacritty/alacritty.toml` (ported) | `%APPDATA%\alacritty\alacritty.toml` |
| `zellij/config.kdl` | `zellij/config.kdl` (`default_shell "pwsh"`) | `%APPDATA%\zellij\config.kdl` |
| `aerospace/aerospace.toml` | `glazewm/config.yaml` | `~/.glzr/glazewm/config.yaml` |
| `nvim/` | `nvim/` (verbatim copy) | `%LOCALAPPDATA%\nvim\` |
| `git/ignore` | `git/ignore` (+ Windows entries) | `~/.config/git/ignore` |
| `btop/btop.conf` | `btop/btop.conf` | `%APPDATA%\btop\btop.conf` |
| `claude-settings.json` | `claude/settings.json` | `~/.claude/settings.json` |
| `statusline-command.sh` | `claude/statusline-command.ps1` | `~/.claude/statusline-command.ps1` |

## Shell: zsh → PowerShell 7

| macOS (zsh) | Windows (PowerShell) |
|---|---|
| oh-my-zsh `git` plugin | `posh-git` module |
| zsh-autosuggestions | PSReadLine `-PredictionSource History -PredictionViewStyle ListView` |
| zsh-syntax-highlighting | PSReadLine `-Colors` (Catppuccin Mocha) |
| zsh-autocomplete | PSReadLine (built-in menu completion) |
| `source <(fzf --zsh)` | PSFzf (`Ctrl+t` / `Ctrl+r`) |
| `eval "$(starship init zsh)"` | `Invoke-Expression (&starship init powershell)` |
| `alias ls='lsd'` | `Remove-Item Alias:ls; function ls { lsd @args }` |
| `alias vim='nvim'` | `Set-Alias vim nvim` |
| `EDITOR=nvim`, `MANPAGER='nvim +Man!'` | `$env:EDITOR='nvim'` (no MANPAGER on Windows) |

## Caveats

- **Claude statusline path**: `settings.json` uses `%USERPROFILE%\.claude\statusline-command.ps1`.
  If the status line doesn't render, replace `%USERPROFILE%` with the absolute path
  (`C:\Users\<you>\...`) — depends on how Claude Code spawns the command on Windows.
- **Windows Terminal**: its `settings.json` is machine-generated — the fragment is **merged**,
  never overwritten (backup written to `settings.json.bak`).
- **Symlinks** need Developer Mode or admin; otherwise `bootstrap.ps1` copies (re-run after edits).
- **GlazeWM** config targets the **v3.x** schema; if you're on v2, regenerate from its sample.
