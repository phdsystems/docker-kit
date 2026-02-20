#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

NEW_VERSION="${1:-}"
if [[ -z "$NEW_VERSION" ]]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.2.0"
    exit 1
fi

VERSION_FILE="$PROJECT_ROOT/dockerkit-package/install.sh"

if [[ -f "$VERSION_FILE" ]]; then
    sed -i "s/DOCKERKIT_VERSION=\".*\"/DOCKERKIT_VERSION=\"$NEW_VERSION\"/" "$VERSION_FILE"
    echo "Updated version to $NEW_VERSION in install.sh"
fi

echo "Bump complete."
