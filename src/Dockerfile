# DockerKit - Docker Management Toolkit Container
# Provides a containerized environment for DockerKit with Docker-in-Docker support

FROM docker:24-dind

# Install bash, curl, jq, and other utilities
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    git \
    make \
    grep \
    sed \
    coreutils \
    ncurses \
    less \
    vim \
    sudo

# Create dockerkit user with sudo privileges
RUN addgroup -g 1000 dockerkit && \
    adduser -D -u 1000 -G dockerkit -s /bin/bash dockerkit && \
    echo "dockerkit ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Set up DockerKit directory
WORKDIR /opt/dockerkit

# Copy DockerKit files
COPY --chown=dockerkit:dockerkit . .

# Make scripts executable
RUN chmod +x dockerkit && \
    chmod +x scripts/*.sh && \
    chmod +x tests/*.sh 2>/dev/null || true && \
    chmod +x tests/mocks/* 2>/dev/null || true

# Add DockerKit to PATH
ENV PATH="/opt/dockerkit:${PATH}"

# Create volume mount points
RUN mkdir -p /var/lib/dockerkit/data && \
    mkdir -p /var/lib/dockerkit/logs && \
    chown -R dockerkit:dockerkit /var/lib/dockerkit

# Switch to dockerkit user
USER dockerkit

# Set up shell environment
RUN echo 'export PS1="\[\033[1;36m\]dockerkit\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]$ "' >> ~/.bashrc && \
    echo 'alias ll="ls -la"' >> ~/.bashrc && \
    echo 'alias dk="dockerkit"' >> ~/.bashrc

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD docker info >/dev/null 2>&1 || exit 1

# Default command
CMD ["/bin/bash"]