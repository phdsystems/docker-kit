#!/bin/bash
# Simple validation test for docker-search-images.sh

SCRIPT="/home/developer/phd-ade/src/scripts/docker-search-images.sh"

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
