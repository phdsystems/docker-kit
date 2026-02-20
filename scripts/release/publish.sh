#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.2.0"
    exit 1
fi

echo "Releasing DockerKit $VERSION..."

echo "Building release image..."
"$SCRIPT_DIR/../ci/build.sh" --tag "$VERSION"

echo "Tagging release..."
git -C "$PROJECT_ROOT" tag -a "v$VERSION" -m "Release v$VERSION"

echo "Deploying..."
IMAGE_TAG="$VERSION" "$SCRIPT_DIR/../ops/deploy.sh"
IMAGE_TAG="latest" "$SCRIPT_DIR/../ops/deploy.sh"

echo "Pushing git tag..."
git -C "$PROJECT_ROOT" push origin "v$VERSION"

echo "Release $VERSION complete."
