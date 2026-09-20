#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# OpenCloud Desktop — Flatpak build pipeline
#
#   * Detects the upstream version from the latest stable release tag.
#   * Builds a Flatpak bundle via docker + flatpak-builder (from source).
#   * `check` reports host build compatibility (missing components, daemon, arch).
#
# See AGENTS.md for the full design, verified facts, and learnings.
# ---------------------------------------------------------------------------

# --- Configuration ----------------------------------------------------------
UPSTREAM_REPO="https://github.com/opencloud-eu/desktop.git"
APP_ID="com.handtrixxx.OpenCloud"

# --- Usage ------------------------------------------------------------------
usage() {
    cat <<'EOF'
Usage: build.sh [COMMAND]

Commands:
  detect            Detect and print the current upstream version/tag, then exit
                    (no build is started). Useful to see what version a build
                    would use before committing to a long from-source build.
  check             Check the host for build compatibility and report any missing
                    build components (docker, daemon, git, arch, network, ...).
                    Add --strict to also run a minimal --privileged container.
  x86_64            Build only the x86_64 (amd64) Flatpak bundle.
  arm64             Build only the arm64 (aarch64) Flatpak bundle.
                    On an arm64 host this is a native build. On a non-arm64 host it is
                    NOT possible with QEMU user-mode emulation: flatpak-builder's
                    bubblewrap sandbox needs user namespaces, which QEMU user-mode does
                    not provide (unshare -> EINVAL). A native arm64 environment is
                    required -- see AGENTS.md 'Learnings' for options.
  both              Build BOTH x86_64 and arm64 bundles into dist/.
  -h, --help        Show this help.

With no command, builds for the host architecture.

Examples:
  ./build.sh detect          # print the upstream version that would be built
  ./build.sh check           # verify the host can build this Flatpak
  ./build.sh check --strict  # additionally prove 'docker run --privileged' works
  ./build.sh x86_64          # build only the x86_64 bundle
  ./build.sh arm64           # build only the arm64 bundle
  ./build.sh both            # build both archs -> dist/*.flatpak
EOF
}

# ---------------------------------------------------------------------------
# detect_upstream
#   Queries the upstream repository for its tags and selects the latest *stable*
#   release (vX.Y.Z, no prerelease suffix). Sets the globals UPSTREAM_TAG
#   (e.g. "v4.0.0") and VERSION (e.g. "4.0.0"). Exits the script on failure.
#
#   Why the tag, not VERSION.cmake from HEAD? At HEAD, VERSION.cmake reports the
#   next in-development version (e.g. 4.0.1) which has no release tag. Pinning
#   to a real tag keeps the build reproducible and makes VERSION and the clone
#   point always agree.
# ---------------------------------------------------------------------------
detect_upstream() {
    local tag version
    tag=$(git ls-remote --tags "$UPSTREAM_REPO" 2>/dev/null \
        | grep -v '\^{}' \
        | awk -F/ '{print $3}' \
        | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -V \
        | tail -1)
    version="${tag#v}"
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ERROR: could not determine a valid upstream version (got: '$tag')." >&2
        echo "       Check your network connection and retry." >&2
        exit 1
    fi
    UPSTREAM_TAG="$tag"
    VERSION="$version"
}

# --- Host compatibility check -----------------------------------------------
# Reports whether the host has everything needed to run this pipeline.
#
# NOTE: flatpak, flatpak-builder, cmake, ninja etc. are installed *inside* the
# Docker build image (Dockerfile.builder), so they are NOT host requirements and
# are intentionally not reported as missing here.
#
# Required (a MISS fails the check -> exit 1): git, docker, docker daemon, arch.
# Advisory (informational only): privileged support, cross-arch binfmt/qemu,
#   docker buildx, network reachability, disk space.

have() { command -v "$1" >/dev/null 2>&1; }
report_ok()    { printf '  [ OK  ] %-20s %s\n' "$1" "$2"; }
report_miss()  { printf '  [MISS] %-20s %s\n' "$1" "$2"; }
report_warn()  { printf '  [WARN] %-20s %s\n' "$1" "$2"; }
report_info()  { printf '  [info] %-20s %s\n' "$1" "$2"; }

# net_check <host>  ->  0 if <host>:443 is reachable (best-effort, ~6s cap)
net_check() {
    local host="$1"
    if command -v timeout >/dev/null 2>&1; then
        timeout 6 bash -c "exec 3<>/dev/tcp/$host/443" 2>/dev/null
    else
        (exec 3<>/dev/tcp/$host/443) 2>/dev/null
    fi
}

host_check() {
    local strict="${1:-0}"
    local hostarch="${HOST_ARCH:-$(uname -m)}"
    local failures=0
    local other_arch free_gb dk

    case "$hostarch" in
        x86_64)  other_arch="aarch64" ;;
        aarch64) other_arch="x86_64"  ;;
        *)       other_arch=""       ;;
    esac

    echo "=== Host compatibility check: OpenCloud Desktop Flatpak build ==="
    echo "(flatpak / flatpak-builder / cmake / ninja live in the Docker image, not the host)"
    echo

    # git (required — used for version detection)
    if have git; then
        report_ok "git" "$(git --version 2>/dev/null | head -1)"
    else
        report_miss "git" "not found (required for version detection)."
        echo "      fix: install git  (e.g. 'sudo dnf install git' / 'sudo apt-get install git')."
        failures=$((failures + 1))
    fi

    # docker (required — command, daemon, permissions)
    if have docker; then
        report_ok "docker" "$(docker --version 2>/dev/null)"
        if docker info >/dev/null 2>&1; then
            dk=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo unknown)
            report_ok "docker daemon" "server reachable (v$dk)"

            if [ "$strict" = "1" ]; then
                if docker run --privileged --rm \
                       docker.io/library/alpine:latest echo ok >/dev/null 2>&1; then
                    report_ok "privileged run" "verified (ran a minimal --privileged container)"
                else
                    report_warn "privileged run" "FAILED under --strict; the build needs 'docker run --privileged'."
                fi
            else
                report_info "privileged run" "build needs 'docker run --privileged' (run 'check --strict' to prove it)"
            fi

            if docker buildx version >/dev/null 2>&1; then
                report_ok "docker buildx" "available (needed only for the multi-arch path, Step 3)"
            else
                report_info "docker buildx" "not available (only needed for the multi-arch path)"
            fi
        else
            report_miss "docker daemon" "daemon not reachable (daemon down or missing permission?)."
            echo "      fix: 'sudo systemctl start docker'  OR  add your user to the 'docker' group."
            failures=$((failures + 1))
        fi
    else
        report_miss "docker" "not found (required)."
        echo "      fix: install the Docker Engine: https://docs.docker.com/engine/install/"
        failures=$((failures + 1))
    fi

    # host architecture (required)
    case "$hostarch" in
        x86_64|aarch64) report_ok "host architecture" "$hostarch (supported)" ;;
        *) report_miss "host architecture" "$hostarch (unsupported; need x86_64 or aarch64)"; failures=$((failures + 1)) ;;
    esac

    # cross-arch capability (advisory)
    if [ -n "$other_arch" ] && [ -f "/proc/sys/fs/binfmt_misc/qemu-$other_arch" ]; then
        report_ok "binfmt/qemu (cross)" "qemu-$other_arch registered (can build $other_arch on this host)"
    else
        report_info "binfmt/qemu (cross)" "cross-arch not available here (only native $hostarch builds)"
    fi

    # network (advisory)
    if net_check "github.com"; then
        report_ok "network: github" "reachable (version detection + upstream clone)"
    else
        report_warn "network: github" "not reachable now (needed for 'detect' and cloning)."
    fi
    if net_check "dl.flathub.org"; then
        report_ok "network: flathub" "reachable (build pulls org.kde.Platform from Flathub)"
    else
        report_warn "network: flathub" "not reachable now (needed to pull runtime/deps)."
    fi

    # disk space (advisory)
    free_gb=$(df -Pm . 2>/dev/null | awk 'NR==2 {print int($4/1024)}')
    if [ -n "$free_gb" ]; then
        if [ "$free_gb" -ge 15 ]; then
            report_ok "disk space" "${free_gb} GB free (>= 15 GB recommended)"
        else
            report_warn "disk space" "${free_gb} GB free — a from-source Qt/KF6 build may need ~15 GB."
        fi
    else
        report_info "disk space" "could not determine free space."
    fi

    echo
    if [ "$failures" -eq 0 ]; then
        echo "Result: OK — all required host components are present. Host is ready to build."
        return 0
    else
        echo "Result: FAIL — $failures required component(s) missing. Fix the [MISS] items, then re-run 'build.sh check'."
        return 1
    fi
}

# --- Parse the first argument (a command) -----------------------------------
case "${1:-}" in
    -h|--help|help)
        usage
        exit 0
        ;;
    detect|--detect)
        echo "Detecting latest stable upstream tag (queries GitHub, needs network)..."
        detect_upstream
        echo "Detected upstream tag : $UPSTREAM_TAG"
        echo "Detected version      : $VERSION"
        exit 0
        ;;
    check|--check|doctor|--doctor)
        strict=0
        if [ "${2:-}" = "--strict" ] || [ "${2:-}" = "-s" ]; then
            strict=1
        fi
        rc=0
        host_check "$strict" || rc=$?
        exit "$rc"
        ;;
esac

# --- Build helpers ------------------------------------------------------------
# Map an arch (uname -m or flatpak name) to its flatpak arch name.
flatpak_arch_of() {
    case "$1" in
        x86_64)         echo "x86_64" ;;
        aarch64|arm64)  echo "aarch64" ;;
        *)              echo "" ;;
    esac
}

# For a cross-arch build (target != host) the host must (a) be able to execute
# the target arch's binaries (a QEMU user-mode emulator + binfmt), AND (b) be
# able to create user namespaces UNDER that emulation (unshare CLONE_NEWUSER).
# (b) is the one people forget: flatpak-builder sandboxes EVERY module build
# with bubblewrap (bwrap), which must create a user namespace, and QEMU
# *user-mode* emulation does NOT implement that syscall (it returns EINVAL).
# A native build (target == host) needs neither. Aborts early with an
# actionable message if either requirement is unmet.
require_qemu_if_cross() {
    local target_flatpak="$1"
    local host_flatpak
    host_flatpak=$(flatpak_arch_of "$(uname -m)")
    if [ "$target_flatpak" = "$host_flatpak" ]; then
        return 0
    fi

    # (1) A QEMU user-mode emulator must exist so docker/binfmt can execute the
    #     target-arch binaries at all (static = preferred, dynamic = also OK).
    local qbin
    for qbin in "/usr/bin/qemu-${target_flatpak}-static" "/usr/bin/qemu-${target_flatpak}"; do
        if [ -x "$qbin" ]; then
            break
        fi
    done
    if [ -z "${qbin:-}" ]; then
        echo "ERROR: cross-arch build for ${target_flatpak} needs a QEMU user-mode emulator on the host." >&2
        echo "       (Neither /usr/bin/qemu-${target_flatpak}-static nor /usr/bin/qemu-${target_flatpak} was found.)" >&2
        echo "       Install one of these (needs sudo):" >&2
        echo "         sudo apt-get update && sudo apt-get install -y qemu-user-static binfmt-support   # preferred (static)" >&2
        echo "         sudo apt-get update && sudo apt-get install -y qemu-user binfmt-support           # dynamic" >&2
        return 1
    fi

    # (2) Fast pre-flight: user namespaces must actually work under the
    #     emulation. flatpak-builder's bwrap sandbox needs unshare(CLONE_NEWUSER);
    #     QEMU user-mode emulation returns EINVAL for it, so a foreign-arch
    #     from-source build is guaranteed to die at the FIRST module. Test it
    #     NOW -- before spending tens of minutes downloading the SDK + Qt/KF6
    #     deps -- and abort with an actionable message if it does not work.
    #     (Verified on this host: amd64 'unshare --user' works; aarch64 under
    #      QEMU user-mode -> 'Creating new namespace failed: EINVAL'.)
    local probe_img="arm64v8/debian:bookworm-slim"
    # Run the probe only if we can obtain the image; otherwise fail OPEN (we
    # cannot conclude user namespaces are broken -- let the real build surface
    # its own error). 'command -v unshare || exit 0' also fails open if the
    # image lacks unshare, so a flaky image never blocks the build.
    if docker image inspect "$probe_img" >/dev/null 2>&1 || docker pull "$probe_img" >/dev/null 2>&1; then
        if ! docker run --rm --platform "linux/${target_flatpak}" --privileged "$probe_img" sh -c 'command -v unshare >/dev/null 2>&1 || exit 0; unshare --user true' >/dev/null 2>&1; then
            echo "ERROR: cross-arch build for ${target_flatpak} cannot work on this host." >&2
            echo "       QEMU *user-mode* emulation (needed for a cross-arch 'docker run') does not" >&2
            echo "       support user namespaces: 'unshare --user' fails (EINVAL). flatpak-builder" >&2
            echo "       sandboxes every module build with bubblewrap (bwrap), which REQUIRES a user" >&2
            echo "       namespace, so a from-source build dies at the first module under emulation." >&2
            echo "       (Verified on this host: amd64 unshare works; aarch64 under QEMU -> EINVAL.)" >&2
            echo "" >&2
            echo "       Building an aarch64 bundle needs a NATIVE aarch64 environment, e.g.:" >&2
            echo "         - an arm64 machine or CI runner (fastest), or" >&2
            echo "         - a full-system arm64 VM (qemu-system-aarch64) with docker + flatpak, or" >&2
            echo "         - a cloud ARM instance (e.g. AWS Graviton / Azure Alibaba-Cloud ARM VM)." >&2
            echo "       See AGENTS.md 'Learnings' for the full diagnosis." >&2
            return 1
        fi
    fi
    return 0
}

# build_one <target_arch>   (target_arch: x86_64 | aarch64)
# Builds one arch: docker build (right base image) -> docker run --privileged
# (flatpak-builder from source) -> docker cp the bundle into dist/.
build_one() {
    local target="$1"
    local FLATPAK_ARCH DOCKER_PLATFORM IMG_TAG CTN OUT
    case "$target" in
        x86_64)         FLATPAK_ARCH="x86_64";  DOCKER_PLATFORM="linux/amd64" ;;
        aarch64|arm64)  FLATPAK_ARCH="aarch64"; DOCKER_PLATFORM="linux/arm64" ;;
        *)              echo "Unsupported target architecture: $target" >&2; return 1 ;;
    esac

    require_qemu_if_cross "$FLATPAK_ARCH" || return 1

    IMG_TAG="opencloud-builder-${FLATPAK_ARCH}"
    CTN="flatpak-build-${FLATPAK_ARCH}"
    OUT="./dist/com.handtrixxx.OpenCloud_${VERSION}.${FLATPAK_ARCH}.flatpak"

    echo ""
    echo "=== Building ${FLATPAK_ARCH} (docker platform ${DOCKER_PLATFORM}, version ${VERSION}) ==="
    echo "Building Docker image for ${FLATPAK_ARCH}..."
    docker build --platform "$DOCKER_PLATFORM" -f Dockerfile.builder \
        --build-arg APP_VERSION="$VERSION" --build-arg UPSTREAM_TAG="$UPSTREAM_TAG" \
        -t "$IMG_TAG" .

    echo "Removing old container if it exists..."
    docker rm -f "$CTN" 2>/dev/null || true

    echo "Running flatpak-builder in a privileged ${FLATPAK_ARCH} container (SLOW: from-source Qt/KF6)..."
    if ! docker run --platform "$DOCKER_PLATFORM" --privileged --name "$CTN" "$IMG_TAG"; then
        echo "ERROR: flatpak build failed for ${FLATPAK_ARCH}. Last container logs:" >&2
        docker logs --tail 80 "$CTN" 2>/dev/null || true
        docker rm -f "$CTN" 2>/dev/null || true
        return 1
    fi

    echo "Copying flatpak bundle..."
    docker cp "${CTN}:/build/src/com.handtrixxx.OpenCloud.flatpak" "$OUT"
    docker rm -f "$CTN"
    echo "=== ${FLATPAK_ARCH} done: $OUT ==="
    ls -lh "$OUT"
}

# --- Build ------------------------------------------------------------------
HOST_ARCH=$(uname -m)
echo "Host architecture: $HOST_ARCH"

# Detect the upstream version (needed for every build).
echo "Detecting latest stable upstream tag (queries GitHub, needs network)..."
detect_upstream
echo "Using upstream tag '$UPSTREAM_TAG' -> version $VERSION"

mkdir -p dist

case "${1:-}" in
    x86_64)
        build_one x86_64
        ;;
    arm64|aarch64)
        build_one aarch64
        ;;
    both|all)
        build_one x86_64
        build_one aarch64
        ;;
    "")
        # No build command: build for the host architecture.
        case "$(flatpak_arch_of "$HOST_ARCH")" in
            x86_64|aarch64) build_one "$(flatpak_arch_of "$HOST_ARCH")" ;;
            *) echo "Unsupported host architecture: $HOST_ARCH" >&2; exit 1 ;;
        esac
        ;;
    *)
        echo "Unknown command: ${1}" >&2
        echo "" >&2
        usage >&2
        exit 1
        ;;
esac

echo ""
echo "=== Build(s) complete! ==="
ls -lh dist/*.flatpak 2>/dev/null || true