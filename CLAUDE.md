# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles for **macOS** and **Windows**, checked out at `~/.dotfiles/configs`. The repo is
split into two self-contained, per-OS sets plus repo-level docs at the root:

- **`macos/`** — the macOS setup; source of truth for configs read from `~/.config/*`, `~/.zshrc`,
  `~/.claude/*` (deployed as symlinks by `macos/bootstrap.sh`, so edits here are live). There is no
  build/test suite — a change takes effect when the tool re-reads its config.
- **`windows/`** — a native Windows 11 + PowerShell 7 port (see `windows/MAPPING.md` for the
  macOS→Windows tool mapping and `windows/README.md` for setup).

Cross-platform configs that are byte-identical (`nvim/`, `starship.toml`, `zellij/`, `git/ignore`)
are **duplicated** in both `macos/` and `windows/` so each set stands alone — keep them in sync when
editing either side.

## Repository Layout & Deployment

- **Root (repo meta):** `README.md`, `CLAUDE.md`, `.gitignore`, `.claude/settings.local.json`.
- **macOS packages/deploy** — `macos/bootstrap.sh` (`brew bundle` + oh-my-zsh, then symlinks the
  configs to their live locations; flags `--no-casks`, `--skip-packages`, `--skip-deploy`, `--copy`).
  It resolves its own path, so the repo can live anywhere, and moves anything it would overwrite to
  `~/.dotfiles-backup/<timestamp>/`. Packages: `macos/Brewfile`; regenerate with
  `brew bundle dump --file=macos/Brewfile --force`.
- **Windows packages/deploy** — `windows/bootstrap.ps1` (Scoop + winget + modules, then deploys
  configs). Snapshots: `windows/scoop.json`, `windows/winget.json`.
- **`.gitignore`** uses `**/`-anchored patterns so generated files are ignored under both `macos/`
  and `windows/` (e.g. `**/nvim/lazy-lock.json`); it also carries macOS (`.DS_Store`) and Windows
  (`Thumbs.db`, `Desktop.ini`) noise.
- **`macos/git/ignore`** / **`windows/git/ignore`** are the user's *global* gitignore
  (`core.excludesfile`) — distinct from the repo's own `.gitignore`.

## Two Neovim Configurations

1. **`macos/nvim/`** (mirrored verbatim at **`windows/nvim/`**) — AstroNvim v6 config using lazy.nvim.
   The primary active config.
   - Entry: `nvim/init.lua` bootstraps lazy.nvim, then loads `lua/lazy_setup.lua` and `lua/polish.lua`
   - `lua/lazy_setup.lua` pins AstroNvim to `version = "^6"`, then imports `community` and `plugins/`
   - Plugin specs are individual files in `lua/plugins/*.lua` returning LazySpec tables
   - Leader `<Space>`, local leader `,`; colorscheme `tokyonight-night` (`lua/plugins/astroui.lua`)
   - Mason tools (`lua/plugins/mason.lua`): lua-language-server, stylua, debugpy, tree-sitter-cli
   - Claude Code integration via `lua/plugins/claudecode.lua` (`<leader>a` prefix)
   - `lua/community.lua` and `lua/polish.lua` are disabled by an `if true then return … end` guard —
     editing them without removing that line has no effect.
   - On Windows, tree-sitter needs a C compiler (`zig`), debugpy needs Python+`pynvim`, and clipboard
     uses `win32yank` — all installed by `windows/bootstrap.ps1`.

2. **`macos/init.lua`** (root of `macos/`) — a standalone Kickstart.nvim config (backup/alternative,
   not used by the `nvim/` directory and not deployed on Windows).

## Lua Formatting & Linting

- **StyLua** — config `macos/nvim/.stylua.toml`: 120 col, 2-space, Unix LE,
  `collapse_simple_statement = "Always"`, `call_parentheses = "None"`. Run `stylua macos/nvim/`.
- **Selene** — config `macos/nvim/selene.toml` (`std = "neovim"`). Run `selene macos/nvim/`.

## Terminal & Shell

macOS (`macos/`):
- **Ghostty** (`ghostty/config`), **Alacritty** (`alacritty.toml`): Catppuccin Mocha, JetBrainsMono
  Nerd Font, 70% opacity.
- **Starship** (`starship.toml`): Tokyo Night powerline prompt.
- **Zsh** (`zshrc` → `~/.zshrc`): oh-my-zsh + starship; aliases `ls`→`lsd`, `vim`→`nvim`; sources
  zsh-syntax-highlighting/zsh-autosuggestions + fzf. `zsh/catppuccin-mocha.zsh` is the highlight theme.
- **Zellij** (`zellij/config.kdl`), **btop**, **cava**.

Windows (`windows/`) — see `windows/MAPPING.md`:
- **PowerShell 7** profile (`powershell/Microsoft.PowerShell_profile.ps1` → `$PROFILE`) translates
  `zshrc`: PSReadLine (highlight+autosuggest, Catppuccin colors), PSFzf, posh-git, starship.
- **Windows Terminal** (`windows-terminal/settings.fragment.json`, **merged** into the live
  `settings.json` by `merge-wt-settings.ps1` — never overwritten) + **Alacritty** (`alacritty/`).

## Claude Code Integration

- macOS: `macos/claude-settings.json` → `~/.claude/settings.json`; `macos/statusline-command.sh`
  (bash, Tokyo Night status line, per-session token accumulation).
- Windows: `windows/claude/settings.json` (statusLine → `pwsh`) + `windows/claude/statusline-command.ps1`
  (PowerShell rewrite; tokens keyed by `session_id` in TEMP).
- Neovim: `nvim/lua/plugins/claudecode.lua` wires `coder/claudecode.nvim` under `<leader>a`.

## Window Management

- macOS: **AeroSpace** (`macos/aerospace/aerospace.toml`) — Alt+hjkl focus, Alt+Shift+hjkl move,
  Alt+1-9 workspaces, service mode via Alt+Shift+semicolon.
- Windows: **GlazeWM** (`windows/glazewm/config.yaml`, v3 schema) reproduces those keybinds
  (alt+h/j/k/l focus, alt+shift+… move, alt+1..9 workspaces, alt+r resize mode, alt+shift+r reload).

## Windows Validation

- `windows/validate.ps1` — post-bootstrap self-check (tools resolve, configs deployed + parse,
  `$PROFILE` loads, fonts present, statusline renders, `nvim :checkhealth`).
- Manual GUI smoke-test checklist in `windows/README.md`.

## Theme Consistency

Tokyo Night (terminals/nvim/starship) and Catppuccin Mocha (terminals/shell) across both OSes.
Font: JetBrainsMono Nerd Font everywhere.
