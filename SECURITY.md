# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes       |

## Reporting a Vulnerability

If you discover a security vulnerability in DockerKit, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Email **security@phdsystems.com** with:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will acknowledge receipt within 48 hours and provide a timeline for a fix.

## Security Considerations

### Docker Socket Access

DockerKit requires access to the Docker socket (`/var/run/docker.sock`) to manage Docker resources. This grants full Docker daemon access. Only run DockerKit in trusted environments.

### Resource Isolation

DockerKit's build, test, and install scripts are scoped to resources prefixed with `dck*`. The management CLI (`dck`) itself operates on all Docker resources as intended.

### Compliance Standards

DockerKit validates against:

- [CIS Docker Benchmark](docs/standards/cis_docker_benchmark.md)
- [OWASP Container Security](docs/standards/owasp_container_security.md)

### Secret Handling

- DockerKit scans for exposed secrets in Dockerfiles and container configurations
- The auto-remediation engine can remove detected secrets
- See the [Docker Secrets Guide](docs/tutorial/docker/docker_secrets_guide.md) for best practices
