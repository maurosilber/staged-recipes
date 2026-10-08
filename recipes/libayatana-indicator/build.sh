#!/bin/bash

set -euxo pipefail

# ENABLE_LOADER builds the ayatana-indicator-loader3 debugging tool; not needed.
cmake -S . -B build -GNinja \
    ${CMAKE_ARGS} \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DENABLE_TESTS=OFF \
    -DENABLE_LOADER=OFF \
    -DFLAVOUR_GTK3=ON \
    -DENABLE_IDO=ON

cmake --build build --verbose
cmake --install build
