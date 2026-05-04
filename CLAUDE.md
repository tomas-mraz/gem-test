# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & run

- Dev run (Linux host): `zig build run` (or `make run`).
- All cross-compile artifacts go to `./build/` via the `Makefile`. `*-release` targets use `-Doptimize=ReleaseSafe`; non-release targets emit `-dev` artifacts. `make build-all` / `make build-all-release` cover every platform.
- Per platform: `make build-linux[-arm64]`, `make build-windows[-arm64]`, `make build-macos`, `make build-android` (debug APK), `make build-android-release` (AAB), `make sign-android-release` (signed AAB), `make build-macos-app[-release]` / `sign-macos-app[-release]` / `build-macos-dmg[-release]`.
- Required env: `VULKAN_SDK` (all desktop targets — needs `vk.xml`); `ANDROID_NDK_HOME` or `ANDROID_NDK_ROOT` for Android (or pass `-Dandroid-ndk=<path>`); `SDKROOT` only when cross-compiling macOS from Linux (staged Apple SDK with `usr/include`, `usr/lib`, `System/Library/Frameworks`).
- Android signing requires `ANDROID_KEYSTORE`, `ANDROID_KEY_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`. macOS codesign requires `MACOS_CODESIGN_IDENTITY` and runs only on Darwin.
- A reference Linux build environment is in `Dockerfile` (Zig 0.16.0, Android SDK/NDK, Gradle 9.1, glslang). GitLab CI in `.gitlab-ci.yml` builds the signed Android AAB on tag pipelines only.
- There are no tests in this repo and no test target.

## Architecture

This is a small Vulkan demo app built on top of two sibling Zig packages resolved via `path =` in `build.zig.zon`:

- `../gem` — exposed as the `gem` module: provides `Engine`, scene manager, and ECS-style components (`Position`, `Color`, `Angle`, `Velocity`, etc.). Owns the platform abstraction and Vulkan device.
- `../vulkan-ash` — exposed as the `ash` module: Vulkan bindings (`ash.vk`), GLFW wrapper (`ash.glfw`), and the Android `native_app_glue` glue.

Both must exist as siblings of this checkout for `zig build` to resolve dependencies.

### Two entry points, one app

`build.zig` selects the root source by ABI: `src/main_android.zig` for `.android`/`.androideabi` (built as a dynamic library — `lib gem-test.so` — invoked via `android_main` from native-app-glue), otherwise `src/main_desktop.zig` (executable using GLFW). Both call into `src/app.zig` which builds the engine, instantiates three scenes, and wires them through the scene manager. Anything that should run on every platform belongs in `app.zig`; entry-point files only differ in allocator strategy and platform setup (logging, GLFW callbacks, `android_app` plumbing).

### Scenes and event wiring

Three scenes live in `src/scene{1,2,3}.zig` and share `src/triangle_renderer.zig` (a Vulkan pipeline that draws an embedded triangle mesh with per-instance push constants). Transitions are name-based events declared in `src/sceneevent.zig` and bound in `app.registerScenes` — e.g. `intro` emits `intro.finished` → switches to `game`; `game` emits `game.open-menu` → `menu`; `menu` emits `menu.resume-game` → `game`. Add a new transition by declaring a constant in `sceneevent.zig`, emitting it from one scene, and binding it in `app.registerScenes`.

Each scene defines its own archetype structs (parallel `std.ArrayList` columns per component) instead of using a generic ECS storage — follow that pattern when adding scenes.

### Shaders & assets

GLSL shaders in `resources/shaders/triangle.{vert,frag}` are compiled to SPIR-V at build time via `glslangValidator` (must be on `PATH`) and embedded into the binary as anonymous modules named `vertex_shader` / `fragment_shader`. Triangle mesh data is embedded from `resources/geometry/triangle.vertices.json` as `triangle_vertices`. `triangle_renderer.zig` consumes all three via `@embedFile`. New shaders or static assets follow the same pattern in `build.zig`.

### Android specifics

The Android target compiles the shared library, then `make build-android*` moves `lib gem-test.so` into `android/app/src/main/jniLibs/<abi>/` before invoking the Gradle wrapper (`./gradlew assembleDebug` or `bundleRelease`). The Gradle build is intentionally minimal (single ABI split, no minification) — `android/app/build.gradle.kts` only packages the prebuilt `.so`. `build.zig` writes a `libc.txt` pointing Zig at NDK Bionic and adds the NDK sysroot include/lib paths; the API level defaults to 29 and is overridable with `-Dandroid-api=<n>`.

### macOS cross-compile

When the target is Darwin and the host is not, `build.zig` adds `$SDKROOT/usr/lib` as a library path and `$SDKROOT/System/Library/Frameworks` as a framework path so transitive system libs (e.g. `-lobjc` from GLFW) link. Native macOS builds rely on Zig's `xcrun` auto-detection and ignore `SDKROOT`. MoltenVK is not bundled — the binary loads the host Vulkan loader at runtime.
