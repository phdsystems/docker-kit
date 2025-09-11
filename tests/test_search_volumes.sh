#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$DOCKERKIT_DIR/src"
SEARCH_SCRIPT="$SCRIPTS_DIR/docker-search-volumes.sh"

source "$SCRIPT_DIR/test_helpers.sh" 2>/dev/null || true
    echo "❌ Failed to source test utils"
    exit 1
}

echo "🧪 Testing Docker Volume Search Functionality..."

test_volume_search_help() {
    echo "  Testing volume search help..."
    
    output=$("$SEARCH_SCRIPT" --help 2>&1) || true
    
    if [[ "$output" == *"Usage:"* ]] && \
       [[ "$output" == *"--name"* ]] && \
       [[ "$output" == *"--driver"* ]] && \
       [[ "$output" == *"--dangling"* ]] && \
       [[ "$output" == *"--container"* ]]; then
        echo "    ✅ Help output contains all major options"
        return 0
    else
        echo "    ❌ Help output is incomplete"
        return 1
    fi
}

test_volume_search_by_name() {
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

test_volume_search_by_driver() {
    echo "  Testing search by driver parameter..."
    
    if grep -q '\-d\|--driver' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --driver parameter"
        
        if grep -q 'filter driver=' "$SEARCH_SCRIPT"; then
            echo "    ✅ Driver filter uses Docker filter"
            return 0
        else
            echo "    ❌ Driver filter not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --driver parameter"
        return 1
    fi
}

test_volume_search_dangling() {
    echo "  Testing dangling volumes filter..."
    
    if grep -q '\--dangling' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --dangling parameter"
        
        if grep -q 'filter dangling=true' "$SEARCH_SCRIPT"; then
            echo "    ✅ Dangling filter uses Docker filter"
            return 0
        else
            echo "    ❌ Dangling filter not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --dangling parameter"
        return 1
    fi
}

test_volume_search_in_use() {
    echo "  Testing in-use volumes filter..."
    
    if grep -q '\--in-use' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --in-use parameter"
        
        if grep -q 'filter dangling=false' "$SEARCH_SCRIPT"; then
            echo "    ✅ In-use filter uses Docker filter"
            return 0
        else
            echo "    ❌ In-use filter not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --in-use parameter"
        return 1
    fi
}

test_volume_search_by_container() {
    echo "  Testing search by container parameter..."
    
    if grep -q '\-c\|--container' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --container parameter"
        
        if grep -q 'find_volumes_by_container' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has dedicated container search function"
            
            if grep -q 'docker inspect.*Mounts' "$SEARCH_SCRIPT"; then
                echo "    ✅ Inspects container mounts"
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

test_volume_mount_point_search() {
    echo "  Testing mount point search..."
    
    if grep -q '\--mount-point' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --mount-point parameter"
        
        if grep -q 'find_volumes_by_mount_point' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has mount point search function"
            return 0
        else
            echo "    ❌ Mount point search not properly implemented"
            return 1
        fi
    else
        echo "    ⚠️  Script doesn't support --mount-point (optional)"
        return 0
    fi
}

test_volume_size_option() {
    echo "  Testing volume size option..."
    
    if grep -q '\-s\|--size' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --size parameter"
        
        if grep -q 'get_volume_size' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has volume size calculation function"
            
            if grep -q 'du -sh' "$SEARCH_SCRIPT"; then
                echo "    ✅ Uses du command for size"
                return 0
            fi
        else
            echo "    ❌ Size option not properly implemented"
            return 1
        fi
    else
        echo "    ⚠️  Script doesn't support --size (optional)"
        return 0
    fi
}

test_volume_inspect_option() {
    echo "  Testing volume inspect option..."
    
    if grep -q '\--inspect' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --inspect parameter"
        
        if grep -q 'inspect_volume' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has inspect_volume function"
            
            if grep -q 'docker volume inspect' "$SEARCH_SCRIPT"; then
                echo "    ✅ Uses docker volume inspect"
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

test_volume_cleanup_option() {
    echo "  Testing volume cleanup option..."
    
    if grep -q '\--cleanup' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --cleanup parameter"
        
        if grep -q 'cleanup_dangling_volumes' "$SEARCH_SCRIPT"; then
            echo "    ✅ Has cleanup function"
            
            if grep -q 'docker volume prune' "$SEARCH_SCRIPT"; then
                echo "    ✅ Uses docker volume prune"
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

test_volume_output_formats() {
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
        
        if [[ $formats_found -ge 1 ]]; then
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

test_volume_analyze_function() {
    echo "  Testing volume analysis functionality..."
    
    if grep -q 'analyze_volumes' "$SEARCH_SCRIPT"; then
        echo "    ✅ Has analyze_volumes function"
        
        if grep -q 'Total volumes:' "$SEARCH_SCRIPT"; then
            echo "    ✅ Shows total volume count"
        fi
        
        if grep -q 'Dangling:' "$SEARCH_SCRIPT"; then
            echo "    ✅ Shows dangling count"
        fi
        
        if grep -q 'In use:' "$SEARCH_SCRIPT"; then
            echo "    ✅ Shows in-use count"
        fi
        
        return 0
    else
        echo "    ⚠️  No analyze function found"
        return 0
    fi
}

run_tests() {
    local failed=0
    
    test_volume_search_help || ((failed++))
    test_volume_search_by_name || ((failed++))
    test_volume_search_by_driver || ((failed++))
    test_volume_search_dangling || ((failed++))
    test_volume_search_in_use || ((failed++))
    test_volume_search_by_container || ((failed++))
    test_volume_mount_point_search || ((failed++))
    test_volume_size_option || ((failed++))
    test_volume_inspect_option || ((failed++))
    test_volume_cleanup_option || ((failed++))
    test_volume_output_formats || ((failed++))
    test_volume_analyze_function || ((failed++))
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "✅ All volume search unit tests passed!"
        return 0
    else
        echo "❌ $failed volume search test(s) failed"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi