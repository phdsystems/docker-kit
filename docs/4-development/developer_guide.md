---
layout: default
title: Developer Guide
parent: Development
nav_order: 1
---

# DockerKit Developer Guide

**Audience**: Contributors, developers modifying DockerKit

## WHAT

Guide for developing, testing, and contributing to DockerKit.

## WHY

Consistent development practices across contributors ensure code quality, prevent regressions, and maintain the safety boundary.

## HOW

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Bash | >= 4.0 | Pre-installed on Linux/macOS |
| Docker | >= 20.10 | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) |
| jq | Latest | `apt install jq` / `brew install jq` |
| ShellCheck | Latest | `apt install shellcheck` / `brew install shellcheck` |

### Project Structure

```
docker-kit/
├── bin/dck                    # CLI entry point (dispatch only)
├── main/src/                  # 32 core modules
│   ├── docker-*.sh            # Feature modules
│   └── lib/                   # Shared libraries
│       ├── common.sh          # Logging, formatting, validation
│       └── docker-wrapper.sh  # Docker command abstraction
├── tests/                     # Test suite
│   ├── mocks/                 # Docker/sudo mocks
│   ├── test_*.sh              # Test modules
│   └── run_all_tests.sh       # Test runner
├── scripts/                   # Automation
│   ├── ci/                    # Build, lint, test
│   ├── dev/                   # Development setup
│   ├── ops/                   # Deployment, health checks
│   └── release/               # Version bumping, publishing
├── template/complete/         # Production-ready Docker templates
└── docs/                      # Documentation
```

### Development Workflow

```
1. Fork + branch    →  git checkout -b feature/my-feature
2. Write code       →  Edit main/src/docker-*.sh
3. Lint             →  ./scripts/ci/lint.sh
4. Test             →  ./tests/run_all_tests.sh
5. Commit           →  Conventional Commits format
6. PR               →  Against main branch
```

### Adding a New Module

1. Create `main/src/docker-{feature}.sh`
2. Add `set -euo pipefail` and source `lib/common.sh`
3. Register the command in `bin/dck` (add case to dispatch)
4. Create `tests/test_{feature}.sh`
5. Run `./scripts/ci/lint.sh` and `./tests/run_all_tests.sh`

### Running Tests

```bash
# All tests (mock-based, no Docker daemon needed)
./tests/run_all_tests.sh

# Unit tests only
./tests/run_unit_tests.sh

# Specific test
./tests/test_compliance_module.sh

# With real Docker (requires running daemon)
./tests/test_with_real_docker.sh
```

### Linting

```bash
# ShellCheck all scripts
./scripts/ci/lint.sh
```

All scripts must pass with zero warnings before merging.

### Code Style

Follow [bash_style_guide.md](../standards/bash_style_guide.md):

- `set -euo pipefail` in every script
- Quote all variable expansions: `"$var"` not `$var`
- Use `[[ ]]` for conditionals
- Lowercase for local variables, UPPERCASE for exports
- Functions: `snake_case()` with documentation for non-trivial logic

### Safety Rules

- Build/test/install scripts: only touch `dck*`-prefixed resources
- All destructive operations: must support `--dry-run`
- All cleanup operations: must require explicit confirmation
- See [safety_boundaries.md](../safety_boundaries.md)

## Related Documentation

- [Architecture](../3-design/architecture.md) — System design and module organization
- [Compliance Checklist](../3-design/compliance/compliance_checklist.md) — Architecture compliance audit
- [Contributing](../../CONTRIBUTING.md) — Contribution process and PR guidelines
- [Standards](../standards/README.md) — Coding and security standards
