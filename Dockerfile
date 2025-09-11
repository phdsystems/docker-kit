# syntax=docker/dockerfile:1.4
# -----------------------------------------------------------------------------
# DockerKit - Docker Management Toolkit
# Production Dockerfile
# -----------------------------------------------------------------------------

# For full build with all features, see build-targets/Dockerfile.dockerkit
# This is a simplified production build

# Pin specific version for reproducibility
FROM alpine:3.19.1

# Add metadata labels
LABEL maintainer="DCK Team" \
      version="1.0.0" \
      description="DCK - Docker Management Toolkit" \
      org.opencontainers.image.source="https://github.com/phdsystems/dck"

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    git \
    docker-cli \
    docker-cli-compose \
    sudo

# Create dck user
RUN addgroup -g 1000 dck && \
    adduser -D -u 1000 -G dck -s /bin/bash dck && \
    echo "dck ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Set up DockerKit directory
WORKDIR /opt/dck

# Copy DockerKit files (ordered by change frequency for better caching)
COPY --chown=dck:dck ./docs/ /opt/dck/docs/
COPY --chown=dck:dck ./lib/ /opt/dck/lib/
COPY --chown=dck:dck ./src/ /opt/dck/src/
COPY --chown=dck:dck ./dck /opt/dck/

# Make scripts executable
RUN chmod +x dck && \
    chmod +x src/*.sh && \
    ln -s /opt/dck/dck /usr/local/bin/dck

# Create data directories
RUN mkdir -p /var/lib/dck/data && \
    mkdir -p /var/lib/dck/logs && \
    chown -R dck:dck /var/lib/dck

# Environment
ENV PATH="/opt/dck:${PATH}"

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD dck version || exit 1

# Switch to dck user
USER dck

# Entry point for production (exec form for proper signal handling)
ENTRYPOINT ["dck"]
CMD ["--help"]