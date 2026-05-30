# verify-syntax.ps1 - Verify syntax of all PowerShell scripts
param()

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$files = @(
    (Join-Path $ScriptDir "lib\common.ps1"),
    (Join-Path $ScriptDir "recon.ps1"),
    (Join-Path $ScriptDir "extract-apis.ps1"),
    (Join-Path $ScriptDir "scan-sinks.ps1"),
    (Join-Path $ScriptDir "scan-configs.ps1"),
    (Join-Path $ScriptDir "validate-output.ps1")
)

$totalErrors = 0

Write-Host "PowerShell Script Syntax Verification"
Write-Host "======================================"
Write-Host ""

foreach ($f in $files) {
    $name = Split-Path -Leaf $f
    Write-Host "Checking: $name ... " -NoNewline

    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$parseErrors)

    if ($parseErrors.Count -eq 0) {
        Write-Host "OK" -ForegroundColor Green
    }
    else {
        Write-Host "FAIL ($($parseErrors.Count) errors)" -ForegroundColor Red
        foreach ($e in $parseErrors) {
            Write-Host "  Line $($e.Extent.StartLineNumber): $($e.Message)" -ForegroundColor Yellow
        }
        $totalErrors += $parseErrors.Count
    }
}

Write-Host ""
Write-Host "======================================"
if ($totalErrors -eq 0) {
    Write-Host "All scripts passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Total errors: $totalErrors" -ForegroundColor Red
    exit 1
}
