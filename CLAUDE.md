# DockerKit — Project Instructions

## Quick Reference

- **Language**: Bash 5.x (`set -euo pipefail` in all scripts)
- **Entry point**: `bin/dck` — routes to modules in `main/src/`
- **Tests**: `./tests/run_all_tests.sh` (mock-based, no Docker daemon needed)
- **Lint**: `./scripts/ci/lint.sh` (ShellCheck)
- **Build**: `./build.sh`

## Rules

- All scripts must pass ShellCheck with zero warnings
- Follow the style guide at `docs/standards/bash_style_guide.md`
- Build/test/install scripts must never touch Docker resources outside the `dck*` namespace
- All destructive operations must support `--dry-run`
- Quote all variable expansions, use `[[ ]]` for conditionals

## Structure

See [docs/reference/CLAUDE.md](docs/reference/CLAUDE.md) for full architecture, module naming conventions, and common tasks.
