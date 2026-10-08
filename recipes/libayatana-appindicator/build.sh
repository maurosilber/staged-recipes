#!/bin/bash

set -euxo pipefail

export XDG_DATA_DIRS="${PREFIX}/share:${BUILD_PREFIX}/share:${XDG_DATA_DIRS:-/usr/share}"

# Mono bindings need a C# toolchain and gtk-sharp; gtk-doc is not packaged here.
cmake -S . -B build -GNinja \
    ${CMAKE_ARGS} \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DENABLE_TESTS=OFF \
    -DENABLE_GTKDOC=OFF \
    -DENABLE_BINDINGS_MONO=OFF \
    -DENABLE_BINDINGS_VALA=ON \
    -DFLAVOUR_GTK3=ON

cmake --build build --verbose
cmake --install build
