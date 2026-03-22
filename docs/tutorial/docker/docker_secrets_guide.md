# Docker Secrets Management Guide

**Audience**: DevOps engineers, developers handling sensitive data

## WHAT

Guide to managing secrets in Docker across BuildKit, Swarm, Compose, and Kubernetes.

## WHY

Environment variables leak secrets in logs and process tables. Proper secrets management keeps credentials out of images, logs, and runtime inspection.

## HOW

> **Note:** The `version` key is optional in modern Docker Compose and is omitted from examples below.

### Table of Contents
- [Overview](#overview)
- [Why Use Secrets Instead of Environment Variables](#why-use-secrets-instead-of-environment-variables)
- [Docker BuildKit Secrets (Build-time)](#docker-buildkit-secrets-build-time)
- [Docker Swarm Secrets (Runtime)](#docker-swarm-secrets-runtime)
- [Docker Compose Secrets](#docker-compose-secrets)
- [Kubernetes Secrets](#kubernetes-secrets)
- [Application Integration](#application-integration)
- [Security Best Practices](#security-best-practices)
- [Migration from Environment Variables](#migration-from-environment-variables)

## Overview

Docker secrets provide a secure way to manage sensitive data such as passwords, API keys, SSH keys, certificates, and other credentials. Unlike environment variables, secrets are encrypted at rest and in transit, and are only accessible to services that need them.

## Why Use Secrets Instead of Environment Variables

### Environment Variables Limitations
- Visible in container inspect output
- Logged in process listings (`ps aux`)
- Inherited by child processes
- Often accidentally logged
- Stored in plain text in compose files

### Secrets Advantages
- Encrypted at rest
- Encrypted in transit
- Only accessible to authorized services
- Mounted as files (not in environment)
- Automatic rotation support
- Audit trail capabilities
- **Override environment variables** (including .env files)

## Docker BuildKit Secrets (Build-time)

BuildKit secrets allow you to pass sensitive data during image build without leaving traces in the final image.

### Basic BuildKit Secret Usage

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine:latest

# Mount secret during build only
RUN --mount=type=secret,id=github_token \
    TOKEN=$(cat /run/secrets/github_token) && \
    git clone https://${TOKEN}@github.com/private/repo.git /app

# Secret is NOT in the final image!
```

Build command:
```bash
# Pass secret from file
docker build --secret id=github_token,src=.secrets/github_token .

# Pass secret from environment variable
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
echo $GITHUB_TOKEN | docker build --secret id=github_token -
```

### Multiple BuildKit Secrets

```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-alpine

WORKDIR /app

# Use multiple secrets for private npm registry
RUN --mount=type=secret,id=npm_token \
    --mount=type=secret,id=npm_registry \
    NPM_TOKEN=$(cat /run/secrets/npm_token) && \
    REGISTRY=$(cat /run/secrets/npm_registry) && \
    echo "//${REGISTRY}/:_authToken=${NPM_TOKEN}" > ~/.npmrc && \
    npm install && \
    rm ~/.npmrc  # Clean up

# No secrets in the image layers!
```

### SSH Key for Private Repositories

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.21-alpine

# Use SSH key to clone private repos
RUN --mount=type=ssh \
    mkdir -p -m 0700 ~/.ssh && \
    ssh-keyscan github.com >> ~/.ssh/known_hosts && \
    git clone git@github.com:private/repo.git /app

# Alternative: Using secret file
RUN --mount=type=secret,id=ssh_key,target=/root/.ssh/id_rsa,mode=0600 \
    --mount=type=secret,id=known_hosts,target=/root/.ssh/known_hosts \
    git clone git@github.com:private/repo.git /app
```

Build with SSH:
```bash
docker build --ssh default .
# or with specific key
docker build --ssh default=$HOME/.ssh/id_rsa .
```

## Docker Swarm Secrets (Runtime)

Docker Swarm mode provides built-in secret management for runtime secrets.

### Creating Swarm Secrets

```bash
# From string
echo "MyP@ssw0rd" | docker secret create db_password -

# From file
docker secret create ssl_cert cert.pem

# Generate random secret
openssl rand -base64 32 | docker secret create api_key -
```

### Using Secrets in Swarm Services

```yaml
# docker-compose.yml (Swarm mode)

services:
  database:
    image: postgres:16
    secrets:
      - db_password
      - db_root_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
      POSTGRES_ROOT_PASSWORD_FILE: /run/secrets/db_root_password
    deploy:
      replicas: 1

  app:
    image: myapp:latest
    secrets:
      - db_password
      - api_key
      - jwt_secret
    environment:
      # Reference secret files
      DATABASE_PASSWORD_FILE: /run/secrets/db_password
      API_KEY_FILE: /run/secrets/api_key
      JWT_SECRET_FILE: /run/secrets/jwt_secret

secrets:
  db_password:
    external: true  # Created with docker secret create
  db_root_password:
    external: true
  api_key:
    external: true
  jwt_secret:
    external: true
```

Deploy to Swarm:
```bash
docker stack deploy -c docker-compose.yml myapp
```

### Secret Rotation in Swarm

```bash
# Create new version
echo "NewP@ssw0rd" | docker secret create db_password_v2 -

# Update service to use new secret
docker service update \
  --secret-rm db_password \
  --secret-add source=db_password_v2,target=db_password \
  myapp_database
```

## Secrets vs Environment Variables Precedence

### Configuration Precedence Order

When using both secrets and environment variables, the precedence depends on how your application reads configuration:

```javascript
// Application-controlled precedence
function getConfig(name) {
  // 1. HIGHEST PRIORITY: Secret file
  const secretFile = process.env[`${name}_FILE`];
  if (secretFile && fs.existsSync(secretFile)) {
    return fs.readFileSync(secretFile, 'utf8').trim();
  }
  
  // 2. FALLBACK: Environment variable
  return process.env[name];
}
```

### Overriding .env with Secrets

```yaml
# docker-compose.yml

services:
  app:
    image: myapp:latest
    env_file: 
      - .env  # Contains: PASSWORD=development
    secrets:
      - password  # Contains: production-secret
    environment:
      # This makes the app use secret instead of .env
      PASSWORD_FILE: /run/secrets/password
      # Fallback from .env if secret doesn't exist
      PASSWORD: ${PASSWORD}

secrets:
  password:
    file: ./secrets/password  # OVERRIDES .env value!
```

### Practical Override Example

```yaml
# .env (development defaults)
DATABASE_PASSWORD=localdev
REDIS_PASSWORD=redis123
API_KEY=dev-key

# docker-compose.yml
services:
  app:
    env_file: .env
    secrets:
      - db_password    # Overrides DATABASE_PASSWORD
      - redis_password # Overrides REDIS_PASSWORD
      # api_key not provided as secret, uses .env value
    environment:
      # Secrets override .env for sensitive data
      DATABASE_PASSWORD_FILE: /run/secrets/db_password
      REDIS_PASSWORD_FILE: /run/secrets/redis_password
      # API_KEY from .env (no secret override)
      API_KEY: ${API_KEY}

secrets:
  db_password:
    file: ./secrets/db_password  # production value
  redis_password:
    file: ./secrets/redis_password  # production value
```

Result:
- `DATABASE_PASSWORD`: Uses secret (production value)
- `REDIS_PASSWORD`: Uses secret (production value)  
- `API_KEY`: Uses .env value (dev-key)

## Docker Compose Secrets

Docker Compose (non-Swarm) supports secrets for local development.

### File-based Secrets (Development)

```yaml
# docker-compose.yml

services:
  database:
    image: postgres:16
    secrets:
      - db_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password

  app:
    build: .
    secrets:
      - db_password
      - api_key
    environment:
      DATABASE_PASSWORD_FILE: /run/secrets/db_password
      API_KEY_FILE: /run/secrets/api_key

secrets:
  db_password:
    file: ./secrets/db_password.txt  # Local file
  api_key:
    file: ./secrets/api_key.txt
```

Directory structure:
```
project/
├── docker-compose.yml
├── secrets/           # Add to .gitignore!
│   ├── db_password.txt
│   └── api_key.txt
└── .gitignore
```

### Environment Variable Secrets (CI/CD)

```yaml
# docker-compose.yml

services:
  app:
    image: myapp:latest
    secrets:
      - db_password
      - api_key
    environment:
      DATABASE_PASSWORD_FILE: /run/secrets/db_password
      API_KEY_FILE: /run/secrets/api_key

secrets:
  db_password:
    environment: DB_PASSWORD_SECRET  # From env var
  api_key:
    environment: API_KEY_SECRET
```

Usage:
```bash
export DB_PASSWORD_SECRET="production-password"
export API_KEY_SECRET="sk-prod-key"
docker-compose up
```

## Kubernetes Secrets

Kubernetes has its own secret management system.

### Creating Kubernetes Secrets

```bash
# From literals
kubectl create secret generic app-secrets \
  --from-literal=db-password='MyP@ssw0rd' \
  --from-literal=api-key='sk-proj-xxxxx'

# From files
kubectl create secret generic app-secrets \
  --from-file=ssh-key=/path/to/id_rsa \
  --from-file=ssl-cert=/path/to/cert.pem

# From .env file
kubectl create secret generic app-secrets \
  --from-env-file=.env.production
```

### Using Secrets in Pods

```yaml
# deployment.yaml
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
        # Mount as files
        volumeMounts:
        - name: secrets
          mountPath: /run/secrets
          readOnly: true
        # Or as environment variables (less secure)
        env:
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db-password
      volumes:
      - name: secrets
        secret:
          secretName: app-secrets
          # Set file permissions
          defaultMode: 0400
          items:
          - key: db-password
            path: db_password
          - key: api-key
            path: api_key
```

### Sealed Secrets (GitOps)

For GitOps workflows, use Sealed Secrets to encrypt secrets that can be stored in Git:

```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create a secret
echo -n "MyP@ssw0rd" | kubectl create secret generic db-secret \
  --dry-run=client \
  --from-file=password=/dev/stdin \
  -o yaml | kubeseal -o yaml > sealed-secret.yaml

# Commit sealed-secret.yaml to Git (safe!)
git add sealed-secret.yaml
git commit -m "Add encrypted database password"
```

## Application Integration

### Reading Secrets from Files (Recommended)

**Node.js Example:**
```javascript
const fs = require('fs');

function getSecret(secretName) {
  const secretPath = process.env[`${secretName}_FILE`];
  if (secretPath) {
    try {
      return fs.readFileSync(secretPath, 'utf8').trim();
    } catch (err) {
      console.error(`Failed to read secret ${secretName}:`, err);
      throw err;
    }
  }
  // Fallback to env var for development
  return process.env[secretName];
}

// Usage
const dbPassword = getSecret('DATABASE_PASSWORD');
const apiKey = getSecret('API_KEY');
```

**Python Example:**
```python
import os
from pathlib import Path

def get_secret(secret_name):
    """Read secret from file or environment variable."""
    secret_file = os.environ.get(f"{secret_name}_FILE")
    
    if secret_file:
        try:
            return Path(secret_file).read_text().strip()
        except Exception as e:
            print(f"Failed to read secret {secret_name}: {e}")
            raise
    
    # Fallback to environment variable
    return os.environ.get(secret_name)

# Usage
db_password = get_secret("DATABASE_PASSWORD")
api_key = get_secret("API_KEY")
```

**Go Example:**
```go
package main

import (
    "fmt"
    "os"
    "strings"
)

func GetSecret(name string) (string, error) {
    // Check for file path
    if filePath := os.Getenv(name + "_FILE"); filePath != "" {
        data, err := os.ReadFile(filePath)
        if err != nil {
            return "", fmt.Errorf("reading secret %s: %w", name, err)
        }
        return strings.TrimSpace(string(data)), nil
    }
    
    // Fallback to environment variable
    return os.Getenv(name), nil
}

// Usage
dbPassword, _ := GetSecret("DATABASE_PASSWORD")
apiKey, _ := GetSecret("API_KEY")
```

### Shell Script Integration

```bash
#!/bin/bash

# Function to read secret
get_secret() {
    local secret_name=$1
    local file_var="${secret_name}_FILE"
    
    if [ -n "${!file_var}" ]; then
        # Read from file
        cat "${!file_var}" 2>/dev/null | tr -d '\n'
    else
        # Fallback to env var
        echo "${!secret_name}"
    fi
}

# Usage
DB_PASSWORD=$(get_secret "DATABASE_PASSWORD")
API_KEY=$(get_secret "API_KEY")

# Connect to database
psql "postgresql://user:${DB_PASSWORD}@localhost/mydb"
```

## Security Best Practices

### 1. Never Log Secrets
```javascript
// BAD
console.log(`Connecting with password: ${password}`);

// GOOD
console.log('Connecting to database...');
```

### 2. Use Least Privilege
```yaml
# Give each service only the secrets it needs
services:
  frontend:
    secrets:
      - api_key  # Only needs API key
  
  backend:
    secrets:
      - db_password  # Only needs database
      - api_key
```

### 3. Rotate Secrets Regularly
```bash
# Automated rotation script
#!/bin/bash
NEW_PASSWORD=$(openssl rand -base64 32)
echo "${NEW_PASSWORD}" | docker secret create "db_password_$(date +%s)" -
docker service update --secret-rm db_password --secret-add db_password_new app
```

### 4. Encrypt Secrets at Rest
```yaml
# docker-compose.yml with encrypted secrets
secrets:
  db_password:
    file: ./secrets/db_password.enc
    driver: encrypted  # Custom driver
```

### 5. Audit Secret Access
```bash
# Monitor secret access
docker events --filter event=secret
```

### 6. Use Short-Lived Tokens
```dockerfile
# BuildKit with temporary token
RUN --mount=type=secret,id=temp_token \
    TOKEN=$(cat /run/secrets/temp_token) && \
    # Token expires in 5 minutes
    curl -H "Authorization: Bearer $TOKEN" https://api.example.com/data
```

## Migration from Environment Variables

### Step 1: Identify Sensitive Variables
```bash
# Find potential secrets in docker-compose.yml
grep -E "(PASSWORD|SECRET|KEY|TOKEN|CERT)" docker-compose.yml
```

### Step 2: Create Secret Files
```bash
# Create secrets directory
mkdir -p secrets
chmod 700 secrets

# Move secrets to files
echo "${DB_PASSWORD}" > secrets/db_password
echo "${API_KEY}" > secrets/api_key
chmod 600 secrets/*
```

### Step 3: Update Docker Compose
```yaml
# Before (environment variables)
services:
  app:
    environment:
      - DB_PASSWORD=MyP@ssw0rd  # BAD!
      - API_KEY=sk-xxxxx         # BAD!

# After (secrets)
services:
  app:
    secrets:
      - db_password
      - api_key
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - API_KEY_FILE=/run/secrets/api_key

secrets:
  db_password:
    file: ./secrets/db_password
  api_key:
    file: ./secrets/api_key
```

### Step 4: Update Application Code
```javascript
// Before
const password = process.env.DB_PASSWORD;

// After
const password = fs.readFileSync(
  process.env.DB_PASSWORD_FILE || '/run/secrets/db_password',
  'utf8'
).trim();
```

### Step 5: Update CI/CD Pipeline
```yaml
# GitHub Actions example
- name: Deploy with secrets
  run: |
    echo "${{ secrets.DB_PASSWORD }}" > db_password
    echo "${{ secrets.API_KEY }}" > api_key
    docker stack deploy -c docker-compose.yml app
    rm db_password api_key  # Clean up
```

## Examples

### Complete Example: Secure Node.js App

**Dockerfile:**
```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-alpine

WORKDIR /app

# Use BuildKit secret for private npm packages
RUN --mount=type=secret,id=npm_token \
    echo "//registry.npmjs.org/:_authToken=$(cat /run/secrets/npm_token)" > ~/.npmrc && \
    npm ci --production && \
    rm ~/.npmrc

COPY . .

USER node
EXPOSE 3000
CMD ["node", "server.js"]
```

**docker-compose.yml:**
```yaml

services:
  postgres:
    image: postgres:16
    secrets:
      - db_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
      POSTGRES_DB: myapp
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    secrets:
      - redis_password
    command: >
      sh -c 'redis-server --requirepass "$$(cat /run/secrets/redis_password)"'

  app:
    build:
      context: .
      secrets:
        - id: npm_token
          src: ./.secrets/npm_token
    secrets:
      - db_password
      - redis_password
      - jwt_secret
      - api_key
    environment:
      NODE_ENV: production
      DATABASE_PASSWORD_FILE: /run/secrets/db_password
      REDIS_PASSWORD_FILE: /run/secrets/redis_password
      JWT_SECRET_FILE: /run/secrets/jwt_secret
      API_KEY_FILE: /run/secrets/api_key
    depends_on:
      - postgres
      - redis
    ports:
      - "3000:3000"

secrets:
  db_password:
    file: ./secrets/db_password
  redis_password:
    file: ./secrets/redis_password
  jwt_secret:
    file: ./secrets/jwt_secret
  api_key:
    file: ./secrets/api_key

volumes:
  postgres_data:
```

**Application Code (server.js):**
```javascript
const fs = require('fs');
const express = require('express');
const { Pool } = require('pg');
const redis = require('redis');
const jwt = require('jsonwebtoken');

// Secret helper
function getSecret(name) {
  const filePath = process.env[`${name}_FILE`];
  if (filePath && fs.existsSync(filePath)) {
    return fs.readFileSync(filePath, 'utf8').trim();
  }
  throw new Error(`Secret ${name} not found`);
}

// Load secrets
const secrets = {
  dbPassword: getSecret('DATABASE_PASSWORD'),
  redisPassword: getSecret('REDIS_PASSWORD'),
  jwtSecret: getSecret('JWT_SECRET'),
  apiKey: getSecret('API_KEY')
};

// Database connection
const pool = new Pool({
  host: 'postgres',
  database: 'myapp',
  user: 'postgres',
  password: secrets.dbPassword
});

// Redis connection
const redisClient = redis.createClient({
  host: 'redis',
  password: secrets.redisPassword
});

// Express app
const app = express();

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
  // Never log secrets!
  console.log('Secrets loaded successfully');
});
```

## Summary

### When to Use Each Method

| Method | Use Case | Security Level |
|--------|----------|---------------|
| Environment Variables | Non-sensitive config | Low |
| BuildKit Secrets | Build-time secrets | High (build only) |
| Docker Swarm Secrets | Production runtime | High |
| Compose Secrets (file) | Development/testing | Medium |
| Kubernetes Secrets | K8s deployments | High |

### Key Takeaways

✅ **DO:**
- Use secrets for all sensitive data
- Read secrets from files, not environment variables
- Rotate secrets regularly
- Use BuildKit secrets for build-time needs
- Implement proper secret management in production

❌ **DON'T:**
- Store secrets in environment variables
- Commit secret files to Git
- Log secret values
- Share secrets between unrelated services
- Leave secrets in Docker image layers

By following these patterns, your applications will have enterprise-grade secret management with proper security controls.