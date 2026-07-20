#Requires -Version 7.0
# Claude Code status line (PowerShell) — Windows port of macos/statusline-command.sh
# Tokyo Night palette. Deploy target: ~/.claude/statusline-command.ps1
# Reads the session JSON from stdin; accumulates token counts per session in TEMP.

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$e = [char]27   # ANSI escape

# ── Read stdin JSON ──────────────────────────────────────────────────────────
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { return }
$data = $raw | ConvertFrom-Json

$cwd   = $data.cwd
$model = $data.model.display_name
$user  = $env:USERNAME

# ── Shorten cwd: $HOME -> ~, then keep last 3 segments ───────────────────────
$homeDir = $env:USERPROFILE
$short = if ($cwd -and $cwd.StartsWith($homeDir, [StringComparison]::OrdinalIgnoreCase)) {
    '~' + $cwd.Substring($homeDir.Length)
} else { $cwd }
$parts = $short -split '[\\/]+' | Where-Object { $_ -ne '' }
if ($parts.Count -gt 3) { $short = '.../' + ($parts[-3..-1] -join '/') }
else { $short = $short -replace '\\', '/' }

# ── Git branch + dirty flag ──────────────────────────────────────────────────
$gitInfo = ''
if ($cwd -and (git -C $cwd rev-parse --is-inside-work-tree 2>$null)) {
    $branch = git -C $cwd symbolic-ref --short HEAD 2>$null
    if (-not $branch) { $branch = git -C $cwd rev-parse --short HEAD 2>$null }
    if ($branch) {
        $dirty = if (git -C $cwd status --porcelain 2>$null) { '*' } else { '' }
        $gitInfo = " |  $branch$dirty"
    }
}

# ── Token count formatter (<1000 as-is, k, M) ────────────────────────────────
function Format-Tokens([double]$n) {
    if ($n -ge 1000000) { '{0:0.0}M' -f ($n / 1000000) }
    elseif ($n -ge 1000) { '{0:0.0}k' -f ($n / 1000) }
    else { '{0:0}' -f $n }
}

# ── Context usage: accumulate tokens across turns, keyed by session_id ────────
$ctxInfo = ''
$usedPct = $data.context_window.used_percentage
$turnOut = $data.context_window.current_usage.output_tokens
$turnIn  = $data.context_window.current_usage.input_tokens
if ($null -ne $usedPct -and $null -ne $turnOut -and $null -ne $turnIn) {
    $sid = if ($data.session_id) { $data.session_id } else { 'default' }
    $tmpDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
    $tokenFile = Join-Path $tmpDir "claude_tokens_$sid"

    $accOut = 0L; $accIn = 0L
    if (Test-Path $tokenFile) {
        $lines = Get-Content $tokenFile
        if ($lines.Count -ge 2) {
            [void][long]::TryParse($lines[0], [ref]$accOut)
            [void][long]::TryParse($lines[1], [ref]$accIn)
        }
    }
    $totalOut = $accOut + [long]$turnOut
    $totalIn  = $accIn + [long]$turnIn
    Set-Content -Path $tokenFile -Value @("$totalOut", "$totalIn")

    $ctxInt = [math]::Round([double]$usedPct)
    $ctxInfo = " | $(Format-Tokens $totalOut)↓ $(Format-Tokens $totalIn)↑ ${ctxInt}%"
}

# ── Build status line (Tokyo Night ANSI colors) ──────────────────────────────
$time = Get-Date -Format 'HH:mm'
$blue   = "$e[38;2;122;162;247m"   # #7aa2f7
$purple = "$e[38;2;187;154;247m"   # #bb9af7
$green  = "$e[38;2;158;206;106m"   # #9ece6a (model)
$bgreen = "$e[38;2;0;255;0m"       # bright green (time)
$reset  = "$e[0m"

$line  = "$blue󰍲 $reset"                 # Windows glyph (nerd font)
$line += "$blue$user$reset"
$line += " $purple$short$reset"
if ($gitInfo) { $line += "$purple$gitInfo$reset" }
$line += " | $green$model$reset"
$line += $ctxInfo
$line += " | $bgreen$time$reset"

[Console]::Out.Write($line + "`n")
