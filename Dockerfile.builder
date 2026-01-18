FROM fedora:latest

RUN dnf install -y flatpak flatpak-builder git && \
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

WORKDIR /build

RUN git clone https://github.com/opencloud-eu/desktop.git

WORKDIR /build/src

COPY ./src/com.handtrixxx.OpenCloud.yml .
COPY ./src/favicon.svg .
COPY ./src/com.handtrixxx.OpenCloud.metainfo.xml .

# Create build script with proper format
RUN printf '#!/bin/bash\nset -e\nflatpak-builder --disable-rofiles-fuse --force-clean --install-deps-from=flathub --repo=repo builddir com.handtrixxx.OpenCloud.yml\nflatpak build-bundle repo com.handtrixxx.OpenCloud.flatpak com.handtrixxx.OpenCloud\n' > /build.sh && chmod +x /build.sh

CMD ["/bin/bash", "/build.sh"]