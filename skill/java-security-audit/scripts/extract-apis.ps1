<#
.SYNOPSIS
    API Endpoint Extraction (Deterministic Scan)
.DESCRIPTION
    Extracts all endpoints, parameters, and annotations from Controllers
.PARAMETER ProjectDir
    Path to the Java project root
.PARAMETER OutputFile
    Output JSON file path
.EXAMPLE
    .\extract-apis.ps1 -ProjectDir "D:\code\project" -OutputFile "output\apis-raw.json"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectDir,
    
    [string]$OutputFile = 'output/apis-raw.json'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir 'lib\common.ps1')

$ProjectDir = Get-NormalizedPath $ProjectDir
$OutputDir = Split-Path -Parent $OutputFile
if ($OutputDir -and -not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-LogInfo ('API extraction: ' + $ProjectDir)

# Find all Controller files
$controllerMatches = Find-PatternRecursive -Pattern '@(Controller|RestController)' -Directory $ProjectDir
$controllerFiles = $controllerMatches | ForEach-Object { $_.File } | Sort-Object -Unique

Write-LogInfo ('Found ' + $controllerFiles.Count + ' Controller files')

# Extract endpoints from each file
$endpoints = @()

foreach ($file in $controllerFiles) {
    $lines = Get-Content $file -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    
    # Extract class-level @RequestMapping
    $classPath = ''
    $rawContent = $lines -join "`n"
    $classRmPattern = '@RequestMapping\s*\(\s*(?:value\s*=\s*)?["'']([^"'']+)["'']'
    if ($rawContent -match $classRmPattern) {
        $classPath = $Matches[1]
    }
    
    # Scan each line for method-level mappings
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $mappingPattern = '@(Get|Post|Put|Delete|Patch|Request)Mapping'
        
        if ($line -match $mappingPattern) {
            $lineNum = $i + 1
            
            # Extract HTTP method
            $httpMethod = 'ALL'
            if ($line -match '@GetMapping') { $httpMethod = 'GET' }
            elseif ($line -match '@PostMapping') { $httpMethod = 'POST' }
            elseif ($line -match '@PutMapping') { $httpMethod = 'PUT' }
            elseif ($line -match '@DeleteMapping') { $httpMethod = 'DELETE' }
            elseif ($line -match '@PatchMapping') { $httpMethod = 'PATCH' }
            elseif ($line -match '@RequestMapping') {
                if ($line -match 'RequestMethod\.GET') { $httpMethod = 'GET' }
                elseif ($line -match 'RequestMethod\.POST') { $httpMethod = 'POST' }
                elseif ($line -match 'RequestMethod\.PUT') { $httpMethod = 'PUT' }
                elseif ($line -match 'RequestMethod\.DELETE') { $httpMethod = 'DELETE' }
            }
            
            # Extract path
            $methodPath = ''
            $pathPattern = '(?:value|path)\s*=\s*["'']([^"'']+)["'']'
            if ($line -match $pathPattern) {
                $methodPath = $Matches[1]
            } else {
                $shortPathPattern = '@(?:Get|Post|Put|Delete|Patch|Request)Mapping\s*\(\s*["'']([^"'']+)["'']'
                if ($line -match $shortPathPattern) {
                    $methodPath = $Matches[1]
                }
            }
            
            $fullPath = $classPath + $methodPath
            if (-not $fullPath) { $fullPath = '/' }
            
            # Extract method name from subsequent lines
            $methodName = 'unknown'
            $endSearch = [Math]::Min($i + 5, $lines.Count)
            for ($j = $i + 1; $j -lt $endSearch; $j++) {
                $methodPattern = '(?:public|private|protected)\s+\S+\s+(\w+)\s*\('
                if ($lines[$j] -match $methodPattern) {
                    $methodName = $Matches[1]
                    break
                }
            }
            
            # Extract parameters from method signature (next few lines)
            $params = @()
            $paramBlock = ''
            $endParam = [Math]::Min($i + 6, $lines.Count)
            for ($j = $i + 1; $j -lt $endParam; $j++) {
                $paramBlock += $lines[$j] + ' '
            }
            
            # @RequestParam
            $rpPattern = '@RequestParam\s*(?:\([^)]*\))?\s+(\S+)\s+(\w+)'
            $rpMatches = [regex]::Matches($paramBlock, $rpPattern)
            foreach ($m in $rpMatches) {
                $params += @{
                    annotation = '@RequestParam'
                    name = $m.Groups[2].Value
                    type = $m.Groups[1].Value
                }
            }
            
            # @PathVariable
            $pvPattern = '@PathVariable\s*(?:\([^)]*\))?\s+(\S+)\s+(\w+)'
            $pvMatches = [regex]::Matches($paramBlock, $pvPattern)
            foreach ($m in $pvMatches) {
                $params += @{
                    annotation = '@PathVariable'
                    name = $m.Groups[2].Value
                    type = $m.Groups[1].Value
                }
            }
            
            # @RequestBody
            $rbPattern = '@RequestBody\s+(\S+)\s+(\w+)'
            if ($paramBlock -match $rbPattern) {
                $params += @{
                    annotation = '@RequestBody'
                    name = $Matches[2]
                    type = $Matches[1]
                }
            }
            
            # @RequestHeader
            $rhPattern = '@RequestHeader\s*(?:\([^)]*\))?\s+(\S+)\s+(\w+)'
            $rhMatches = [regex]::Matches($paramBlock, $rhPattern)
            foreach ($m in $rhMatches) {
                $params += @{
                    annotation = '@RequestHeader'
                    name = $m.Groups[2].Value
                    type = $m.Groups[1].Value
                }
            }
            
            # @CookieValue
            $cvPattern = '@CookieValue\s*(?:\([^)]*\))?\s+(\S+)\s+(\w+)'
            $cvMatches = [regex]::Matches($paramBlock, $cvPattern)
            foreach ($m in $cvMatches) {
                $params += @{
                    annotation = '@CookieValue'
                    name = $m.Groups[2].Value
                    type = $m.Groups[1].Value
                }
            }
            
            # Check security annotations (lines before method)
            $security = ''
            $contextStart = [Math]::Max(0, $i - 4)
            $contextBlock = ($lines[$contextStart..$i]) -join "`n"
            
            if ($contextBlock -match '@PreAuthorize') { $security = 'PreAuthorize' }
            elseif ($contextBlock -match '@Secured') { $security = 'Secured' }
            elseif ($contextBlock -match '@RolesAllowed') { $security = 'RolesAllowed' }
            
            $endpoints += @{
                httpMethod = $httpMethod
                path = $fullPath
                methodName = $methodName
                file = $file
                line = $lineNum
                security = $security
                params = $params
            }
        }
    }
}

# Output JSON
$result = @{
    project_dir = $ProjectDir
    scan_time = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    total_endpoints = $endpoints.Count
    endpoints = $endpoints
}

$result | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding utf8

Write-LogOk ('API extraction complete: ' + $endpoints.Count + ' endpoints')
Write-LogInfo ('Output: ' + $OutputFile)
