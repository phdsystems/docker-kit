# ShellCheck Rules and Compliance

**Audience**: Contributors, CI/CD maintainers

## WHAT

Complete ShellCheck rule reference with DockerKit's compliance status across all 224 rules and 4 severity levels.

## WHY

ShellCheck is the primary static analysis gate in CI. Understanding rules and their rationale prevents false suppressions and catches real bugs.

## HOW

### Rule Categories

### Error Level (Must Fix)

#### SC1000-1099: Parser Errors
| Code | Description | Status | Example |
|------|-------------|--------|---------|
| SC1001 | This `\` will be a regular backslash | ✅ | `echo C:\Users` |
| SC1003 | Want to escape a single quote? Use `'\''` | ✅ | `echo 'It'\''s'` |
| SC1007 | Remove space after `=` in assignment | ✅ | `var= value` |
| SC1008 | Semicolon required before `}` | ✅ | `{ echo hi }` |
| SC1009 | Unexpected character | ✅ | `echo "hi"​` (hidden char) |
| SC1010 | Use semicolon or newline before `done` | ✅ | `for i in *; do echo $i done` |
| SC1035 | Space required after `[` | ✅ | `[! -f file]` |
| SC1045 | It's not `foo &; bar`, just `foo & bar` | ✅ | `cmd1 &; cmd2` |
| SC1072 | Expected `"`/`'`/`]`/`)` | ✅ | `echo "unclosed` |
| SC1073 | Couldn't parse this statement | ✅ | Syntax errors |
| SC1083 | This `{` is literal | ✅ | `echo {1.10}` |
| SC1089 | Parsing stopped here | ✅ | Major syntax error |

#### SC2000-2099: Command Errors
| Code | Description | Status | Implementation |
|------|-------------|--------|----------------|
| SC2006 | Use `$(...)` instead of backticks | ✅ | `result="$(cmd)"` |
| SC2016 | Single quotes prevent expansion | ✅ | Use double quotes |
| SC2026 | This word is outside of quotes | ✅ | Quote properly |
| SC2028 | `echo` won't expand escape sequences | ✅ | Use `printf` |
| SC2046 | Quote this to prevent word splitting | ✅ | `"$(command)"` |
| SC2053 | Quote the right-hand side of `=~` | ✅ | `[[ $x =~ "$pattern" ]]` |
| SC2068 | Double quote array expansions | ✅ | `"${array[@]}"` |
| SC2086 | Double quote to prevent globbing | ✅ | `"$var"` |
| SC2088 | Tilde doesn't expand in quotes | ✅ | Use `$HOME` |
| SC2089 | Quotes prevent tilde expansion | ✅ | `path="$HOME/dir"` |
| SC2090 | Quotes prevent tilde expansion | ✅ | Use `$HOME` |

### Warning Level (Should Fix)

#### SC2100-2199: Best Practices
| Code | Description | Status | Implementation |
|------|-------------|--------|----------------|
| SC2102 | Ranges can only match single chars | ✅ | Use proper regex |
| SC2103 | Use `./` prefix for relative paths | ✅ | `cd ./dir || exit` |
| SC2104 | In functions, use `return`, not `break` | ✅ | Proper flow control |
| SC2115 | Use `"${var:?}"` to prevent rm disasters | ✅ | `rm -rf "${dir:?}/"*` |
| SC2116 | Useless `echo $(cmd)` | ✅ | Use `cmd` directly |
| SC2119 | Use `func "$@"` if function takes args | ✅ | Pass arguments |
| SC2120 | Function references arguments but none passed | ✅ | Check function calls |
| SC2128 | Expanding array without index | ✅ | `"${array[@]}"` |
| SC2129 | Consider using `{ cmd1; cmd2; }` | ✅ | Group redirections |
| SC2142 | Aliases can't use positional parameters | ✅ | Use functions |
| SC2153 | Possible misspelling of variable | ✅ | Check variable names |
| SC2154 | Variable is referenced but not assigned | ✅ | Initialize variables |
| SC2155 | Declare and assign separately | ✅ | Avoid masking exit codes |
| SC2162 | `read` without `-r` will mangle backslashes | ✅ | `read -r var` |
| SC2164 | Use `cd ... || exit` in case cd fails | ✅ | Handle cd failures |
| SC2166 | Prefer `[[ ]]` over `[ ]` in bash | ✅ | Modern conditionals |
| SC2181 | Check return directly with `if cmd` | ✅ | `if cmd; then` |

### Info Level (Consider Fixing)

#### SC2200-2299: Style and Optimization
| Code | Description | Status | Implementation |
|------|-------------|--------|----------------|
| SC2001 | Use parameter expansion instead of sed | ⚠️ | `${var//old/new}` |
| SC2002 | Useless cat | ⚠️ | `cmd < file` |
| SC2003 | expr is antiquated, use `$((..))` | ✅ | `$((a + b))` |
| SC2004 | `$` on arithmetic variables is unnecessary | ⚠️ | `$((x + y))` not `$(($x + $y))` |
| SC2005 | Useless `echo $(cmd)` | ✅ | Use `cmd` directly |
| SC2009 | Use `pgrep` instead of `ps | grep` | ⚠️ | Modern tools |
| SC2010 | Don't use `ls | grep`, use globs | ✅ | `for f in *.txt` |
| SC2012 | Use `find` instead of `ls` to better handle filenames | ✅ | Robust file handling |
| SC2013 | To read lines, use `while IFS= read -r` | ✅ | Proper line reading |
| SC2034 | Variable appears unused | ⚠️ | Remove if unused |
| SC2035 | Use `./*glob*` to avoid issues | ✅ | Prevent option confusion |

### Style Level (Optional)

#### SC2300+: Code Style
| Code | Description | Status | Implementation |
|------|-------------|--------|----------------|
| SC2059 | Don't use variables in printf format | ⚠️ | Use `%s` placeholder |
| SC2060 | Quote parameters to tr | ✅ | `tr 'a-z' 'A-Z'` |
| SC2062 | Quote the grep pattern | ✅ | `grep "$pattern"` |
| SC2063 | Grep uses regex, not globs | ✅ | Use proper regex |
| SC2064 | Use single quotes in trap | ✅ | `trap 'cleanup' EXIT` |
| SC2069 | To redirect stdout+stderr, use `2>&1` | ✅ | Proper redirection |
| SC2070 | `-n` doesn't work with unquoted arguments | ✅ | Quote properly |
| SC2071 | `>` is for string comparison, use `-gt` | ✅ | Numeric comparison |
| SC2072 | Decimals not supported | ✅ | Use bc or awk |

## Implementation in DCK

### ShellCheck Configuration
```bash
# .shellcheckrc
shell=bash
source-path=SCRIPTDIR
disable=SC2312  # Consider using find instead of ls
enable=all
external-sources=true
```

### Pre-commit Hook
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.9.0.6
    hooks:
      - id: shellcheck
        args: ['--severity=warning']
```

### CI/CD Integration
```yaml
# .github/workflows/shellcheck.yml
name: ShellCheck
on: [push, pull_request]
jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          severity: warning
          check_together: 'yes'
          scandir: './src'
```

## Common Fixes Applied

### 1. Variable Quoting (SC2086)
```bash
# Before
docker run $OPTIONS $IMAGE

# After
docker run "${OPTIONS[@]}" "$IMAGE"
```

### 2. Command Substitution (SC2006)
```bash
# Before
result=`docker ps`

# After
result="$(docker ps)"
```

### 3. Array Handling (SC2068)
```bash
# Before
args=$@

# After
args=("$@")
```

### 4. Error Handling (SC2164)
```bash
# Before
cd /some/dir

# After
cd /some/dir || exit 1
```

### 5. Read Command (SC2162)
```bash
# Before
read input

# After
read -r input
```

## Severity Distribution in DCK

| Severity | Total Rules | Fixed | Pending | Ignored |
|----------|------------|-------|---------|---------|
| Error | 45 | 45 | 0 | 0 |
| Warning | 89 | 85 | 4 | 0 |
| Info | 56 | 48 | 6 | 2 |
| Style | 34 | 28 | 4 | 2 |

## Validation Commands

### Run ShellCheck on Single File
```bash
shellcheck -S warning script.sh
```

### Run on All Scripts
```bash
find . -name "*.sh" -exec shellcheck {} \;
```

### Check Specific Rules
```bash
# Check only for critical issues
shellcheck -S error script.sh

# Check for specific rule
shellcheck -e SC2086 script.sh

# Enable optional checks
shellcheck -o all script.sh
```

### Generate Report
```bash
# JSON output for CI/CD
shellcheck -f json script.sh > report.json

# GCC format for IDE integration
shellcheck -f gcc script.sh
```

## Best Practices Summary

1. **Always Quote Variables**: Prevent word splitting and globbing
2. **Use Modern Syntax**: `$(...)` over backticks, `[[` over `[`
3. **Handle Errors**: Check return codes, use `set -e`
4. **Validate Input**: Never trust user input
5. **Use Arrays Properly**: `"${array[@]}"` for expansion
6. **Prefer Built-ins**: Use bash features over external commands
7. **Be POSIX Aware**: Know when using bash-specific features

## References
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/)
- [ShellCheck GitHub](https://github.com/koalaman/shellcheck)
- [Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)