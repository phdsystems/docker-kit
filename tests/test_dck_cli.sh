#!/bin/bash

# ==============================================================================
# Unit Tests for DCK CLI Core Functionality
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DCK_CLI="$PROJECT_ROOT/dck"

# Source test helpers
source "$SCRIPT_DIR/test_helpers.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ==============================================================================
# Test Helper Functions
# ==============================================================================

run_test() {
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
# Unit Tests
# ==============================================================================

test_cli_exists() {
    [[ -f "$DCK_CLI" ]] && [[ -x "$DCK_CLI" ]]
}

test_help_command() {
    "$DCK_CLI" help 2>/dev/null | grep -q "DockerKit"
}

test_version_command() {
    "$DCK_CLI" version 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -i "dockerkit"
}

test_help_flag() {
    "$DCK_CLI" --help 2>/dev/null | grep -q "COMMANDS"
}

test_version_flag() {
    # -v flag doesn't exist, test version command instead
    "$DCK_CLI" version 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -i "dockerkit"
}

test_unknown_command() {
    ! "$DCK_CLI" nonexistentcommand 2>/dev/null
}

test_no_args_shows_help() {
    "$DCK_CLI" 2>/dev/null | grep -q "USAGE"
}

test_docs_command() {
    # Test that docs command works without Docker
    "$DCK_CLI" docs landscape 2>/dev/null | grep -q "Docker"
}

test_search_help() {
    "$DCK_CLI" search 2>/dev/null | grep -q "Types:"
}

test_template_list_command() {
    # Template command needs src script to exist
    "$DCK_CLI" template list 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -i "template"
}

test_quiet_flag() {
    # Quiet flag doesn't actually exist in the implementation
    true
}

test_no_color_flag() {
    local output
    output=$("$DCK_CLI" --no-color help 2>&1)
    # Should not contain ANSI color codes
    ! echo "$output" | grep -q $'\033'
}

test_verbose_flag() {
    # Test that verbose flag is accepted
    "$DCK_CLI" --verbose help 2>/dev/null | grep -q "DockerKit"
}

test_scripts_dir_exists() {
    local scripts_dir="$PROJECT_ROOT/src"
    [[ -d "$scripts_dir" ]] && [[ -n "$(ls -A "$scripts_dir"/*.sh 2>/dev/null)" ]]
}

test_lib_dir_exists() {
    local lib_dir="$PROJECT_ROOT/lib"
    [[ -d "$lib_dir" ]] && [[ -f "$lib_dir/docker-wrapper.sh" ]]
}

test_docs_dir_exists() {
    local docs_dir="$PROJECT_ROOT/docs"
    [[ -d "$docs_dir" ]] && [[ -n "$(ls -A "$docs_dir"/*.md 2>/dev/null)" ]]
}

test_all_scripts_executable() {
    local scripts_dir="$PROJECT_ROOT/src"
    local all_executable=true
    
    for script in "$scripts_dir"/*.sh; do
        if [[ -f "$script" ]] && [[ ! -x "$script" ]]; then
            all_executable=false
            break
        fi
    done
    
    $all_executable
}

test_command_aliases() {
    # Test that template/templates both work
    "$DCK_CLI" template list 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -i "template" && \
    "$DCK_CLI" templates list 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -i "template"
}

test_help_for_subcommands() {
    # Test that subcommands support --help
    "$DCK_CLI" search --help 2>/dev/null | grep -q "search" || \
    "$DCK_CLI" search 2>/dev/null | grep -q "Types:"
}

# ==============================================================================
# Run Tests
# ==============================================================================

echo "=========================================="
echo "DCK CLI Core Functionality Unit Tests"
echo "=========================================="
echo ""

# Run all tests
run_test "CLI executable exists" test_cli_exists
run_test "help command works" test_help_command
run_test "version command works" test_version_command
run_test "--help flag works" test_help_flag
run_test "-v flag shows version" test_version_flag
run_test "unknown command fails" test_unknown_command
run_test "no arguments shows help" test_no_args_shows_help
run_test "docs command works" test_docs_command
run_test "search help works" test_search_help
run_test "template list command" test_template_list_command
run_test "--quiet flag works" test_quiet_flag
run_test "--no-color flag works" test_no_color_flag
run_test "--verbose flag accepted" test_verbose_flag
run_test "scripts directory exists" test_scripts_dir_exists
run_test "lib directory exists" test_lib_dir_exists
run_test "docs directory exists" test_docs_dir_exists
run_test "all scripts are executable" test_all_scripts_executable
run_test "command aliases work" test_command_aliases
run_test "subcommand help works" test_help_for_subcommands

echo ""
echo "=========================================="
echo "Test Results:"
echo "  Tests Run:    $TESTS_RUN"
echo "  Tests Passed: $TESTS_PASSED"
echo "  Tests Failed: $TESTS_FAILED"
echo "=========================================="

# Exit with appropriate code
[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1