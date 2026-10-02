Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $Here
. (Join-Path $Here '_godot.ps1')
$Godot = Resolve-Godot

function Invoke-Gate([string]$Label, [string[]]$GodotArgs) {
    Write-Host "== $Label =="
    $output = Invoke-Godot $Godot $GodotArgs 2>&1
    $status = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($status -ne 0) {
        throw "VERIFY FAIL: $Label exited with status $status"
    }
    $text = ($output | Out-String)
    if ($text -match 'SCRIPT ERROR:|(^|\s)ERROR:|Parse Error|Compile Error') {
        throw "VERIFY FAIL: $Label emitted an engine/parser error"
    }
}

Invoke-Gate 'import' @('--headless', '--path', $Root, '--import')

$courseDir = Join-Path $Root 'content\courses'
$courseCount = @(Get-ChildItem -Path $courseDir -Filter 'course_*.tres' -File -ErrorAction SilentlyContinue).Count
if ($courseCount -ne 25) {
    Invoke-Gate 'course data export' @('--headless', '--path', $Root, '--', '--export-courses')
}
$courseCount = @(Get-ChildItem -Path $courseDir -Filter 'course_*.tres' -File -ErrorAction SilentlyContinue).Count
if ($courseCount -ne 25) {
    throw "VERIFY FAIL: expected 25 serialized course files, found $courseCount"
}

Invoke-Gate 'unit tests' @('--headless', '--path', $Root, '--', '--unit')
Invoke-Gate 'smoke test' @('--headless', '--path', $Root, '--', '--smoke')
Invoke-Gate 'replay determinism' @('--headless', '--fixed-fps', '120', '--path', $Root, '--', '--replay-test')
Invoke-Gate 'speedrun suite' @('--headless', '--fixed-fps', '120', '--path', $Root, '--', '--speedrun-test')
Invoke-Gate 'community courses' @('--headless', '--fixed-fps', '120', '--path', $Root, '--', '--community-test')
Invoke-Gate 'multiplayer' @('--headless', '--fixed-fps', '60', '--path', $Root, '--', '--net-test')
Invoke-Gate 'presentation' @('--headless', '--fixed-fps', '120', '--path', $Root, '--', '--presentation-test')
Invoke-Gate 'playtest harness' @('--headless', '--path', $Root, '--', '--harness-test')
Write-Host '== all gates passed =='
