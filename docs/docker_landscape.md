---
layout: default
title: Docker Landscape
parent: Reference
nav_order: 1
---

# Docker Landscape

**Audience**: All users, developers new to Docker

## WHAT

Overview of the Docker object model and ecosystem — core objects, supporting entities, and open-source vs proprietary boundaries.

## WHY

Understanding Docker's object model and ecosystem context is essential before working with DockerKit's management and compliance features.

## HOW

### Core Docker Objects

These are the primary building blocks most users interact with, all of which are **open source** (part of the Moby project under Apache 2.0):

* **Images**
  Read-only templates made up of layers, used to create containers.

* **Containers**
  Runtime instances of images. Containers add a thin, writable layer on top of an image.

* **Volumes**
  Persistent data storage managed by Docker. They live outside the container lifecycle.

* **Networks**
  Provide connectivity between containers, supporting drivers such as `bridge`, `overlay`, `host`, and `macvlan`.

---

### Less Commonly Used (But Still First-Class Objects)

These are part of the Docker API and CLI but used mainly in cluster setups or advanced scenarios. All of these are also **open source** as part of Docker Engine (Moby):

* **Plugins**
  Extensions for networking, logging, or volume drivers.

* **Secrets** *(Swarm only)*
  Encrypted blobs of sensitive data (like passwords, certificates) managed by the swarm.

* **Configs** *(Swarm only)*
  Plain-text configuration data distributed securely to services.

* **Services** *(Swarm only)*
  Higher-level abstraction that defines how containers are deployed across nodes in a swarm.

* **Stacks** *(Swarm only)*
  Collections of services (like a `docker-compose.yml` deployed at swarm scale).

* **Nodes** *(Swarm only)*
  The machines (physical or virtual) that participate in a swarm cluster.

---

### Supporting Objects

These aren't always treated as core objects but are important in the Docker ecosystem. Most are **open source**, but some surrounding tools are proprietary:

* **Build cache / builder objects**
  Layer caches and buildkit/builder backends that optimize image builds. *(open source)*

* **Contexts**
  Named endpoints that let you switch between different Docker environments (local, remote, cloud). *(open source)*

* **Registries / credentials**
  Authentication and configuration for pushing/pulling images. The client-side is open source, but hosted services like **Docker Hub** are proprietary SaaS.

* **Events**
  A stream of real-time object state changes (create, start, stop, destroy) available via `docker events`. *(open source)*

* **Docker Desktop** *(not an object, but often confused)*
  Proprietary GUI/VM integration layer for Mac/Windows. Not open source.

---

### Object Relationships

How Docker's objects relate in a non‑Swarm and Swarm setup.

### Non‑Swarm (single host)

* **Image → Container(s)**
  Images are immutable templates. A single image can create many containers.

* **Container ⟷ Volume(s)**
  Volumes provide persistent data for containers. One container can mount many volumes; a volume can be mounted by many containers (concurrently or sequentially, depending on workload).

* **Container ⟷ Network(s)**
  Networks connect containers. A container can attach to multiple networks; a network can have many containers.

* **Plugins → (Networks / Volumes)**
  Plugins extend drivers for networking, storage, logging.

#### ASCII sketch

```
        Image (immutable)
             │
             ▼
        Container (runtime)
        ┌───────────┴───────────┐
        ▼                       ▼
    Volume (data)          Network (connectivity)
```

### Swarm relationships (if enabled)

* **Stack → Service(s) → Task(s)/Container(s)**
  Stacks group services; services manage replicated/updated containers (tasks) across nodes.

* **Node → hosts Container(s)**
  Each swarm node runs one or more service tasks (containers).

* **Secrets / Configs → consumed by Service(s)/Container(s)**
  Injected at runtime (files/env) without baking into images.

#### ASCII sketch (Swarm)

```
Stack
 └─ Service (desired state)
     └─ Tasks / Containers  ←→  Networks
                      │
                      └→ Volumes
Nodes (cluster machines) host the tasks
Secrets/Configs → injected into Services/Containers
```

### Cardinality quick‑ref

* **Image : Container** → 1 : N
* **Container : Volume** → N : M
* **Container : Network** → N : M
* **Stack : Service** → 1 : N
* **Service : Container(Task)** → 1 : N
* **Node : Container(Task)** → 1 : N

### Mutability perspective

* **Immutable templates:** Images
* **Runtime / mutable:** Containers, Volumes (data), Networks (membership), Services/Stacks/Nodes (Swarm)
* **Data/Config blobs:** Secrets & Configs (content immutable; usage mutable)

### Relationship mutability

* **Mutable at runtime:**

  * *Image ↔ Containers*: containers can be created/removed anytime.
  * *Container ↔ Volumes*: volume contents change; attach/detach via recreate or connect flows.
  * *Container ↔ Networks*: containers can connect/disconnect at runtime.
  * *Service ↔ Containers (Swarm)*: scale/updates change task membership.
  * *Stack ↔ Services (Swarm)*: updates/redeploys change included services.
  * *Node ↔ Containers (Swarm)*: rescheduling moves tasks between nodes.
  * *Secrets/Configs ↔ Consumers (Swarm)*: which services use them is mutable (content is immutable).

* **Static/immutable relationships:**

  * *Image ↔ Layers*: layer chain does not change post-build.
  * *Plugin ↔ Object type*: plugin capabilities are fixed (e.g., volume vs network driver).

---

### Security Anti-Patterns

### Docker Socket Container Pattern

* **Description:** Mounting the host's Docker socket (`/var/run/docker.sock`) into a container so that the container can run Docker commands against the host daemon.
* **Why risky:**

  * Grants the container root‑equivalent control over the entire host.
  * Breaks isolation: one compromised container can manage or escape into others.
  * Effectively bypasses Docker's security boundaries.
* **Why it's used:**

  * Common in CI/CD (GitLab Runner, Jenkins, GitHub Actions) to allow builds/pushes inside containers.
  * Handy for admin/ops containers where trusted users need full Docker control.
  * Simple to configure — no TLS setup or external daemon required.
* **Safer alternatives:**

  * Use **rootless Docker** or **Podman** for builds without a root daemon.
  * Use **Docker BuildKit** (`buildx`) with an isolated worker.
  * Connect to a **remote Docker daemon over TLS** instead of mounting the socket.
  * In Kubernetes, use RBAC and `kubectl` rather than exposing the Docker socket.

✅ Considered an **anti‑pattern** in production security contexts. Acceptable only in highly trusted, controlled environments (like private CI/CD).

---

### Summary

* **Open source objects**: Images, Containers, Volumes, Networks, Plugins, Secrets, Configs, Services, Stacks, Nodes, Builder cache, Contexts, Events.
* **Proprietary tooling/services**: Docker Desktop, Docker Hub (hosted registry).

This means the **core Docker functionality is fully open source**, while some user-facing packaging and hosted services are not.