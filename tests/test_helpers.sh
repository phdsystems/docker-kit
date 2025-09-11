#!/bin/bash

# Shared test helpers for DockerKit tests

# Global variable for Docker command (with or without sudo)
DOCKER_CMD="docker"

# Check if Docker needs sudo
check_docker_needs_sudo() {
    # First try without sudo
    if docker info &>/dev/null 2>&1; then
        echo "ℹ️  Docker works without sudo"
        DOCKER_CMD="docker"
        return 0
    fi
    
    # Try with sudo if available
    if command -v sudo &>/dev/null; then
        if sudo docker info &>/dev/null 2>&1; then
            echo "ℹ️  Docker requires sudo"
            DOCKER_CMD="sudo docker"
            return 0
        fi
    fi
    
    # Docker not accessible
    return 1
}

# Check if Docker is available and set up test environment
setup_docker_test_env() {
    local script_dir="${1:-$(pwd)}"
    
    if command -v docker &>/dev/null; then
        if check_docker_needs_sudo; then
            echo "ℹ️  Using real Docker for tests"
            export DOCKERKIT_TEST_MODE="real"
            export DOCKER_CMD
            return 0
        fi
    fi
    
    echo "ℹ️  Docker not available, using mock for tests"
    export PATH="$script_dir/mocks:$PATH"
    export DOCKERKIT_TEST_MODE="mock"
    export DOCKER_CMD="docker"  # Mock doesn't need sudo
    return 1
}

# Check test output based on mode
check_output_for_mode() {
    local output="$1"
    local real_pattern="$2"
    local mock_pattern="$3"
    
    if [[ "${DOCKERKIT_TEST_MODE}" == "real" ]]; then
        echo "$output" | grep -qE "$real_pattern"
    else
        echo "$output" | grep -qE "$mock_pattern"
    fi
}

# Print test result with mode indicator
print_test_result() {
    local test_name="$1"
    local passed="$2"
    
    if [[ "$passed" == "true" ]]; then
        if [[ "${DOCKERKIT_TEST_MODE}" == "real" ]]; then
            echo "✅ PASS (real Docker)"
        else
            echo "✅ PASS (mock)"
        fi
    else
        echo "❌ FAIL"
    fi
}

# Execute Docker command with proper permissions
run_docker() {
    $DOCKER_CMD "$@"
}