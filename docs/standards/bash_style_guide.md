# Bash Style Guide and Best Practices

## Table of Contents

- [Overview](#overview)
- [File Organization](#file-organization)
  - [File Header](#file-header)
  - [File Naming](#file-naming)
  - [File Structure](#file-structure)
- [Comments and Documentation](#comments-and-documentation)
- [Variables](#variables)
  - [Variable Naming](#variable-naming)
  - [Variable Declaration](#variable-declaration)
  - [Variable Scope](#variable-scope)
- [Functions](#functions)
  - [Function Naming](#function-naming)
  - [Function Documentation](#function-documentation)
  - [Function Structure](#function-structure)
- [Control Structures](#control-structures)
- [Error Handling](#error-handling)
- [Command Substitution](#command-substitution)
- [Pipes and Redirections](#pipes-and-redirections)
- [Arrays and Lists](#arrays-and-lists)
- [String Manipulation](#string-manipulation)
- [Testing and Conditionals](#testing-and-conditionals)
- [Loops](#loops)
- [Input/Output](#inputoutput)
- [Security Best Practices](#security-best-practices)
- [Performance Guidelines](#performance-guidelines)
- [Portability](#portability)
- [Testing Standards](#testing-standards)
- [Documentation Standards](#documentation-standards)
- [Code Review Checklist](#code-review-checklist)
- [Common Patterns](#common-patterns)
- [Anti-Patterns to Avoid](#anti-patterns-to-avoid)
- [References](#references)

## Overview
This guide defines coding standards for bash scripts based on Google Shell Style Guide, GNU Bash standards, and security best practices.

## File Organization

### File Header
```bash
#!/usr/bin/env bash
#
# Script: dck-manager.sh
# Description: Docker container management utility
# Author: DCK Team
# Version: 1.0.0
# License: MIT
#
# Usage:
#   ./dck-manager.sh [options] <command>
#
# Dependencies:
#   - docker >= 20.10
#   - jq >= 1.6
#

set -euo pipefail  # Strict mode
IFS=$'\n\t'       # Secure IFS
```

### File Naming
- Use lowercase with hyphens: `docker-utils.sh`
- Libraries end with `.sh`: `lib/common.sh`
- Executables may omit extension: `dck`
- Test files: `test-docker-utils.sh`

## Code Layout

### Indentation
```bash
# Use 2 spaces (Google style) or 4 spaces (GNU style)
# DCK uses 4 spaces

function process_container() {
    local container="$1"
    
    if docker_exists "$container"; then
        echo "Processing: $container"
        docker inspect "$container"
    fi
}
```

### Line Length
- Maximum 80 characters preferred
- Break long commands with backslash:
```bash
docker run \
    --name "$container_name" \
    --volume "${host_path}:${container_path}" \
    --env "API_KEY=${API_KEY}" \
    --restart unless-stopped \
    "$image_name"
```

### Function Organization
```bash
#!/usr/bin/env bash

# 1. Script settings
set -euo pipefail

# 2. Global constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly VERSION="1.0.0"

# 3. Global variables
DEBUG=${DEBUG:-false}

# 4. Imports/Sources
source "${SCRIPT_DIR}/lib/common.sh"

# 5. Function definitions
function main() {
    # Main logic
}

function helper_function() {
    # Helper logic
}

# 6. Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Naming Conventions

### Variables
```bash
# Local variables: lowercase with underscores
local file_name="document.txt"
local user_count=0

# Global variables: UPPERCASE with underscores
DOCKER_HOST="unix:///var/run/docker.sock"
MAX_RETRIES=3

# Constants: readonly UPPERCASE
readonly CONFIG_FILE="/etc/dck/config.yaml"
readonly DEFAULT_TIMEOUT=30

# Environment variables: UPPERCASE
export DCK_HOME="${HOME}/.dck"
export PATH="${DCK_HOME}/bin:${PATH}"
```

### Functions
```bash
# Use lowercase with underscores
function validate_input() {
    # Function names should be verbs
}

# Prefix private functions with underscore
function _internal_helper() {
    # Not intended for external use
}

# Namespace functions in libraries
function docker::list_containers() {
    # Prevents naming conflicts
}
```

## Variable Usage

### Declaration and Scope
```bash
# Declare variables at function start
function process_data() {
    local input_file="$1"
    local output_file="$2"
    local temp_file
    local line_count=0
    
    temp_file="$(mktemp)"
    # ...
}

# Use local for function variables
function calculate() {
    local -i sum=0  # Integer
    local -a array=()  # Array
    local -A map=()  # Associative array
}

# Declare global constants
declare -gr CONSTANT="immutable"
```

### Quoting
```bash
# Always quote variables
echo "$variable"
echo "${array[@]}"

# Quote command substitutions
result="$(command)"

# Quote in conditionals
if [[ "$var" == "value" ]]; then

# Exception: Arithmetic context
if (( count > 10 )); then
```

### Parameter Expansion
```bash
# Default values
port="${PORT:-8080}"

# Required values
api_key="${API_KEY:?Error: API_KEY not set}"

# String manipulation
filename="${path##*/}"  # Basename
dirname="${path%/*}"    # Directory
extension="${filename##*.}"  # Extension

# Length
if [[ ${#string} -gt 100 ]]; then
```

## Functions

### Function Definition
```bash
# Preferred style (more portable)
function my_function() {
    local arg1="$1"
    local arg2="${2:-default}"
    
    # Function body
    return 0
}

# Alternative style
my_function() {
    # Function body
}
```

### Documentation
```bash
# Document complex functions
# 
# Process Docker container with specified options
# 
# Arguments:
#   $1 - Container name or ID
#   $2 - Action (start|stop|restart)
#   $3 - Timeout in seconds (optional, default: 30)
# 
# Returns:
#   0 - Success
#   1 - Container not found
#   2 - Action failed
#
function process_container() {
    local container="$1"
    local action="$2"
    local timeout="${3:-30}"
    # ...
}
```

### Return Values
```bash
# Use return for status codes (0-255)
function check_permission() {
    if [[ -w "$1" ]]; then
        return 0  # Success
    else
        return 1  # Failure
    fi
}

# Use stdout for data
function get_container_id() {
    local name="$1"
    docker ps -q --filter "name=${name}"
}

# Usage
if id="$(get_container_id "myapp")"; then
    echo "Container ID: $id"
fi
```

## Conditionals

### If Statements
```bash
# Single condition
if [[ "$user" == "admin" ]]; then
    grant_access
fi

# Multiple conditions
if [[ "$user" == "admin" ]] && [[ "$ip" == "192.168.1.1" ]]; then
    grant_full_access
elif [[ "$user" == "user" ]]; then
    grant_limited_access
else
    deny_access
fi

# One-liner (use sparingly)
[[ -f "$file" ]] && process_file "$file"

# Prefer explicit if for clarity
if [[ -f "$file" ]]; then
    process_file "$file"
fi
```

### Case Statements
```bash
case "$action" in
    start|START)
        start_service
        ;;
    stop|STOP)
        stop_service
        ;;
    restart|RESTART)
        stop_service
        start_service
        ;;
    status)
        check_status
        ;;
    *)
        echo "Unknown action: $action" >&2
        exit 1
        ;;
esac
```

## Loops

### For Loops
```bash
# Iterate over list
for container in nginx redis postgres; do
    docker start "$container"
done

# Iterate over array
containers=("nginx" "redis" "postgres")
for container in "${containers[@]}"; do
    docker start "$container"
done

# C-style (avoid in POSIX scripts)
for ((i=0; i<10; i++)); do
    echo "$i"
done

# Process files safely
for file in *.txt; do
    [[ -e "$file" ]] || continue  # Handle no matches
    process_file "$file"
done
```

### While Loops
```bash
# Read lines from file
while IFS= read -r line; do
    process_line "$line"
done < input.txt

# Read from command
docker ps --format '{{.Names}}' | while IFS= read -r container; do
    echo "Container: $container"
done

# Counter loop
counter=0
while [[ $counter -lt 10 ]]; do
    echo "$counter"
    ((counter++))
done
```

## Error Handling

### Exit Codes
```bash
# Standard exit codes
readonly E_SUCCESS=0
readonly E_GENERAL=1
readonly E_MISUSE=2
readonly E_CANTEXEC=126
readonly E_NOTFOUND=127

# Custom exit codes (64-113)
readonly E_MISSING_ARG=64
readonly E_INVALID_INPUT=65
readonly E_NETWORK_ERROR=66
```

### Error Messages
```bash
# Send errors to stderr
echo "Error: File not found" >&2

# Error function
error() {
    echo "Error: $*" >&2
}

# Fatal error function
die() {
    echo "Fatal: $*" >&2
    exit 1
}

# Usage
[[ -f "$config" ]] || die "Config file not found: $config"
```

### Trap Handling
```bash
# Cleanup on exit
cleanup() {
    local exit_code=$?
    rm -f "$temp_file"
    [[ $exit_code -eq 0 ]] || echo "Script failed with code: $exit_code" >&2
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

# Debug trap
trap 'echo "Line $LINENO: $BASH_COMMAND"' DEBUG
```

## Input Validation

### Argument Parsing
```bash
function parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--file)
                FILE="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                ARGS+=("$1")
                shift
                ;;
        esac
    done
}
```

### Input Sanitization
```bash
# Validate alphanumeric
if [[ ! "$input" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    die "Invalid input: $input"
fi

# Validate file path
if [[ "$path" =~ \.\. ]]; then
    die "Path traversal detected: $path"
fi

# Validate integer
if ! [[ "$number" =~ ^[0-9]+$ ]]; then
    die "Not a number: $number"
fi
```

## Debugging

### Debug Mode
```bash
# Enable debug mode
if [[ "${DEBUG:-false}" == "true" ]]; then
    set -x  # Print commands
    PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
fi

# Debug function
debug() {
    [[ "${DEBUG:-false}" == "true" ]] && echo "DEBUG: $*" >&2
}

# Usage
debug "Processing file: $file"
```

### Logging
```bash
# Log levels
readonly LOG_LEVEL_ERROR=0
readonly LOG_LEVEL_WARN=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_DEBUG=3

LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date -Iseconds)"
    
    case "$level" in
        ERROR)
            [[ $LOG_LEVEL -ge $LOG_LEVEL_ERROR ]] && \
                echo "[$timestamp] [ERROR] $message" >&2
            ;;
        WARN)
            [[ $LOG_LEVEL -ge $LOG_LEVEL_WARN ]] && \
                echo "[$timestamp] [WARN] $message" >&2
            ;;
        INFO)
            [[ $LOG_LEVEL -ge $LOG_LEVEL_INFO ]] && \
                echo "[$timestamp] [INFO] $message"
            ;;
        DEBUG)
            [[ $LOG_LEVEL -ge $LOG_LEVEL_DEBUG ]] && \
                echo "[$timestamp] [DEBUG] $message"
            ;;
    esac
}
```

## Comments

### Inline Comments
```bash
# Check if container exists
if docker_exists "$container"; then
    docker stop "$container"  # Stop gracefully
fi

# TODO: Add timeout handling
# FIXME: Handle special characters in names
# NOTE: Requires Docker 20.10+
```

### Block Comments
```bash
# This function processes Docker containers based on
# the specified action. It handles errors gracefully
# and provides detailed logging for debugging.
#
# The function supports the following actions:
#   - start: Start stopped containers
#   - stop: Stop running containers
#   - restart: Restart containers
```

## Testing

### Unit Test Structure
```bash
#!/usr/bin/env bash
# test-docker-utils.sh

source "$(dirname "$0")/../src/docker-utils.sh"

# Test helper
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    if [[ "$expected" != "$actual" ]]; then
        echo "FAIL: $message"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        return 1
    fi
    echo "PASS: $message"
    return 0
}

# Test cases
test_container_exists() {
    # Setup
    local container="test-container"
    
    # Test
    result=$(container_exists "$container")
    
    # Assert
    assert_equals "true" "$result" "Container should exist"
}

# Run tests
test_container_exists
```

## Common Pitfalls to Avoid

### 1. Unquoted Variables
```bash
# Wrong
rm $file

# Right
rm "$file"
```

### 2. Using eval
```bash
# Wrong - Command injection risk
eval "$user_input"

# Right - Use case or arrays
case "$command" in
    start|stop|restart) "$command" ;;
esac
```

### 3. Parsing ls Output
```bash
# Wrong
for file in $(ls *.txt); do

# Right
for file in *.txt; do
    [[ -e "$file" ]] || continue
```

### 4. Missing Error Handling
```bash
# Wrong
cd /some/dir
rm *

# Right
cd /some/dir || exit 1
rm ./* 2>/dev/null || true
```

## DCK Style Compliance

| Style Rule | Status | Implementation |
|------------|--------|----------------|
| Indentation (4 spaces) | ✅ | Consistent |
| Line length (<80) | ⚠️ | Mostly compliant |
| Function names | ✅ | snake_case |
| Variable names | ✅ | Proper casing |
| Error handling | ✅ | set -euo pipefail |
| Comments | ✅ | Well documented |
| Quoting | ✅ | Variables quoted |

## References

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Hackers Wiki](https://wiki.bash-hackers.org/)
- [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)
- [Pure Bash Bible](https://github.com/dylanaraps/pure-bash-bible)