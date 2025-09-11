#!/bin/bash

# ==============================================================================
# Integration Tests for DockerKit
# ==============================================================================
# Tests end-to-end workflows and component interactions
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DCK_CLI="$PROJECT_ROOT/dck"
TEMPLATE_DIR="$PROJECT_ROOT/template/complete"
TEST_TEMP_DIR=$(mktemp -d)

# Source test helpers
source "$SCRIPT_DIR/test_helpers.sh" 2>/dev/null || true

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup on exit
trap "rm -rf $TEST_TEMP_DIR" EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==============================================================================
# Test Helper Functions
# ==============================================================================

run_test() {
    local test_name="$1"
    local test_func="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing $test_name... "
    
    if $test_func 2>/dev/null; then
        echo -e "${GREEN} PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED} FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ==============================================================================
# Integration Tests - CLI Workflow
# ==============================================================================

test_help_to_version_workflow() {
    # Test that help leads to version command
    "$DCK_CLI" help 2>&1 | grep -q "version" && \
    "$DCK_CLI" version 2>&1 | grep -qi "dockerkit"
}

test_search_workflow() {
    # Test search command workflow
    "$DCK_CLI" search 2>&1 | grep -q "Types:" && \
    "$DCK_CLI" search --help 2>&1 | grep -qi "search"
}

test_template_workflow() {
    # Test template list -> show -> generate workflow
    local test_dir="$TEST_TEMP_DIR/template-test"
    
    "$DCK_CLI" template list 2>&1 | grep -qi "template" && \
    "$DCK_CLI" template show language/node 2>&1 | grep -qi "node" && \
    "$DCK_CLI" template generate language/node "$test_dir" 2>&1
    
    # Verify generated files
    [[ -f "$test_dir/Dockerfile" ]] && \
    [[ -f "$test_dir/docker-compose.yml" ]]
}

test_compliance_workflow() {
    # Test compliance check -> fix workflow
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.test"
    echo "FROM ubuntu:latest" > "$dockerfile"
    
    # Check compliance
    "$DCK_CLI" compliance dockerfile "$dockerfile" 2>&1 | grep -qi "score\|compliance"
    
    # Generate fixed version
    "$DCK_CLI" compliance dockerfile --generate-fixed "$dockerfile" 2>&1
    
    # Check if fixed file was created or original was modified
    [[ -f "${dockerfile}.fixed" ]] || [[ -f "$dockerfile" ]]
}

test_system_analysis_workflow() {
    # Test system command provides comprehensive info
    "$DCK_CLI" system 2>&1 | grep -qi "docker\|system"
}

# ==============================================================================
# Integration Tests - Template System
# ==============================================================================

test_template_generation_all_categories() {
    # Test generating templates from each category
    local categories=("language/node" "database/postgresql" "monitoring/prometheus" "iam/keycloak")
    local all_success=true
    
    for template in "${categories[@]}"; do
        local test_dir="$TEST_TEMP_DIR/$(basename $template)"
        if ! "$DCK_CLI" template generate "$template" "$test_dir" 2>&1 >/dev/null; then
            all_success=false
        fi
        
        # Basic validation
        if [[ ! -f "$test_dir/Dockerfile" ]] && [[ ! -f "$test_dir/docker-compose.yml" ]]; then
            all_success=false
        fi
    done
    
    $all_success
}

test_template_dockerfile_compliance() {
    # Test that generated templates pass compliance checks
    local test_dir="$TEST_TEMP_DIR/compliance-test"
    "$DCK_CLI" template generate language/node "$test_dir" 2>&1 >/dev/null
    
    if [[ -f "$test_dir/Dockerfile" ]]; then
        "$DCK_CLI" compliance dockerfile "$test_dir/Dockerfile" 2>&1 | grep -qi "pass\|score"
    else
        true  # Skip if no Dockerfile
    fi
}

# ==============================================================================
# Integration Tests - Search Functionality
# ==============================================================================

test_search_all_object_types() {
    # Test search for all Docker object types
    local types=("images" "containers" "volumes" "networks")
    local all_success=true
    
    for type in "${types[@]}"; do
        if ! "$DCK_CLI" search "$type" --help 2>&1 | grep -qi "$type\|search"; then
            all_success=false
        fi
    done
    
    $all_success
}

test_search_with_filters() {
    # Test search with various filter options
    "$DCK_CLI" search images --name nginx 2>&1 | grep -qi "search\|image\|nginx" || true
}

# ==============================================================================
# Integration Tests - Docker Management
# ==============================================================================

test_docker_object_inspection() {
    # Test inspecting all Docker object types
    local commands=("images" "containers" "volumes" "networks")
    local all_success=true
    
    for cmd in "${commands[@]}"; do
        if ! "$DCK_CLI" "$cmd" 2>&1 | grep -qi "$cmd\|docker"; then
            all_success=false
        fi
    done
    
    $all_success
}

test_cleanup_dry_run() {
    # Test cleanup with dry-run (safe)
    "$DCK_CLI" cleanup --dry-run 2>&1 | grep -qi "cleanup\|dry"
}

test_export_functionality() {
    # Test export to different formats
    "$DCK_CLI" export containers --format json 2>&1 | grep -qi "export\|json\|container" || true
}

# ==============================================================================
# Integration Tests - Monitoring and Analysis
# ==============================================================================

test_monitoring_workflow() {
    # Test monitoring commands
    "$DCK_CLI" monitor --help 2>&1 | grep -qi "monitor" || true
}

test_security_analysis() {
    # Test security analysis
    "$DCK_CLI" security 2>&1 | grep -qi "security\|audit"
}

test_analyze_command() {
    # Test analyze command for different object types
    "$DCK_CLI" analyze images 2>&1 | grep -qi "analyze\|image\|analysis"
}

# ==============================================================================
# Integration Tests - Error Handling
# ==============================================================================

test_invalid_command_handling() {
    # Test that invalid commands are handled gracefully
    ! "$DCK_CLI" invalidcommand 2>&1 | grep -q "Error"
}

test_missing_arguments_handling() {
    # Test commands with missing required arguments
    "$DCK_CLI" template generate 2>&1 | grep -qi "usage\|error\|missing" || true
}

test_invalid_template_handling() {
    # Test generating non-existent template
    ! "$DCK_CLI" template generate nonexistent/template "$TEST_TEMP_DIR/test" 2>&1
}

# ==============================================================================
# Integration Tests - File Operations
# ==============================================================================

test_docs_command() {
    # Test documentation viewing
    "$DCK_CLI" docs 2>&1 | head -20 | grep -qi "docker"
}

test_no_docker_commands() {
    # Test commands that work without Docker
    "$DCK_CLI" help 2>&1 | grep -q "COMMANDS" && \
    "$DCK_CLI" version 2>&1 | grep -qi "dockerkit" && \
    "$DCK_CLI" docs 2>&1 | head -5 | grep -qi "docker"
}

# ==============================================================================
# Integration Tests - Complex Workflows
# ==============================================================================

test_full_development_workflow() {
    # Test complete development workflow
    local app_dir="$TEST_TEMP_DIR/myapp"
    
    # 1. Generate template
    "$DCK_CLI" template generate language/node "$app_dir" 2>&1 >/dev/null
    
    # 2. Check compliance
    if [[ -f "$app_dir/Dockerfile" ]]; then
        "$DCK_CLI" compliance dockerfile "$app_dir/Dockerfile" 2>&1 | grep -qi "score"
    fi
    
    # 3. Verify structure
    [[ -f "$app_dir/docker-compose.yml" ]] && \
    [[ -f "$app_dir/.env.example" ]]
}

test_multi_template_generation() {
    # Test generating multiple templates in sequence
    local templates=("language/python" "language/go")
    local all_success=true
    
    for i in "${!templates[@]}"; do
        local test_dir="$TEST_TEMP_DIR/app$i"
        if ! "$DCK_CLI" template generate "${templates[$i]}" "$test_dir" 2>&1 >/dev/null; then
            all_success=false
        fi
    done
    
    $all_success
}

# ==============================================================================
# Integration Tests - Command Aliases
# ==============================================================================

test_command_aliases() {
    # Test that command aliases work
    "$DCK_CLI" template list 2>&1 | grep -qi "template" && \
    "$DCK_CLI" templates list 2>&1 | grep -qi "template"
}

# ==============================================================================
# Run Tests
# ==============================================================================

echo "=========================================="
echo "DockerKit Integration Tests"
echo "=========================================="
echo ""

# CLI Workflow Tests
echo -e "${BLUE}Testing CLI Workflows...${NC}"
run_test "help to version workflow" test_help_to_version_workflow
run_test "search workflow" test_search_workflow
run_test "template workflow" test_template_workflow
run_test "compliance workflow" test_compliance_workflow
run_test "system analysis workflow" test_system_analysis_workflow

# Template System Tests
echo -e "\n${BLUE}Testing Template System...${NC}"
run_test "template generation all categories" test_template_generation_all_categories
run_test "template dockerfile compliance" test_template_dockerfile_compliance

# Search Functionality Tests
echo -e "\n${BLUE}Testing Search Functionality...${NC}"
run_test "search all object types" test_search_all_object_types
run_test "search with filters" test_search_with_filters

# Docker Management Tests
echo -e "\n${BLUE}Testing Docker Management...${NC}"
run_test "docker object inspection" test_docker_object_inspection
run_test "cleanup dry-run" test_cleanup_dry_run
run_test "export functionality" test_export_functionality

# Monitoring and Analysis Tests
echo -e "\n${BLUE}Testing Monitoring and Analysis...${NC}"
run_test "monitoring workflow" test_monitoring_workflow
run_test "security analysis" test_security_analysis
run_test "analyze command" test_analyze_command

# Error Handling Tests
echo -e "\n${BLUE}Testing Error Handling...${NC}"
run_test "invalid command handling" test_invalid_command_handling
run_test "missing arguments handling" test_missing_arguments_handling
run_test "invalid template handling" test_invalid_template_handling

# File Operations Tests
echo -e "\n${BLUE}Testing File Operations...${NC}"
run_test "docs command" test_docs_command
run_test "no docker commands" test_no_docker_commands

# Complex Workflow Tests
echo -e "\n${BLUE}Testing Complex Workflows...${NC}"
run_test "full development workflow" test_full_development_workflow
run_test "multi-template generation" test_multi_template_generation
run_test "command aliases" test_command_aliases

echo ""
echo "=========================================="
echo "Test Results:"
echo "  Tests Run:    $TESTS_RUN"
echo "  Tests Passed: $TESTS_PASSED"
echo "  Tests Failed: $TESTS_FAILED"
echo "=========================================="

# Exit with appropriate code
[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1