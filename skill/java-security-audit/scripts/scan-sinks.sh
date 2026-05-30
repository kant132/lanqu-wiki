#!/usr/bin/env bash
# scan-sinks.sh - Sink 模式扫描（确定性扫描）
# 扫描所有安全相关的 Sink 模式
#
# 用法: ./scan-sinks.sh <project_dir> [output_file]
# 输出: JSON 格式的 Sink 清单

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PROJECT_DIR="${1:?用法: $0 <project_dir> [output_file]}"
OUTPUT_FILE="${2:-output/sinks-raw.json}"
PROJECT_DIR="$(normalize_path "$PROJECT_DIR")"

mkdir -p "$(dirname "$OUTPUT_FILE")"

log_info "开始 Sink 模式扫描: $PROJECT_DIR"

SRC_DIR="$PROJECT_DIR/src/main/java"
if [ ! -d "$SRC_DIR" ]; then
    log_error "源码目录不存在: $SRC_DIR"
    exit 1
fi

# ============================================================
# Sink 模式定义
# ============================================================
declare -A SINK_PATTERNS=(
    ["SQL_EXECUTION"]="Statement\.(executeQuery|executeUpdate|execute)\s*\(|createQuery\s*\(|createNativeQuery\s*\("
    ["SQL_CONCAT"]="\+\s*\w+\s*\+\s*\""
    ["FILE_OPS"]="new\s+File\s*\(|FileInputStream\s*\(|FileOutputStream\s*\(|Paths\.get\s*\(|\.transferTo\s*\("
    ["HTTP_REQUEST"]="RestTemplate|HttpClient|WebClient|URL\.openConnection|HttpURLConnection|\.openStream\s*\("
    ["DESERIALIZE"]="\.readObject\s*\(|\.fromXML\s*\(|\.parseObject\s*\(|enableDefaultTyping|ObjectInputStream|XMLDecoder"
    ["TEMPLATE_RENDER"]="getTemplate\s*\(|th:utext|\?new\s*\(|VelocityEngine"
    ["EXPRESSION_PARSE"]="parseExpression\s*\(|SpelExpressionParser|StandardEvaluationContext|OgnlUtil|MVEL\.eval|GroovyShell|ScriptEngine"
    ["JNDI"]="InitialContext\.lookup|JndiTemplate\.lookup|ctx\.lookup"
    ["XXE"]="DocumentBuilderFactory|SAXParser|XMLReader|TransformerFactory|XMLInputFactory"
    ["CMD_EXEC"]="Runtime\.getRuntime\(\)\.exec\s*\(|ProcessBuilder|Runtime\.exec\s*\("
    ["REDIRECT"]="sendRedirect\s*\(|RedirectView|\.forward\s*\("
    ["LDAP"]="DirContext\.search|LdapTemplate|SearchControls"
)

# ============================================================
# 扫描每种 Sink 类型
# ============================================================
SINK_RESULTS=""
TOTAL_SINKS=0

for sink_type in "${!SINK_PATTERNS[@]}"; do
    pattern="${SINK_PATTERNS[$sink_type]}"
    
    MATCHES=""
    MATCH_COUNT=0
    
    while IFS= read -r match; do
        [ -z "$match" ] && continue
        file=$(echo "$match" | cut -d: -f1)
        line_num=$(echo "$match" | cut -d: -f2)
        content=$(echo "$match" | cut -d: -f3- | sed 's/^[[:space:]]*//' | head -c 200)
        
        MATCH_COUNT=$((MATCH_COUNT + 1))
        TOTAL_SINKS=$((TOTAL_SINKS + 1))
        MATCHES="$MATCHES{\"file\":\"$file\",\"line\":$line_num,\"content\":\"$(json_escape "$content")\"},"
    done < <(grep -rnE "$pattern" "$SRC_DIR" --include="*.java" 2>/dev/null)
    
    MATCHES="${MATCHES%,}"
    
    if [ "$MATCH_COUNT" -gt 0 ]; then
        SINK_RESULTS="$SINK_RESULTS\"$sink_type\":{\"count\":$MATCH_COUNT,\"matches\":[$MATCHES]},"
        log_warn "$sink_type: $MATCH_COUNT 处匹配"
    else
        log_ok "$sink_type: 无匹配"
    fi
done

SINK_RESULTS="${SINK_RESULTS%,}"

# ============================================================
# 额外扫描：硬编码密钥
# ============================================================
log_info "扫描硬编码密钥..."

HARDCODED=""
HARDCODED_COUNT=0

while IFS= read -r match; do
    [ -z "$match" ] && continue
    file=$(echo "$match" | cut -d: -f1)
    line_num=$(echo "$match" | cut -d: -f2)
    content=$(echo "$match" | cut -d: -f3- | sed 's/^[[:space:]]*//' | head -c 200)
    
    HARDCODED_COUNT=$((HARDCODED_COUNT + 1))
    HARDCODED="$HARDCODED{\"file\":\"$file\",\"line\":$line_num,\"content\":\"$(json_escape "$content")\"},"
done < <(grep -rnE '(password|secret|key|apiKey|api_key)\s*=\s*"[^"]+"' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -v "test" | grep -v "Test")

HARDCODED="${HARDCODED%,}"

# ============================================================
# 额外扫描：弱密码学
# ============================================================
log_info "扫描弱密码学..."

WEAK_CRYPTO=""
WEAK_CRYPTO_COUNT=0

declare -A CRYPTO_PATTERNS=(
    ["WEAK_HASH"]="MessageDigest\.getInstance\s*\(\s*[\"'](?:MD5|SHA-?1)[\"']"
    ["WEAK_CIPHER"]="Cipher\.getInstance\s*\(\s*[\"'](?:DES|RC4|RC2|Blowfish)"
    ["ECB_MODE"]="Cipher\.getInstance\s*\(\s*[\"'][^\"']*/ECB/"
    ["WEAK_RANDOM"]="new\s+Random\s*\("
    ["TRUST_ALL"]="X509TrustManager.*checkServerTrusted"
)

for crypto_type in "${!CRYPTO_PATTERNS[@]}"; do
    pattern="${CRYPTO_PATTERNS[$crypto_type]}"
    
    while IFS= read -r match; do
        [ -z "$match" ] && continue
        file=$(echo "$match" | cut -d: -f1)
        line_num=$(echo "$match" | cut -d: -f2)
        content=$(echo "$match" | cut -d: -f3- | sed 's/^[[:space:]]*//' | head -c 200)
        
        WEAK_CRYPTO_COUNT=$((WEAK_CRYPTO_COUNT + 1))
        WEAK_CRYPTO="$WEAK_CRYPTO{\"type\":\"$crypto_type\",\"file\":\"$file\",\"line\":$line_num,\"content\":\"$(json_escape "$content")\"},"
    done < <(grep -rnE "$pattern" "$SRC_DIR" --include="*.java" 2>/dev/null)
done

WEAK_CRYPTO="${WEAK_CRYPTO%,}"

# ============================================================
# 输出 JSON
# ============================================================
cat > "$OUTPUT_FILE" <<EOF
{
  "project_dir": "$PROJECT_DIR",
  "scan_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "total_sinks": $TOTAL_SINKS,
  "sinks": {$SINK_RESULTS},
  "hardcoded_secrets": {
    "count": $HARDCODED_COUNT,
    "matches": [$HARDCODED]
  },
  "weak_crypto": {
    "count": $WEAK_CRYPTO_COUNT,
    "matches": [$WEAK_CRYPTO]
  }
}
EOF

log_ok "Sink 扫描完成: $TOTAL_SINKS 个 Sink, $HARDCODED_COUNT 个硬编码密钥, $WEAK_CRYPTO_COUNT 个弱密码学"
log_info "输出文件: $OUTPUT_FILE"
