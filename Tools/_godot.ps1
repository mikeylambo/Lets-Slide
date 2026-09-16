Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-Godot {
    if ($env:GODOT) {
        if (Test-Path $env:GODOT) { return (Resolve-Path $env:GODOT).Path }
        $cmd = Get-Command $env:GODOT -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
        throw "GODOT is set but not executable/found: $env:GODOT"
    }

    foreach ($name in @('godot', 'godot4')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }

    $candidates = @(
        "$env:ProgramFiles\Godot\Godot.exe",
        "$env:ProgramFiles\Godot\Godot_v4.7-stable_win64.exe",
        "$env:LOCALAPPDATA\Programs\Godot\Godot.exe",
        "$env:USERPROFILE\scoop\apps\godot\current\godot.exe"
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) { return (Resolve-Path $candidate).Path }
    }

    throw 'Godot not found. Set $env:GODOT="C:\full\path\to\Godot.exe" (expected 4.7.x).'
}
