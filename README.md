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
sudo apt-get install -y cmake build-essential qt6-base-dev qt6-tools-dev qt6-tools-dev-tools qt6-declarative-dev qt6-tools-dev qt6-tools-dev-tools zlib1g-dev extra-cmake-modules libsqlite3-dev qtkeychain-qt6-dev libkdsingleapplication-qt6-dev
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