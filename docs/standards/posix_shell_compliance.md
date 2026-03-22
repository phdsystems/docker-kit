---
layout: default
title: POSIX Shell Compliance
parent: Standards
nav_order: 6
---

# POSIX Shell Compliance Standards

**Audience**: Contributors, portability reviewers

## WHAT

POSIX.1-2017 compliance reference for shell scripting, documenting which Bash features are POSIX-compliant and which are Bash-only.

## WHY

Understanding POSIX boundaries helps contributors make intentional decisions about portability vs Bash-specific convenience.

## HOW

### Table of Contents

- [Overview](#overview)
- [Why POSIX Compliance Matters](#why-posix-compliance-matters)
- [POSIX vs Bash Features](#posix-vs-bash-features)
  - [POSIX Compliant Features](#-posix-compliant-features)
  - [Bash-Only Features to Avoid](#-bash-only-features-to-avoid)
- [POSIX Compliant Alternatives](#posix-compliant-alternatives)
- [Testing for POSIX Compliance](#testing-for-posix-compliance)
- [Common Pitfalls](#common-pitfalls)
- [POSIX Shell Built-ins](#posix-shell-built-ins)
- [POSIX Utilities](#posix-utilities)
- [Best Practices](#best-practices)
- [DCK Implementation](#dck-implementation)
- [Shell Detection](#shell-detection)
- [References](#references)

## Overview
POSIX (Portable Operating System Interface) defines standards for shell scripting portability across Unix-like systems. This ensures scripts work on any POSIX-compliant shell (sh, dash, ksh, etc.), not just bash.

## Why POSIX Compliance Matters

1. **Portability**: Scripts run on any Unix-like system
2. **Container Compatibility**: Alpine uses ash, Ubuntu uses dash
3. **Performance**: POSIX shells are faster and smaller
4. **Embedded Systems**: Limited environments may only have sh
5. **CI/CD**: Build environments may not have bash

## POSIX vs Bash Features

### POSIX Compliant Features

#### Basic Syntax
```sh
#!/bin/sh
# POSIX shell shebang

# Variable assignment
VAR="value"
readonly VAR="constant"

# Command substitution
result=$(command)

# Arithmetic
result=$((2 + 2))

# Conditionals
if [ "$var" = "value" ]; then
    echo "match"
elif [ "$var" != "other" ]; then
    echo "no match"
else
    echo "default"
fi

# Loops
for item in item1 item2 item3; do
    echo "$item"
done

while [ "$count" -lt 10 ]; do
    count=$((count + 1))
done

# Case statements
case "$var" in
    pattern1) echo "match 1" ;;
    pattern2|pattern3) echo "match 2 or 3" ;;
    *) echo "default" ;;
esac

# Functions
my_function() {
    echo "arg: $1"
    return 0
}

# Parameter expansion
${var:-default}     # Use default if unset
${var:=default}     # Set and use default if unset
${var:?error}       # Error if unset
${var:+alternate}   # Use alternate if set
${#var}            # String length
${var%pattern}     # Remove shortest suffix
${var%%pattern}    # Remove longest suffix
${var#pattern}     # Remove shortest prefix
${var##pattern}    # Remove longest prefix
```

#### Test Operators
```sh
# File tests
[ -e file ]    # Exists
[ -f file ]    # Regular file
[ -d dir ]     # Directory
[ -r file ]    # Readable
[ -w file ]    # Writable
[ -x file ]    # Executable
[ -s file ]    # Size > 0
[ -L link ]    # Symbolic link

# String tests
[ -z "$str" ]     # Zero length
[ -n "$str" ]     # Non-zero length
[ "$s1" = "$s2" ] # Equal
[ "$s1" != "$s2" ] # Not equal

# Numeric tests
[ "$n1" -eq "$n2" ]  # Equal
[ "$n1" -ne "$n2" ]  # Not equal
[ "$n1" -lt "$n2" ]  # Less than
[ "$n1" -le "$n2" ]  # Less or equal
[ "$n1" -gt "$n2" ]  # Greater than
[ "$n1" -ge "$n2" ]  # Greater or equal

# Logical operators
[ expr1 ] && [ expr2 ]  # AND
[ expr1 ] || [ expr2 ]  # OR
! [ expr ]              # NOT
```

### Bash-Only Features (Not POSIX)

#### Arrays
```bash
# Bash arrays - NOT POSIX
array=(one two three)
echo "${array[0]}"
echo "${array[@]}"
echo "${#array[@]}"

# POSIX alternative - use positional parameters
set -- one two three
echo "$1"  # First element
echo "$@"  # All elements
echo "$#"  # Count
```

#### Advanced Test Syntax
```bash
# Bash [[ ]] - NOT POSIX
[[ "$str" =~ regex ]]
[[ "$str" == pattern* ]]
[[ "$a" < "$b" ]]

# POSIX alternatives
expr "$str" : "regex" >/dev/null
case "$str" in pattern*) ;; esac
[ "$(printf '%s\n' "$a" "$b" | sort | head -n1)" = "$a" ]
```

#### String Manipulation
```bash
# Bash string manipulation - NOT POSIX
${var^^}      # Uppercase
${var,,}      # Lowercase
${var/old/new} # Replace first
${var//old/new} # Replace all

# POSIX alternatives
echo "$var" | tr '[:lower:]' '[:upper:]'  # Uppercase
echo "$var" | tr '[:upper:]' '[:lower:]'  # Lowercase
echo "$var" | sed 's/old/new/'            # Replace first
echo "$var" | sed 's/old/new/g'           # Replace all
```

#### Process Substitution
```bash
# Bash process substitution - NOT POSIX
diff <(cmd1) <(cmd2)

# POSIX alternative using temp files
tmp1=$(mktemp)
tmp2=$(mktemp)
cmd1 > "$tmp1"
cmd2 > "$tmp2"
diff "$tmp1" "$tmp2"
rm -f "$tmp1" "$tmp2"
```

#### Arithmetic
```bash
# Bash arithmetic - NOT POSIX
((count++))
((result = a * b))
for ((i=0; i<10; i++)); do

# POSIX alternatives
count=$((count + 1))
result=$((a * b))
i=0; while [ "$i" -lt 10 ]; do
    i=$((i + 1))
done
```

## POSIX Compliance Checklist

### Script Header
```sh
#!/bin/sh
# POSIX compliant shell script
set -e  # Exit on error
set -u  # Error on undefined variables
```

### Variable Handling
- [x] Always quote variables: `"$var"`
- [x] Use `${var:-default}` for defaults
- [x] Check if set: `[ -n "${var:-}" ]`
- [x] No arrays, use positional parameters
- [x] No declare/typeset/local (use subshells)

### Command Syntax
- [x] Use `[ ]` not `[[ ]]`
- [x] Use `$(...)` not `` `...` ``
- [x] Use `$((...))` for arithmetic
- [x] No `<<<` here-strings
- [x] No `<()` process substitution

### Functions
```sh
# POSIX function definition
my_func() {
    # No 'local' keyword - use subshell for scope
    (
        var="local value"
        echo "$var"
    )
}

# No 'function' keyword
# No 'declare -f'
```

### Portability Tips

#### 1. Echo vs Printf
```sh
# echo behavior varies between shells
echo -n "text"  # May not work

# printf is POSIX and consistent
printf '%s' "text"
printf '%s\n' "text with newline"
```

#### 2. Command Availability
```sh
# Check command exists (POSIX)
command -v docker >/dev/null 2>&1 || {
    echo "docker not found" >&2
    exit 1
}

# NOT: which, type -P, hash
```

#### 3. Signal Handling
```sh
# POSIX signal names (no SIG prefix)
trap 'cleanup' INT TERM EXIT
trap 'cleanup' 2 15 0  # Numeric also works

# NOT: SIGINT, SIGTERM
```

#### 4. Redirection
```sh
# POSIX redirection
cmd > file 2>&1      # Stdout and stderr to file
cmd >> file 2>&1     # Append

# NOT: &>, &>>
```

## Testing for POSIX Compliance

### 1. Use sh Instead of Bash
```bash
# Test with POSIX shell
sh -n script.sh  # Syntax check
sh script.sh     # Run with sh
```

### 2. Use Dash (Debian/Ubuntu)
```bash
# Install dash
apt-get install dash

# Test script
dash -n script.sh
dash script.sh
```

### 3. Use ShellCheck
```bash
# Check for POSIX compliance
shellcheck --shell=sh script.sh

# Add to script
# shellcheck shell=sh
```

### 4. Use checkbashisms
```bash
# Install
apt-get install devscripts

# Check for bashisms
checkbashisms script.sh
```

## Common POSIX Violations and Fixes

### 1. Arrays
```bash
# Violation
files=(*.txt)
for file in "${files[@]}"; do

# POSIX Fix
for file in *.txt; do
```

### 2. Substring Expansion
```bash
# Violation
if [[ "$string" == *"substring"* ]]; then

# POSIX Fix
case "$string" in
    *substring*) echo "found" ;;
esac
```

### 3. Regex Matching
```bash
# Violation
if [[ "$email" =~ ^[a-z]+@[a-z]+\.[a-z]+$ ]]; then

# POSIX Fix
if expr "$email" : '^[a-z]\+@[a-z]\+\.[a-z]\+$' >/dev/null; then
```

### 4. Integer Comparison in [[
```bash
# Violation
if [[ $num -gt 10 ]]; then

# POSIX Fix
if [ "$num" -gt 10 ]; then
```

### 5. Here Strings
```bash
# Violation
cmd <<< "$variable"

# POSIX Fix
printf '%s\n' "$variable" | cmd
# or
cmd <<EOF
$variable
EOF
```

## DCK POSIX Compliance Status

| Feature | POSIX | DCK Status | Notes |
|---------|-------|------------|-------|
| Shebang | `#!/bin/sh` | ⚠️ | Uses `#!/usr/bin/env bash` |
| Test syntax | `[ ]` | ✅ | Mostly compliant |
| Arrays | None | ⚠️ | Uses bash arrays |
| Arithmetic | `$(())` | ✅ | POSIX compliant |
| Functions | `name()` | ✅ | POSIX style |
| Local vars | None | ⚠️ | Uses `local` keyword |
| String ops | Limited | ⚠️ | Uses bash features |

### Making DCK POSIX Compliant

To make DCK fully POSIX compliant:

1. **Replace bash arrays with functions**:
```sh
# Instead of: containers=()
# Use: set --
add_container() { set -- "$@" "$1"; }
```

2. **Replace string operations**:
```sh
# Instead of: ${var,,}
# Use: echo "$var" | tr '[:upper:]' '[:lower:]'
```

3. **Replace [[ with [**:
```sh
# Instead of: [[ "$var" == "value" ]]
# Use: [ "$var" = "value" ]
```

4. **Remove local keyword**:
```sh
# Instead of: local var="value"
# Use subshell: (var="value"; command)
```

## Benefits of POSIX Compliance

1. **Universal Compatibility**: Runs on any Unix-like system
2. **Container Ready**: Works in minimal containers
3. **Faster Execution**: POSIX shells are lighter
4. **Better Testing**: Easier to validate behavior
5. **Industry Standard**: Expected in enterprise environments

## References

- [POSIX.1-2017 Shell Command Language](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)
- [Dash as /bin/sh](https://wiki.ubuntu.com/DashAsBinSh)
- [Rich's sh (POSIX shell) tricks](https://www.etalabs.net/sh_tricks.html)
- [POSIX Shell Tutorial](https://www.grymoire.com/Unix/Sh.html)
- [Autoconf Portable Shell](https://www.gnu.org/savannah-checkouts/gnu/autoconf/manual/autoconf-2.69/html_node/Portable-Shell.html)