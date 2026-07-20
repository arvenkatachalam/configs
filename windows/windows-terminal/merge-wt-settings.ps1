#Requires -Version 7.0
<#
    Merges settings.fragment.json into the LIVE Windows Terminal settings.json
    (scheme + profiles.defaults + default profile). Never overwrites wholesale:
    backs up first, validates the result, and restores the backup on any failure.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$fragmentPath = Join-Path $PSScriptRoot 'settings.fragment.json'

# Locate the live settings.json across Store / Preview / unpackaged installs.
$candidates = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$settingsPath = $candidates | Where-Object { Test-Path (Split-Path $_ -Parent) } | Select-Object -First 1
if (-not $settingsPath) {
    Write-Warning "Windows Terminal not found. Launch it once, then re-run this script (or bootstrap.ps1 -SkipPackages)."
    return
}

$fragment = Get-Content $fragmentPath -Raw | ConvertFrom-Json -AsHashtable

# Read existing settings (JSONC-tolerant: strip /* */ and whole-line // comments).
if (Test-Path $settingsPath) {
    Copy-Item $settingsPath "$settingsPath.bak" -Force
    $raw = Get-Content $settingsPath -Raw
} else {
    $raw = '{}'
}
$stripped = [regex]::Replace($raw, '/\*.*?\*/', '', 'Singleline')
$stripped = ($stripped -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"

try {
    $settings = $stripped | ConvertFrom-Json -AsHashtable
    if (-not $settings) { $settings = @{} }

    # 1) schemes — replace-by-name or append
    if (-not $settings.ContainsKey('schemes')) { $settings['schemes'] = @() }
    foreach ($scheme in $fragment['schemes']) {
        $settings['schemes'] = @($settings['schemes'] | Where-Object { $_.name -ne $scheme.name })
        $settings['schemes'] += $scheme
    }

    # 2) profiles.defaults — merge keys
    if (-not $settings.ContainsKey('profiles')) { $settings['profiles'] = @{} }
    if (-not $settings['profiles'].ContainsKey('defaults')) { $settings['profiles']['defaults'] = @{} }
    foreach ($k in $fragment['profileDefaults'].Keys) {
        $settings['profiles']['defaults'][$k] = $fragment['profileDefaults'][$k]
    }

    # 3) defaultProfile — point at the PowerShell 7 profile if we can find it
    $match = $fragment['defaultProfileCommandlineMatch']
    $list = $settings['profiles']['list']
    if ($list) {
        $pwshProfile = $list | Where-Object {
            $_.source -eq 'Windows.Terminal.PowershellCore' -or ($_.commandline -and $_.commandline -match $match)
        } | Select-Object -First 1
        if ($pwshProfile) { $settings['defaultProfile'] = $pwshProfile.guid }
    }

    $json = $settings | ConvertTo-Json -Depth 32
    if (-not (Test-Json $json -ErrorAction SilentlyContinue)) { throw 'merged settings failed JSON validation' }
    $json | Set-Content $settingsPath -Encoding utf8
    Write-Host "Merged Catppuccin scheme + defaults into $settingsPath (backup: $settingsPath.bak)"
}
catch {
    if (Test-Path "$settingsPath.bak") { Copy-Item "$settingsPath.bak" $settingsPath -Force }
    Write-Warning "WT merge failed ($_). Restored backup. Merge $fragmentPath manually."
}
