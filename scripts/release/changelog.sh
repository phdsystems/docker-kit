#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

VERSION="${1:-$(git -C "$PROJECT_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "unreleased")}"
CHANGELOG="$PROJECT_ROOT/CHANGELOG.md"
DATE="$(date +%Y-%m-%d)"

echo "Generating changelog entry for $VERSION ($DATE)..."

ENTRY="## [$VERSION] - $DATE\n\n$(git -C "$PROJECT_ROOT" log --oneline "$(git -C "$PROJECT_ROOT" describe --tags --abbrev=0 HEAD^ 2>/dev/null || git rev-list --max-parents=0 HEAD)..HEAD" 2>/dev/null | sed 's/^/- /')\n"

if [[ -f "$CHANGELOG" ]]; then
    TMP=$(mktemp)
    { echo -e "$ENTRY"; cat "$CHANGELOG"; } > "$TMP"
    mv "$TMP" "$CHANGELOG"
else
    echo -e "# Changelog\n\n$ENTRY" > "$CHANGELOG"
fi

echo "Changelog updated: $CHANGELOG"
