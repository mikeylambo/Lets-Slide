param(
    [string]$Course = 'course_01'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $Here
. (Join-Path $Here '_godot.ps1')
$Godot = Resolve-Godot

& $Godot --headless --path $Root -- --probe "--course=$Course"
exit $LASTEXITCODE
