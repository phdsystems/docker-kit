# Contributing to DockerKit

Thank you for your interest in contributing to DockerKit.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/<your-username>/docker-kit.git`
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Set up the development environment: `./scripts/dev/setup.sh`

## Development Workflow

### Project Structure

```
docker-kit/
  bin/dck              # CLI entry point
  main/src/            # Core modules (32 Bash scripts)
  main/src/lib/        # Shared libraries
  tests/               # Test suite (25 modules)
  scripts/             # CI/CD and automation
  template/            # Production-ready Docker templates
  docs/                # Documentation
```

### Running Tests

```bash
# Run all tests
./tests/run_all_tests.sh

# Run unit tests only
./tests/run_unit_tests.sh

# Run a specific test
./tests/test_compliance_module.sh
```

### Linting

All Bash scripts must pass ShellCheck:

```bash
./scripts/ci/lint.sh
```

### Code Style

Follow the [Bash Style Guide](docs/standards/bash_style_guide.md):

- Use `set -euo pipefail` in all scripts
- Quote all variable expansions
- Use `[[ ]]` for conditionals (not `[ ]`)
- Use lowercase for local variables, uppercase for exported/environment variables
- Add function documentation comments for non-trivial functions

### Safety Rules

- Build, test, and install scripts must **never** modify Docker resources outside the `dck*` namespace
- All destructive operations require `--dry-run` support
- All cleanup operations require explicit user confirmation

## Submitting Changes

1. Ensure all tests pass
2. Ensure ShellCheck passes with no warnings
3. Write clear commit messages following [Conventional Commits](https://www.conventionalcommits.org/)
4. Push to your fork and open a Pull Request against `main`
5. Fill out the PR template describing your changes

## Reporting Issues

Open an issue on [GitHub Issues](https://github.com/phdsystems/docker-kit/issues) with:

- A clear title and description
- Steps to reproduce (if applicable)
- Expected vs actual behavior
- DockerKit version (`dck version`) and Docker version (`docker --version`)

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
