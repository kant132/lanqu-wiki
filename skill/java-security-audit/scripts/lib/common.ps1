# common.ps1 - 公共函数库
# 所有审计脚本共享的工具函数

# ============================================================
# 颜色输出
# ============================================================
function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-LogOk {
    param([string]$Message)
    Write-Host "[OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-LogWarn {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# ============================================================
# 路径处理
# ============================================================
function Get-NormalizedPath {
    param([string]$Path)
    # 将反斜杠转为正斜杠，移除尾部斜杠
    $normalized = $Path -replace '\\', '/'
    $normalized = $normalized.TrimEnd('/')
    return $normalized
}

function Get-ScriptDirectory {
    if ($PSScriptRoot) {
        return $PSScriptRoot
    }
    return Split-Path -Parent $MyInvocation.MyCommand.Path
}

# ============================================================
# 文件扫描
# ============================================================
function Find-JavaFiles {
    param(
        [string]$ProjectDir,
        [ValidateSet('main', 'test', 'all')]
        [string]$Scope = 'main'
    )
    
    switch ($Scope) {
        'main' {
            Get-ChildItem -Path $ProjectDir -Filter "*.java" -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -like "*\src\main\java\*" -or $_.FullName -like "*/src/main/java/*" }
        }
        'test' {
            Get-ChildItem -Path $ProjectDir -Filter "*.java" -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -like "*\src\test\java\*" -or $_.FullName -like "*/src/test/java/*" }
        }
        'all' {
            Get-ChildItem -Path $ProjectDir -Filter "*.java" -Recurse -File -ErrorAction SilentlyContinue
        }
    }
}

function Find-ConfigFiles {
    param([string]$ProjectDir)
    
    Get-ChildItem -Path $ProjectDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.FullName -like "*\src\main\resources\*" -or $_.FullName -like "*/src/main/resources/*") -and
            ($_.Name -like "application*.yml" -or $_.Name -like "application*.yaml" -or 
             $_.Name -like "application*.properties" -or $_.Name -like "bootstrap*.yml" -or 
             $_.Name -like "bootstrap*.properties")
        }
}

# ============================================================
# 模式匹配
# ============================================================
function Find-PatternInFile {
    param(
        [string]$Pattern,
        [string]$File
    )
    
    if (-not (Test-Path $File)) { return @() }
    
    $results = @()
    Select-String -Path $File -Pattern $Pattern -ErrorAction SilentlyContinue | ForEach-Object {
        $results += @{
            File = $File
            Line = $_.LineNumber
            Content = $_.Line.Trim()
        }
    }
    return $results
}

function Find-PatternRecursive {
    param(
        [string]$Pattern,
        [string]$Directory,
        [string]$FilePattern = "*.java"
    )
    
    $results = @()
    Get-ChildItem -Path $Directory -Filter $FilePattern -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        $file = $_.FullName
        Select-String -Path $file -Pattern $Pattern -ErrorAction SilentlyContinue | ForEach-Object {
            $results += @{
                File = $file
                Line = $_.LineNumber
                Content = $_.Line.Trim()
            }
        }
    }
    return $results
}

# ============================================================
# JSON 输出
# ============================================================
function ConvertTo-SafeJson {
    param(
        [object]$Object,
        [int]$Depth = 10
    )
    $Object | ConvertTo-Json -Depth $Depth -Compress:$false
}

# ============================================================
# 计数与统计
# ============================================================
function Count-Matches {
    param(
        [string]$Pattern,
        [string]$File
    )
    
    if (-not (Test-Path $File)) { return 0 }
    $count = (Select-String -Path $File -Pattern $Pattern -ErrorAction SilentlyContinue).Count
    return if ($null -eq $count) { 0 } else { $count }
}

function Count-MatchingFiles {
    param(
        [string]$Pattern,
        [string]$Directory,
        [string]$FilePattern = "*.java"
    )
    
    $files = Get-ChildItem -Path $Directory -Filter $FilePattern -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { Select-String -Path $_.FullName -Pattern $Pattern -Quiet -ErrorAction SilentlyContinue }
    return @($files).Count
}

# ============================================================
# 验证函数
# ============================================================
function Test-RequiredFile {
    param(
        [string]$File,
        [string]$Description
    )
    
    if (Test-Path $File) {
        Write-LogOk "$Description`: $File"
        return $true
    } else {
        Write-LogError "$Description 缺失: $File"
        return $false
    }
}

function Test-RequiredSection {
    param(
        [string]$File,
        [string]$Section
    )
    
    if (-not (Test-Path $File)) {
        Write-LogError "文件不存在: $File"
        return $false
    }
    
    $content = Get-Content $File -Raw -ErrorAction SilentlyContinue
    if ($content -match [regex]::Escape($Section)) {
        Write-LogOk "包含段落: $Section"
        return $true
    } else {
        Write-LogError "缺失段落: $Section (在 $File 中)"
        return $false
    }
}

function Test-TableRows {
    param(
        [string]$File,
        [string]$TableHeader,
        [int]$MinRows,
        [string]$Description
    )
    
    if (-not (Test-Path $File)) {
        Write-LogError "文件不存在: $File"
        return $false
    }
    
    $content = Get-Content $File -ErrorAction SilentlyContinue
    $found = $false
    $count = 0
    
    foreach ($line in $content) {
        if ($line -match [regex]::Escape($TableHeader)) {
            $found = $true
            continue
        }
        if ($found -and $line -match '^\|[^-]') {
            $count++
        }
        if ($found -and $line -notmatch '^\|') {
            break
        }
    }
    
    if ($count -ge $MinRows) {
        Write-LogOk "$Description`: $count 行 (>= $MinRows)"
        return $true
    } else {
        Write-LogError "$Description`: $count 行 (< $MinRows, 在 $File 中)"
        return $false
    }
}

# Functions are available after dot-sourcing: . .\lib\common.ps1
