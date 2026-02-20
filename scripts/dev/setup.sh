#!/usr/bin/env bash
set -euo pipefail

echo "Setting up DockerKit development environment..."

if ! command -v docker &>/dev/null; then
    echo "Warning: Docker is not installed. Install it from https://docs.docker.com/get-docker/"
fi

if ! command -v shellcheck &>/dev/null; then
    echo "Installing shellcheck..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get install -y shellcheck
    elif command -v brew &>/dev/null; then
        brew install shellcheck
    else
        echo "Error: Cannot install shellcheck automatically. Install it manually." >&2
        exit 1
    fi
fi

echo "Setup complete."
