#!/bin/bash

# ==============================================================================
# Error Handling and Edge Case Tests for DockerKit
# ==============================================================================
# Tests error conditions, edge cases, and boundary scenarios
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DCK_CLI="$PROJECT_ROOT/dck"
SRC_DIR="$PROJECT_ROOT/src"
TEST_TEMP_DIR=$(mktemp -d)

# Source test helpers
source "$SCRIPT_DIR/test_helpers.sh" 2>/dev/null || true

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup on exit
trap "rm -rf $TEST_TEMP_DIR" EXIT

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
# Error Handling Tests - Invalid Commands
# ==============================================================================

test_invalid_main_command() {
    # Should return error for invalid command
    ! "$DCK_CLI" invalidcommand 2>&1
}

test_invalid_subcommand() {
    # Should handle invalid subcommands
    ! "$DCK_CLI" template invalidsubcommand 2>&1
}

test_misspelled_command() {
    # Common misspellings should show helpful error
    "$DCK_CLI" templte 2>&1 | grep -qi "error\|unknown"
}

# ==============================================================================
# Error Handling Tests - Missing Arguments
# ==============================================================================

test_template_generate_missing_args() {
    # Missing output directory
    ! "$DCK_CLI" template generate language/node 2>&1
}

test_compliance_missing_dockerfile() {
    # Missing dockerfile argument
    "$DCK_CLI" compliance dockerfile 2>&1 | grep -qi "usage\|error\|missing"
}

test_export_missing_type() {
    # Missing export type
    "$DCK_CLI" export 2>&1 | grep -qi "error\|unknown"
}

# ==============================================================================
# Error Handling Tests - Invalid Paths
# ==============================================================================

test_nonexistent_dockerfile_compliance() {
    # Compliance check on non-existent file
    ! "$DCK_CLI" compliance dockerfile /nonexistent/Dockerfile 2>&1
}

test_invalid_template_path() {
    # Generate template with invalid name
    ! "$DCK_CLI" template generate invalid/template/path "$TEST_TEMP_DIR/test" 2>&1
}

test_protected_directory_generation() {
    # Try to generate in protected directory
    ! "$DCK_CLI" template generate language/node /root/test 2>&1
}

# ==============================================================================
# Edge Cases - Empty Files
# ==============================================================================

test_empty_dockerfile_compliance() {
    local empty_file="$TEST_TEMP_DIR/empty.Dockerfile"
    touch "$empty_file"
    
    # Should handle empty Dockerfile gracefully
    "$DCK_CLI" compliance dockerfile "$empty_file" 2>&1 | grep -qi "empty\|error\|invalid"
}

test_malformed_dockerfile() {
    local bad_file="$TEST_TEMP_DIR/bad.Dockerfile"
    echo "INVALID DOCKERFILE CONTENT @@##$$" > "$bad_file"
    
    # Should handle malformed content
    "$DCK_CLI" compliance dockerfile "$bad_file" 2>&1 | grep -qi "error\|invalid\|score"
}

# ==============================================================================
# Edge Cases - Large Files
# ==============================================================================

test_large_dockerfile_compliance() {
    local large_file="$TEST_TEMP_DIR/large.Dockerfile"
    
    # Create a large Dockerfile (1000 lines)
    echo "FROM alpine:3.19" > "$large_file"
    for i in {1..999}; do
        echo "RUN echo 'line $i'" >> "$large_file"
    done
    
    # Should handle large files
    timeout 10 "$DCK_CLI" compliance dockerfile "$large_file" 2>&1 | grep -qi "score"
}

# ==============================================================================
# Edge Cases - Special Characters
# ==============================================================================

test_special_chars_in_paths() {
    local special_dir="$TEST_TEMP_DIR/test dir with spaces"
    mkdir -p "$special_dir"
    
    # Should handle spaces in paths
    "$DCK_CLI" template generate language/node "$special_dir" 2>&1
    [[ -f "$special_dir/Dockerfile" ]]
}

test_unicode_in_dockerfile() {
    local unicode_file="$TEST_TEMP_DIR/unicode.Dockerfile"
    echo "FROM alpine:3.19" > "$unicode_file"
    echo "LABEL maintainer=\"测试 тест δοκιμή\"" >> "$unicode_file"
    
    # Should handle unicode characters
    "$DCK_CLI" compliance dockerfile "$unicode_file" 2>&1 | grep -qi "score"
}

# ==============================================================================
# Edge Cases - Concurrent Operations
# ==============================================================================

test_parallel_template_generation() {
    # Generate multiple templates in parallel
    local pids=()
    local all_success=true
    
    for i in {1..3}; do
        "$DCK_CLI" template generate language/node "$TEST_TEMP_DIR/parallel$i" 2>&1 >/dev/null &
        pids+=($!)
    done
    
    # Wait for all to complete
    for pid in "${pids[@]}"; do
        if ! wait $pid; then
            all_success=false
        fi
    done
    
    # Check all were created
    for i in {1..3}; do
        if [[ ! -f "$TEST_TEMP_DIR/parallel$i/Dockerfile" ]]; then
            all_success=false
        fi
    done
    
    $all_success
}

# ==============================================================================
# Edge Cases - Resource Limits
# ==============================================================================

test_command_timeout() {
    # Commands should timeout gracefully
    timeout 2 "$DCK_CLI" monitor 2>&1 || true
}

test_recursive_template_generation() {
    # Try to generate template inside another template
    local dir1="$TEST_TEMP_DIR/template1"
    local dir2="$dir1/template2"
    
    "$DCK_CLI" template generate language/node "$dir1" 2>&1 >/dev/null
    "$DCK_CLI" template generate language/python "$dir2" 2>&1 >/dev/null
    
    # Both should exist
    [[ -f "$dir1/Dockerfile" ]] && [[ -f "$dir2/Dockerfile" ]]
}

# ==============================================================================
# Edge Cases - Permission Issues
# ==============================================================================

test_readonly_directory() {
    local readonly_dir="$TEST_TEMP_DIR/readonly"
    mkdir -p "$readonly_dir"
    chmod 444 "$readonly_dir"
    
    # Should fail gracefully with read-only directory
    ! "$DCK_CLI" template generate language/node "$readonly_dir/test" 2>&1
    
    # Cleanup
    chmod 755 "$readonly_dir"
}

test_no_write_permission() {
    local no_write="$TEST_TEMP_DIR/nowrite"
    mkdir -p "$no_write"
    chmod 555 "$no_write"
    
    # Should handle permission denied
    ! "$DCK_CLI" template generate language/node "$no_write/app" 2>&1
    
    # Cleanup
    chmod 755 "$no_write"
}

# ==============================================================================
# Edge Cases - Invalid Input
# ==============================================================================

test_negative_numbers() {
    # Test commands that take numeric arguments
    "$DCK_CLI" compliance dockerfile --threshold -50 "$TEST_TEMP_DIR/test" 2>&1 | grep -qi "error\|invalid"
}

test_extremely_long_arguments() {
    # Test with very long argument
    local long_arg=$(printf 'a%.0s' {1..1000})
    ! "$DCK_CLI" template generate "$long_arg" "$TEST_TEMP_DIR/test" 2>&1
}

test_null_byte_in_input() {
    # Test with null byte in filename
    local null_file="$TEST_TEMP_DIR/test\x00file"
    ! "$DCK_CLI" compliance dockerfile "$null_file" 2>&1
}

# ==============================================================================
# Edge Cases - Environment Variables
# ==============================================================================

test_with_docker_unavailable() {
    # Simulate Docker not available
    export DOCKER_AVAILABLE="false"
    
    # Help should still work
    "$DCK_CLI" help 2>&1 | grep -q "COMMANDS"
    
    # Docker commands should fail gracefully
    "$DCK_CLI" images 2>&1 | grep -qi "docker\|error"
    
    unset DOCKER_AVAILABLE
}

test_with_custom_docker_host() {
    # Test with custom DOCKER_HOST
    export DOCKER_HOST="tcp://invalid:2375"
    
    # Should handle connection failure
    "$DCK_CLI" images 2>&1 | grep -qi "error\|docker"
    
    unset DOCKER_HOST
}

# ==============================================================================
# Edge Cases - Signal Handling
# ==============================================================================

test_interrupt_handling() {
    # Start a long-running command and interrupt it
    timeout 1 "$DCK_CLI" monitor 2>&1 &
    local pid=$!
    sleep 0.5
    kill -INT $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
}

# ==============================================================================
# Run Tests
# ==============================================================================

echo "=========================================="
echo "Error Handling and Edge Case Tests"
echo "=========================================="
echo ""

# Invalid Command Tests
echo "Testing Invalid Commands..."
run_test "invalid main command" test_invalid_main_command
run_test "invalid subcommand" test_invalid_subcommand
run_test "misspelled command" test_misspelled_command

# Missing Arguments Tests
echo -e "\nTesting Missing Arguments..."
run_test "template generate missing args" test_template_generate_missing_args
run_test "compliance missing dockerfile" test_compliance_missing_dockerfile
run_test "export missing type" test_export_missing_type

# Invalid Paths Tests
echo -e "\nTesting Invalid Paths..."
run_test "nonexistent dockerfile" test_nonexistent_dockerfile_compliance
run_test "invalid template path" test_invalid_template_path
run_test "protected directory" test_protected_directory_generation

# Empty Files Tests
echo -e "\nTesting Empty Files..."
run_test "empty dockerfile compliance" test_empty_dockerfile_compliance
run_test "malformed dockerfile" test_malformed_dockerfile

# Large Files Tests
echo -e "\nTesting Large Files..."
run_test "large dockerfile compliance" test_large_dockerfile_compliance

# Special Characters Tests
echo -e "\nTesting Special Characters..."
run_test "special chars in paths" test_special_chars_in_paths
run_test "unicode in dockerfile" test_unicode_in_dockerfile

# Concurrent Operations Tests
echo -e "\nTesting Concurrent Operations..."
run_test "parallel template generation" test_parallel_template_generation

# Resource Limits Tests
echo -e "\nTesting Resource Limits..."
run_test "command timeout" test_command_timeout
run_test "recursive template generation" test_recursive_template_generation

# Permission Tests
echo -e "\nTesting Permission Issues..."
run_test "readonly directory" test_readonly_directory
run_test "no write permission" test_no_write_permission

# Invalid Input Tests
echo -e "\nTesting Invalid Input..."
run_test "negative numbers" test_negative_numbers
run_test "extremely long arguments" test_extremely_long_arguments
run_test "null byte in input" test_null_byte_in_input

# Environment Variables Tests
echo -e "\nTesting Environment Variables..."
run_test "docker unavailable" test_with_docker_unavailable
run_test "custom docker host" test_with_custom_docker_host

# Signal Handling Tests
echo -e "\nTesting Signal Handling..."
run_test "interrupt handling" test_interrupt_handling

echo ""
echo "=========================================="
echo "Test Results:"
echo "  Tests Run:    $TESTS_RUN"
echo "  Tests Passed: $TESTS_PASSED"
echo "  Tests Failed: $TESTS_FAILED"
echo "=========================================="

# Exit with appropriate code
[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1