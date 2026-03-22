# Bash/Shell Security Guidelines

**Audience**: Contributors, security reviewers

## WHAT

Security guidelines covering command injection prevention, path protection, input validation, and privilege management for Bash scripts.

## WHY

Shell scripts are a common attack vector. Explicit security guidelines prevent vulnerabilities from reaching production.

## HOW

### Table of Contents

- [Overview](#overview)
- [Security Standards Compliance](#security-standards-compliance)
  - [1. Command Injection Prevention](#1-command-injection-prevention-)
  - [2. Path Injection Protection](#2-path-injection-protection-)
  - [3. Variable Sanitization](#3-variable-sanitization-)
  - [4. Secure Temporary Files](#4-secure-temporary-files-)
  - [5. Input Validation](#5-input-validation-)
  - [6. Privilege Management](#6-privilege-management-)
  - [7. Race Condition Prevention](#7-race-condition-prevention-)
  - [8. Signal Handling](#8-signal-handling-)
  - [9. Secure Defaults](#9-secure-defaults-)
  - [10. Error Information Disclosure](#10-error-information-disclosure-)
- [Shell Security Tools](#shell-security-tools)
- [Common Vulnerabilities](#common-vulnerabilities)
- [Security Checklist](#security-checklist)
- [References](#references)

## Overview
Comprehensive security and quality standards for shell scripts, focusing on security, portability, and maintainability.

## Security Standards Compliance

### 1. Command Injection Prevention ✅

**Risk**: Unescaped user input in commands
**Severity**: Critical

**Mitigations Implemented**:
```bash
# ❌ BAD - Command injection vulnerable
eval "docker run $user_input"
docker run $(echo $user_input)

# ✅ GOOD - Safe practices
docker run "$@"                    # Use positional parameters
docker run "${container_name}"      # Quote variables
printf '%q' "$user_input"          # Escape special characters
```

### 2. Path Injection Protection ✅

**Risk**: Malicious PATH manipulation
**Severity**: High

**Implementation**:
```bash
#!/usr/bin/env bash
# ✅ Set secure PATH at script start
export PATH="/usr/local/bin:/usr/bin:/bin"

# ✅ Use absolute paths for critical commands
readonly DOCKER="/usr/bin/docker"
readonly GIT="/usr/bin/git"

# ✅ Verify command locations
command -v docker >/dev/null 2>&1 || { echo "docker not found"; exit 1; }
```

### 3. Input Validation ✅

**Risk**: Malformed or malicious input
**Severity**: High

```bash
# ✅ Validate all inputs
validate_container_name() {
    local name="$1"
    # Only allow alphanumeric, dash, underscore
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Invalid container name" >&2
        return 1
    fi
}

# ✅ Sanitize file paths
sanitize_path() {
    local path="$1"
    # Remove directory traversal attempts
    path="${path//\.\.\/}"
    path="${path//\/\//\/}"
    echo "$path"
}
```

### 4. Secure File Operations ✅

**Risk**: Race conditions, symlink attacks
**Severity**: Medium

```bash
# ✅ Use mktemp for temporary files
readonly TMP_FILE="$(mktemp /tmp/dck.XXXXXX)"
trap 'rm -f "$TMP_FILE"' EXIT

# ✅ Set restrictive permissions
umask 077  # Files: 600, Dirs: 700

# ✅ Check file ownership before operations
if [[ "$(stat -c %U "$file")" != "$USER" ]]; then
    echo "Error: File not owned by current user" >&2
    exit 1
fi
```

### 5. Secret Management ✅

**Risk**: Exposed credentials
**Severity**: Critical

```bash
# ❌ BAD - Secrets in code
API_KEY="sk-1234567890"

# ✅ GOOD - Environment variables
API_KEY="${API_KEY:?Error: API_KEY not set}"

# ✅ GOOD - Read from secure file
API_KEY="$(cat /run/secrets/api_key)"

# ✅ Prevent secrets in history
set +o history  # Disable history
export HISTCONTROL=ignorespace  # Ignore commands starting with space
```

### 6. Error Handling ✅

**Risk**: Silent failures, undefined behavior
**Severity**: Medium

```bash
#!/usr/bin/env bash
# ✅ Strict error handling
set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'        # Set secure Internal Field Separator

# ✅ Error trap with cleanup
cleanup() {
    local exit_code=$?
    echo "Cleaning up..." >&2
    # Cleanup operations
    exit "$exit_code"
}
trap cleanup EXIT ERR

# ✅ Explicit error checking
if ! docker_output="$(docker ps 2>&1)"; then
    echo "Error: Failed to list containers: $docker_output" >&2
    exit 1
fi
```

### 7. Privilege Escalation Prevention ✅

**Risk**: Unauthorized privilege elevation
**Severity**: Critical

```bash
# ✅ Never use sudo in scripts without validation
require_sudo() {
    if [[ $EUID -eq 0 ]]; then
        echo "Error: This script should not be run as root" >&2
        exit 1
    fi
}

# ✅ Drop privileges when possible
drop_privileges() {
    if [[ $EUID -eq 0 ]]; then
        exec su -s /bin/bash nobody "$0" "$@"
    fi
}
```

### 8. Resource Limits ✅

**Risk**: Resource exhaustion
**Severity**: Medium

```bash
# ✅ Set resource limits
ulimit -t 300   # CPU time limit (5 minutes)
ulimit -f 10000 # File size limit (10MB)
ulimit -u 100   # Process limit

# ✅ Timeout for long operations
timeout 30 docker pull "$image" || {
    echo "Error: Image pull timed out" >&2
    exit 1
}
```

### 9. Logging and Auditing ✅

**Risk**: No audit trail
**Severity**: Low

```bash
# ✅ Structured logging
readonly LOG_FILE="/var/log/dck/operations.log"

log() {
    local level="$1"
    shift
    echo "$(date -Iseconds) [$level] [$$] $*" >> "$LOG_FILE"
}

log INFO "Starting container: $container_name"
log ERROR "Failed to start container: $error_message"

# ✅ Audit sensitive operations
audit_action() {
    logger -t dck -p auth.info "User $USER performed: $1"
}
```

### 10. TOCTOU (Time-of-Check-Time-of-Use) Prevention ✅

**Risk**: Race condition vulnerabilities
**Severity**: Medium

```bash
# ❌ BAD - TOCTOU vulnerable
if [[ -f "$file" ]]; then
    cat "$file"  # File might change between check and use
fi

# ✅ GOOD - Atomic operations
if output="$(cat "$file" 2>/dev/null)"; then
    echo "$output"
else
    echo "Error: Cannot read file" >&2
fi
```

## ShellCheck Compliance

### Severity Levels
- **Error**: Must fix (SC2086, SC2046, SC2006)
- **Warning**: Should fix (SC2166, SC2164, SC2155)
- **Info**: Consider fixing (SC2034, SC2162)
- **Style**: Optional (SC2004, SC2007)

### Critical Rules Enforced

```bash
# SC2086: Quote variables to prevent word splitting
# ❌ BAD
rm $file
# ✅ GOOD
rm "$file"

# SC2046: Quote command substitution
# ❌ BAD
rm $(ls *.tmp)
# ✅ GOOD
rm "$(ls *.tmp)" || find . -name "*.tmp" -delete

# SC2006: Use $(...) instead of backticks
# ❌ BAD
result=`command`
# ✅ GOOD
result="$(command)"

# SC2016: Single quotes prevent expansion
# ❌ BAD
echo '$HOME'  # Prints literal $HOME
# ✅ GOOD
echo "$HOME"  # Prints /home/user

# SC2068: Quote array expansions
# ❌ BAD
args=$@
# ✅ GOOD
args=("$@")
```

## POSIX Compliance

### Portable Shell Features

```bash
#!/bin/sh  # POSIX shell, not bash

# ✅ POSIX compliant
[ "$var" = "value" ]        # String comparison
[ "$num" -eq 5 ]           # Numeric comparison
command -v docker          # Command existence

# ❌ Bash-only features to avoid for portability
[[ "$var" == "value" ]]    # Double brackets
(( num++ ))                # Arithmetic evaluation
arrays=()                  # Arrays
${var,,}                   # Case conversion
```

## Security Checklist

### Pre-Development
- [ ] Define trust boundaries
- [ ] Identify sensitive operations
- [ ] Plan input validation strategy
- [ ] Design error handling approach

### During Development
- [ ] Set strict mode (`set -euo pipefail`)
- [ ] Quote all variables
- [ ] Validate all inputs
- [ ] Use absolute paths
- [ ] Implement timeouts
- [ ] Add comprehensive logging
- [ ] Handle errors explicitly
- [ ] Clean up resources (trap EXIT)

### Testing
- [ ] Run ShellCheck with strict settings
- [ ] Test with malicious inputs
- [ ] Verify privilege requirements
- [ ] Check resource consumption
- [ ] Test error conditions
- [ ] Audit log output

### Deployment
- [ ] Set restrictive permissions (755 or less)
- [ ] Verify no hardcoded secrets
- [ ] Document security assumptions
- [ ] Enable audit logging
- [ ] Set up monitoring

## Static Analysis Tools

### ShellCheck Configuration
```yaml
# .shellcheckrc
shell=bash
enable=all
exclude=SC2312  # Consider shellcheck -x
severity=warning

# In scripts
# shellcheck disable=SC2034  # Unused variable (if intentional)
```

### Additional Tools
```bash
# bashate - Style checker
bashate --ignore E006 *.sh

# bash -n - Syntax check
bash -n script.sh

# set -x - Debug mode
bash -x script.sh

# shfmt - Formatter
shfmt -i 2 -bn -ci -w *.sh
```

## Common Security Anti-Patterns

### 1. Unsafe eval/exec
```bash
# ❌ NEVER DO THIS
eval "$user_input"
exec $command

# ✅ Safe alternatives
case "$user_input" in
    start|stop|restart) "$user_input" ;;
    *) echo "Invalid command" >&2 ;;
esac
```

### 2. Unquoted Variables
```bash
# ❌ Word splitting vulnerability
if [ $USER_INPUT = "value" ]; then

# ✅ Safe comparison
if [ "$USER_INPUT" = "value" ]; then
```

### 3. Unsafe Find/Exec
```bash
# ❌ Command injection via filenames
find . -type f -exec rm {} \;

# ✅ Safe deletion
find . -type f -delete
# or
find . -type f -print0 | xargs -0 rm
```

### 4. Predictable Temp Files
```bash
# ❌ Race condition
tmp_file="/tmp/myapp.tmp"

# ✅ Secure temp file
tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT
```

## DCK Implementation Status

| Security Control | Status | Implementation |
|-----------------|--------|----------------|
| Command Injection Prevention | ✅ | All variables quoted |
| Path Injection Protection | ✅ | Absolute paths used |
| Input Validation | ✅ | Validation functions |
| Secure File Operations | ✅ | mktemp, proper permissions |
| Secret Management | ✅ | No hardcoded secrets |
| Error Handling | ✅ | set -euo pipefail |
| Privilege Prevention | ✅ | Non-root checks |
| Resource Limits | ✅ | Timeouts implemented |
| Logging/Auditing | ✅ | Structured logging |
| TOCTOU Prevention | ✅ | Atomic operations |

## References
- [OWASP Command Injection](https://owasp.org/www-community/attacks/Command_Injection)
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls)
- [POSIX Shell Standard](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)