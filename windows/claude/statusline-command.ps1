#Requires -Version 7.0
# Claude Code status line (PowerShell) — Windows port of macos/statusline-command.sh
# Kept section-for-section and color-for-color identical to the bash version:
# Tokyo Night Storm, flat. No background blocks,  arrows, or trailing
# $character glyph — each section is plain text in its own distinct Storm hue,
# joined by a dim separator.
#
# Deploy target: ~/.claude/statusline-command.ps1
# Reads the session JSON from stdin; accumulates token counts per session in TEMP.

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$e = [char]27   # ANSI escape

# ── Read stdin JSON ──────────────────────────────────────────────────────────
$raw = [Console]::In.ReadToEnd()
# Fall through to the defaults below rather than printing nothing, so an empty
# or malformed payload still renders a line (matches the bash version).
$data = if ($raw) { try { $raw | ConvertFrom-Json } catch { $null } } else { $null }

$cwd   = if ($data.cwd) { $data.cwd } else { $PWD.Path }
$model = if ($data.model.display_name) { $data.model.display_name } else { 'Claude' }

# ── Tokyo Night Storm palette - foregrounds only, one per section ─────────────
$BLUE       = '122;162;247'   # #7aa2f7  user@host
$TEAL       = '115;218;202'   # #73daca  directory
$MAGENTA    = '187;154;247'   # #bb9af7  git branch
$GREEN      = '158;206;106'   # #9ece6a  language runtimes
$ORANGE     = '255;158;100'   # #ff9e64  model
$CYAN       = '125;207;255'   # #7dcfff  context / tokens
$PURE_GREEN = '0;255;0'       # #00ff00  time - deliberately outside the Storm palette
$COMMENT    = '86;95;137'     # #565f89  separators
$RED        = '247;118;142'   # #f7768e  elevated shell (bash colors root the same way)

function Paint([string]$rgb, [string]$text) { "$e[38;2;${rgb}m$text$e[0m" }

$sections = @()

# ── 1. user@host ─────────────────────────────────────────────────────────────
$user = $env:USERNAME
$hostName = $env:COMPUTERNAME
# Administrator is the Windows analogue of the bash version's root check.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
$userFg = if ($isAdmin) { $RED } else { $BLUE }
$sections += Paint $userFg "$user@$hostName"

# ── 2. directory - full path from ~, no truncation, as starship is configured ─
$homeDir = $env:USERPROFILE
$short = if ($cwd -and $homeDir -and $cwd.StartsWith($homeDir, [StringComparison]::OrdinalIgnoreCase)) {
    '~' + $cwd.Substring($homeDir.Length)
} else { $cwd }
# Render separators as '/' so the two platforms' status lines read identically.
$short = $short -replace '\\', '/'
$sections += Paint $TEAL $short

# ── 3. git branch + dirty status - only inside a repo ────────────────────────
if ($cwd -and (git -C $cwd --no-optional-locks rev-parse --is-inside-work-tree 2>$null)) {
    $branch = git -C $cwd --no-optional-locks symbolic-ref --short HEAD 2>$null
    if (-not $branch) { $branch = git -C $cwd --no-optional-locks rev-parse --short HEAD 2>$null }
    if ($branch) {
        $dirty = if (git -C $cwd --no-optional-locks status --porcelain 2>$null) { ' *' } else { '' }
        $sections += Paint $MAGENTA " $branch$dirty"
    }
}

# ── 4. language runtime versions - only if a marker file is present ──────────
# Order matches starship's $rust$golang$nodejs$python; each check is a cheap
# file test (mirrors how starship itself gates these modules) before
# shelling out to the version binary, to keep the status line fast.
$lang = ''
if ((Test-Path (Join-Path $cwd 'Cargo.toml')) -and (Get-Command rustc -ErrorAction SilentlyContinue)) {
    $v = (rustc --version 2>$null) -split '\s+' | Select-Object -Index 1
    if ($v) { $lang += "🦀 $v " }
}
if ((Test-Path (Join-Path $cwd 'go.mod')) -and (Get-Command go -ErrorAction SilentlyContinue)) {
    $v = (go version 2>$null) -split '\s+' | Select-Object -Index 2
    if ($v) { $lang += "🐹 $($v -replace '^go', '') " }
}
if ((Test-Path (Join-Path $cwd 'package.json')) -and (Get-Command node -ErrorAction SilentlyContinue)) {
    $v = (node --version 2>$null) -replace '^v', ''
    if ($v) { $lang += "node $v " }
}
$pyMarker = @('requirements.txt', 'pyproject.toml', 'setup.py') |
    Where-Object { Test-Path (Join-Path $cwd $_) } | Select-Object -First 1
if ($pyMarker) {
    $py = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
    if ($py) {
        $v = (& $py.Source --version 2>$null) -split '\s+' | Select-Object -Index 1
        if ($v) { $lang += "py $v " }
    }
}
if ($lang) { $sections += Paint $GREEN $lang.TrimEnd() }

# ── 5. model name (Claude-only) ──────────────────────────────────────────────
$sections += Paint $ORANGE "✦ $model"

# ── Token count formatter (<1000 as-is, k, M) ────────────────────────────────
function Format-Tokens([double]$n) {
    if ($n -ge 1000000) { '{0:0.0}M' -f ($n / 1000000) }
    elseif ($n -ge 1000) { '{0:0.0}k' -f ($n / 1000) }
    else { '{0:0}' -f $n }
}

# ── 6. context / token usage (Claude-only) ───────────────────────────────────
# Accumulated across turns keyed by session_id; the bash version keys on PPID,
# which has no cheap Windows equivalent — the rendered output is the same.
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
    $sections += Paint $CYAN "$(Format-Tokens $totalOut)↓ $(Format-Tokens $totalIn)↑ ${ctxInt}%"
}

# ── 7. time - HH:mm matches starship's time_format ───────────────────────────
$sections += Paint $PURE_GREEN (Get-Date -Format 'HH:mm')

# ── join: dim separator only between sections that actually rendered ─────────
$sep = Paint $COMMENT ' │ '
[Console]::Out.Write(($sections -join $sep) + "`n")
