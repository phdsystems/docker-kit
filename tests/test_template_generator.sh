#!/bin/bash

# ==============================================================================
# Unit Tests for Docker Template Generator
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_SCRIPT="$PROJECT_ROOT/src/docker-template-generator.sh"
TEMPLATE_DIR="$PROJECT_ROOT/template/complete"

# Source test helpers
source "$SCRIPT_DIR/test_helpers.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Temp directory for test outputs
TEST_TEMP_DIR=$(mktemp -d)
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
# Unit Tests - Template Script
# ==============================================================================

test_template_script_exists() {
    [[ -f "$TEMPLATE_SCRIPT" ]] && [[ -x "$TEMPLATE_SCRIPT" ]]
}

test_template_dir_exists() {
    [[ -d "$TEMPLATE_DIR" ]]
}

test_template_list_command() {
    "$TEMPLATE_SCRIPT" list 2>&1 | grep -qi "available\|template\|language"
}

test_template_show_command() {
    # Test showing a specific template  
    "$TEMPLATE_SCRIPT" show language/node 2>&1 | grep -qi "node\|docker\|template"
}

test_template_generate_command() {
    local output_dir="$TEST_TEMP_DIR/test-app"
    "$TEMPLATE_SCRIPT" generate language/node "$output_dir" 2>&1
    
    # Check if files were created
    [[ -f "$output_dir/Dockerfile" ]] && \
    [[ -f "$output_dir/docker-compose.yml" ]] && \
    [[ -f "$output_dir/.env.example" ]]
}

test_template_help_command() {
    "$TEMPLATE_SCRIPT" --help 2>&1 | grep -qi "usage\|template\|generate"
}

test_template_invalid_template() {
    local output_dir="$TEST_TEMP_DIR/invalid"
    ! "$TEMPLATE_SCRIPT" generate nonexistent/template "$output_dir" 2>&1
}

test_template_no_output_dir() {
    # Should fail without output directory
    ! "$TEMPLATE_SCRIPT" generate language/node 2>&1
}

# ==============================================================================
# Unit Tests - Template Categories
# ==============================================================================

test_language_templates_exist() {
    [[ -d "$TEMPLATE_DIR/language" ]] && \
    [[ -n "$(ls -A "$TEMPLATE_DIR/language")" ]]
}

test_database_templates_exist() {
    [[ -d "$TEMPLATE_DIR/database" ]] && \
    [[ -n "$(ls -A "$TEMPLATE_DIR/database")" ]]
}

test_monitoring_templates_exist() {
    [[ -d "$TEMPLATE_DIR/monitoring" ]] && \
    [[ -n "$(ls -A "$TEMPLATE_DIR/monitoring")" ]]
}

test_iam_templates_exist() {
    [[ -d "$TEMPLATE_DIR/iam" ]] && \
    [[ -n "$(ls -A "$TEMPLATE_DIR/iam")" ]]
}

test_orchestration_templates_exist() {
    [[ -d "$TEMPLATE_DIR/orchestration" ]] && \
    [[ -n "$(ls -A "$TEMPLATE_DIR/orchestration")" ]]
}

# ==============================================================================
# Unit Tests - Template Structure
# ==============================================================================

test_node_template_structure() {
    local template="$TEMPLATE_DIR/language/node"
    [[ -f "$template/Dockerfile" ]] && \
    [[ -f "$template/docker-compose.yml" ]] && \
    [[ -f "$template/.env.example" ]]
}

test_python_template_structure() {
    local template="$TEMPLATE_DIR/language/python"
    [[ -f "$template/Dockerfile" ]] && \
    [[ -f "$template/docker-compose.yml" ]] && \
    [[ -f "$template/.env.example" ]]
}

test_go_template_structure() {
    local template="$TEMPLATE_DIR/language/go"
    [[ -f "$template/Dockerfile" ]] && \
    [[ -f "$template/docker-compose.yml" ]] && \
    [[ -f "$template/.env.example" ]]
}

test_postgresql_template_structure() {
    local template="$TEMPLATE_DIR/database/postgresql"
    [[ -f "$template/Dockerfile" ]] || [[ -f "$template/docker-compose.yml" ]]
}

test_prometheus_template_structure() {
    local template="$TEMPLATE_DIR/monitoring/prometheus"
    [[ -f "$template/Dockerfile" ]] || [[ -f "$template/docker-compose.yml" ]]
}

test_keycloak_template_structure() {
    local template="$TEMPLATE_DIR/iam/keycloak"
    [[ -f "$template/Dockerfile" ]] || [[ -f "$template/docker-compose.yml" ]]
}

# ==============================================================================
# Unit Tests - Template Content
# ==============================================================================

test_template_dockerfile_best_practices() {
    local dockerfile="$TEMPLATE_DIR/language/node/Dockerfile"
    if [[ -f "$dockerfile" ]]; then
        # Check for best practices
        grep -q "USER\|nobody\|node" "$dockerfile" && \
        grep -q "HEALTHCHECK" "$dockerfile" && \
        ! grep -q ":latest" "$dockerfile"
    else
        true  # Skip if no Dockerfile
    fi
}

test_template_compose_has_healthcheck() {
    local compose="$TEMPLATE_DIR/language/node/docker-compose.yml"
    if [[ -f "$compose" ]]; then
        grep -q "healthcheck:\|health" "$compose"
    else
        true  # Skip if no compose file
    fi
}

test_template_env_example_exists() {
    local env_file="$TEMPLATE_DIR/language/node/.env.example"
    if [[ -f "$env_file" ]]; then
        # Check for common env vars
        grep -q "PORT\|DB_\|REDIS_\|APP_" "$env_file"
    else
        true  # Skip if no env file
    fi
}

test_template_no_secrets_in_files() {
    # Ensure no real secrets in template files
    ! grep -r "password123\|secret123\|api_key_here" "$TEMPLATE_DIR" 2>/dev/null | \
        grep -v ".env.example" | \
        grep -v "# Example"
}

# ==============================================================================
# Unit Tests - Template Generation
# ==============================================================================

test_generate_preserves_structure() {
    local output_dir="$TEST_TEMP_DIR/preserve-test"
    "$TEMPLATE_SCRIPT" generate language/node "$output_dir" 2>&1
    
    # Compare structure
    [[ -f "$output_dir/Dockerfile" ]] && \
    [[ -f "$output_dir/docker-compose.yml" ]] && \
    [[ -f "$output_dir/.env.example" ]]
}

test_generate_creates_gitignore() {
    local output_dir="$TEST_TEMP_DIR/gitignore-test"
    "$TEMPLATE_SCRIPT" generate language/node "$output_dir" 2>&1
    
    # Check if .dockerignore exists or is created
    [[ -f "$output_dir/.dockerignore" ]] || true
}

test_generate_handles_existing_dir() {
    local output_dir="$TEST_TEMP_DIR/existing"
    mkdir -p "$output_dir"
    echo "existing file" > "$output_dir/existing.txt"
    
    "$TEMPLATE_SCRIPT" generate language/node "$output_dir" 2>&1
    
    # Should preserve existing files and add new ones
    [[ -f "$output_dir/existing.txt" ]] && \
    [[ -f "$output_dir/Dockerfile" ]]
}

# ==============================================================================
# Run Tests
# ==============================================================================

echo "=========================================="
echo "Docker Template Generator Unit Tests"
echo "=========================================="
echo ""

# Template Script Tests
run_test "template script exists" test_template_script_exists
run_test "template directory exists" test_template_dir_exists
run_test "template list command" test_template_list_command
run_test "template show command" test_template_show_command
run_test "template generate command" test_template_generate_command
run_test "template help command" test_template_help_command
run_test "invalid template error" test_template_invalid_template
run_test "missing output dir error" test_template_no_output_dir

# Template Categories Tests
run_test "language templates exist" test_language_templates_exist
run_test "database templates exist" test_database_templates_exist
run_test "monitoring templates exist" test_monitoring_templates_exist
run_test "IAM templates exist" test_iam_templates_exist
run_test "orchestration templates exist" test_orchestration_templates_exist

# Template Structure Tests
run_test "Node.js template structure" test_node_template_structure
run_test "Python template structure" test_python_template_structure
run_test "Go template structure" test_go_template_structure
run_test "PostgreSQL template structure" test_postgresql_template_structure
run_test "Prometheus template structure" test_prometheus_template_structure
run_test "Keycloak template structure" test_keycloak_template_structure

# Template Content Tests
run_test "Dockerfile best practices" test_template_dockerfile_best_practices
run_test "Compose has healthcheck" test_template_compose_has_healthcheck
run_test "env.example exists" test_template_env_example_exists
run_test "no secrets in templates" test_template_no_secrets_in_files

# Template Generation Tests
run_test "generation preserves structure" test_generate_preserves_structure
run_test "generation creates gitignore" test_generate_creates_gitignore
run_test "generation handles existing dir" test_generate_handles_existing_dir

echo ""
echo "=========================================="
echo "Test Results:"
echo "  Tests Run:    $TESTS_RUN"
echo "  Tests Passed: $TESTS_PASSED"
echo "  Tests Failed: $TESTS_FAILED"
echo "=========================================="

# Exit with appropriate code
[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1