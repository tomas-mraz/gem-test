# gem-test
Test application

## Cross-compilation

The `Makefile` exposes targets for each supported platform. Builds run from a
Linux host; native builds on the target platform also work where applicable.

All artifacts land in `./build/`.

| Target               | Make target              | Output                                    |
|----------------------|--------------------------|-------------------------------------------|
| Linux amd64 (host)   | `make build-linux`       | `build/gem-test-linux-amd64`              |
| Linux arm64          | `make build-linux-arm64` | `build/gem-test-linux-arm64`              |
| Android (arm64-v8a)  | `make build-android` (debug APK) / `make build-android-release` (AAB) / `make sign-android-release` (signed AAB) | `build/gem-test-android-arm64-dev.apk` / `build/gem-test-android.aab` / `build/gem-test-android-signed.aab` |
| Windows amd64        | `make build-windows`     | `build/gem-test-win-amd64.exe`            |
| Windows arm64        | `make build-windows-arm64` | `build/gem-test-win-arm64.exe`          |
| macOS arm64          | `make build-macos` / `make build-macos-app` / `make build-macos-dmg` | `build/gem-test-macos-arm64` / `build/gem-test-macos-arm64-dev.app` / `build/gem-test-macos-arm64-dev.dmg` |

`*-release` variants build with `-Doptimize=ReleaseSafe`. `make build-all` /
`make build-all-release` build every platform in one go.

Linux arm64 cross-compile only needs the regular (amd64) `-dev` packages on
the build host:

```sh
sudo apt install libwayland-dev libxkbcommon-dev libvulkan-dev \
                 libegl-dev libc6-dev glslang-tools
```

Those headers are arch-neutral, and Zig ships its own glibc for cross builds.
GLFW resolves Wayland/Vulkan/EGL via `dlopen` at runtime, so no aarch64 `.so`
files are needed at build time. Multi-arch (`:arm64` variants) would only
matter if a library starts being linked at build time.

### Required environment variables

| Variable          | Used for                              | Notes                                                |
|-------------------|---------------------------------------|------------------------------------------------------|
| `VULKAN_SDK`      | All desktop targets                   | Path to the Vulkan SDK root (provides `vk.xml`).     |
| `ANDROID_NDK_HOME` (or `ANDROID_NDK_ROOT`) | Android target | NDK root; alternatively pass `-Dandroid-ndk=<path>`. |
| `SDKROOT`         | macOS cross-compile from non-Darwin   | Path to a staged Apple SDK (see below).              |

### Android

The Android build compiles a shared library through Zig, drops it into
`android/app/src/main/jniLibs/<abi>/`, then runs Gradle to package the
artifact:

- `make build-android` → debug APK (`assembleDebug`) for sideloading
- `make build-android-release` → release AAB (`bundleRelease`) for Play Store
- `make sign-android-release` → signed release AAB via `jarsigner`

Signing requires these environment variables:

- `ANDROID_KEYSTORE`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

For GitLab CI, set `ANDROID_KEYSTORE` as a `File` type CI/CD variable whose
content is the `.jks`/`.keystore` file. GitLab then exposes the temporary file
path in `$ANDROID_KEYSTORE`, which works directly with `make sign-android-release`.

Override `ANDROID_TARGET` / `ANDROID_ABI` to build for an architecture other
than `aarch64-linux-android` / `arm64-v8a`.

### GitLab CI

The repository includes [.gitlab-ci.yml](/home/tomas/git-osobni-github/gem-test/.gitlab-ci.yml),
which publishes a signed Android AAB on tag pipelines.

Required GitLab CI/CD variables:

- `ANDROID_KEYSTORE` (`File` type)
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

Mark the signing variables as `Protected`; keep the password variables masked,
and run releases from protected tags.

The job produces these artifacts:

- `build/gem-test-android.aab`
- `build/gem-test-android-signed.aab`

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

Additional packaging targets:

- `make build-macos-app` / `make build-macos-app-release` create a minimal
  `.app` bundle around the compiled executable. The bundle uses
  `assets/macos/app-icon.png` as the source icon asset.
- `make sign-macos-app` / `make sign-macos-app-release` copy that `.app`
  bundle to a `-signed.app` artifact and sign the bundle with `codesign`.
- `make build-macos-dmg` / `make build-macos-dmg-release` wrap the `.app`
  bundle into a `.dmg` file from the corresponding `-signed.app` artifact.
  These targets require macOS because they call `hdiutil`.

When `build-macos-app*` runs on macOS, it also converts the PNG source icon
into `AppIcon.icns` with `sips` and `iconutil` and places it under
`Contents/Resources/`.

Override these variables if needed:

- `MACOS_APP_DISPLAY_NAME` for the Finder-visible app name and DMG volume name
- `MACOS_BUNDLE_ID` for the bundle identifier written into `Info.plist`
- `MACOS_APP_ICON_PNG` for the source PNG used to generate the macOS app icon
- `MACOS_APP_ICON_NAME` for the icon file name recorded in `Info.plist`
- `MACOS_CODESIGN_IDENTITY` for the signing identity passed to `codesign`
- `MACOS_CODESIGN` to override the `codesign` executable path

### Windows

`make build-windows` produces a 64-bit executable; `make build-windows-arm64`
targets ARM64. No additional setup beyond `VULKAN_SDK` is required.

### Cleaning

Per-target clean rules: `clean-linux`, `clean-android`, `clean-windows`, `clean-macos`.

# Related sources
- https://developer.android.com/studio/publish/app-signing#register_upload_key
