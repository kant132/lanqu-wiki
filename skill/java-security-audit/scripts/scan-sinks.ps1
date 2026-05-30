<#
.SYNOPSIS
    Sink Pattern Scanner (Deterministic)
.DESCRIPTION
    Scans all security-relevant sink patterns in Java source code
.PARAMETER ProjectDir
    Path to the Java project root
.PARAMETER OutputFile
    Output JSON file path
.EXAMPLE
    .\scan-sinks.ps1 -ProjectDir "D:\code\project" -OutputFile "output\sinks-raw.json"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectDir,
    
    [string]$OutputFile = 'output/sinks-raw.json'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir 'lib\common.ps1')

$ProjectDir = Get-NormalizedPath $ProjectDir
$OutputDir = Split-Path -Parent $OutputFile
if ($OutputDir -and -not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-LogInfo ('Sink scan: ' + $ProjectDir)

$srcDir = Join-Path $ProjectDir 'src/main/java'
if (-not (Test-Path $srcDir)) {
    Write-LogError ('Source directory not found: ' + $srcDir)
    exit 1
}

# Sink pattern definitions
$sinkPatterns = [ordered]@{
    SQL_EXECUTION    = 'Statement\.(executeQuery|executeUpdate|execute)\s*\(|createQuery\s*\(|createNativeQuery\s*\('
    SQL_CONCAT       = '\+\s*\w+\s*\+\s*"'
    FILE_OPS         = 'new\s+File\s*\(|FileInputStream\s*\(|FileOutputStream\s*\(|Paths\.get\s*\(|\.transferTo\s*\('
    HTTP_REQUEST     = 'RestTemplate|HttpClient|WebClient|URL\.openConnection|HttpURLConnection|\.openStream\s*\('
    DESERIALIZE      = '\.readObject\s*\(|\.fromXML\s*\(|\.parseObject\s*\(|enableDefaultTyping|ObjectInputStream|XMLDecoder'
    TEMPLATE_RENDER  = 'getTemplate\s*\(|th:utext|\?new\s*\(|VelocityEngine'
    EXPRESSION_PARSE = 'parseExpression\s*\(|SpelExpressionParser|StandardEvaluationContext|OgnlUtil|MVEL\.eval|GroovyShell|ScriptEngine'
    JNDI             = 'InitialContext\.lookup|JndiTemplate\.lookup|ctx\.lookup'
    XXE              = 'DocumentBuilderFactory|SAXParser|XMLReader|TransformerFactory|XMLInputFactory'
    CMD_EXEC         = 'Runtime\.getRuntime\(\)\.exec\s*\(|ProcessBuilder|Runtime\.exec\s*\('
    REDIRECT         = 'sendRedirect\s*\(|RedirectView|\.forward\s*\('
    LDAP             = 'DirContext\.search|LdapTemplate|SearchControls'
}

# Scan each sink type
$sinkResults = @{}
$totalSinks = 0

foreach ($sinkType in $sinkPatterns.Keys) {
    $pattern = $sinkPatterns[$sinkType]
    $matches = Find-PatternRecursive -Pattern $pattern -Directory $srcDir
    
    if ($matches.Count -gt 0) {
        $matchList = @()
        foreach ($m in $matches) {
            $content = $m.Content
            if ($content.Length -gt 200) { $content = $content.Substring(0, 200) }
            $matchList += @{
                file = $m.File
                line = $m.Line
                content = $content
            }
        }
        $sinkResults[$sinkType] = @{
            count = $matches.Count
            matches = $matchList
        }
        $totalSinks += $matches.Count
        Write-LogWarn ($sinkType + ': ' + $matches.Count + ' matches')
    } else {
        Write-LogOk ($sinkType + ': no matches')
    }
}

# Hardcoded secrets scan
Write-LogInfo 'Scanning hardcoded secrets...'

$secretPattern = '(password|secret|key|apiKey|api_key)\s*=\s*"[^"]+"'
$hardcodedMatches = Find-PatternRecursive -Pattern $secretPattern -Directory $srcDir
$hardcodedMatches = @($hardcodedMatches | Where-Object { $_.File -notmatch '[Tt]est' })

$hardcoded = @{
    count = $hardcodedMatches.Count
    matches = @()
}

foreach ($m in $hardcodedMatches) {
    $content = $m.Content
    if ($content.Length -gt 200) { $content = $content.Substring(0, 200) }
    $hardcoded.matches += @{
        file = $m.File
        line = $m.Line
        content = $content
    }
}

# Weak crypto scan
Write-LogInfo 'Scanning weak cryptography...'

$cryptoPatterns = [ordered]@{
    WEAK_HASH   = 'MessageDigest\.getInstance\s*\(\s*["''](?:MD5|SHA-?1)["'']'
    WEAK_CIPHER = 'Cipher\.getInstance\s*\(\s*["''](?:DES|RC4|RC2|Blowfish)'
    ECB_MODE    = 'Cipher\.getInstance\s*\(\s*["''][^"'']*/ECB/'
    WEAK_RANDOM = 'new\s+Random\s*\('
    TRUST_ALL   = 'X509TrustManager.*checkServerTrusted'
}

$weakCrypto = @{
    count = 0
    matches = @()
}

foreach ($cryptoType in $cryptoPatterns.Keys) {
    $pattern = $cryptoPatterns[$cryptoType]
    $matches = Find-PatternRecursive -Pattern $pattern -Directory $srcDir
    
    foreach ($m in $matches) {
        $weakCrypto.count++
        $content = $m.Content
        if ($content.Length -gt 200) { $content = $content.Substring(0, 200) }
        $weakCrypto.matches += @{
            type = $cryptoType
            file = $m.File
            line = $m.Line
            content = $content
        }
    }
}

# Output JSON
$result = @{
    project_dir = $ProjectDir
    scan_time = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    total_sinks = $totalSinks
    sinks = $sinkResults
    hardcoded_secrets = $hardcoded
    weak_crypto = $weakCrypto
}

$result | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding utf8

$msg = 'Sink scan complete: {0} sinks, {1} hardcoded secrets, {2} weak crypto' -f `
    $totalSinks, $hardcoded.count, $weakCrypto.count
Write-LogOk $msg
Write-LogInfo ('Output: ' + $OutputFile)
