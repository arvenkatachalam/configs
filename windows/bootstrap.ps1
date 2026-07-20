#Requires -Version 7.0
<#
.SYNOPSIS
    Bootstraps the Windows dotfiles: installs tooling (Scoop + winget), PowerShell
    modules, npm globals, VS Code extensions, then deploys the configs to their
    live locations.

.DESCRIPTION
    Mirror of the macOS `brew bundle` + manual-copy workflow. Idempotent: safe to
    re-run. Deploys configs via symlink when Developer Mode / admin is available,
    otherwise falls back to copying (in copy mode, re-run after editing a config).

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File .\bootstrap.ps1
    pwsh -File .\bootstrap.ps1 -SkipPackages    # only (re)deploy configs
#>
[CmdletBinding()]
param(
    [switch]$SkipPackages,   # skip Scoop/winget/npm/module install, only deploy configs
    [switch]$SkipDeploy,     # only install packages, don't touch config targets
    [switch]$CopyOnly        # force copy deploy (don't attempt symlinks)
)

$ErrorActionPreference = 'Stop'
$RepoWin = $PSScriptRoot   # ...\dotfiles\configs\windows

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

# ---------------------------------------------------------------------------
# Package inventory (authoritative). scoop.json / winget.json are regenerable
# snapshots of this, produced with `scoop export` / `winget export`.
# ---------------------------------------------------------------------------
$ScoopBuckets = @('main', 'extras', 'nerd-fonts', 'versions')

# name = scoop app; value = bucket (for a clean, unambiguous install)
$ScoopApps = [ordered]@{
    'git'           = 'main'      # also required by scoop itself
    '7zip'          = 'main'
    'ripgrep'       = 'main'
    'fzf'           = 'main'
    'fd'            = 'main'       # fzf/yazi companion
    'lsd'           = 'main'
    'starship'      = 'main'
    'neovim'        = 'main'
    'gh'            = 'main'
    'fastfetch'     = 'main'
    'uv'            = 'main'
    'tree-sitter'   = 'main'      # tree-sitter-cli
    'zellij'        = 'main'      # native Windows since 0.44
    'luarocks'      = 'main'
    'zoxide'        = 'main'
    'python'        = 'main'      # for pynvim / debugpy
    'zig'           = 'main'      # C compiler for nvim-treesitter on Windows
    'nodejs-lts'    = 'main'      # node
    'lazygit'       = 'extras'
    'btop-lhm'      = 'extras'    # btop for Windows (LibreHardwareMonitor)
    'glazewm'       = 'extras'    # tiling WM (AeroSpace replacement)
    'alacritty'     = 'extras'
    'win32yank'     = 'extras'    # nvim clipboard provider
    'bitwarden-cli' = 'extras'
    'JetBrainsMono-NF'      = 'nerd-fonts'
    'JetBrainsMono-NF-Mono' = 'nerd-fonts'
    'Iosevka-NF'            = 'nerd-fonts'
}

# GUI apps + Windows Terminal + PowerShell 7 (winget). --ignore-unavailable in
# import handles any ID that isn't published; a couple are best-guess (see MAPPING.md).
$WingetIds = @(
    'Microsoft.WindowsTerminal',
    'Microsoft.PowerShell',
    'Microsoft.VisualStudioCode',
    'Anysphere.Cursor',
    'Anthropic.Claude',
    'sxyazi.yazi',            # yazi: winget (NOT scoop, per yazi docs)
    'calibre.calibre',
    'Doist.Todoist'
)

$PSModules = @('PSReadLine', 'PSFzf', 'posh-git')

# node CLIs (brew gemini-cli/opencode/claude-code + npm globals) → npm on Windows
$NpmGlobals = @(
    '@anthropic-ai/claude-code',
    '@google/gemini-cli',
    'opencode-ai',
    'obsidian-headless',
    'worm-scraper'
)

# VS Code extensions (mirrors Brewfile `vscode` lines)
$CodeExtensions = @(
    'batisteo.vscode-django', 'bierner.markdown-checkbox', 'catppuccin.catppuccin-vsc',
    'catppuccin.catppuccin-vsc-icons', 'davidanson.vscode-markdownlint',
    'donjayamanne.python-extension-pack', 'eamodio.gitlens', 'enkia.tokyo-night',
    'google.geminicodeassist', 'kevinrose.vsc-python-indent',
    'ms-azuretools.vscode-containers', 'ms-azuretools.vscode-docker',
    'ms-python.debugpy', 'ms-python.python', 'ms-python.vscode-pylance',
    'ms-toolsai.jupyter', 'ms-toolsai.jupyter-keymap', 'ms-toolsai.jupyter-renderers',
    'ms-toolsai.vscode-jupyter-cell-tags', 'ms-toolsai.vscode-jupyter-slideshow',
    'ms-vscode-remote.remote-containers', 'ms-vscode.atom-keybindings',
    'njpwerner.autodocstring', 'redhat.vscode-yaml',
    'shd101wyy.markdown-preview-enhanced', 'yzhang.markdown-all-in-one'
)

# ---------------------------------------------------------------------------
function Install-Packages {
    Write-Step 'Scoop'
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host 'Installing Scoop...'
        Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
    }
    foreach ($b in $ScoopBuckets) {
        if ((scoop bucket list 6>$null | Select-String -SimpleMatch $b) -eq $null) {
            scoop bucket add $b
        }
    }
    foreach ($app in $ScoopApps.Keys) {
        $bucket = $ScoopApps[$app]
        Write-Host "scoop install $bucket/$app"
        scoop install "$bucket/$app"
    }

    Write-Step 'winget (GUI apps)'
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        foreach ($id in $WingetIds) {
            winget install --id $id --exact --silent `
                --accept-package-agreements --accept-source-agreements `
                --disable-interactivity 2>$null
        }
    } else {
        Write-Warning 'winget not found; skipping GUI apps. Install App Installer from the Store.'
    }

    Write-Step 'PowerShell modules'
    if (-not (Get-PSRepository PSGallery).InstallationPolicy -eq 'Trusted') {
        Set-PSRepository PSGallery -InstallationPolicy Trusted
    }
    foreach ($m in $PSModules) {
        Install-Module $m -Scope CurrentUser -Force -AllowClobber
    }

    Write-Step 'npm globals'
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        foreach ($pkg in $NpmGlobals) { npm install -g $pkg }
    } else {
        Write-Warning 'npm not found (node install may need a new shell); re-run to install npm globals.'
    }

    Write-Step 'VS Code extensions'
    if (Get-Command code -ErrorAction SilentlyContinue) {
        foreach ($ext in $CodeExtensions) { code --install-extension $ext --force }
    } else {
        Write-Warning 'code CLI not found; open VS Code once, then re-run.'
    }
}

# ---------------------------------------------------------------------------
# Deploy: symlink if possible, else copy. Handles files and directories.
# ---------------------------------------------------------------------------
function Test-CanSymlink {
    if ($CopyOnly) { return $false }
    # Dev Mode?
    $devmode = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
        -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue
    if ($devmode.AllowDevelopmentWithoutDevLicense -eq 1) { return $true }
    # Admin?
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Deploy-Config {
    param([string]$Source, [string]$Target, [switch]$Directory)
    $src = Join-Path $RepoWin $Source
    if (-not (Test-Path $src)) { Write-Warning "missing source: $src"; return }
    $parent = Split-Path $Target -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path $Target) { Remove-Item $Target -Recurse -Force }

    if ($script:CanSymlink) {
        New-Item -ItemType SymbolicLink -Path $Target -Target $src -Force | Out-Null
        Write-Host "link  $Target -> $src"
    } else {
        if ($Directory) { Copy-Item $src $Target -Recurse -Force }
        else { Copy-Item $src $Target -Force }
        Write-Host "copy  $Target"
    }
}

function Deploy-All {
    $script:CanSymlink = Test-CanSymlink
    Write-Step ("Deploying configs ({0} mode)" -f ($(if ($script:CanSymlink) {'symlink'} else {'copy'})))

    $cfg = Join-Path $HOME '.config'
    Deploy-Config 'powershell/Microsoft.PowerShell_profile.ps1' $PROFILE
    Deploy-Config 'starship.toml'        (Join-Path $cfg 'starship.toml')
    Deploy-Config 'alacritty/alacritty.toml' (Join-Path $env:APPDATA 'alacritty\alacritty.toml')
    Deploy-Config 'zellij/config.kdl'    (Join-Path $env:APPDATA 'zellij\config.kdl')
    Deploy-Config 'glazewm/config.yaml'  (Join-Path $HOME '.glzr\glazewm\config.yaml')
    Deploy-Config 'nvim'                 (Join-Path $env:LOCALAPPDATA 'nvim') -Directory
    Deploy-Config 'git/ignore'           (Join-Path $cfg 'git\ignore')
    Deploy-Config 'claude/settings.json' (Join-Path $HOME '.claude\settings.json')
    Deploy-Config 'claude/statusline-command.ps1' (Join-Path $HOME '.claude\statusline-command.ps1')
    Deploy-Config 'btop/btop.conf'       (Join-Path $env:APPDATA 'btop\btop.conf')

    # global gitignore
    git config --global core.excludesfile (Join-Path $cfg 'git\ignore')

    # Windows Terminal: MERGE (never overwrite the live settings.json)
    & (Join-Path $RepoWin 'windows-terminal/merge-wt-settings.ps1')

    # pynvim for nvim :checkhealth
    if (Get-Command python -ErrorAction SilentlyContinue) { python -m pip install --user --upgrade pynvim | Out-Null }
}

# ---------------------------------------------------------------------------
if (-not $SkipPackages) { Install-Packages }
if (-not $SkipDeploy)   { Deploy-All }

Write-Step 'Next steps'
@'
 - Restart the terminal (or `. $PROFILE`) to load the profile + starship.
 - Set your terminal font to "JetBrainsMono Nerd Font" (installed via scoop).
 - Launch nvim once to let lazy.nvim + Mason install; then run :checkhealth.
 - Enable GlazeWM at startup (see windows/README.md) and reload with alt+shift+r.
 - Run windows/validate.ps1 to verify everything.
'@ | Write-Host
