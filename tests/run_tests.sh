#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     DockerKit Test Suite Runner        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --unit          Run unit tests only
    --integration   Run integration tests only
    --verbose       Enable verbose output
    --help          Show this help message

Examples:
    $0              # Run all tests
    $0 --unit       # Run unit tests only
    $0 --integration # Run integration tests only
EOF
}

RUN_UNIT=true
RUN_INTEGRATION=true
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --unit)
            RUN_UNIT=true
            RUN_INTEGRATION=false
            shift
            ;;
        --integration)
            RUN_UNIT=false
            RUN_INTEGRATION=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

run_test() {
    local test_file="$1"
    local test_name="$(basename "$test_file" .sh)"
    
    echo -e "${BLUE}Running: ${NC}$test_name"
    
    if [[ "$VERBOSE" == "true" ]]; then
        bash "$test_file"
    else
        output=$(bash "$test_file" 2>&1)
        exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            echo -e "${GREEN}  ✅ PASSED${NC}"
        else
            echo -e "${RED}  ❌ FAILED${NC}"
            echo "$output" | tail -10
        fi
        
        return $exit_code
    fi
}

total_tests=0
failed_tests=0

if [[ "$RUN_UNIT" == "true" ]]; then
    echo -e "${YELLOW}🧪 Running Unit Tests...${NC}"
    echo "------------------------"
    
    unit_tests=(
        "$TESTS_DIR/test_dockerkit_cli.sh"
        "$TESTS_DIR/test_docker_operations.sh"
        "$TESTS_DIR/test_search_features.sh"
        "$TESTS_DIR/test_search_images.sh"
        "$TESTS_DIR/test_search_containers.sh"
        "$TESTS_DIR/test_search_volumes.sh"
        "$TESTS_DIR/test_search_networks.sh"
    )
    
    for test in "${unit_tests[@]}"; do
        if [[ -f "$test" ]]; then
            chmod +x "$test"
            ((total_tests++))
            run_test "$test" || ((failed_tests++))
            echo ""
        fi
    done
fi

if [[ "$RUN_INTEGRATION" == "true" ]]; then
    echo -e "${YELLOW}🔧 Running Integration Tests...${NC}"
    echo "-------------------------------"
    
    integration_tests=(
        "$TESTS_DIR/test_integration.sh"
    )
    
    for test in "${integration_tests[@]}"; do
        if [[ -f "$test" ]]; then
            chmod +x "$test"
            ((total_tests++))
            run_test "$test" || ((failed_tests++))
            echo ""
        fi
    done
fi

echo "╔════════════════════════════════════════╗"
echo "║           Test Summary                 ║"
echo "╠════════════════════════════════════════╣"
printf "║  Total Tests:   %-22d ║\n" "$total_tests"
printf "║  Passed:        %-22d ║\n" "$((total_tests - failed_tests))"
printf "║  Failed:        %-22d ║\n" "$failed_tests"
echo "╚════════════════════════════════════════╝"

if [[ $failed_tests -eq 0 ]]; then
    echo -e "\n${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}❌ $failed_tests test(s) failed${NC}"
    exit 1
fi