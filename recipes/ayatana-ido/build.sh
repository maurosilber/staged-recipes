#!/bin/bash

set -euxo pipefail

# vala 0.56's vapigen rejects the <doc:format/> element that gobject-introspection
# >=1.80 writes into .gir files ("unknown child element `doc:format'"), so strip it
# from the .gir files vapigen reads. It only records the doc comment syntax.
strip_doc_format() {
    sed -i '/<doc:format /d' "$@"
}

# g-ir-scanner and gi-docgen look up GIR dependencies through XDG_DATA_DIRS.
export XDG_DATA_DIRS="${PREFIX}/share:${BUILD_PREFIX}/share:${XDG_DATA_DIRS:-/usr/share}"

# C++ is only used by the (disabled) gtest-based tests; drop it from project()
# so that a C++ compiler is not required.
sed -i 's/^project(ayatana-ido C CXX)/project(ayatana-ido C)/' CMakeLists.txt

# Upstream forces CMAKE_INSTALL_PREFIX to /usr when left at the default, and
# GNUInstallDirs would pick lib64 on RHEL-like build images, so pin both.
cmake -S . -B build -GNinja \
    ${CMAKE_ARGS} \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DENABLE_TESTS=OFF

strip_doc_format "${PREFIX}"/share/gir-1.0/*.gir "${BUILD_PREFIX}"/share/gir-1.0/*.gir

# Generate the .gir (and .typelib) first, strip it, then let vapigen consume it.
cmake --build build --target src/AyatanaIdo3-0.4.typelib --verbose
strip_doc_format build/src/AyatanaIdo3-0.4.gir

cmake --build build --verbose
cmake --install build
