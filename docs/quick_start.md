# Quick Start Guide

**Audience**: New users

## WHAT

Step-by-step guide to install and run DockerKit for the first time.

## WHY

A fast onboarding path reduces friction for new users and ensures correct initial setup.

## HOW

### Prerequisites

- Docker >= 20.10
- Bash >= 4.0
- `jq` (installed automatically by the installer)

## Installation

```bash
git clone https://github.com/phdsystems/docker-kit.git
cd docker-kit
./dockerkit-package/install.sh
```

This installs the `dck` command globally.

## Basic Usage

```bash
# Show all commands
dck help

# Show version
dck version
```

## Inspecting Docker Resources

```bash
# List and analyze images
dck images

# List containers (all states)
dck containers

# List volumes
dck volumes

# List networks
dck networks
```

## Searching

```bash
# Search images by name
dck search images nginx

# Find running containers
dck search containers --status running

# Find dangling volumes
dck search volumes --dangling

# Find unused networks
dck search networks --unused
```

## Advanced Analysis

```bash
# Deep image analysis with layer details
dck analyze images

# Container analysis with resource usage
dck analyze containers

# Full system overview
dck system
```

## Security & Compliance

```bash
# Run security audit
dck security

# Check Dockerfile compliance
dck compliance dockerfile

# Check container compliance
dck compliance container nginx
```

## Monitoring & Cleanup

```bash
# Real-time resource monitoring
dck monitor

# Live container stats
dck stats

# Health check aggregation
dck health

# Safe cleanup (dry-run first)
dck cleanup --dry-run

# Execute cleanup
dck cleanup
```

## Template Generation

```bash
# Generate a production-ready Docker stack
dck template
```

Available stack categories: Node.js, Python, Go, PostgreSQL, Redis, Keycloak, Prometheus, Kubernetes. See [templates.md](templates.md) for details.

## Export

```bash
# Export image data as JSON
dck export images --format json

# Export container data
dck export containers --format json
```

## Documentation

```bash
# View Docker landscape documentation
dck docs

# View a specific doc
dck docs docker_landscape
```

## Next Steps

- [Safety Boundaries](safety_boundaries.md) — Understand DockerKit's safety guarantees
- [Compliance](3-design/compliance_overview.md) — CIS Docker Benchmark and OWASP checks
- [Templates](templates.md) — Production-ready stack templates
- [Best Practices](docker_best_practices_validation.md) — Dockerfile validation rules
