ARG BASE_IMAGE=arm64v8/fedora:latest
FROM ${BASE_IMAGE}

LABEL maintainer="niklas.stephan@gmail.com"
LABEL description="Dockerfile for building the opencloud desktop client"
LABEL usage="docker build -t opencloud-desktop-client ."
LABEL version="0.1"

# Install dependencies
RUN dnf update -y && \
    dnf install -y git cmake gcc-c++ boost-devel openssl-devel libcurl-devel jsoncpp-devel libxml2-devel sqlite-devel qt5-qtbase-devel qt5-qtsvg-devel qt5-linguist qt5-qtmultimedia-devel \
    qt5-qttools-devel qt5-qtwebengine-devel extra-cmake-modules jq kdsingleapplication-qt6-devel patchelf \
    qt6-qtbase-devel qt6-qttools-devel qt6-qtwebengine-devel qt6-qtmultimedia-devel qtkeychain-qt6-devel mvn rpm-build && \
    dnf clean all

# install libregraphapi
WORKDIR /apiclient
COPY ./src/cpp .
WORKDIR /apiclient/client/build
RUN cmake .. && \
    make -j$(nproc) && \
    make install

WORKDIR /opencloud
RUN git clone https://github.com/opencloud-eu/desktop.git

WORKDIR /opencloud/desktop
# Add content of cpack.text to CMakeLists.txt

RUN echo 'set(CPACK_PACKAGE_NAME "opencloud")' >> CMakeLists.txt && \
    echo 'set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")' >> CMakeLists.txt && \
    echo 'set(BUILD_SHARED_LIBS OFF)' >> CMakeLists.txt && \
    echo 'set(CPACK_PACKAGE_VERSION "1.0.0")' >> CMakeLists.txt && \
    echo 'set(CPACK_PACKAGE_RELEASE "1")' >> CMakeLists.txt && \
    echo 'set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "OpenCloud Desktop Client")' >> CMakeLists.txt && \
    echo 'set(CPACK_PACKAGE_VENDOR "YourName")' >> CMakeLists.txt && \
    echo 'set(CPACK_PACKAGE_LICENSE "Your License")' >> CMakeLists.txt && \
    echo 'set(CPACK_PACKAGE_URL "http://yourappwebsite.com")' >> CMakeLists.txt && \
    echo 'set(CPACK_RPM_PACKAGE_GROUP "Applications/YourAppGroup")' >> CMakeLists.txt && \
    echo 'set(CPACK_RPM_PACKAGE_REQUIRES "qt6-qtbase >= 6.0, qt6-qttools >= 6.0, libcurl >= 7.0")' >> CMakeLists.txt && \
    echo 'set(CPACK_RPM_PACKAGE_AUTOREQPROV ON)' >> CMakeLists.txt && \
    echo 'include(CPack)' >> CMakeLists.txt

RUN mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DLibreGraphAPI_DIR=/apiclient/cpp/client/build .. && \
    make -j$(nproc) && \
    make install

# create rpm file
WORKDIR /opencloud/desktop/build
RUN cpack -G RPM
# Install AppImage tools
RUN curl -Lo /usr/local/bin/appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-aarch64.AppImage && \
    chmod +x /usr/local/bin/appimagetool
# Install AppImage tools
RUN curl -Lo /tmp/linuxdeploy-aarch64.AppImage https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-aarch64.AppImage && \
    chmod +x /tmp/linuxdeploy-aarch64.AppImage && \
    /tmp/linuxdeploy-aarch64.AppImage --appimage-extract && \
    mv squashfs-root/usr/bin/linuxdeploy /usr/local/bin/linuxdeploy && \
    rm -rf /tmp/linuxdeploy-aarch64.AppImage squashfs-root

COPY ./src/icons /opencloud/desktop/build/icons
RUN echo '[Desktop Entry]' > /opencloud/desktop/opencloud.desktop && \
    echo 'Name=OpenCloud Desktop Client' >> /opencloud/desktop/opencloud.desktop && \
    echo 'Exec=opencloud' >> /opencloud/desktop/opencloud.desktop && \
    echo 'Icon=256-opencloud-icon' >> /opencloud/desktop/opencloud.desktop && \
    echo 'Type=Application' >> /opencloud/desktop/opencloud.desktop && \
    echo 'Categories=Utility;' >> /opencloud/desktop/opencloud.desktop

# Prepare AppDir structure
RUN mkdir -p /AppDir/usr/bin && \
    mkdir -p /AppDir/usr/share/applications && \
    mkdir -p /AppDir/usr/share/icons/hicolor/256x256/apps && \
    cp -R /opencloud/desktop/build/bin/* /AppDir/usr/bin/ && \
    cp /opencloud/desktop/opencloud.desktop /AppDir/usr/share/applications/opencloud.desktop && \
    cp /opencloud/desktop/build/icons/256-opencloud-icon.png /AppDir/usr/share/icons/hicolor/256x256/apps/256-opencloud-icon.png

#ENV LD_PRELOAD=""
ENV NO_FUSE=1
#RUN /usr/local/bin/linuxdeploy --appdir /AppDir --output appimage
#RUN /usr/local/bin/appimagetool --appimage-extract-and-run /AppDir /output/OpenCloud-Desktop-Client-aarch64.AppImage
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /output
ENTRYPOINT [ "/entrypoint.sh" ]