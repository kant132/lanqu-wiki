#!/usr/bin/env bash
# extract-apis.sh - API 端点提取（确定性扫描）
# 从 Controller 中提取所有端点、参数、注解
#
# 用法: ./extract-apis.sh <project_dir> [output_file]
# 输出: JSON 格式的端点清单

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PROJECT_DIR="${1:?用法: $0 <project_dir> [output_file]}"
OUTPUT_FILE="${2:-output/apis-raw.json}"
PROJECT_DIR="$(normalize_path "$PROJECT_DIR")"

mkdir -p "$(dirname "$OUTPUT_FILE")"

log_info "开始 API 端点提取: $PROJECT_DIR"

# ============================================================
# 提取所有 Controller 文件
# ============================================================
CONTROLLER_FILES=()
while IFS= read -r file; do
    [ -n "$file" ] && CONTROLLER_FILES+=("$file")
done < <(grep -rlE "@(Controller|RestController)" "$PROJECT_DIR" --include="*.java" 2>/dev/null)

log_info "发现 ${#CONTROLLER_FILES[@]} 个 Controller 文件"

# ============================================================
# 逐文件提取端点
# ============================================================
ENDPOINTS=""
ENDPOINT_COUNT=0

for file in "${CONTROLLER_FILES[@]}"; do
    # 提取类级 @RequestMapping
    class_path=$(grep -oP '@RequestMapping\s*\(\s*(?:value\s*=\s*)?["\x27]\K[^"\x27]+' "$file" 2>/dev/null | head -1 || echo "")
    class_name=$(basename "$file" .java)
    
    # 提取方法级映射
    # 匹配 @GetMapping, @PostMapping, @PutMapping, @DeleteMapping, @PatchMapping, @RequestMapping
    while IFS= read -r match; do
        [ -z "$match" ] && continue
        
        line_num=$(echo "$match" | cut -d: -f1)
        line_content=$(echo "$match" | cut -d: -f2-)
        
        # 提取 HTTP 方法
        http_method="ALL"
        if echo "$line_content" | grep -q "@GetMapping"; then
            http_method="GET"
        elif echo "$line_content" | grep -q "@PostMapping"; then
            http_method="POST"
        elif echo "$line_content" | grep -q "@PutMapping"; then
            http_method="PUT"
        elif echo "$line_content" | grep -q "@DeleteMapping"; then
            http_method="DELETE"
        elif echo "$line_content" | grep -q "@PatchMapping"; then
            http_method="PATCH"
        elif echo "$line_content" | grep -q "@RequestMapping"; then
            # 尝试提取 method 属性
            if echo "$line_content" | grep -q "RequestMethod.GET"; then
                http_method="GET"
            elif echo "$line_content" | grep -q "RequestMethod.POST"; then
                http_method="POST"
            elif echo "$line_content" | grep -q "RequestMethod.PUT"; then
                http_method="PUT"
            elif echo "$line_content" | grep -q "RequestMethod.DELETE"; then
                http_method="DELETE"
            fi
        fi
        
        # 提取路径
        method_path=$(echo "$line_content" | grep -oP '(?:value|path)\s*=\s*["\x27]\K[^"\x27]+' 2>/dev/null | head -1 || echo "")
        if [ -z "$method_path" ]; then
            method_path=$(echo "$line_content" | grep -oP '@(?:Get|Post|Put|Delete|Patch|Request)Mapping\s*\(\s*["\x27]\K[^"\x27]+' 2>/dev/null | head -1 || echo "")
        fi
        
        # 拼接完整路径
        full_path="${class_path}${method_path}"
        [ -z "$full_path" ] && full_path="/"
        
        # 提取方法名（下一行的方法签名）
        method_name=$(sed -n "$((line_num + 1)),$((line_num + 3))p" "$file" 2>/dev/null | grep -oP '(?:public|private|protected)\s+\S+\s+\K\w+' | head -1 || echo "unknown")
        
        # 提取参数（从方法签名中）
        params=""
        # 搜索后续行中的参数注解
        param_block=$(sed -n "$((line_num + 1)),$((line_num + 5))p" "$file" 2>/dev/null)
        
        # @RequestParam
        while IFS= read -r param; do
            [ -z "$param" ] && continue
            param_name=$(echo "$param" | grep -oP '@RequestParam\s*(?:\([^)]*\))?\s+\S+\s+\K\w+' 2>/dev/null || echo "")
            param_type=$(echo "$param" | grep -oP '@RequestParam\s*(?:\([^)]*\))?\s+\K\S+' 2>/dev/null || echo "")
            [ -n "$param_name" ] && params="$params{\"annotation\":\"@RequestParam\",\"name\":\"$param_name\",\"type\":\"$param_type\"},"
        done < <(echo "$param_block" | grep "@RequestParam" 2>/dev/null)
        
        # @PathVariable
        while IFS= read -r param; do
            [ -z "$param" ] && continue
            param_name=$(echo "$param" | grep -oP '@PathVariable\s*(?:\([^)]*\))?\s+\S+\s+\K\w+' 2>/dev/null || echo "")
            param_type=$(echo "$param" | grep -oP '@PathVariable\s*(?:\([^)]*\))?\s+\K\S+' 2>/dev/null || echo "")
            [ -n "$param_name" ] && params="$params{\"annotation\":\"@PathVariable\",\"name\":\"$param_name\",\"type\":\"$param_type\"},"
        done < <(echo "$param_block" | grep "@PathVariable" 2>/dev/null)
        
        # @RequestBody
        if echo "$param_block" | grep -q "@RequestBody" 2>/dev/null; then
            param_type=$(echo "$param_block" | grep -oP '@RequestBody\s+\K\S+' 2>/dev/null | head -1 || echo "")
            param_name=$(echo "$param_block" | grep -oP '@RequestBody\s+\S+\s+\K\w+' 2>/dev/null | head -1 || echo "body")
            params="$params{\"annotation\":\"@RequestBody\",\"name\":\"$param_name\",\"type\":\"$param_type\"},"
        fi
        
        # @RequestHeader
        while IFS= read -r param; do
            [ -z "$param" ] && continue
            param_name=$(echo "$param" | grep -oP '@RequestHeader\s*(?:\([^)]*\))?\s+\S+\s+\K\w+' 2>/dev/null || echo "")
            param_type=$(echo "$param" | grep -oP '@RequestHeader\s*(?:\([^)]*\))?\s+\K\S+' 2>/dev/null || echo "")
            [ -n "$param_name" ] && params="$params{\"annotation\":\"@RequestHeader\",\"name\":\"$param_name\",\"type\":\"$param_type\"},"
        done < <(echo "$param_block" | grep "@RequestHeader" 2>/dev/null)
        
        # @CookieValue
        while IFS= read -r param; do
            [ -z "$param" ] && continue
            param_name=$(echo "$param" | grep -oP '@CookieValue\s*(?:\([^)]*\))?\s+\S+\s+\K\w+' 2>/dev/null || echo "")
            param_type=$(echo "$param" | grep -oP '@CookieValue\s*(?:\([^)]*\))?\s+\K\S+' 2>/dev/null || echo "")
            [ -n "$param_name" ] && params="$params{\"annotation\":\"@CookieValue\",\"name\":\"$param_name\",\"type\":\"$param_type\"},"
        done < <(echo "$param_block" | grep "@CookieValue" 2>/dev/null)
        
        params="${params%,}"
        
        # 检查安全注解
        security=""
        context_block=$(sed -n "$((line_num > 3 ? line_num - 3 : 1)),$((line_num + 1))p" "$file" 2>/dev/null)
        if echo "$context_block" | grep -q "@PreAuthorize" 2>/dev/null; then
            security="PreAuthorize"
        elif echo "$context_block" | grep -q "@Secured" 2>/dev/null; then
            security="Secured"
        elif echo "$context_block" | grep -q "@RolesAllowed" 2>/dev/null; then
            security="RolesAllowed"
        fi
        
        ENDPOINT_COUNT=$((ENDPOINT_COUNT + 1))
        ENDPOINTS="$ENDPOINTS{\"httpMethod\":\"$http_method\",\"path\":\"$(json_escape "$full_path")\",\"methodName\":\"$method_name\",\"file\":\"$file\",\"line\":$line_num,\"security\":\"$security\",\"params\":[$params]},"
        
    done < <(grep -nE "@(Get|Post|Put|Delete|Patch|Request)Mapping" "$file" 2>/dev/null)
done

ENDPOINTS="${ENDPOINTS%,}"

# ============================================================
# 输出 JSON
# ============================================================
cat > "$OUTPUT_FILE" <<EOF
{
  "project_dir": "$PROJECT_DIR",
  "scan_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "total_endpoints": $ENDPOINT_COUNT,
  "endpoints": [$ENDPOINTS]
}
EOF

log_ok "API 提取完成: $ENDPOINT_COUNT 个端点"
log_info "输出文件: $OUTPUT_FILE"
