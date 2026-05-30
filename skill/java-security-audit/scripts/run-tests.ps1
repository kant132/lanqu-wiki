<#
.SYNOPSIS
    Test suite for all PowerShell audit scripts
.DESCRIPTION
    Runs each script against WebGoat-2025.3 and validates output
.PARAMETER ProjectDir
    Path to the test project (default: D:\code\WebGoat-2025.3)
.EXAMPLE
    .\run-tests.ps1
    .\run-tests.ps1 -ProjectDir "D:\code\WebGoat-2025.3"
#>
param(
    [string]$ProjectDir = 'D:\code\WebGoat-2025.3'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TestOutputDir = Join-Path $ScriptDir 'test-output'

# Clean test output
if (Test-Path $TestOutputDir) {
    Remove-Item $TestOutputDir -Recurse -Force
}
New-Item -ItemType Directory -Path $TestOutputDir -Force | Out-Null

$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0

function Assert-True {
    param(
        [bool]$Condition,
        [string]$TestName,
        [string]$Detail = ''
    )
    if ($Condition) {
        Write-Host "  [PASS] $TestName" -ForegroundColor Green
        $script:TestsPassed++
    } else {
        Write-Host "  [FAIL] $TestName" -ForegroundColor Red
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor Yellow }
        $script:TestsFailed++
    }
}

function Assert-FileExists {
    param([string]$File, [string]$TestName)
    Assert-True -Condition (Test-Path $File) -TestName $TestName -Detail "File not found: $File"
}

function Assert-JsonValid {
    param([string]$File, [string]$TestName)
    if (-not (Test-Path $File)) {
        Assert-True -Condition $false -TestName $TestName -Detail "File not found"
        return
    }
    try {
        $content = Get-Content $File -Raw
        $null = $content | ConvertFrom-Json
        Assert-True -Condition $true -TestName $TestName
    } catch {
        Assert-True -Condition $false -TestName $TestName -Detail "Invalid JSON: $($_.Exception.Message)"
    }
}

function Assert-JsonField {
    param(
        [string]$File,
        [string]$FieldPath,
        [string]$TestName,
        $ExpectedValue = $null,
        [switch]$NotNull,
        [int]$MinValue = -1
    )
    if (-not (Test-Path $File)) {
        Assert-True -Condition $false -TestName $TestName -Detail "File not found"
        return
    }
    try {
        $json = Get-Content $File -Raw | ConvertFrom-Json
        
        # Navigate field path (e.g., "build.tool" or "controllers.count")
        $value = $json
        foreach ($part in $FieldPath.Split('.')) {
            $value = $value.$part
        }
        
        if ($null -eq $value) {
            Assert-True -Condition $false -TestName $TestName -Detail "Field '$FieldPath' is null"
            return
        }
        
        if ($NotNull) {
            Assert-True -Condition ($null -ne $value) -TestName $TestName
        }
        elseif ($null -ne $ExpectedValue) {
            Assert-True -Condition ($value -eq $ExpectedValue) -TestName $TestName -Detail "Expected '$ExpectedValue', got '$value'"
        }
        elseif ($MinValue -ge 0) {
            Assert-True -Condition ($value -ge $MinValue) -TestName $TestName -Detail "Expected >= $MinValue, got $value"
        }
        else {
            Assert-True -Condition $true -TestName $TestName
        }
    } catch {
        Assert-True -Condition $false -TestName $TestName -Detail "Error: $($_.Exception.Message)"
    }
}

# ============================================================
# Test 1: recon.ps1
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Test Suite 1: recon.ps1" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$reconOutput = Join-Path $TestOutputDir 'phase1-raw.json'

Write-Host "  Running recon.ps1..."
& (Join-Path $ScriptDir 'recon.ps1') -ProjectDir $ProjectDir -OutputFile $reconOutput 2>&1 | Out-Null

Assert-FileExists $reconOutput 'recon.ps1 produces output file'
Assert-JsonValid $reconOutput 'recon.ps1 output is valid JSON'
Assert-JsonField -File $reconOutput -FieldPath 'build.tool' -ExpectedValue 'maven' -TestName 'build.tool = maven'
Assert-JsonField -File $reconOutput -FieldPath 'build.framework' -ExpectedValue 'spring-boot-webmvc' -TestName 'build.framework = spring-boot-webmvc'
Assert-JsonField -File $reconOutput -FieldPath 'controllers.count' -MinValue 1 -TestName 'controllers.count >= 1'
Assert-JsonField -File $reconOutput -FieldPath 'security_chains.count' -MinValue 1 -TestName 'security_chains.count >= 1'
Assert-JsonField -File $reconOutput -FieldPath 'config_files.count' -MinValue 1 -TestName 'config_files.count >= 1'
Assert-JsonField -File $reconOutput -FieldPath 'protocols' -NotNull -TestName 'protocols field exists'

# Check specific WebGoat findings
$json = Get-Content $reconOutput -Raw | ConvertFrom-Json
$hasJwt = $json.protocols -contains 'JWT-LIFECYCLE'
Assert-True -Condition $hasJwt -TestName 'Detects JWT-LIFECYCLE protocol'

$hasPwdReset = $json.protocols -contains 'PWD-RESET'
Assert-True -Condition $hasPwdReset -TestName 'Detects PWD-RESET protocol'

$hasFileUpload = $json.protocols -contains 'FILE-UPLOAD'
Assert-True -Condition $hasFileUpload -TestName 'Detects FILE-UPLOAD protocol'

# Check SecurityFilterChain details
$secChains = $json.security_chains.items
$hasCsrfDisabled = $false
$hasNoOpEncoder = $false
foreach ($chain in $secChains) {
    if ($chain.csrfDisabled -eq $true) { $hasCsrfDisabled = $true }
    if ($chain.passwordEncoder -eq 'NoOpPasswordEncoder') { $hasNoOpEncoder = $true }
}
Assert-True -Condition $hasCsrfDisabled -TestName 'Detects CSRF disabled'
Assert-True -Condition $hasNoOpEncoder -TestName 'Detects NoOpPasswordEncoder'

# ============================================================
# Test 2: extract-apis.ps1
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Test Suite 2: extract-apis.ps1" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$apisOutput = Join-Path $TestOutputDir 'apis-raw.json'

Write-Host "  Running extract-apis.ps1..."
& (Join-Path $ScriptDir 'extract-apis.ps1') -ProjectDir $ProjectDir -OutputFile $apisOutput 2>&1 | Out-Null

Assert-FileExists $apisOutput 'extract-apis.ps1 produces output file'
Assert-JsonValid $apisOutput 'extract-apis.ps1 output is valid JSON'
Assert-JsonField -File $apisOutput -FieldPath 'total_endpoints' -MinValue 50 -TestName 'total_endpoints >= 50 (WebGoat has ~168)'

$apiJson = Get-Content $apisOutput -Raw | ConvertFrom-Json

# Check specific endpoints exist
$hasSqlInjection = $false
$hasXxe = $false
$hasDeserialization = $false
foreach ($ep in $apiJson.endpoints) {
    if ($ep.path -match 'SqlInjection') { $hasSqlInjection = $true }
    if ($ep.path -match 'xxe') { $hasXxe = $true }
    if ($ep.path -match 'Deserialization') { $hasDeserialization = $true }
}
Assert-True -Condition $hasSqlInjection -TestName 'Finds SQL injection endpoints'
Assert-True -Condition $hasXxe -TestName 'Finds XXE endpoints'
Assert-True -Condition $hasDeserialization -TestName 'Finds deserialization endpoints'

# Check parameter extraction
$hasParams = $false
foreach ($ep in $apiJson.endpoints) {
    if ($ep.params.Count -gt 0) { $hasParams = $true; break }
}
Assert-True -Condition $hasParams -TestName 'Extracts parameters from endpoints'

# ============================================================
# Test 3: scan-sinks.ps1
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Test Suite 3: scan-sinks.ps1" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$sinksOutput = Join-Path $TestOutputDir 'sinks-raw.json'

Write-Host "  Running scan-sinks.ps1..."
& (Join-Path $ScriptDir 'scan-sinks.ps1') -ProjectDir $ProjectDir -OutputFile $sinksOutput 2>&1 | Out-Null

Assert-FileExists $sinksOutput 'scan-sinks.ps1 produces output file'
Assert-JsonValid $sinksOutput 'scan-sinks.ps1 output is valid JSON'
Assert-JsonField -File $sinksOutput -FieldPath 'total_sinks' -MinValue 10 -TestName 'total_sinks >= 10'

$sinkJson = Get-Content $sinksOutput -Raw | ConvertFrom-Json

# Check specific sink types found in WebGoat
Assert-True -Condition ($null -ne $sinkJson.sinks.SQL_EXECUTION) -TestName 'Finds SQL_EXECUTION sinks'
Assert-True -Condition ($null -ne $sinkJson.sinks.SQL_CONCAT) -TestName 'Finds SQL_CONCAT sinks'
Assert-True -Condition ($null -ne $sinkJson.sinks.FILE_OPS) -TestName 'Finds FILE_OPS sinks'
Assert-True -Condition ($null -ne $sinkJson.sinks.HTTP_REQUEST) -TestName 'Finds HTTP_REQUEST sinks'
Assert-True -Condition ($null -ne $sinkJson.sinks.DESERIALIZE) -TestName 'Finds DESERIALIZE sinks'
Assert-True -Condition ($null -ne $sinkJson.sinks.XXE) -TestName 'Finds XXE sinks'
Assert-True -Condition ($null -ne $sinkJson.sinks.CMD_EXEC) -TestName 'Finds CMD_EXEC sinks'

# Check hardcoded secrets
Assert-True -Condition ($sinkJson.hardcoded_secrets.count -gt 0) -TestName 'Finds hardcoded secrets'

# Check weak crypto
Assert-True -Condition ($sinkJson.weak_crypto.count -gt 0) -TestName 'Finds weak cryptography'

# ============================================================
# Test 4: scan-configs.ps1
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Test Suite 4: scan-configs.ps1" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$configsOutput = Join-Path $TestOutputDir 'configs-raw.json'

Write-Host "  Running scan-configs.ps1..."
& (Join-Path $ScriptDir 'scan-configs.ps1') -ProjectDir $ProjectDir -OutputFile $configsOutput 2>&1 | Out-Null

Assert-FileExists $configsOutput 'scan-configs.ps1 produces output file'
Assert-JsonValid $configsOutput 'scan-configs.ps1 output is valid JSON'
Assert-JsonField -File $configsOutput -FieldPath 'config_files_scanned' -MinValue 1 -TestName 'config_files_scanned >= 1'
Assert-JsonField -File $configsOutput -FieldPath 'high_risk_count' -MinValue 1 -TestName 'high_risk_count >= 1'

$configJson = Get-Content $configsOutput -Raw | ConvertFrom-Json

# Check that configs object has entries
$configKeys = @($configJson.configs.PSObject.Properties.Name)
Assert-True -Condition ($configKeys.Count -gt 0) -TestName 'Config entries found'

# ============================================================
# Test 5: validate-output.ps1 (test with missing files)
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Test Suite 5: validate-output.ps1" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Test with empty directory (should fail)
$emptyDir = Join-Path $TestOutputDir 'empty'
New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null

Write-Host "  Running validate-output.ps1 on empty dir (expect failure)..."
$exitCode = 0
try {
    & (Join-Path $ScriptDir 'validate-output.ps1') -OutputDir $emptyDir -Phase 'phase1' 2>&1 | Out-Null
    $exitCode = $LASTEXITCODE
} catch {
    $exitCode = 1
}

Assert-True -Condition ($exitCode -ne 0) -TestName 'validate-output.ps1 fails on empty directory'

# ============================================================
# Summary
# ============================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Passed:  $script:TestsPassed" -ForegroundColor Green
Write-Host "  Failed:  $script:TestsFailed" -ForegroundColor $(if ($script:TestsFailed -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Skipped: $script:TestsSkipped" -ForegroundColor Yellow
Write-Host ""

if ($script:TestsFailed -eq 0) {
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests failed!" -ForegroundColor Red
    exit 1
}
