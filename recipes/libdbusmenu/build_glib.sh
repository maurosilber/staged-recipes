#!/bin/bash

set -euxo pipefail

export XDG_DATA_DIRS="${PREFIX}/share:${BUILD_PREFIX}/share:${XDG_DATA_DIRS:-/usr/share}"

# Makefile.am hardcodes -Werror; newer compilers/glib emit warnings upstream never saw.
export CFLAGS="${CFLAGS} -Wno-error"

# The release tarball ships an old config.guess/config.sub.
cp "${BUILD_PREFIX}"/share/gnuconfig/config.* . || true

# configure.ac only defines the HAVE_VALGRIND conditional inside the tests block,
# so --disable-tests fails with "conditional HAVE_VALGRIND was never defined".
export HAVE_VALGRIND_TRUE='#'
export HAVE_VALGRIND_FALSE=''

./configure \
    --prefix="${PREFIX}" \
    --libdir="${PREFIX}/lib" \
    --disable-static \
    --disable-gtk \
    --disable-dumper \
    --disable-tests \
    --disable-gtk-doc \
    --enable-introspection=yes \
    --enable-vala=yes

make -j"${CPU_COUNT}" V=1
make install
