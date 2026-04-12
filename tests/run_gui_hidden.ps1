# Run GUI tests with MATLAB fully hidden (no taskbar, no focus steal)
# Usage:  powershell -ExecutionPolicy Bypass -File tests/run_gui_hidden.ps1 [group]
#   group defaults to "gui" if omitted.
param([string]$Group = "gui")

$logFile = Join-Path $env:TEMP "matlab_gui_test_log.txt"
if (Test-Path $logFile) { Remove-Item $logFile }

$escapedLog = $logFile -replace '\\','/'
$matlabCmd = "diary('$escapedLog'); addpath(pwd); setupToolbox; runAllTests(Group='$Group'); diary off;"

# Find MATLAB executable
$matlabExe = Get-ChildItem "C:\Program Files\MATLAB" -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 1 |
    ForEach-Object { Join-Path $_.FullName "bin\matlab.exe" }
if (-not (Test-Path $matlabExe)) {
    Write-Host "Error: MATLAB not found in C:\Program Files\MATLAB\" -ForegroundColor Red
    exit 1
}

$p = Start-Process -FilePath $matlabExe `
    -ArgumentList "-batch", """$matlabCmd""" `
    -WindowStyle Hidden `
    -WorkingDirectory (Split-Path $PSScriptRoot) `
    -PassThru -Wait

if (Test-Path $logFile) {
    Get-Content $logFile | Select-Object -Last 15
} else {
    Write-Host "No log file produced."
}

if ($p.ExitCode -ne 0) {
    Write-Host ""
    Write-Host "MATLAB exited with code $($p.ExitCode)" -ForegroundColor Red
    exit $p.ExitCode
}
