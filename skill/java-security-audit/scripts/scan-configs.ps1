<#
.SYNOPSIS
    Config File Security Scanner (Deterministic)
.DESCRIPTION
    Scans application.yml/properties for security-related configurations
.PARAMETER ProjectDir
    Path to the Java project root
.PARAMETER OutputFile
    Output JSON file path
.EXAMPLE
    .\scan-configs.ps1 -ProjectDir "D:\code\project" -OutputFile "output\configs-raw.json"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectDir,
    
    [string]$OutputFile = 'output/configs-raw.json'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir 'lib\common.ps1')

$ProjectDir = Get-NormalizedPath $ProjectDir
$OutputDir = Split-Path -Parent $OutputFile
if ($OutputDir -and -not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-LogInfo ('Config scan: ' + $ProjectDir)

# Find all config files
$configFiles = @(Find-ConfigFiles -ProjectDir $ProjectDir)
Write-LogInfo ('Found ' + $configFiles.Count + ' config files')

# Security config patterns
$securityConfigPatterns = [ordered]@{
    SSL_ENABLED             = 'server\.ssl\.enabled'
    SSL_KEYSTORE            = 'server\.ssl\.key-store'
    SSL_KEYSTORE_PASSWORD   = 'server\.ssl\.key-store-password'
    SSL_KEY_ALIAS           = 'server\.ssl\.key-alias'
    SSL_PROTOCOL            = 'server\.ssl\.protocol'
    ACTUATOR_EXPOSURE       = 'management\.endpoints\.web\.exposure\.include'
    ACTUATOR_PORT           = 'management\.server\.port'
    HEALTH_DETAILS          = 'management\.endpoint\.health\.show-details'
    SESSION_TIMEOUT         = 'server\.servlet\.session\.timeout'
    SESSION_COOKIE_NAME     = 'server\.servlet\.session\.cookie\.name'
    SESSION_COOKIE_HTTPONLY = 'server\.servlet\.session\.cookie\.http-only'
    SESSION_COOKIE_SECURE   = 'server\.servlet\.session\.cookie\.secure'
    SESSION_COOKIE_SAMESITE = 'server\.servlet\.session\.cookie\.same-site'
    ERROR_STACKTRACE        = 'server\.error\.include-stacktrace'
    ERROR_MESSAGE           = 'server\.error\.include-message'
    CORS_ORIGINS            = 'cors\.allowed-origins|allowedOrigins'
    CORS_CREDENTIALS        = 'cors\.allow-credentials|allowCredentials'
    OAUTH2_CLIENT_ID        = 'spring\.security\.oauth2\.client\.registration.*\.client-id'
    OAUTH2_CLIENT_SECRET    = 'spring\.security\.oauth2\.client\.registration.*\.client-secret'
    DB_URL                  = 'spring\.datasource\.url'
    DB_USERNAME             = 'spring\.datasource\.username'
    DB_PASSWORD             = 'spring\.datasource\.password'
    MULTIPART_MAX_SIZE      = 'spring\.servlet\.multipart\.max-file-size'
    MULTIPART_MAX_REQUEST   = 'spring\.servlet\.multipart\.max-request-size'
    JACKSON_FAIL_ON_UNKNOWN = 'spring\.jackson\.deserialization\.fail-on-unknown-properties'
    LOG_LEVEL_ROOT          = 'logging\.level\.root'
    LOG_LEVEL_APP           = 'logging\.level\.org\.owasp'
}

# Risk assessment function
function Get-RiskLevel {
    param([string]$ConfigKey, [string]$ConfigValue)
    
    switch ($ConfigKey) {
        'SSL_ENABLED' {
            if ($ConfigValue -eq 'false') { return 'HIGH' } else { return 'LOW' }
        }
        'SSL_KEYSTORE_PASSWORD' { return 'HIGH' }
        'ACTUATOR_EXPOSURE' {
            if ($ConfigValue -match 'env|configprops|beans|dump|trace') { return 'HIGH' } else { return 'LOW' }
        }
        'HEALTH_DETAILS' {
            if ($ConfigValue -eq 'always') { return 'MEDIUM' } else { return 'LOW' }
        }
        'ERROR_STACKTRACE' {
            if ($ConfigValue -eq 'always') { return 'HIGH' } else { return 'LOW' }
        }
        'ERROR_MESSAGE' {
            if ($ConfigValue -eq 'always') { return 'HIGH' } else { return 'LOW' }
        }
        'SESSION_COOKIE_HTTPONLY' {
            if ($ConfigValue -eq 'false') { return 'HIGH' } else { return 'LOW' }
        }
        'SESSION_COOKIE_SECURE' {
            if ($ConfigValue -eq 'false') { return 'HIGH' } else { return 'LOW' }
        }
        'CORS_ORIGINS' {
            if ($ConfigValue -eq '*') { return 'HIGH' } else { return 'LOW' }
        }
        'OAUTH2_CLIENT_SECRET' { return 'HIGH' }
        'DB_PASSWORD' { return 'HIGH' }
        default { return 'LOW' }
    }
}

# Scan each config file
$configResults = @{}
$highRiskCount = 0

foreach ($configFile in $configFiles) {
    $filePath = $configFile.FullName
    $fileName = $configFile.Name
    Write-LogInfo ('Scanning: ' + $filePath)
    
    $fileResults = @()
    
    foreach ($configKey in $securityConfigPatterns.Keys) {
        $pattern = $securityConfigPatterns[$configKey]
        
        $matches = Find-PatternInFile -Pattern $pattern -File $filePath
        
        foreach ($m in $matches) {
            $rawLine = $m.Content
            
            # Extract key and value
            $actualKey = $rawLine
            $actualValue = ''
            if ($rawLine -match '^([^=]+)=(.*)$') {
                $actualKey = $Matches[1].Trim()
                $actualValue = $Matches[2].Trim()
            }
            
            # Redact sensitive values
            $displayValue = $actualValue
            if ($configKey -match 'PASSWORD|SECRET') {
                $displayValue = '[REDACTED]'
            }
            
            # Assess risk
            $risk = Get-RiskLevel -ConfigKey $configKey -ConfigValue $actualValue
            if ($risk -eq 'HIGH') {
                $highRiskCount++
            }
            
            $fileResults += @{
                key = $configKey
                actualKey = $actualKey
                value = $displayValue
                line = $m.Line
                risk = $risk
            }
        }
    }
    
    if ($fileResults.Count -gt 0) {
        $configResults[$fileName] = @{
            file = $filePath
            items = $fileResults
        }
    }
}

# Output JSON
$result = @{
    project_dir = $ProjectDir
    scan_time = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    config_files_scanned = $configFiles.Count
    high_risk_count = $highRiskCount
    configs = $configResults
}

$result | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding utf8

$msg = 'Config scan complete: {0} files, {1} high-risk items' -f $configFiles.Count, $highRiskCount
Write-LogOk $msg
Write-LogInfo ('Output: ' + $OutputFile)
