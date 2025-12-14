# `OpenCloud Desktop for ARM64`

> ⚠️ **Warning**: This Fork currently isn't finished yet.

## Introduction

`OpenCloud Desktop` is a tool to synchronize files from `OpenCloud`
with your computer.
This project is about to provide it also for the arm64 architecture, since the official Linux release is just an AppImage for amd64.

## Compile OpenCloud Package from source

If you follow these instructions you will compile the current version of the OpenCloud Desktop client for your system (and for its architecture).

### Prerequisites

#### Debian based
```bash
sudo apt-get install -y cmake build-essential qt6-base-dev qt6-tools-dev qt6-tools-dev-tools qt6-declarative-dev qt6-tools-dev qt6-tools-dev-tools zlib1g-dev extra-cmake-modules libsqlite3-dev qtkeychain-qt6-dev libkdsingleapplication-qt6-dev libre-graph-api-cpp-qt-client
```

### Build

```bash
git clone https://github.com/opencloud-eu/desktop.git
cd desktop && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
sudo make install
```

The outpout in folder ```bin``` contains the executable ```opencloud``` compiled for your system.

## Flatpak Local Build

install flatpak builder and be sure you have added the flathub remote
```bash
sudo apt-get install -y flatpak-builder
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```


Download the latest source file to get the sha256 checksum
```yml
wget -O - https://github.com/opencloud-eu/desktop/archive/refs/tags/v3.0.3.tar.gz | sha256sum
```

create a .yml repo file "org.flatpak.OpenCloud.yml"

Build the application using Flatpak builder
```bash
flatpak-builder --force-clean --user --install-deps-from=flathub --repo=repo --install builddir org.flatpak.OpenCloud.yml
``` 

we could already run the application now:
```bash
flatpak run org.flatpak.OpenCloud
``` 

Create .flatpak bundle file
```bash
flatpak build-bundle repo OpenCloud.flatpak org.flatpak.OpenCloud --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo
```

Install the final app:
```bash
flatpak install --user OpenCloud.flatpak
```

Uninstall the final app:
```bash
flatpak remove org.flatpak.OpenCloud
```

## Flathub

Install the flathub builder
```bash
flatpak install -y flathub org.flatpak.Builder
```

Add flathub remote repo
```bash
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

Build manifest
```bash
flatpak run --command=flathub-build org.flatpak.Builder --install org.flatpak.OpenCloud.yml
```

Run and test
```bash
flatpak run org.flatpak.OpenCloud
```