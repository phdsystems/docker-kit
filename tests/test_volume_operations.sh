#!/bin/bash

# Unit tests for DockerKit Volume Operations

set -euo pipefail

# Test setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VOLUME_SCRIPT="$DOCKERKIT_DIR/scripts/docker-volume-operations.sh"

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

# Clean up test volumes
cleanup_test_volumes() {
    if [[ "$USE_MOCK" != "true" ]]; then
        $DOCKER_CMD volume rm dockerkit-test-vol1 &>/dev/null || true
        $DOCKER_CMD volume rm dockerkit-test-vol2 &>/dev/null || true
        $DOCKER_CMD volume rm dockerkit-test-backup &>/dev/null || true
    fi
}

# Test Suite: Help and Usage
test_help_output() {
    echo -e "\n${BLUE}Testing help output...${NC}"
    
    local output
    output=$("$VOLUME_SCRIPT" --help 2>&1)
    
    assert_contains "$output" "DockerKit Volume Operations" "Help header present"
    assert_contains "$output" "USAGE:" "Usage section present"
    assert_contains "$output" "ACTIONS:" "Actions section present"
    assert_contains "$output" "create" "Create action documented"
    assert_contains "$output" "remove" "Remove action documented"
    assert_contains "$output" "inspect" "Inspect action documented"
    assert_contains "$output" "backup" "Backup action documented"
    assert_contains "$output" "restore" "Restore action documented"
    assert_contains "$output" "clone" "Clone action documented"
}

# Test Suite: Create Operations
test_create_operations() {
    echo -e "\n${BLUE}Testing create operations...${NC}"
    
    cleanup_test_volumes
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$("$VOLUME_SCRIPT" create test-volume 2>&1 || true)
        assert_contains "$output" "create" "Create command recognized"
    else
        # Test with real Docker
        local output
        output=$("$VOLUME_SCRIPT" create dockerkit-test-vol1 2>&1)
        
        assert_contains "$output" "Creating volume" "Create message shown"
        
        # Verify volume exists
        local exists
        exists=$($DOCKER_CMD volume ls -q | grep -c "dockerkit-test-vol1" || echo "0")
        assert_equals "1" "$exists" "Volume created successfully"
        
        # Test create with driver options
        output=$("$VOLUME_SCRIPT" create dockerkit-test-vol2 --driver local --label test=true 2>&1)
        assert_contains "$output" "Creating volume" "Create with options message shown"
        
        cleanup_test_volumes
    fi
}

# Test Suite: Remove Operations
test_remove_operations() {
    echo -e "\n${BLUE}Testing remove operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$("$VOLUME_SCRIPT" remove test-volume 2>&1 || true)
        assert_contains "$output" "remove" "Remove command recognized"
    else
        # Test with real Docker
        # Create a volume to remove
        $DOCKER_CMD volume create dockerkit-test-vol1 &>/dev/null
        
        local output
        output=$("$VOLUME_SCRIPT" remove dockerkit-test-vol1 --force 2>&1)
        
        assert_contains "$output" "Removing volume" "Remove message shown"
        
        # Verify volume is removed
        local exists
        exists=$($DOCKER_CMD volume ls -q | grep -c "dockerkit-test-vol1" || echo "0")
        assert_equals "0" "$exists" "Volume removed successfully"
    fi
}

# Test Suite: List Operations
test_list_operations() {
    echo -e "\n${BLUE}Testing list operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$("$VOLUME_SCRIPT" list 2>&1 || true)
        assert_contains "$output" "list" "List command recognized"
    else
        # Test with real Docker
        # Create test volumes
        $DOCKER_CMD volume create dockerkit-test-vol1 &>/dev/null
        $DOCKER_CMD volume create dockerkit-test-vol2 &>/dev/null
        
        local output
        output=$("$VOLUME_SCRIPT" list 2>&1)
        
        assert_contains "$output" "Listing volumes" "List message shown"
        
        # Test with filter
        output=$("$VOLUME_SCRIPT" list --filter "name=dockerkit-test" 2>&1)
        assert_contains "$output" "dockerkit-test" "Filtered list works"
        
        cleanup_test_volumes
    fi
}

# Test Suite: Inspect Operations
test_inspect_operations() {
    echo -e "\n${BLUE}Testing inspect operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$("$VOLUME_SCRIPT" inspect test-volume 2>&1 || true)
        assert_contains "$output" "inspect" "Inspect command recognized"
    else
        # Test with real Docker
        # Create a volume to inspect
        $DOCKER_CMD volume create dockerkit-test-vol1 &>/dev/null
        
        local output
        output=$("$VOLUME_SCRIPT" inspect dockerkit-test-vol1 2>&1)
        
        assert_contains "$output" "Inspecting volume" "Inspect message shown"
        
        cleanup_test_volumes
    fi
}

# Test Suite: Backup/Restore Operations
test_backup_restore_operations() {
    echo -e "\n${BLUE}Testing backup/restore operations...${NC}"
    
    local test_dir="/tmp/dockerkit-test-$$"
    mkdir -p "$test_dir"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$("$VOLUME_SCRIPT" backup test-volume -o "$test_dir/backup.tar" 2>&1 || true)
        assert_contains "$output" "backup" "Backup command recognized"
        
        output=$("$VOLUME_SCRIPT" restore test-volume -i "$test_dir/backup.tar" 2>&1 || true)
        assert_contains "$output" "restore" "Restore command recognized"
    else
        # Test with real Docker
        # Create a volume with some data
        $DOCKER_CMD volume create dockerkit-test-backup &>/dev/null
        $DOCKER_CMD run --rm -v dockerkit-test-backup:/data alpine sh -c "echo 'test data' > /data/test.txt"
        
        # Test backup
        local output
        output=$(cd "$test_dir" && "$VOLUME_SCRIPT" backup dockerkit-test-backup -o backup.tar 2>&1)
        assert_contains "$output" "Backing up volume" "Backup message shown"
        
        # Note: Full restore test would require more complex setup
        # Just test the command parsing for now
        
        cleanup_test_volumes
    fi
    
    # Clean up
    rm -rf "$test_dir"
}

# Test Suite: Clone Operations
test_clone_operations() {
    echo -e "\n${BLUE}Testing clone operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$("$VOLUME_SCRIPT" clone source-vol target-vol 2>&1 || true)
        assert_contains "$output" "clone" "Clone command recognized"
    else
        # Test with real Docker
        # Create source volume with data
        $DOCKER_CMD volume create dockerkit-test-vol1 &>/dev/null
        $DOCKER_CMD run --rm -v dockerkit-test-vol1:/data alpine sh -c "echo 'test' > /data/file.txt"
        
        # Test cloning
        local output
        output=$("$VOLUME_SCRIPT" clone dockerkit-test-vol1 dockerkit-test-vol2 2>&1)
        
        assert_contains "$output" "Cloning volume" "Clone message shown"
        
        # Verify target volume exists
        local exists
        exists=$($DOCKER_CMD volume ls -q | grep -c "dockerkit-test-vol2" || echo "0")
        assert_equals "1" "$exists" "Target volume created"
        
        cleanup_test_volumes
    fi
}

# Test Suite: Invalid Arguments
test_invalid_arguments() {
    echo -e "\n${BLUE}Testing invalid arguments...${NC}"
    
    # Test missing action
    local output
    output=$("$VOLUME_SCRIPT" 2>&1 || true)
    assert_contains "$output" "No action specified" "Missing action error shown"
    
    # Test missing volume name for create
    output=$("$VOLUME_SCRIPT" create 2>&1 || true)
    assert_contains "$output" "No volume name specified" "Missing volume name error shown"
    
    # Test missing source for clone
    output=$("$VOLUME_SCRIPT" clone 2>&1 || true)
    assert_contains "$output" "required" "Missing clone arguments error shown"
}

# Main test runner
main() {
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}       Volume Operations Tests          ${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    # Check if script exists
    if [[ ! -f "$VOLUME_SCRIPT" ]]; then
        echo -e "${RED}Error: Volume operations script not found at $VOLUME_SCRIPT${NC}"
        exit 1
    fi
    
    # Run test suites
    test_help_output
    test_create_operations
    test_remove_operations
    test_list_operations
    test_inspect_operations
    test_backup_restore_operations
    test_clone_operations
    test_invalid_arguments
    
    # Clean up any remaining test volumes
    cleanup_test_volumes
    
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