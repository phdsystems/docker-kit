# DCK (DockerKit) - Comprehensive Docker Management Toolkit

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/yourusername/dck)
[![Docker](https://img.shields.io/badge/docker-%3E%3D20.10-blue.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

DCK (DockerKit) is a comprehensive, self-contained Docker management toolkit that simplifies Docker operations with powerful search, analysis, and management capabilities. The short command name `dck` makes it quick and easy to use.

## 📖 Table of Contents

- [🔒 Safety Guarantee](#-safety-guarantee)
- [🚀 Features](#-features)
- [📋 Requirements](#-requirements)
- [🛠️ Installation](#️-installation)
- [📖 Usage](#-usage)
- [🐳 Docker Compose Services](#-docker-compose-services)
- [🔧 Configuration](#-configuration)
- [🧪 Testing](#-testing)
- [🚀 CI/CD Integration](#-cicd-integration)
- [📚 Documentation](#-documentation)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)
- [🙏 Acknowledgments](#-acknowledgments)
- [📞 Support](#-support)
- [🗺️ Roadmap](#️-roadmap)

## 🔒 Safety Guarantee

**DockerKit's build, test, and installation scripts NEVER delete or modify Docker resources that don't belong to DockerKit.**

All DockerKit infrastructure resources are prefixed with `dck` (containers, images, volumes, networks). Build scripts, tests, and cleanup commands only manage these prefixed resources, ensuring your existing Docker setup remains untouched during DockerKit installation, testing, or removal.

**Note:** When using DockerKit as a Docker management tool, you have full control to manage ANY Docker resource - this is the tool's intended purpose. The safety restrictions only apply to DockerKit's own infrastructure operations (build, test, install, clean), not to your usage of the tool itself.

## 🚀 Features

### Core Capabilities
- **🔍 Advanced Search**: Search images, containers, volumes, and networks with powerful filters
- **📊 System Analysis**: Comprehensive Docker system analysis and metrics
- **🧹 Smart Cleanup**: Intelligent cleanup of unused Docker resources
- **📈 Real-time Monitoring**: Live resource monitoring and health checks
- **🔒 Security Auditing**: Docker security analysis and recommendations
- **✅ Compliance Checking**: Docker best practices enforcement with **auto-remediation**
- **🔧 Auto-Fix**: Automatically fix Dockerfile security issues and best practice violations
- **📦 Container Management**: Advanced container operations and management
- **🌐 Network Analysis**: Network topology and connectivity analysis
- **💾 Volume Management**: Volume inspection, backup, and migration
- **🎯 Template Generation**: Complete production-ready Docker stacks for various technologies

### Search Features
- Search Docker images by name, tag, size, registry
- Find containers by status, port, network, volume
- Locate volumes by driver, container usage, mount points
- Discover networks by driver, subnet, container connections

## 📋 Requirements

- Docker 20.10 or higher
- Docker Compose 2.0 or higher (for containerized deployment)
- Bash 4.0 or higher (for standalone usage)

## 🛠️ Installation

### Option 1: Containerized (Recommended)

```bash
# Clone the repository
git clone https://github.com/yourusername/dck.git
cd dck

# Build and run with Docker Compose
./build.sh
docker-compose up -d
docker exec -it dck bash
```

### Option 2: Standalone Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/dck.git
cd dck

# Make the CLI executable
chmod +x dck

# Use directly
./dck --help

# Or add to PATH
export PATH="$PATH:$(pwd)"
```

### Option 3: Quick Start with Docker

```bash
# Pull and run the pre-built image
docker run -it --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --privileged \
  dck:latest
```

## 📖 Usage

### Basic Commands

```bash
# Show help
dck --help
dck help

# Show version
dck version

# System overview
dck system

# List images
dck images

# List containers
dck containers

# List volumes
dck volumes

# List networks
dck networks
```

### Search Operations

```bash
# Search for nginx images
dck search images nginx

# Find running containers
dck search containers --status running

# Find containers exposing port 80
dck search containers --port 80

# Find dangling volumes
dck search volumes --dangling

# Find unused networks
dck search networks --unused
```

### Advanced Operations

```bash
# Analyze all Docker resources
dck analyze

# Monitor resources in real-time
dck monitor

# Security audit
dck security

# Docker compliance checking
dck compliance dockerfile Dockerfile
dck compliance container nginx
dck compliance image alpine:3.19
dck compliance lint Dockerfile
dck compliance cis

# Auto-fix Dockerfile issues
dck compliance dockerfile --fix Dockerfile
dck compliance dockerfile --interactive Dockerfile
dck compliance dockerfile --generate-fixed Dockerfile

# CI/CD Integration with exit codes
dck compliance dockerfile --strict Dockerfile           # Fail if score < 70%
dck compliance dockerfile --threshold 90 Dockerfile     # Fail if score < 90%

# Cleanup unused resources (only DockerKit resources)
dck cleanup --dry-run
dck cleanup

# Export data as JSON
dck export containers --format json > containers.json

# Safety check - verify what would be affected
dck safety-check
```

### Template Generation

Generate complete, production-ready Docker stacks for various technologies:

```bash
# List all available templates
dck template list

# Generate a specific template
dck template generate language/node ./my-node-app
dck template generate database/postgresql ./my-postgres
dck template generate monitoring/prometheus ./monitoring-stack

# View template details
dck template show language/node

# Generate with custom configuration
dck template generate language/python ./my-python-app --port 8000
```

#### Available Templates

**Language Stacks:**
- `language/node` - Node.js with PostgreSQL, Redis, Nginx
- `language/python` - Python with PostgreSQL, Redis, Celery, Nginx  
- `language/go` - Go with PostgreSQL, Redis
- `language/java` - Java Spring Boot with PostgreSQL, Redis
- `language/ruby` - Ruby on Rails with PostgreSQL, Redis, Sidekiq
- `language/php` - PHP with PostgreSQL, Redis, Nginx
- `language/dotnet` - .NET Core with SQL Server, Redis
- `language/rust` - Rust with PostgreSQL, Redis

**Database Systems:**
- `database/postgresql` - PostgreSQL with replication, backup, monitoring
- `database/mysql` - MySQL with replication and backup
- `database/mongodb` - MongoDB replica set with backup
- `database/redis` - Redis with persistence and RedisInsight
- `database/elasticsearch` - Elasticsearch cluster with Kibana
- `database/cassandra` - Cassandra cluster with monitoring

**Monitoring & Observability:**
- `monitoring/prometheus` - Prometheus with Grafana and exporters
- `monitoring/elasticsearch` - ELK stack (Elasticsearch, Logstash, Kibana)
- `monitoring/jaeger` - Distributed tracing with Jaeger
- `monitoring/loki` - Log aggregation with Loki and Grafana

**Identity & Access Management:**
- `iam/keycloak` - Keycloak with PostgreSQL backend
- `iam/authentik` - Authentik identity provider
- `iam/ory` - Ory Kratos, Hydra, Oathkeeper, Keto stack

**Container Orchestration:**
- `orchestration/kubernetes` - Local Kubernetes with k3s
- `orchestration/nomad` - HashiCorp Nomad cluster
- `orchestration/swarm` - Docker Swarm mode configuration

Each template includes:
- Production-ready Dockerfile with security best practices
- docker-compose.yml for local development
- .env.example with all configuration options
- Health checks and monitoring endpoints
- Proper secret management patterns
- Volume configurations for data persistence
- Network isolation and security settings

## 🎯 Template System

DCK includes a comprehensive template generation system that creates complete, production-ready Docker stacks. Each template is a self-contained package with everything needed for production deployment.

### Using Templates

```bash
# List available templates
dck template list

# Generate a Node.js application stack
dck template generate language/node ./my-app
cd ./my-app

# Customize the .env file
cp .env.example .env
# Edit .env with your configuration

# Start the complete stack
docker-compose up -d
```

### Template Structure

Each template package includes:
```
my-app/
├── Dockerfile           # Production-optimized, multi-stage build
├── docker-compose.yml   # Complete service stack
├── .env.example        # Configuration template
├── .dockerignore       # Build optimization
└── configs/            # Additional configuration files
```

## 🐳 Docker Compose Services

The project includes multiple services for different use cases:

### Core Service
```bash
# Start the core DockerKit service
docker-compose up -d dck
```

### API Service (Optional)
```bash
# Start with API service
docker-compose --profile api up -d
```

### Web UI (Optional)
```bash
# Start with Web UI
docker-compose --profile ui up -d
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file from the example:

```bash
cp .env.example .env
```

Available configurations:

```env
# Docker Configuration
DOCKER_HOST=unix:///var/run/docker.sock

# DockerKit Settings
DOCKERKIT_LOG_LEVEL=info
DOCKERKIT_DATA_DIR=/var/lib/dck/data
DOCKERKIT_LOG_DIR=/var/lib/dck/logs

# API Configuration (optional)
API_PORT=8080
API_HOST=0.0.0.0

# UI Configuration (optional)
UI_PORT=3000
```

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Run all tests
./tests/run_tests.sh

# Run unit tests only
./tests/run_tests.sh --unit

# Run integration tests only
./tests/run_tests.sh --integration

# Run with Docker
docker-compose run --rm dck ./tests/run_tests.sh
```

## 🚀 CI/CD Integration

DCK supports exit codes for automated pipeline integration:

### GitHub Actions
```yaml
- name: Check Dockerfile Compliance
  run: dck compliance dockerfile --strict Dockerfile
  # Fails pipeline if compliance score < 70%
```

### Environment-Specific Thresholds
```bash
# Development: Relaxed standards
dck compliance dockerfile --threshold 50 Dockerfile.dev

# Staging: Moderate standards  
dck compliance dockerfile --threshold 70 Dockerfile.staging

# Production: Strict standards
dck compliance dockerfile --threshold 90 Dockerfile.prod
```

## 📚 Documentation

### Core Documentation

- **[Template System Guide](docs/TEMPLATES.md)** - Complete guide to the Docker template generation system
  - Available templates and their components
  - Customization options
  - Best practices for each technology stack
  - Production deployment guidelines

- **[Compliance Module Guide](docs/COMPLIANCE.md)** - Comprehensive guide to Docker compliance checking and auto-remediation
  - Dockerfile security analysis
  - Container runtime compliance
  - Auto-fix capabilities
  - CI/CD integration

### Tutorials

- **[Environment Variables & .env Files Guide](docs/tutorial/docker/environment-variables-guide.md)** - Best practices for Docker configuration
  - 12-Factor app compliance
  - Docker Compose patterns
  - Security best practices
  - Error handling strategies

- **[Docker Secrets Management Guide](docs/tutorial/docker/docker-secrets-guide.md)** - Secure handling of sensitive data
  - BuildKit secrets for build-time
  - Docker Swarm secrets for production
  - Kubernetes secrets integration
  - Migration from environment variables

### Security & Standards Documentation

Located in [`docs/standards/`](docs/standards/):

#### Docker Standards
- **[CIS Docker Benchmark](docs/standards/CIS-DOCKER-BENCHMARK.MD)** - 52 security controls implementation
- **[OWASP Container Security](docs/standards/OWASP-CONTAINER-SECURITY.MD)** - Top 10 container security risks
- **[Docker Official Images](docs/standards/DOCKER-OFFICIAL-IMAGES.MD)** - Production-ready image standards

#### Shell/Bash Standards
- **[Bash Style Guide](docs/standards/BASH-STYLE-GUIDE.MD)** - Comprehensive coding standards (647 lines)
- **[Bash Security Guidelines](docs/standards/BASH-SECURITY-GUIDELINES.MD)** - Security best practices
- **[POSIX Shell Compliance](docs/standards/POSIX-SHELL-COMPLIANCE.MD)** - Portability standards
- **[ShellCheck Rules](docs/standards/SHELLCHECK-RULES.MD)** - Static analysis rules

#### Quick Links
- **[Standards Overview](docs/standards/README.MD)** - Summary of all standards with metrics
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute to the project

## 🤝 Contributing

Contributions are welcome! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Docker team for the amazing container platform
- Community contributors
- Open source projects that inspired this toolkit

## 📞 Support

- [GitHub Issues](https://github.com/yourusername/dck/issues)
- [Documentation](https://github.com/yourusername/dck/wiki)
- [Discord Community](https://discord.gg/dck)

## 🗺️ Roadmap

- [ ] Web-based UI dashboard
- [ ] RESTful API for remote management
- [ ] Kubernetes integration
- [ ] Cloud provider integrations (AWS, GCP, Azure)
- [ ] Advanced backup and restore features
- [ ] Multi-host Docker management
- [ ] Plugin system for extensions

---

Made with ❤️ by the DockerKit Team