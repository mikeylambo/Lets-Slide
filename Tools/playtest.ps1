# One-click playtest: build (import + strict script check), then launch straight
# into the Playtest Harness. No editor required.
#
#   powershell -ExecutionPolicy Bypass -File Tools\playtest.ps1
#   powershell -ExecutionPolicy Bypass -File Tools\playtest.ps1 course_03 --blind
#
# When you quit, the session handoff is at playtests\LATEST.md - paste it back.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $Here
. (Join-Path $Here '_godot.ps1')
$Godot = Resolve-Godot

$Course = 'course_01'
$Extra = @($args)
if ($Extra.Count -gt 0 -and -not ([string]$Extra[0]).StartsWith('--')) {
    $Course = [string]$Extra[0]
    $Extra = @($Extra | Select-Object -Skip 1)
}

Write-Host '== build: importing project =='
$importLog = Invoke-Godot $Godot @('--headless', '--path', $Root, '--import') | Out-String
if ($importLog -match 'SCRIPT ERROR:|Parse Error|Compile Error') {
    Write-Host 'BUILD FAIL - script errors:' -ForegroundColor Red
    $importLog -split "`r?`n" | Where-Object { $_ -match 'SCRIPT ERROR:|Parse Error|Compile Error' } | Write-Host
    exit 1
}

$commit = 'local'
try { $commit = (& git -C $Root rev-parse --short HEAD 2>$null).Trim(); & git -C $Root diff --quiet 2>$null; if ($LASTEXITCODE -ne 0) { $commit += '+dirty' } } catch {}
$env:LETS_SLIDE_COMMIT = $commit

Write-Host "== launching harness on $Course =="
$launch = @('--path', $Root, '--', '--harness', "--course=$Course") + $Extra
Invoke-Godot $Godot $launch | Out-Null

$latest = Join-Path $Root 'playtests\LATEST.md'
if (Test-Path $latest) { Write-Host ''; Write-Host "== session handoff: $latest ==" }
exit 0
