FROM ubuntu:24.04

ARG ZIG_VERSION=0.16.0
ARG ANDROID_API_LEVEL=34
ARG ANDROID_BUILD_TOOLS_LEVEL=35.0.0
ARG ANDROID_NDK_VERSION=26.3.11579264
ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708
ARG ANDROID_SDK_ROOT=/opt/android-sdk
ARG GRADLE_VERSION=9.1.0
ARG VULKAN_VALIDATION_VERSION=1.4.335.0

ENV DEBIAN_FRONTEND=noninteractive

# System packages: build deps for Linux + Android tooling + glslangValidator
# for in-build shader compilation. dpkg --add-architecture arm64 stays so the
# disabled multi-arch line below can be re-enabled without further plumbing.
#
# arm64 *-dev variants are NOT installed: GLFW dlopen()s Wayland/Vulkan/EGL at
# runtime and Zig provides cross glibc, so cross-compile only needs the
# arch-neutral headers from the amd64 packages. Re-enable the commented line
# if anything later starts link-time depending on those libraries:
#       libwayland-dev:arm64 libxkbcommon-dev:arm64 libvulkan-dev:arm64 libegl-dev:arm64 libc6-dev:arm64
RUN dpkg --add-architecture arm64 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl unzip xz-utils \
        openjdk-21-jdk-headless \
        glslang-tools \
        libwayland-dev libxkbcommon-dev libvulkan-dev libegl-dev libc6-dev && \
    rm -rf /var/lib/apt/lists/*

# Zig toolchain
RUN curl -fsSL https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz | tar -xJ -C /opt && \
    ln -s /opt/zig-linux-x86_64-${ZIG_VERSION} /opt/zig
ENV PATH="/opt/zig:${PATH}"

# Android cmdline-tools, SDK, NDK
ENV ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT}
ENV ANDROID_HOME=${ANDROID_SDK_ROOT}
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools && \
    curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" -o /tmp/cmdtools.zip && \
    unzip -q /tmp/cmdtools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools && \
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm /tmp/cmdtools.zip && \
    yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager --licenses >/dev/null && \
    ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager \
        "platform-tools" \
        "platforms;android-${ANDROID_API_LEVEL}" \
        "build-tools;${ANDROID_BUILD_TOOLS_LEVEL}" \
        "ndk;${ANDROID_NDK_VERSION}"

ENV ANDROID_NDK_HOME=${ANDROID_SDK_ROOT}/ndk/${ANDROID_NDK_VERSION}
ENV PATH="${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools"

# Gradle 9.1 (project's Gradle wrapper will use whichever version it pins; this
# binary is here for ad-hoc invocations or wrapper bootstrap).
RUN curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o /tmp/gradle.zip && \
    unzip -q /tmp/gradle.zip -d /opt && \
    ln -s /opt/gradle-${GRADLE_VERSION} /opt/gradle && \
    rm /tmp/gradle.zip
ENV PATH="${PATH}:/opt/gradle/bin"

# Android Vulkan validation layers (downloaded for optional APK packaging).
RUN curl -fsSL "https://github.com/KhronosGroup/Vulkan-ValidationLayers/releases/download/vulkan-sdk-${VULKAN_VALIDATION_VERSION}/android-binaries-${VULKAN_VALIDATION_VERSION}.tar.gz" -o /opt/android-vulkan-layers.tar.gz

# Vulkan registry: Ubuntu's libvulkan-dev places vk.xml at
# /usr/share/vulkan/registry/, which the build's lookup probes via VULKAN_SDK.
ENV VULKAN_SDK=/usr

# Apple SDK for macOS cross-compile: bind-mount or COPY a staged SDK at this
# path (see README). Native macOS builds don't use this.
ENV SDKROOT=/opt/apple-sdk

WORKDIR /workspace
