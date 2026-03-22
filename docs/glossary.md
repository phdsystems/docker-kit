---
layout: default
title: Glossary
parent: Reference
nav_order: 8
---

# Glossary

**Audience**: All users and contributors

## WHAT

Alphabetized list of domain terms used across DockerKit documentation and source code.

## WHY

A shared vocabulary eliminates ambiguity and ensures consistent terminology across docs, code, and conversations.

## HOW

**ADR** - Architecture Decision Record. A document capturing a significant architectural decision, its context, and consequences.

**CIS Docker Benchmark** - A security configuration guide published by the Center for Internet Security for hardening Docker environments.

**Compliance Check** - An automated validation of Docker resources against security standards (CIS, OWASP).

**Container** - A runnable instance of a Docker image, providing an isolated environment for a process.

**Dangling Image** - A Docker image that is no longer tagged and not referenced by any container.

**dck** - The DockerKit CLI command. Entry point for all DockerKit operations.

**DockerKit** - This project. A Docker management and compliance toolkit.

**Dockerfile** - A text file containing instructions to build a Docker image.

**Docker Compose** - A tool for defining and running multi-container Docker applications using a YAML file.

**Docker Socket** - The Unix socket (`/var/run/docker.sock`) used to communicate with the Docker daemon.

**Dry Run** - Executing a command in preview mode without making changes. All destructive DockerKit operations support `--dry-run`.

**Hadolint** - A Dockerfile linter that checks for best practices and common mistakes.

**Health Check** - A Docker mechanism to determine if a container is functioning correctly.

**Image** - A read-only template used to create Docker containers, built from a Dockerfile.

**Network** - A Docker object that enables communication between containers.

**OWASP Container Security** - The OWASP Top 10 security risks specific to containerized applications.

**Remediation** - The auto-fix capability in DockerKit that corrects Dockerfile violations (e.g., adding non-root users, pinning base images).

**Safety Boundary** - The principle that DockerKit build/test/install scripts only operate on resources prefixed with `dck*`. The management CLI itself operates on all Docker resources.

**ShellCheck** - A static analysis tool for Bash scripts that identifies bugs and style issues.

**Trivy** - An open-source vulnerability scanner for container images.

**Volume** - A Docker-managed persistent storage mechanism for container data.

**W3H** - WHO-WHAT-WHY-HOW. The documentation structure pattern used in this project.
