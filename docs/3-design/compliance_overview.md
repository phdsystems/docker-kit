# Docker Compliance Module Documentation

**Audience**: DevOps engineers, security teams, contributors

## WHAT

Compliance checking module providing CIS Docker Benchmark, OWASP Container Security validation, Dockerfile linting, and auto-remediation for Docker environments.

## WHY

Manual compliance auditing is error-prone and inconsistent. Automated checking ensures every build meets security baselines without human oversight.

## HOW

The compliance module supports the following features and workflows.

- [Overview](#overview)
- [Quick Start](#quick-start)
  - [Basic Compliance Checking](#basic-compliance-checking)
  - [Auto-Remediation Commands](#auto-remediation-commands)
- [Features](#features)
  - [1. Auto-Remediation](#1-auto-remediation-new)
  - [2. Dockerfile Compliance Checking](#2-dockerfile-compliance-checking)
  - [3. Container Runtime Compliance](#3-container-runtime-compliance)
  - [4. Image Security Scanning](#4-image-security-scanning)
  - [5. Dockerfile Linting](#5-dockerfile-linting)
  - [6. CIS Docker Benchmark](#6-cis-docker-benchmark)
- [Compliance Scoring](#compliance-scoring)
- [Integration with CI/CD](#integration-with-cicd)
  - [GitHub Actions Example](#github-actions-example)
  - [GitLab CI Example](#gitlab-ci-example)
- [Best Practices Recommendations](#best-practices-recommendations)
  - [For Dockerfiles](#for-dockerfiles)
  - [For Container Runtime](#for-container-runtime)
- [Troubleshooting](#troubleshooting)
- [Configuration](#configuration)
  - [Environment Variables](#environment-variables)
  - [Custom Rules](#custom-rules)
- [API Reference](#api-reference)
  - [Command Structure](#command-structure)
  - [Commands](#commands)
  - [Options](#options)
- [Contributing](#contributing)
- [Related Documentation](#related-documentation)
- [Support](#support)

## Overview

DCK's compliance module provides comprehensive Docker security and best practices enforcement with **automatic remediation capabilities**, implementing three major industry standards:

- **CIS Docker Benchmark** - Security hardening guidelines
- **OWASP Container Security** - Application security in containers
- **Docker Official Images** - Production-ready image standards

### Template Integration

All DCK templates are pre-validated to achieve 95%+ compliance scores. When generating templates with `dck template generate`, you get:
- Pre-configured security best practices
- Compliance-ready Dockerfiles
- Proper secret management patterns
- Health checks and monitoring built-in

### Auto-Remediation Features

The compliance module can now automatically fix detected issues in your Dockerfiles:
- Fix missing non-root users
- Pin base image versions
- Add health checks
- Replace hardcoded secrets with build arguments
- Fix ADD misuse
- Clean package manager caches
- Add missing WORKDIR and metadata labels

## Quick Start

### Basic Compliance Checking

```bash
# Check Dockerfile compliance
dck compliance dockerfile Dockerfile

# Check running container compliance
dck compliance container <container-name>

# Scan image for vulnerabilities
dck compliance image alpine:3.19

# Lint Dockerfile with Hadolint
dck compliance lint Dockerfile

# Run full CIS Docker Benchmark
dck compliance cis
```

### Auto-Remediation Commands

```bash
# Automatically fix all issues in a Dockerfile
dck compliance dockerfile --fix Dockerfile

# Interactive mode - choose which fixes to apply
dck compliance dockerfile --interactive Dockerfile

# Generate a fixed version without modifying the original
dck compliance dockerfile --generate-fixed Dockerfile

# Direct remediation command
dck compliance remediate --mode auto Dockerfile

# Generate fixed version with custom output name
dck compliance remediate --mode auto --output Dockerfile.secure Dockerfile
```

### CI/CD Integration with Exit Codes

```bash
# Fail if compliance score < 70% (default threshold)
dck compliance dockerfile --strict Dockerfile

# Set custom threshold for different environments
dck compliance dockerfile --threshold 50 Dockerfile    # Dev (relaxed)
dck compliance dockerfile --threshold 70 Dockerfile    # Staging (moderate)
dck compliance dockerfile --threshold 90 Dockerfile    # Production (strict)

# Combine with auto-fix in CI/CD
dck compliance dockerfile --strict --fix Dockerfile
```

## Features

### 1. Auto-Remediation (NEW!)

Automatically fixes common Docker security and best practice issues.

#### Remediation Modes:
- **Auto (`--fix` or `--auto`)**: Applies all fixes automatically
- **Interactive (`--interactive`)**: Prompts for each fix
- **Generate (`--generate-fixed`)**: Creates fixed version without modifying original

#### What Gets Fixed:
1. **Security Issues**:
   - Adds non-root user with proper permissions
   - Converts hardcoded secrets to build arguments
   - Fixes excessive permissions

2. **Best Practices**:
   - Pins base image versions (e.g., `alpine:latest` → `alpine:3.19.1`)
   - Replaces ADD with COPY where appropriate
   - Adds HEALTHCHECK directives
   - Cleans package manager caches
   - Adds WORKDIR configuration
   - Adds metadata labels

#### Example Before and After:

**Before (insecure):**
```dockerfile
FROM alpine:latest
RUN apk add curl
ENV PASSWORD="secret123"
ADD http://example.com/app.tar /app/
CMD ["sh"]
```

**After (secured):**
```dockerfile
FROM alpine:3.19.1
LABEL maintainer="your-email@example.com"
LABEL version="1.0.0"
WORKDIR /app
RUN apk add --no-cache curl
ARG PASSWORD
ENV PASSWORD=${PASSWORD}
RUN curl -fsSL http://example.com/app.tar -o /app/app.tar
RUN addgroup -g 1001 appuser && \
    adduser -D -u 1001 -G appuser appuser
USER appuser
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost/health || exit 1
CMD ["sh"]
```

### 2. Dockerfile Compliance Checking

Analyzes Dockerfiles against best practices and security standards.

#### Checks Performed:
- ✅ **Non-root User**: Ensures containers run as non-root
- ✅ **Version Pinning**: Validates base image and package versions
- ✅ **Health Checks**: Verifies HEALTHCHECK directive presence
- ✅ **Metadata Labels**: Checks for required labels (maintainer, version, description)
- ✅ **Secret Detection**: Scans for hardcoded credentials
- ✅ **COPY vs ADD**: Ensures proper usage of COPY directive
- ✅ **Cache Cleanup**: Validates package manager cache cleanup
- ✅ **WORKDIR Usage**: Checks for proper working directory
- ✅ **Trusted Base Images**: Validates base image trustworthiness

#### Example Output:
```
🔍 Analyzing Dockerfile: Dockerfile
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Non-root User: ✅ Non-root user configured
✅ Version Pinning: ✅ Base image version pinned
✅ Health Check: ✅ HEALTHCHECK configured
⚠️  Metadata Labels: ⚠️ Missing labels: version description
✅ No Hardcoded Secrets: ✅ No hardcoded secrets detected
✅ COPY vs ADD Usage: ✅ Proper COPY usage
✅ Cache Cleanup: ✅ Package cache cleaned
✅ WORKDIR Usage: ✅ WORKDIR configured
✅ Trusted Base Image: ✅ Using trusted base image

📊 Compliance Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Checks: 9
Passed: 8
Warnings: 1
Failed: 0

Compliance Score: 88%
⚠️ GOOD - Minor improvements needed
```

### 2. Container Runtime Compliance

Analyzes running containers for security configurations.

#### Checks Performed:
- ✅ **User Privileges**: Validates non-root execution
- ✅ **Capabilities**: Checks for dropped capabilities
- ✅ **Read-only Filesystem**: Validates immutable root
- ✅ **Privileged Mode**: Ensures containers aren't privileged
- ✅ **Resource Limits**: Checks memory and CPU limits
- ✅ **Restart Policy**: Validates appropriate restart policy
- ✅ **Health Monitoring**: Verifies health check configuration
- ✅ **Network Isolation**: Checks network mode security

#### Example Command:
```bash
dck compliance container nginx
```

### 3. Image Security Scanning

Integrates with security scanners to detect vulnerabilities.

#### Supported Scanners:
- **Trivy**: Comprehensive vulnerability scanner
- **Docker Scout**: Docker's native security scanner
- **Snyk**: (When available)

#### Example Command:
```bash
dck compliance image alpine:3.19.1
```

### 4. Dockerfile Linting

Uses Hadolint for advanced Dockerfile analysis.

#### Features:
- Syntax validation
- Best practices enforcement
- Shell script analysis within RUN instructions
- Package version suggestions

#### Example Command:
```bash
dck compliance lint Dockerfile.prod
```

### 5. CIS Docker Benchmark

Runs the complete CIS Docker Benchmark security assessment.

#### Coverage:
- Host configuration
- Docker daemon configuration
- Container images and build files
- Container runtime
- Docker security operations

#### Example Command:
```bash
dck compliance cis
```

## Compliance Scoring

The module provides a compliance score based on check results:

| Score Range | Level | Description |
|------------|-------|-------------|
| 90-100% | EXCELLENT | Production ready, minimal issues |
| 70-89% | GOOD | Minor improvements needed |
| 50-69% | FAIR | Significant improvements recommended |
| 0-49% | POOR | Major security issues to address |

## Integration with CI/CD

### Exit Code Behavior

The compliance module supports proper exit codes for CI/CD integration:

| Mode | Exit Code | When |
|------|-----------|------|
| Normal (default) | 0 | Always (backward compatible) |
| `--strict` | 0 | Score ≥ 70% (default threshold) |
| `--strict` | 1 | Score < 70% |
| `--threshold N` | 0 | Score ≥ N% |
| `--threshold N` | 1 | Score < N% |

### GitHub Actions Example

```yaml
name: Docker Compliance Check
on: [push, pull_request]

jobs:
  compliance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install DCK
        run: |
          git clone https://github.com/yourusername/dck.git
          cd dck && chmod +x dck
          export PATH="$PATH:$(pwd)"
      
      - name: Check Dockerfile Compliance (Strict)
        run: dck compliance dockerfile --strict Dockerfile
        # Fails the pipeline if score < 70%
        
      - name: Auto-fix and Check Again
        run: |
          dck compliance dockerfile --fix Dockerfile
          dck compliance dockerfile --threshold 80 Dockerfile
        
      - name: Lint Dockerfile
        run: dck compliance lint Dockerfile
```

### GitLab CI Example

```yaml
docker-compliance:
  stage: test
  script:
    - git clone https://github.com/yourusername/dck.git
    - cd dck && chmod +x dck
    - export PATH="$PATH:$(pwd)"
    - |
      if [ "$CI_COMMIT_BRANCH" = "main" ]; then
        dck compliance dockerfile --threshold 90 Dockerfile  # Production standard
      else
        dck compliance dockerfile --threshold 70 Dockerfile  # Development standard
      fi
    - dck compliance lint Dockerfile
  only:
    - merge_requests
    - main
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    
    stages {
        stage('Compliance Check') {
            steps {
                script {
                    // Different thresholds for different branches
                    def threshold = env.BRANCH_NAME == 'main' ? 90 : 70
                    
                    sh """
                        git clone https://github.com/yourusername/dck.git
                        cd dck && chmod +x dck
                        export PATH="\$PATH:\$(pwd)"
                        
                        # Check compliance with appropriate threshold
                        dck compliance dockerfile --threshold ${threshold} Dockerfile
                        
                        # Generate compliance report
                        dck compliance dockerfile Dockerfile > compliance-report.txt
                    """
                }
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'compliance-report.txt', fingerprint: true
        }
    }
}
```

## Best Practices Recommendations

### For Dockerfiles

1. **Always use specific versions**:
   ```dockerfile
   # Good
   FROM alpine:3.19.1
   
   # Bad
   FROM alpine:latest
   ```

2. **Create non-root user**:
   ```dockerfile
   RUN addgroup -g 1000 appuser && \
       adduser -D -u 1000 -G appuser appuser
   USER appuser
   ```

3. **Add health checks**:
   ```dockerfile
   HEALTHCHECK --interval=30s --timeout=3s \
     CMD curl -f http://localhost/health || exit 1
   ```

4. **Clean package caches**:
   ```dockerfile
   RUN apk add --no-cache curl && \
       rm -rf /var/cache/apk/*
   ```

### For Container Runtime

1. **Run with limited capabilities**:
   ```bash
   docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE image
   ```

2. **Set resource limits**:
   ```bash
   docker run --memory=512m --cpus=1 image
   ```

3. **Use read-only filesystem**:
   ```bash
   docker run --read-only --tmpfs /tmp image
   ```

## Troubleshooting

### Common Issues

1. **"Docker daemon not accessible"**
   - Ensure Docker is running
   - Check user permissions or use sudo
   - Verify Docker socket exists at `/var/run/docker.sock`

2. **"Hadolint not found"**
   - DCK will automatically use Docker to run Hadolint
   - For native installation: `brew install hadolint` (macOS) or download from GitHub

3. **"Trivy not available"**
   - Install Trivy: `curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin`
   - Or let DCK use Docker to run security scans

## Configuration

### Environment Variables

```bash
# Set compliance strictness level
export DCK_COMPLIANCE_LEVEL=strict  # strict, normal, lenient

# Set custom compliance rules file
export DCK_COMPLIANCE_RULES=/path/to/custom-rules.yaml

# Enable/disable specific checks
export DCK_SKIP_SECRET_CHECK=false
export DCK_SKIP_VERSION_CHECK=false
```

### Custom Rules

Create a custom rules file:

```yaml
# custom-rules.yaml
rules:
  - id: custom-label-check
    description: Ensure custom labels are present
    severity: warning
    labels:
      - com.company.team
      - com.company.version
  
  - id: base-image-restriction
    description: Only allow approved base images
    severity: error
    allowed_bases:
      - alpine:3.19.1
      - ubuntu:22.04
```

## API Reference

### Command Structure

```
dck compliance <command> [options]
```

### Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `dockerfile` | `df` | Check Dockerfile compliance |
| `container` | `ct` | Check container runtime compliance |
| `image` | `img` | Security scan Docker image |
| `lint` | - | Lint Dockerfile with Hadolint |
| `cis` | `benchmark` | Run CIS Docker Benchmark |
| `all` | - | Run all compliance checks |

### Options

| Option | Description |
|--------|-------------|
| `--fix`, `--auto` | Automatically fix detected issues |
| `--interactive` | Prompt for each fix before applying |
| `--generate-fixed` | Generate fixed version without modifying original |
| `--strict [threshold]` | Exit with code 1 if score < threshold (default: 70) |
| `--threshold <score>` | Set minimum score and enable strict mode (0-100) |
| `--json` | Output results in JSON format |
| `--severity` | Set minimum severity level (critical, high, medium, low) |
| `--ignore` | Comma-separated list of checks to ignore |
| `--config` | Path to custom configuration file |

## Contributing

To add new compliance checks:

1. Add check function to `src/docker-compliance.sh`
2. Update scoring logic in `generate_compliance_report()`
3. Add unit tests to `tests/test_docker_compliance.sh`
4. Update this documentation

## Related Documentation

- [CIS Docker Benchmark](../standards/cis_docker_benchmark.md)
- [OWASP Container Security](../standards/owasp_container_security.md)
- [Docker Official Images](../standards/docker_official_images.md)
- [Bash Security Guidelines](../standards/bash_security_guidelines.md)

## Support

For issues or questions:
- Open an issue on [GitHub](https://github.com/yourusername/dck/issues)
- Check existing [compliance rules documentation](../standards/)
- Run `dck compliance --help` for command-specific help