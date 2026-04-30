# gem-test
Test application

## Cross-compilation

The `Makefile` exposes targets for each supported platform. Builds run from a
Linux host; native builds on the target platform also work where applicable.

All artifacts land in `./build/`.

| Target               | Make target              | Output                                    |
|----------------------|--------------------------|-------------------------------------------|
| Linux amd64 (host)   | `make build-linux`       | `build/gem-test-linux-amd64`              |
| Linux arm64          | `make build-linux-arm64` | `build/gem-test-linux-arm64` (needs sysroot) |
| Android (arm64-v8a)  | `make build-android`     | `build/gem-test-arm64-debug.apk`          |
| Windows amd64        | `make build-windows`     | `build/gem-test-win-amd64.exe`            |
| Windows arm64        | `make build-windows-arm64` | `build/gem-test-win-arm64.exe`          |
| macOS arm64          | `make build-macos`       | `build/gem-test-macos-arm64`              |

`*-release` variants build with `-Doptimize=ReleaseSafe`. `make build-all` /
`make build-all-release` build every platform in one go (Linux arm64 is
excluded — it needs an aarch64-linux sysroot with Wayland/X11 headers, which
the Makefile does not provision).

### Required environment variables

| Variable          | Used for                              | Notes                                                |
|-------------------|---------------------------------------|------------------------------------------------------|
| `VULKAN_SDK`      | All desktop targets                   | Path to the Vulkan SDK root (provides `vk.xml`).     |
| `ANDROID_NDK_HOME` (or `ANDROID_NDK_ROOT`) | Android target | NDK root; alternatively pass `-Dandroid-ndk=<path>`. |
| `SDKROOT`         | macOS cross-compile from non-Darwin   | Path to a staged Apple SDK (see below).              |

### Android

The Android build compiles a shared library through Zig, drops it into
`android/app/src/main/jniLibs/<abi>/`, then runs Gradle to package the APK.
Override `ANDROID_TARGET` / `ANDROID_ABI` to build for an architecture other
than `aarch64-linux-android` / `arm64-v8a`.

### macOS

Cross-compiling to macOS from Linux requires a staged Apple SDK, since Zig
cannot invoke `xcrun` off-Darwin. Point `SDKROOT` at the SDK root, e.g.:

```sh
export SDKROOT=/opt/apple-sdk
make build-macos
```

The SDK directory must contain `usr/include`, `usr/lib`, and
`System/Library/Frameworks`. Native builds on macOS pick the SDK up
automatically via `xcrun` and ignore `SDKROOT`.

At runtime the binary loads the system Vulkan loader, which in turn loads the
Vulkan ICD configured on the host (e.g. Mesa's KosmicKrisp). MoltenVK is not
bundled.

### Windows

`make build-windows` produces a 64-bit executable; `make build-windows-arm64`
targets ARM64. No additional setup beyond `VULKAN_SDK` is required.

### Cleaning

Per-target clean rules: `clean`, `clean-android`, `clean-windows`,
`clean-macos`.
