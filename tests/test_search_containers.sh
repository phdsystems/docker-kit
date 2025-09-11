#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$DOCKERKIT_DIR/src"
SEARCH_SCRIPT="$SCRIPTS_DIR/docker-search-containers.sh"

source "$SCRIPT_DIR/test_helpers.sh" 2>/dev/null || true
    echo "❌ Failed to source test utils"
    exit 1
}

echo "🧪 Testing Docker Container Search Functionality..."

test_container_search_help() {
    echo "  Testing container search help..."
    
    output=$("$SEARCH_SCRIPT" --help 2>&1) || true
    
    if [[ "$output" == *"Usage:"* ]] && \
       [[ "$output" == *"--name"* ]] && \
       [[ "$output" == *"--status"* ]] && \
       [[ "$output" == *"--port"* ]] && \
       [[ "$output" == *"--network"* ]]; then
        echo "    ✅ Help output contains all major options"
        return 0
    else
        echo "    ❌ Help output is incomplete"
        return 1
    fi
}

test_container_search_by_name() {
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

test_container_search_by_status() {
    echo "  Testing search by status parameter..."
    
    if grep -q '\-s\|--status' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --status parameter"
        
        if grep -q 'filter status=' "$SEARCH_SCRIPT"; then
            echo "    ✅ Status filter uses Docker filter"
            
            # Check for various statuses
            if grep -q 'running\|exited\|paused' "$SEARCH_SCRIPT"; then
                echo "    ✅ Supports multiple status types"
                return 0
            fi
        else
            echo "    ❌ Status filter not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --status parameter"
        return 1
    fi
}

test_container_search_by_port() {
    echo "  Testing search by port parameter..."
    
    if grep -q '\-p\|--port' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --port parameter"
        
        if grep -q 'find_containers_by_port' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has dedicated port search function"
            return 0
        elif grep -q 'filter.*expose=' "$SEARCH_SCRIPT"; then
            echo "    ✅ Uses Docker expose filter"
            return 0
        else
            echo "    ❌ Port filter not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --port parameter"
        return 1
    fi
}

test_container_search_by_network() {
    echo "  Testing search by network parameter..."
    
    if grep -q '\--network' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --network parameter"
        
        if grep -q 'filter network=' "$SEARCH_SCRIPT"; then
            echo "    ✅ Network filter uses Docker filter"
            return 0
        else
            echo "    ❌ Network filter not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --network parameter"
        return 1
    fi
}

test_container_search_by_volume() {
    echo "  Testing search by volume parameter..."
    
    if grep -q '\--volume' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --volume parameter"
        
        if grep -q 'find_containers_by_volume' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has dedicated volume search function"
            return 0
        elif grep -q 'filter volume=' "$SEARCH_SCRIPT"; then
            echo "    ✅ Uses Docker volume filter"
            return 0
        else
            echo "    ❌ Volume filter not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --volume parameter"
        return 1
    fi
}

test_container_health_filter() {
    echo "  Testing health status filter..."
    
    if grep -q '\--health' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --health parameter"
        
        if grep -q 'filter health=' "$SEARCH_SCRIPT"; then
            echo "    ✅ Health filter uses Docker filter"
            return 0
        else
            echo "    ❌ Health filter not properly implemented"
            return 1
        fi
    else
        echo "    ⚠️  Script doesn't support --health parameter (optional)"
        return 0
    fi
}

test_container_stats_option() {
    echo "  Testing stats option..."
    
    if grep -q '\--stats' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --stats parameter"
        
        if grep -q 'docker stats' "$SEARCH_SCRIPT"; then
            echo "    ✅ Uses docker stats command"
            return 0
        else
            echo "    ❌ Stats not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --stats parameter"
        return 1
    fi
}

test_container_output_formats() {
    echo "  Testing output format options..."
    
    if grep -q '\-f\|--format' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --format parameter"
        
        local formats_found=0
        
        if grep -q 'json)' "$SEARCH_SCRIPT"; then
            echo "    ✅ Supports JSON format"
            ((formats_found++))
        fi
        
        if grep -q 'id-only)' "$SEARCH_SCRIPT"; then
            echo "    ✅ Supports ID-only format"
            ((formats_found++))
        fi
        
        if grep -q 'names)' "$SEARCH_SCRIPT"; then
            echo "    ✅ Supports names format"
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

test_container_analyze_function() {
    echo "  Testing container analysis functionality..."
    
    if grep -q 'analyze_containers' "$SEARCH_SCRIPT"; then
        echo "    ✅ Has analyze_containers function"
        
        if grep -q 'Total containers:' "$SEARCH_SCRIPT"; then
            echo "    ✅ Shows total container count"
        fi
        
        if grep -q 'Running:' "$SEARCH_SCRIPT"; then
            echo "    ✅ Shows running count"
        fi
        
        if grep -q 'Exited:' "$SEARCH_SCRIPT"; then
            echo "    ✅ Shows exited count"
        fi
        
        return 0
    else
        echo "    ⚠️  No analyze function found"
        return 0
    fi
}

test_container_network_connections() {
    echo "  Testing network connections feature..."
    
    if grep -q 'inspect_container_connections' "$SEARCH_SCRIPT"; then
        echo "    ✅ Has network connections function"
        
        if grep -q 'docker network inspect' "$SEARCH_SCRIPT"; then
            echo "    ✅ Inspects network connections"
            return 0
        fi
    else
        echo "    ⚠️  No network connections feature (optional)"
        return 0
    fi
}

test_container_all_flag() {
    echo "  Testing --all flag..."
    
    if grep -q '\-a\|--all' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --all parameter"
        
        if grep -q 'docker ps.*-a' "$SEARCH_SCRIPT"; then
            echo "    ✅ Properly passes -a to docker ps"
            return 0
        else
            echo "    ❌ --all flag not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --all parameter"
        return 1
    fi
}

run_tests() {
    local failed=0
    
    test_container_search_help || ((failed++))
    test_container_search_by_name || ((failed++))
    test_container_search_by_status || ((failed++))
    test_container_search_by_port || ((failed++))
    test_container_search_by_network || ((failed++))
    test_container_search_by_volume || ((failed++))
    test_container_health_filter || ((failed++))
    test_container_stats_option || ((failed++))
    test_container_output_formats || ((failed++))
    test_container_analyze_function || ((failed++))
    test_container_network_connections || ((failed++))
    test_container_all_flag || ((failed++))
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "✅ All container search unit tests passed!"
        return 0
    else
        echo "❌ $failed container search test(s) failed"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi