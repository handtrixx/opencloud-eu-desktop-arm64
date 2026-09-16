#!/bin/bash
set -e

# Create dist folder if it doesn't exist
mkdir -p dist


# Detect host architecture
HOST_ARCH=$(uname -m)
case $HOST_ARCH in
  x86_64)
    echo "Host architecture is AMD64/x86_64"
    ;;
  aarch64|arm64)
    echo "Host architecture is ARM64/aarch64"
    ;;
  *)
    echo "Unsupported host architecture: $HOST_ARCH"
    exit 1
    ;;
esac

# Set target architecture - default to host architecture, but allow override
if [ -n "$1" ]; then
    TARGET_ARCH=$1
    echo "Target architecture overridden to: $TARGET_ARCH"
else
    TARGET_ARCH=$HOST_ARCH
    echo "Building for host architecture: $TARGET_ARCH"
fi

case $TARGET_ARCH in
  x86_64)
    FLATPAK_ARCH="x86_64"
    DOCKER_TARGETARCH="amd64"
    echo "Building for AMD64/x86_64 architecture"
    ;;
  aarch64|arm64)
    FLATPAK_ARCH="aarch64"
    DOCKER_TARGETARCH="arm64"
    echo "Building for ARM64/aarch64 architecture"
    ;;
  *)
    echo "Unsupported target architecture: $TARGET_ARCH"
    exit 1
    ;;
esac

# For now, we'll use a fixed version as the automatic detection requires
# complex logic to determine upstream version without cloning source first
echo "Using fixed version 4.0.0 (this will be updated when upstream version is detected)"
VERSION="4.0.0"

echo "Building Docker image with version $VERSION and target architecture $DOCKER_TARGETARCH..."
docker build -f Dockerfile.builder --build-arg APP_VERSION=$VERSION --build-arg TARGETARCH=$DOCKER_TARGETARCH -t opencloud-builder .

echo "Removing old container if exists..."
docker rm -f flatpak-build 2>/dev/null || true

echo "Running flatpak-builder in privileged container..."
docker run --privileged --name flatpak-build opencloud-builder

echo "Copying flatpak bundle..."
docker cp flatpak-build:/build/src/com.handtrixxx.OpenCloud.flatpak ./dist/com.handtrixxx.OpenCloud_${VERSION}.${FLATPAK_ARCH}.flatpak

echo "Cleaning up container..."
docker rm flatpak-build

echo ""
echo "=== Build complete! ==="
echo "Flatpak bundle created:"
ls -lh dist/com.handtrixxx.OpenCloud_${VERSION}.${FLATPAK_ARCH}.flatpak