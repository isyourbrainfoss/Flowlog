# Avvik

Deviations from tracking Flutter stable. Each entry records what changed, why, which files, the sha256, and how to turn it off.

## 2026-11-21 — Pin Flutter 3.47.8 (no Wayland subsurface renderer)

### What

Flutter is pinned to **3.47.8** everywhere this repo installs it. One knob per workflow, `FLUTTER_VERSION: "3.47.8"`:

- `.github/workflows/linux-flatpak-release.yml` — x86_64 uses `subosito/flutter-action@v2` with `channel: stable` and `flutter-version: ${{ env.FLUTTER_VERSION }}`. aarch64 clones `https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1` (flutter-action has no arm64 SDK archive).
- `.github/workflows/ci.yml` — analyze, test, and the release-signing APK check use the same pin.
- `.github/workflows/android-release.yml` — same pin. Android is not hit by the Wayland bug. One toolchain so analyze, test, and Android do not drift onto 3.50 while Linux stays on 3.47.8.

Local SDK used for the x86_64 check: Flutter 3.47.8, framework `737ba8f885`, engine revision `cf636b1dfb`, engine hash `dfd2e6cb7d319db05e3bf1503f3e2ac60f6288a2`, Dart 3.13.7. No FVM.

Both Flatpak jobs, after the build, print `flutter --version` and fail if `app/flowlog/build/linux/<arch>/release/bundle/lib/libflutter_linux_gtk.so` contains `FlViewRendererSubsurface`.

`linux-flatpak-release.yml` also runs on `pull_request` to `main` and still uploads `flatpak-bundle-x86_64`, `flatpak-bundle-aarch64`, and the repo artifacts. The `publish` job (gh-pages, release assets, `repository_dispatch` to isyourbrainfoss/flatpak) runs only when `github.event_name != 'pull_request' && github.ref == 'refs/heads/main'`. PR runs use their own concurrency group (`flatpak-pages-<ref>`), so they do not cancel a main publish. Push to main and `workflow_dispatch` share `flatpak-pages-main`.

No application code changed. `pubspec.lock` and `analysis_options.yaml` were not rewritten. `environment.sdk: ^3.12.2` still matches Dart 3.13.7.

`melos run analyze` and `melos run test` passed on 3.47.8. The local x86_64 Flatpak build (`REPO_DIR=$PWD/flatpak/repo-local ./flatpak/build-flatpak.sh x86_64`) succeeded. `strings` on the built `libflutter_linux_gtk.so` (bundle and `flatpak/build-x86_64/files/bin/lib/`) found 0 `FlViewRendererSubsurface` and 0 `Timed out waiting for subsurface`.

A Wayland-without-X11 smoke test of that build dir (not installed) stayed up for 25s (exit 124). Stderr had no subsurface timeout, no "cannot open display", and no crash. The engine logged Impeller OpenGL ES. Sway registered a toplevel `com.flowlog.flowlog` / `flowlog` and the client attached 1280×767 frames. The desk compositor is Sway, and workspace 1 was a fullscreen window, so a screenshot did not show Flowlog. That is not proof the window was on screen, and it is not proof the Fairphone 5 (phoc) works.

aarch64 is not built on this desk. Its sha256 comes from the pull request's `build-aarch64` job.

### Why

Flutter 3.50 on Linux/Wayland draws with `FlViewRendererSubsurface` (`fl_view_renderer_subsurface.cc`, `fl_subsurface*.cc`). On a Fairphone 5 (BengalOS 0.26.1120.1, Phosh/phoc 0.59, aarch64, GNOME Platform 50) the app logs `Timed out waiting for subsurface frame ... (have 3840x2160)` and then deadlocks: futex on the main thread, raster thread spinning, no window. Upstream: [flutter#196529](https://github.com/flutter/flutter/issues/196529), [flutter#196663](https://github.com/flutter/flutter/issues/196663), [flutter#195822](https://github.com/flutter/flutter/issues/195822).

`FLUTTER_LINUX_RENDERER=software` aborts in Impeller DlText. 3.50 has no `opengl-gtk` opt-out. 3.47.8's Linux shell only has `fl_view_renderer.{cc,h}`. Its `linux-arm64-release` `libflutter_linux_gtk.so` has neither string; 3.50.1's has both.

### Files

- `.github/workflows/linux-flatpak-release.yml`
- `.github/workflows/ci.yml`
- `.github/workflows/android-release.yml`
- `docs/AVVIK.md`

### sha256

| File | sha256 |
|---|---|
| x86_64 `libflutter_linux_gtk.so` (17 256 536 bytes, Flutter bundle and `flatpak/build-x86_64/files/bin/lib/`, same file) | `360ff98cd21382014818e418a9b96dcddf93240751300627fe14816d5993a891` |
| x86_64 `flatpak/com.flowlog.flowlog-x86_64.flatpak` (local, not published) | `fe34c0f83469f42617e66dd6e3ed6d7acb3281a57837de738c81f1e78c7f44e9` |
| aarch64 `libflutter_linux_gtk.so` and `com.flowlog.flowlog-aarch64.flatpak` | not built here; take the sha256 from the pull request's `build-aarch64` artifact |

`FlViewRendererSubsurface` count in the local x86_64 `.so`: 0.

### Off switch

There is no runtime flag. Shipping 3.47.8 is the off switch for the 3.50 renderer. Revert the pin commit, or set `FLUTTER_VERSION` back to unpinned `stable`, and the next Flatpak build is 3.50 again. The guard step fails that build while `FlViewRendererSubsurface` is still in the `.so`.

### Rollback

Revert the pin commit (and this file) and push to `main` only after review. Do not force-push.

Unpin when a stable Flutter release contains the subsurface fix **and** a build of that release has been verified on the Fairphone 5: the window appears under Phosh/phoc, and the log does not contain `Timed out waiting for subsurface frame`. Until that check, leave the pin.
