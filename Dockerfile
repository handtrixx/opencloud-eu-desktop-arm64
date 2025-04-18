ARG BASE_IMAGE=fedora:latest
FROM ${BASE_IMAGE}

LABEL maintainer="niklas.stephan@gmail.com"
LABEL description="Dockerfile for building the opencloud desktop client"
LABEL usage="docker build -t opencloud-desktop-client ."
LABEL version="0.1"

# Install dependencies
RUN dnf update -y && \
    dnf install -y git cmake gcc-c++ boost-devel openssl-devel libcurl-devel jsoncpp-devel libxml2-devel sqlite-devel qt5-qtbase-devel qt5-qtsvg-devel qt5-linguist qt5-qtmultimedia-devel \
    qt5-qttools-devel qt5-qtwebengine-devel extra-cmake-modules jq kdsingleapplication-qt6-devel\
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
RUN curl -Lo /usr/local/bin/appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage && \
    chmod +x /usr/local/bin/appimagetool && \
    curl -Lo /usr/local/bin/linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage && \
    chmod +x /usr/local/bin/linuxdeploy

# Prepare AppDir structure
RUN mkdir -p /AppDir/usr/bin && \
    mkdir -p /AppDir/usr/share/applications && \
    mkdir -p /AppDir/usr/share/icons/hicolor/256x256/apps && \
    cp /opencloud/desktop/build/bin/* /AppDir/usr/bin/ && \
    echo "[Desktop Entry]\nName=OpenCloud Desktop Client\nExec=opencloud-desktop\nIcon=opencloud\nType=Application\nCategories=Utility;" > /AppDir/usr/share/applications/opencloud.desktop && \
    cp /path/to/icon.png /AppDir/usr/share/icons/hicolor/256x256/apps/opencloud.png

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /output
ENTRYPOINT [ "/entrypoint.sh" ]


#docker build -t opencloud-desktop-client .
#docker run -it -v ./bin:/output opencloud-desktop-client
#    LibreGraphAPIConfig.cmake
#libregraphapi-config.cmake
