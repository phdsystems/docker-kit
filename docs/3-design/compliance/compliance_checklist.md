# Architecture Compliance Checklist

**Audience**: Architects, contributors, reviewers

Derived from [architecture.md](../architecture.md). Every enforceable rule has a corresponding checkbox.

---

## 1. Module Structure

- [ ] All core modules live in `main/src/docker-*.sh`
- [ ] Shared libraries live in `main/src/lib/`
- [ ] CLI entry point is `bin/dck` only
- [ ] No business logic in `bin/dck` — dispatch only

## 2. Naming Conventions

- [ ] Module files follow `docker-{feature}.sh` pattern
- [ ] Advanced variants follow `docker-advanced-{object}.sh`
- [ ] Search variants follow `docker-search-{object}.sh`
- [ ] Test files follow `test_{feature}.sh` pattern

## 3. Code Standards

- [ ] All scripts use `set -euo pipefail`
- [ ] All scripts pass ShellCheck with zero warnings
- [ ] All variable expansions are quoted
- [ ] Conditionals use `[[ ]]` not `[ ]`
- [ ] Local variables are lowercase; exported variables are UPPERCASE
- [ ] Functions have documentation comments for non-trivial logic

## 4. Safety Boundary

- [ ] Build/test/install scripts only touch `dck*`-prefixed Docker resources
- [ ] All destructive operations support `--dry-run`
- [ ] All cleanup operations require explicit user confirmation
- [ ] Management CLI (`dck`) operates on all Docker resources (by design)

## 5. Testing

- [ ] Tests use mock system (`tests/mocks/docker`, `tests/mocks/sudo`)
- [ ] Tests run without Docker daemon
- [ ] Each module has corresponding test coverage
- [ ] Integration tests exist for CLI dispatch

## 6. Dependencies

- [ ] Zero runtime dependencies beyond Bash, Docker CLI, jq, curl, git
- [ ] Shared logic goes in `lib/common.sh` or `lib/docker-wrapper.sh`
- [ ] No external Bash libraries or frameworks

## 7. Documentation

- [ ] All docs follow W3H structure (Audience/WHAT/WHY/HOW)
- [ ] All doc filenames use snake_lower_case (except git standard files)
- [ ] All docs declare `**Audience**:` after the H1
- [ ] docs/README.md hub exists and links to all documentation
- [ ] docs/glossary.md exists with domain terminology
