# Changelog

All notable changes to DockerKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-11-12

### Added

- **CLI** (`dck`): Unified command interface for all Docker management operations
- **Object Inspection**: Inspect and analyze images, containers, volumes, and networks
- **Search & Discovery**: Filter Docker objects by name, status, labels, and more
- **Compliance Checking**: CIS Docker Benchmark and OWASP Container Security validation
- **Security Auditing**: Vulnerability scanning, secret detection, Hadolint integration
- **Auto-Remediation**: Fix Dockerfile violations (non-root users, unpinned images, secrets, missing health checks, ADD to COPY)
- **Template Generator**: Production-ready Docker stacks for Node.js, Python, Go, PostgreSQL, Redis, Keycloak, Prometheus, Kubernetes
- **Resource Monitoring**: Real-time monitoring dashboard with health checks and performance metrics
- **Safe Cleanup**: Intelligent pruning with dry-run support and resource isolation
- **Docker Compose Operations**: Stack management and lifecycle control
- **Export**: Export Docker object data as JSON
- **Documentation**: Docker landscape guide, best practices, compliance standards, tutorials
- **Test Suite**: 25 test modules covering unit, integration, and E2E scenarios
- **CI/CD**: Build, lint (ShellCheck), test, deploy, and release automation
- **Safety Guarantee**: Build/test/install scripts scoped to `dck*`-prefixed resources only
