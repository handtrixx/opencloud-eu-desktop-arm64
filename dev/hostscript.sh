sudo dnf install rpm-build

cd /home/handtrixxx/webdev/builder

git clone https://github.com/opencloud-eu/libre-graph-api

cd libre-graph-api

docker run --rm -v "${PWD}:/local" openapitools/openapi-generator-cli generate --enable-post-process-file  -t local/templates/cpp-qt-client -i local/api/openapi-spec/v1.0.yaml -g cpp-qt-client -o /local/out/cpp

sudo chown -R handtrixxx: out

cd out/cpp/client

mkdir build

cd build

cmake ..

make -j$(nproc)

sudo make install

cd /home/handtrixxx/webdev/builder

git clone https://github.com/opencloud-eu/desktop.git

cd desktop

echo 'set(CPACK_PACKAGE_NAME "opencloud")' >> CMakeLists.txt && \
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
echo 'set(CPACK_PACKAGE_CONTACT "MyName")' >> CMakeLists.txt && \
echo 'include(CPack)' >> CMakeLists.txt

mkdir build

cd build

cmake -DCMAKE_BUILD_TYPE=Release -DLibreGraphAPI_DIR=/usr/local/lib64/cmake/LibreGraphAPI/ .. 

make -j$(nproc)

sudo make install

sudo cpack -G RPM

cd /home/handtrixxx/webdev/builder

curl -Lo ./linuxdeploy-aarch64.AppImage https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-aarch64.AppImage

chmod +x linuxdeploy-aarch64.AppImage

echo '[Desktop Entry]' > ./opencloud.desktop && \
echo 'Name=OpenCloud Desktop Client' >> ./opencloud.desktop && \
echo 'Exec=opencloud' >> ./opencloud.desktop && \
echo 'Icon=opencloud-icon' >> ./opencloud.desktop && \
echo 'Type=Application' >> ./opencloud.desktop && \
echo 'Categories=Utility;' >> ./opencloud.desktop

./linuxdeploy-aarch64.AppImage --appdir AppDir --executable ./desktop/build/bin/opencloud --desktop-file ./opencloud.desktop --icon-file ./desktop/src/resources/theme/universal/opencloud-icon.svg

cp ./opencloud.desktop ./AppDir/usr/share/applications/opencloud.desktop
cp ./desktop/src/resources/theme/universal/opencloud-icon.svg ./AppDir/usr/share/icons/hicolor/scalable/apps/opencloud-icon.svg

cd /home/handtrixxx/webdev/builder

curl -Lo ./appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-aarch64.AppImage

chmod +x appimagetool

./appimagetool ./AppDir opencloud-arch64.AppImage 