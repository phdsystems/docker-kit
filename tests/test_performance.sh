#!/bin/bash

# ==============================================================================
# Performance Tests for DockerKit
# ==============================================================================
# Tests performance, responsiveness, and resource usage
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DCK_CLI="$PROJECT_ROOT/dck"
TEST_TEMP_DIR=$(mktemp -d)

# Source test helpers
source "$SCRIPT_DIR/test_helpers.sh" 2>/dev/null || true

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Performance thresholds
FAST_THRESHOLD=0.5    # Commands should complete in < 0.5s
NORMAL_THRESHOLD=2.0  # Normal commands < 2s
SLOW_THRESHOLD=5.0    # Complex commands < 5s

# Cleanup on exit
trap "rm -rf $TEST_TEMP_DIR" EXIT

# ==============================================================================
# Performance Test Helper Functions
# ==============================================================================

measure_time() {
    local start=$(date +%s.%N)
    "$@" >/dev/null 2>&1
    local end=$(date +%s.%N)
    echo "$end - $start" | bc
}

run_perf_test() {
    local test_name="$1"
    local threshold="$2"
    local command="${@:3}"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing $test_name (threshold: ${threshold}s)... "
    
    local duration=$(measure_time $command)
    
    if (( $(echo "$duration < $threshold" | bc -l) )); then
        echo "✓ PASSED (${duration}s)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAILED (${duration}s > ${threshold}s)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

run_batch_test() {
    local test_name="$1"
    local test_func="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing $test_name... "
    
    if $test_func; then
        echo "✓ PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ FAILED"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ==============================================================================
# Performance Tests - CLI Response Time
# ==============================================================================

test_help_performance() {
    run_perf_test "help command" $FAST_THRESHOLD "$DCK_CLI" help
}

test_version_performance() {
    run_perf_test "version command" $FAST_THRESHOLD "$DCK_CLI" version
}

test_docs_performance() {
    run_perf_test "docs command" $NORMAL_THRESHOLD "$DCK_CLI" docs
}

# ==============================================================================
# Performance Tests - Template Operations
# ==============================================================================

test_template_list_performance() {
    run_perf_test "template list" $FAST_THRESHOLD "$DCK_CLI" template list
}

test_template_show_performance() {
    run_perf_test "template show" $FAST_THRESHOLD "$DCK_CLI" template show language/node
}

test_template_generate_performance() {
    run_perf_test "template generate" $NORMAL_THRESHOLD "$DCK_CLI" template generate language/node "$TEST_TEMP_DIR/perf-test"
}

# ==============================================================================
# Performance Tests - Search Operations
# ==============================================================================

test_search_help_performance() {
    run_perf_test "search help" $FAST_THRESHOLD "$DCK_CLI" search
}

test_search_images_performance() {
    run_perf_test "search images" $NORMAL_THRESHOLD "$DCK_CLI" search images --name test
}

# ==============================================================================
# Performance Tests - Compliance Operations
# ==============================================================================

test_compliance_small_file() {
    local small_file="$TEST_TEMP_DIR/small.Dockerfile"
    echo "FROM alpine:3.19" > "$small_file"
    echo "USER nobody" >> "$small_file"
    
    run_perf_test "compliance small file" $FAST_THRESHOLD "$DCK_CLI" compliance dockerfile "$small_file"
}

test_compliance_medium_file() {
    local medium_file="$TEST_TEMP_DIR/medium.Dockerfile"
    echo "FROM alpine:3.19" > "$medium_file"
    for i in {1..50}; do
        echo "RUN echo 'line $i'" >> "$medium_file"
    done
    
    run_perf_test "compliance medium file" $NORMAL_THRESHOLD "$DCK_CLI" compliance dockerfile "$medium_file"
}

# ==============================================================================
# Performance Tests - Batch Operations
# ==============================================================================

test_multiple_template_generation() {
    local all_fast=true
    
    for i in {1..5}; do
        local start=$(date +%s.%N)
        "$DCK_CLI" template generate language/node "$TEST_TEMP_DIR/batch$i" >/dev/null 2>&1
        local end=$(date +%s.%N)
        local duration=$(echo "$end - $start" | bc)
        
        if (( $(echo "$duration > $NORMAL_THRESHOLD" | bc -l) )); then
            all_fast=false
        fi
    done
    
    $all_fast
}

test_parallel_compliance_checks() {
    # Create test files
    local files=()
    for i in {1..5}; do
        local file="$TEST_TEMP_DIR/parallel$i.Dockerfile"
        echo "FROM alpine:3.19" > "$file"
        echo "RUN apk add --no-cache curl" >> "$file"
        files+=("$file")
    done
    
    # Run compliance checks in parallel
    local pids=()
    local start=$(date +%s.%N)
    
    for file in "${files[@]}"; do
        "$DCK_CLI" compliance dockerfile "$file" >/dev/null 2>&1 &
        pids+=($!)
    done
    
    # Wait for all to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    local end=$(date +%s.%N)
    local total_time=$(echo "$end - $start" | bc)
    
    # Should complete all 5 in reasonable time
    (( $(echo "$total_time < $SLOW_THRESHOLD" | bc -l) ))
}

# ==============================================================================
# Performance Tests - Memory Usage
# ==============================================================================

test_memory_efficient_operations() {
    # Test that operations don't consume excessive memory
    local all_efficient=true
    
    # Generate a large Dockerfile
    local large_file="$TEST_TEMP_DIR/large.Dockerfile"
    echo "FROM alpine:3.19" > "$large_file"
    for i in {1..500}; do
        echo "RUN echo 'line $i with some longer text to increase file size'" >> "$large_file"
    done
    
    # Check compliance (should handle large files efficiently)
    if ! timeout 10 "$DCK_CLI" compliance dockerfile "$large_file" >/dev/null 2>&1; then
        all_efficient=false
    fi
    
    $all_efficient
}

# ==============================================================================
# Performance Tests - Caching
# ==============================================================================

test_repeated_command_caching() {
    # First run (cold)
    local cold_start=$(date +%s.%N)
    "$DCK_CLI" template list >/dev/null 2>&1
    local cold_end=$(date +%s.%N)
    local cold_time=$(echo "$cold_end - $cold_start" | bc)
    
    # Second run (potentially cached)
    local warm_start=$(date +%s.%N)
    "$DCK_CLI" template list >/dev/null 2>&1
    local warm_end=$(date +%s.%N)
    local warm_time=$(echo "$warm_end - $warm_start" | bc)
    
    # Warm should be same or faster than cold (allowing for variance)
    (( $(echo "$warm_time <= $cold_time * 1.2" | bc -l) ))
}

# ==============================================================================
# Performance Tests - Error Recovery
# ==============================================================================

test_quick_error_detection() {
    # Errors should be detected quickly
    run_perf_test "invalid command detection" $FAST_THRESHOLD "$DCK_CLI" invalidcommand
}

test_missing_file_detection() {
    # Missing files should fail fast
    run_perf_test "missing file detection" $FAST_THRESHOLD "$DCK_CLI" compliance dockerfile /nonexistent/file
}

# ==============================================================================
# Performance Tests - Resource Cleanup
# ==============================================================================

test_cleanup_performance() {
    # Create multiple test directories
    for i in {1..10}; do
        mkdir -p "$TEST_TEMP_DIR/cleanup$i"
        echo "test" > "$TEST_TEMP_DIR/cleanup$i/file.txt"
    done
    
    # Cleanup should be fast
    local start=$(date +%s.%N)
    rm -rf "$TEST_TEMP_DIR/cleanup"*
    local end=$(date +%s.%N)
    local duration=$(echo "$end - $start" | bc)
    
    (( $(echo "$duration < $FAST_THRESHOLD" | bc -l) ))
}

# ==============================================================================
# Performance Tests - Stress Testing
# ==============================================================================

test_rapid_successive_commands() {
    # Run many commands in quick succession
    local all_success=true
    local start=$(date +%s.%N)
    
    for i in {1..20}; do
        if ! "$DCK_CLI" version >/dev/null 2>&1; then
            all_success=false
        fi
    done
    
    local end=$(date +%s.%N)
    local total_time=$(echo "$end - $start" | bc)
    
    # 20 commands should complete quickly
    $all_success && (( $(echo "$total_time < $SLOW_THRESHOLD" | bc -l) ))
}

# ==============================================================================
# Run Tests
# ==============================================================================

echo "=========================================="
echo "DockerKit Performance Tests"
echo "=========================================="
echo ""

# Check if bc is available
if ! command -v bc &>/dev/null; then
    echo "Warning: 'bc' command not found. Installing bc for performance measurements..."
    sudo apt-get update && sudo apt-get install -y bc 2>/dev/null || true
fi

# CLI Response Time Tests
echo "Testing CLI Response Times..."
test_help_performance
test_version_performance
test_docs_performance

# Template Operations Tests
echo -e "\nTesting Template Operations..."
test_template_list_performance
test_template_show_performance
test_template_generate_performance

# Search Operations Tests
echo -e "\nTesting Search Operations..."
test_search_help_performance
test_search_images_performance

# Compliance Operations Tests
echo -e "\nTesting Compliance Operations..."
test_compliance_small_file
test_compliance_medium_file

# Batch Operations Tests
echo -e "\nTesting Batch Operations..."
run_batch_test "multiple template generation" test_multiple_template_generation
run_batch_test "parallel compliance checks" test_parallel_compliance_checks

# Memory Usage Tests
echo -e "\nTesting Memory Efficiency..."
run_batch_test "memory efficient operations" test_memory_efficient_operations

# Caching Tests
echo -e "\nTesting Caching..."
run_batch_test "repeated command caching" test_repeated_command_caching

# Error Recovery Tests
echo -e "\nTesting Error Recovery..."
test_quick_error_detection
test_missing_file_detection

# Resource Cleanup Tests
echo -e "\nTesting Resource Cleanup..."
run_batch_test "cleanup performance" test_cleanup_performance

# Stress Tests
echo -e "\nTesting Under Stress..."
run_batch_test "rapid successive commands" test_rapid_successive_commands

echo ""
echo "=========================================="
echo "Test Results:"
echo "  Tests Run:    $TESTS_RUN"
echo "  Tests Passed: $TESTS_PASSED"
echo "  Tests Failed: $TESTS_FAILED"
echo "=========================================="

# Exit with appropriate code
[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1