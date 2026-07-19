# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal macOS dotfiles. This repository is checked out at `~/.dotfiles/configs` and is the
source of truth for configs that each tool reads from its own conventional location
(`~/.config/*`, `~/.zshrc`, `~/.claude/*`, …). There is no build step and no test suite — a
change takes effect when the relevant tool re-reads its config or on next launch.

## Repository Layout & Deployment

- **Packages** — Homebrew taps, formulae, casks, fonts, and VS Code extensions are declared in
  `Brewfile`. Install everything with `brew bundle --file=Brewfile`. After adding/removing
  software, regenerate it with `brew bundle dump --file=Brewfile --force`.
- **`.gitignore`** deliberately excludes app-generated state (`gh/`, `raycast/`, `iterm2/`, …)
  and auto-refetched assets (`alacritty/themes/`, `btop/themes/`, `nvim/lazy-lock.json`, …).
  Don't commit these; they are re-created on each machine.
- **`git/ignore`** is the user's *global* gitignore (`core.excludesfile`) — distinct from this
  repo's own `.gitignore`.
- **`**/.claude/settings.local.json`** is git-ignored (machine-local Claude Code settings).

## Two Neovim Configurations

There are two independent Neovim configs in this repo:

1. **`nvim/`** — AstroNvim v6 based config using lazy.nvim. This is the primary active config.
   - Entry: `nvim/init.lua` bootstraps lazy.nvim, then loads `lua/lazy_setup.lua` and `lua/polish.lua`
   - `lua/lazy_setup.lua` pins AstroNvim to `version = "^6"`, then imports `community` and the `plugins/` folder
   - Plugin specs go in `lua/plugins/*.lua` as individual files returning LazySpec tables
   - Leader key: `<Space>`, local leader: `,`
   - Colorscheme: `tokyonight-night` (set in `lua/plugins/astroui.lua`)
   - LSP tools managed via Mason (`lua/plugins/mason.lua`): lua-language-server, stylua, debugpy, tree-sitter-cli
   - Claude Code integration via `lua/plugins/claudecode.lua` with `<leader>a` prefix keybinds
   - `lua/community.lua` and `lua/polish.lua` are currently disabled (early-return guards). Editing
     them without removing the `if true then return … end` guard line has no effect.

2. **`init.lua`** (root) — Kickstart.nvim based config (standalone, not used by the `nvim/` directory). This is an alternative/backup config using a single-file approach with inline lazy.nvim setup.

## Lua Formatting & Linting

The `nvim/` Lua is the only code in this repo with tooling:

- **StyLua** (formatter) — config `nvim/.stylua.toml`: 120 column width, 2-space indentation, Unix
  line endings, `collapse_simple_statement = "Always"`, `call_parentheses = "None"`. Run `stylua nvim/`.
- **Selene** (linter) — config `nvim/selene.toml` (`std = "neovim"`). Run `selene nvim/`.

StyLua and the Lua language server are also installed inside Neovim via Mason, so editing in nvim
formats/diagnoses without the CLIs.

## Terminal & Shell

- **Ghostty** (`ghostty/config`): Primary terminal. Catppuccin Mocha theme, JetBrainsMono Nerd Font Mono, 70% opacity with blur.
- **Alacritty** (`alacritty.toml`): Secondary terminal. Catppuccin Mocha theme, JetBrainsMono Nerd Font, 70% opacity.
- **Starship** (`starship.toml`): Shell prompt. Custom Tokyo Night-themed powerline segments with OS, directory, git, language versions, docker, and time modules.
- **Zsh** (`zshrc`, deployed as `~/.zshrc`): oh-my-zsh + starship. Sets `EDITOR=nvim`,
  `MANPAGER='nvim +Man!'`, aliases `ls`→`lsd` and `vim`→`nvim`, and sources homebrew
  zsh-syntax-highlighting/zsh-autosuggestions plus fzf key bindings. `zsh/catppuccin-mocha.zsh` is
  the syntax-highlighting color theme.
- **Zellij** (`zellij/config.kdl`): Terminal multiplexer.
- **btop** (`btop/btop.conf`) and **cava** (`cava/config`): System monitor and audio visualizer.

## Claude Code Integration

- `claude-settings.json` → deployed as `~/.claude/settings.json`; selects the command status line
  and default model (`opus`).
- `statusline-command.sh` → `~/.claude/statusline-command.sh`; renders a Tokyo Night-styled status
  line (user, cwd, git, model, context %) and accumulates per-session token counts in a temp file
  keyed by `$PPID`.
- Inside Neovim, `nvim/lua/plugins/claudecode.lua` wires `coder/claudecode.nvim` under the
  `<leader>a` prefix (toggle/focus/send/diff-accept/deny, model select, resume/continue).

## Window Management

- **AeroSpace** (`aerospace/aerospace.toml`): Tiling window manager. Alt+hjkl for focus, Alt+Shift+hjkl for move, Alt+1-9 for workspaces. Workspaces 1-5 on main monitor, 6-9 on secondary. Service mode via Alt+Shift+semicolon.

## Theme Consistency

Tokyo Night (terminals/nvim/starship) and Catppuccin Mocha (terminals/zsh) are used across tools. Font is JetBrainsMono Nerd Font everywhere.
