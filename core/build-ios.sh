set -euo pipefail

rustup target add --toolchain nightly-2023-10-05 \
  aarch64-apple-ios \
  aarch64-apple-ios-sim \
  x86_64-apple-ios


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
# 2.2 Package into XCFramework
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

