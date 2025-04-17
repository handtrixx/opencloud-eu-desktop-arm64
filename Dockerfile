ARG BASE_IMAGE=fedora:latest
FROM ${BASE_IMAGE}

LABEL maintainer="niklas.stephan@gmail.com"
LABEL description="Dockerfile for building a Docker image that builds the opencloud desktop client"
LABEL usage="docker build -t opencloud-desktop-client ."
LABEL version="0.1"

# Install dependencies
RUN dnf update -y && \
    dnf install -y git cmake gcc-c++ boost-devel openssl-devel libcurl-devel jsoncpp-devel libxml2-devel sqlite-devel qt5-qtbase-devel qt5-qtsvg-devel qt5-linguist qt5-qtmultimedia-devel \
    qt5-qttools-devel qt5-qtwebengine-devel extra-cmake-modules\
    qt6-qtbase-devel qt6-qttools-devel qt6-qtwebengine-devel qt6-qtmultimedia-devel qtkeychain-qt6-devel && \
    dnf clean all

# install libregraphapi
WORKDIR /opencloud
RUN git clone https://github.com/opencloud-eu/libre-graph-api.git && \
    cd libre-graph-api && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make install

WORKDIR /opencloud
# Get the latest version of the opencloud client
RUN git clone https://github.com/opencloud-eu/desktop.git && \
    cd desktop && \
    mkdir build && \
    cd build && \
    cmake ..
    # cmake -DCMAKE_PREFIX_PATH=/usr/local/lib/cmake/LibreGraphAPI ..

ENTRYPOINT [ "tail", "-f", "/dev/null" ]