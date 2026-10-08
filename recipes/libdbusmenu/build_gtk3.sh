#!/bin/bash

set -euxo pipefail

export XDG_DATA_DIRS="${PREFIX}/share:${BUILD_PREFIX}/share:${XDG_DATA_DIRS:-/usr/share}"

# Makefile.am hardcodes -Werror; newer compilers/glib emit warnings upstream never saw.
export CFLAGS="${CFLAGS} -Wno-error"

cp "${BUILD_PREFIX}"/share/gnuconfig/config.* . || true

# configure.ac only defines the HAVE_VALGRIND conditional inside the tests block,
# so --disable-tests fails with "conditional HAVE_VALGRIND was never defined".
export HAVE_VALGRIND_TRUE='#'
export HAVE_VALGRIND_FALSE=''

./configure \
    --prefix="${PREFIX}" \
    --libdir="${PREFIX}/lib" \
    --disable-static \
    --with-gtk=3 \
    --disable-dumper \
    --disable-tests \
    --disable-gtk-doc \
    --enable-introspection=yes \
    --enable-vala=yes

# libdbusmenu-gtk links against the in-tree libdbusmenu-glib, so build both,
# but only install the GTK part: libdbusmenu-glib comes from its own output.
make -j"${CPU_COUNT}" V=1
make -C libdbusmenu-gtk install
