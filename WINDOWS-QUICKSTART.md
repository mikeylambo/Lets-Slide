# LET'S SLIDE — Windows quickstart

The project is Godot 4.7.x + GDScript. PowerShell helpers live beside the existing Bash tools.

## One-time setup

If `godot` is already on PATH, no setup is needed. Otherwise point the tools at your executable for the current PowerShell session:

```powershell
$env:GODOT = "C:\Path\To\Godot_v4.7-stable_win64.exe"
```

If Windows blocks local scripts, use the commands below with `-ExecutionPolicy Bypass` rather than changing the machine-wide policy.

## Daily loop

```powershell
git pull
powershell -ExecutionPolicy Bypass -File Tools\verify.ps1
powershell -ExecutionPolicy Bypass -File Tools\run.ps1
```

Full 25-course physical probe:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\verify-full.ps1
```

Probe one course:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\probe.ps1 course_03
```

Movement Lab:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\lab.ps1
```

## Course data

Normal export only creates missing course resources and preserves tuned `.tres` files:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\export-courses.ps1
```

To deliberately regenerate all course resources from `CourseCatalog.gd`:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\export-courses.ps1 -Force
```

**Warning:** `-Force` replaces saved course tuning, measured medals, and inspector edits. Commit first.

## Measured medal calibration

Region I only:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\calibrate-medals.ps1
```

All 25 courses:

```powershell
powershell -ExecutionPolicy Bypass -File Tools\calibrate-medals.ps1 -Mode all
```

Calibration only writes courses that physically pass the probe. Commit the resulting `content/courses/*.tres` files after reviewing them.

## Recommended production loop

1. `git pull`
2. `Tools\verify.ps1`
3. Play the course being tuned.
4. Make/receive one consolidated code change.
5. Re-run `verify.ps1`.
6. Run `verify-full.ps1` only at content milestones.
7. Calibrate medals only after course geometry and motor feel are stable enough for that milestone.
