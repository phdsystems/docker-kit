# DockerKit Quick Start

## Installation

To install DockerKit in any project, run:

```bash
curl -fsSL https://raw.githubusercontent.com/phdsystems/phd-ade/feature/docker-kit/dockerkit-package/install.sh | bash
```

## Basic Usage

Once installed, you can use DockerKit commands:

```bash
# Check Docker compliance
dck check

# Generate a Dockerfile template
dck template dockerfile --type node

# Run security audit
dck audit --format json

# List available templates
dck template list
```

## Integration in Your Project

### Add to package.json
```json
{
  "scripts": {
    "docker:check": "dck check --strict",
    "docker:audit": "dck audit --format json --output audit.json"
  }
}
```

### Add to Makefile
```makefile
docker-check:
	@dck check --strict --threshold 80

docker-fix:
	@dck fix --dry-run
```

### Add to CI/CD (GitHub Actions)
```yaml
- name: Install and Run DockerKit
  run: |
    curl -fsSL https://raw.githubusercontent.com/phdsystems/phd-ade/feature/docker-kit/dockerkit-package/install.sh | bash
    dck check --strict
```

## Repository Information

- **Repository**: https://github.com/phdsystems/phd-ade
- **Branch**: feature/docker-kit
- **Path**: /dockerkit-package

## Support

For issues or questions, please visit:
https://github.com/phdsystems/phd-ade/issues