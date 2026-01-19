#!/bin/bash
set -e

# Create dist folder if it doesn't exist
mkdir -p dist


# Detect host architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64)
    FLATPAK_ARCH="x86_64"
    echo "Building for AMD64/x86_64 architecture"
    ;;
  aarch64|arm64)
    FLATPAK_ARCH="aarch64"
    echo "Building for ARM64/aarch64 architecture"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "Building Docker image..."
docker build -f Dockerfile.builder -t opencloud-builder .

echo "Removing old container if exists..."
docker rm -f flatpak-build 2>/dev/null || true

echo "Running flatpak-builder in privileged container..."
docker run --privileged --name flatpak-build opencloud-builder

echo "Copying flatpak bundle..."
docker cp flatpak-build:/build/src/com.handtrixxx.OpenCloud.flatpak ./dist/com.handtrixxx.OpenCloud.${FLATPAK_ARCH}.flatpak

echo "Cleaning up container..."
docker rm flatpak-build

echo ""
echo "=== Build complete! ==="
echo "Flatpak bundle created:"
ls -lh dist/com.handtrixxx.OpenCloud.${FLATPAK_ARCH}.flatpak