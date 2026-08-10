# .dotfiles

Personal development environment configuration files for **macOS** and **Windows**.

The repo is split by operating system:

- **[`macos/`](macos)** — the macOS setup (Homebrew, zsh, Ghostty/Alacritty, AeroSpace, …).
- **[`windows/`](windows)** — a native Windows 11 + PowerShell 7 port (Scoop/winget, Windows
  Terminal/Alacritty, GlazeWM, …). See **[`windows/MAPPING.md`](windows/MAPPING.md)** for the
  tool-by-tool macOS→Windows equivalence.

## Tools

| Purpose | macOS | Windows |
|---|---|---|
| Shell | zsh + oh-my-zsh | PowerShell 7 (PSReadLine, PSFzf, posh-git) |
| Prompt | [starship](https://starship.rs/) | starship |
| Terminal | [Ghostty](https://ghostty.org/) / [Alacritty](https://alacritty.org/) | [Windows Terminal](https://aka.ms/terminal) / Alacritty |
| Multiplexer | [zellij](https://zellij.dev/) / tmux | zellij (native ≥ 0.44) |
| Editor | [Neovim](https://neovim.io/) (AstroNvim v6) | Neovim (AstroNvim v6) |
| Window manager | [AeroSpace](https://github.com/nikitabobko/AeroSpace) | [GlazeWM](https://github.com/glzr-io/glazewm) |
| Packages | [Homebrew](https://brew.sh/) | [Scoop](https://scoop.sh/) + [winget](https://learn.microsoft.com/windows/package-manager/) |
| System monitor | [btop](https://github.com/aristocratos/btop) | btop-lhm |
| File manager | [yazi](https://yazi-rs.github.io/) | yazi |

## Theme

- **Colorscheme**: Tokyo Night (nvim, starship) / Catppuccin Mocha (terminals, shell)
- **Font**: JetBrainsMono Nerd Font

## Setup

### macOS

```sh
git clone git@github.com:arvenkatachalam/dotfiles.git ~/dotfiles
cd ~/dotfiles/macos
./bootstrap.sh
```

`bootstrap.sh` installs everything (`brew bundle` + oh-my-zsh) and symlinks the files under
`macos/` to their live locations (`~/.config/*`, `~/.zshrc`, `~/.claude/*`) — whatever it would
overwrite is moved to `~/.dotfiles-backup/<timestamp>/` first. Flags: `--no-casks` (formulae only),
`--skip-packages` (re-deploy configs only), `--skip-deploy`, `--copy` (copy instead of symlink).

Regenerate the Brewfile after installing/removing software:

```sh
brew bundle dump --file=~/dotfiles/macos/Brewfile --force
```

### Windows

```powershell
git clone https://github.com/arvenkatachalam/dotfiles.git ~/dotfiles
cd ~/dotfiles/windows
pwsh -ExecutionPolicy Bypass -File .\bootstrap.ps1
pwsh -File .\validate.ps1
```

`bootstrap.ps1` installs everything (Scoop + winget + modules) and deploys the configs. See
**[`windows/README.md`](windows/README.md)** for details and the validation checklist.

Neovim plugins install automatically on first launch via lazy.nvim (both OSes).
