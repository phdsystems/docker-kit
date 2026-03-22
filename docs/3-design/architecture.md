---
layout: default
title: Architecture
parent: Design
nav_order: 1
---

# DockerKit Architecture

**Audience**: Architects, technical leadership, contributors

## WHAT

DockerKit is a modular Bash CLI toolkit for Docker management, organized as a command dispatcher (`bin/dck`) routing to 32 specialized modules under `main/src/`.

## WHY

Docker environments need consistent security auditing, compliance checking, and resource management. A unified CLI with modular internals keeps each concern isolated while providing a single user interface.

## HOW

### System Overview

```mermaid
block-beta
  columns 4
  block:router:4
    dck["bin/dck — CLI Router & Dispatcher"]
  end
  block:inspect:1
    A["Object Inspect\nimages\ncontainers\nvolumes\nnetworks"]
  end
  block:search:1
    B["Search & Filter\nsearch-images\nsearch-containers\nsearch-volumes\nsearch-networks"]
  end
  block:analysis:1
    C["Analysis & Audit\nadvanced-images\nadvanced-containers\nsecurity\ncompliance\nremediation"]
  end
  block:ops:1
    D["Operations\ncleanup\nmonitor\ntemplate-generator\ncompose-operations\ncontainer-lifecycle\ncontainer-exec\nimage-operations\nvolume-operations\nnetwork-operations"]
  end
  block:lib:4
    E["main/src/lib/ — common.sh (logging, formatting) · docker-wrapper.sh (sudo, Docker cmd abstraction)"]
  end
```

### Module Categories

| Category | Modules | Purpose |
|----------|---------|---------|
| Object Inspection | `docker-images.sh`, `docker-containers.sh`, `docker-volumes.sh`, `docker-networks.sh` | Basic Docker object listing and inspection |
| Advanced Analysis | `docker-advanced-*.sh` (4 modules) | Deep analysis with layer details, resource usage |
| Search & Filter | `docker-search-*.sh` (4 modules) | Filter objects by name, status, labels |
| Security & Compliance | `docker-security.sh`, `docker-compliance.sh`, `docker-remediation.sh` | CIS/OWASP auditing, auto-fix |
| Operations | `docker-cleanup.sh`, `docker-monitor.sh`, `docker-template-generator.sh` | Resource management, monitoring, scaffolding |
| Lifecycle | `docker-container-lifecycle.sh`, `docker-container-exec.sh`, `docker-compose-operations.sh` | Container and Compose lifecycle management |
| Object Operations | `docker-image-operations.sh`, `docker-volume-operations.sh`, `docker-network-operations.sh` | Advanced CRUD for Docker objects |

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Pure Bash | Zero runtime dependencies beyond Docker and standard Unix tools |
| Dispatch pattern | `bin/dck` routes to `main/src/docker-*.sh` — modules are independently testable |
| Shared libraries | `lib/common.sh` and `lib/docker-wrapper.sh` prevent duplication |
| Mock-based tests | Tests run without Docker daemon via `tests/mocks/` |
| Safety boundary | Build/test/install scripts scoped to `dck*` prefix; management CLI has full access |

### Data Flow

```mermaid
flowchart LR
  User --> dck["bin/dck"]
  dck --> parse["Parse command"]
  parse --> check["check_docker()"]
  check --> dispatch["Dispatch to module"]
  dispatch --> wrapper["docker-wrapper.sh\n(sudo detection)"]
  dispatch --> module["main/src/docker-*.sh\n(module logic)"]
  wrapper --> docker["Docker CLI/API"]
  module --> output["Formatted output"]
```

### Technology Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Language | Bash | 5.x |
| Base Image | Alpine Linux | 3.19.1 |
| JSON Processing | jq | Latest |
| Linting | ShellCheck, Hadolint | Latest |
| Scanning | Trivy, Docker Scout | Latest |
| Distribution | npm, Docker | Latest |

## Related Documentation

- [Safety Boundaries](../safety_boundaries.md) — Safety guarantees and scope
- [Compliance](compliance_overview.md) — CIS/OWASP compliance checking
- [Standards](../standards/README.md) — Security and coding standards
- [Compliance Checklist](compliance/compliance_checklist.md) — Architecture compliance audit
- [Developer Guide](../4-development/developer_guide.md) — Development workflow
