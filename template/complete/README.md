# Complete Docker Template Packages

This directory contains complete, production-ready Docker setups for various technologies. Each template includes:

- `Dockerfile` - Optimized, secure Docker image
- `.env.example` - Environment variables template
- `docker-compose.yml` - Full stack orchestration
- `.dockerignore` - Build optimization
- Supporting configuration files

## Directory Structure

```
complete/
├── language/           # Programming language stacks
│   ├── node/          # Node.js with PostgreSQL, Redis, Nginx
│   ├── python/        # Python with PostgreSQL, Redis, Celery, Nginx
│   ├── go/            # Go with PostgreSQL, Redis
│   └── java-spring/   # Spring Boot with PostgreSQL, Redis
│
├── database/          # Database servers
│   ├── postgresql/    # PostgreSQL with replication, backup, monitoring
│   ├── mongodb/       # MongoDB with replica set, backup
│   └── redis/         # Redis with sentinel, persistence
│
├── monitoring/        # Monitoring stacks
│   ├── prometheus/    # Full Prometheus stack with Grafana
│   ├── elasticsearch/ # ELK stack (Elasticsearch, Logstash, Kibana)
│   └── jaeger/        # Distributed tracing
│
├── iam/              # Identity & Access Management
│   ├── keycloak/     # Keycloak with PostgreSQL backend
│   ├── vault/        # HashiCorp Vault with storage backend
│   └── openldap/     # OpenLDAP with phpLDAPadmin
│
└── orchestration/    # Container orchestration
    ├── kubernetes/   # Kubernetes tools and operators
    └── swarm/        # Docker Swarm configurations
```

## Usage

### 1. Copy Template

```bash
# Copy the entire template directory
cp -r template/complete/language/node myapp/

# Navigate to your app
cd myapp/
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with your values
nano .env
```

### 3. Start Services

```bash
# Start all services
docker-compose up -d

# Start with specific profile
docker-compose --profile monitoring up -d

# View logs
docker-compose logs -f app
```

### 4. Customize

Each template is designed to be customized:

- Modify `Dockerfile` for your specific needs
- Adjust `docker-compose.yml` services
- Add/remove services as needed
- Configure volumes and networks

## Environment Variables

All templates use `.env` files for configuration:

- **Non-sensitive defaults** - Can be committed
- **Sensitive values** - Use Docker secrets in production
- **Override pattern** - Secrets override `.env` values

### Development vs Production

```yaml
# Development - uses .env
docker-compose up

# Production - uses secrets
docker stack deploy -c docker-compose.yml app
```

## Security Best Practices

All templates follow security best practices:

- ✅ Non-root user execution
- ✅ No hardcoded secrets
- ✅ Health checks configured
- ✅ Proper signal handling
- ✅ Security headers (where applicable)
- ✅ Network isolation
- ✅ Read-only mounts where possible

## Profiles

Many templates use Docker Compose profiles for optional services:

```bash
# Core services only
docker-compose up

# With monitoring
docker-compose --profile monitoring up

# With backup services
docker-compose --profile backup up

# Everything
docker-compose --profile full up
```

## Common Patterns

### Database Connections

All database templates provide:
- Primary instance
- Optional replicas
- Backup services
- Monitoring exporters
- Admin interfaces

### Application Stacks

Language templates include:
- Application server
- Database (PostgreSQL)
- Cache (Redis)
- Queue workers (if applicable)
- Reverse proxy (Nginx)
- Static file serving

### Monitoring

Monitoring templates provide:
- Metrics collection
- Alerting
- Visualization
- Log aggregation
- Distributed tracing

## Customization Tips

1. **Start Small** - Use core services first, add others as needed
2. **Use Profiles** - Enable optional services with profiles
3. **Override Files** - Use `docker-compose.override.yml` for local changes
4. **Secrets Management** - Migrate from `.env` to secrets for production
5. **Volume Management** - Use named volumes for persistence
6. **Network Isolation** - Create separate networks for different concerns

## Examples

### Quick Start - Node.js App

```bash
# Copy template
cp -r template/complete/language/node myapp/
cd myapp/

# Configure
cp .env.example .env
# Edit .env with your settings

# Start
docker-compose up -d

# Access
# App: http://localhost:3000
# Metrics: http://localhost:9090
```

### Production Deployment

```bash
# Use secrets instead of .env
docker secret create db_password ./secrets/db_password

# Deploy stack
docker stack deploy -c docker-compose.yml myapp

# Scale
docker service scale myapp_app=3
```

## Support

For issues or questions about templates:
1. Check the template's README
2. Review the Dockerfile comments
3. Consult the main DCK documentation
4. Open an issue on GitHub