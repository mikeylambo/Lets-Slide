param(
    [switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $Here
. (Join-Path $Here '_godot.ps1')
$Godot = Resolve-Godot

$argsList = @('--headless', '--path', $Root, '--', '--export-courses')
if ($Force) { $argsList += '--force-export-courses' }
Invoke-Godot $Godot $argsList
exit $LASTEXITCODE
