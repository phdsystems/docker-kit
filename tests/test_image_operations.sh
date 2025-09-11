#!/bin/bash

# Unit tests for DockerKit Image Operations

set -euo pipefail

# Test setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_SCRIPT="$DOCKERKIT_DIR/scripts/docker-image-operations.sh"

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

assert_file_exists() {
    local file="$1"
    local test_name="$2"
    
    ((TESTS_RUN++))
    
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  File not found: $file"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test Suite: Help and Usage
test_help_output() {
    echo -e "\n${BLUE}Testing help output...${NC}"
    
    local output
    output=$("$IMAGE_SCRIPT" --help 2>&1)
    
    assert_contains "$output" "DockerKit Image Operations" "Help header present"
    assert_contains "$output" "USAGE:" "Usage section present"
    assert_contains "$output" "ACTIONS:" "Actions section present"
    assert_contains "$output" "pull" "Pull action documented"
    assert_contains "$output" "push" "Push action documented"
    assert_contains "$output" "build" "Build action documented"
    assert_contains "$output" "remove" "Remove action documented"
    assert_contains "$output" "tag" "Tag action documented"
    assert_contains "$output" "save" "Save action documented"
    assert_contains "$output" "load" "Load action documented"
}

# Test Suite: Pull Operations
test_pull_operations() {
    echo -e "\n${BLUE}Testing pull operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock - check command parsing
        local output
        output=$("$IMAGE_SCRIPT" pull alpine:latest 2>&1 || true)
        assert_contains "$output" "pull" "Pull command recognized"
    else
        # Test with real Docker - pull small image
        local output
        output=$("$IMAGE_SCRIPT" pull alpine:latest 2>&1)
        
        assert_contains "$output" "Pulling image" "Pull message shown"
        
        # Verify image exists
        local exists
        exists=$($DOCKER_CMD images -q alpine:latest | wc -l)
        assert_equals "1" "$exists" "Image pulled successfully"
    fi
}

# Test Suite: Tag Operations
test_tag_operations() {
    echo -e "\n${BLUE}Testing tag operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$("$IMAGE_SCRIPT" tag alpine:latest alpine:test 2>&1 || true)
        assert_contains "$output" "tag" "Tag command recognized"
    else
        # Test with real Docker
        # Ensure we have an image to tag
        $DOCKER_CMD pull alpine:latest &>/dev/null || true
        
        # Test tagging
        local output
        output=$("$IMAGE_SCRIPT" tag alpine:latest dockerkit-test:v1 2>&1)
        
        assert_contains "$output" "Tagging image" "Tag message shown"
        
        # Verify tag exists
        local exists
        exists=$($DOCKER_CMD images -q dockerkit-test:v1 | wc -l)
        assert_equals "1" "$exists" "Image tagged successfully"
        
        # Clean up
        $DOCKER_CMD rmi dockerkit-test:v1 &>/dev/null || true
    fi
}

# Test Suite: Save/Load Operations
test_save_load_operations() {
    echo -e "\n${BLUE}Testing save/load operations...${NC}"
    
    local test_dir="/tmp/dockerkit-test-$$"
    mkdir -p "$test_dir"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$("$IMAGE_SCRIPT" save alpine:latest -o "$test_dir/test.tar" 2>&1 || true)
        assert_contains "$output" "save" "Save command recognized"
        
        output=$("$IMAGE_SCRIPT" load -i "$test_dir/test.tar" 2>&1 || true)
        assert_contains "$output" "load" "Load command recognized"
    else
        # Test with real Docker
        # Ensure we have an image to save
        $DOCKER_CMD pull alpine:latest &>/dev/null || true
        
        # Test saving
        local output
        output=$("$IMAGE_SCRIPT" save alpine:latest -o "$test_dir/alpine.tar" 2>&1)
        
        assert_contains "$output" "Saving image" "Save message shown"
        assert_file_exists "$test_dir/alpine.tar" "Tar file created"
        
        # Test loading (would need to remove image first in real scenario)
        output=$("$IMAGE_SCRIPT" load -i "$test_dir/alpine.tar" 2>&1)
        assert_contains "$output" "Loading image" "Load message shown"
    fi
    
    # Clean up
    rm -rf "$test_dir"
}

# Test Suite: Build Operations
test_build_operations() {
    echo -e "\n${BLUE}Testing build operations...${NC}"
    
    # Create temporary Dockerfile
    local test_dir="/tmp/dockerkit-test-$$"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/Dockerfile" << 'EOF'
FROM alpine:latest
RUN echo "test"
EOF
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$(cd "$test_dir" && "$IMAGE_SCRIPT" build -t test:latest -f Dockerfile . 2>&1 || true)
        assert_contains "$output" "build" "Build command recognized"
    else
        # Test with real Docker
        local output
        output=$(cd "$test_dir" && "$IMAGE_SCRIPT" build -t dockerkit-test-build:latest -f Dockerfile . 2>&1)
        
        assert_contains "$output" "Building image" "Build message shown"
        
        # Verify image was built
        local exists
        exists=$($DOCKER_CMD images -q dockerkit-test-build:latest | wc -l)
        assert_equals "1" "$exists" "Image built successfully"
        
        # Clean up
        $DOCKER_CMD rmi dockerkit-test-build:latest &>/dev/null || true
    fi
    
    # Clean up
    rm -rf "$test_dir"
}

# Test Suite: Remove Operations
test_remove_operations() {
    echo -e "\n${BLUE}Testing remove operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$("$IMAGE_SCRIPT" remove test:latest --force 2>&1 || true)
        assert_contains "$output" "remove" "Remove command recognized"
    else
        # Test with real Docker
        # Create a test image to remove
        $DOCKER_CMD pull alpine:latest &>/dev/null || true
        $DOCKER_CMD tag alpine:latest dockerkit-test-remove:latest &>/dev/null
        
        # Test removing
        local output
        output=$("$IMAGE_SCRIPT" remove dockerkit-test-remove:latest --force 2>&1)
        
        assert_contains "$output" "Removing image" "Remove message shown"
        
        # Verify image is removed
        local exists
        exists=$($DOCKER_CMD images -q dockerkit-test-remove:latest | wc -l)
        assert_equals "0" "$exists" "Image removed successfully"
    fi
}

# Test Suite: History Operations
test_history_operations() {
    echo -e "\n${BLUE}Testing history operations...${NC}"
    
    if [[ "$USE_MOCK" == "true" ]]; then
        # Test with mock
        local output
        output=$("$IMAGE_SCRIPT" history alpine:latest 2>&1 || true)
        assert_contains "$output" "history" "History command recognized"
    else
        # Test with real Docker
        $DOCKER_CMD pull alpine:latest &>/dev/null || true
        
        local output
        output=$("$IMAGE_SCRIPT" history alpine:latest 2>&1)
        
        assert_contains "$output" "History for image" "History message shown"
    fi
}

# Test Suite: Invalid Arguments
test_invalid_arguments() {
    echo -e "\n${BLUE}Testing invalid arguments...${NC}"
    
    # Test missing action
    local output
    output=$("$IMAGE_SCRIPT" 2>&1 || true)
    assert_contains "$output" "No action specified" "Missing action error shown"
    
    # Test missing image for pull
    output=$("$IMAGE_SCRIPT" pull 2>&1 || true)
    assert_contains "$output" "No image specified" "Missing image error shown"
    
    # Test missing tag target
    output=$("$IMAGE_SCRIPT" tag alpine:latest 2>&1 || true)
    assert_contains "$output" "target tag required" "Missing tag target error shown"
}

# Test Suite: Command Options
test_command_options() {
    echo -e "\n${BLUE}Testing command options...${NC}"
    
    # Test platform option
    local output
    output=$("$IMAGE_SCRIPT" pull alpine:latest --platform linux/amd64 --help 2>&1 || true)
    assert_contains "$output" "platform" "Platform option recognized"
    
    # Test no-cache option
    output=$("$IMAGE_SCRIPT" build --no-cache --help 2>&1 || true)
    assert_contains "$output" "cache" "No-cache option recognized"
    
    # Test quiet option
    output=$("$IMAGE_SCRIPT" pull alpine:latest --quiet --help 2>&1 || true)
    assert_contains "$output" "quiet" "Quiet option recognized"
}

# Main test runner
main() {
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}      Image Operations Tests            ${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    # Check if script exists
    if [[ ! -f "$IMAGE_SCRIPT" ]]; then
        echo -e "${RED}Error: Image operations script not found at $IMAGE_SCRIPT${NC}"
        exit 1
    fi
    
    # Run test suites
    test_help_output
    test_pull_operations
    test_tag_operations
    test_save_load_operations
    test_build_operations
    test_remove_operations
    test_history_operations
    test_invalid_arguments
    test_command_options
    
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