#!/bin/bash

# ==============================================================================
# Example: Integrating DockerKit in Your Project
# ==============================================================================

# Method 1: As a Git Submodule
# -----------------------------
git submodule add https://github.com/phdsystems/phd-ade.git tools/phd-ade
git submodule update --init --recursive

# Use directly from submodule
./tools/phd-ade/dockerkit-package/bin/dck check

# Method 2: As an npm Dependency
# -------------------------------
npm install --save-dev @phdsystems/dockerkit

# Add to package.json scripts
cat >> package.json << 'EOF'
{
  "scripts": {
    "docker:check": "dck check",
    "docker:audit": "dck audit --format json --output docker-audit.json",
    "docker:template": "dck template dockerfile --type node"
  }
}
EOF

# Method 3: In Docker Compose
# ----------------------------
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  dockerkit:
    image: phdsystems/dockerkit:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - .:/workspace
    working_dir: /workspace
    command: check --strict

  app:
    build: .
    depends_on:
      - dockerkit
EOF

# Method 4: In CI/CD Pipeline (GitHub Actions)
# ---------------------------------------------
cat > .github/workflows/docker-compliance.yml << 'EOF'
name: Docker Compliance

on:
  push:
    paths:
      - 'Dockerfile*'
      - 'docker-compose*.yml'
      - '.dockerignore'

jobs:
  compliance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup DockerKit
        run: |
          curl -fsSL https://raw.githubusercontent.com/phdsystems/phd-ade/feature/docker-kit/dockerkit-package/install.sh | bash
          echo "/usr/local/dockerkit/bin" >> $GITHUB_PATH
      
      - name: Run Compliance Check
        run: dck check --strict --threshold 80
      
      - name: Generate Report
        if: always()
        run: dck report --format markdown --output compliance-report.md
      
      - name: Upload Report
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: docker-compliance-report
          path: compliance-report.md
EOF

# Method 5: As a Pre-commit Hook
# -------------------------------
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Docker compliance pre-commit hook

# Check if Dockerfile changed
if git diff --cached --name-only | grep -q "Dockerfile"; then
    echo "Running Docker compliance check..."
    
    # Install DockerKit if not present
    if ! command -v dck &> /dev/null; then
        curl -fsSL https://raw.githubusercontent.com/phdsystems/phd-ade/feature/docker-kit/dockerkit-package/install.sh | bash
    fi
    
    # Run compliance check
    dck check --strict || {
        echo "Docker compliance check failed!"
        echo "Run 'dck fix' to auto-fix issues or fix manually"
        exit 1
    }
fi
EOF
chmod +x .git/hooks/pre-commit

# Method 6: As a Makefile Target
# -------------------------------
cat > Makefile << 'EOF'
# DockerKit integration

DOCKERKIT := $(shell command -v dck 2> /dev/null)

.PHONY: docker-check docker-fix docker-audit

install-dockerkit:
ifndef DOCKERKIT
	@echo "Installing DockerKit..."
	@curl -fsSL https://raw.githubusercontent.com/phdsystems/phd-ade/feature/docker-kit/dockerkit-package/install.sh | bash
endif

docker-check: install-dockerkit
	@echo "Running Docker compliance check..."
	@dck check --strict

docker-fix: install-dockerkit
	@echo "Fixing Docker compliance issues..."
	@dck fix --dry-run
	@read -p "Apply fixes? [y/N] " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		dck fix; \
	fi

docker-audit: install-dockerkit
	@echo "Running Docker security audit..."
	@dck audit --format json --output docker-audit.json
	@echo "Audit complete. Results in docker-audit.json"

docker-template: install-dockerkit
	@echo "Available templates:"
	@dck template list
	@read -p "Enter template type: " template; \
	dck template dockerfile --type $$template --output Dockerfile.generated

# Include in your build process
build: docker-check
	docker build -t myapp:latest .

deploy: docker-audit build
	docker push myapp:latest
EOF

# Method 7: As a Standalone Script in Project
# --------------------------------------------
cat > check-docker-compliance.sh << 'EOF'
#!/bin/bash

# Project-specific Docker compliance checker

set -e

# Configuration
DOCKERKIT_VERSION="1.0.0"
COMPLIANCE_THRESHOLD=85
OUTPUT_FORMAT="json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Install DockerKit if needed
install_dockerkit() {
    if ! command -v dck &> /dev/null; then
        echo -e "${YELLOW}DockerKit not found. Installing...${NC}"
        curl -fsSL https://raw.githubusercontent.com/phdsystems/phd-ade/feature/docker-kit/dockerkit-package/install.sh | bash
    fi
}

# Run compliance check
run_compliance_check() {
    echo -e "${GREEN}Running Docker compliance check...${NC}"
    
    dck check \
        --threshold "$COMPLIANCE_THRESHOLD" \
        --format "$OUTPUT_FORMAT" \
        --output compliance-report.json
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ Docker compliance check passed!${NC}"
    else
        echo -e "${RED}✗ Docker compliance check failed!${NC}"
        echo "View detailed report: compliance-report.json"
        exit 1
    fi
}

# Main execution
main() {
    install_dockerkit
    run_compliance_check
}

main "$@"
EOF
chmod +x check-docker-compliance.sh

echo "Integration examples created successfully!"