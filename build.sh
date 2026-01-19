#!/bin/bash
set -e

# Create dist folder if it doesn't exist
mkdir -p dist

# Setup QEMU for cross-platform builds
echo "Setting up QEMU for cross-platform builds..."
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

#echo "=== Building AMD64 flatpak ==="
#echo "Building Docker image for AMD64..."
#docker buildx build --platform linux/amd64 -f Dockerfile.builder -t opencloud-builder-amd64 --load .

#echo "Removing old AMD64 container if exists..."
#docker rm -f flatpak-build-amd64 2>/dev/null || true

#echo "Running flatpak-builder in privileged container for AMD64..."
#docker run --platform linux/amd64 --privileged --name flatpak-build-amd64 opencloud-builder-amd64

#echo "Copying AMD64 flatpak bundle..."
#docker cp flatpak-build-amd64:/build/src/com.handtrixxx.OpenCloud.flatpak ./dist/com.handtrixxx.OpenCloud.x86_64.flatpak

#echo "Cleaning up AMD64 container..."
#docker rm flatpak-build-amd64

echo ""
echo "=== Building ARM64 flatpak ==="
echo "Note: ARM64 build requires native ARM64 hardware or will be very slow with emulation"
echo "Building Docker image for ARM64..."

docker buildx build --platform linux/arm64 -f Dockerfile.builder.arm64 -t opencloud-builder-arm64 --load .

echo "Removing old ARM64 container if exists..."
docker rm -f flatpak-build-arm64 2>/dev/null || true

echo "Running flatpak-builder in privileged container for ARM64..."
docker run --platform linux/arm64 --privileged --name flatpak-build-arm64 opencloud-builder-arm64

echo "Copying ARM64 flatpak bundle..."
docker cp flatpak-build-arm64:/build/src/com.handtrixxx.OpenCloud.flatpak ./dist/com.handtrixxx.OpenCloud.aarch64.flatpak

echo "Cleaning up ARM64 container..."
docker rm flatpak-build-arm64
rm -f Dockerfile.builder.arm64

echo ""
echo "=== Build complete! ==="
echo "Flatpak bundles created in dist/ folder:"
ls -lh dist/

#docker build -f Dockerfile.builder -t opencloud-builder .
#docker run --privileged --name flatpak-build opencloud-builder
#docker cp flatpak-build:/build/src/com.handtrixxx.OpenCloud.flatpak ./com.handtrixxx.OpenCloud.flatpak