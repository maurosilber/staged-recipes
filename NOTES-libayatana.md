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

## Finding 3: webkit2gtk4.1-feedstock recipe
- recipe/recipe.yaml (v1), 2.48.5 build 4, host has gtk3, glib, gobject-introspection,
  libsoup etc. run_exports pins webkit2gtk4.1 exact.
