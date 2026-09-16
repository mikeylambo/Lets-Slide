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
        "$env:USERPROFILE\Desktop\Godot_v4.7-stable_win64.exe",
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

function ConvertTo-NativeArgument([string]$Value) {
    # ProcessStartInfo.ArgumentList is unavailable in Windows PowerShell 5.1.
    # Our Godot arguments do not contain embedded quotes, so standard Windows
    # quoting is sufficient and preserves project paths containing spaces.
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + ($Value -replace '"', '\"') + '"'
}

function Invoke-Godot([string]$Godot, [string[]]$GodotArgs) {
    # Godot's Windows GUI-subsystem executable does not reliably populate
    # LASTEXITCODE when invoked directly from Windows PowerShell. Use Process
    # and wait explicitly. Build the legacy Arguments string so this works on
    # both Windows PowerShell 5.1 and modern PowerShell.
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $Godot
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true

    if ($GodotArgs -contains '--headless') {
        $pathIndex = [Array]::IndexOf($GodotArgs, '--path')
        $settingsRoot = if ($pathIndex -ge 0) { $GodotArgs[$pathIndex + 1] } else { $env:TEMP }
        $headlessAppData = Join-Path $settingsRoot ('.godot/headless-appdata-{0}' -f [guid]::NewGuid())
        [void](New-Item -ItemType Directory -Path $headlessAppData -Force)
        $info.EnvironmentVariables['APPDATA'] = $headlessAppData
    }

    $quotedArgs = @()
    foreach ($argument in $GodotArgs) {
        $quotedArgs += ConvertTo-NativeArgument ([string]$argument)
    }
    $info.Arguments = $quotedArgs -join ' '

    $process = New-Object System.Diagnostics.Process
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
