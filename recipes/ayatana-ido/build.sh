#!/bin/bash

set -euxo pipefail

# g-ir-scanner and gi-docgen look up GIR dependencies through XDG_DATA_DIRS.
export XDG_DATA_DIRS="${PREFIX}/share:${BUILD_PREFIX}/share:${XDG_DATA_DIRS:-/usr/share}"

# Upstream forces CMAKE_INSTALL_PREFIX to /usr when left at the default, and
# GNUInstallDirs would pick lib64 on RHEL-like build images, so pin both.
cmake -S . -B build -GNinja \
    ${CMAKE_ARGS} \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DENABLE_TESTS=OFF

cmake --build build --verbose
cmake --install build
