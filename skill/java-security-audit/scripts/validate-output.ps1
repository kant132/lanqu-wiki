<#
.SYNOPSIS
    Output Completeness Validator (Deterministic)
.DESCRIPTION
    Validates that audit reports contain all required sections
.PARAMETER OutputDir
    Path to the output directory
.PARAMETER Phase
    Which phase to validate: all, phase1, phase2, phase3, phase4, final
.EXAMPLE
    .\validate-output.ps1 -OutputDir "output" -Phase "all"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,
    
    [ValidateSet('all', 'phase1', 'phase2', 'phase3', 'phase4', 'final')]
    [string]$Phase = 'all'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir 'lib\common.ps1')

$script:ErrorCount = 0
$script:WarningCount = 0

Write-LogInfo ('Output validation: ' + $OutputDir + ' (phase: ' + $Phase + ')')

# ============================================================
# Validation functions
# ============================================================
function Check-FileExists {
    param([string]$File, [string]$Desc)
    $fullPath = Join-Path $OutputDir $File
    if (Test-Path $fullPath) {
        Write-LogOk ($Desc + ': ' + $File)
    } else {
        Write-LogError ($Desc + ' missing: ' + $File)
        $script:ErrorCount++
    }
}

function Check-SectionExists {
    param([string]$File, [string]$Section, [string]$Desc)
    $fullPath = Join-Path $OutputDir $File
    if (-not (Test-Path $fullPath)) {
        Write-LogError ('File not found: ' + $File)
        $script:ErrorCount++
        return
    }
    $content = Get-Content $fullPath -Raw -ErrorAction SilentlyContinue
    if ($content -and $content.Contains($Section)) {
        Write-LogOk $Desc
    } else {
        Write-LogError ('Missing section: ' + $Section + ' (in ' + $File + ')')
        $script:ErrorCount++
    }
}

function Check-NoEllipsis {
    param([string]$File, [string]$Desc)
    $fullPath = Join-Path $OutputDir $File
    if (-not (Test-Path $fullPath)) { return }
    $content = Get-Content $fullPath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return }
    
    $ellipsisPattern = '\.\.\.\.|' + [regex]::Escape('...')
    $count = ([regex]::Matches($content, $ellipsisPattern)).Count
    
    if ($count -gt 0) {
        Write-LogError ($Desc + ': found ' + $count + ' ellipsis (in ' + $File + ')')
        $script:ErrorCount++
    } else {
        Write-LogOk ($Desc + ': no ellipsis')
    }
}

function Check-ContainsPattern {
    param([string]$File, [string]$Pattern, [string]$Desc)
    $fullPath = Join-Path $OutputDir $File
    if (-not (Test-Path $fullPath)) {
        Write-LogError ('File not found: ' + $File)
        $script:ErrorCount++
        return
    }
    $content = Get-Content $fullPath -Raw -ErrorAction SilentlyContinue
    if ($content -and $content -match $Pattern) {
        Write-LogOk $Desc
    } else {
        Write-LogError ($Desc + ' (not found in ' + $File + ')')
        $script:ErrorCount++
    }
}

function Check-ChineseOutput {
    param([string]$File, [string]$Desc)
    $fullPath = Join-Path $OutputDir $File
    if (-not (Test-Path $fullPath)) { return }
    $lines = Get-Content $fullPath -ErrorAction SilentlyContinue
    if (-not $lines) { return }
    
    $totalLines = $lines.Count
    if ($totalLines -eq 0) { $totalLines = 1 }
    
    $chinesePattern = '[\u4e00-\u9fff]'
    $chineseLines = 0
    foreach ($line in $lines) {
        if ($line -match $chinesePattern) {
            $chineseLines++
        }
    }
    
    $ratio = [math]::Round($chineseLines * 100 / $totalLines)
    
    if ($ratio -ge 10) {
        Write-LogOk ($Desc + ': Chinese ratio ' + $ratio + '%')
    } else {
        Write-LogWarn ($Desc + ': Chinese ratio only ' + $ratio + '%, may need translation')
        $script:WarningCount++
    }
}

# ============================================================
# Phase validators
# ============================================================
function Validate-Phase1 {
    Write-LogInfo '=== Phase 1 Validation ==='
    Check-FileExists 'phase1-recon.md' 'Phase 1 report'
    Check-SectionExists 'phase1-recon.md' 'C1' 'C1 assertion'
    Check-SectionExists 'phase1-recon.md' 'C6' 'C6 assertion (config)'
    Check-SectionExists 'phase1-recon.md' 'C8' 'C8 assertion (protocols)'
    Check-NoEllipsis 'phase1-recon.md' 'Phase 1 no ellipsis'
    Check-ChineseOutput 'phase1-recon.md' 'Phase 1 Chinese output'
}

function Validate-Phase2 {
    Write-LogInfo '=== Phase 2 Validation ==='
    Check-FileExists 'phase2-filter-audit.md' 'Phase 2 report'
    Check-NoEllipsis 'phase2-filter-audit.md' 'Phase 2 no ellipsis'
    Check-ChineseOutput 'phase2-filter-audit.md' 'Phase 2 Chinese output'
}

function Validate-Phase3 {
    Write-LogInfo '=== Phase 3 Validation ==='
    Check-FileExists 'phase3-interceptor-audit.md' 'Phase 3 report'
    Check-NoEllipsis 'phase3-interceptor-audit.md' 'Phase 3 no ellipsis'
    Check-ChineseOutput 'phase3-interceptor-audit.md' 'Phase 3 Chinese output'
}

function Validate-Phase4 {
    Write-LogInfo '=== Phase 4 Validation ==='
    Check-FileExists 'phase4-api-audit.md' 'Phase 4 report'
    Check-SectionExists 'phase4-api-audit.md' 'PoC' 'PoC section'
    Check-SectionExists 'phase4-api-audit.md' 'Fuzzing' 'Fuzzing dictionary'
    Check-ContainsPattern 'phase4-api-audit.md' 'curl' 'PoC contains curl'
    Check-ContainsPattern 'phase4-api-audit.md' 'DETERMINISTIC|HEURISTIC|SUBJECTIVE' 'Deterministic labels'
    Check-ContainsPattern 'phase4-api-audit.md' 'CONFIRMED|LIKELY|POSSIBLE' 'Confidence labels'
    Check-NoEllipsis 'phase4-api-audit.md' 'Phase 4 no ellipsis'
    Check-ChineseOutput 'phase4-api-audit.md' 'Phase 4 Chinese output'
}

function Validate-Final {
    Write-LogInfo '=== Final Report Validation ==='
    Check-FileExists 'final-audit-report.md' 'Final report'
    Check-FileExists 'comprehensive-security-analysis.md' 'Comprehensive analysis'
    Check-FileExists 'threat-model.md' 'Threat model'
    Check-SectionExists 'final-audit-report.md' 'PASS' 'Conservation check'
    Check-NoEllipsis 'final-audit-report.md' 'Final report no ellipsis'
    Check-ChineseOutput 'final-audit-report.md' 'Final report Chinese output'
}

# ============================================================
# Execute validation
# ============================================================
switch ($Phase) {
    'phase1' { Validate-Phase1 }
    'phase2' { Validate-Phase2 }
    'phase3' { Validate-Phase3 }
    'phase4' { Validate-Phase4 }
    'final'  { Validate-Final }
    'all' {
        Validate-Phase1
        Validate-Phase2
        Validate-Phase3
        Validate-Phase4
        Validate-Final
    }
}

# Summary
Write-Host ''
Write-Host '============================================'
if ($script:ErrorCount -eq 0) {
    Write-LogOk ('Validation passed! 0 errors, ' + $script:WarningCount + ' warnings')
    exit 0
} else {
    Write-LogError ('Validation failed! ' + $script:ErrorCount + ' errors, ' + $script:WarningCount + ' warnings')
    exit 1
}
