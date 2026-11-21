# Avvik

Deviations from current Flutter stable for Navigation. Each entry records what changed, why, which files, the sha256, the off switch, and the rollback.

## 2026-11-21 — Pin Flutter 3.47.8 (no Wayland subsurface renderer)

### What

Flutter is pinned to **3.47.8** (stable; framework `737ba8f885`, engine.version `cf636b1dfb`, engine hash `dfd2e6cb7d31`, Dart 3.13.7) everywhere this repo installs Flutter. One workflow-level knob, `FLUTTER_VERSION`, in each file:

- `.github/workflows/linux-flatpak-release.yml` — x86_64 uses `subosito/flutter-action@v2` with `channel: stable` and `flutter-version: ${{ env.FLUTTER_VERSION }}`. aarch64 clones `https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1`.
- `.github/workflows/ci.yml` — analyze, test, Linux debug, and the debug APK use the same pin.
- `.github/workflows/android_release.yml` — the release APK uses the same pin. Android is not hit by the Wayland bug. One toolchain avoids "works on 3.47, breaks on 3.50" drift.

The Flatpak workflow also:

- runs on `pull_request` to `main`, so an aarch64 bundle can be built from a PR
- uploads `flatpak-bundle-x86_64` and `flatpak-bundle-aarch64` as before
- runs `publish` (gh-pages, release attach, `repository_dispatch`) only when `github.event_name != 'pull_request' && github.ref == 'refs/heads/main'`
- uses concurrency group `flatpak-pages-${{ github.event_name == 'pull_request' && github.ref || 'main' }}` so a PR run does not cancel a main publish
- fails the x86_64 and aarch64 jobs if `strings` finds `FlViewRendererSubsurface` in the built `libflutter_linux_gtk.so`, and prints `flutter --version`

No application code changed. `pubspec.yaml` `environment.sdk` stays `^3.12.2` (Dart 3.13.7 satisfies it). `pubspec.lock` did not need to change. `flutter pub get` rewrote `analysis_options.yaml` on disk; that rewrite is not committed. The README does not name a Flutter version, so it was left as-is. No FVM.

### Why

Flutter 3.50.x on Linux/Wayland renders with `FlViewRendererSubsurface` (`fl_view_renderer_subsurface.cc`, `fl_subsurface*.cc`). On a Fairphone 5 (BengalOS 0.26.1120.1, Phosh/phoc 0.59, aarch64, GNOME Platform 50) that logs `Timed out waiting for subsurface frame ... (have 3840x2160)` and then deadlocks: futex on the main thread, raster thread spinning, no window. Upstream: flutter#196529, flutter#196663, flutter#195822.

`FLUTTER_LINUX_RENDERER=software` aborts in Impeller's `DlText` path, and 3.50 has no `opengl-gtk` opt-out. 3.47.8's Linux shell has only `fl_view_renderer.{cc,h}`. Its `linux-arm64-release` `libflutter_linux_gtk.so` has no `FlViewRendererSubsurface` string and no subsurface timeout string. 3.47.9 also lacks the renderer; this pin stays on 3.47.8 because that is the requested version.

### Files

- `.github/workflows/linux-flatpak-release.yml`
- `.github/workflows/ci.yml`
- `.github/workflows/android_release.yml`
- `docs/AVVIK.md`

### sha256

Local desk build, Flutter 3.47.8, x86_64. The Flatpak copy and the Flutter release-bundle copy are the same bytes. `strings | grep -c FlViewRendererSubsurface` is 0. `strings | grep -c 'Timed out waiting for subsurface'` is 0.

| File | sha256 |
|---|---|
| `libflutter_linux_gtk.so` (x86_64, 17256536 bytes) | `360ff98cd21382014818e418a9b96dcddf93240751300627fe14816d5993a891` |
| `com.isyourbrainfoss.Navigation-x86_64.flatpak` (8099544 bytes) | `d8a1fe648f200737f90da9f0551b477df8e29ad5737dce214d435203a8f0e194` |

aarch64 sha256 is not from this desk (no aarch64 emulation). It comes from the PR's `build-aarch64` artifact `flatpak-bundle-aarch64`.

### Off switch

There is no runtime flag. 3.50 cannot opt out of the subsurface renderer. Shipping 3.47.8 is the off switch for that renderer.

### Rollback

Revert the pin commit, or set `FLUTTER_VERSION` back to current stable.

Unpin only after a stable Flutter release that contains the subsurface fix, and that release has been verified on the Fairphone 5: the window appears, and the log has no `Timed out waiting for subsurface frame`. Until that check, leave the pin.
