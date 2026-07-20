# PowerShell 7 profile — Windows analog of macos/zshrc
# Deploy target: $PROFILE  (…\Documents\PowerShell\Microsoft.PowerShell_profile.ps1)
#
# Guarded throughout: a missing module/tool warns but never throws, so the profile
# always dot-sources cleanly (validate.ps1 relies on this).

# ── Editor ──────────────────────────────────────────────────────────────────
$env:EDITOR = 'nvim'
$env:VISUAL = 'nvim'

# ── Aliases (ls -> lsd, vim -> nvim) ────────────────────────────────────────
# NOTE: aliases outrank functions in PowerShell command resolution, so the
# built-in `ls` -> Get-ChildItem alias must be removed before defining ours.
Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
if (Get-Command lsd -ErrorAction SilentlyContinue) {
    function ls { lsd @args }
}
Set-Alias vim nvim -ErrorAction SilentlyContinue

# ── PSReadLine: autosuggestions + syntax highlighting (Catppuccin Mocha) ─────
# Replaces zsh-autosuggestions + zsh-syntax-highlighting + zsh/catppuccin-mocha.zsh
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -EditMode Windows
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -Colors @{
        Command                = "`e[38;2;137;180;250m"  # blue
        Comment                = "`e[38;2;108;112;134m"  # overlay0
        ContinuationPrompt     = "`e[38;2;205;214;244m"  # text
        Default                = "`e[38;2;205;214;244m"  # text
        Emphasis               = "`e[38;2;245;194;231m"  # pink
        Error                  = "`e[38;2;243;139;168m"  # red
        InlinePrediction       = "`e[38;2;108;112;134m"  # overlay0
        Keyword                = "`e[38;2;203;166;247m"  # mauve
        ListPrediction         = "`e[38;2;148;226;213m"  # teal
        Member                 = "`e[38;2;205;214;244m"  # text
        Number                 = "`e[38;2;250;179;135m"  # peach
        Operator               = "`e[38;2;137;220;235m"  # sky
        Parameter              = "`e[38;2;235;160;172m"  # maroon
        Selection              = "`e[48;2;69;71;90m"     # surface1 (bg)
        String                 = "`e[38;2;166;227;161m"  # green
        Type                   = "`e[38;2;249;226;175m"  # yellow
        Variable               = "`e[38;2;242;205;205m"  # flamingo
    }
}

# ── fzf key bindings (Ctrl+T files, Ctrl+R history) — replaces `fzf --zsh` ────
if (Get-Module -ListAvailable PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    if (Get-Command fd -ErrorAction SilentlyContinue) { $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git' }
}

# ── git prompt integration — replaces oh-my-zsh `git` plugin ─────────────────
if (Get-Module -ListAvailable posh-git) { Import-Module posh-git }

# ── zoxide (smarter cd) ──────────────────────────────────────────────────────
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ── Starship prompt (Tokyo Night) — replaces `starship init zsh` ─────────────
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
