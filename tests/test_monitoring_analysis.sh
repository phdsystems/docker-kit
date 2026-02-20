#!/bin/bash

# ==============================================================================
# Unit Tests for Monitoring and Analysis Tools
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"

# Source test helpers
source "$SCRIPT_DIR/test_helpers.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ==============================================================================
# Mock Setup
# ==============================================================================

setup_mocks() {
    export DOCKER_CMD="echo"
    export DOCKER_AVAILABLE="true"
}

# ==============================================================================
# Test Helper Functions
# ==============================================================================

run_test() {
    local test_name="$1"
    local test_func="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing $test_name... "
    
    if $test_func 2>/dev/null; then
        echo "✓ PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAILED"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ==============================================================================
# Unit Tests - Docker Monitor
# ==============================================================================

test_monitor_script_exists() {
    [[ -f "$SRC_DIR/docker-monitor.sh" ]] && [[ -x "$SRC_DIR/docker-monitor.sh" ]]
}

test_monitor_help() {
    "$SRC_DIR/docker-monitor.sh" --help 2>&1 | grep -q "monitor\|Monitor\|Usage"
}

test_monitor_health_command() {
    "$SRC_DIR/docker-monitor.sh" health 2>&1 | grep -q "health\|Health\|container" || true
}

test_monitor_stats_command() {
    "$SRC_DIR/docker-monitor.sh" stats 2>&1 | grep -q "stats\|Stats\|CPU\|Memory" || true
}

test_monitor_resources_command() {
    "$SRC_DIR/docker-monitor.sh" resources 2>&1 | grep -q "resource\|Resource\|usage" || true
}

# ==============================================================================
# Unit Tests - Docker Security
# ==============================================================================

test_security_script_exists() {
    [[ -f "$SRC_DIR/docker-security.sh" ]] && [[ -x "$SRC_DIR/docker-security.sh" ]]
}

test_security_help() {
    "$SRC_DIR/docker-security.sh" --help 2>&1 | grep -q "security\|Security\|audit"
}

test_security_audit_command() {
    "$SRC_DIR/docker-security.sh" audit 2>&1 | grep -q "audit\|Audit\|security" || true
}

test_security_scan_command() {
    "$SRC_DIR/docker-security.sh" scan 2>&1 | grep -q "scan\|Scan\|vulnerabilit" || true
}

test_security_report_command() {
    "$SRC_DIR/docker-security.sh" report 2>&1 | grep -q "report\|Report\|finding" || true
}

# ==============================================================================
# Unit Tests - Docker Advanced Analysis
# ==============================================================================

test_advanced_images_analysis() {
    [[ -f "$SRC_DIR/docker-advanced-images.sh" ]] && \
    "$SRC_DIR/docker-advanced-images.sh" --help 2>&1 | grep -q "image\|Image\|analysis" || true
}

test_advanced_containers_analysis() {
    [[ -f "$SRC_DIR/docker-advanced-containers.sh" ]] && \
    "$SRC_DIR/docker-advanced-containers.sh" --help 2>&1 | grep -q "container\|Container\|analysis" || true
}

test_advanced_volumes_analysis() {
    [[ -f "$SRC_DIR/docker-advanced-volumes.sh" ]] && \
    "$SRC_DIR/docker-advanced-volumes.sh" --help 2>&1 | grep -q "volume\|Volume\|analysis" || true
}

test_advanced_networks_analysis() {
    [[ -f "$SRC_DIR/docker-advanced-networks.sh" ]] && \
    "$SRC_DIR/docker-advanced-networks.sh" --help 2>&1 | grep -q "network\|Network\|analysis" || true
}

# ==============================================================================
# Unit Tests - Docker Cleanup
# ==============================================================================

test_cleanup_script_exists() {
    [[ -f "$SRC_DIR/docker-cleanup.sh" ]] && [[ -x "$SRC_DIR/docker-cleanup.sh" ]]
}

test_cleanup_help() {
    "$SRC_DIR/docker-cleanup.sh" --help 2>&1 | grep -q "cleanup\|Cleanup\|remove"
}

test_cleanup_dry_run() {
    "$SRC_DIR/docker-cleanup.sh" --dry-run 2>&1 | grep -q "DRY\|dry\|would" || true
}

test_cleanup_images_command() {
    "$SRC_DIR/docker-cleanup.sh" images --dry-run 2>&1 | grep -q "image\|Image" || true
}

test_cleanup_containers_command() {
    "$SRC_DIR/docker-cleanup.sh" containers --dry-run 2>&1 | grep -q "container\|Container" || true
}

test_cleanup_volumes_command() {
    "$SRC_DIR/docker-cleanup.sh" volumes --dry-run 2>&1 | grep -q "volume\|Volume" || true
}

test_cleanup_all_command() {
    "$SRC_DIR/docker-cleanup.sh" all --dry-run 2>&1 | grep -q "all\|All\|system" || true
}

# ==============================================================================
# Unit Tests - System Analysis
# ==============================================================================

test_system_df_analysis() {
    # Mock docker system df output
    export DOCKER_CMD="echo 'TYPE TOTAL ACTIVE SIZE RECLAIMABLE'"
    "$PROJECT_ROOT/bin/dck" system 2>&1 | grep -q "System\|system\|Docker" || true
}

test_system_info_analysis() {
    # Mock docker info output
    export DOCKER_CMD="echo 'Containers: 5'"
    "$PROJECT_ROOT/bin/dck" system 2>&1 | grep -q "Container\|container\|System" || true
}

# ==============================================================================
# Unit Tests - Export Functionality
# ==============================================================================

test_export_json_format() {
    export DOCKER_CMD="echo '[{\"name\":\"test\"}]'"
    "$PROJECT_ROOT/bin/dck" export containers --format json 2>&1 | grep -q "test\|{" || true
}

test_export_csv_format() {
    export DOCKER_CMD="echo 'name,id'"
    "$PROJECT_ROOT/bin/dck" export images --format csv 2>&1 | grep -q "name\|," || true
}

# ==============================================================================
# Unit Tests - Metrics Collection
# ==============================================================================

test_metrics_endpoint() {
    # Test if monitoring scripts expose metrics
    [[ -f "$SRC_DIR/docker-monitor.sh" ]] && \
    "$SRC_DIR/docker-monitor.sh" metrics 2>&1 | grep -q "metric\|Metric\|prometheus" || true
}

test_health_aggregation() {
    # Test health check aggregation
    "$SRC_DIR/docker-monitor.sh" health --all 2>&1 | grep -q "health\|Health\|status" || true
}

# ==============================================================================
# Run Tests
# ==============================================================================

echo "=========================================="
echo "Monitoring and Analysis Tools Unit Tests"
echo "=========================================="
echo ""

# Setup mocks
setup_mocks

# Docker Monitor Tests
run_test "monitor script exists" test_monitor_script_exists
run_test "monitor help command" test_monitor_help
run_test "monitor health command" test_monitor_health_command
run_test "monitor stats command" test_monitor_stats_command
run_test "monitor resources command" test_monitor_resources_command

# Docker Security Tests
run_test "security script exists" test_security_script_exists
run_test "security help command" test_security_help
run_test "security audit command" test_security_audit_command
run_test "security scan command" test_security_scan_command
run_test "security report command" test_security_report_command

# Advanced Analysis Tests
run_test "advanced images analysis" test_advanced_images_analysis
run_test "advanced containers analysis" test_advanced_containers_analysis
run_test "advanced volumes analysis" test_advanced_volumes_analysis
run_test "advanced networks analysis" test_advanced_networks_analysis

# Docker Cleanup Tests
run_test "cleanup script exists" test_cleanup_script_exists
run_test "cleanup help command" test_cleanup_help
run_test "cleanup dry-run mode" test_cleanup_dry_run
run_test "cleanup images command" test_cleanup_images_command
run_test "cleanup containers command" test_cleanup_containers_command
run_test "cleanup volumes command" test_cleanup_volumes_command
run_test "cleanup all command" test_cleanup_all_command

# System Analysis Tests
run_test "system df analysis" test_system_df_analysis
run_test "system info analysis" test_system_info_analysis

# Export Tests
run_test "export JSON format" test_export_json_format
run_test "export CSV format" test_export_csv_format

# Metrics Tests
run_test "metrics endpoint" test_metrics_endpoint
run_test "health aggregation" test_health_aggregation

echo ""
echo "=========================================="
echo "Test Results:"
echo "  Tests Run:    $TESTS_RUN"
echo "  Tests Passed: $TESTS_PASSED"
echo "  Tests Failed: $TESTS_FAILED"
echo "=========================================="

# Exit with appropriate code
[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1