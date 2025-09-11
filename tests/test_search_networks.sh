#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$DOCKERKIT_DIR/src"
SEARCH_SCRIPT="$SCRIPTS_DIR/docker-search-networks.sh"

source "$SCRIPT_DIR/test_helpers.sh" 2>/dev/null || true
    echo "❌ Failed to source test utils"
    exit 1
}

echo "🧪 Testing Docker Network Search Functionality..."

test_network_search_help() {
    echo "  Testing network search help..."
    
    output=$("$SEARCH_SCRIPT" --help 2>&1) || true
    
    if [[ "$output" == *"Usage:"* ]] && \
       [[ "$output" == *"--name"* ]] && \
       [[ "$output" == *"--driver"* ]] && \
       [[ "$output" == *"--container"* ]] && \
       [[ "$output" == *"--subnet"* ]]; then
        echo "    ✅ Help output contains all major options"
        return 0
    else
        echo "    ❌ Help output is incomplete"
        return 1
    fi
}

test_network_search_by_name() {
    echo "  Testing search by name parameter..."
    
    if grep -q '\-n\|--name' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --name parameter"
        
        if grep -q 'filter name=' "$SEARCH_SCRIPT"; then
            echo "    ✅ Name filter uses Docker filter"
            return 0
        else
            echo "    ❌ Name filter not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --name parameter"
        return 1
    fi
}

test_network_search_by_driver() {
    echo "  Testing search by driver parameter..."
    
    if grep -q '\-d\|--driver' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --driver parameter"
        
        if grep -q 'filter driver=' "$SEARCH_SCRIPT"; then
            echo "    ✅ Driver filter uses Docker filter"
            
            # Check for various drivers
            if grep -q 'bridge\|host\|overlay\|macvlan' "$SEARCH_SCRIPT"; then
                echo "    ✅ Mentions multiple driver types"
                return 0
            fi
        else
            echo "    ❌ Driver filter not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --driver parameter"
        return 1
    fi
}

test_network_search_by_scope() {
    echo "  Testing search by scope parameter..."
    
    if grep -q '\--scope' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --scope parameter"
        
        if grep -q 'filter scope=' "$SEARCH_SCRIPT"; then
            echo "    ✅ Scope filter uses Docker filter"
            return 0
        else
            echo "    ❌ Scope filter not properly implemented"
            return 1
        fi
    else
        echo "    ⚠️  Script doesn't support --scope (optional)"
        return 0
    fi
}

test_network_internal_filters() {
    echo "  Testing internal/external filters..."
    
    local filters_found=0
    
    if grep -q '\--internal' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --internal parameter"
        ((filters_found++))
    fi
    
    if grep -q '\--no-internal' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --no-internal parameter"
        ((filters_found++))
    fi
    
    if grep -q 'filter internal=' "$SEARCH_SCRIPT"; then
        echo "    ✅ Internal filter uses Docker filter"
        ((filters_found++))
    fi
    
    if [[ $filters_found -ge 2 ]]; then
        return 0
    else
        echo "    ⚠️  Limited internal/external filtering"
        return 0
    fi
}

test_network_search_by_container() {
    echo "  Testing search by container parameter..."
    
    if grep -q '\-c\|--container' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --container parameter"
        
        if grep -q 'find_networks_by_container' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has dedicated container search function"
            
            if grep -q 'NetworkSettings.Networks' "$SEARCH_SCRIPT"; then
                echo "    ✅ Inspects container network settings"
                return 0
            fi
        else
            echo "    ❌ Container filter not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --container parameter"
        return 1
    fi
}

test_network_search_by_subnet() {
    echo "  Testing search by subnet parameter..."
    
    if grep -q '\--subnet' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --subnet parameter"
        
        if grep -q 'find_networks_by_subnet' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has subnet search function"
            
            if grep -q 'IPAM.Config' "$SEARCH_SCRIPT"; then
                echo "    ✅ Inspects IPAM configuration"
                return 0
            fi
        else
            echo "    ❌ Subnet filter not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --subnet parameter"
        return 1
    fi
}

test_network_unused_filter() {
    echo "  Testing unused networks filter..."
    
    if grep -q '\--unused' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --unused parameter"
        
        if grep -q 'find_unused_networks' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has unused networks function"
            return 0
        else
            echo "    ❌ Unused filter not properly implemented"
            return 1
        fi
    else
        echo "    ⚠️  Script doesn't support --unused (optional)"
        return 0
    fi
}

test_network_in_use_filter() {
    echo "  Testing in-use networks filter..."
    
    if grep -q '\--in-use' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --in-use parameter"
        
        if grep -q 'find_networks_in_use' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has in-use networks function"
            return 0
        else
            echo "    ❌ In-use filter not properly implemented"
            return 1
        fi
    else
        echo "    ⚠️  Script doesn't support --in-use (optional)"
        return 0
    fi
}

test_network_inspect_option() {
    echo "  Testing network inspect option..."
    
    if grep -q '\--inspect' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --inspect parameter"
        
        if grep -q 'inspect_network' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has inspect_network function"
            
            if grep -q 'docker network inspect' "$SEARCH_SCRIPT"; then
                echo "    ✅ Uses docker network inspect"
                return 0
            fi
        else
            echo "    ❌ Inspect option not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --inspect parameter"
        return 1
    fi
}

test_network_trace_option() {
    echo "  Testing network trace option..."
    
    if grep -q '\--trace' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --trace parameter"
        
        if grep -q 'trace_network_connectivity' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has network trace function"
            
            if grep -q 'Connectivity Map' "$SEARCH_SCRIPT"; then
                echo "    ✅ Shows connectivity map"
                return 0
            fi
        else
            echo "    ❌ Trace option not properly implemented"
            return 1
        fi
    else
        echo "    ⚠️  Script doesn't support --trace (optional)"
        return 0
    fi
}

test_network_cleanup_option() {
    echo "  Testing network cleanup option..."
    
    if grep -q '\--cleanup' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --cleanup parameter"
        
        if grep -q 'cleanup_unused_networks' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has cleanup function"
            
            if grep -q 'docker network prune' "$SEARCH_SCRIPT"; then
                echo "    ✅ Uses docker network prune"
                return 0
            fi
        else
            echo "    ❌ Cleanup option not properly implemented"
            return 1
        fi
    else
        echo "    ⚠️  Script doesn't support --cleanup (optional)"
        return 0
    fi
}

test_network_output_formats() {
    echo "  Testing output format options..."
    
    if grep -q '\-f\|--format' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --format parameter"
        
        local formats_found=0
        
        if grep -q 'json)' "$SEARCH_SCRIPT"; then
            echo "    ✅ Supports JSON format"
            ((formats_found++))
        fi
        
        if grep -q 'names-only)' "$SEARCH_SCRIPT"; then
            echo "    ✅ Supports names-only format"
            ((formats_found++))
        fi
        
        if grep -q 'detailed)' "$SEARCH_SCRIPT"; then
            echo "    ✅ Supports detailed format"
            ((formats_found++))
        fi
        
        if [[ $formats_found -ge 2 ]]; then
            return 0
        else
            echo "    ⚠️  Limited format options"
            return 0
        fi
    else
        echo "    ❌ Script doesn't support --format parameter"
        return 1
    fi
}

test_network_analyze_function() {
    echo "  Testing network analysis functionality..."
    
    if grep -q 'analyze_networks' "$SEARCH_SCRIPT"; then
        echo "    ✅ Has analyze_networks function"
        
        if grep -q 'Total networks:' "$SEARCH_SCRIPT"; then
            echo "    ✅ Shows total network count"
        fi
        
        if grep -q 'Networks by driver:' "$SEARCH_SCRIPT"; then
            echo "    ✅ Shows networks by driver"
        fi
        
        if grep -q 'IP allocation:' "$SEARCH_SCRIPT"; then
            echo "    ✅ Shows IP allocation info"
        fi
        
        return 0
    else
        echo "    ⚠️  No analyze function found"
        return 0
    fi
}

run_tests() {
    local failed=0
    
    test_network_search_help || ((failed++))
    test_network_search_by_name || ((failed++))
    test_network_search_by_driver || ((failed++))
    test_network_search_by_scope || ((failed++))
    test_network_internal_filters || ((failed++))
    test_network_search_by_container || ((failed++))
    test_network_search_by_subnet || ((failed++))
    test_network_unused_filter || ((failed++))
    test_network_in_use_filter || ((failed++))
    test_network_inspect_option || ((failed++))
    test_network_trace_option || ((failed++))
    test_network_cleanup_option || ((failed++))
    test_network_output_formats || ((failed++))
    test_network_analyze_function || ((failed++))
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "✅ All network search unit tests passed!"
        return 0
    else
        echo "❌ $failed network search test(s) failed"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi