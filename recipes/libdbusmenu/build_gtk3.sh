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

# vala 0.56's vapigen rejects the <doc:format/> element that gobject-introspection
# >=1.80 writes into .gir files ("unknown child element `doc:format'"), so strip it
# from the installed .gir files and, through a vapigen wrapper, from the freshly
# generated ones before vapigen reads them. It only records the doc comment syntax.
sed -i '/<doc:format /d' "${PREFIX}"/share/gir-1.0/*.gir "${BUILD_PREFIX}"/share/gir-1.0/*.gir
cat > "${SRC_DIR}/vapigen-wrapper" <<'EOF_WRAPPER'
#!/bin/bash
for arg in "$@"; do
    case "${arg}" in
        *.gir) [ -f "${arg}" ] && sed -i '/<doc:format /d' "${arg}" ;;
    esac
done
exec vapigen "$@"
EOF_WRAPPER
chmod +x "${SRC_DIR}/vapigen-wrapper"
export VALA_API_GEN="${SRC_DIR}/vapigen-wrapper"

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
