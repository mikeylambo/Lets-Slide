param(
    [string]$Course = 'course_01'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $Here
. (Join-Path $Here '_godot.ps1')
$Godot = Resolve-Godot

Invoke-Godot $Godot @('--headless', '--fixed-fps', '120', '--path', $Root, '--', '--probe', "--course=$Course")
exit $LASTEXITCODE
