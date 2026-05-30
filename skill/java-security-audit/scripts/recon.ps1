<#
.SYNOPSIS
    Phase 1: Project Reconnaissance (Deterministic Scan)
.DESCRIPTION
    Outputs structured JSON data for AI analysis
.PARAMETER ProjectDir
    Path to the Java project root
.PARAMETER OutputFile
    Output JSON file path
.EXAMPLE
    .\recon.ps1 -ProjectDir "D:\code\project" -OutputFile "output\phase1-raw.json"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectDir,
    
    [string]$OutputFile = 'output/phase1-raw.json'
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir 'lib\common.ps1')

$ProjectDir = Get-NormalizedPath $ProjectDir
$OutputDir = Split-Path -Parent $OutputFile
if ($OutputDir -and -not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-LogInfo ('Phase 1 Recon: ' + $ProjectDir)

# 1. Build file detection
Write-LogInfo 'Detecting build files...'

$build = @{
    tool = 'unknown'
    file = ''
    framework = 'unknown'
    framework_version = 'unknown'
    java_version = 'unknown'
}

$pomFile = Join-Path $ProjectDir 'pom.xml'
$gradleFile = Join-Path $ProjectDir 'build.gradle'
$gradleKtsFile = Join-Path $ProjectDir 'build.gradle.kts'

if (Test-Path $pomFile) {
    $build.tool = 'maven'
    $build.file = 'pom.xml'
    $pomContent = Get-Content $pomFile -Raw

    if ($pomContent -match '<version>([^<]+)</version>') {
        $build.framework_version = $Matches[1]
    }
    if ($pomContent -match 'spring-boot-starter-webflux') {
        $build.framework = 'spring-boot-webflux'
    } elseif ($pomContent -match 'spring-boot-starter-web') {
        $build.framework = 'spring-boot-webmvc'
    }
    $javaVerPattern = '<java\.version>([^<]+)</java\.version>'
    if ($pomContent -match $javaVerPattern) {
        $build.java_version = $Matches[1]
    }
}
elseif (Test-Path $gradleFile) {
    $build.tool = 'gradle'
    $build.file = 'build.gradle'
    $gradleContent = Get-Content $gradleFile -Raw
    if ($gradleContent -match 'spring-boot-starter-web') {
        $build.framework = 'spring-boot-webmvc'
    } elseif ($gradleContent -match 'spring-boot-starter-webflux') {
        $build.framework = 'spring-boot-webflux'
    }
}
elseif (Test-Path $gradleKtsFile) {
    $build.tool = 'gradle'
    $build.file = 'build.gradle.kts'
}

Write-LogOk ('Build: ' + $build.tool + ', Framework: ' + $build.framework)

# 2. Controller scan
Write-LogInfo 'Scanning Controllers...'

$controllers = @()
$controllerMatches = Find-PatternRecursive -Pattern '@(Controller|RestController)' -Directory $ProjectDir
$controllerFiles = $controllerMatches | ForEach-Object { $_.File } | Sort-Object -Unique

foreach ($file in $controllerFiles) {
    $className = [System.IO.Path]::GetFileNameWithoutExtension($file)
    $classPath = ''
    $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
    $rmPattern = '@RequestMapping\s*\(\s*(?:value\s*=\s*)?["'']([^"'']+)["'']'
    if ($content -and $content -match $rmPattern) {
        $classPath = $Matches[1]
    }
    $controllers += @{
        file = $file
        class = $className
        classPath = $classPath
    }
}

Write-LogOk ('Found ' + $controllers.Count + ' Controllers')

# 3. Filter scan
Write-LogInfo 'Scanning Filters...'

$filters = @()

$webFilterFiles = Find-PatternRecursive -Pattern '@WebFilter' -Directory $ProjectDir
foreach ($m in $webFilterFiles) {
    $filters += @{
        file = $m.File
        class = [System.IO.Path]::GetFileNameWithoutExtension($m.File)
        type = 'WebFilter'
    }
}

$filterRegFiles = Find-PatternRecursive -Pattern 'FilterRegistrationBean' -Directory $ProjectDir
foreach ($m in $filterRegFiles) {
    $filters += @{
        file = $m.File
        class = [System.IO.Path]::GetFileNameWithoutExtension($m.File)
        type = 'FilterRegistrationBean'
    }
}

Write-LogOk ('Found ' + $filters.Count + ' Filters')

# 4. Interceptor scan
Write-LogInfo 'Scanning Interceptors...'

$interceptors = @()
$interceptorFiles = Find-PatternRecursive -Pattern 'HandlerInterceptor|addInterceptors' -Directory $ProjectDir

foreach ($m in $interceptorFiles) {
    $interceptors += @{
        file = $m.File
        class = [System.IO.Path]::GetFileNameWithoutExtension($m.File)
    }
}

Write-LogOk ('Found ' + $interceptors.Count + ' Interceptors')

# 5. SecurityFilterChain scan
Write-LogInfo 'Scanning SecurityFilterChain...'

$securityChains = @()
$secChainFiles = Find-PatternRecursive -Pattern 'SecurityFilterChain' -Directory $ProjectDir

foreach ($m in $secChainFiles) {
    $file = $m.File
    $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
    $csrfDisabled = $false
    if ($content -and $content -match 'csrf.*disable') {
        $csrfDisabled = $true
    }
    $passwordEncoder = 'unknown'
    if ($content -and $content -match 'NoOpPasswordEncoder') {
        $passwordEncoder = 'NoOpPasswordEncoder'
    } elseif ($content -and $content -match 'BCryptPasswordEncoder') {
        $passwordEncoder = 'BCryptPasswordEncoder'
    }
    $securityChains += @{
        file = $file
        class = [System.IO.Path]::GetFileNameWithoutExtension($file)
        csrfDisabled = $csrfDisabled
        passwordEncoder = $passwordEncoder
    }
}

Write-LogOk ('Found ' + $securityChains.Count + ' SecurityFilterChains')

# 6. Config file scan
Write-LogInfo 'Scanning config files...'

$configFiles = @()
$foundConfigs = Find-ConfigFiles -ProjectDir $ProjectDir
foreach ($cf in $foundConfigs) {
    $configFiles += $cf.FullName
}

Write-LogOk ('Found ' + $configFiles.Count + ' config files')

# 7. Dependency scan
Write-LogInfo 'Scanning key dependencies...'

$dependencies = @()
if ($build.tool -eq 'maven' -and (Test-Path $pomFile)) {
    $pomContent = Get-Content $pomFile -Raw
    $keyDeps = @('xstream', 'jjwt', 'jose4j', 'nimbus-jose', 'spring-security', 'thymeleaf', 'commons-collections')
    foreach ($dep in $keyDeps) {
        $depPattern = $dep + '[\s\S]{0,200}<version>([^<]+)</version>'
        if ($pomContent -match $depPattern) {
            $dependencies += @{
                name = $dep
                version = $Matches[1]
            }
        }
    }
}

# 8. Protocol feature scan
Write-LogInfo 'Scanning protocol features...'

$protocols = @()

$checks = @(
    @{ id = 'OAUTH2-AC';    pattern = '@EnableOAuth2Client|spring\.security\.oauth2\.client' },
    @{ id = 'JWT-LIFECYCLE'; pattern = 'JwtDecoder|jjwt|java-jwt|jose4j' },
    @{ id = 'PWD-RESET';    pattern = 'resetPassword|forgotPassword|passwordReset' },
    @{ id = 'MFA';          pattern = 'twoFactor|mfa|totp|authenticator' },
    @{ id = 'PAYMENT';      pattern = 'payment|charge|transfer|transaction|checkout' },
    @{ id = 'WEBSOCKET';    pattern = '@ServerEndpoint|@MessageMapping|WebSocketHandler' },
    @{ id = 'GRAPHQL';      pattern = '@QueryMapping|@MutationMapping|@DgsQuery|graphql' },
    @{ id = 'FILE-UPLOAD';  pattern = 'MultipartFile' }
)

foreach ($check in $checks) {
    $result = Find-PatternRecursive -Pattern $check.pattern -Directory $ProjectDir
    if ($result.Count -gt 0) {
        $protocols += $check.id
    }
}

# Output JSON
Write-LogInfo ('Generating output: ' + $OutputFile)

$result = @{
    project_dir = $ProjectDir
    scan_time = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    build = $build
    controllers = @{
        count = $controllers.Count
        items = $controllers
    }
    filters = @{
        count = $filters.Count
        items = $filters
    }
    interceptors = @{
        count = $interceptors.Count
        items = $interceptors
    }
    security_chains = @{
        count = $securityChains.Count
        items = $securityChains
    }
    config_files = @{
        count = $configFiles.Count
        items = $configFiles
    }
    dependencies = $dependencies
    protocols = $protocols
}

$result | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding utf8

Write-LogOk 'Phase 1 Recon complete'
Write-LogInfo ('Output: ' + $OutputFile)
$msg = 'Stats: {0} Controllers, {1} Filters, {2} Interceptors, {3} SecurityFilterChains, {4} config files' -f `
    $controllers.Count, $filters.Count, $interceptors.Count, $securityChains.Count, $configFiles.Count
Write-LogInfo $msg
