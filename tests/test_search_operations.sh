#!/bin/bash
# Simple validation test for docker-search-images.sh

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/main/src/docker-search-images.sh"

if [[ ! -f "$SCRIPT" ]]; then
    echo "Script not found: $SCRIPT"
    exit 1
fi

# Test help output
if "$SCRIPT" --help >/dev/null 2>&1; then
    echo "Help command works"
    exit 0
else
    echo "Help command failed"
    exit 1
fi
