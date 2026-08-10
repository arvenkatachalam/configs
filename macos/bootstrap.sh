#!/usr/bin/env bash
#
# Bootstraps the macOS dotfiles: installs tooling (Homebrew bundle + oh-my-zsh),
# then deploys the configs to their live locations (~/.config/*, ~/.zshrc, ~/.claude/*).
#
# Mirror of windows/bootstrap.ps1. Idempotent: safe to re-run. Configs are
# symlinked back into this repo, so editing a file here takes effect live.
# Anything it would overwrite is moved to ~/.dotfiles-backup/<timestamp>/ first.
#
#   ./bootstrap.sh                  # full Brewfile (formulae + casks) + deploy
#   ./bootstrap.sh --no-casks       # skip GUI apps, VS Code extensions and npm globals
#   ./bootstrap.sh --skip-packages  # only (re)deploy configs
#   ./bootstrap.sh --skip-deploy    # only install packages
#   ./bootstrap.sh --copy           # copy configs instead of symlinking

set -euo pipefail

REPO_MAC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

SKIP_PACKAGES=0
SKIP_DEPLOY=0
NO_CASKS=0
COPY=0

for arg in "$@"; do
  case "$arg" in
    --skip-packages) SKIP_PACKAGES=1 ;;
    --skip-deploy) SKIP_DEPLOY=1 ;;
    --no-casks) NO_CASKS=1 ;;
    --copy) COPY=1 ;;
    -h | --help)
      awk 'NR>2 && /^#/ { sub(/^# ?/, ""); print; next } NR>2 { exit }' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "unknown option: $arg (try --help)" >&2
      exit 1
      ;;
  esac
done

step() { printf '\n\033[36m=== %s ===\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }
warn() { printf '\033[33mwarn: %s\033[0m\n' "$1" >&2; }

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------
install_packages() {
  step 'Homebrew'
  if ! command -v brew >/dev/null 2>&1; then
    info 'installing Homebrew...'
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  info "$(brew --version | head -1)"

  step 'brew bundle'
  if [ "$NO_CASKS" -eq 1 ]; then
    # Formulae + taps only: drop GUI apps, VS Code extensions and npm globals.
    local filtered
    filtered="$(mktemp)"
    grep -Ev '^(cask|vscode|mas|npm) ' "$REPO_MAC/Brewfile" >"$filtered"
    brew bundle --file="$filtered"
    rm -f "$filtered"
  else
    brew bundle --file="$REPO_MAC/Brewfile"
  fi

  # Ghostty keeps its terminfo inside the app bundle, so an incoming SSH session
  # carrying TERM=xterm-ghostty finds nothing in the system db and loses ZLE.
  # Install it into ~/.terminfo so this host is reachable over SSH from Ghostty.
  step 'ghostty terminfo'
  local gt='/Applications/Ghostty.app/Contents/Resources/terminfo'
  if infocmp xterm-ghostty >/dev/null 2>&1; then
    info 'already resolvable'
  elif [ -d "$gt" ]; then
    infocmp -x -A "$gt" xterm-ghostty | tic -x -o "$HOME/.terminfo" -
    info 'installed -> ~/.terminfo'
  else
    warn 'Ghostty.app not found; skipping (SSH from Ghostty will fall back to xterm-256color)'
  fi

  # zshrc sources $ZSH/oh-my-zsh.sh — without it the shell errors on startup.
  step 'oh-my-zsh'
  if [ -d "$HOME/.oh-my-zsh" ]; then
    info 'already installed'
  else
    RUNZSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      "" --unattended --keep-zshrc
  fi
}

# ---------------------------------------------------------------------------
# Deploy: symlink (default) or copy, backing up whatever is already there.
# ---------------------------------------------------------------------------
deploy_config() {
  local src="$REPO_MAC/$1" dst="$2"

  if [ ! -e "$src" ]; then
    warn "missing source: $src"
    return
  fi

  # Already pointing at this repo — nothing to do.
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ] && [ "$COPY" -eq 0 ]; then
    info "ok    ${dst/#$HOME/~}"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    local rel="${dst#"$HOME"/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$dst" "$BACKUP_DIR/$rel"
    info "saved ${dst/#$HOME/~} -> ${BACKUP_DIR/#$HOME/~}/$rel"
  fi

  if [ "$COPY" -eq 1 ]; then
    cp -R "$src" "$dst"
    info "copy  ${dst/#$HOME/~}"
  else
    ln -s "$src" "$dst"
    info "link  ${dst/#$HOME/~} -> ${src/#$HOME/~}"
  fi
}

deploy_all() {
  step "Deploying configs ($([ "$COPY" -eq 1 ] && echo copy || echo symlink) mode)"
  local cfg="$HOME/.config"

  deploy_config 'zshrc' "$HOME/.zshrc"
  deploy_config 'starship.toml' "$cfg/starship.toml"
  deploy_config 'alacritty.toml' "$cfg/alacritty.toml"
  deploy_config 'ghostty' "$cfg/ghostty"
  deploy_config 'zellij/config.kdl' "$cfg/zellij/config.kdl"
  deploy_config 'btop/btop.conf' "$cfg/btop/btop.conf"
  deploy_config 'cava' "$cfg/cava"
  deploy_config 'aerospace/aerospace.toml' "$cfg/aerospace/aerospace.toml"
  deploy_config 'nvim' "$cfg/nvim"
  deploy_config 'git/ignore' "$cfg/git/ignore"
  deploy_config 'zsh/catppuccin-mocha.zsh' "$cfg/zsh/catppuccin-mocha.zsh"
  deploy_config 'claude-settings.json' "$HOME/.claude/settings.json"
  deploy_config 'statusline-command.sh' "$HOME/.claude/statusline-command.sh"

  # global gitignore
  git config --global core.excludesfile "$cfg/git/ignore"
}

# ---------------------------------------------------------------------------
[ "$SKIP_PACKAGES" -eq 1 ] || install_packages
[ "$SKIP_DEPLOY" -eq 1 ] || deploy_all

step 'Next steps'
cat <<'EOF'
 - Restart the terminal (or `exec zsh`) to load zsh + starship.
 - Set the terminal font to "JetBrainsMono Nerd Font" (Ghostty/Alacritty already do).
 - Launch nvim once to let lazy.nvim + Mason install, then run :checkhealth.
 - Start AeroSpace and grant Accessibility permission (System Settings > Privacy).
 - Re-run `brew bundle dump --file=macos/Brewfile --force` after installing software.
EOF
