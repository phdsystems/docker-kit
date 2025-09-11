# Docker Kit

> Comprehensive Docker management toolkit with safety guarantees

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)
[![Docker](https://img.shields.io/badge/docker-%3E%3D20.10-blue.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## Quick Start

```bash
# Quick command interface
dck

# Build with best practices
dck build --best-practices

# Analyze Dockerfile
dck analyze Dockerfile

# Clean unused resources (safe)
dck clean --safe
```

## Features

- 🔒 **Safety Guarantee** - Never deletes or modifies resources not created by DockerKit
- 🏗️ **Best Practices** - Enforces Docker best practices automatically
- 📊 **Image Analysis** - Deep analysis of Docker images and containers
- 🧹 **Safe Cleanup** - Intelligent cleanup of unused resources
- 📋 **Compliance** - CIS Docker Benchmark and OWASP compliance checks

## Installation

```bash
git clone https://github.com/phdsystems/docker-kit.git
cd docker-kit
./install.sh
```

## Documentation

- 📖 [Quick Start Guide](docs/QUICK-START.md)
- 🏗️ [Best Practices](docs/docker-best-practices-validation.md)
- 📊 [Feature Comparison](docs/docker-feature-comparison.md)
- 🔒 [Safety Boundaries](docs/safety-boundaries.md)
- 📋 [Compliance Standards](docs/standards/)

## Safety Guarantee

DockerKit's build, test, and installation scripts **NEVER** delete or modify Docker resources that don't belong to DockerKit. All operations are:
- Explicitly confirmed before execution
- Limited to DockerKit-managed resources
- Fully reversible

## License

MIT
