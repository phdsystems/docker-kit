# Docker Environment Variables and .env Files Guide

## Table of Contents
- [Overview](#overview)
- [12-Factor App Compliance](#12-factor-app-compliance)
- [Environment Variable Patterns](#environment-variable-patterns)
- [Working with .env Files](#working-with-env-files)
- [Docker Compose Patterns](#docker-compose-patterns)
- [Error Handling](#error-handling)
- [Security Best Practices](#security-best-practices)
- [Examples](#examples)

## Overview

This guide covers best practices for managing environment variables in Docker containers, with a focus on maintaining 12-factor app compliance and security.

## 12-Factor App Compliance

The [12-Factor App](https://12factor.net/) methodology defines best practices for building cloud-native applications. Key principles for Docker configuration:

### Factor III: Config
- **Store configuration in environment variables**
- Never hardcode credentials or environment-specific values
- Configuration should be strictly separated from code

### Factor V: Build, Release, Run
- **Strictly separate build and run stages**
- Same Docker image must work across all environments
- Configuration injected at runtime, not build time

### ❌ Anti-Pattern: Build-Time Configuration
```dockerfile
# WRONG: Baking environment config into image
ARG DATABASE_URL
ENV DATABASE_URL=${DATABASE_URL}
```

### ✅ Correct Pattern: Runtime Configuration
```dockerfile
# CORRECT: Configuration provided at runtime
ENV NODE_ENV=production  # Safe default
# DATABASE_URL injected via docker run or compose
```

## Environment Variable Patterns

### 1. Safe Defaults in Dockerfile
```dockerfile
# Non-sensitive defaults that apply to all environments
ENV NODE_ENV=production
ENV PORT=3000
ENV LOG_LEVEL=info
ENV WORKERS=4
```

### 2. Required External Configuration
```dockerfile
# Document required environment variables
# These MUST be provided at runtime

# Option 1: Documentation only
# ENV DATABASE_URL (required - set via .env or compose)

# Option 2: Reference secret files
ENV DATABASE_PASSWORD_FILE=/run/secrets/db_password

# Option 3: Fail fast if not provided
# (handled in application code or entrypoint script)
```

### 3. Build Arguments (Use Carefully)
```dockerfile
# ONLY for build-time needs, never for runtime config
ARG NODE_VERSION=20
FROM node:${NODE_VERSION}-alpine

# OK: Version selection
ARG BUILDKIT_INLINE_CACHE=1

# NOT OK: Runtime configuration
# ARG API_KEY (never do this!)
```

## Working with .env Files

### File Structure
```
project/
├── .env                 # Default, auto-loaded by docker-compose
├── .env.example         # Template with all variables (commit this)
├── .env.defaults        # Safe defaults (commit this)
├── .env.local          # Local development (gitignore)
├── .env.production     # Production values (gitignore)
└── .env.staging        # Staging values (gitignore)
```

### .env.example (Committed to Repository)
```bash
# Database Configuration
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=myapp
DATABASE_USER=appuser
DATABASE_PASSWORD=changeme

# Redis Configuration  
REDIS_HOST=localhost
REDIS_PORT=6379

# Application Settings
JWT_SECRET=change-this-secret-key
API_KEY=your-api-key-here
```

### .env.defaults (Safe Defaults - Committed)
```bash
# Non-sensitive defaults
NODE_ENV=development
PORT=3000
LOG_LEVEL=debug
CACHE_TTL=3600
MAX_CONNECTIONS=100
```

### .env.production (Never Commit)
```bash
# Real production values
DATABASE_PASSWORD=xK9#mP2$vL5@nQ8
JWT_SECRET=highly-secure-random-string-here
API_KEY=sk-proj-real-api-key
STRIPE_SECRET_KEY=sk_live_actual_key
```

## Docker Compose Patterns

### Basic env_file Usage
```yaml
version: '3.8'
services:
  app:
    image: myapp:latest
    env_file: .env  # Loads .env file
```

### Multiple env Files with Priority
```yaml
services:
  app:
    image: myapp:latest
    env_file:
      - .env.defaults     # Loaded first
      - .env.production   # Overrides defaults
    environment:
      - PORT=8080         # Highest priority
```

Priority order (highest to lowest):
1. **Docker Secrets** (when application reads from secret files)
2. `environment:` section in docker-compose.yml
3. Last `env_file` in list
4. First `env_file` in list
5. `.env` file (auto-loaded)
6. Shell environment variables

### Optional env Files (Docker Compose 2.24.0+)
```yaml
services:
  app:
    image: myapp:latest
    env_file:
      - path: .env.defaults
        required: true    # Must exist
      - path: .env.local
        required: false   # Optional, won't error if missing
```

### Variable Substitution with Defaults
```yaml
services:
  app:
    image: myapp:latest
    environment:
      # Use value from .env or shell, fallback to default
      - NODE_ENV=${NODE_ENV:-production}
      - PORT=${PORT:-3000}
      - DATABASE_URL=${DATABASE_URL:-postgresql://localhost/db}
      
      # Require variable (error if not set)
      - API_KEY=${API_KEY:?Error: API_KEY is required}
      - JWT_SECRET=${JWT_SECRET:?Error: JWT_SECRET must be set}
```

### Environment-Specific Compose Files
```yaml
# docker-compose.yml (base)
services:
  app:
    image: myapp:latest
    env_file: .env.defaults

# docker-compose.prod.yml (production overrides)
services:
  app:
    env_file:
      - .env.defaults
      - .env.production
    deploy:
      replicas: 3
```

Usage:
```bash
# Development
docker-compose up

# Production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

## Error Handling

### What Happens When .env Files Are Missing?

#### Required File Missing (Default Behavior)
```yaml
env_file: .env.production  # Will fail if missing
```
Error:
```
ERROR: Couldn't find env file: /path/to/.env.production
```

#### Graceful Handling Options

1. **Optional Files**
```yaml
env_file:
  - path: .env.production
    required: false
```

2. **Default Values**
```yaml
environment:
  - DATABASE_URL=${DATABASE_URL:-postgresql://localhost/myapp}
```

3. **Error Messages**
```yaml
environment:
  - SECRET_KEY=${SECRET_KEY:?Error: SECRET_KEY is required for production}
```

4. **Validation Script**
```bash
#!/bin/bash
# validate-env.sh
required_vars=("DATABASE_URL" "JWT_SECRET" "API_KEY")

for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "Error: $var is not set"
    exit 1
  fi
done
```

## Using Secrets with Environment Variables

### Secrets Override Pattern

Secrets can override `.env` values for sensitive data while keeping non-sensitive config in environment variables:

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    image: myapp:latest
    env_file: .env  # Contains: DATABASE_PASSWORD=dev-password
    secrets:
      - db_password  # Contains: production-password
    environment:
      # Non-sensitive from .env
      NODE_ENV: ${NODE_ENV:-production}
      PORT: ${PORT:-3000}
      
      # Tell app where to find the secret (overrides .env value)
      DATABASE_PASSWORD_FILE: /run/secrets/db_password
      # Fallback if no secret exists
      DATABASE_PASSWORD: ${DATABASE_PASSWORD}

secrets:
  db_password:
    file: ./secrets/db_password  # This takes precedence!
```

### Application Integration

```javascript
// Smart configuration loader - secrets override env vars
function getConfig(name) {
  // 1. Check for secret file FIRST (highest priority)
  const secretFile = process.env[`${name}_FILE`];
  if (secretFile && fs.existsSync(secretFile)) {
    return fs.readFileSync(secretFile, 'utf8').trim();
  }
  
  // 2. Fallback to environment variable
  return process.env[name];
}

// Usage
const dbPassword = getConfig('DATABASE_PASSWORD');
// Returns secret file content if exists, otherwise env var
```

### Hybrid Development/Production Pattern

```yaml
# Development: uses .env file
services:
  postgres:
    image: postgres:16
    env_file: .env.development
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}

# Production: uses secrets (overrides .env)
services:
  postgres:
    image: postgres:16
    env_file: .env.defaults  # Non-sensitive only
    secrets:
      - db_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
      # Fallback (rarely used in production)
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-}
```

### Best Practice: Separation of Concerns

```yaml
# .env.defaults (committed to repo)
NODE_ENV=production
PORT=3000
LOG_LEVEL=info
CACHE_TTL=3600

# .env.development (gitignored)
DATABASE_PASSWORD=dev-password
API_KEY=dev-key

# Production: secrets override sensitive values
services:
  app:
    env_file:
      - .env.defaults  # Non-sensitive config
    secrets:
      - db_password    # Overrides DATABASE_PASSWORD
      - api_key        # Overrides API_KEY
    environment:
      # Point to secrets for sensitive data
      DATABASE_PASSWORD_FILE: /run/secrets/db_password
      API_KEY_FILE: /run/secrets/api_key
```

## Security Best Practices

### 1. Never Commit Sensitive Data
```gitignore
# .gitignore
.env
.env.local
.env.production
.env.staging
.env.*.local

# Keep these
!.env.example
!.env.defaults
```

### 2. Use Docker Secrets for Production
```yaml
services:
  app:
    image: myapp:latest
    secrets:
      - db_password
      - jwt_secret
    environment:
      - DATABASE_PASSWORD_FILE=/run/secrets/db_password
      - JWT_SECRET_FILE=/run/secrets/jwt_secret

secrets:
  db_password:
    external: true
  jwt_secret:
    external: true
```

### 3. Validate Environment Variables
```dockerfile
# entrypoint.sh
#!/bin/sh
set -e

# Check required variables
: ${DATABASE_URL:?DATABASE_URL is required}
: ${JWT_SECRET:?JWT_SECRET is required}

# Start application
exec "$@"
```

### 4. Use Least Privilege Principle
```yaml
environment:
  # Read-only database user for reports
  - REPORTS_DB_USER=reports_readonly
  - REPORTS_DB_PASS=${REPORTS_PASSWORD}
  
  # Full access for main app
  - APP_DB_USER=app_user
  - APP_DB_PASS=${APP_PASSWORD}
```

## Examples

### Example 1: Node.js Application
```yaml
# docker-compose.yml
version: '3.8'
services:
  node-app:
    build: .
    env_file:
      - path: .env.defaults
        required: true
      - path: .env.local
        required: false
    environment:
      - NODE_ENV=${NODE_ENV:-production}
      - PORT=${PORT:-3000}
      - DATABASE_URL=${DATABASE_URL:?Database URL is required}
    ports:
      - "${PORT:-3000}:${PORT:-3000}"
```

### Example 2: Multi-Service Stack
```yaml
# docker-compose.yml
version: '3.8'

x-common-variables: &common-variables
  LOG_LEVEL: ${LOG_LEVEL:-info}
  TZ: ${TZ:-UTC}

services:
  postgres:
    image: postgres:16
    env_file: .env.postgres
    environment:
      <<: *common-variables
      POSTGRES_DB: ${DB_NAME:-myapp}
      POSTGRES_USER: ${DB_USER:-postgres}
      POSTGRES_PASSWORD: ${DB_PASSWORD:?Database password required}
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    environment:
      <<: *common-variables
    command: redis-server --requirepass ${REDIS_PASSWORD:-redis123}

  app:
    build: .
    depends_on:
      - postgres
      - redis
    env_file:
      - .env.defaults
      - .env.${ENVIRONMENT:-local}
    environment:
      <<: *common-variables
      DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}
      REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379
    ports:
      - "${APP_PORT:-3000}:3000"

volumes:
  postgres_data:
```

### Example 3: Development vs Production
```bash
# .env.development
NODE_ENV=development
LOG_LEVEL=debug
DATABASE_HOST=localhost
API_MOCK=true

# .env.production  
NODE_ENV=production
LOG_LEVEL=error
DATABASE_HOST=prod-db.example.com
API_MOCK=false
```

```yaml
# Usage
services:
  app:
    image: myapp:latest
    env_file: .env.${DEPLOY_ENV:-development}
```

### Example 4: Kubernetes ConfigMap (Alternative to .env)
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  NODE_ENV: production
  LOG_LEVEL: info
  PORT: "3000"
---
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  database-url: cG9zdGdyZXNxbDovL3VzZXI6cGFzc0BkYi9teWFwcA==
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:latest
        envFrom:
        - configMapRef:
            name: app-config
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
```

## Summary

✅ **DO:**
- Store all configuration in environment variables
- Use .env files for local development
- Provide .env.example templates
- Use runtime configuration injection
- Implement proper secret management
- Validate required variables at startup

❌ **DON'T:**
- Bake environment-specific values into images
- Commit .env files with real values
- Use ARG for runtime configuration
- Hardcode sensitive data anywhere
- Mix build-time and runtime configuration

By following these patterns, your Docker applications will be:
- **Portable**: Same image works everywhere
- **Secure**: Secrets never in code or images
- **Maintainable**: Clear configuration structure
- **12-Factor Compliant**: Following cloud-native best practices