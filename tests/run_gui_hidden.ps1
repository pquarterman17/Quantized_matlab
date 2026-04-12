# Run GUI tests with MATLAB fully hidden (no taskbar, no focus steal)
$logFile = Join-Path $env:TEMP "matlab_gui_test_log.txt"
if (Test-Path $logFile) { Remove-Item $logFile }

$escapedLog = $logFile -replace '\\','/'
$matlabCmd = "diary('$escapedLog'); addpath(pwd); setupToolbox; runAllTests(Group='gui'); diary off;"

$p = Start-Process -FilePath "C:\Program Files\MATLAB\R2025b\bin\matlab.exe" `
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
