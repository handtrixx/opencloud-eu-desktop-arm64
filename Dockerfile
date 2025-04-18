ARG BASE_IMAGE=fedora:latest
FROM ${BASE_IMAGE}

LABEL maintainer="niklas.stephan@gmail.com"
LABEL description="Dockerfile for building a Docker image that builds the opencloud desktop client"
LABEL usage="docker build -t opencloud-desktop-client ."
LABEL version="0.1"

# Install dependencies
RUN dnf update -y && \
    dnf install -y git cmake gcc-c++ boost-devel openssl-devel libcurl-devel jsoncpp-devel libxml2-devel sqlite-devel qt5-qtbase-devel qt5-qtsvg-devel qt5-linguist qt5-qtmultimedia-devel \
    qt5-qttools-devel qt5-qtwebengine-devel extra-cmake-modules jq \
    qt6-qtbase-devel qt6-qttools-devel qt6-qtwebengine-devel qt6-qtmultimedia-devel qtkeychain-qt6-devel mvn && \
    dnf clean all

# install libregraphapi
WORKDIR /opencloud/openapitools
RUN curl https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/bin/utils/openapi-generator-cli.sh -o openapi-generator-cli.sh && \
    chmod +x openapi-generator-cli.sh
RUN ./openapi-generator-cli.sh generate -g cpp-qt-client -i https://raw.githubusercontent.com/OpenAPITools/openapi-generator/master/modules/openapi-generator/src/test/resources/3_0/petstore.yaml -o ./cpp
WORKDIR /opencloud/openapitools/cpp/client
RUN mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc)

#WORKDIR /opencloud
# Get the latest version of the opencloud client
#RUN git clone https://github.com/opencloud-eu/desktop.git && \
#    cd desktop && \
#    mkdir build && \
#    cd build && \
#    cmake -DCMAKE_MODULE_PATH=/opencloud/openapitools/cpp/client/build ..

ENTRYPOINT [ "/bin/bash" ]


#docker build -t opencloud-desktop-client .
#docker run -it -v ./bin:/output opencloud-desktop-client
#    LibreGraphAPIConfig.cmake
#libregraphapi-config.cmake