#Requires -Version 7.0
<#
.SYNOPSIS
    Post-bootstrap self-check for the Windows dotfiles (Tier 1 validation).
.DESCRIPTION
    Verifies tools are installed, configs are deployed to their expected paths and
    parse, the PowerShell profile loads cleanly, nvim is healthy, and the Claude
    status line renders. Prints a PASS/FAIL table and exits non-zero on any failure.
.EXAMPLE
    pwsh -File .\validate.ps1
    pwsh -File .\validate.ps1 -SkipNvim   # skip the slow nvim checks
#>
[CmdletBinding()]
param([switch]$SkipNvim)

$results = [System.Collections.Generic.List[object]]::new()
function Add-Result($name, $ok, $detail = '') {
    $results.Add([pscustomobject]@{ Check = $name; Result = $(if ($ok) { 'PASS' } else { 'FAIL' }); Detail = "$detail" })
}
function Test-Cmd($name, $exe) {
    $c = Get-Command $exe -ErrorAction SilentlyContinue
    Add-Result "tool: $name" ($null -ne $c) $(if ($c) { $c.Source } else { 'not found' })
}
function Test-File($name, $path, [switch]$Json) {
    if (-not (Test-Path $path)) { Add-Result "config: $name" $false "missing: $path"; return }
    if ($Json) {
        try { Get-Content $path -Raw | ConvertFrom-Json | Out-Null; Add-Result "config: $name" $true 'parsed' }
        catch { Add-Result "config: $name" $false "bad JSON: $_" }
    } else {
        Add-Result "config: $name" ((Get-Item $path).Length -gt 0) $path
    }
}

Write-Host "`n== Tools ==" -ForegroundColor Cyan
Test-Cmd 'neovim' 'nvim';      Test-Cmd 'ripgrep' 'rg';    Test-Cmd 'fzf' 'fzf'
Test-Cmd 'lsd' 'lsd';          Test-Cmd 'lazygit' 'lazygit'; Test-Cmd 'gh' 'gh'
Test-Cmd 'starship' 'starship'; Test-Cmd 'zellij' 'zellij'; Test-Cmd 'yazi' 'yazi'
Test-Cmd 'uv' 'uv';            Test-Cmd 'git' 'git';       Test-Cmd 'node' 'node'
Test-Cmd 'fastfetch' 'fastfetch'; Test-Cmd 'glazewm' 'glazewm'; Test-Cmd 'zoxide' 'zoxide'

Write-Host "`n== Configs (deployed) ==" -ForegroundColor Cyan
$cfg = Join-Path $HOME '.config'
Test-File 'PowerShell profile' $PROFILE
Test-File 'starship'   (Join-Path $cfg 'starship.toml')
Test-File 'alacritty'  (Join-Path $env:APPDATA 'alacritty\alacritty.toml')
Test-File 'zellij'     (Join-Path $env:APPDATA 'zellij\config.kdl')
Test-File 'glazewm'    (Join-Path $HOME '.glzr\glazewm\config.yaml')
Test-File 'nvim'       (Join-Path $env:LOCALAPPDATA 'nvim\init.lua')
Test-File 'git ignore' (Join-Path $cfg 'git\ignore')
Test-File 'claude settings' (Join-Path $HOME '.claude\settings.json') -Json
Test-File 'claude statusline' (Join-Path $HOME '.claude\statusline-command.ps1')
Test-File 'btop'       (Join-Path $env:APPDATA 'btop\btop.conf')

Write-Host "`n== Runtime ==" -ForegroundColor Cyan
# Profile loads cleanly in a child shell
$probe = pwsh -NoProfile -Command ". `"$PROFILE`" *> `$null; exit 0" 2>&1
Add-Result 'profile dot-sources' ($LASTEXITCODE -eq 0) "$probe"

# Fonts present
$fonts = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts", "$env:WINDIR\Fonts" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'JetBrainsMono' }
Add-Result 'JetBrainsMono NF font' ($null -ne $fonts) $(if ($fonts) { "$($fonts.Count) files" } else { 'not installed' })

# Claude status line renders
$statusline = Join-Path $HOME '.claude\statusline-command.ps1'
if (Test-Path $statusline) {
    $sample = '{"session_id":"validate","cwd":"' + ($HOME -replace '\\','\\') + '","model":{"display_name":"Opus"},"context_window":{"used_percentage":42,"current_usage":{"output_tokens":1200,"input_tokens":34000}}}'
    $out = $sample | pwsh -NoProfile -File $statusline
    Add-Result 'statusline renders' ([bool]($out -and $out -match 'Opus')) ($out -replace "`e",'^[')
}

if (-not $SkipNvim) {
    Write-Host "`n== Neovim (slow) ==" -ForegroundColor Cyan
    if (Get-Command nvim -ErrorAction SilentlyContinue) {
        nvim --headless "+Lazy! sync" +qa 2>&1 | Out-Null
        nvim --headless "+checkhealth" +qa 2>&1 | Out-Null
        Add-Result 'nvim checkhealth' ($LASTEXITCODE -eq 0) "exit $LASTEXITCODE"
    } else { Add-Result 'nvim checkhealth' $false 'nvim not found' }
}

Write-Host ''
$results | Format-Table -AutoSize
$fail = ($results | Where-Object Result -eq 'FAIL').Count
if ($fail) { Write-Host "$fail check(s) FAILED" -ForegroundColor Red; exit 1 }
Write-Host 'All checks passed.' -ForegroundColor Green
