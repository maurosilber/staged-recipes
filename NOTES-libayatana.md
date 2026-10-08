# libayatana-appindicator-glib + webkit2gtk4.1 + Tauri tray: investigation notes

(Working notes; delete before any PR to staged-recipes.)

## Environment
- Host is macOS arm64 (no docker). Using Apple `container` CLI 1.4.1 to run
  `linux/amd64` containers (Rosetta) for linux-64 builds.

## Finding 1: Tauri/tray-icon cannot use the glib variant at all (API + soname)
- `libappindicator-sys` 0.9.0 (tauri-apps/libappindicator-rs, `sys/src/lib.rs`)
  dlopens, in order:
  `libayatana-appindicator3.so.1`, `libappindicator3.so.1`,
  and with feature `backcompat` (default) `libayatana-appindicator3.so`, `libappindicator3.so`.
  It never tries `libayatana-appindicator-glib.so.*`.
- This recipe ships `libayatana-appindicator-glib.so.2` (src/CMakeLists.txt:
  `VERSION 2.0.0 SOVERSION 2`).
- API is also incompatible: glib variant has
  `void app_indicator_set_menu (AppIndicator *self, GMenu *menu);`
  while libappindicator-sys / tray-icon (via muda gtk3) passes a `GtkMenu*`.
  So even a symlink `libayatana-appindicator3.so.1 -> libayatana-appindicator-glib.so.2`
  would crash/misbehave at `set_menu`.
- tray-icon 0.26.1 features: `libappindicator` (default, GTK3, uses dlopen above)
  or `ksni` (pure-Rust StatusNotifierItem over D-Bus, no C lib needed).
  Tauri 2.x (crates/tauri/Cargo.toml) hard-wires
  `tray-icon = { version = "0.25", default-features = false, features = ["serde", "libappindicator"] }`.
  So Tauri needs the GTK3 `libayatana-appindicator3` (0.5.x), not the glib one.

## Finding 2: what conda-forge has
- `pixi search -p linux-64 -c conda-forge`: no `libayatana-appindicator`,
  `libayatana-indicator`, `libayatana-ido`, `libdbusmenu*`, `libappindicator`.
- Available: webkit2gtk4.1 2.48.5 (build _4, deps gtk3 >=3.24.52, libglib >=2.88.2),
  gtk3 3.24.52, glib 2.90.0, librsvg 2.62.4.
- GTK3 libayatana-appindicator 0.6.0 needs (pkg-config):
  glib-2.0>=2.58, ayatana-indicator3-0.4>=0.8.4, gtk+-3.0>=3.24, dbusmenu-gtk3-0.4.
  libayatana-indicator 0.9.5 needs glib, gtk3, libayatana-ido3-0.4 (optional, ENABLE_IDO).
  ayatana-ido 0.10.4 needs glib, gtk3.
  dbusmenu-gtk3 comes from Canonical's libdbusmenu (16.04.0, autotools).

## Plan / milestone 1 (recipes written)
Because Tauri needs `libayatana-appindicator3.so.1` with the GTK3 API, the fix
in staged-recipes is to add the GTK3 stack (built in dependency order):
1. `recipes/libdbusmenu` -> outputs `libdbusmenu-glib`, `libdbusmenu-gtk3` (16.04.0, autotools;
   launchpad URL is under the `16.04` series, not `16.10`).
2. `recipes/ayatana-ido` -> `libayatana-ido` 0.10.4 (CMake; GIR + Vala are REQUIRED upstream).
3. `recipes/libayatana-indicator` -> 0.9.5 (CMake, ENABLE_IDO=ON, ENABLE_LOADER=OFF).
4. `recipes/libayatana-appindicator` -> 0.6.0 (CMake, GTK3, mono/gtk-doc off, vala on).

## Linux build environment on macOS
- `container system kernel set --recommended` hung; fixed by downloading
  kata-static-3.32.0-arm64.tar.zst manually, decompressing, and
  `container system kernel set --tar kata.tar --binary opt/kata/share/kata-containers/vmlinux-6.18.35-197`.
- `container run --platform linux/amd64 ubuntu:24.04` works (x86_64 via Rosetta).
- Builds: rattler-build inside container, `-m conda-forge-pinning conda_build_config.yaml -m .ci_support/linux64.yaml -c conda-forge`.

## Build fixes found so far (milestone 2)
- gio-2.0.pc -> zlib, fontconfig.pc (via gtk+-3.0.pc) -> expat: pkg-config fails
  ("Package 'zlib', required by 'gio-2.0', not found", "Package 'expat', required by
  'fontconfig', not found") unless `zlib` and `expat` are in host. Added with ignore_run_exports.
- ayatana-ido: `project(ayatana-ido C CXX)` needs a C++ compiler only for tests -> sed to `C`.
- libdbusmenu: `--disable-tests` -> "conditional HAVE_VALGRIND was never defined";
  fixed by exporting HAVE_VALGRIND_TRUE='#' HAVE_VALGRIND_FALSE=''. Needs xsltproc (libxslt).
- Variant files: rattler-build 0.76 only honors `# [linux]` selectors in a file
  named conda_build_config.yaml; `channel_sources` must be removed when passing `-c`.

## Finding 4: webkit2gtk4.1 needs glibc >= 2.34 on the user's system
- `pixi install` with default system-requirements fails:
  "webkit2gtk4.1 2.48.4 | 2.48.5 would require __glibc >=2.34,<3.0.a0, for which no candidates were found."
- Cause: feedstock recipe/conda_build_config.yaml sets `c_stdlib_version: 2.34`.
  Users need `[system-requirements] libc = "2.34"` in pixi (or a glibc>=2.34 host).
  Not a conflict with our recipes (built against 2.17, which is compatible).

## Status log
- libayatana-appindicator-glib (original recipe): builds on linux-64 (container) ->
  libayatana-appindicator-glib-2.0.3-h423ffd8_0.conda.
- ~06:20-07:35: GTK3 builds were blocked ~75 min on "Blocking waiting for global file lock
  on package cache" because a concurrent `pixi install` (Tauri env) held the rattler cache
  lock. Don't run pixi install and rattler-build at the same time in one container.

## Finding 3: webkit2gtk4.1-feedstock recipe
- recipe/recipe.yaml (v1), 2.48.5 build 4, host has gtk3, glib, gobject-introspection,
  libsoup etc. run_exports pins webkit2gtk4.1 exact.

## Session 2 (linux-64 cloud container, native)
- Sources from github.com archives and launchpadlibrarian.net are blocked by that
  environment's egress policy, so local builds used Ubuntu archive orig tarballs
  (ido 0.10.4; indicator 0.9.4; appindicator 0.5.94; libdbusmenu
  16.04.1+16.04.20160927 = 16.04.0 + packaging, autoreconf'd with a gtk-doc stub)
  via scratch copies of the recipes. Recipes themselves keep the upstream URLs.
- vala 0.56.17 (latest on conda-forge) chokes on `<doc:format/>` in .gir files
  (gobject-introspection >=1.80). Now stripped in ayatana-ido, libayatana-appindicator
  (build gir target first, strip, then continue) and libdbusmenu (VALA_API_GEN wrapper).
- Test envs need zlib + expat for pkg-config (gio-2.0.pc / fontconfig.pc).
- With those fixes all 5 outputs build and pass their tests on linux-64.

## Finding 5: webkit2gtk4.1 cannot coexist with libglib >=2.90 (root cause)
- Packages built against current glib (2.90) run-export `libglib >=2.90` -> `libffi 3.7`.
- webkit2gtk4.1 2.48.5_4 has `ruby` (and perl/gperf/unifdef) in `host` without
  ignore_run_exports, so it depends at runtime on `ruby >=4.0.5,<4.1` -> `libffi <3.6`.
  => unsolvable with libglib 2.90. webkit2gtk4.1 alone resolves libglib 2.88.3.
- Workaround in our recipes: `glib <2.90` in host (comment explains it).
- Proper fix: webkit2gtk4.1-feedstock should move ruby/perl/gperf/unifdef to `build`
  (they are build-time tools) or add them to `ignore_run_exports.from_package`.
