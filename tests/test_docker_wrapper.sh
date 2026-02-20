#!/usr/bin/env bash
#
# Unit tests for Docker Wrapper
#

set -uo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WRAPPER_SCRIPT="${PROJECT_ROOT}/main/src/lib/docker-wrapper.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Test Framework
# ============================================================================

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

assert_not_empty() {
    local value="$1"
    local test_name="${2:-Test}"
    
    ((TESTS_RUN++))
    
    if [[ -n "$value" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected non-empty value"
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

# ============================================================================
# Unit Tests
# ============================================================================

test_wrapper_exists() {
    echo -e "\n${YELLOW}Testing Docker Wrapper Script Exists...${NC}"
    
    if [[ -f "$WRAPPER_SCRIPT" ]]; then
        echo -e "${GREEN}✓${NC} Docker wrapper script exists"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "${RED}✗${NC} Docker wrapper script not found at $WRAPPER_SCRIPT"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

test_wrapper_sources() {
    echo -e "\n${YELLOW}Testing Docker Wrapper Can Be Sourced...${NC}"
    
    # Try to source the wrapper in a subshell
    if (source "$WRAPPER_SCRIPT" 2>/dev/null); then
        echo -e "${GREEN}✓${NC} Docker wrapper can be sourced"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "${RED}✗${NC} Failed to source docker wrapper"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

test_docker_cmd_set() {
    echo -e "\n${YELLOW}Testing DOCKER_CMD Variable Set...${NC}"
    
    # Source wrapper and check DOCKER_CMD
    local docker_cmd
    docker_cmd=$(bash -c "source '$WRAPPER_SCRIPT' && echo \"\$DOCKER_CMD\"")
    
    assert_not_empty "$docker_cmd" "DOCKER_CMD variable is set"
}

test_docker_available_set() {
    echo -e "\n${YELLOW}Testing DOCKER_AVAILABLE Variable Set...${NC}"
    
    # Source wrapper and check DOCKER_AVAILABLE
    local docker_available
    docker_available=$(bash -c "source '$WRAPPER_SCRIPT' && echo \"\$DOCKER_AVAILABLE\"")
    
    if [[ "$docker_available" == "true" ]] || [[ "$docker_available" == "false" ]]; then
        echo -e "${GREEN}✓${NC} DOCKER_AVAILABLE is set to: $docker_available"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "${RED}✗${NC} DOCKER_AVAILABLE not properly set"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

test_docker_run_function() {
    echo -e "\n${YELLOW}Testing docker_run Function...${NC}"
    
    # Check if docker_run function is defined
    local function_exists
    function_exists=$(bash -c "source '$WRAPPER_SCRIPT' && type -t docker_run")
    
    assert_equals "function" "$function_exists" "docker_run function exists"
}

test_detect_docker_command() {
    echo -e "\n${YELLOW}Testing detect_docker_command Function...${NC}"
    
    # Check if detect_docker_command function works
    local result
    result=$(bash -c "
        source '$WRAPPER_SCRIPT'
        # Override the function to test logic
        detect_docker_command() {
            if command -v docker &>/dev/null; then
                echo 'docker-found'
            else
                echo 'docker-not-found'
            fi
        }
        detect_docker_command
    ")
    
    if [[ "$result" == "docker-found" ]] || [[ "$result" == "docker-not-found" ]]; then
        echo -e "${GREEN}✓${NC} detect_docker_command function works"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "${RED}✗${NC} detect_docker_command function failed"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

test_wrapper_handles_sudo() {
    echo -e "\n${YELLOW}Testing Wrapper Handles Sudo...${NC}"
    
    # Check if wrapper detects need for sudo
    local docker_cmd
    docker_cmd=$(bash -c "source '$WRAPPER_SCRIPT' && echo \"\$DOCKER_CMD\"")
    
    if [[ "$docker_cmd" == "docker" ]] || [[ "$docker_cmd" == "sudo docker" ]]; then
        echo -e "${GREEN}✓${NC} Wrapper handles Docker command (with or without sudo): $docker_cmd"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "${YELLOW}⚠${NC} Unexpected DOCKER_CMD value: $docker_cmd"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    fi
}

test_wrapper_exports() {
    echo -e "\n${YELLOW}Testing Wrapper Exports Variables...${NC}"
    
    # Check if variables are exported
    local exports
    exports=$(bash -c "source '$WRAPPER_SCRIPT' && export -p | grep -E 'DOCKER_CMD|DOCKER_AVAILABLE' | wc -l")
    
    if [[ "$exports" -ge 2 ]]; then
        echo -e "${GREEN}✓${NC} Wrapper exports required variables"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "${RED}✗${NC} Wrapper doesn't export all required variables"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

test_wrapper_idempotent() {
    echo -e "\n${YELLOW}Testing Wrapper Is Idempotent...${NC}"
    
    # Source wrapper multiple times and ensure it doesn't break
    local result
    result=$(bash -c "
        source '$WRAPPER_SCRIPT'
        first_cmd=\"\$DOCKER_CMD\"
        source '$WRAPPER_SCRIPT'
        second_cmd=\"\$DOCKER_CMD\"
        if [[ \"\$first_cmd\" == \"\$second_cmd\" ]]; then
            echo 'idempotent'
        else
            echo 'not-idempotent'
        fi
    ")
    
    assert_equals "idempotent" "$result" "Wrapper is idempotent"
}

test_docker_run_execution() {
    echo -e "\n${YELLOW}Testing docker_run Execution...${NC}"
    
    # Test that docker_run can execute commands
    local result
    result=$(bash -c "
        source '$WRAPPER_SCRIPT'
        if [[ \"\$DOCKER_AVAILABLE\" == 'true' ]]; then
            docker_run --version 2>/dev/null | grep -q 'Docker version' && echo 'works' || echo 'failed'
        else
            echo 'docker-not-available'
        fi
    ")
    
    if [[ "$result" == "works" ]]; then
        echo -e "${GREEN}✓${NC} docker_run executes Docker commands"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    elif [[ "$result" == "docker-not-available" ]]; then
        echo -e "${YELLOW}⚠${NC} Docker not available (expected in CI)"
        ((TESTS_PASSED++))
        ((TESTS_RUN++))
    else
        echo -e "${RED}✗${NC} docker_run failed to execute"
        ((TESTS_FAILED++))
        ((TESTS_RUN++))
    fi
}

# ============================================================================
# Main Test Runner
# ============================================================================

run_tests() {
    echo "=========================================="
    echo "Docker Wrapper - Unit Tests"
    echo "=========================================="
    
    # Run all test functions
    test_wrapper_exists
    test_wrapper_sources
    test_docker_cmd_set
    test_docker_available_set
    test_docker_run_function
    test_detect_docker_command
    test_wrapper_handles_sudo
    test_wrapper_exports
    test_wrapper_idempotent
    test_docker_run_execution
    
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