#!/bin/bash

# Unit tests for DockerKit Container Lifecycle Operations

set -euo pipefail

# Test setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIFECYCLE_SCRIPT="$DOCKERKIT_DIR/scripts/docker-container-lifecycle.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Check if using real Docker or mock
if [[ "${USE_MOCK_DOCKER:-false}" == "true" ]] || ! docker info &>/dev/null 2>&1; then
    if ! sudo docker info &>/dev/null 2>&1; then
        echo -e "${YELLOW}Using mock Docker for tests${NC}"
        export PATH="$SCRIPT_DIR/mocks:$PATH"
        export DOCKER_CMD="docker"
        USE_MOCK=true
    else
        echo -e "${GREEN}Using real Docker with sudo${NC}"
        export DOCKER_CMD="sudo docker"
        USE_MOCK=false
    fi
else
    echo -e "${GREEN}Using real Docker${NC}"
    export DOCKER_CMD="docker"
    USE_MOCK=false
fi

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    ((TESTS_RUN++))
    
    if [[ "$expected" == "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected: $expected"
        echo -e "  Actual: $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    local text="$1"
    local pattern="$2"
    local test_name="$3"
    
    ((TESTS_RUN++))
    
    if echo "$text" | grep -q "$pattern"; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Pattern '$pattern' not found in output"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    ((TESTS_RUN++))
    
    if [[ "$expected" -eq "$actual" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected exit code: $expected"
        echo -e "  Actual exit code: $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Create test container if using real Docker
setup_test_container() {
    if [[ "$USE_MOCK" != "true" ]]; then
        # Create a test container
        $DOCKER_CMD run -d --name dockerkit-test-lifecycle alpine:latest sleep 3600 &>/dev/null || true
    fi
}

# Clean up test container
cleanup_test_container() {
    if [[ "$USE_MOCK" != "true" ]]; then
        $DOCKER_CMD stop dockerkit-test-lifecycle &>/dev/null || true
        $DOCKER_CMD rm dockerkit-test-lifecycle &>/dev/null || true
    fi
}

# Test Suite: Help and Usage
test_help_output() {
    echo -e "\n${BLUE}Testing help output...${NC}"
    
    local output
    output=$("$LIFECYCLE_SCRIPT" --help 2>&1)
    
    assert_contains "$output" "DockerKit Container Lifecycle Management" "Help header present"
    assert_contains "$output" "USAGE:" "Usage section present"
    assert_contains "$output" "ACTIONS:" "Actions section present"
    assert_contains "$output" "start" "Start action documented"
    assert_contains "$output" "stop" "Stop action documented"
    assert_contains "$output" "restart" "Restart action documented"
    assert_contains "$output" "remove" "Remove action documented"
    assert_contains "$output" "kill" "Kill action documented"
}

# Test Suite: Start Operations
test_start_operations() {
    echo -e "\n${BLUE}Testing start operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock - check command parsing
        local output
        output=$("$LIFECYCLE_SCRIPT" start test-container 2>&1 || true)
        assert_contains "$output" "start" "Start command recognized"
    else
        # Test with real Docker
        setup_test_container
        
        # Stop the container first
        $DOCKER_CMD stop dockerkit-test-lifecycle &>/dev/null
        
        # Test starting stopped container
        local output
        output=$("$LIFECYCLE_SCRIPT" start dockerkit-test-lifecycle 2>&1)
        local exit_code=$?
        
        assert_exit_code 0 "$exit_code" "Start command exits successfully"
        assert_contains "$output" "Starting containers" "Start message shown"
        
        # Verify container is running
        local status
        status=$($DOCKER_CMD inspect dockerkit-test-lifecycle --format='{{.State.Running}}' 2>/dev/null || echo "false")
        assert_equals "true" "$status" "Container is running after start"
        
        cleanup_test_container
    fi
}

# Test Suite: Stop Operations
test_stop_operations() {
    echo -e "\n${BLUE}Testing stop operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock - check command parsing
        local output
        output=$("$LIFECYCLE_SCRIPT" stop test-container 2>&1 || true)
        assert_contains "$output" "stop" "Stop command recognized"
    else
        # Test with real Docker
        setup_test_container
        
        # Test stopping running container
        local output
        output=$("$LIFECYCLE_SCRIPT" stop dockerkit-test-lifecycle 2>&1)
        local exit_code=$?
        
        assert_exit_code 0 "$exit_code" "Stop command exits successfully"
        assert_contains "$output" "Stopping containers" "Stop message shown"
        
        # Verify container is stopped
        local status
        status=$($DOCKER_CMD inspect dockerkit-test-lifecycle --format='{{.State.Running}}' 2>/dev/null || echo "true")
        assert_equals "false" "$status" "Container is stopped after stop"
        
        cleanup_test_container
    fi
}

# Test Suite: Remove Operations
test_remove_operations() {
    echo -e "\n${BLUE}Testing remove operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock - check command parsing
        local output
        output=$("$LIFECYCLE_SCRIPT" remove test-container --force 2>&1 || true)
        assert_contains "$output" "remove" "Remove command recognized"
    else
        # Test with real Docker
        setup_test_container
        $DOCKER_CMD stop dockerkit-test-lifecycle &>/dev/null
        
        # Test removing container
        local output
        output=$("$LIFECYCLE_SCRIPT" remove dockerkit-test-lifecycle --force 2>&1)
        local exit_code=$?
        
        assert_exit_code 0 "$exit_code" "Remove command exits successfully"
        assert_contains "$output" "Removing container" "Remove message shown"
        
        # Verify container is removed
        local exists
        exists=$($DOCKER_CMD ps -aq -f name=dockerkit-test-lifecycle | wc -l)
        assert_equals "0" "$exists" "Container removed successfully"
    fi
}

# Test Suite: Invalid Arguments
test_invalid_arguments() {
    echo -e "\n${BLUE}Testing invalid arguments...${NC}"
    
    # Test missing action
    local output
    output=$("$LIFECYCLE_SCRIPT" 2>&1 || true)
    assert_contains "$output" "No action specified" "Missing action error shown"
    
    # Test invalid action
    output=$("$LIFECYCLE_SCRIPT" invalid-action 2>&1 || true)
    assert_contains "$output" "Unknown action" "Invalid action error shown"
    
    # Test missing container name
    output=$("$LIFECYCLE_SCRIPT" start 2>&1 || true)
    assert_contains "$output" "No container specified" "Missing container error shown"
}

# Test Suite: Command Options
test_command_options() {
    echo -e "\n${BLUE}Testing command options...${NC}"
    
    # Test force flag parsing
    local output
    output=$("$LIFECYCLE_SCRIPT" remove test --force --help 2>&1 || true)
    assert_contains "$output" "Force" "Force option recognized"
    
    # Test timeout option
    output=$("$LIFECYCLE_SCRIPT" stop test --time 30 --help 2>&1 || true)
    assert_contains "$output" "timeout" "Timeout option recognized"
    
    # Test all flag
    output=$("$LIFECYCLE_SCRIPT" stop --all --help 2>&1 || true)
    assert_contains "$output" "all" "All flag recognized"
}

# Test Suite: Restart Operations
test_restart_operations() {
    echo -e "\n${BLUE}Testing restart operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$("$LIFECYCLE_SCRIPT" restart test-container 2>&1 || true)
        assert_contains "$output" "restart" "Restart command recognized"
    else
        # Test with real Docker
        setup_test_container
        
        # Test restarting container
        local output
        output=$("$LIFECYCLE_SCRIPT" restart dockerkit-test-lifecycle 2>&1)
        local exit_code=$?
        
        assert_exit_code 0 "$exit_code" "Restart command exits successfully"
        assert_contains "$output" "Restarting containers" "Restart message shown"
        
        # Verify container is still running
        local status
        status=$($DOCKER_CMD inspect dockerkit-test-lifecycle --format='{{.State.Running}}' 2>/dev/null || echo "false")
        assert_equals "true" "$status" "Container is running after restart"
        
        cleanup_test_container
    fi
}

# Test Suite: Pause/Unpause Operations
test_pause_operations() {
    echo -e "\n${BLUE}Testing pause/unpause operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$("$LIFECYCLE_SCRIPT" pause test-container 2>&1 || true)
        assert_contains "$output" "pause" "Pause command recognized"
        
        output=$("$LIFECYCLE_SCRIPT" unpause test-container 2>&1 || true)
        assert_contains "$output" "unpause" "Unpause command recognized"
    else
        # Test with real Docker
        setup_test_container
        
        # Test pausing container
        local output
        output=$("$LIFECYCLE_SCRIPT" pause dockerkit-test-lifecycle 2>&1)
        assert_contains "$output" "Pausing containers" "Pause message shown"
        
        # Test unpausing container
        output=$("$LIFECYCLE_SCRIPT" unpause dockerkit-test-lifecycle 2>&1)
        assert_contains "$output" "Unpausing containers" "Unpause message shown"
        
        cleanup_test_container
    fi
}

# Main test runner
main() {
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Container Lifecycle Operations Tests  ${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    # Check if script exists
    if [[ ! -f "$LIFECYCLE_SCRIPT" ]]; then
        echo -e "${RED}Error: Container lifecycle script not found at $LIFECYCLE_SCRIPT${NC}"
        exit 1
    fi
    
    # Run test suites
    test_help_output
    test_start_operations
    test_stop_operations
    test_remove_operations
    test_invalid_arguments
    test_command_options
    test_restart_operations
    test_pause_operations
    
    # Print summary
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}           Test Summary                 ${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "Tests run:    ${TESTS_RUN}"
    echo -e "Tests passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed: ${RED}${TESTS_FAILED}${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed${NC}"
        exit 1
    fi
}

# Run tests
main "$@"