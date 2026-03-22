# DCK Safety Boundaries

**Audience**: All users, contributors, auditors

## WHAT

Definition of DockerKit's safety guarantees — which operations are protected, and what the blast radius of each command is.

## WHY

Users must trust that DockerKit will never destroy resources outside its own namespace. Documenting boundaries makes the guarantee auditable.

## HOW

### What the Safety Guarantees Cover

### Protected Operations (DCK Infrastructure Only)

These operations will ONLY affect DCK's own resources (prefixed with `dck`):

1. **Build Scripts** (`scripts/build.sh`)
   - Only builds/tags images as `dck:*`
   - Never deletes non-DCK images

2. **Run Scripts** (`scripts/run.sh`)
   - Only manages containers named `dck*`
   - Never stops/removes other containers

3. **Installation Scripts** (`scripts/install.sh`)
   - Only installs to `/opt/dck`
   - Only creates symlinks for `dck` command

4. **Development Scripts** (`scripts/dev.sh`)
   - Only manages `dck-dev` and `dck-test` containers
   - Only removes `dck:dev` images

5. **Makefile Targets**
   - `make clean` - Only removes DCK containers/images/volumes
   - `make safe-clean` - Verifies before cleaning DCK resources

6. **Unit Tests** (`tests/*`)
   - Mock Docker operations or only create test containers prefixed with `dck-test-*`
   - Never affect production Docker resources

## What the Safety Guarantees DO NOT Cover

### Full Docker Management (User Operations)

When you USE DCK as a Docker management tool, you have FULL control:

```bash
# These commands work on ALL Docker resources, not just DCK ones:

# Search ANY images
dck search images nginx

# Delete ANY container (user's responsibility)
dck delete container my-app-container

# Remove ANY image
dck cleanup images --all

# Stop ANY container
dck stop container redis-server

# Remove ANY volume
dck remove volume postgres-data

# Clean up ANY unused resources
dck cleanup --all --force
```

## Summary

- **DCK's internal operations** = Safe, limited to `dck*` resources
- **DCK as a tool** = Full Docker management capabilities, user controls what to delete

This separation ensures:
1. Installing/uninstalling DCK won't affect your existing Docker setup
2. Running DCK tests won't interfere with your containers
3. Building DCK won't delete your images
4. BUT you can still use DCK to manage ALL your Docker resources as needed

## Example Scenarios

### Scenario 1: Building DCK
```bash
make build
# ✅ Only creates dck:latest image
# ✅ Won't delete your nginx, postgres, redis images
```

### Scenario 2: Cleaning DCK
```bash
make clean
# ✅ Only removes dck, dck-api, dck-ui containers
# ✅ Only removes dck:* images
# ✅ Won't touch your app containers or images
```

### Scenario 3: Using DCK to Manage Docker
```bash
dck cleanup --all
# ⚠️ CAN remove any unused Docker resources (as intended)
# ⚠️ This is the tool's purpose - full Docker management

dck delete container my-production-app
# ⚠️ WILL delete the specified container (as intended)
# ⚠️ User has full control when using the tool
```

### Scenario 4: Running Tests
```bash
make test
# ✅ Uses mock Docker or creates dck-test-* containers
# ✅ Won't interfere with your running containers
```

## Implementation Notes

The safety is implemented at these levels:

1. **Script Level**: Build/run/install scripts use exact name matching for `dck*`
2. **Test Level**: Tests use mocks or isolated test containers
3. **Makefile Level**: Clean targets filter by `dck*` prefix
4. **Documentation Level**: Clear warnings and explanations

The actual DCK tool (`dck` command) has NO such restrictions - it's a full-featured Docker management tool that can operate on any Docker resource as commanded by the user.