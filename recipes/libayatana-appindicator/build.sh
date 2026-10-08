#!/bin/bash

set -euxo pipefail

# vala 0.56's vapigen rejects the <doc:format/> element that gobject-introspection
# >=1.80 writes into .gir files ("unknown child element `doc:format'"), so strip it
# from the .gir files vapigen reads. It only records the doc comment syntax.
strip_doc_format() {
    sed -i '/<doc:format /d' "$@"
}

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

strip_doc_format "${PREFIX}"/share/gir-1.0/*.gir "${BUILD_PREFIX}"/share/gir-1.0/*.gir

# Generate the .gir (and .typelib) first, strip it, then let vapigen consume it.
cmake --build build --target src --verbose
strip_doc_format build/src/AyatanaAppIndicator3-0.1.gir

cmake --build build --verbose
cmake --install build
