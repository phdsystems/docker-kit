#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if ! command -v shellcheck &>/dev/null; then
    echo "Error: shellcheck is not installed. Run scripts/dev/setup.sh first." >&2
    exit 1
fi

echo "Linting DockerKit shell scripts..."

FAILED=0
while IFS= read -r -d '' script; do
    if shellcheck "$script"; then
        echo "  OK: $script"
    else
        echo "  FAIL: $script"
        FAILED=$((FAILED + 1))
    fi
done < <(find "$PROJECT_ROOT/main/src" -name "*.sh" -print0)

if [[ $FAILED -gt 0 ]]; then
    echo "$FAILED script(s) failed lint."
    exit 1
fi

echo "Lint complete."
