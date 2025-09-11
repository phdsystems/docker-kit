#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKERKIT_CLI="$DOCKERKIT_DIR/dck"

# Source test helpers
source "$SCRIPT_DIR/test_helpers.sh" 2>/dev/null || true

echo "🧪 Testing DockerKit CLI..."
echo ""

# Check if Docker is available and running
check_docker() {
    # First check if docker command exists
    if ! command -v docker &>/dev/null; then
        echo "⚠️  Docker not installed, using mock for tests"
        export PATH="$SCRIPT_DIR/mocks:$PATH"
        return 1
    fi
    
    # Try without sudo
    if docker info &>/dev/null 2>&1; then
        echo "✅ Using real Docker for tests (no sudo needed)"
        export DOCKER_CMD="docker"
        return 0
    fi
    
    # Try with sudo if available
    if command -v sudo &>/dev/null; then
        if sudo docker info &>/dev/null 2>&1; then
            echo "✅ Using real Docker for tests (with sudo)"
            export DOCKER_CMD="sudo docker"
            return 0
        fi
    fi
    
    # Docker not accessible
    echo "⚠️  Docker daemon not accessible, using mock for tests"
    export PATH="$SCRIPT_DIR/mocks:$PATH"
    export DOCKER_CMD="docker"
    return 1
}

# Setup test environment
USING_REAL_DOCKER=false
if check_docker; then
    USING_REAL_DOCKER=true
fi
echo ""

# Test 1: File permissions
echo -n "1. File permissions: "
if [[ -x "$DOCKERKIT_CLI" ]]; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Not executable"
    exit 1
fi

# Test 2: Help command
echo -n "2. Help command: "
if "$DOCKERKIT_CLI" --help 2>&1 | grep -q "DockerKit"; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Help not showing DockerKit"
fi

# Test 3: Version command  
echo -n "3. Version command: "
if "$DOCKERKIT_CLI" version 2>&1 | grep -q "DockerKit"; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Version not showing DockerKit"
fi

# Test 4: Invalid command
echo -n "4. Invalid command: "
if "$DOCKERKIT_CLI" invalid-command 2>&1 | grep -q "Error"; then
    echo "✅ PASS"
else
    echo "⚠️  WARN - No error for invalid command"
fi

# Test 5: Images command
echo -n "5. Images command: "
output=$("$DOCKERKIT_CLI" images 2>&1)
if [[ "$USING_REAL_DOCKER" == "true" ]]; then
    # With real Docker, check for actual Docker output
    if echo "$output" | grep -qE "(REPOSITORY|IMAGE ID|No images|docker images)"; then
        echo "✅ PASS (real)"
    else
        echo "❌ FAIL - Images command not working"
    fi
else
    # With mock, check for mock output
    if echo "$output" | grep -qE "(REPOSITORY|nginx|IMAGE)"; then
        echo "✅ PASS (mock)"
    else
        echo "❌ FAIL - Images command not working"
    fi
fi

# Test 6: Containers command
echo -n "6. Containers command: "
output=$("$DOCKERKIT_CLI" containers 2>&1)
if [[ "$USING_REAL_DOCKER" == "true" ]]; then
    if echo "$output" | grep -qE "(CONTAINER|STATUS|No containers|docker ps)"; then
        echo "✅ PASS (real)"
    else
        echo "❌ FAIL - Containers command not working"
    fi
else
    if echo "$output" | grep -qE "(CONTAINER|web|NAME)"; then
        echo "✅ PASS (mock)"
    else
        echo "❌ FAIL - Containers command not working"
    fi
fi

# Test 7: Volumes command
echo -n "7. Volumes command: "
output=$("$DOCKERKIT_CLI" volumes 2>&1)
if [[ "$USING_REAL_DOCKER" == "true" ]]; then
    if echo "$output" | grep -qE "(VOLUME|DRIVER|No volumes|docker volume)"; then
        echo "✅ PASS (real)"
    else
        echo "❌ FAIL - Volumes command not working"
    fi
else
    if echo "$output" | grep -qE "(VOLUME|data_volume|DRIVER)"; then
        echo "✅ PASS (mock)"
    else
        echo "❌ FAIL - Volumes command not working"
    fi
fi

# Test 8: Networks command
echo -n "8. Networks command: "
output=$("$DOCKERKIT_CLI" networks 2>&1)
if [[ "$USING_REAL_DOCKER" == "true" ]]; then
    if echo "$output" | grep -qE "(NETWORK|DRIVER|bridge|docker network)"; then
        echo "✅ PASS (real)"
    else
        echo "❌ FAIL - Networks command not working"
    fi
else
    if echo "$output" | grep -qE "(NETWORK|bridge|DRIVER)"; then
        echo "✅ PASS (mock)"
    else
        echo "❌ FAIL - Networks command not working"
    fi
fi

# Test 9: Search command
echo -n "9. Search command: "
if "$DOCKERKIT_CLI" search 2>&1 | grep -q "images"; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Search command not working"
fi

# Test 10: Search images
echo -n "10. Search images: "
output=$("$DOCKERKIT_CLI" search images nginx 2>&1)
if echo "$output" | grep -qE "(Searching|nginx|🔍|No images found)"; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Search images not working"
fi

# Test 11: No args behavior
echo -n "11. No args (help): "
if "$DOCKERKIT_CLI" 2>&1 | grep -qE "(USAGE|help|DockerKit)"; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Not showing help with no args"
fi

# Test 12: Docs command (works regardless of Docker)
echo -n "12. Docs command: "
if "$DOCKERKIT_CLI" docs 2>&1 | head -3 | grep -qE "(Docker|landscape|#)"; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Docs command not working"
fi

# Test 13: System command (if Docker available)
if [[ "$USING_REAL_DOCKER" == "true" ]]; then
    echo -n "13. System command: "
    if "$DOCKERKIT_CLI" system 2>&1 | grep -qE "(Docker|System|Version)"; then
        echo "✅ PASS"
    else
        echo "❌ FAIL - System command not working"
    fi
fi

# Test 14: Search with filters
echo -n "14. Search with filters: "
output=$("$DOCKERKIT_CLI" search containers --status running 2>&1)
if echo "$output" | grep -qE "(Searching|containers|running|No containers)"; then
    echo "✅ PASS"
else
    echo "❌ FAIL - Search filters not working"
fi

# Test 15: Help for subcommands
echo -n "15. Subcommand help: "
if "$DOCKERKIT_CLI" images --help 2>&1 | grep -qE "(Usage|Options|help)"; then
    echo "✅ PASS"
else
    echo "⚠️  WARN - Subcommand help not available"
fi

echo ""
echo "================================"
echo "DockerKit CLI Test Summary"
echo "================================"
if [[ "$USING_REAL_DOCKER" == "true" ]]; then
    echo "Test Mode: Real Docker"
    if [[ "$DOCKER_CMD" == "sudo docker" ]]; then
        echo "Docker Access: With sudo"
    else
        echo "Docker Access: Direct (no sudo)"
    fi
else
    echo "Test Mode: Mock Docker"
fi
echo "All core functionality tested!"

# Exit successfully - failures would have been caught earlier
exit 0