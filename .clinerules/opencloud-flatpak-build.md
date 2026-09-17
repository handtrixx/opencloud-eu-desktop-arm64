# Project: OpenCloud Desktop Flatpak build pipeline

Before doing any work here, read `AGENTS.md` at the repo root — it is the living plan
plus verified learnings for this project. Pick up from its **"Gaps to fix"** and
**"Next steps"** sections.

Do not re-derive facts already verified there. In short:
- OpenCloud version lives in upstream `VERSION.cmake` as `MIRALL_VERSION_{MAJOR,MINOR,PATCH}`
  (legacy `MIRALL_` prefix), currently **4.0.1**.
- The binary/executable name is `opencloud` (from upstream `OPENCLOUD.cmake` →
  `APPLICATION_EXECUTABLE`); the manifest `command: opencloud` is already correct.
- Build model: `build.sh` → `Dockerfile.builder` → flatpak-builder **from source** on
  `org.kde.Platform 6.10`; slow. Main work left is dynamic version + building BOTH archs.
