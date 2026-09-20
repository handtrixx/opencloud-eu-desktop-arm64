# OpenCloud Desktop Flatpak Pipeline — Resume Notes

> Read this first in any new session. It is the **living plan + verified facts +
> learnings** for this project, written so you don't have to re-derive anything.
> Continue from **"Next steps"**: items marked `[ ]` are not done yet.
> Last updated: 2026-09-20

## Goal
A reproducible, dual-architecture build pipeline that:
1. Clones upstream OpenCloud Desktop (`https://github.com/opencloud-eu/desktop.git`)
   **pinned to a release tag**.
2. Extracts the version **from the tag** (see "Version strategy" — DECIDED).
3. Builds Flatpak bundles for **both** `x86_64` (amd64) and `arm64`/`aarch64`.
4. Emits `dist/com.handtrixxx.OpenCloud_<VERSION>.<arch>.flatpak`.

Official OpenCloud only ships an amd64 AppImage; this repo adds arm64 + versioned bundles.

## Build model (current, works for the host arch)
`build.sh` → `docker build` a Fedora image (`Dockerfile.builder`) → `docker run --privileged`
executes **flatpak-builder from source** inside the container, using the cloned upstream as a
`type: dir` source, then `flatpak build-bundle`. Runtime is `org.kde.Platform 6.10` (Qt6/KF6),
pulled from Flathub. Building from source is slow (Qt/KF6 + 5 dependency modules).

## Version strategy (DECIDED — do not re-litigate)
- **Source of truth = the upstream release tag, NOT `VERSION.cmake` from HEAD.**
  - Rationale: at HEAD, `VERSION.cmake` reports the *next in-development* version
    (e.g. `4.0.1`) which has **no release tag**. Pinning to a real tag keeps the build
    reproducible and makes `VERSION` and the clone point always agree.
- **Tag format:** `v`-prefixed semver, e.g. `v4.0.0`. Prereleases use suffixes
  (`-rc.N`, `-beta.N`, `-alpha.N`) and are excluded from "stable".
- **Current stable tag: `v4.0.0` → version `4.0.0`** (matches the metainfo's
  `<release version="4.0.0" date="2026-09-03">` at line 57).
- **Detection recipe** (implemented in `build.sh` → `detect_upstream()`):
  ```
  git ls-remote --tags <repo> \
    | grep -v '\^{}' | awk -F/ '{print $3}' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1   # → v4.0.0
  ```
  then `VERSION="${TAG#v}"` → `4.0.0`.
- **`build.sh detect`** prints the detected tag + version and exits (no build).

## Repo layout
- `build.sh` — CLI: `detect` | `check` | `x86_64` | `arm64` | `both` | `--help`. Auto-detects version; per-arch `docker build --platform` → `docker run --platform --privileged`; `docker cp` → `dist/`. `both` builds x86_64 then arm64. Cross-arch arm64 needs host `qemu-user-static` (guarded by `require_qemu_if_cross`). `check` reports host build compatibility (git/docker/daemon/arch/network; `--strict` runs a minimal `--privileged` container).
- `Dockerfile.builder` — `fedora:latest`; clones upstream **pinned to `UPSTREAM_TAG`** (line 15); copies manifest/icon/metainfo; **fixes the metainfo `<release version>`** to `APP_VERSION` (line 24); generates `/build.sh` that runs `flatpak-builder` (`FLATPAK_ARCH=$(uname -m)`) + `build-bundle` (discovers the branch; `--runtime-repo` flathub). Built per-arch via `docker build --platform` → `docker run --platform --privileged`.
- `src/com.handtrixxx.OpenCloud.yml` — manifest; 5 from-source modules (libsecret, qtkeychain-qt5, libregraphapi, kdsingleapplication, opencloud); `command: opencloud`; post-install renames desktop file & fixes Exec/Icon.
- `src/com.handtrixxx.OpenCloud.metainfo.xml` — AppStream; `<release version="4.0.0" date="2026-09-03">` (line 57).
- `src/favicon.svg` — app icon.
- `.smoke-test/` — smoke-test assets.

## Verified upstream facts (re-clone to inspect: `git clone --depth 1 --branch v4.0.0 https://github.com/opencloud-eu/desktop.git /tmp/oc-v400`)
- **Version** lives in `VERSION.cmake` as `MIRALL_VERSION_{MAJOR,MINOR,PATCH}`
  (legacy `MIRALL_` prefix, NOT `OPENCLOUD_`). At **tag v4.0.0** = `4.0.0`; at **HEAD** = `4.0.1`.
  Root CMakeLists: `include(VERSION.cmake)` then `project(OpenCloudDesktop ... VERSION ${MAJOR}.${MINOR}.${PATCH})`.
- **Binary/executable name:** `opencloud` (from `OPENCLOUD.cmake` →
  `set( APPLICATION_EXECUTABLE "opencloud" )`; becomes `opencloud_beta` in beta).
  This confirms `command: opencloud` in the manifest is correct.
- **Desktop file:** `src/gui/CMakeLists.txt` does
  `configure_file(opencloud.desktop.in → ${APPLICATION_EXECUTABLE}.desktop)`, installed to
  `/app/share/applications/opencloud.desktop`; placeholders `@APPLICATION_EXECUTABLE@` etc.
  - There's also `opencloudcmd.desktop.in` (CLI companion) — the manifest's post-install deletes it.
  - Manifest post-install already: deletes `opencloud.desktop` + `opencloudcmd.desktop`, renames
    the metainfo to a `.desktop` file, strips KDE-only `%f`, sets `Exec=opencloud` + `Icon`.

## Host capabilities (this build host)
- Host arch: **x86_64**.
- **binfmt/qemu present:** `/proc/sys/fs/binfmt_misc/qemu-aarch64` exists → a cross-arch
  `docker run --platform linux/arm64` is *executable* here (QEMU user-mode).
- **BUT cross-arch from-source flatpak-builder is INFEASIBLE on this host (VERIFIED 2026-09-20).**
  QEMU *user-mode* does not implement `unshare(CLONE_NEWUSER)` (returns `EINVAL`), and
  `flatpak-builder` sandboxes every module build with `bwrap`, which NEEDS a user namespace.
  Proof: `docker run --platform linux/arm64 --privileged arm64v8/debian ... unshare --user`
  → `Creating new namespace failed: EINVAL`; the identical command on `linux/amd64` → OK.
  ⇒ **An aarch64 bundle must be built on a NATIVE aarch64 environment** (arm64 machine/CI,
  a full-system `qemu-system-aarch64` VM, or a cloud ARM instance). See "Learnings".

## Gaps to fix (the actual remaining work)
1. **Pin the clone to a tag** — `Dockerfile.builder` line 11 clones HEAD. Add
   `ARG UPSTREAM_TAG`, `git clone --branch "$UPSTREAM_TAG"`, and pass
   `--build-arg UPSTREAM_TAG=$UPSTREAM_TAG` from `build.sh`.
2. **Fix the broken metainfo sed** — `Dockerfile.builder` line 19 does
   `sed "s|<release version=\"3.0.3\"|...${APP_VERSION}\"|"` but the file has
   `<release version="4.0.0" date="2026-09-03">` → **no match, version never updates**.
   (The replacement also omits the `date` attribute.) Template on the real string or a placeholder.
3. **arm64 build** — BLOCKED on this x86_64 host: cross-arch from-source `flatpak-builder`
   needs user namespaces, which QEMU user-mode doesn't provide (verified `EINVAL`). Needs a
   NATIVE aarch64 environment (arm64 machine/CI, `qemu-system-aarch64` VM, or cloud ARM).
4. **Build BOTH archs** — loop x86_64 then arm64 in `build.sh`, emitting two bundles.
5. **Smoke-test** — x86_64 PASSED (bundle built + installed, `Version: 4.0.0`, 2026-09-20).
   arm64 BLOCKED (needs native aarch64 env; `require_qemu_if_cross` now fails fast instead of
   wasting ~30 min on the SDK download).
6. **README** — still describes single-arch; update once two-arch works.

## Next steps (ordered)
- [x] **Step 1** — Version detection from the latest stable tag in `build.sh`, incl. a `detect` command + `--help`. **(done, verified → v4.0.0 / 4.0.0)**
- [x] **Step 2** — `Dockerfile.builder`: accepts `UPSTREAM_TAG`, pins clone to tag (line 15), fixes the metainfo `<release version>` sed (line 24). **(done)**
- [~] **Step 3** — Cross-arch mechanism: **BOTH local paths ruled out on this host** (2026-09-20): `buildx` (buildkit RUN sandbox blocks user namespaces) AND `docker run --platform linux/arm64 --privileged` (QEMU user-mode lacks `unshare(CLONE_NEWUSER)` → `bwrap` dies at module 1). The arm64 leg needs a **native aarch64 environment** (arm64 machine/CI, `qemu-system-aarch64` VM, or cloud ARM). See Learnings.
- [x] **Step 4** — `build.sh`: per-arch `docker build --platform` + `docker run --platform --privileged`; `both` command builds x86_64 then arm64; `require_qemu_if_cross` guards the cross leg AND now **pre-flights `unshare --user` in a `linux/arm64` container, failing fast** with an actionable "needs native aarch64" message on hosts where QEMU user-mode can't do it. **(code done, verified 2026-09-20)**
- [~] **Step 5** — arm64 smoke-test: **BLOCKED on this host** (QEMU user-mode can't create the user namespaces `bwrap` needs — verified `EINVAL`; see Learnings). x86_64 leg PASSED (2026-09-20: bundle built + installed, `Version: 4.0.0`). To proceed, run `build.sh arm64` on a **native aarch64 environment** (arm64 CI/VM/cloud ARM); `require_qemu_if_cross` now fails fast here instead of wasting ~30 min.
- [ ] **Step 6** — Update README for two-arch (Gap #6).

## Learnings / pitfalls (don't re-derive)
- **`TARGETARCH` is a label, not a cross-compile.** In `Dockerfile.builder`, the generated
  `/build.sh` only maps `TARGETARCH → FLATPAK_ARCH` and passes it to `flatpak build-bundle`.
  flatpak-builder itself still builds for the container's native arch. A genuine aarch64
  bundle requires the **build container (base image + deps) to actually be aarch64**.
- **Multi-arch mechanism — VERIFIED state (2026-09-20):**
  - ❌ `docker buildx build --platform linux/arm64` — buildkit RUN-step sandbox blocks
    user-namespace creation (see next bullet). Ruled out.
  - ❌ `docker run --platform linux/arm64 --privileged` + QEMU user-mode — QEMU user-mode
    lacks `unshare(CLONE_NEWUSER)` (EINVAL), so `flatpak-builder`/`bwrap` dies at module 1.
    Ruled out (this host).
  - ✅ **Native aarch64 environment** — the ONLY viable path: an arm64 machine/CI runner
    [fastest], a full-system `qemu-system-aarch64` VM (docker+flatpak inside), or a cloud
    ARM instance (AWS Graviton / Azure / Alibaba-Cloud ARM VM). Then `build.sh arm64` runs
    the same proven `--privileged` path natively.
  - Whatever path: verify the output is truly aarch64, e.g. `flatpak info --show-metadata <bundle>`.
- **`buildx`/buildkit CANNOT run `flatpak-builder` (VERIFIED 2026-09-20).** buildkit runs
  every `RUN` step in a sandboxed, non-privileged container and **blocks user-namespace
  creation**: `unshare --user` fails inside a buildkit RUN step — on native x86_64 AND under
  `buildx build --platform linux/arm64`. `flatpak-builder` shells out to `bwrap` (bubblewrap),
  which MUST create a user namespace, so it fails with `bwrap: Creating new namespace failed:
  Operation not permitted`. There is NO supported buildkit flag to re-enable user namespaces
  for RUN steps. Therefore the arm64 leg uses **`docker run --platform linux/arm64 --privileged`**
  on the host (the same `--privileged` path x86_64 uses, which is NOT sandboxed), with the host
  `qemu-user-static` providing the aarch64 static binaries.
- **QEMU *user-mode* cross-build CANNOT run `flatpak-builder` (VERIFIED 2026-09-20).**
  The real blocker for the arm64 leg on an x86_64 host. QEMU *user-mode* (the `qemu-aarch64`
  binfmt emulator used by `docker run --platform linux/arm64`) does NOT implement
  `unshare(CLONE_NEWUSER)` — it returns `EINVAL`. `flatpak-builder` sandboxes every module
  build with `bwrap` (bubblewrap), which MUST create a user namespace, so the build dies at
  the FIRST module: `bwrap: Creating new namespace failed: Invalid argument`. Proof here:
  `docker run --platform linux/arm64 --privileged arm64v8/debian ... unshare --user` → EINVAL;
  identical on `linux/amd64` → OK (so the HOST kernel is fine — QEMU user-mode is what lacks
  the syscall). ⇒ cross-arch from-source builds on this host are infeasible; use a NATIVE
  aarch64 environment (see "Multi-arch mechanism"). `build.sh`'s `require_qemu_if_cross` now
  probes `unshare --user` in a `linux/arm64` container and fails fast with this explanation
  instead of letting the build burn ~30 min on the SDK download before dying at module 1.
- **`set -e` + piped `git ls-remote`:** a pipeline's exit status is that of the *last*
  command (`tail` = 0) even when `git`/network fails, so an empty result must be validated
  explicitly (done in `detect_upstream()`).
- **Metainfo sed bug** (Gap #2): search string `3.0.3` doesn't exist in the file.
- **Bundle ref = git branch, NOT the app version.** `flatpak-builder` exports the ref as
  `app/<id>/<arch>/<branch>` where `<branch>` defaults to **`master`** (it does NOT read the
  AppStream/metainfo version for ref naming). So `flatpak build-bundle ... <VERSION>` fails with
  **"No such app"** (e.g. `.../x86_64/4.0.0` doesn't exist). FIX (in `Dockerfile.builder`):
  discover the branch — `ls repo/refs/heads/app/<id>/<arch>` — and pass THAT to `build-bundle`.
- **`--runtime-repo` is mandatory for a standalone installable bundle.** A `.flatpak` bundle is
  **app-only by design** (~2.5MB is correct — it does NOT embed the runtime). Without
  `--runtime-repo <flathub-url>`, `flatpak install <bundle>` cannot resolve `org.kde.Platform`.
  We embed `https://dl.flathub.org/repo/flathub.flatpakrepo` so the runtime is auto-fetched.
- **x86_64 pipeline VERIFIED end-to-end (2026-09-20).** `./build.sh x86_64` →
  `dist/com.handtrixxx.OpenCloud_4.0.0.x86_64.flatpak`; `flatpak install` succeeds, app reports
  `Version: 4.0.0` / `Branch: master`, and `org.kde.Platform 6.10` + GL/VAAPI/codecs are pulled
  from the `flathub` remote. (Harmless noise: `bwrap: Creating new namespace failed` during
  post-install triggers — install still completes.)

## Env / commands
- Workdir: `/home/handtrixxx/code/opencloud-eu-desktop-arm64`.
- Preview version (no build): `./build.sh detect`.
- Host compatibility check (no build): `./build.sh check` (add `--strict` to prove a `--privileged` container can run).
- Help: `./build.sh --help`.
- List upstream stable tags: `git ls-remote --tags https://github.com/opencloud-eu/desktop.git | grep -E 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$'`.
- Re-clone for inspection: `git clone --depth 1 --branch v4.0.0 https://github.com/opencloud-eu/desktop.git /tmp/oc-v400`.
- Docker daemon required; `docker run --privileged` needed for flatpak (rofiles); `--disable-rofiles-fuse` already set.
- Build is slow (from-source Qt/KF6; arm64 slower under QEMU) — budget time.
