# DockerKit Makefile
# Provides convenient shortcuts for common operations

.PHONY: help build run test clean install uninstall shell logs status dev-build dev-run dev-test safety-check

# Default target
help:
	@echo "DockerKit Makefile Commands:"
	@echo ""
	@echo "  make build        - Build DockerKit Docker image"
	@echo "  make run          - Run DockerKit container"
	@echo "  make test         - Run all tests"
	@echo "  make clean        - Clean up containers and images"
	@echo "  make install      - Install DockerKit locally"
	@echo "  make uninstall    - Uninstall DockerKit"
	@echo "  make shell        - Shell into running container"
	@echo "  make logs         - Show container logs"
	@echo "  make status       - Show DockerKit status"
	@echo ""
	@echo "Development commands:"
	@echo "  make dev-build    - Build development image"
	@echo "  make dev-run      - Run with live code mounting"
	@echo "  make dev-test     - Run tests in development mode"
	@echo ""
	@echo "Docker Compose commands:"
	@echo "  make up           - Start all services"
	@echo "  make down         - Stop all services"
	@echo "  make up-api       - Start with API service"
	@echo "  make up-ui        - Start with UI service"

# Build Docker image
build:
	@./scripts/build.sh

# Run DockerKit
run:
	@./scripts/run.sh

# Run tests
test:
	@./tests/run_tests.sh

# Clean up - ONLY DockerKit resources
clean:
	@echo "Cleaning DockerKit resources only..."
	@echo "WARNING: This will only remove DockerKit-specific containers, images, and volumes"
	@echo ""
	@# Stop and remove only DockerKit containers (exact name match)
	@docker ps -aq -f name=^dockerkit$$ | xargs -r docker stop 2>/dev/null || true
	@docker ps -aq -f name=^dockerkit$$ | xargs -r docker rm 2>/dev/null || true
	@docker ps -aq -f name=^dockerkit-session | xargs -r docker stop 2>/dev/null || true
	@docker ps -aq -f name=^dockerkit-session | xargs -r docker rm 2>/dev/null || true
	@docker ps -aq -f name=^dockerkit-api$$ | xargs -r docker stop 2>/dev/null || true
	@docker ps -aq -f name=^dockerkit-api$$ | xargs -r docker rm 2>/dev/null || true
	@docker ps -aq -f name=^dockerkit-ui$$ | xargs -r docker stop 2>/dev/null || true
	@docker ps -aq -f name=^dockerkit-ui$$ | xargs -r docker rm 2>/dev/null || true
	@# Remove only DockerKit images
	@docker rmi dockerkit:latest 2>/dev/null || true
	@docker rmi dockerkit:dev 2>/dev/null || true
	@docker rmi dockerkit-api:latest 2>/dev/null || true
	@docker rmi dockerkit-ui:latest 2>/dev/null || true
	@# Remove only DockerKit volumes
	@docker volume rm dockerkit_data 2>/dev/null || true
	@docker volume rm dockerkit_logs 2>/dev/null || true
	@docker volume rm dockerkit_config 2>/dev/null || true
	@echo "✓ DockerKit cleanup complete"
	@echo "✓ Other Docker resources were NOT affected"

# Install locally
install:
	@sudo ./scripts/install.sh

# Uninstall
uninstall:
	@if [ -f /opt/dockerkit/uninstall.sh ]; then \
		sudo /opt/dockerkit/uninstall.sh; \
	else \
		echo "DockerKit is not installed"; \
	fi

# Shell into container
shell:
	@docker exec -it dockerkit bash

# Show logs
logs:
	@docker logs -f dockerkit

# Show status
status:
	@echo "DockerKit Status:"
	@echo ""
	@docker ps --filter "name=dockerkit" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@docker images --filter "reference=dockerkit*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

# Development build
dev-build:
	@./scripts/dev.sh build

# Development run
dev-run:
	@./scripts/dev.sh run

# Development test
dev-test:
	@./scripts/dev.sh test

# Docker Compose commands
up:
	@docker-compose up -d

down:
	@docker-compose down

up-api:
	@docker-compose --profile api up -d

up-ui:
	@docker-compose --profile ui up -d

# Quick test commands
test-unit:
	@./tests/run_tests.sh --unit

test-integration:
	@./tests/run_tests.sh --integration

test-smoke:
	@./tests/run_tests.sh --smoke

# Build variants
build-all:
	@./scripts/build.sh --profile all

build-api:
	@./scripts/build.sh --profile api

build-ui:
	@./scripts/build.sh --profile ui

# Push to registry
push:
	@./scripts/build.sh --push

# Version info
version:
	@./dockerkit --version 2>/dev/null || echo "DockerKit not installed"

# Safety check - verify DockerKit only affects its own resources
safety-check:
	@./scripts/safety-check.sh all

# Safety verification before cleanup
safety-verify:
	@./scripts/safety-check.sh verify

# Safe cleanup with verification
safe-clean: safety-verify clean
	@echo "✓ Safe cleanup completed"