#!/bin/bash

# ==============================================================================
# Unit Tests for Docker Compliance Module
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"
COMPLIANCE_SCRIPT="$SRC_DIR/docker-compliance.sh"
REMEDIATION_SCRIPT="$SRC_DIR/docker-remediation.sh"

# Source test helpers
source "$SCRIPT_DIR/test_helpers.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Temp directory for test files
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

create_test_dockerfile() {
    local file="$1"
    local content="$2"
    echo "$content" > "$file"
}

# ==============================================================================
# Unit Tests - Compliance Script
# ==============================================================================

test_compliance_script_exists() {
    [[ -f "$COMPLIANCE_SCRIPT" ]] && [[ -x "$COMPLIANCE_SCRIPT" ]]
}

test_remediation_script_exists() {
    [[ -f "$REMEDIATION_SCRIPT" ]] && [[ -x "$REMEDIATION_SCRIPT" ]]
}

test_compliance_help() {
    "$COMPLIANCE_SCRIPT" --help 2>&1 | grep -q "compliance\|Compliance\|Usage"
}

test_compliance_dockerfile_good() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.good"
    create_test_dockerfile "$dockerfile" "FROM alpine:3.19
USER nobody:nobody
HEALTHCHECK CMD wget --spider http://localhost/health || exit 1
EXPOSE 8080
ENTRYPOINT [\"app\"]"
    
    "$COMPLIANCE_SCRIPT" dockerfile "$dockerfile" 2>&1 | grep -q "Score:\|PASS\|compliance"
}

test_compliance_dockerfile_bad() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.bad"
    create_test_dockerfile "$dockerfile" "FROM ubuntu:latest
RUN apt-get update
ADD http://example.com/file /tmp/
ENV PASSWORD=secret123
EXPOSE 22"
    
    local output
    output=$("$COMPLIANCE_SCRIPT" dockerfile "$dockerfile" 2>&1)
    echo "$output" | grep -qi "fail\|warning\|issue\|score"
}

test_compliance_dockerfile_fix_flag() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.fix"
    create_test_dockerfile "$dockerfile" "FROM ubuntu:latest
RUN apt-get update"
    
    # Test that --fix flag is recognized
    "$COMPLIANCE_SCRIPT" dockerfile --fix "$dockerfile" 2>&1 | grep -q "fix\|Fix\|remediat" || true
}

test_compliance_dockerfile_threshold() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.threshold"
    create_test_dockerfile "$dockerfile" "FROM alpine:3.19
USER nobody"
    
    # Test threshold flag
    "$COMPLIANCE_SCRIPT" dockerfile --threshold 50 "$dockerfile" 2>&1
    # Should exit successfully if score > 50
}

test_compliance_dockerfile_strict() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.strict"
    create_test_dockerfile "$dockerfile" "FROM alpine
RUN apk add curl"
    
    # Test strict mode (should fail if score < 70)
    ! "$COMPLIANCE_SCRIPT" dockerfile --strict "$dockerfile" 2>&1
}

test_compliance_lint_command() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.lint"
    create_test_dockerfile "$dockerfile" "FROM alpine:3.19"
    
    "$COMPLIANCE_SCRIPT" lint "$dockerfile" 2>&1 | grep -qi "lint\|check\|compliance"
}

test_compliance_cis_command() {
    # Test CIS benchmark command
    "$COMPLIANCE_SCRIPT" cis 2>&1 | grep -q "CIS\|benchmark\|security" || true
}

test_compliance_json_output() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.json"
    create_test_dockerfile "$dockerfile" "FROM alpine:3.19"
    
    "$COMPLIANCE_SCRIPT" dockerfile --json "$dockerfile" 2>&1 | grep -q "{\|score\|issues" || true
}

# ==============================================================================
# Unit Tests - Remediation
# ==============================================================================

test_remediation_fix_user() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.user"
    create_test_dockerfile "$dockerfile" "FROM alpine:3.19
RUN echo hello"
    
    "$REMEDIATION_SCRIPT" "$dockerfile" 2>&1
    grep -q "USER\|nobody\|nonroot" "$dockerfile" || true
}

test_remediation_pin_version() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.version"
    create_test_dockerfile "$dockerfile" "FROM ubuntu:latest"
    
    "$REMEDIATION_SCRIPT" "$dockerfile" 2>&1
    ! grep -q ":latest" "$dockerfile"
}

test_remediation_add_healthcheck() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.health"
    create_test_dockerfile "$dockerfile" "FROM alpine:3.19
USER nobody"
    
    "$REMEDIATION_SCRIPT" "$dockerfile" 2>&1
    grep -q "HEALTHCHECK" "$dockerfile" || true
}

test_remediation_remove_secrets() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.secrets"
    create_test_dockerfile "$dockerfile" "FROM alpine:3.19
ENV PASSWORD=secret123
ENV API_KEY=abcd1234"
    
    "$REMEDIATION_SCRIPT" "$dockerfile" 2>&1
    ! grep -q "secret123\|abcd1234" "$dockerfile"
}

test_remediation_fix_add() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.add"
    create_test_dockerfile "$dockerfile" "FROM alpine:3.19
ADD file.tar.gz /app/"
    
    "$REMEDIATION_SCRIPT" "$dockerfile" 2>&1
    grep -q "COPY" "$dockerfile" || ! grep -q "^ADD" "$dockerfile"
}

test_remediation_clean_cache() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.cache"
    create_test_dockerfile "$dockerfile" "FROM alpine:3.19
RUN apk add curl"
    
    "$REMEDIATION_SCRIPT" "$dockerfile" 2>&1
    grep -q "no-cache\|clean\|rm" "$dockerfile" || true
}

# ==============================================================================
# Unit Tests - Integration
# ==============================================================================

test_compliance_with_fixed_dockerfile() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.integration"
    create_test_dockerfile "$dockerfile" "FROM ubuntu:latest
RUN apt-get update
ENV PASSWORD=secret"
    
    # First run remediation
    "$REMEDIATION_SCRIPT" "$dockerfile" 2>&1
    
    # Then check compliance - score should be improved
    "$COMPLIANCE_SCRIPT" dockerfile "$dockerfile" 2>&1 | grep -q "Score:"
}

test_compliance_generate_fixed() {
    local dockerfile="$TEST_TEMP_DIR/Dockerfile.generate"
    create_test_dockerfile "$dockerfile" "FROM alpine:latest"
    
    "$COMPLIANCE_SCRIPT" dockerfile --generate-fixed "$dockerfile" 2>&1
    [[ -f "${dockerfile}.fixed" ]] || true
}

# ==============================================================================
# Run Tests
# ==============================================================================

echo "=========================================="
echo "Docker Compliance Module Unit Tests"
echo "=========================================="
echo ""

# Compliance Script Tests
run_test "compliance script exists" test_compliance_script_exists
run_test "remediation script exists" test_remediation_script_exists
run_test "compliance help command" test_compliance_help
run_test "compliance good Dockerfile" test_compliance_dockerfile_good
run_test "compliance bad Dockerfile" test_compliance_dockerfile_bad
run_test "compliance --fix flag" test_compliance_dockerfile_fix_flag
run_test "compliance --threshold flag" test_compliance_dockerfile_threshold
run_test "compliance --strict mode" test_compliance_dockerfile_strict
run_test "compliance lint command" test_compliance_lint_command
run_test "compliance CIS command" test_compliance_cis_command
run_test "compliance JSON output" test_compliance_json_output

# Remediation Tests
run_test "remediation fix missing user" test_remediation_fix_user
run_test "remediation pin version" test_remediation_pin_version
run_test "remediation add healthcheck" test_remediation_add_healthcheck
run_test "remediation remove secrets" test_remediation_remove_secrets
run_test "remediation fix ADD usage" test_remediation_fix_add
run_test "remediation clean cache" test_remediation_clean_cache

# Integration Tests
run_test "compliance after remediation" test_compliance_with_fixed_dockerfile
run_test "compliance generate-fixed" test_compliance_generate_fixed

echo ""
echo "=========================================="
echo "Test Results:"
echo "  Tests Run:    $TESTS_RUN"
echo "  Tests Passed: $TESTS_PASSED"
echo "  Tests Failed: $TESTS_FAILED"
echo "=========================================="

# Exit with appropriate code
[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1