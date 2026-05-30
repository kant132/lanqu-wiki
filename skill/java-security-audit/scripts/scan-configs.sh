#!/usr/bin/env bash
# scan-configs.sh - 配置文件安全扫描（确定性扫描）
# 扫描 application.yml/properties 中的安全相关配置
#
# 用法: ./scan-configs.sh <project_dir> [output_file]
# 输出: JSON 格式的配置安全分析

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PROJECT_DIR="${1:?用法: $0 <project_dir> [output_file]}"
OUTPUT_FILE="${2:-output/configs-raw.json}"
PROJECT_DIR="$(normalize_path "$PROJECT_DIR")"

mkdir -p "$(dirname "$OUTPUT_FILE")"

log_info "开始配置文件安全扫描: $PROJECT_DIR"

# ============================================================
# 查找所有配置文件
# ============================================================
CONFIG_FILES=()
while IFS= read -r file; do
    [ -n "$file" ] && CONFIG_FILES+=("$file")
done < <(find_config_files "$PROJECT_DIR")

log_info "发现 ${#CONFIG_FILES[@]} 个配置文件"

# ============================================================
# 安全配置模式定义
# ============================================================
declare -A SECURITY_CONFIG_PATTERNS=(
    # SSL/TLS
    ["SSL_ENABLED"]="server\.ssl\.enabled"
    ["SSL_KEYSTORE"]="server\.ssl\.key-store"
    ["SSL_KEYSTORE_PASSWORD"]="server\.ssl\.key-store-password"
    ["SSL_KEY_ALIAS"]="server\.ssl\.key-alias"
    ["SSL_PROTOCOL"]="server\.ssl\.protocol"
    
    # Actuator
    ["ACTUATOR_EXPOSURE"]="management\.endpoints\.web\.exposure\.include"
    ["ACTUATOR_PORT"]="management\.server\.port"
    ["HEALTH_DETAILS"]="management\.endpoint\.health\.show-details"
    
    # Session
    ["SESSION_TIMEOUT"]="server\.servlet\.session\.timeout"
    ["SESSION_COOKIE_NAME"]="server\.servlet\.session\.cookie\.name"
    ["SESSION_COOKIE_HTTPONLY"]="server\.servlet\.session\.cookie\.http-only"
    ["SESSION_COOKIE_SECURE"]="server\.servlet\.session\.cookie\.secure"
    ["SESSION_COOKIE_SAMESITE"]="server\.servlet\.session\.cookie\.same-site"
    
    # Error handling
    ["ERROR_STACKTRACE"]="server\.error\.include-stacktrace"
    ["ERROR_MESSAGE"]="server\.error\.include-message"
    
    # CORS
    ["CORS_ORIGINS"]="cors\.allowed-origins|allowedOrigins"
    ["CORS_CREDENTIALS"]="cors\.allow-credentials|allowCredentials"
    
    # OAuth2
    ["OAUTH2_CLIENT_ID"]="spring\.security\.oauth2\.client\.registration.*\.client-id"
    ["OAUTH2_CLIENT_SECRET"]="spring\.security\.oauth2\.client\.registration.*\.client-secret"
    
    # Datasource
    ["DB_URL"]="spring\.datasource\.url"
    ["DB_USERNAME"]="spring\.datasource\.username"
    ["DB_PASSWORD"]="spring\.datasource\.password"
    
    # File upload
    ["MULTIPART_MAX_SIZE"]="spring\.servlet\.multipart\.max-file-size"
    ["MULTIPART_MAX_REQUEST"]="spring\.servlet\.multipart\.max-request-size"
    
    # Jackson
    ["JACKSON_FAIL_ON_UNKNOWN"]="spring\.jackson\.deserialization\.fail-on-unknown-properties"
    
    # Logging
    ["LOG_LEVEL_ROOT"]="logging\.level\.root"
    ["LOG_LEVEL_APP"]="logging\.level\.org\.owasp"
)

# ============================================================
# 风险评级函数
# ============================================================
assess_risk() {
    local key="$1"
    local value="$2"
    
    case "$key" in
        SSL_ENABLED)
            [ "$value" = "false" ] && echo "HIGH" || echo "LOW"
            ;;
        SSL_KEYSTORE_PASSWORD)
            echo "HIGH" # 密码不应出现在配置文件中
            ;;
        ACTUATOR_EXPOSURE)
            if echo "$value" | grep -qE "env|configprops|beans|dump|trace"; then
                echo "HIGH"
            else
                echo "LOW"
            fi
            ;;
        HEALTH_DETAILS)
            [ "$value" = "always" ] && echo "MEDIUM" || echo "LOW"
            ;;
        ERROR_STACKTRACE|ERROR_MESSAGE)
            [ "$value" = "always" ] && echo "HIGH" || echo "LOW"
            ;;
        SESSION_COOKIE_HTTPONLY|SESSION_COOKIE_SECURE)
            [ "$value" = "false" ] && echo "HIGH" || echo "LOW"
            ;;
        CORS_ORIGINS)
            [ "$value" = "*" ] && echo "HIGH" || echo "LOW"
            ;;
        OAUTH2_CLIENT_SECRET)
            echo "HIGH" # 密钥不应出现在配置文件中
            ;;
        DB_PASSWORD)
            echo "HIGH" # 密码不应出现在配置文件中
            ;;
        *)
            echo "LOW"
            ;;
    esac
}

# ============================================================
# 扫描每个配置文件
# ============================================================
CONFIG_RESULTS=""
HIGH_RISK_COUNT=0

for config_file in "${CONFIG_FILES[@]}"; do
    log_info "扫描: $config_file"
    
    FILE_RESULTS=""
    
    for config_key in "${!SECURITY_CONFIG_PATTERNS[@]}"; do
        pattern="${SECURITY_CONFIG_PATTERNS[$config_key]}"
        
        # 在配置文件中搜索
        while IFS= read -r match; do
            [ -z "$match" ] && continue
            
            line_num=$(echo "$match" | cut -d: -f1)
            raw_line=$(echo "$match" | cut -d: -f2-)
            
            # 提取键和值
            actual_key=$(echo "$raw_line" | cut -d= -f1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            actual_value=$(echo "$raw_line" | cut -d= -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            
            # 脱敏处理
            display_value="$actual_value"
            if echo "$config_key" | grep -qE "PASSWORD|SECRET"; then
                display_value="[REDACTED]"
            fi
            
            # 评估风险
            risk=$(assess_risk "$config_key" "$actual_value")
            [ "$risk" = "HIGH" ] && HIGH_RISK_COUNT=$((HIGH_RISK_COUNT + 1))
            
            FILE_RESULTS="$FILE_RESULTS{\"key\":\"$config_key\",\"actualKey\":\"$(json_escape "$actual_key")\",\"value\":\"$(json_escape "$display_value")\",\"line\":$line_num,\"risk\":\"$risk\"},"
            
        done < <(grep -nE "$pattern" "$config_file" 2>/dev/null)
    done
    
    FILE_RESULTS="${FILE_RESULTS%,}"
    
    if [ -n "$FILE_RESULTS" ]; then
        CONFIG_RESULTS="$CONFIG_RESULTS\"$(basename "$config_file")\":{\"file\":\"$config_file\",\"items\":[$FILE_RESULTS]},"
    fi
done

CONFIG_RESULTS="${CONFIG_RESULTS%,}"

# ============================================================
# 输出 JSON
# ============================================================
cat > "$OUTPUT_FILE" <<EOF
{
  "project_dir": "$PROJECT_DIR",
  "scan_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "config_files_scanned": ${#CONFIG_FILES[@]},
  "high_risk_count": $HIGH_RISK_COUNT,
  "configs": {$CONFIG_RESULTS}
}
EOF

log_ok "配置扫描完成: ${#CONFIG_FILES[@]} 个文件, $HIGH_RISK_COUNT 个高风险项"
log_info "输出文件: $OUTPUT_FILE"
