export CRSQLITE_COMMIT_SHA=$(shell git rev-parse HEAD)
echo crcommit $CRSQLITE_COMMIT_SHA
mkdir -p packages/crsqlite-wasm/dist
pushd ../deps/emsdk
./emsdk install 3.1.45
./emsdk activate 3.1.45
source ./emsdk_env.sh
popd
cd ../wa-sqlite
MAKE=${MAKE:-$(command -v gmake || command -v make)}
"$MAKE"
cp dist/crsqlite.wasm ../../packages/crsqlite-wasm/dist/crsqlite.wasm
cp dist/crsqlite.mjs ../../packages/crsqlite-wasm/src/crsqlite.mjs

