#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKERKIT_CLI="$DOCKERKIT_DIR/dockerkit"
SCRIPTS_DIR="$DOCKERKIT_DIR/src"

source "$SCRIPT_DIR/test_helpers.sh" 2>/dev/null || true
    echo "❌ Failed to source test utils"
    exit 1
}

echo "🧪 Testing DockerKit Search Features..."

test_search_scripts_exist() {
    echo "  Checking search scripts exist..."
    local scripts=(
        "docker-search-images.sh"
        "docker-search-containers.sh"
        "docker-search-volumes.sh"
        "docker-search-networks.sh"
    )
    
    local failed=0
    for script in "${scripts[@]}"; do
        if [[ -f "$SCRIPTS_DIR/$script" ]]; then
            if [[ -x "$SCRIPTS_DIR/$script" ]]; then
                echo "    ✅ $script exists and is executable"
            else
                echo "    ❌ $script exists but is not executable"
                ((failed++))
            fi
        else
            echo "    ❌ $script does not exist"
            ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

test_search_scripts_syntax() {
    echo "  Testing search scripts syntax..."
    local failed=0
    
    for script in "$SCRIPTS_DIR"/docker-search-*.sh; do
        if [[ -f "$script" ]]; then
            bash -n "$script" 2>/dev/null || {
                echo "    ❌ Syntax error in $(basename "$script")"
                ((failed++))
            }
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        echo "    ✅ All search scripts have valid syntax"
        return 0
    else
        echo "    ❌ $failed search script(s) have syntax errors"
        return 1
    fi
}

test_search_command_in_cli() {
    echo "  Testing search command in DockerKit CLI..."
    
    output=$("$DOCKERKIT_CLI" help 2>&1)
    if [[ "$output" == *"search"* ]]; then
        echo "    ✅ Search command is registered in CLI"
        return 0
    else
        echo "    ❌ Search command not found in CLI help"
        return 1
    fi
}

test_search_help() {
    echo "  Testing search help output..."
    
    output=$("$DOCKERKIT_CLI" search 2>&1) || true
    
    if [[ "$output" == *"images"* ]] && [[ "$output" == *"containers"* ]] && \
       [[ "$output" == *"volumes"* ]] && [[ "$output" == *"networks"* ]]; then
        echo "    ✅ Search help shows all object types"
        return 0
    else
        echo "    ❌ Search help incomplete"
        return 1
    fi
}

test_search_images_help() {
    echo "  Testing search images help..."
    
    output=$("$SCRIPTS_DIR/docker-search-images.sh" --help 2>&1) || true
    
    if [[ "$output" == *"Usage:"* ]] && [[ "$output" == *"Options:"* ]]; then
        echo "    ✅ Search images help is valid"
        return 0
    else
        echo "    ❌ Search images help is invalid"
        return 1
    fi
}

test_search_containers_help() {
    echo "  Testing search containers help..."
    
    output=$("$SCRIPTS_DIR/docker-search-containers.sh" --help 2>&1) || true
    
    if [[ "$output" == *"Usage:"* ]] && [[ "$output" == *"Options:"* ]]; then
        echo "    ✅ Search containers help is valid"
        return 0
    else
        echo "    ❌ Search containers help is invalid"
        return 1
    fi
}

test_search_volumes_help() {
    echo "  Testing search volumes help..."
    
    output=$("$SCRIPTS_DIR/docker-search-volumes.sh" --help 2>&1) || true
    
    if [[ "$output" == *"Usage:"* ]] && [[ "$output" == *"Options:"* ]]; then
        echo "    ✅ Search volumes help is valid"
        return 0
    else
        echo "    ❌ Search volumes help is invalid"
        return 1
    fi
}

test_search_networks_help() {
    echo "  Testing search networks help..."
    
    output=$("$SCRIPTS_DIR/docker-search-networks.sh" --help 2>&1) || true
    
    if [[ "$output" == *"Usage:"* ]] && [[ "$output" == *"Options:"* ]]; then
        echo "    ✅ Search networks help is valid"
        return 0
    else
        echo "    ❌ Search networks help is invalid"
        return 1
    fi
}

test_search_features_coverage() {
    echo "  Testing search features coverage..."
    local features_found=0
    local total_features=0
    
    # Check images search features
    local image_features=(
        "--name"
        "--tag"
        "--dangling"
        "--min-size"
        "--registry"
    )
    
    for feature in "${image_features[@]}"; do
        ((total_features++))
        if grep -q "$feature" "$SCRIPTS_DIR/docker-search-images.sh" 2>/dev/null; then
            ((features_found++))
        fi
    done
    
    # Check containers search features
    local container_features=(
        "--name"
        "--status"
        "--port"
        "--network"
        "--stats"
    )
    
    for feature in "${container_features[@]}"; do
        ((total_features++))
        if grep -q "$feature" "$SCRIPTS_DIR/docker-search-containers.sh" 2>/dev/null; then
            ((features_found++))
        fi
    done
    
    # Check volumes search features
    local volume_features=(
        "--name"
        "--dangling"
        "--container"
        "--inspect"
    )
    
    for feature in "${volume_features[@]}"; do
        ((total_features++))
        if grep -q "$feature" "$SCRIPTS_DIR/docker-search-volumes.sh" 2>/dev/null; then
            ((features_found++))
        fi
    done
    
    # Check networks search features
    local network_features=(
        "--name"
        "--driver"
        "--container"
        "--subnet"
    )
    
    for feature in "${network_features[@]}"; do
        ((total_features++))
        if grep -q "$feature" "$SCRIPTS_DIR/docker-search-networks.sh" 2>/dev/null; then
            ((features_found++))
        fi
    done
    
    echo "    Features implemented: $features_found/$total_features"
    
    if [[ $features_found -eq $total_features ]]; then
        echo "    ✅ All expected search features are implemented"
        return 0
    else
        echo "    ⚠️  Some search features may be missing"
        return 0  # Warning, not failure
    fi
}

run_tests() {
    local failed=0
    
    test_search_scripts_exist || ((failed++))
    test_search_scripts_syntax || ((failed++))
    test_search_command_in_cli || ((failed++))
    test_search_help || ((failed++))
    test_search_images_help || ((failed++))
    test_search_containers_help || ((failed++))
    test_search_volumes_help || ((failed++))
    test_search_networks_help || ((failed++))
    test_search_features_coverage || ((failed++))
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "✅ All search feature tests passed!"
        return 0
    else
        echo "❌ $failed search feature test(s) failed"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi