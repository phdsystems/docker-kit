# ==============================================================================
# DockerKit Makefile
# ==============================================================================
# Build, test, and package DockerKit for distribution
# ==============================================================================

.PHONY: all build test install uninstall package clean help

# Configuration
NAME := dockerkit
VERSION := 1.0.0
PREFIX := /usr/local/dockerkit
BIN_DIR := /usr/local/bin
BUILD_DIR := ./build
DIST_DIR := ./dist
PACKAGE_NAME := $(NAME)-$(VERSION)

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# Default target
all: build test

help: ## Show this help message
	@echo "$(BLUE)DockerKit Build System$(NC)"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Configuration:"
	@echo "  VERSION: $(VERSION)"
	@echo "  PREFIX:  $(PREFIX)"
	@echo "  BIN_DIR: $(BIN_DIR)"

build: ## Build DockerKit package
	@echo "$(BLUE)Building DockerKit $(VERSION)...$(NC)"
	@mkdir -p $(BUILD_DIR)/{bin,lib,templates,docs}
	
	# Copy source files
	@cp -r bin/* $(BUILD_DIR)/bin/ 2>/dev/null || true
	@cp -r src/* $(BUILD_DIR)/lib/ 2>/dev/null || true
	@cp -r templates/* $(BUILD_DIR)/templates/ 2>/dev/null || true
	@cp -r docs/* $(BUILD_DIR)/docs/ 2>/dev/null || true
	
	# Make scripts executable
	@chmod +x $(BUILD_DIR)/bin/* 2>/dev/null || true
	@chmod +x $(BUILD_DIR)/lib/*.sh 2>/dev/null || true
	
	@echo "$(GREEN)✓ Build complete$(NC)"

test: ## Run test suite
	@echo "$(BLUE)Running tests...$(NC)"
	@if [ -d "tests" ]; then \
		for test in tests/test_*.sh; do \
			if [ -f "$$test" ]; then \
				echo "Running $$test..."; \
				bash "$$test" || exit 1; \
			fi; \
		done; \
		echo "$(GREEN)✓ All tests passed$(NC)"; \
	else \
		echo "$(YELLOW)No tests found$(NC)"; \
	fi

install: build ## Install DockerKit to system
	@echo "$(BLUE)Installing DockerKit...$(NC)"
	@bash install.sh --prefix $(PREFIX) --bin $(BIN_DIR)

uninstall: ## Uninstall DockerKit from system
	@echo "$(RED)Uninstalling DockerKit...$(NC)"
	@bash install.sh --uninstall

package: build ## Create distribution packages
	@echo "$(BLUE)Creating distribution packages...$(NC)"
	@mkdir -p $(DIST_DIR)
	
	# Create tarball
	@echo "Creating tarball..."
	@cp -r $(BUILD_DIR) $(PACKAGE_NAME)
	@cp install.sh $(PACKAGE_NAME)/
	@cp Makefile $(PACKAGE_NAME)/
	@cp README.md $(PACKAGE_NAME)/ 2>/dev/null || true
	@cp LICENSE $(PACKAGE_NAME)/ 2>/dev/null || true
	@tar -czf $(DIST_DIR)/$(PACKAGE_NAME).tar.gz $(PACKAGE_NAME)
	@rm -rf $(PACKAGE_NAME)
	
	# Create zip
	@echo "Creating zip..."
	@cp -r $(BUILD_DIR) $(PACKAGE_NAME)
	@cp install.sh $(PACKAGE_NAME)/
	@cp Makefile $(PACKAGE_NAME)/
	@cp README.md $(PACKAGE_NAME)/ 2>/dev/null || true
	@cp LICENSE $(PACKAGE_NAME)/ 2>/dev/null || true
	@zip -qr $(DIST_DIR)/$(PACKAGE_NAME).zip $(PACKAGE_NAME)
	@rm -rf $(PACKAGE_NAME)
	
	# Create self-extracting installer
	@echo "Creating self-extracting installer..."
	@cat > $(DIST_DIR)/$(PACKAGE_NAME)-installer.sh << 'INSTALLER'
#!/bin/bash
# Self-extracting DockerKit installer
set -e
TMPDIR=$$(mktemp -d)
ARCHIVE=$$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' "$$0")
tail -n+$$ARCHIVE "$$0" | tar xz -C $$TMPDIR
cd $$TMPDIR/$(PACKAGE_NAME)
bash install.sh "$$@"
cd /
rm -rf $$TMPDIR
exit 0
__ARCHIVE_BELOW__
INSTALLER
	@cp -r $(BUILD_DIR) $(PACKAGE_NAME)
	@cp install.sh $(PACKAGE_NAME)/
	@cp Makefile $(PACKAGE_NAME)/
	@tar -cz $(PACKAGE_NAME) >> $(DIST_DIR)/$(PACKAGE_NAME)-installer.sh
	@chmod +x $(DIST_DIR)/$(PACKAGE_NAME)-installer.sh
	@rm -rf $(PACKAGE_NAME)
	
	@echo "$(GREEN)✓ Packages created in $(DIST_DIR)/$(NC)"
	@ls -lh $(DIST_DIR)/

release: package ## Create a GitHub release
	@echo "$(BLUE)Creating GitHub release...$(NC)"
	@if command -v gh >/dev/null 2>&1; then \
		echo "Creating release $(VERSION)..."; \
		gh release create v$(VERSION) \
			--title "DockerKit $(VERSION)" \
			--notes "DockerKit $(VERSION) release" \
			$(DIST_DIR)/$(PACKAGE_NAME).tar.gz \
			$(DIST_DIR)/$(PACKAGE_NAME).zip \
			$(DIST_DIR)/$(PACKAGE_NAME)-installer.sh; \
		echo "$(GREEN)✓ Release created$(NC)"; \
	else \
		echo "$(YELLOW)GitHub CLI not found. Please install 'gh' to create releases.$(NC)"; \
		echo "Manual upload required for:"; \
		ls -1 $(DIST_DIR)/; \
	fi

docker-image: ## Build Docker image with DockerKit
	@echo "$(BLUE)Building Docker image...$(NC)"
	@echo "FROM alpine:latest" > Dockerfile.dockerkit
	@echo "RUN apk add --no-cache bash docker-cli" >> Dockerfile.dockerkit
	@echo "COPY $(BUILD_DIR) /usr/local/dockerkit" >> Dockerfile.dockerkit
	@echo "ENV PATH=/usr/local/dockerkit/bin:\$$PATH" >> Dockerfile.dockerkit
	@echo "ENTRYPOINT [\"dck\"]" >> Dockerfile.dockerkit
	@docker build -f Dockerfile.dockerkit -t $(NAME):$(VERSION) .
	@docker tag $(NAME):$(VERSION) $(NAME):latest
	@rm Dockerfile.dockerkit
	@echo "$(GREEN)✓ Docker image built: $(NAME):$(VERSION)$(NC)"

npm-package: build ## Create npm package
	@echo "$(BLUE)Creating npm package...$(NC)"
	@mkdir -p $(DIST_DIR)/npm
	@cat > $(DIST_DIR)/npm/package.json << 'EOF'
{
  "name": "@phdsystems/dockerkit",
  "version": "$(VERSION)",
  "description": "Docker compliance and management toolkit",
  "bin": {
    "dck": "./bin/dck",
    "dockerkit": "./bin/dockerkit"
  },
  "scripts": {
    "postinstall": "node postinstall.js"
  },
  "keywords": ["docker", "compliance", "devops", "toolkit"],
  "author": "PHD Systems",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/phdsystems/dockerkit.git"
  }
}
EOF
	@cp -r $(BUILD_DIR)/* $(DIST_DIR)/npm/
	@cat > $(DIST_DIR)/npm/postinstall.js << 'EOF'
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Make scripts executable
const binDir = path.join(__dirname, 'bin');
fs.readdirSync(binDir).forEach(file => {
  fs.chmodSync(path.join(binDir, file), 0o755);
});

console.log('DockerKit installed successfully!');
console.log('Run "npx dck --help" to get started.');
EOF
	@cd $(DIST_DIR)/npm && npm pack
	@echo "$(GREEN)✓ npm package created$(NC)"

clean: ## Clean build artifacts
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(BUILD_DIR) $(DIST_DIR)
	@echo "$(GREEN)✓ Clean complete$(NC)"

dev: ## Run in development mode
	@echo "$(BLUE)Running in development mode...$(NC)"
	@export PATH="$$(pwd)/bin:$$PATH" && \
		export DOCKERKIT_HOME="$$(pwd)" && \
		bash

.PHONY: version
version: ## Show version
	@echo "DockerKit version $(VERSION)"

.PHONY: check-deps
check-deps: ## Check dependencies
	@echo "$(BLUE)Checking dependencies...$(NC)"
	@command -v docker >/dev/null 2>&1 && echo "$(GREEN)✓ docker$(NC)" || echo "$(RED)✗ docker$(NC)"
	@command -v bash >/dev/null 2>&1 && echo "$(GREEN)✓ bash$(NC)" || echo "$(RED)✗ bash$(NC)"
	@command -v make >/dev/null 2>&1 && echo "$(GREEN)✓ make$(NC)" || echo "$(RED)✗ make$(NC)"
	@command -v tar >/dev/null 2>&1 && echo "$(GREEN)✓ tar$(NC)" || echo "$(RED)✗ tar$(NC)"
	@command -v zip >/dev/null 2>&1 && echo "$(GREEN)✓ zip$(NC)" || echo "$(YELLOW)⚠ zip (optional)$(NC)"
	@command -v gh >/dev/null 2>&1 && echo "$(GREEN)✓ gh (GitHub CLI)$(NC)" || echo "$(YELLOW)⚠ gh (optional)$(NC)"
	@command -v npm >/dev/null 2>&1 && echo "$(GREEN)✓ npm$(NC)" || echo "$(YELLOW)⚠ npm (optional)$(NC)"

# Shortcuts
i: install
u: uninstall
p: package
c: clean
t: test