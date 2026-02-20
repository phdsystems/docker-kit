#!/bin/bash

# Docker wrapper that handles sudo requirements
# This script detects if Docker needs sudo and sets up the appropriate command

# Global variable for Docker command
export DOCKER_CMD=""

# Detect if Docker needs sudo
detect_docker_command() {
    # Check if docker command exists
    if ! command -v docker &>/dev/null; then
        return 1
    fi
    
    # Try without sudo first
    if docker info &>/dev/null 2>&1; then
        DOCKER_CMD="docker"
        return 0
    fi
    
    # Check if we should try with sudo
    if command -v sudo &>/dev/null; then
        # Try with sudo without password prompt first
        if sudo -n docker info &>/dev/null 2>&1; then
            DOCKER_CMD="sudo docker"
            return 0
        fi
        
        # Set to use sudo even if it needs password
        # The password prompt will happen on first actual use
        DOCKER_CMD="sudo docker"
        return 0
    fi
    
    # Docker not accessible
    return 1
}

# Initialize Docker command on sourcing
if detect_docker_command; then
    export DOCKER_AVAILABLE=true
else
    export DOCKER_AVAILABLE=false
    DOCKER_CMD="docker"  # Set default for error messages
fi

# Wrapper function for Docker commands
docker_run() {
    if [[ "$DOCKER_AVAILABLE" != "true" ]]; then
        echo "Error: Docker is not available or not accessible" >&2
        return 1
    fi
    $DOCKER_CMD "$@"
}