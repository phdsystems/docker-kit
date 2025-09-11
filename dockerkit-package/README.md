# DockerKit - Docker Compliance & Management Toolkit

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/phdsystems/dockerkit)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-%3E%3D20.10-blue.svg)](https://www.docker.com/)

DockerKit is a comprehensive toolkit for Docker compliance, security, and management in production environments. It provides automated compliance checking, template generation, and best practices enforcement.

## 🚀 Features

- **Compliance Checking**: Automated Docker security and compliance validation
- **Template Generation**: Production-ready Dockerfile and docker-compose templates
- **Best Practices**: Enforce industry standards and security guidelines
- **Multi-Format Reports**: JSON, HTML, and terminal output formats
- **CI/CD Integration**: Easy integration with CI/CD pipelines
- **Extensible**: Plugin architecture for custom checks and templates

## 📦 Installation

### Method 1: Quick Install (Recommended)

```bash
# Download and run the installer
curl -fsSL https://raw.githubusercontent.com/phdsystems/phd-ade/feature/docker-kit/dockerkit-package/install.sh | bash
```

### Method 2: Manual Installation

```bash
# Clone the repository
git clone https://github.com/phdsystems/phd-ade.git
cd phd-ade/dockerkit-package

# Install using make
make install

# Or install with custom paths
make install PREFIX=/opt/dockerkit BIN_DIR=/usr/bin
```

### Method 3: npm Package

```bash
# Install globally via npm
npm install -g @phdsystems/dockerkit

# Run using npx
npx dck --help
```

### Method 4: Docker Image

```bash
# Pull the Docker image
docker pull phdsystems/dockerkit:latest

# Run as a container
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock phdsystems/dockerkit check
```

### Method 5: From Source

```bash
# Clone and build from source
git clone https://github.com/phdsystems/phd-ade.git
cd phd-ade/dockerkit-package
make build
make test
sudo make install
```

## 🎯 Quick Start

### Basic Usage

```bash
# Check Docker compliance
dck check

# Generate a secure Dockerfile template
dck template dockerfile --type node

# Run comprehensive audit
dck audit --format json --output report.json

# List available templates
dck template list
```

### CI/CD Integration

#### GitHub Actions

```yaml
name: Docker Compliance Check

on: [push, pull_request]

jobs:
  compliance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install DockerKit
        run: |
          curl -fsSL https://raw.githubusercontent.com/phdsystems/phd-ade/feature/docker-kit/dockerkit-package/install.sh | bash
      
      - name: Run Compliance Check
        run: dck check --strict --threshold 80
```

#### GitLab CI

```yaml
docker-compliance:
  stage: test
  script:
    - curl -fsSL https://raw.githubusercontent.com/phdsystems/phd-ade/feature/docker-kit/dockerkit-package/install.sh | bash
    - dck check --format json --output compliance.json
  artifacts:
    reports:
      compliance: compliance.json
```

#### Jenkins Pipeline

```groovy
pipeline {
    agent any
    stages {
        stage('Docker Compliance') {
            steps {
                sh '''
                    curl -fsSL https://raw.githubusercontent.com/phdsystems/phd-ade/feature/docker-kit/dockerkit-package/install.sh | bash
                    dck check --strict
                '''
            }
        }
    }
}
```

## 📋 Available Commands

### Core Commands

| Command | Description | Example |
|---------|-------------|---------|
| `check` | Run compliance checks | `dck check --strict` |
| `audit` | Comprehensive security audit | `dck audit --verbose` |
| `template` | Generate templates | `dck template dockerfile --type python` |
| `fix` | Auto-fix common issues | `dck fix --dry-run` |
| `report` | Generate compliance reports | `dck report --format html` |

### Template Types

```bash
# List all available templates
dck template list

# Generate specific templates
dck template dockerfile --type node --output Dockerfile
dck template compose --type microservices --output docker-compose.yml
dck template config --type production --output .dockerignore
```

### Compliance Checks

The tool performs the following compliance checks:

- **Security**
  - Non-root user enforcement
  - Secret scanning
  - Vulnerability assessment
  - Network exposure analysis
  
- **Best Practices**
  - Layer optimization
  - Cache efficiency
  - Image size analysis
  - Label standards
  
- **Configuration**
  - Resource limits
  - Health checks
  - Logging configuration
  - Restart policies

## 🔧 Configuration

### Environment Variables

```bash
# Set custom installation directory
export DOCKERKIT_HOME=/opt/dockerkit

# Set compliance threshold
export DOCKERKIT_THRESHOLD=85

# Enable verbose output
export DOCKERKIT_VERBOSE=true
```

### Configuration File

Create `.dockerkit.yml` in your project:

```yaml
version: 1.0
compliance:
  threshold: 80
  strict: true
  ignore:
    - DK001  # Ignore specific check
    - DK002
  
templates:
  default_type: production
  output_dir: ./docker
  
reporting:
  format: json
  output: compliance-report.json
  include_passed: false
```

## 📊 Output Formats

### JSON Report

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "score": 92,
  "status": "PASSED",
  "checks": [
    {
      "id": "DK001",
      "name": "Non-root user",
      "status": "PASSED",
      "severity": "HIGH"
    }
  ]
}
```

### HTML Report

Generates an interactive HTML report with:
- Visual compliance dashboard
- Detailed findings
- Remediation suggestions
- Trend analysis

## 🛠️ Development

### Building from Source

```bash
# Clone repository
git clone https://github.com/phdsystems/dockerkit.git
cd dockerkit

# Install dependencies
make check-deps

# Build
make build

# Run tests
make test

# Create distribution packages
make package
```

### Creating Custom Checks

```bash
# Create custom check plugin
cat > checks/custom-check.sh << 'EOF'
#!/bin/bash
check_custom_rule() {
    # Implementation
}
EOF

# Register the check
dck plugin add ./checks/custom-check.sh
```

## 📚 Documentation

- [User Guide](docs/user-guide.md)
- [API Reference](docs/api-reference.md)
- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Docker community for best practices
- CIS Docker Benchmark
- OWASP Docker Security Cheat Sheet

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/phdsystems/dockerkit/issues)
- **Discussions**: [GitHub Discussions](https://github.com/phdsystems/dockerkit/discussions)
- **Email**: support@phdsystems.com

## 🔮 Roadmap

- [ ] Kubernetes compliance checks
- [ ] Container registry scanning
- [ ] Policy as Code support
- [ ] IDE plugins (VSCode, IntelliJ)
- [ ] Web UI dashboard
- [ ] Cloud provider integrations

---

**DockerKit** - Making Docker compliance simple and automated 🐳