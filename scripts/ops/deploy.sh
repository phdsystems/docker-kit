#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY:-docker.io}"
IMAGE_NAME="${IMAGE_NAME:-dockerkit}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "Deploying DockerKit image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}..."

docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Deploy complete."
