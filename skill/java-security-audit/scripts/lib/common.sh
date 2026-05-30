#!/usr/bin/env bash
# common.sh - 公共函数库
# 所有审计脚本共享的工具函数

set -euo pipefail

# ============================================================
# 颜色输出
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ============================================================
# 路径处理
# ============================================================

# 规范化项目路径（支持 Windows 和 Linux）
normalize_path() {
    local path="$1"
    # 将 Windows 反斜杠转为正斜杠
    path="${path//\\//}"
    # 移除尾部斜杠
    path="${path%/}"
    echo "$path"
}

# 获取脚本所在目录
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [ -L "$source" ]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ "$source" != /* ]] && source="$dir/$source"
    done
    echo "$(cd -P "$(dirname "$source")" && pwd)"
}

# ============================================================
# 文件扫描
# ============================================================

# 查找所有 Java 源文件
find_java_files() {
    local project_dir="$1"
    local scope="${2:-main}" # main, test, all
    
    case "$scope" in
        main)
            find "$project_dir" -path "*/src/main/java/*.java" -type f 2>/dev/null
            ;;
        test)
            find "$project_dir" -path "*/src/test/java/*.java" -type f 2>/dev/null
            ;;
        all)
            find "$project_dir" -name "*.java" -type f 2>/dev/null
            ;;
    esac
}

# 查找配置文件
find_config_files() {
    local project_dir="$1"
    find "$project_dir" -path "*/src/main/resources/*" \
        \( -name "application*.yml" -o -name "application*.yaml" -o -name "application*.properties" \
           -o -name "bootstrap*.yml" -o -name "bootstrap*.properties" \) \
        -type f 2>/dev/null
}

# ============================================================
# 模式匹配
# ============================================================

# 在文件中搜索模式，输出 file:line:content
grep_pattern() {
    local pattern="$1"
    local file="$2"
    grep -nE "$pattern" "$file" 2>/dev/null | while IFS=: read -r line_num content; do
        echo "$file:$line_num:$(echo "$content" | sed 's/^[[:space:]]*//')"
    done
}

# 在目录中递归搜索模式
grep_pattern_recursive() {
    local pattern="$1"
    local dir="$2"
    local file_pattern="${3:-*.java}"
    grep -rnE "$pattern" "$dir" --include="$file_pattern" 2>/dev/null | while IFS=: read -r file line_num content; do
        echo "$file:$line_num:$(echo "$content" | sed 's/^[[:space:]]*//')"
    done
}

# ============================================================
# JSON 输出
# ============================================================

# 转义字符串用于 JSON
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# 输出 JSON 数组元素
json_array_start() {
    echo "["
}

json_array_end() {
    echo "]"
}

json_object() {
    local first=true
    echo -n "{"
    for kv in "$@"; do
        local key="${kv%%=*}"
        local value="${kv#*=}"
        if [ "$first" = true ]; then
            first=false
        else
            echo -n ","
        fi
        echo -n "\"$key\":\"$(json_escape "$value")\""
    done
    echo -n "}"
}

# ============================================================
# 计数与统计
# ============================================================

# 统计文件中的匹配行数
count_matches() {
    local pattern="$1"
    local file="$2"
    grep -cE "$pattern" "$file" 2>/dev/null || echo "0"
}

# 统计目录中的匹配文件数
count_matching_files() {
    local pattern="$1"
    local dir="$2"
    local file_pattern="${3:-*.java}"
    grep -rlE "$pattern" "$dir" --include="$file_pattern" 2>/dev/null | wc -l | tr -d ' '
}

# ============================================================
# 验证函数
# ============================================================

# 检查必填文件是否存在
check_required_file() {
    local file="$1"
    local description="$2"
    if [ -f "$file" ]; then
        log_ok "$description: $file"
        return 0
    else
        log_error "$description 缺失: $file"
        return 1
    fi
}

# 检查文件是否包含必填段落
check_required_section() {
    local file="$1"
    local section="$2"
    if grep -q "$section" "$file" 2>/dev/null; then
        log_ok "包含段落: $section"
        return 0
    else
        log_error "缺失段落: $section (在 $file 中)"
        return 1
    fi
}

# 检查表格行数是否 >= 预期
check_table_rows() {
    local file="$1"
    local table_header="$2"
    local min_rows="$3"
    local description="$4"
    
    # 查找表格后的数据行数（排除表头和分隔行）
    local count=$(awk "/$table_header/{found=1; next} found && /^\|/{count++} found && !/^\|/{exit} END{print count}" "$file" 2>/dev/null || echo "0")
    
    if [ "$count" -ge "$min_rows" ]; then
        log_ok "$description: $count 行 (>= $min_rows)"
        return 0
    else
        log_error "$description: $count 行 (< $min_rows)"
        return 1
    fi
}
