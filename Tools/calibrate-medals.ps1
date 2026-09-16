param(
    [ValidateSet('region1','all')]
    [string]$Mode = 'region1'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $Here
. (Join-Path $Here '_godot.ps1')
$Godot = Resolve-Godot

$course01 = Join-Path $Root 'content\courses\course_01.tres'
if (-not (Test-Path $course01)) {
    & (Join-Path $Here 'export-courses.ps1')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$start = 1
$end = if ($Mode -eq 'all') { 25 } else { 5 }
$tempCsv = Join-Path $env:TEMP ("lets-slide-medals-{0}.csv" -f ([guid]::NewGuid().ToString('N')))
try {
    for ($n = $start; $n -le $end; $n++) {
        $id = 'course_{0:D2}' -f $n
        Write-Host "== calibrate $id =="
        $out = & (Join-Path $Here 'probe.ps1') -Course $id 2>&1
        $status = $LASTEXITCODE
        $out | ForEach-Object { Write-Host $_ }
        if ($status -ne 0) {
            throw "CALIBRATION FAIL: $id did not pass the physical probe"
        }
        $text = $out | Out-String
        $timeMatch = [regex]::Match($text, '(?m)^\s*time\s*:\s*([0-9.]+)')
        if (-not $timeMatch.Success) {
            throw "CALIBRATION FAIL: could not parse finish time for $id"
        }
        $scoreMatch = [regex]::Match($text, '(?m)^\s*score\s*:\s*([0-9]+)')
        $time = $timeMatch.Groups[1].Value
        $score = if ($scoreMatch.Success) { $scoreMatch.Groups[1].Value } else { '0' }
        Add-Content -Path $tempCsv -Value "$id,$time,$score"
    }

    & $Godot --headless --path $Root -- --apply-medals "--medal-file=$tempCsv"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "Measured medal times written for $Mode."
}
finally {
    Remove-Item $tempCsv -ErrorAction SilentlyContinue
}
