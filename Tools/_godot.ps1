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

function Invoke-Godot([string]$Godot, [string[]]$GodotArgs) {
    # Godot's Windows GUI-subsystem executable does not set LASTEXITCODE when
    # invoked directly from PowerShell, so run and wait through Process.
    $info = [System.Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Godot
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    if ($GodotArgs -contains '--headless') {
        $pathIndex = [Array]::IndexOf($GodotArgs, '--path')
        $settingsRoot = if ($pathIndex -ge 0) { $GodotArgs[$pathIndex + 1] } else { $env:TEMP }
        $headlessAppData = Join-Path $settingsRoot ('.godot/headless-appdata-{0}' -f [guid]::NewGuid())
        [void](New-Item -ItemType Directory -Path $headlessAppData -Force)
        $info.Environment['APPDATA'] = $headlessAppData
    }
    foreach ($argument in $GodotArgs) { [void]$info.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $info
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout.Result -split "`r?`n" | Where-Object { $_ -ne '' } | Write-Output
    $stderr.Result -split "`r?`n" | Where-Object { $_ -ne '' } | Write-Output
    $global:LASTEXITCODE = $process.ExitCode
    $process.Dispose()
}
