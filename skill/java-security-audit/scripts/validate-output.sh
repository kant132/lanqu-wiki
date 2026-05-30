#!/usr/bin/env bash
# validate-output.sh - 输出完整性验证（确定性验证）
# 验证审计报告是否包含所有必填内容
#
# 用法: ./validate-output.sh <output_dir> [phase]
#   phase: all (默认), phase1, phase2, phase3, phase4, final
# 退出码: 0=全部通过, 1=存在缺失

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

OUTPUT_DIR="${1:?用法: $0 <output_dir> [phase]}"
PHASE="${2:-all}"

ERRORS=0
WARNINGS=0

log_info "开始输出验证: $OUTPUT_DIR (阶段: $PHASE)"

# ============================================================
# 验证函数
# ============================================================

check_file_exists() {
    local file="$1"
    local desc="$2"
    if [ -f "$OUTPUT_DIR/$file" ]; then
        log_ok "$desc: $file"
    else
        log_error "$desc 缺失: $file"
        ERRORS=$((ERRORS + 1))
    fi
}

check_section_exists() {
    local file="$1"
    local section="$2"
    local desc="$3"
    if [ ! -f "$OUTPUT_DIR/$file" ]; then
        log_error "文件不存在: $file"
        ERRORS=$((ERRORS + 1))
        return
    fi
    if grep -q "$section" "$OUTPUT_DIR/$file" 2>/dev/null; then
        log_ok "$desc"
    else
        log_error "缺失段落 '$section' (在 $file 中)"
        ERRORS=$((ERRORS + 1))
    fi
}

check_no_ellipsis() {
    local file="$1"
    local desc="$2"
    if [ ! -f "$OUTPUT_DIR/$file" ]; then
        return
    fi
    local count=$(grep -cE '\.\.\.|以上为摘要|仅列出|省略' "$OUTPUT_DIR/$file" 2>/dev/null || echo "0")
    if [ "$count" -gt 0 ]; then
        log_error "$desc: 发现 $count 处省略语 (在 $file 中)"
        ERRORS=$((ERRORS + 1))
    else
        log_ok "$desc: 无省略语"
    fi
}

check_table_min_rows() {
    local file="$1"
    local header_pattern="$2"
    local min_rows="$3"
    local desc="$4"
    
    if [ ! -f "$OUTPUT_DIR/$file" ]; then
        log_error "文件不存在: $file"
        ERRORS=$((ERRORS + 1))
        return
    fi
    
    # 统计表格数据行（排除表头和分隔行）
    local count=$(awk "/$header_pattern/{found=1; next} found && /^\|[^-]/{count++} found && /^[^|]/{found=0} END{print count+0}" "$OUTPUT_DIR/$file" 2>/dev/null)
    
    if [ "$count" -ge "$min_rows" ]; then
        log_ok "$desc: $count 行 (>= $min_rows)"
    else
        log_error "$desc: $count 行 (< $min_rows, 在 $file 中)"
        ERRORS=$((ERRORS + 1))
    fi
}

check_contains_pattern() {
    local file="$1"
    local pattern="$2"
    local desc="$3"
    if [ ! -f "$OUTPUT_DIR/$file" ]; then
        log_error "文件不存在: $file"
        ERRORS=$((ERRORS + 1))
        return
    fi
    if grep -qE "$pattern" "$OUTPUT_DIR/$file" 2>/dev/null; then
        log_ok "$desc"
    else
        log_error "$desc (在 $file 中未找到)"
        ERRORS=$((ERRORS + 1))
    fi
}

check_chinese_output() {
    local file="$1"
    local desc="$2"
    if [ ! -f "$OUTPUT_DIR/$file" ]; then
        return
    fi
    # 检查是否包含中文字符（标题和描述应为中文）
    local chinese_count=$(grep -cP '[\x{4e00}-\x{9fff}]' "$OUTPUT_DIR/$file" 2>/dev/null || echo "0")
    local total_lines=$(wc -l < "$OUTPUT_DIR/$file" 2>/dev/null || echo "1")
    local ratio=$((chinese_count * 100 / total_lines))
    
    if [ "$ratio" -ge 10 ]; then
        log_ok "$desc: 中文占比 ${ratio}%"
    else
        log_warn "$desc: 中文占比仅 ${ratio}%，可能需要翻译"
        WARNINGS=$((WARNINGS + 1))
    fi
}

# ============================================================
# Phase 1 验证
# ============================================================
validate_phase1() {
    log_info "=== Phase 1 验证 ==="
    
    check_file_exists "phase1-recon.md" "Phase 1 报告"
    check_section_exists "phase1-recon.md" "资产台账" "资产台账段落"
    check_section_exists "phase1-recon.md" "配置文件分析" "配置文件分析段落"
    check_section_exists "phase1-recon.md" "断言评估" "断言评估段落"
    check_section_exists "phase1-recon.md" "C1" "C1 断言"
    check_section_exists "phase1-recon.md" "C6" "C6 断言（配置文件）"
    check_section_exists "phase1-recon.md" "C8" "C8 断言（协议识别）"
    check_no_ellipsis "phase1-recon.md" "Phase 1 无省略语"
    check_chinese_output "phase1-recon.md" "Phase 1 中文输出"
}

# ============================================================
# Phase 2 验证
# ============================================================
validate_phase2() {
    log_info "=== Phase 2 验证 ==="
    
    check_file_exists "phase2-filter-audit.md" "Phase 2 报告"
    check_section_exists "phase2-filter-audit.md" "执行链" "Filter 执行链段落"
    check_section_exists "phase2-filter-audit.md" "可达性" "可达性评估段落"
    check_section_exists "phase2-filter-audit.md" "SC-DEEP" "配置深度审计段落"
    check_no_ellipsis "phase2-filter-audit.md" "Phase 2 无省略语"
    check_chinese_output "phase2-filter-audit.md" "Phase 2 中文输出"
}

# ============================================================
# Phase 3 验证
# ============================================================
validate_phase3() {
    log_info "=== Phase 3 验证 ==="
    
    check_file_exists "phase3-interceptor-audit.md" "Phase 3 报告"
    check_section_exists "phase3-interceptor-audit.md" "执行链" "Interceptor 执行链段落"
    check_section_exists "phase3-interceptor-audit.md" "可达性" "可达性评估段落"
    check_section_exists "phase3-interceptor-audit.md" "IC-DEEP" "配置深度审计段落"
    check_no_ellipsis "phase3-interceptor-audit.md" "Phase 3 无省略语"
    check_chinese_output "phase3-interceptor-audit.md" "Phase 3 中文输出"
}

# ============================================================
# Phase 4 验证
# ============================================================
validate_phase4() {
    log_info "=== Phase 4 验证 ==="
    
    check_file_exists "phase4-api-audit.md" "Phase 4 报告"
    check_section_exists "phase4-api-audit.md" "威胁建模摘要" "威胁建模摘要"
    check_section_exists "phase4-api-audit.md" "路由映射" "路由映射表"
    check_section_exists "phase4-api-audit.md" "框架防护分析" "框架防护分析"
    check_section_exists "phase4-api-audit.md" "参数消毒分析" "参数消毒分析"
    check_section_exists "phase4-api-audit.md" "正向链路" "正向链路"
    check_section_exists "phase4-api-audit.md" "完整 Sink 路径" "完整 Sink 路径"
    check_section_exists "phase4-api-audit.md" "整体置信度" "整体置信度"
    check_section_exists "phase4-api-audit.md" "PoC" "PoC"
    check_section_exists "phase4-api-audit.md" "验证标准" "验证标准"
    check_section_exists "phase4-api-audit.md" "Fuzzing" "Fuzzing 字典"
    check_section_exists "phase4-api-audit.md" "协议审计" "协议审计结果"
    check_section_exists "phase4-api-audit.md" "跨请求" "跨请求污点链路"
    check_section_exists "phase4-api-audit.md" "业务逻辑" "业务逻辑风险"
    
    # 检查 curl 命令格式
    check_contains_pattern "phase4-api-audit.md" "curl" "PoC 包含 curl 命令"
    
    # 检查确定性标注
    check_contains_pattern "phase4-api-audit.md" "DETERMINISTIC\|HEURISTIC\|SUBJECTIVE" "确定性标注"
    
    # 检查置信度标注
    check_contains_pattern "phase4-api-audit.md" "CONFIRMED\|LIKELY\|POSSIBLE" "置信度标注"
    
    check_no_ellipsis "phase4-api-audit.md" "Phase 4 无省略语"
    check_chinese_output "phase4-api-audit.md" "Phase 4 中文输出"
}

# ============================================================
# 最终报告验证
# ============================================================
validate_final() {
    log_info "=== 最终报告验证 ==="
    
    check_file_exists "final-audit-report.md" "最终报告"
    check_section_exists "final-audit-report.md" "执行摘要" "执行摘要"
    check_section_exists "final-audit-report.md" "框架分析结果" "框架分析结果"
    check_section_exists "final-audit-report.md" "API 分析结果" "API 分析结果"
    check_section_exists "final-audit-report.md" "综合安全分析" "综合安全分析"
    check_section_exists "final-audit-report.md" "修复建议" "修复建议"
    check_section_exists "final-audit-report.md" "资产守恒验证" "资产守恒验证"
    check_section_exists "final-audit-report.md" "PASS\|FAIL" "守恒验证结果"
    
    check_file_exists "comprehensive-security-analysis.md" "综合分析报告"
    check_file_exists "threat-model.md" "威胁建模报告"
    
    check_no_ellipsis "final-audit-report.md" "最终报告无省略语"
    check_chinese_output "final-audit-report.md" "最终报告中文输出"
}

# ============================================================
# 执行验证
# ============================================================
case "$PHASE" in
    phase1)  validate_phase1 ;;
    phase2)  validate_phase2 ;;
    phase3)  validate_phase3 ;;
    phase4)  validate_phase4 ;;
    final)   validate_final ;;
    all)
        validate_phase1
        validate_phase2
        validate_phase3
        validate_phase4
        validate_final
        ;;
    *)
        log_error "未知阶段: $PHASE (可选: phase1, phase2, phase3, phase4, final, all)"
        exit 1
        ;;
esac

# ============================================================
# 汇总
# ============================================================
echo ""
echo "============================================"
if [ "$ERRORS" -eq 0 ]; then
    log_ok "验证通过! 0 个错误, $WARNINGS 个警告"
    exit 0
else
    log_error "验证失败! $ERRORS 个错误, $WARNINGS 个警告"
    exit 1
fi
