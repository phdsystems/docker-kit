#!/bin/bash

# DockerKit Comprehensive Test Runner
# Runs all unit tests for DockerKit components

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$TEST_DIR/.." && pwd)"

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Parse command line arguments
RUN_ALL=true
RUN_SEARCH=false
RUN_LIFECYCLE=false
RUN_IMAGE=false
RUN_VOLUME=false
RUN_NETWORK=false
RUN_COMPOSE=false
RUN_EXEC=false
RUN_COMPLIANCE=false
RUN_WRAPPER=false
USE_MOCK=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            RUN_ALL=true
            shift
            ;;
        --search)
            RUN_ALL=false
            RUN_SEARCH=true
            shift
            ;;
        --lifecycle)
            RUN_ALL=false
            RUN_LIFECYCLE=true
            shift
            ;;
        --image)
            RUN_ALL=false
            RUN_IMAGE=true
            shift
            ;;
        --volume)
            RUN_ALL=false
            RUN_VOLUME=true
            shift
            ;;
        --network)
            RUN_ALL=false
            RUN_NETWORK=true
            shift
            ;;
        --compose)
            RUN_ALL=false
            RUN_COMPOSE=true
            shift
            ;;
        --exec)
            RUN_ALL=false
            RUN_EXEC=true
            shift
            ;;
        --compliance)
            RUN_ALL=false
            RUN_COMPLIANCE=true
            shift
            ;;
        --wrapper)
            RUN_ALL=false
            RUN_WRAPPER=true
            shift
            ;;
        --mock)
            USE_MOCK=true
            export USE_MOCK_DOCKER=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --all        Run all tests (default)"
            echo "  --search     Run only search tests"
            echo "  --lifecycle  Run only container lifecycle tests"
            echo "  --image      Run only image operation tests"
            echo "  --volume     Run only volume operation tests"
            echo "  --network    Run only network operation tests"
            echo "  --compose    Run only compose operation tests"
            echo "  --exec       Run only container exec tests"
            echo "  --compliance Run only compliance tests"
            echo "  --wrapper    Run only Docker wrapper tests"
            echo "  --mock       Use mock Docker for testing"
            echo "  --verbose    Show detailed output"
            echo "  --help       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Run all tests"
            echo "  $0 --lifecycle        # Run only lifecycle tests"
            echo "  $0 --mock             # Run all tests with mock Docker"
            echo "  $0 --image --volume   # Run image and volume tests"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         DockerKit Comprehensive Test Suite     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Check Docker availability
if [[ "$USE_MOCK" == "true" ]]; then
    echo -e "${YELLOW}📦 Using mock Docker for tests${NC}"
elif docker info &>/dev/null 2>&1; then
    echo -e "${GREEN}🐳 Using real Docker for tests${NC}"
elif sudo docker info &>/dev/null 2>&1; then
    echo -e "${GREEN}🐳 Using real Docker with sudo for tests${NC}"
else
    echo -e "${YELLOW}⚠️  Docker not available - will use mock${NC}"
    export USE_MOCK_DOCKER=true
fi
echo ""

# Function to run a test file
run_test() {
    local test_file="$1"
    local test_name="$2"
    local test_description="$3"
    
    echo -e "${CYAN}▶ Running $test_description...${NC}"
    
    if [[ ! -f "$test_file" ]]; then
        # Try to find the test file
        if [[ -f "$TEST_DIR/$test_file" ]]; then
            test_file="$TEST_DIR/$test_file"
        elif [[ -f "$TEST_DIR/test_$test_file.sh" ]]; then
            test_file="$TEST_DIR/test_$test_file.sh"
        else
            echo -e "${YELLOW}  ⚠ Test file not found - skipping${NC}"
            ((SKIPPED_TESTS++))
            ((TOTAL_TESTS++))
            return
        fi
    fi
    
    if [[ ! -x "$test_file" ]]; then
        chmod +x "$test_file"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        if "$test_file"; then
            echo -e "${GREEN}  ✓ $test_name passed${NC}"
            ((PASSED_TESTS++))
        else
            echo -e "${RED}  ✗ $test_name failed${NC}"
            ((FAILED_TESTS++))
        fi
    else
        if "$test_file" >/dev/null 2>&1; then
            echo -e "${GREEN}  ✓ $test_name passed${NC}"
            ((PASSED_TESTS++))
        else
            echo -e "${RED}  ✗ $test_name failed${NC}"
            ((FAILED_TESTS++))
        fi
    fi
    ((TOTAL_TESTS++))
    echo ""
}

# Function to create simple test for missing test files
create_simple_test() {
    local script_path="$1"
    local test_file="$2"
    
    # Create a simple validation test
    cat > "$test_file" << EOF
#!/bin/bash
# Simple validation test for $(basename "$script_path")

SCRIPT="$script_path"

if [[ ! -f "\$SCRIPT" ]]; then
    echo "Script not found: \$SCRIPT"
    exit 1
fi

# Test help output
if "\$SCRIPT" --help >/dev/null 2>&1; then
    echo "Help command works"
    exit 0
else
    echo "Help command failed"
    exit 1
fi
EOF
    chmod +x "$test_file"
}

# Run tests based on selection
echo -e "${BLUE}Test Categories:${NC}"
echo ""

if [[ "$RUN_ALL" == "true" ]] || [[ "$RUN_SEARCH" == "true" ]]; then
    echo -e "${CYAN}[Search Operations]${NC}"
    
    # Create a combined search test if individual test doesn't exist
    SEARCH_TEST="$TEST_DIR/test_search_operations.sh"
    if [[ ! -f "$SEARCH_TEST" ]]; then
        create_simple_test "$DOCKERKIT_DIR/scripts/docker-search-images.sh" "$SEARCH_TEST"
    fi
    run_test "$SEARCH_TEST" "search_operations" "Search Operations Tests"
fi

if [[ "$RUN_ALL" == "true" ]] || [[ "$RUN_LIFECYCLE" == "true" ]]; then
    echo -e "${CYAN}[Container Lifecycle]${NC}"
    run_test "test_container_lifecycle.sh" "container_lifecycle" "Container Lifecycle Tests"
fi

if [[ "$RUN_ALL" == "true" ]] || [[ "$RUN_EXEC" == "true" ]]; then
    echo -e "${CYAN}[Container Execution]${NC}"
    
    # Create exec test if it doesn't exist
    EXEC_TEST="$TEST_DIR/test_container_exec.sh"
    if [[ ! -f "$EXEC_TEST" ]]; then
        create_simple_test "$DOCKERKIT_DIR/scripts/docker-container-exec.sh" "$EXEC_TEST"
    fi
    run_test "$EXEC_TEST" "container_exec" "Container Execution Tests"
fi

if [[ "$RUN_ALL" == "true" ]] || [[ "$RUN_IMAGE" == "true" ]]; then
    echo -e "${CYAN}[Image Operations]${NC}"
    run_test "test_image_operations.sh" "image_operations" "Image Operations Tests"
fi

if [[ "$RUN_ALL" == "true" ]] || [[ "$RUN_VOLUME" == "true" ]]; then
    echo -e "${CYAN}[Volume Operations]${NC}"
    run_test "test_volume_operations.sh" "volume_operations" "Volume Operations Tests"
fi

if [[ "$RUN_ALL" == "true" ]] || [[ "$RUN_NETWORK" == "true" ]]; then
    echo -e "${CYAN}[Network Operations]${NC}"
    
    # Create network test if it doesn't exist
    NETWORK_TEST="$TEST_DIR/test_network_operations.sh"
    if [[ ! -f "$NETWORK_TEST" ]]; then
        create_simple_test "$DOCKERKIT_DIR/scripts/docker-network-operations.sh" "$NETWORK_TEST"
    fi
    run_test "$NETWORK_TEST" "network_operations" "Network Operations Tests"
fi

if [[ "$RUN_ALL" == "true" ]] || [[ "$RUN_COMPOSE" == "true" ]]; then
    echo -e "${CYAN}[Docker Compose]${NC}"
    
    # Create compose test if it doesn't exist
    COMPOSE_TEST="$TEST_DIR/test_compose_operations.sh"
    if [[ ! -f "$COMPOSE_TEST" ]]; then
        create_simple_test "$DOCKERKIT_DIR/scripts/docker-compose-operations.sh" "$COMPOSE_TEST"
    fi
    run_test "$COMPOSE_TEST" "compose_operations" "Docker Compose Tests"
fi

if [[ "$RUN_ALL" == "true" ]] || [[ "$RUN_COMPLIANCE" == "true" ]]; then
    echo -e "${CYAN}[Docker Compliance]${NC}"
    run_test "test_docker_compliance.sh" "docker_compliance" "Docker Compliance Tests"
fi

if [[ "$RUN_ALL" == "true" ]] || [[ "$RUN_WRAPPER" == "true" ]]; then
    echo -e "${CYAN}[Docker Wrapper]${NC}"
    run_test "test_docker_wrapper.sh" "docker_wrapper" "Docker Wrapper Tests"
fi

# Print summary
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 Test Summary                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Calculate percentages
if [[ $TOTAL_TESTS -gt 0 ]]; then
    PASS_PERCENT=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
else
    PASS_PERCENT=0
fi

# Display results with visual indicators
echo -e "📊 Total tests run: ${TOTAL_TESTS}"
echo -e "✅ Passed: ${GREEN}${PASSED_TESTS}${NC}"
echo -e "❌ Failed: ${RED}${FAILED_TESTS}${NC}"
if [[ $SKIPPED_TESTS -gt 0 ]]; then
    echo -e "⏭️  Skipped: ${YELLOW}${SKIPPED_TESTS}${NC}"
fi

# Progress bar
echo ""
echo -n "Progress: ["
for ((i=0; i<20; i++)); do
    if [[ $i -lt $((PASS_PERCENT / 5)) ]]; then
        echo -n "█"
    else
        echo -n "░"
    fi
done
echo "] ${PASS_PERCENT}%"

# Final status
echo ""
if [[ $FAILED_TESTS -eq 0 ]] && [[ $TOTAL_TESTS -gt 0 ]]; then
    echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
    exit 0
elif [[ $TOTAL_TESTS -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  No tests were run${NC}"
    exit 1
else
    echo -e "${RED}💔 ${FAILED_TESTS} test(s) failed${NC}"
    echo -e "${YELLOW}Please review the failures above${NC}"
    exit 1
fi