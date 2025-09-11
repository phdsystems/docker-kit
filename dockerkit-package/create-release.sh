#!/bin/bash

# ==============================================================================
# DockerKit Release Builder
# ==============================================================================
# Creates distribution packages for multiple platforms and package managers
# ==============================================================================

set -euo pipefail

VERSION="${1:-1.0.0}"
RELEASE_DIR="releases/v${VERSION}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Creating DockerKit Release v${VERSION}${NC}"

# Create release directory
mkdir -p "${RELEASE_DIR}"

# ==============================================================================
# 1. Tarball Distribution
# ==============================================================================
echo -e "${BLUE}Creating tarball distribution...${NC}"

TARBALL_NAME="dockerkit-${VERSION}-linux-x64.tar.gz"
tar -czf "${RELEASE_DIR}/${TARBALL_NAME}" \
    --exclude='.git' \
    --exclude='releases' \
    --exclude='*.log' \
    --exclude='node_modules' \
    --transform "s,^,dockerkit-${VERSION}/," \
    bin src templates docs install.sh Makefile README.md package.json

echo -e "${GREEN}✓ Created ${TARBALL_NAME}${NC}"

# ==============================================================================
# 2. Self-Extracting Installer
# ==============================================================================
echo -e "${BLUE}Creating self-extracting installer...${NC}"

cat > "${RELEASE_DIR}/dockerkit-installer.sh" << 'HEADER'
#!/bin/bash
# DockerKit Self-Extracting Installer
set -e
echo "Installing DockerKit..."
TMPDIR=$(mktemp -d)
ARCHIVE=$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' "$0")
tail -n+$ARCHIVE "$0" | tar xz -C $TMPDIR
cd $TMPDIR/dockerkit-*/
bash install.sh "$@"
cd /
rm -rf $TMPDIR
echo "DockerKit installed successfully!"
exit 0
__ARCHIVE_BELOW__
HEADER

cat "${RELEASE_DIR}/${TARBALL_NAME}" >> "${RELEASE_DIR}/dockerkit-installer.sh"
chmod +x "${RELEASE_DIR}/dockerkit-installer.sh"

echo -e "${GREEN}✓ Created self-extracting installer${NC}"

# ==============================================================================
# 3. DEB Package (Debian/Ubuntu)
# ==============================================================================
echo -e "${BLUE}Creating DEB package...${NC}"

DEB_DIR="${RELEASE_DIR}/dockerkit_${VERSION}_amd64"
mkdir -p "${DEB_DIR}/DEBIAN"
mkdir -p "${DEB_DIR}/usr/local/dockerkit"/{bin,lib,templates,docs}
mkdir -p "${DEB_DIR}/usr/local/bin"

# Copy files
cp -r bin/* "${DEB_DIR}/usr/local/dockerkit/bin/"
cp -r src/* "${DEB_DIR}/usr/local/dockerkit/lib/"
cp -r templates/* "${DEB_DIR}/usr/local/dockerkit/templates/" 2>/dev/null || true
cp -r docs/* "${DEB_DIR}/usr/local/dockerkit/docs/" 2>/dev/null || true

# Create control file
cat > "${DEB_DIR}/DEBIAN/control" << EOF
Package: dockerkit
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Depends: docker.io | docker-ce, bash (>= 4.0)
Maintainer: PHD Systems <support@phdsystems.com>
Description: Docker Compliance & Management Toolkit
 DockerKit provides automated compliance checking,
 template generation, and best practices enforcement
 for Docker environments.
EOF

# Create postinst script
cat > "${DEB_DIR}/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e
ln -sf /usr/local/dockerkit/bin/dck /usr/local/bin/dck
ln -sf /usr/local/dockerkit/bin/dockerkit /usr/local/bin/dockerkit
chmod +x /usr/local/dockerkit/bin/*
echo "DockerKit installed successfully!"
EOF
chmod 755 "${DEB_DIR}/DEBIAN/postinst"

# Build DEB package
dpkg-deb --build "${DEB_DIR}" "${RELEASE_DIR}/dockerkit_${VERSION}_amd64.deb" 2>/dev/null || \
    echo -e "${YELLOW}⚠ dpkg-deb not available, skipping DEB package${NC}"

# ==============================================================================
# 4. RPM Package (RHEL/CentOS/Fedora)
# ==============================================================================
echo -e "${BLUE}Creating RPM spec file...${NC}"

cat > "${RELEASE_DIR}/dockerkit.spec" << EOF
Name:           dockerkit
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        Docker Compliance & Management Toolkit

License:        MIT
URL:            https://github.com/phdsystems/dockerkit
Source0:        dockerkit-${VERSION}.tar.gz

Requires:       docker
Requires:       bash >= 4.0

%description
DockerKit provides automated compliance checking,
template generation, and best practices enforcement
for Docker environments.

%prep
%setup -q

%install
mkdir -p %{buildroot}/usr/local/dockerkit
cp -r * %{buildroot}/usr/local/dockerkit/
mkdir -p %{buildroot}/usr/local/bin
ln -s /usr/local/dockerkit/bin/dck %{buildroot}/usr/local/bin/dck

%files
/usr/local/dockerkit
/usr/local/bin/dck

%changelog
* $(date +"%a %b %d %Y") PHD Systems <support@phdsystems.com> - ${VERSION}-1
- Initial release
EOF

echo -e "${GREEN}✓ Created RPM spec file${NC}"

# ==============================================================================
# 5. Homebrew Formula (macOS)
# ==============================================================================
echo -e "${BLUE}Creating Homebrew formula...${NC}"

cat > "${RELEASE_DIR}/dockerkit.rb" << EOF
class Dockerkit < Formula
  desc "Docker Compliance & Management Toolkit"
  homepage "https://github.com/phdsystems/dockerkit"
  url "https://github.com/phdsystems/dockerkit/releases/download/v${VERSION}/dockerkit-${VERSION}.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on "docker"
  depends_on "bash"

  def install
    prefix.install Dir["*"]
    bin.install_symlink prefix/"bin/dck"
    bin.install_symlink prefix/"bin/dockerkit"
  end

  test do
    system "#{bin}/dck", "--version"
  end
end
EOF

echo -e "${GREEN}✓ Created Homebrew formula${NC}"

# ==============================================================================
# 6. Docker Image
# ==============================================================================
echo -e "${BLUE}Creating Dockerfile...${NC}"

cat > "${RELEASE_DIR}/Dockerfile" << EOF
FROM alpine:3.18

LABEL maintainer="PHD Systems <support@phdsystems.com>"
LABEL version="${VERSION}"
LABEL description="DockerKit - Docker Compliance & Management Toolkit"

RUN apk add --no-cache bash docker-cli curl

COPY bin /usr/local/dockerkit/bin
COPY src /usr/local/dockerkit/lib
COPY templates /usr/local/dockerkit/templates
COPY docs /usr/local/dockerkit/docs

ENV PATH="/usr/local/dockerkit/bin:\${PATH}"
ENV DOCKERKIT_HOME="/usr/local/dockerkit"

RUN chmod +x /usr/local/dockerkit/bin/* && \\
    ln -s /usr/local/dockerkit/bin/dck /usr/local/bin/dck

ENTRYPOINT ["dck"]
CMD ["--help"]
EOF

echo -e "${GREEN}✓ Created Dockerfile${NC}"

# ==============================================================================
# 7. Checksums
# ==============================================================================
echo -e "${BLUE}Generating checksums...${NC}"

cd "${RELEASE_DIR}"
sha256sum dockerkit-* > SHA256SUMS
md5sum dockerkit-* > MD5SUMS
cd - > /dev/null

echo -e "${GREEN}✓ Generated checksums${NC}"

# ==============================================================================
# 8. Release Notes
# ==============================================================================
echo -e "${BLUE}Creating release notes...${NC}"

cat > "${RELEASE_DIR}/RELEASE_NOTES.md" << EOF
# DockerKit v${VERSION} Release Notes

## 🎉 What's New

- Initial release of DockerKit
- Docker compliance checking
- Template generation system
- Multiple output formats
- CI/CD integration support

## 📦 Installation

### Quick Install
\`\`\`bash
curl -fsSL https://github.com/phdsystems/dockerkit/releases/download/v${VERSION}/dockerkit-installer.sh | bash
\`\`\`

### Package Managers

#### Debian/Ubuntu
\`\`\`bash
wget https://github.com/phdsystems/dockerkit/releases/download/v${VERSION}/dockerkit_${VERSION}_amd64.deb
sudo dpkg -i dockerkit_${VERSION}_amd64.deb
\`\`\`

#### macOS (Homebrew)
\`\`\`bash
brew tap phdsystems/dockerkit
brew install dockerkit
\`\`\`

#### Docker
\`\`\`bash
docker pull phdsystems/dockerkit:${VERSION}
\`\`\`

## 📋 Checksums

See SHA256SUMS and MD5SUMS files for verification.

## 🐛 Bug Fixes

- N/A (Initial release)

## 📝 Documentation

Full documentation available at: https://github.com/phdsystems/dockerkit

## 🙏 Contributors

Thank you to all contributors who made this release possible!
EOF

echo -e "${GREEN}✓ Created release notes${NC}"

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo -e "${GREEN}${BOLD}Release v${VERSION} created successfully!${NC}"
echo ""
echo "Release contents:"
ls -lh "${RELEASE_DIR}/"
echo ""
echo "Next steps:"
echo "1. Test the packages"
echo "2. Update SHA256 in Homebrew formula"
echo "3. Create GitHub release and upload artifacts"
echo "4. Push Docker image to registry"
echo "5. Publish to npm registry"