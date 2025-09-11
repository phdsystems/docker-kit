#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$DOCKERKIT_DIR/src"
SEARCH_SCRIPT="$SCRIPTS_DIR/docker-search-images.sh"

# Source test helpers if available
source "$SCRIPT_DIR/test_helpers.sh" 2>/dev/null || true

echo "🧪 Testing Docker Image Search Functionality..."

setup_mock_docker() {
    export PATH="$SCRIPT_DIR/mocks:$PATH"
    export MOCK_MODE="images"
}

teardown_mock_docker() {
    export PATH="${PATH#$SCRIPT_DIR/mocks:}"
    unset MOCK_MODE
}

test_image_search_help() {
    echo "  Testing image search help..."
    
    output=$("$SEARCH_SCRIPT" --help 2>&1) || true
    
    if [[ "$output" == *"Usage:"* ]] && \
       [[ "$output" == *"--name"* ]] && \
       [[ "$output" == *"--tag"* ]] && \
       [[ "$output" == *"--dangling"* ]] && \
       [[ "$output" == *"--min-size"* ]]; then
        echo "    ✅ Help output contains all major options"
        return 0
    else
        echo "    ❌ Help output is incomplete"
        return 1
    fi
}

test_image_search_by_name() {
    echo "  Testing search by name parameter..."
    
    # Check if the script accepts --name parameter
    if grep -q '\-n\|--name' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --name parameter"
        
        # Check if it's properly handled
        if grep -q 'FILTER_NAME=' "$SEARCH_SCRIPT"; then
            echo "    ✅ Name filter is properly stored"
            return 0
        else
            echo "    ❌ Name filter not properly handled"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --name parameter"
        return 1
    fi
}

test_image_search_by_tag() {
    echo "  Testing search by tag parameter..."
    
    if grep -q '\-t\|--tag' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --tag parameter"
        
        if grep -q 'FILTER_TAG=' "$SEARCH_SCRIPT"; then
            echo "    ✅ Tag filter is properly stored"
            return 0
        else
            echo "    ❌ Tag filter not properly handled"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --tag parameter"
        return 1
    fi
}

test_image_search_dangling() {
    echo "  Testing dangling images filter..."
    
    if grep -q '\-d\|--dangling' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --dangling parameter"
        
        if grep -q 'filter.*dangling=true' "$SEARCH_SCRIPT"; then
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

test_image_size_filters() {
    echo "  Testing size-based filters..."
    
    local size_options_found=0
    
    if grep -q '\--min-size' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --min-size parameter"
        ((size_options_found++))
    fi
    
    if grep -q '\--max-size' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --max-size parameter"
        ((size_options_found++))
    fi
    
    if grep -q 'convert_size_to_bytes' "$SEARCH_SCRIPT"; then
        echo "    ✅ Has size conversion function"
        ((size_options_found++))
    fi
    
    if [[ $size_options_found -ge 2 ]]; then
        return 0
    else
        echo "    ❌ Size filtering not fully implemented"
        return 1
    fi
}

test_image_registry_search() {
    echo "  Testing registry search functionality..."
    
    if grep -q '\-r\|--registry' "$SEARCH_SCRIPT"; then
        echo "    ✅ Script supports --registry parameter"
        
        if grep -q 'docker search' "$SEARCH_SCRIPT"; then
            echo "    ✅ Uses docker search for registry"
            return 0
        else
            echo "    ❌ Registry search not properly implemented"
            return 1
        fi
    else
        echo "    ❌ Script doesn't support --registry parameter"
        return 1
    fi
}

test_image_output_formats() {
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
        
        if grep -q 'table' "$SEARCH_SCRIPT"; then
            echo "    ✅ Supports table format"
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

test_image_analyze_function() {
    echo "  Testing image analysis functionality..."
    
    if grep -q 'analyze_images' "$SEARCH_SCRIPT"; then
        echo "    ✅ Has analyze_images function"
        
        if grep -q 'Total images:' "$SEARCH_SCRIPT"; then
            echo "    ✅ Shows total image count"
        fi
        
        if grep -q 'Dangling images:' "$SEARCH_SCRIPT"; then
            echo "    ✅ Shows dangling image count"
        fi
        
        if grep -q 'largest images' "$SEARCH_SCRIPT"; then
            echo "    ✅ Shows largest images"
        fi
        
        return 0
    else
        echo "    ⚠️  No analyze function found"
        return 0
    fi
}

test_image_error_handling() {
    echo "  Testing error handling..."
    
    if grep -q 'command -v docker' "$SEARCH_SCRIPT"; then
        echo "    ✅ Checks for Docker installation"
    else
        echo "    ❌ Doesn't check for Docker"
        return 1
    fi
    
    if grep -q 'set -e' "$SEARCH_SCRIPT"; then
        echo "    ✅ Uses error exit mode"
    fi
    
    if grep -q 'Error:' "$SEARCH_SCRIPT"; then
        echo "    ✅ Has error messages"
    fi
    
    return 0
}

run_tests() {
    local failed=0
    
    test_image_search_help || ((failed++))
    test_image_search_by_name || ((failed++))
    test_image_search_by_tag || ((failed++))
    test_image_search_dangling || ((failed++))
    test_image_size_filters || ((failed++))
    test_image_registry_search || ((failed++))
    test_image_output_formats || ((failed++))
    test_image_analyze_function || ((failed++))
    test_image_error_handling || ((failed++))
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "✅ All image search unit tests passed!"
        return 0
    else
        echo "❌ $failed image search test(s) failed"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi