Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

& (Join-Path $Here 'verify.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$failed = 0
for ($i = 1; $i -le 25; $i++) {
    $id = 'course_{0:D2}' -f $i
    Write-Host "== probe $id =="
    & (Join-Path $Here 'probe.ps1') -Course $id
    if ($LASTEXITCODE -ne 0) { $failed++ }
}
Write-Host "== authored probe failures: $failed =="
if ($failed -ne 0) { exit 1 }
