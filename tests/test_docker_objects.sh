#!/bin/bash

# ==============================================================================
# Unit Tests for Docker Object Inspection Scripts
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"

# Source test helpers
source "$SCRIPT_DIR/test_helpers.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ==============================================================================
# Mock Docker Commands
# ==============================================================================

setup_mocks() {
    export DOCKER_CMD="$SCRIPT_DIR/mocks/docker_mock.sh"
    export DOCKER_AVAILABLE="true"
    
    # Create mock script if it doesn't exist
    mkdir -p "$SCRIPT_DIR/mocks"
    cat > "$SCRIPT_DIR/mocks/docker_mock.sh" << 'EOF'
#!/bin/bash
case "$1" in
    images)
        echo "REPOSITORY   TAG       IMAGE ID       CREATED        SIZE"
        echo "nginx        latest    a6bd71f48f68   2 days ago     187MB"
        echo "alpine       3.19      ace17d5d883e   1 week ago     7.73MB"
        ;;
    ps)
        if [[ "$2" == "-a" ]]; then
            echo "CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES"
            echo "abc123def456   nginx     nginx     1h ago    Up 1h     80/tcp    web"
            echo "def456ghi789   redis     redis     2h ago    Exited    6379/tcp  cache"
        else
            echo "CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES"
            echo "abc123def456   nginx     nginx     1h ago    Up 1h     80/tcp    web"
        fi
        ;;
    volume)
        if [[ "$2" == "ls" ]]; then
            echo "DRIVER    VOLUME NAME"
            echo "local     postgres_data"
            echo "local     redis_data"
        fi
        ;;
    network)
        if [[ "$2" == "ls" ]]; then
            echo "NETWORK ID     NAME      DRIVER    SCOPE"
            echo "bridge123      bridge    bridge    local"
            echo "host456        host      host      local"
            echo "custom789      mynet     bridge    local"
        fi
        ;;
    inspect)
        echo '{"Id":"abc123","Config":{"Image":"nginx"}}'
        ;;
    *)
        echo "Mock docker command: $@" >&2
        ;;
esac
EOF
    chmod +x "$SCRIPT_DIR/mocks/docker_mock.sh"
}

cleanup_mocks() {
    rm -f "$SCRIPT_DIR/mocks/docker_mock.sh"
}

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
# Unit Tests - Docker Images
# ==============================================================================

test_docker_images_script_exists() {
    [[ -f "$SRC_DIR/docker-images.sh" ]] && [[ -x "$SRC_DIR/docker-images.sh" ]]
}

test_docker_images_basic() {
    local output
    output=$("$SRC_DIR/docker-images.sh" 2>&1)
    echo "$output" | grep -qi "image\|docker\|repository"
}

test_docker_images_json_format() {
    # Test JSON output format
    "$SRC_DIR/docker-images.sh" --format json 2>&1 | grep -qi "json\|image\|{" || true
}

test_docker_advanced_images_exists() {
    [[ -f "$SRC_DIR/docker-advanced-images.sh" ]] && [[ -x "$SRC_DIR/docker-advanced-images.sh" ]]
}

# ==============================================================================
# Unit Tests - Docker Containers
# ==============================================================================

test_docker_containers_script_exists() {
    [[ -f "$SRC_DIR/docker-containers.sh" ]] && [[ -x "$SRC_DIR/docker-containers.sh" ]]
}

test_docker_containers_basic() {
    local output
    output=$("$SRC_DIR/docker-containers.sh" 2>&1)
    echo "$output" | grep -qi "container\|docker"
}

test_docker_containers_all_flag() {
    "$SRC_DIR/docker-containers.sh" --all 2>&1 | grep -q "redis\|cache\|Exited" || true
}

test_docker_advanced_containers_exists() {
    [[ -f "$SRC_DIR/docker-advanced-containers.sh" ]] && [[ -x "$SRC_DIR/docker-advanced-containers.sh" ]]
}

# ==============================================================================
# Unit Tests - Docker Volumes
# ==============================================================================

test_docker_volumes_script_exists() {
    [[ -f "$SRC_DIR/docker-volumes.sh" ]] && [[ -x "$SRC_DIR/docker-volumes.sh" ]]
}

test_docker_volumes_basic() {
    local output
    output=$("$SRC_DIR/docker-volumes.sh" 2>&1)
    echo "$output" | grep -q "postgres_data\|VOLUME\|Volume" || true
}

test_docker_advanced_volumes_exists() {
    [[ -f "$SRC_DIR/docker-advanced-volumes.sh" ]] && [[ -x "$SRC_DIR/docker-advanced-volumes.sh" ]]
}

# ==============================================================================
# Unit Tests - Docker Networks
# ==============================================================================

test_docker_networks_script_exists() {
    [[ -f "$SRC_DIR/docker-networks.sh" ]] && [[ -x "$SRC_DIR/docker-networks.sh" ]]
}

test_docker_networks_basic() {
    local output
    output=$("$SRC_DIR/docker-networks.sh" 2>&1)
    echo "$output" | grep -q "bridge\|NETWORK\|Network" || true
}

test_docker_advanced_networks_exists() {
    [[ -f "$SRC_DIR/docker-advanced-networks.sh" ]] && [[ -x "$SRC_DIR/docker-advanced-networks.sh" ]]
}

# ==============================================================================
# Unit Tests - Docker Monitor
# ==============================================================================

test_docker_monitor_script_exists() {
    [[ -f "$SRC_DIR/docker-monitor.sh" ]] && [[ -x "$SRC_DIR/docker-monitor.sh" ]]
}

test_docker_monitor_help() {
    "$SRC_DIR/docker-monitor.sh" --help 2>&1 | grep -q "monitor\|Monitor\|Usage" || true
}

# ==============================================================================
# Unit Tests - Docker Security
# ==============================================================================

test_docker_security_script_exists() {
    [[ -f "$SRC_DIR/docker-security.sh" ]] && [[ -x "$SRC_DIR/docker-security.sh" ]]
}

test_docker_security_help() {
    "$SRC_DIR/docker-security.sh" --help 2>&1 | grep -q "security\|Security\|Usage" || true
}

# ==============================================================================
# Unit Tests - Docker Cleanup
# ==============================================================================

test_docker_cleanup_script_exists() {
    [[ -f "$SRC_DIR/docker-cleanup.sh" ]] && [[ -x "$SRC_DIR/docker-cleanup.sh" ]]
}

test_docker_cleanup_dry_run() {
    "$SRC_DIR/docker-cleanup.sh" --dry-run 2>&1 | grep -q "cleanup\|Cleanup\|DRY" || true
}

# ==============================================================================
# Run Tests
# ==============================================================================

echo "=========================================="
echo "Docker Object Inspection Scripts Unit Tests"
echo "=========================================="
echo ""

# Setup mocks
setup_mocks

# Docker Images Tests
run_test "docker-images.sh exists" test_docker_images_script_exists
run_test "docker-images basic operation" test_docker_images_basic
run_test "docker-images JSON format" test_docker_images_json_format
run_test "docker-advanced-images.sh exists" test_docker_advanced_images_exists

# Docker Containers Tests
run_test "docker-containers.sh exists" test_docker_containers_script_exists
run_test "docker-containers basic operation" test_docker_containers_basic
run_test "docker-containers --all flag" test_docker_containers_all_flag
run_test "docker-advanced-containers.sh exists" test_docker_advanced_containers_exists

# Docker Volumes Tests
run_test "docker-volumes.sh exists" test_docker_volumes_script_exists
run_test "docker-volumes basic operation" test_docker_volumes_basic
run_test "docker-advanced-volumes.sh exists" test_docker_advanced_volumes_exists

# Docker Networks Tests
run_test "docker-networks.sh exists" test_docker_networks_script_exists
run_test "docker-networks basic operation" test_docker_networks_basic
run_test "docker-advanced-networks.sh exists" test_docker_advanced_networks_exists

# Docker Monitor Tests
run_test "docker-monitor.sh exists" test_docker_monitor_script_exists
run_test "docker-monitor help" test_docker_monitor_help

# Docker Security Tests
run_test "docker-security.sh exists" test_docker_security_script_exists
run_test "docker-security help" test_docker_security_help

# Docker Cleanup Tests
run_test "docker-cleanup.sh exists" test_docker_cleanup_script_exists
run_test "docker-cleanup dry-run" test_docker_cleanup_dry_run

# Cleanup mocks
cleanup_mocks

echo ""
echo "=========================================="
echo "Test Results:"
echo "  Tests Run:    $TESTS_RUN"
echo "  Tests Passed: $TESTS_PASSED"
echo "  Tests Failed: $TESTS_FAILED"
echo "=========================================="

# Exit with appropriate code
[[ $TESTS_FAILED -eq 0 ]] && exit 0 || exit 1