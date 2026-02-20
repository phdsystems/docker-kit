#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Cleaning DockerKit build artifacts..."

find "$PROJECT_ROOT" -name "*.tmp" -delete
find "$PROJECT_ROOT" -name "*.log" -not -path "*/tests/*" -delete

echo "Removing dangling Docker images from builds..."
docker image prune -f --filter "label=project=dockerkit" 2>/dev/null || true

echo "Clean complete."
