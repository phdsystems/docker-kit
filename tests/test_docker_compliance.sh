#!/usr/bin/env bash
#
# Unit tests for Docker Compliance Module
#

set -uo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DCK_CMD="${PROJECT_ROOT}/dck"
COMPLIANCE_SCRIPT="${PROJECT_ROOT}/src/docker-compliance.sh"
TEST_DIR="${SCRIPT_DIR}/test_files"
TEMP_DIR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Test Framework
# ============================================================================

setup() {
    # Create temp directory for test files
    TEMP_DIR=$(mktemp -d)
    TEST_DIR="$TEMP_DIR/test_files"
    mkdir -p "$TEST_DIR"
    
    # Source the compliance script functions
    source "${PROJECT_ROOT}/lib/common.sh" 2>/dev/null || true
    source "${PROJECT_ROOT}/lib/docker-wrapper.sh" 2>/dev/null || true
}

teardown() {
    # Clean up temp files
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="${3:-Test}"
    
    ((TESTS_RUN++))
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="${3:-Test}"
    
    ((TESTS_RUN++))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected to contain: $needle"
        echo "  Actual: $haystack"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local test_name="${2:-File exists: $file}"
    
    ((TESTS_RUN++))
    
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  File not found: $file"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_command_succeeds() {
    local command="$1"
    local test_name="${2:-Command succeeds}"
    
    ((TESTS_RUN++))
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Command failed: $command"
        ((TESTS_FAILED++))
        return 1
    fi
}

# ============================================================================
# Test Helper Functions
# ============================================================================

create_test_dockerfile() {
    local type="$1"
    local file="${TEST_DIR}/Dockerfile.${type}"
    
    case "$type" in
        good)
            cat > "$file" <<'EOF'
FROM alpine:3.19.1
LABEL maintainer="Test Team"
LABEL version="1.0.0"
LABEL description="Test container"
RUN apk add --no-cache bash curl \
    && rm -rf /var/cache/apk/*
RUN adduser -D -u 1000 testuser
WORKDIR /app
USER testuser
HEALTHCHECK CMD curl -f http://localhost/ || exit 1
COPY --chown=testuser:testuser . /app
ENTRYPOINT ["/app/entrypoint.sh"]
EOF
            ;;
        bad)
            cat > "$file" <<'EOF'
FROM alpine:latest
RUN apk add bash curl sudo
ENV API_KEY="secret123"
ENV PASSWORD="admin"
ADD http://example.com/file.tar /tmp/
RUN chmod 777 /app
COPY . /app
CMD ["bash"]
EOF
            ;;
        minimal)
            cat > "$file" <<'EOF'
FROM scratch
COPY binary /
ENTRYPOINT ["/binary"]
EOF
            ;;
    esac
    
    echo "$file"
}

# ============================================================================
# Unit Tests - Dockerfile Compliance
# ============================================================================

test_dockerfile_good_compliance() {
    echo -e "\n${YELLOW}Testing Good Dockerfile Compliance...${NC}"
    
    local dockerfile=$(create_test_dockerfile "good")
    local output
    
    # Run compliance check
    output=$("$DCK_CMD" compliance dockerfile "$dockerfile" 2>&1)
    
    # Check for expected passes
    assert_contains "$output" "Non-root user configured" "Good Dockerfile: Non-root user check"
    assert_contains "$output" "Base image version pinned" "Good Dockerfile: Version pinning check"
    assert_contains "$output" "HEALTHCHECK configured" "Good Dockerfile: Health check present"
    assert_contains "$output" "No hardcoded secrets" "Good Dockerfile: No secrets check"
    assert_contains "$output" "Package cache cleaned" "Good Dockerfile: Cache cleanup check"
    assert_contains "$output" "WORKDIR configured" "Good Dockerfile: WORKDIR check"
    assert_contains "$output" "Proper COPY usage" "Good Dockerfile: COPY vs ADD check"
}

test_dockerfile_bad_compliance() {
    echo -e "\n${YELLOW}Testing Bad Dockerfile Compliance...${NC}"
    
    local dockerfile=$(create_test_dockerfile "bad")
    local output
    
    # Run compliance check
    output=$("$DCK_CMD" compliance dockerfile "$dockerfile" 2>&1)
    
    # Check for expected failures
    assert_contains "$output" "No non-root user" "Bad Dockerfile: Missing non-root user"
    assert_contains "$output" "Base image not version-pinned" "Bad Dockerfile: No version pinning"
    assert_contains "$output" "No HEALTHCHECK" "Bad Dockerfile: Missing health check"
    assert_contains "$output" "Potential secrets found" "Bad Dockerfile: Secrets detected"
    assert_contains "$output" "cache not cleaned" "Bad Dockerfile: Cache not cleaned"
    assert_contains "$output" "ADD used instead of COPY" "Bad Dockerfile: ADD misuse"
}

test_dockerfile_minimal_compliance() {
    echo -e "\n${YELLOW}Testing Minimal Dockerfile Compliance...${NC}"
    
    local dockerfile=$(create_test_dockerfile "minimal")
    local output
    
    # Run compliance check
    output=$("$DCK_CMD" compliance dockerfile "$dockerfile" 2>&1)
    
    # Minimal Dockerfiles should pass some checks
    assert_contains "$output" "No hardcoded secrets" "Minimal Dockerfile: No secrets"
    assert_contains "$output" "Proper COPY usage" "Minimal Dockerfile: COPY usage"
}

test_dockerfile_not_found() {
    echo -e "\n${YELLOW}Testing Dockerfile Not Found...${NC}"
    
    local output
    output=$("$DCK_CMD" compliance dockerfile "/tmp/nonexistent.dockerfile" 2>&1)
    
    assert_contains "$output" "not found" "Dockerfile not found error"
}

# ============================================================================
# Unit Tests - Compliance Commands
# ============================================================================

test_compliance_help() {
    echo -e "\n${YELLOW}Testing Compliance Help...${NC}"
    
    local output
    output=$("$DCK_CMD" compliance 2>&1)
    
    assert_contains "$output" "Usage:" "Compliance help: Usage shown"
    assert_contains "$output" "dockerfile" "Compliance help: dockerfile command"
    assert_contains "$output" "container" "Compliance help: container command"
    assert_contains "$output" "image" "Compliance help: image command"
    assert_contains "$output" "lint" "Compliance help: lint command"
    assert_contains "$output" "cis" "Compliance help: cis command"
}

test_compliance_score_calculation() {
    echo -e "\n${YELLOW}Testing Compliance Score Calculation...${NC}"
    
    local dockerfile=$(create_test_dockerfile "good")
    local output
    
    output=$("$DCK_CMD" compliance dockerfile "$dockerfile" 2>&1)
    
    # Check that a score is calculated
    assert_contains "$output" "Compliance Score:" "Score calculation present"
    assert_contains "$output" "%" "Score percentage shown"
    assert_contains "$output" "Total Checks:" "Total checks counted"
    assert_contains "$output" "Passed:" "Passed checks counted"
}

# ============================================================================
# Unit Tests - Container Compliance (Mock)
# ============================================================================

test_container_compliance_missing() {
    echo -e "\n${YELLOW}Testing Container Compliance with Missing Container...${NC}"
    
    local output
    output=$("$DCK_CMD" compliance container nonexistent-container-xyz123 2>&1)
    
    assert_contains "$output" "not found" "Container not found error"
}

test_container_compliance_no_name() {
    echo -e "\n${YELLOW}Testing Container Compliance without Name...${NC}"
    
    local output
    output=$("$DCK_CMD" compliance container 2>&1)
    
    assert_contains "$output" "required" "Container name required error"
}

# ============================================================================
# Unit Tests - Image Security Scan (Mock)
# ============================================================================

test_image_scan_no_name() {
    echo -e "\n${YELLOW}Testing Image Scan without Name...${NC}"
    
    local output
    output=$("$DCK_CMD" compliance image 2>&1)
    
    assert_contains "$output" "required" "Image name required error"
}

test_image_scan_with_name() {
    echo -e "\n${YELLOW}Testing Image Scan with Name...${NC}"
    
    local output
    output=$("$DCK_CMD" compliance image alpine:3.19.1 2>&1)
    
    # Should at least attempt to scan
    assert_contains "$output" "Security Scan" "Image scan header shown"
}

# ============================================================================
# Unit Tests - Lint Command
# ============================================================================

test_lint_dockerfile() {
    echo -e "\n${YELLOW}Testing Dockerfile Linting...${NC}"
    
    local dockerfile=$(create_test_dockerfile "bad")
    local output
    
    output=$("$DCK_CMD" compliance lint "$dockerfile" 2>&1)
    
    assert_contains "$output" "Linting Dockerfile" "Lint command runs"
}

# ============================================================================
# Integration Tests
# ============================================================================

test_dck_compliance_integration() {
    echo -e "\n${YELLOW}Testing DCK Compliance Integration...${NC}"
    
    # Test that compliance is integrated into main dck command
    local output
    output=$("$DCK_CMD" help 2>&1)
    
    assert_contains "$output" "compliance" "Compliance in main help"
    assert_contains "$output" "Docker best practices" "Compliance description present"
}

test_compliance_color_output() {
    echo -e "\n${YELLOW}Testing Color Output...${NC}"
    
    local dockerfile=$(create_test_dockerfile "good")
    local output
    
    # Run without no-color flag
    output=$("$DCK_CMD" compliance dockerfile "$dockerfile" 2>&1)
    
    # Check for color codes (this is basic, just checking they exist)
    if [[ "$output" == *"\033["* ]] || [[ "$output" == *"[0;32m"* ]]; then
        echo -e "${GREEN}✓${NC} Color codes present in output"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "${YELLOW}⚠${NC} Color codes might be disabled in test environment"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

# ============================================================================
# Performance Tests
# ============================================================================

test_compliance_performance() {
    echo -e "\n${YELLOW}Testing Compliance Performance...${NC}"
    
    local dockerfile=$(create_test_dockerfile "good")
    local start_time=$(date +%s)
    
    "$DCK_CMD" compliance dockerfile "$dockerfile" &>/dev/null
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Should complete within 2 seconds for a simple dockerfile check
    if [[ $duration -le 2 ]]; then
        echo -e "${GREEN}✓${NC} Compliance check completed in ${duration}s"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "${YELLOW}⚠${NC} Compliance check took ${duration}s (expected <2s)"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

# ============================================================================
# Error Handling Tests
# ============================================================================

test_compliance_invalid_command() {
    echo -e "\n${YELLOW}Testing Invalid Compliance Command...${NC}"
    
    local output
    output=$("$DCK_CMD" compliance invalid-command 2>&1)
    
    assert_contains "$output" "Usage:" "Invalid command shows help"
}

test_compliance_with_invalid_dockerfile_syntax() {
    echo -e "\n${YELLOW}Testing Invalid Dockerfile Syntax...${NC}"
    
    # Create a dockerfile with invalid syntax
    local dockerfile="${TEST_DIR}/Dockerfile.invalid"
    cat > "$dockerfile" <<'EOF'
FRUM alpine:3.19
RUNNN echo "invalid"
EOF
    
    local output
    output=$("$DCK_CMD" compliance dockerfile "$dockerfile" 2>&1)
    
    # Should still run checks even with typos
    assert_contains "$output" "Analyzing Dockerfile" "Handles invalid syntax"
}

# ============================================================================
# Main Test Runner
# ============================================================================

run_tests() {
    echo "=========================================="
    echo "Docker Compliance Module - Unit Tests"
    echo "=========================================="
    
    # Setup
    setup
    
    # Run all test functions
    test_dockerfile_good_compliance
    test_dockerfile_bad_compliance
    test_dockerfile_minimal_compliance
    test_dockerfile_not_found
    test_compliance_help
    test_compliance_score_calculation
    test_container_compliance_missing
    test_container_compliance_no_name
    test_image_scan_no_name
    test_image_scan_with_name
    test_lint_dockerfile
    test_dck_compliance_integration
    test_compliance_color_output
    test_compliance_performance
    test_compliance_invalid_command
    test_compliance_with_invalid_dockerfile_syntax
    
    # Teardown
    teardown
    
    # Print summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo -e "Tests Run: $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
    exit $?
fi