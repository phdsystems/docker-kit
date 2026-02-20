#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-dockerkit}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "Checking DockerKit health..."

if ! docker info &>/dev/null; then
    echo "Error: Docker daemon is not running." >&2
    exit 1
fi
echo "  Docker daemon: OK"

if ! docker image inspect "${IMAGE_NAME}:${IMAGE_TAG}" &>/dev/null; then
    echo "  Image ${IMAGE_NAME}:${IMAGE_TAG}: NOT FOUND" >&2
    exit 1
fi
echo "  Image ${IMAGE_NAME}:${IMAGE_TAG}: OK"

echo "Health check passed."
