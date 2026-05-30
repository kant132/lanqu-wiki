#!/usr/bin/env bash
# recon.sh - Phase 1: 项目侦察（确定性扫描）
# 输出: JSON 格式的结构化数据，供 AI 后续分析
#
# 用法: ./recon.sh <project_dir> [output_file]
# 示例: ./recon.sh /path/to/project output/phase1-raw.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ============================================================
# 参数解析
# ============================================================
PROJECT_DIR="${1:?用法: $0 <project_dir> [output_file]}"
OUTPUT_FILE="${2:-output/phase1-raw.json}"
PROJECT_DIR="$(normalize_path "$PROJECT_DIR")"

# 确保输出目录存在
mkdir -p "$(dirname "$OUTPUT_FILE")"

log_info "开始 Phase 1 侦察: $PROJECT_DIR"

# ============================================================
# 1. 构建文件检测
# ============================================================
log_info "检测构建文件..."

BUILD_TOOL="unknown"
BUILD_FILE=""
FRAMEWORK="unknown"
FRAMEWORK_VERSION="unknown"
JAVA_VERSION="unknown"

if [ -f "$PROJECT_DIR/pom.xml" ]; then
    BUILD_TOOL="maven"
    BUILD_FILE="pom.xml"
    
    # 提取 Spring Boot 版本
    FRAMEWORK_VERSION=$(grep -oP '<version>\K[^<]+' "$PROJECT_DIR/pom.xml" 2>/dev/null | head -1 || echo "unknown")
    
    # 检测框架
    if grep -q "spring-boot-starter-web" "$PROJECT_DIR/pom.xml" 2>/dev/null; then
        FRAMEWORK="spring-boot-webmvc"
    elif grep -q "spring-boot-starter-webflux" "$PROJECT_DIR/pom.xml" 2>/dev/null; then
        FRAMEWORK="spring-boot-webflux"
    fi
    
    # 提取 Java 版本
    JAVA_VERSION=$(grep -oP '<java.version>\K[^<]+' "$PROJECT_DIR/pom.xml" 2>/dev/null || echo "unknown")
    
elif [ -f "$PROJECT_DIR/build.gradle" ] || [ -f "$PROJECT_DIR/build.gradle.kts" ]; then
    BUILD_TOOL="gradle"
    BUILD_FILE=$(ls "$PROJECT_DIR"/build.gradle* 2>/dev/null | head -1)
    
    if grep -q "spring-boot-starter-web" "$BUILD_FILE" 2>/dev/null; then
        FRAMEWORK="spring-boot-webmvc"
    elif grep -q "spring-boot-starter-webflux" "$BUILD_FILE" 2>/dev/null; then
        FRAMEWORK="spring-boot-webflux"
    fi
fi

log_ok "构建工具: $BUILD_TOOL, 框架: $FRAMEWORK"

# ============================================================
# 2. Controller 扫描
# ============================================================
log_info "扫描 Controller..."

CONTROLLER_COUNT=0
CONTROLLERS=""

while IFS= read -r file; do
    if [ -n "$file" ]; then
        CONTROLLER_COUNT=$((CONTROLLER_COUNT + 1))
        # 提取类名
        class_name=$(basename "$file" .java)
        # 提取类级 @RequestMapping
        class_path=$(grep -oP '@RequestMapping\s*\(\s*(?:value\s*=\s*)?["\x27]\K[^"\x27]+' "$file" 2>/dev/null | head -1 || echo "")
        CONTROLLERS="$CONTROLLERS{\"file\":\"$file\",\"class\":\"$class_name\",\"classPath\":\"$class_path\"},"
    fi
done < <(grep -rlE "@(Controller|RestController)" "$PROJECT_DIR" --include="*.java" 2>/dev/null)

# 移除尾部逗号
CONTROLLERS="${CONTROLLERS%,}"

log_ok "发现 $CONTROLLER_COUNT 个 Controller"

# ============================================================
# 3. Filter 扫描
# ============================================================
log_info "扫描 Filter..."

FILTER_COUNT=0
FILTERS=""

# @WebFilter
while IFS= read -r file; do
    if [ -n "$file" ]; then
        FILTER_COUNT=$((FILTER_COUNT + 1))
        class_name=$(basename "$file" .java)
        FILTERS="$FILTERS{\"file\":\"$file\",\"class\":\"$class_name\",\"type\":\"WebFilter\"},"
    fi
done < <(grep -rlE "@WebFilter" "$PROJECT_DIR" --include="*.java" 2>/dev/null)

# FilterRegistrationBean
while IFS= read -r file; do
    if [ -n "$file" ]; then
        FILTER_COUNT=$((FILTER_COUNT + 1))
        class_name=$(basename "$file" .java)
        FILTERS="$FILTERS{\"file\":\"$file\",\"class\":\"$class_name\",\"type\":\"FilterRegistrationBean\"},"
    fi
done < <(grep -rlE "FilterRegistrationBean" "$PROJECT_DIR" --include="*.java" 2>/dev/null)

FILTERS="${FILTERS%,}"
log_ok "发现 $FILTER_COUNT 个 Filter"

# ============================================================
# 4. Interceptor 扫描
# ============================================================
log_info "扫描 Interceptor..."

INTERCEPTOR_COUNT=0
INTERCEPTORS=""

while IFS= read -r file; do
    if [ -n "$file" ]; then
        INTERCEPTOR_COUNT=$((INTERCEPTOR_COUNT + 1))
        class_name=$(basename "$file" .java)
        INTERCEPTORS="$INTERCEPTORS{\"file\":\"$file\",\"class\":\"$class_name\"},"
    fi
done < <(grep -rlE "HandlerInterceptor|addInterceptors" "$PROJECT_DIR" --include="*.java" 2>/dev/null)

INTERCEPTORS="${INTERCEPTORS%,}"
log_ok "发现 $INTERCEPTOR_COUNT 个 Interceptor"

# ============================================================
# 5. SecurityFilterChain 扫描
# ============================================================
log_info "扫描 SecurityFilterChain..."

SECURITY_CHAIN_COUNT=0
SECURITY_CHAINS=""

while IFS= read -r file; do
    if [ -n "$file" ]; then
        SECURITY_CHAIN_COUNT=$((SECURITY_CHAIN_COUNT + 1))
        class_name=$(basename "$file" .java)
        
        # 检测 CSRF 是否禁用
        csrf_disabled="false"
        if grep -qE "csrf.*disable" "$file" 2>/dev/null; then
            csrf_disabled="true"
        fi
        
        # 检测密码编码器
        password_encoder="unknown"
        if grep -q "NoOpPasswordEncoder" "$file" 2>/dev/null; then
            password_encoder="NoOpPasswordEncoder"
        elif grep -q "BCryptPasswordEncoder" "$file" 2>/dev/null; then
            password_encoder="BCryptPasswordEncoder"
        fi
        
        SECURITY_CHAINS="$SECURITY_CHAINS{\"file\":\"$file\",\"class\":\"$class_name\",\"csrfDisabled\":$csrf_disabled,\"passwordEncoder\":\"$password_encoder\"},"
    fi
done < <(grep -rlE "SecurityFilterChain" "$PROJECT_DIR" --include="*.java" 2>/dev/null)

SECURITY_CHAINS="${SECURITY_CHAINS%,}"
log_ok "发现 $SECURITY_CHAIN_COUNT 个 SecurityFilterChain"

# ============================================================
# 6. 配置文件扫描
# ============================================================
log_info "扫描配置文件..."

CONFIG_FILES=""
CONFIG_COUNT=0

while IFS= read -r file; do
    if [ -n "$file" ]; then
        CONFIG_COUNT=$((CONFIG_COUNT + 1))
        CONFIG_FILES="$CONFIG_FILES\"$file\","
    fi
done < <(find_config_files "$PROJECT_DIR")

CONFIG_FILES="${CONFIG_FILES%,}"
log_ok "发现 $CONFIG_COUNT 个配置文件"

# ============================================================
# 7. 依赖扫描（关键安全依赖）
# ============================================================
log_info "扫描关键依赖..."

DEPENDENCIES=""

if [ "$BUILD_TOOL" = "maven" ] && [ -f "$PROJECT_DIR/pom.xml" ]; then
    # 提取关键依赖版本
    for dep in "xstream" "jjwt" "jose4j" "nimbus-jose" "spring-security" "thymeleaf" "commons-collections"; do
        version=$(grep -A1 "$dep" "$PROJECT_DIR/pom.xml" 2>/dev/null | grep -oP '<version>\K[^<]+' | head -1 || echo "")
        if [ -n "$version" ]; then
            DEPENDENCIES="$DEPENDENCIES{\"name\":\"$dep\",\"version\":\"$version\"},"
        fi
    done
fi

DEPENDENCIES="${DEPENDENCIES%,}"

# ============================================================
# 8. 协议特征扫描
# ============================================================
log_info "扫描业务协议特征..."

PROTOCOLS=""

# OAuth2
if grep -rqE "@EnableOAuth2Client|spring.security.oauth2.client" "$PROJECT_DIR" --include="*.java" --include="*.properties" --include="*.yml" 2>/dev/null; then
    PROTOCOLS="$PROTOCOLS\"OAUTH2-AC\","
fi

# JWT
if grep -rqE "JwtDecoder|jjwt|java-jwt|jose4j" "$PROJECT_DIR" --include="*.java" 2>/dev/null; then
    PROTOCOLS="$PROTOCOLS\"JWT-LIFECYCLE\","
fi

# 密码重置
if grep -rqE "resetPassword|forgotPassword|passwordReset" "$PROJECT_DIR" --include="*.java" 2>/dev/null; then
    PROTOCOLS="$PROTOCOLS\"PWD-RESET\","
fi

# MFA
if grep -rqE "twoFactor|mfa|totp|authenticator" "$PROJECT_DIR" --include="*.java" 2>/dev/null; then
    PROTOCOLS="$PROTOCOLS\"MFA\","
fi

# 支付
if grep -rqE "payment|charge|transfer|transaction|checkout" "$PROJECT_DIR" --include="*.java" 2>/dev/null; then
    PROTOCOLS="$PROTOCOLS\"PAYMENT\","
fi

# WebSocket
if grep -rqE "@ServerEndpoint|@MessageMapping|WebSocketHandler" "$PROJECT_DIR" --include="*.java" 2>/dev/null; then
    PROTOCOLS="$PROTOCOLS\"WEBSOCKET\","
fi

# GraphQL
if grep -rqE "@QueryMapping|@MutationMapping|@DgsQuery|graphql" "$PROJECT_DIR" --include="*.java" 2>/dev/null; then
    PROTOCOLS="$PROTOCOLS\"GRAPHQL\","
fi

# 文件上传
if grep -rqE "MultipartFile|@RequestParam.*file" "$PROJECT_DIR" --include="*.java" 2>/dev/null; then
    PROTOCOLS="$PROTOCOLS\"FILE-UPLOAD\","
fi

PROTOCOLS="${PROTOCOLS%,}"

# ============================================================
# 输出 JSON
# ============================================================
log_info "生成输出: $OUTPUT_FILE"

cat > "$OUTPUT_FILE" <<EOF
{
  "project_dir": "$PROJECT_DIR",
  "scan_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "build": {
    "tool": "$BUILD_TOOL",
    "file": "$BUILD_FILE",
    "framework": "$FRAMEWORK",
    "framework_version": "$FRAMEWORK_VERSION",
    "java_version": "$JAVA_VERSION"
  },
  "controllers": {
    "count": $CONTROLLER_COUNT,
    "items": [$CONTROLLERS]
  },
  "filters": {
    "count": $FILTER_COUNT,
    "items": [$FILTERS]
  },
  "interceptors": {
    "count": $INTERCEPTOR_COUNT,
    "items": [$INTERCEPTORS]
  },
  "security_chains": {
    "count": $SECURITY_CHAIN_COUNT,
    "items": [$SECURITY_CHAINS]
  },
  "config_files": {
    "count": $CONFIG_COUNT,
    "items": [$CONFIG_FILES]
  },
  "dependencies": [$DEPENDENCIES],
  "protocols": [$PROTOCOLS]
}
EOF

log_ok "Phase 1 侦察完成"
log_info "输出文件: $OUTPUT_FILE"
log_info "统计: $CONTROLLER_COUNT Controller, $FILTER_COUNT Filter, $INTERCEPTOR_COUNT Interceptor, $SECURITY_CHAIN_COUNT SecurityFilterChain, $CONFIG_COUNT 配置文件"
