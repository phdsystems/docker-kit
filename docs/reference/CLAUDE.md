# DockerKit — AI Assistant Reference

## Project Overview

DockerKit (`dck`) is a Docker management and compliance CLI toolkit written in Bash. It provides object inspection, security auditing, compliance checking (CIS/OWASP), auto-remediation, template generation, monitoring, and safe cleanup.

## Architecture

```
bin/dck                          # CLI entry point (dispatches to modules)
main/src/                        # 32 core Bash modules
main/src/lib/common.sh           # Shared utilities (logging, formatting)
main/src/lib/docker-wrapper.sh   # Docker command abstraction (sudo handling)
tests/                           # 25 test modules with Docker mock system
scripts/ci/                      # Build, lint, test automation
scripts/release/                 # Version bumping, changelog, publishing
template/complete/               # Production-ready Docker stack templates
docs/                            # All documentation
dockerkit-package/               # npm distribution packaging
```

## Key Conventions

- **Language**: Bash 5.x with `set -euo pipefail`
- **Style**: See `docs/standards/bash_style_guide.md`
- **Linting**: All scripts must pass ShellCheck (`scripts/ci/lint.sh`)
- **Testing**: Mock-based tests in `tests/` — run without a real Docker daemon
- **Safety**: Build/test/install scripts only touch `dck*`-prefixed Docker resources
- **CLI pattern**: `bin/dck` routes commands to `main/src/docker-*.sh` modules

## Common Tasks

| Task | Command |
|------|---------|
| Run all tests | `./tests/run_all_tests.sh` |
| Run unit tests | `./tests/run_unit_tests.sh` |
| Lint all scripts | `./scripts/ci/lint.sh` |
| Build Docker image | `./build.sh` |
| Run CLI | `./bin/dck help` |

## Module Naming

Core modules follow the pattern `main/src/docker-<feature>.sh`:
- `docker-images.sh`, `docker-containers.sh`, `docker-volumes.sh`, `docker-networks.sh` — basic inspection
- `docker-advanced-*.sh` — deep analysis variants
- `docker-search-*.sh` — search/filter variants
- `docker-compliance.sh`, `docker-security.sh`, `docker-remediation.sh` — audit & fix
- `docker-monitor.sh`, `docker-cleanup.sh`, `docker-template-generator.sh` — operations

## Safety Boundary

The `dck` CLI tool manages **all** Docker resources (that's its purpose). The safety restriction (`dck*` prefix scope) applies only to DockerKit's own build/test/install infrastructure — never to the user-facing management tool.
