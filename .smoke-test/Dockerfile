FROM fedora:latest
ARG SM=yml
RUN dnf install -y flatpak flatpak-builder git jq && \
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
WORKDIR /build
COPY smoke.yml ./
RUN flatpak-builder --disable-rofiles-fuse --force-clean --install-deps-from=flathub --repo=repo builddir smoke.yml && \
    flatpak build-bundle repo out.flatpak com.handtrixxx.Smoke aarch64
RUN ls -lh /build/out.flatpak
