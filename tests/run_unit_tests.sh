#!/bin/bash

# ==============================================================================
# DCK Unit Test Runner
# ==============================================================================
# Runs all unit tests and provides comprehensive reporting
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test configuration
TESTS_DIR="$SCRIPT_DIR"
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_TESTS=()

# Timing
START_TIME=$(date +%s)

# ==============================================================================
# Helper Functions
# ==============================================================================

print_header() {
    echo -e "${BOLD}${CYAN}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
}

print_test_header() {
    echo -e "\n${BOLD}${BLUE}Running: $1${NC}"
    echo -e "${BLUE}------------------------------------------${NC}"
}

run_test_suite() {
    local test_file="$1"
    local test_name="$(basename "$test_file" .sh)"
    
    print_test_header "$test_name"
    
    local test_output
    local test_exit_code=0
    
    # Run the test and capture output
    if test_output=$("$test_file" 2>&1); then
        test_exit_code=0
    else
        test_exit_code=$?
    fi
    
    # Parse test results
    local tests_run=$(echo "$test_output" | grep "Tests Run:" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $3}' | tail -1)
    local tests_passed=$(echo "$test_output" | grep "Tests Passed:" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $3}' | tail -1)
    local tests_failed=$(echo "$test_output" | grep "Tests Failed:" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $3}' | tail -1)
    
    # Default values if parsing fails
    tests_run=${tests_run:-0}
    tests_passed=${tests_passed:-0}
    tests_failed=${tests_failed:-0}
    
    # Update totals
    TOTAL_TESTS=$((TOTAL_TESTS + tests_run))
    TOTAL_PASSED=$((TOTAL_PASSED + tests_passed))
    TOTAL_FAILED=$((TOTAL_FAILED + tests_failed))
    
    # Display results
    if [[ $test_exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ $test_name: All tests passed ($tests_passed/$tests_run)${NC}"
    else
        echo -e "${RED}✗ $test_name: Some tests failed ($tests_failed/$tests_run failed)${NC}"
        FAILED_TESTS+=("$test_name")
        
        # Show failed test details
        echo "$test_output" | grep "✗ FAILED" | while read -r line; do
            echo -e "  ${RED}$line${NC}"
        done
    fi
    
    return $test_exit_code
}

check_dependencies() {
    echo -e "${CYAN}Checking dependencies...${NC}"
    
    local deps_ok=true
    
    # Check for required commands
    for cmd in bash grep awk sed; do
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${RED}  ✗ Missing: $cmd${NC}"
            deps_ok=false
        else
            echo -e "${GREEN}  ✓ Found: $cmd${NC}"
        fi
    done
    
    # Check for project structure
    if [[ ! -f "$PROJECT_ROOT/bin/dck" ]]; then
        echo -e "${RED}  ✗ DCK CLI not found${NC}"
        deps_ok=false
    else
        echo -e "${GREEN}  ✓ DCK CLI found${NC}"
    fi

    if [[ ! -d "$PROJECT_ROOT/main/src" ]]; then
        echo -e "${RED}  ✗ main/src/ directory not found${NC}"
        deps_ok=false
    else
        echo -e "${GREEN}  ✓ main/src/ directory found${NC}"
    fi
    
    if ! $deps_ok; then
        echo -e "${RED}Dependencies check failed. Please install missing components.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All dependencies satisfied.${NC}\n"
}

# ==============================================================================
# Main Test Runner
# ==============================================================================

main() {
    print_header "DCK Unit Test Suite"
    echo -e "${CYAN}Running all unit tests for DockerKit${NC}\n"
    
    # Check dependencies
    check_dependencies
    
    # Define test suites
    declare -a TEST_SUITES=(
        # Unit tests
        "test_dck_cli.sh"
        "test_docker_objects.sh"
        "test_compliance_module.sh"
        "test_template_generator.sh"
        "test_monitoring_analysis.sh"
        "test_docker_wrapper.sh"
        # Integration tests
        "test_integration_e2e.sh"
        "test_error_handling.sh"
        "test_performance.sh"
        # Existing search tests
        "test_search_images.sh"
        "test_search_containers.sh"
        "test_search_volumes.sh"
        "test_search_networks.sh"
    )
    
    # Run each test suite
    local suite_failed=0
    for test_suite in "${TEST_SUITES[@]}"; do
        if [[ -f "$TESTS_DIR/$test_suite" ]]; then
            if ! run_test_suite "$TESTS_DIR/$test_suite"; then
                suite_failed=$((suite_failed + 1))
            fi
        else
            echo -e "${YELLOW}⚠ Test suite not found: $test_suite${NC}"
        fi
    done
    
    # Calculate elapsed time
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    MINUTES=$((ELAPSED / 60))
    SECONDS=$((ELAPSED % 60))
    
    # Print summary
    echo ""
    print_header "Test Summary"
    
    echo -e "${BOLD}Overall Results:${NC}"
    echo -e "  Total Tests Run:    ${BOLD}$TOTAL_TESTS${NC}"
    echo -e "  Tests Passed:       ${GREEN}$TOTAL_PASSED${NC}"
    echo -e "  Tests Failed:       ${RED}$TOTAL_FAILED${NC}"
    
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        local pass_rate=$((TOTAL_PASSED * 100 / TOTAL_TESTS))
        echo -e "  Pass Rate:          ${BOLD}${pass_rate}%${NC}"
    fi
    
    echo -e "  Time Elapsed:       ${BOLD}${MINUTES}m ${SECONDS}s${NC}"
    
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo -e "\n${RED}Failed Test Suites:${NC}"
        for failed in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}• $failed${NC}"
        done
    fi
    
    # Exit code
    if [[ $TOTAL_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}${BOLD}✓ All tests passed successfully!${NC}"
        exit 0
    else
        echo -e "\n${RED}${BOLD}✗ Some tests failed. Please review the output above.${NC}"
        exit 1
    fi
}

# ==============================================================================
# Script Options
# ==============================================================================

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -h, --help     Show this help message"
            echo "  -v, --verbose  Show detailed test output"
            echo "  -q, --quiet    Suppress output except summary"
            echo "  -f, --filter   Run only tests matching pattern"
            echo ""
            echo "Examples:"
            echo "  $0                    # Run all tests"
            echo "  $0 --verbose          # Run with detailed output"
            echo "  $0 --filter cli       # Run only CLI tests"
            exit 0
            ;;
        -v|--verbose)
            export VERBOSE=1
            shift
            ;;
        -q|--quiet)
            export QUIET=1
            shift
            ;;
        -f|--filter)
            export FILTER="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main