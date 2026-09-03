Building cr-sqlite Native Libraries (iOS & Android)
This guide covers building cr-sqlite as a loadable dynamic SQLite extension for iOS (crsqlite.xcframework) and Android (libcrsqlite.so with 16KB page alignment).
1. Prerequisites & Toolchain Setup
1.1 Git Submodules
Ensure submodules are initialized:
git submodule update --init --recursive
1.2 Rust Toolchain
cr-sqlite relies on -Zbuild-std and pins nightly nightly-2023-10-05 in core/rs/bundle/rust-toolchain.toml:
rustup toolchain install nightly-2023-10-05 --component rust-src
1.3 Target Architectures
# iOS targets
rustup target add --toolchain nightly-2023-10-05 \
  aarch64-apple-ios \
  aarch64-apple-ios-sim \
  x86_64-apple-ios

# Android targets
rustup target add --toolchain nightly-2023-10-05 \
  aarch64-linux-android \
  x86_64-linux-android \
  armv7-linux-androideabi
1.4 Native Tooling
- macOS / iOS: Xcode 15+ / 16+ command-line tools (xcode-select --install).
- Android: Android NDK r27+ (e.g. 27.0.11902837) and cargo-ndk:
cargo install cargo-ndk
export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/27.0.11902837"
2. iOS Build Process (crsqlite.xcframework)
Because sqlite3_capi uses bindgen 0.68, targeting aarch64-apple-ios-sim requires overriding clang arguments (BINDGEN_EXTRA_CLANG_ARGS) so libclang does not choke on the -sim triple suffix.
2.1 Build Step-by-Step
Run all commands from the core/ directory:
cd core

# 1. Build iOS Device (arm64)
make clean
export IOS_TARGET=aarch64-apple-ios
make loadable
mkdir -p ./dist-ios
cp ./dist/crsqlite.dylib ./dist-ios/crsqlite-aarch64-apple-ios.dylib

# 2. Build iOS Simulator (arm64) with bindgen fix
make clean
export IOS_TARGET=aarch64-apple-ios-sim
export BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios_sim="--target=arm64-apple-ios-simulator"
make loadable
mkdir -p ./dist-ios-sim
cp ./dist/crsqlite.dylib ./dist-ios-sim/crsqlite-aarch64-apple-ios-sim.dylib

# 3. Build iOS Simulator (x86_64)
make clean
export IOS_TARGET=x86_64-apple-ios
unset BINDGEN_EXTRA_CLANG_ARGS_aarch64_apple_ios_sim
make loadable
cp ./dist/crsqlite.dylib ./dist-ios-sim/crsqlite-x86_64-apple-ios-sim.dylib

# 4. Create Universal Simulator Binary
cd ./dist-ios-sim
lipo crsqlite-aarch64-apple-ios-sim.dylib crsqlite-x86_64-apple-ios-sim.dylib \
  -create -output crsqlite-universal-ios-sim.dylib
cd ..
2.2 Package into XCFramework
BUILD_DIR=./build
DIST_DIR=./dist

PLIST='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>crsqlite</string>
  <key>CFBundleIdentifier</key>
  <string>io.vlcn.crsqlite</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleSignature</key>
  <string>????</string>
</dict>
</plist>'

# Device Framework
mkdir -p "${BUILD_DIR}/ios-arm64/crsqlite.framework"
echo "${PLIST}" > "${BUILD_DIR}/ios-arm64/crsqlite.framework/Info.plist"
cp -f "./dist-ios/crsqlite-aarch64-apple-ios.dylib" "${BUILD_DIR}/ios-arm64/crsqlite.framework/crsqlite"
install_name_tool -id "@rpath/crsqlite.framework/crsqlite" "${BUILD_DIR}/ios-arm64/crsqlite.framework/crsqlite"

# Simulator Framework
mkdir -p "${BUILD_DIR}/ios-arm64_x86_64-simulator/crsqlite.framework"
echo "${PLIST}" > "${BUILD_DIR}/ios-arm64_x86_64-simulator/crsqlite.framework/Info.plist"
cp -p "./dist-ios-sim/crsqlite-universal-ios-sim.dylib" "${BUILD_DIR}/ios-arm64_x86_64-simulator/crsqlite.framework/crsqlite"
install_name_tool -id "@rpath/crsqlite.framework/crsqlite" "${BUILD_DIR}/ios-arm64_x86_64-simulator/crsqlite.framework/crsqlite"

# Assemble XCFramework
rm -rf "${BUILD_DIR}/crsqlite.xcframework"
xcodebuild -create-xcframework \
  -framework "${BUILD_DIR}/ios-arm64/crsqlite.framework" \
  -framework "${BUILD_DIR}/ios-arm64_x86_64-simulator/crsqlite.framework" \
  -output "${BUILD_DIR}/crsqlite.xcframework"

mkdir -p "${DIST_DIR}"
cp -Rf "${BUILD_DIR}/crsqlite.xcframework" "${DIST_DIR}/crsqlite.xcframework"
tar -czf "${DIST_DIR}/crsqlite-ios-dylib.xcframework.tar.gz" -C "${DIST_DIR}" crsqlite.xcframework
rm -rf "${BUILD_DIR}"
3. Android Build Process (libcrsqlite.so)
Android 15+ and Google Play require 16KB page alignment. Pass -Wl,-z,max-page-size=16384 during the final link.
Run from core/:
```bash
cd core
./build-android.sh
```

Or manually:
```bash
cd core
export ANDROID_NDK_HOME="$HOME/Library/Android/sdk/ndk/27.1.12297006"
LLVM_BIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin"

# 1. Build armeabi-v7a
make clean
export ANDROID_TARGET=armv7-linux-androideabi
make loadable CC="$LLVM_BIN/clang -Wl,-z,max-page-size=16384"
mkdir -p ./dist-android/armeabi-v7a
cp ./dist/crsqlite.so ./dist-android/armeabi-v7a/libcrsqlite.so

# 2. Build arm64-v8a
make clean
export ANDROID_TARGET=aarch64-linux-android
make loadable CC="$LLVM_BIN/clang -Wl,-z,max-page-size=16384"
mkdir -p ./dist-android/arm64-v8a
cp ./dist/crsqlite.so ./dist-android/arm64-v8a/libcrsqlite.so

# 3. Build x86
make clean
export ANDROID_TARGET=i686-linux-android
make loadable CC="$LLVM_BIN/clang -Wl,-z,max-page-size=16384"
mkdir -p ./dist-android/x86
cp ./dist/crsqlite.so ./dist-android/x86/libcrsqlite.so

# 4. Build x86_64
make clean
export ANDROID_TARGET=x86_64-linux-android
make loadable CC="$LLVM_BIN/clang -Wl,-z,max-page-size=16384"
mkdir -p ./dist-android/x86_64
cp ./dist/crsqlite.so ./dist-android/x86_64/libcrsqlite.so
```

4. Integration into React Native / op-sqlite
4.1 iOS Setup (Local Pod)
1. Create a local pod directory at <AppRoot>/native/crsqlite:
native/crsqlite/
├── crsqlite.podspec
└── crsqlite.xcframework/
2. Add native/crsqlite/crsqlite.podspec:
Pod::Spec.new do |s|
  s.name                = 'crsqlite'
  s.version             = '0.1.0'
  s.summary             = 'cr-sqlite SQLite loadable extension'
  s.license             = { :type => 'MIT' }
  s.authors             = { 'cr-sqlite' => 'noreply@vlcn.io' }
  s.homepage            = 'https://github.com/vlcn-io/cr-sqlite'
  s.platforms           = { :ios => '13.0' }
  s.source              = { :git => 'local' }
  s.vendored_frameworks = 'crsqlite.xcframework'
end
3. Reference in ios/Podfile:
target 'YourApp' do
  config = use_native_modules!
  pod 'crsqlite', :path => '../native/crsqlite'
end
4. Run pod install in ios/.
4.2 Android Setup (jniLibs)
Copy the compiled .so files into android/app/src/main/jniLibs/:
android/app/src/main/jniLibs/
├── armeabi-v7a/
│   └── libcrsqlite.so
├── arm64-v8a/
│   └── libcrsqlite.so
├── x86/
│   └── libcrsqlite.so
└── x86_64/
    └── libcrsqlite.so
Note: Ensure CPLUS_INCLUDE_PATH / CPATH environment variables are not set in your shell during Android Gradle builds to prevent host JDK headers from interfering with NDK Bionic jni.h.
4.3 JavaScript / TypeScript Usage with op-sqlite
import { Platform } from 'react-native';
import { open, getDylibPath, type DB } from '@op-engineering/op-sqlite';

const EXT_BUNDLE_ID = 'io.vlcn.crsqlite';
const EXT_NAME = 'crsqlite';

```
async function initDatabase(): Promise<DB> {
  const db = open({ name: 'my_crsql.db' });

  // 1. Resolve platform path
  let extensionPath: string;
  if (Platform.OS === 'android') {
    // In Android APK, libcrsqlite.so is extracted to nativeLibraryDir on dlopen search path
    extensionPath = 'libcrsqlite.so';
  } else {
    // On iOS, use op-sqlite's helper or fallback to @rpath
    extensionPath = getDylibPath(EXT_BUNDLE_ID, EXT_NAME) || '@rpath/crsqlite.framework/crsqlite';
  }

  // 2. Load the dynamic extension
  db.loadExtension(extensionPath);

  // 3. Create table & upgrade to Conflict-Free Replicated Relation (CRR)
  await db.execute('CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY NOT NULL, text TEXT);');
  await db.execute("SELECT crsql_as_crr('todos');");

  // 4. Query changes
  const changes = await db.execute('SELECT * FROM crsql_changes;');
  console.log('crsql_changes:', changes.rows);

  return db;
}
```
