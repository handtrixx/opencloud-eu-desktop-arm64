FROM fedora:latest

ARG APP_VERSION=4.0.0
ARG UPSTREAM_TAG=v4.0.0
# Expose the version to the runtime container (docker run) as well, so the
# generated /build.sh can reference it when creating the bundle.
ENV APP_VERSION=${APP_VERSION}

RUN dnf install -y flatpak flatpak-builder bubblewrap git && \
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

WORKDIR /build

# Pin the clone to the exact release tag (reproducible build; agrees with APP_VERSION).
RUN git clone --depth 1 --branch "${UPSTREAM_TAG}" https://github.com/opencloud-eu/desktop.git
WORKDIR /build/src

COPY ./src/com.handtrixxx.OpenCloud.yml .
COPY ./src/favicon.svg .
COPY ./src/com.handtrixxx.OpenCloud.metainfo.xml .

# Update metainfo.xml so its <release version="..."> matches the built version
# (rewrites whatever version is currently on the first <release> line).
RUN sed -i "s/\(<release version=\"\)[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/\1${APP_VERSION}/" com.handtrixxx.OpenCloud.metainfo.xml

# Create the runtime build script. The single-quoted printf keeps $APP_VERSION,
# $(uname -m) and $FLATPAK_ARCH literal so they expand at RUNTIME (the container's
# real arch is the target arch for both native and QEMU/cross builds).
RUN printf '#!/bin/bash\nset -e\nFLATPAK_ARCH=$(uname -m)\necho "Building OpenCloud Flatpak for $FLATPAK_ARCH (version $APP_VERSION)..."\nflatpak-builder --disable-rofiles-fuse --force-clean --install-deps-from=flathub --repo=repo builddir com.handtrixxx.OpenCloud.yml\nBRANCH="$(ls "repo/refs/heads/app/com.handtrixxx.OpenCloud/$FLATPAK_ARCH" | head -n1)"\nflatpak build-bundle --runtime-repo https://dl.flathub.org/repo/flathub.flatpakrepo repo com.handtrixxx.OpenCloud.flatpak com.handtrixxx.OpenCloud "$BRANCH"\n' > /build.sh && chmod +x /build.sh

CMD ["/bin/bash", "/build.sh"]