FROM fedora:latest

ARG APP_VERSION=4.0.0
ARG TARGETARCH=amd64

RUN dnf install -y flatpak flatpak-builder git && \
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

WORKDIR /build

RUN git clone https://github.com/opencloud-eu/desktop.git
WORKDIR /build/src

COPY ./src/com.handtrixxx.OpenCloud.yml .
COPY ./src/favicon.svg .
COPY ./src/com.handtrixxx.OpenCloud.metainfo.xml .

# Update metainfo.xml with the detected version
RUN sed -i "s|<release version=\"3.0.3\"|<release version=\"${APP_VERSION}\"|" com.handtrixxx.OpenCloud.metainfo.xml

# Create build script with proper format
RUN printf '#!/bin/bash\nset -e\n\n# Determine target architecture\nif [ "$TARGETARCH" = "amd64" ]; then\n  FLATPAK_ARCH="x86_64"\nelse\n  FLATPAK_ARCH="aarch64"\nfi\n\necho "Building for architecture: $FLATPAK_ARCH"\n\nflatpak-builder --disable-rofiles-fuse --force-clean --install-deps-from=flathub --repo=repo builddir com.handtrixxx.OpenCloud.yml\nflatpak build-bundle repo com.handtrixxx.OpenCloud.flatpak com.handtrixxx.OpenCloud $FLATPAK_ARCH\n' > /build.sh && chmod +x /build.sh

CMD ["/bin/bash", "/build.sh"]