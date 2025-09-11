#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERKIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$DOCKERKIT_DIR/scripts"

source "$SCRIPT_DIR/../../../tests/lib/test-framework.sh" 2>/dev/null || {
    echo "❌ Failed to source test utils"
    exit 1
}

echo "🧪 Testing Docker Operations Scripts..."

test_script_exists() {
    local script="$1"
    local script_path="$SCRIPTS_DIR/$script"
    
    echo "  Checking $script..."
    if [[ -f "$script_path" ]]; then
        if [[ -x "$script_path" ]]; then
            echo "    ✅ $script exists and is executable"
            return 0
        else
            echo "    ⚠️  $script exists but is not executable"
            return 1
        fi
    else
        echo "    ❌ $script does not exist"
        return 1
    fi
}

test_docker_scripts_syntax() {
    echo "  Testing script syntax..."
    local failed=0
    
    for script in "$SCRIPTS_DIR"/*.sh; do
        if [[ -f "$script" ]]; then
            bash -n "$script" 2>/dev/null || {
                echo "    ❌ Syntax error in $(basename "$script")"
                ((failed++))
            }
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        echo "    ✅ All scripts have valid syntax"
        return 0
    else
        echo "    ❌ $failed script(s) have syntax errors"
        return 1
    fi
}

test_docker_cleanup_script() {
    echo "  Testing docker-cleanup.sh..."
    local script="$SCRIPTS_DIR/docker-cleanup.sh"
    
    if [[ ! -f "$script" ]]; then
        echo "    ❌ Script not found"
        return 1
    fi
    
    if grep -q "docker.*prune" "$script" 2>/dev/null; then
        echo "    ✅ Contains Docker prune commands"
        return 0
    else
        echo "    ❌ Missing Docker prune commands"
        return 1
    fi
}

test_docker_monitor_script() {
    echo "  Testing docker-monitor.sh..."
    local script="$SCRIPTS_DIR/docker-monitor.sh"
    
    if [[ ! -f "$script" ]]; then
        echo "    ❌ Script not found"
        return 1
    fi
    
    if grep -q "docker.*stats\|docker.*ps" "$script" 2>/dev/null; then
        echo "    ✅ Contains Docker monitoring commands"
        return 0
    else
        echo "    ❌ Missing Docker monitoring commands"
        return 1
    fi
}

test_required_scripts() {
    echo "  Checking required scripts..."
    local required_scripts=(
        "docker-containers.sh"
        "docker-images.sh"
        "docker-networks.sh"
        "docker-volumes.sh"
        "docker-cleanup.sh"
        "docker-monitor.sh"
        "docker-security.sh"
    )
    
    local failed=0
    for script in "${required_scripts[@]}"; do
        test_script_exists "$script" || ((failed++))
    done
    
    if [[ $failed -eq 0 ]]; then
        echo "    ✅ All required scripts present"
        return 0
    else
        echo "    ❌ $failed required script(s) missing"
        return 1
    fi
}

run_tests() {
    local failed=0
    
    test_required_scripts || ((failed++))
    test_docker_scripts_syntax || ((failed++))
    test_docker_cleanup_script || ((failed++))
    test_docker_monitor_script || ((failed++))
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        echo "✅ All Docker operations tests passed!"
        return 0
    else
        echo "❌ $failed Docker operations test(s) failed"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi