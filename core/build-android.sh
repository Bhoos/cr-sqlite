rustup target add --toolchain nightly-2023-10-05 \
  aarch64-linux-android \
  x86_64-linux-android \
  armv7-linux-androideabi

cargo install cargo-ndk
export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/27.1.12297006"
LLVM_BIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin"

make clean
export ANDROID_TARGET=aarch64-linux-android
make loadable CC="$LLVM_BIN/clang -Wl,-z,max-page-size=16384"
mkdir -p ./dist-android/arm64-v8a
cp ./dist/crsqlite.so ./dist-android/arm64-v8a/libcrsqlite.so

# 2. Build x86_64 (Emulator)
make clean
export ANDROID_TARGET=x86_64-linux-android
make loadable CC="$LLVM_BIN/clang -Wl,-z,max-page-size=16384"
mkdir -p ./dist-android/x86_64
cp ./dist/crsqlite.so ./dist-android/x86_64/libcrsqlite.so

