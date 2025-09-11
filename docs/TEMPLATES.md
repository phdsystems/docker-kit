# DCK Template System Guide

## Overview

The DCK Template System provides complete, production-ready Docker stacks for various technologies. Each template is a self-contained package that includes everything needed for both development and production deployment.

## Table of Contents

- [Template Philosophy](#template-philosophy)
- [Using Templates](#using-templates)
- [Available Templates](#available-templates)
- [Template Structure](#template-structure)
- [Customization](#customization)
- [Best Practices](#best-practices)
- [Production Deployment](#production-deployment)

## Template Philosophy

DCK templates follow these principles:

1. **Complete Packages**: Each template is a complete, working stack - not just a Dockerfile
2. **Production-Ready**: Security best practices, health checks, and monitoring built-in
3. **12-Factor Compliance**: Strict separation of build and runtime configuration
4. **Environment-Based Config**: All runtime configuration through environment variables
5. **Security First**: Non-root users, minimal images, secrets management patterns
6. **Development & Production**: Same stack works for both environments

## Using Templates

### List Available Templates

```bash
dck template list
```

### Generate a Template

```bash
# Basic generation
dck template generate <template-name> <target-directory>

# Example: Generate a Node.js stack
dck template generate language/node ./my-node-app
```

### View Template Details

```bash
dck template show language/node
```

### Start the Stack

```bash
cd ./my-node-app

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Available Templates

### Language Stacks

#### Node.js (`language/node`)
**Components:**
- Node.js 20 Alpine application
- PostgreSQL 16 database
- Redis 7 cache
- Nginx reverse proxy

**Use Cases:**
- REST APIs
- GraphQL servers
- Real-time applications (Socket.io)
- Microservices

**Special Features:**
- PM2 process manager for production
- Health check endpoint
- Graceful shutdown handling
- npm audit security scanning

#### Python (`language/python`)
**Components:**
- Python 3.12 application
- PostgreSQL 16 database
- Redis 7 cache
- Celery worker for async tasks
- Nginx reverse proxy

**Use Cases:**
- Django/Flask applications
- FastAPI services
- Data processing pipelines
- Machine learning APIs

**Special Features:**
- Gunicorn WSGI server
- Celery beat scheduler
- Poetry dependency management
- Async task processing

#### Go (`language/go`)
**Components:**
- Go 1.21 application
- PostgreSQL 16 database
- Redis 7 cache
- Optional Jaeger tracing

**Use Cases:**
- High-performance APIs
- Microservices
- CLI tools
- System utilities

**Special Features:**
- Multi-stage build for minimal image
- Static binary compilation
- Gosec security scanning
- OpenTelemetry instrumentation

### Database Systems

#### PostgreSQL (`database/postgresql`)
**Components:**
- PostgreSQL 16 primary
- PostgreSQL replica (optional)
- pgAdmin 4 management UI
- Backup service

**Features:**
- Master-slave replication
- Automated backups
- Performance monitoring
- Connection pooling with PgBouncer

#### MongoDB (`database/mongodb`)
**Components:**
- MongoDB 7 replica set
- Mongo Express UI
- Backup service

**Features:**
- Replica set configuration
- Authentication enabled
- Automated backups
- Monitoring metrics

#### Redis (`database/redis`)
**Components:**
- Redis 7 server
- RedisInsight UI
- Redis Sentinel for HA

**Features:**
- Persistence configuration
- Password authentication
- Master-slave replication
- Monitoring dashboard

### Monitoring & Observability

#### Prometheus Stack (`monitoring/prometheus`)
**Components:**
- Prometheus server
- Grafana dashboards
- Node Exporter
- cAdvisor
- Alertmanager

**Features:**
- Pre-configured dashboards
- Alert rules
- Service discovery
- Long-term storage

#### ELK Stack (`monitoring/elasticsearch`)
**Components:**
- Elasticsearch cluster
- Logstash pipeline
- Kibana UI
- Filebeat/Metricbeat

**Features:**
- Log aggregation
- Full-text search
- Visualization dashboards
- Index lifecycle management

#### Jaeger (`monitoring/jaeger`)
**Components:**
- Jaeger collector
- Jaeger query service
- Jaeger UI
- Cassandra/Elasticsearch backend

**Features:**
- Distributed tracing
- Service dependency analysis
- Performance monitoring
- Root cause analysis

### Identity & Access Management

#### Keycloak (`iam/keycloak`)
**Components:**
- Keycloak server
- PostgreSQL backend
- Mail server integration

**Features:**
- Single Sign-On (SSO)
- OAuth 2.0 / OpenID Connect
- User federation
- Multi-factor authentication
- Custom themes support

### Container Orchestration

#### Kubernetes (`orchestration/kubernetes`)
**Components:**
- k3s lightweight Kubernetes
- Helm package manager
- Kubernetes Dashboard
- Metrics Server

**Features:**
- Local development cluster
- Ingress controller
- Storage provisioner
- Service mesh ready

## Template Structure

Each template follows this structure:

```
template-name/
├── Dockerfile                 # Multi-stage, production-optimized
├── docker-compose.yml         # Complete service definitions
├── docker-compose.prod.yml    # Production overrides (optional)
├── .env.example              # Configuration template
├── .dockerignore             # Build optimization
├── configs/                  # Configuration files
│   ├── nginx.conf           # Web server config (if applicable)
│   ├── prometheus.yml       # Monitoring config (if applicable)
│   └── ...
├── scripts/                  # Utility scripts
│   ├── backup.sh            # Backup script
│   ├── healthcheck.sh       # Health check script
│   └── entrypoint.sh        # Custom entrypoint
└── secrets/                  # Secret templates
    └── .gitkeep
```

## Customization

### Environment Variables

All templates use environment variables for configuration:

```bash
# Application settings
APP_NAME=myapp
APP_ENV=production
APP_PORT=8080
APP_DEBUG=false

# Database settings
DB_HOST=postgres
DB_PORT=5432
DB_NAME=myapp
DB_USER=appuser
DB_PASSWORD=secretpassword

# Redis settings
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redispassword

# Monitoring
METRICS_ENABLED=true
METRICS_PORT=9090
```

### Docker Compose Overrides

For environment-specific settings:

```yaml
# docker-compose.override.yml (development)
version: '3.8'
services:
  app:
    volumes:
      - ./src:/app/src  # Hot reload
    environment:
      - APP_DEBUG=true
```

### Extending Templates

Templates are designed to be extended:

```dockerfile
# Custom Dockerfile extending template
FROM template-base AS custom

# Add custom dependencies
RUN npm install additional-package

# Add custom configuration
COPY custom-config.json /app/config/
```

## Best Practices

### Security

1. **Never commit .env files** - Use .env.example as template
2. **Use secrets for sensitive data** - Don't put passwords in environment variables in production
3. **Keep images updated** - Regularly rebuild with latest base images
4. **Scan for vulnerabilities** - Use `dck compliance dockerfile --fix`

### Performance

1. **Use multi-stage builds** - Keep production images small
2. **Enable build cache** - Use Docker BuildKit
3. **Optimize layer caching** - Order Dockerfile commands properly
4. **Set resource limits** - Define CPU and memory limits

### Development Workflow

1. **Use docker-compose.override.yml** - For local development settings
2. **Mount source code** - For hot reload during development
3. **Use .env.local** - For developer-specific settings
4. **Enable debug mode** - Only in development

## Production Deployment

### Pre-deployment Checklist

- [ ] All sensitive data in secrets, not environment variables
- [ ] Production environment variables configured
- [ ] Health checks verified and working
- [ ] Resource limits set appropriately
- [ ] Logging configured for production
- [ ] Monitoring and alerting configured
- [ ] Backup strategy implemented
- [ ] Security scanning completed

### Deployment Steps

1. **Generate and customize template**
   ```bash
   dck template generate language/node ./production-app
   cd ./production-app
   ```

2. **Configure for production**
   ```bash
   # Create production environment file
   cp .env.example .env.production
   # Edit with production values
   
   # Use production compose file
   docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
   ```

3. **Set up secrets** (Docker Swarm example)
   ```bash
   # Create secrets
   echo "mypassword" | docker secret create db_password -
   
   # Deploy stack
   docker stack deploy -c docker-compose.yml myapp
   ```

4. **Verify deployment**
   ```bash
   # Check health
   docker-compose ps
   curl http://localhost:8080/health
   
   # View logs
   docker-compose logs -f
   
   # Monitor metrics
   curl http://localhost:9090/metrics
   ```

### Scaling

Templates support horizontal scaling:

```bash
# Scale application instances
docker-compose up -d --scale app=3

# With Docker Swarm
docker service scale myapp_app=3

# With Kubernetes
kubectl scale deployment myapp --replicas=3
```

## Troubleshooting

### Common Issues

**Container fails to start**
- Check logs: `docker-compose logs <service>`
- Verify environment variables: `docker-compose config`
- Check health status: `docker-compose ps`

**Database connection errors**
- Ensure database is healthy: `docker-compose ps postgres`
- Check credentials in .env match database settings
- Verify network connectivity: `docker-compose exec app ping postgres`

**Permission errors**
- Templates use non-root users by default
- Ensure volumes have correct permissions
- Check user ID mappings

**Build failures**
- Clear Docker build cache: `docker builder prune`
- Update base images: `docker-compose build --pull`
- Check for network issues during package downloads

### Getting Help

1. Check template-specific README in the generated directory
2. Run compliance check: `dck compliance dockerfile Dockerfile`
3. View DCK documentation: `dck docs`
4. Check GitHub issues: https://github.com/yourusername/dck/issues

## Contributing

To add new templates:

1. Create template directory structure under `template/complete/`
2. Follow the standard structure and naming conventions
3. Include comprehensive .env.example
4. Add health checks and monitoring endpoints
5. Test with compliance checker
6. Update documentation

See [CONTRIBUTING.md](../CONTRIBUTING.md) for details.