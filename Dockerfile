ARG BASE_IMAGE=fedora:latest
FROM ${BASE_IMAGE}

LABEL maintainer="niklas.stephan@gmail.com"
LABEL description="Dockerfile for building the opencloud desktop client"
LABEL usage="docker build -t opencloud-desktop-client ."
LABEL version="0.1"

# Install dependencies
RUN dnf update -y && \
    dnf install -y git cmake gcc-c++ boost-devel openssl-devel libcurl-devel jsoncpp-devel libxml2-devel sqlite-devel qt5-qtbase-devel qt5-qtsvg-devel qt5-linguist qt5-qtmultimedia-devel \
    qt5-qttools-devel qt5-qtwebengine-devel extra-cmake-modules jq kdsingleapplication-qt6-devel patchelf \
    qt6-qtbase-devel qt6-qttools-devel qt6-qtwebengine-devel qt6-qtmultimedia-devel qtkeychain-qt6-devel mvn && \
    dnf clean all

# install libregraphapi
WORKDIR /apiclient
COPY ./src/cpp .
WORKDIR /apiclient/client/build
RUN cmake .. &&  \
    make -j$(nproc) && \
    make install

WORKDIR /opencloud
# Get the latest version of the opencloud client
RUN git clone https://github.com/opencloud-eu/desktop.git && \
    cd desktop && \
    mkdir build && \
    cd build && \
    cmake -DLibreGraphAPI_DIR=/apiclient/cpp/client/build .. && \
    make -j$(nproc) && \
    make install
# Install AppImage tools
RUN curl -Lo /usr/local/bin/appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-aarch64.AppImage && \
    chmod +x /usr/local/bin/appimagetool
    ## && \
   # curl -Lo /usr/local/bin/linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20250213-2/linuxdeploy-aarch64.AppImage && \
  #  chmod +x /usr/local/bin/linuxdeploy
# Install AppImage tools
# Install linuxdeploy by extracting the AppImage
RUN curl -Lo /tmp/linuxdeploy-aarch64.AppImage https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20250213-2/linuxdeploy-aarch64.AppImage && \
    chmod +x /tmp/linuxdeploy-aarch64.AppImage && \
    /tmp/linuxdeploy-aarch64.AppImage --appimage-extract && \
    mv squashfs-root/usr/bin/linuxdeploy /usr/local/bin/linuxdeploy && \
    rm -rf /tmp/linuxdeploy-aarch64.AppImage squashfs-root

COPY ./src/icons /opencloud/desktop/build/icons
COPY ./src/opencloud.desktop /opencloud/desktop/opencloud.desktop
# Prepare AppDir structure
# Prepare AppDir structure
RUN mkdir -p /AppDir/usr/bin && \
    mkdir -p /AppDir/usr/share/applications && \
    mkdir -p /AppDir/usr/share/icons/hicolor/256x256/apps && \
    cp -R /opencloud/desktop/build/bin/* /AppDir/usr/bin/ && \
    cp /opencloud/desktop/opencloud.desktop /AppDir/usr/share/applications/opencloud.desktop && \
    cp /opencloud/desktop/build/icons/256-opencloud-icon.png /AppDir/usr/share/icons/hicolor/256x256/apps/256-opencloud-icon.png

#ENV LD_PRELOAD=""
ENV NO_FUSE=1
RUN /usr/local/bin/linuxdeploy --appdir /AppDir --output appimage
#RUN /usr/local/bin/appimagetool /AppDir /output/OpenCloud-Desktop-Client-x86_64.AppImage
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /output
ENTRYPOINT [ "/entrypoint.sh" ]


#docker build -t opencloud-desktop-client .
#docker run -it -v ./bin:/output opencloud-desktop-client
#    LibreGraphAPIConfig.cmake
#libregraphapi-config.cmake
