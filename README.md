# `OpenCloud Desktop Flatpaks for ARM64 and AMD64`

Easy and transparent provision of flatpaks made from the official OpenCloud Desktop sources for installation on Linux Operating Systems.

## Introduction

`OpenCloud Desktop` is a tool to synchronize files from `OpenCloud` with your computer.
This project is about to provide flatpaks for the arm64 and amd64 architectures, since the official Linux release is just an AppImage for amd64.

## Quickstart

### Download
For arm64 (Rapsi, Server, etc.) download: <a href="#">OpenCloud Desktop for arm64</a>

For amd64 ("classic" PCs with Intel or AMD CPUs) download: <a href="#">OpenCloud Desktop for amd64</a>

### Install

**Note:** Requires Flathub to be configured. If you haven't already, add it with:

```bash
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

Then install OpenCloud Desktop:

For amd64:

```bash
flatpak install --user com.handtrixxx.OpenCloud.x86_64.flatpak
```

For arm64
```bash
flatpak install --user com.handtrixxx.OpenCloud.arm64.flatpak
```

*if that fails with error "Fehler: The application com.handtrixxx.OpenCloud/x86_64/master requires the runtime org.kde.Platform/x86_64/6.10 which was not found", run:
```bash
flatpak install --user flathub org.kde.Platform//6.10
```
and try again.


### Done

You can find the OpenCloud Desktop app installed as any other Flatpak on your system, now. Have Fun!


## Build on your own

If you prefer to build the flatpaks on your own, you can do so as well. Be prepared the whole procedure can take a while, mostly depending on the speed of the host you are using.

### Prequisites

Only prerequisite is that you have installed the docker engine as described on the <a href="https://docs.docker.com/engine/install/" target="_blank">Docker Websites</a>.

### Clone Project

```bash
git clone
```

### Execute build script

```bash
./build.sh
```

## ToDos

While the build process already always will grab the newest release of the OpenCloud Desktop resources, the other dependencies are currently on hardcoded versions. In future they also should always point to the newest available versions.

Also the *.flatpak output files should contain the version number, since OpenCloud Desktop has no auto-update functionality.

Actually I planned to distribute the flatpaks via Flathub, but the code reviewer assigned to my request was not really as helpfull as he should be according to their guidelines and had only very limited social skills as well. 
Asking for support at Heinlein also didn't result in any response. 
So for the moment this GitHub repository stays the only community contribution regarding packaging for the moment.

## License

These app  builds are based on "The OpenCloud Desktop application", originally developed by the OpenCloud community.
Source code available at: https://github.com/opencloud-eu/desktop .
Licensed under GPLv2.
