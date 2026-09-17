# OpenCloud Desktop Flatpak Pipeline — Resume Notes

> Read this first in any new session. It captures the goal, verified facts, and
> exactly where to pick up. Continue from **"Gaps to fix"** → **"Next steps"**.
> Last updated: 2026-09-17

## Goal
A dynamic build pipeline that:
1. Clones upstream OpenCloud Desktop (`https://github.com/opencloud-eu/desktop.git`).
2. Extracts the version automatically (upstream = **4.0.1**; this repo still pins 4.0.0).
3. Builds Flatpak bundles for **both** `x86_64` (amd64) and `arm64`/`aarch64`.
4. Emits `dist/com.handtrixxx.OpenCloud_<VERSION>.<arch>.flatpak`.

Official OpenCloud only ships an amd64 AppImage; this repo adds arm64 + versioned bundles.

## Build model (current, works)
`build.sh` → `docker build` a Fedora image (`Dockerfile.builder`) → `docker run --privileged`
executes **flatpak-builder from source** inside the container, using the cloned upstream as a
`type: dir` source, then `flatpak build-bundle`. Runtime is `org.kde.Platform 6.10` (Qt6/KF6),
pulled from Flathub. Building from source is slow (Qt/KF6 + 5 dependency modules).

## Repo layout
- `build.sh` — host-arch detect, `$1` override (x86_64|arm64), docker build+run, `docker cp` → `dist/`. **Single-arch only; VERSION hardcoded.**
- `Dockerfile.builder` — `fedora:latest`; clones upstream at **HEAD** (no tag); copies manifest/icon/metainfo; runs flatpak-builder + build-bundle.
- `src/com.handtrixxx.OpenCloud.yml` — manifest; 5 from-source modules (libsecret, qtkeychain-qt5, libregraphapi, kdsingleapplication, opencloud); `command: opencloud`; post-install renames desktop file & fixes Exec/Icon.
- `src/com.handtrixxx.OpenCloud.metainfo.xml` — AppStream; `<release version="4.0.0">`.
- `src/favicon.svg` — app icon.
- `.smoke-test/` — smoke-test assets.

## Verified upstream facts (inspected at `/tmp/oc-inspect`, EPHEMERAL — re-clone if gone)
- **Version** lives in `VERSION.cmake` (NOT a single `VERSION` var):
  `MIRALL_VERSION_MAJOR=4`, `MIRALL_VERSION_MINOR=0`, `MIRALL_VERSION_PATCH=1` → **4.0.1**.
  Legacy `MIRALL_` prefix (not `OPENCLOUD_`). Root CMakeLists: `include(VERSION.cmake)` then
  `project(OpenCloudDesktop ... VERSION ${MAJOR}.${MINOR}.${PATCH})`.
  - **Extraction recipe:** shallow-clone → for each of MAJOR/MINOR/PATCH run
    `grep -E 'set\( *MIRALL_VERSION_<X>' VERSION.cmake | grep -oE '[0-9]+'` → compose `X.Y.Z`.
- **Binary name:** `OPENCLOUD.cmake` → `set( APPLICATION_EXECUTABLE "opencloud" )`
  (becomes `opencloud_beta` in beta). This confirms `command: opencloud` in the manifest is correct.
- **Desktop file:** `src/gui/CMakeLists.txt` does `configure_file(opencloud.desktop.in → ${APPLICATION_EXECUTABLE}.desktop)`,
  installed to `/app/share/applications/opencloud.desktop`; placeholders `@APPLICATION_EXECUTABLE@` etc.
  - There's also `opencloudcmd.desktop.in` (CLI companion) — the manifest's post-install deletes it.
  - Manifest post-install already: deletes `opencloud.desktop` + `opencloudcmd.desktop`, renames
    `com.handtrixxx.OpenCloud.metainfo.xml` → `.desktop`, strips KDE-only `%f`, sets `Exec=opencloud` + `Icon`.

## Gaps to fix (the actual work)
1. **Version detection** — `build.sh` hardcodes `VERSION="4.0.0"`. Replace with clone + parse `VERSION.cmake`.
2. **Two architectures** — `build.sh` builds one arch (host or `$1`) via plain `docker build`. To get both, either loop `x86_64` then `arm64`, or use `docker buildx` (multi-platform). Cross-arch (amd64→arm64) needs **binfmt/qemu** registered on the host.
3. **Broken metainfo sed** — `Dockerfile.builder` does `sed "s|<release version=\"3.0.3\"|...${APP_VERSION}\"|"`, but the file has `<release version="4.0.0">` → **no match, version never updates**. Template the version reliably (sed on the real `4.0.0`, or a placeholder).
4. **Reproducibility** — `Dockerfile.builder` clones upstream **HEAD** (no tag). Pin to the tag matching the detected version.
5. **Stale README** — still says version `3.0.3`; update, and document the two-arch build.

## Open questions (confirm before implementing)
- **Upstream tag naming:** `v4.0.1` vs `4.0.1`? → `git ls-remote --tags https://github.com/opencloud-eu/desktop.git | tail`.
- **Cross-arch on this host:** is `binfmt`/qemu available, or should arm64 build run on an arm64 runner?
- Keep flatpak-builder-from-source (current, recommended — handles Qt/KF6 deps) vs `cmake --install /app` direct.

## Next steps (ordered)
1. Confirm upstream tag naming (`git ls-remote --tags ...`).
2. `build.sh`: add dynamic version (shallow clone → parse `MIRALL_VERSION_*` → validate `^[0-9]+\.[0-9]+\.[0-9]+$`).
3. `build.sh` + `Dockerfile.builder`: build BOTH archs (per-arch loop or buildx); `docker cp` each bundle to `dist/..._<VER>.<arch>.flatpak`.
4. `Dockerfile.builder`: pin clone to tag; fix metainfo version templating (bug #3).
5. Smoke-test one arch (x86_64) first, then arm64.
6. Update `README.md`.

## Env / commands
- Workdir: `/home/handtrixxx/code/opencloud-eu-desktop-arm64`.
- Upstream inspection copy: `/tmp/oc-inspect` (re-clone: `git clone --depth 1 https://github.com/opencloud-eu/desktop.git /tmp/oc-inspect`).
- Docker daemon required; `docker run --privileged` needed for flatpak (rofiles); `--disable-rofiles-fuse` already set in the build script.
- Build is slow (from-source Qt/KF6) — budget time and expect long builds.
