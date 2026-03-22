---
layout: default
title: Image Comparison
parent: Reference
nav_order: 3
---

# Docker Image Size Comparison

**Audience**: DevOps engineers, contributors

## WHAT

Size and capability comparison across DockerKit image variants (original, multistage, minimal, distroless).

## WHY

Choosing the right image variant requires understanding the trade-offs between size, functionality, and security posture.

## HOW

### Build Results

| Image Variant | Size | Reduction | Description |
|--------------|------|-----------|-------------|
| dck:original | 108MB | Baseline | Single-stage Alpine with all tools |
| dck:multistage | 108MB | 0% | Multi-stage build with validation |
| dck:minimal | 30.4MB | -72% | Scratch-based with essential binaries |
| dck:distroless | 3.26MB | -97% | Ultra-minimal distroless (limited functionality) |

## Analysis

### Original vs Multistage (108MB each)
- Both images have the same size because they include the same runtime dependencies
- Multistage advantage: Build-time validation with shellcheck
- Multistage advantage: Better layer caching and cleaner build process

### Minimal Image (30.4MB - 72% reduction)
- Built from scratch with only essential binaries
- Includes: bash, curl, jq, docker-cli
- Trade-off: Limited shell utilities (uses busybox)
- Best for: Production environments where size matters

### Distroless Image (3.26MB - 97% reduction)
- Ultra-minimal with just a Go binary placeholder
- Trade-off: No shell, limited functionality
- Would require rewriting DCK as a compiled binary
- Best for: Highly secure, minimal attack surface deployments

## Recommendations

1. **Development**: Use `Dockerfile` (original) for full tooling
2. **CI/CD**: Use `Dockerfile.multistage` for build validation
3. **Production**: Use `Dockerfile.minimal` for good balance of size and functionality
4. **High Security**: Consider `Dockerfile.distroless` with compiled DCK binary

## Build Commands

```bash
# Original
docker build -f Dockerfile -t dck:latest .

# Multi-stage
docker build -f Dockerfile.multistage -t dck:multistage .

# Minimal
docker build -f Dockerfile.minimal -t dck:minimal .

# Distroless (experimental)
docker build -f Dockerfile.distroless -t dck:distroless .
```

## Security Scan Results

Run security scans on the minimal production image:
```bash
docker scout cves dck:minimal
trivy image dck:minimal
```