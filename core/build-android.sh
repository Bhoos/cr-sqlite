#!/usr/bin/env bash
set -euo pipefail

# Ensure script runs from the core directory
cd "$(dirname "$0")"

echo "=== Ensuring Rust targets are installed ==="
rustup target add --toolchain nightly-2023-10-05 \
  aarch64-linux-android \
  x86_64-linux-android \
  armv7-linux-androideabi \
  i686-linux-android

# Ensure cargo-ndk is installed
if ! command -v cargo-ndk &>/dev/null; then
  echo "Installing cargo-ndk..."
  cargo install cargo-ndk
fi

# Dynamically resolve ANDROID_NDK_HOME if not already set
if [ -z "${ANDROID_NDK_HOME:-}" ]; then
  for base in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk" "$HOME/Android/Sdk" "/opt/android-sdk"; do
    if [ -n "$base" ] && [ -d "$base/ndk" ]; then
      LATEST_NDK="$(find "$base/ndk" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
      if [ -n "$LATEST_NDK" ] && [ -d "$LATEST_NDK" ]; then
        ANDROID_NDK_HOME="$LATEST_NDK"
        break
      fi
    fi
  done
fi

if [ -z "${ANDROID_NDK_HOME:-}" ] || [ ! -d "${ANDROID_NDK_HOME:-}" ]; then
  echo "Error: Android NDK not found. Please set ANDROID_NDK_HOME or install NDK via Android SDK." >&2
  exit 1
fi

export ANDROID_NDK_HOME
echo "Using Android NDK: ${ANDROID_NDK_HOME}"

PREBUILT_DIR="$(find "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n 1)"
if [ -z "${PREBUILT_DIR}" ] || [ ! -d "${PREBUILT_DIR}/bin" ]; then
  echo "Error: LLVM prebuilt toolchain not found in ${ANDROID_NDK_HOME}." >&2
  exit 1
fi
LLVM_BIN="${PREBUILT_DIR}/bin"

# Android ABIs and their corresponding Rust targets:
# - armeabi-v7a -> armv7-linux-androideabi
# - arm64-v8a   -> aarch64-linux-android
# - x86         -> i686-linux-android
# - x86_64      -> x86_64-linux-android
TARGETS=(
  "armeabi-v7a:armv7-linux-androideabi"
  "arm64-v8a:aarch64-linux-android"
  "x86:i686-linux-android"
  "x86_64:x86_64-linux-android"
)

mkdir -p ./dist-android

for entry in "${TARGETS[@]}"; do
  ABI="${entry%%:*}"
  TARGET="${entry##*:}"

  echo "=== Building Android (${ABI} / ${TARGET}) ==="
  make clean
  export ANDROID_TARGET="${TARGET}"
  # Android 15+ and Google Play require 16KB page alignment. Pass -Wl,-z,max-page-size=16384 during final link.
  make loadable CC="$LLVM_BIN/clang -Wl,-z,max-page-size=16384"

  mkdir -p "./dist-android/${ABI}"
  cp ./dist/crsqlite.so "./dist-android/${ABI}/libcrsqlite.so"
  echo "Successfully built ./dist-android/${ABI}/libcrsqlite.so"
done

echo "=== All 4 Android architectures built successfully! ==="
