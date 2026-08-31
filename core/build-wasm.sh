#!/usr/bin/env bash
set -euo pipefail
mkdir -p "./build/wasm"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EMSDK_DIR="${REPO_ROOT}/deps/emsdk"
WA_SQLITE_DIR="${REPO_ROOT}/wa-sqlite"

rustup toolchain install nightly-2023-10-05 --component rust-src
rustup target add wasm32-unknown-emscripten --toolchain nightly-2023-10-05
export RUSTUP_TOOLCHAIN=nightly-2023-10-05

export CRSQLITE_COMMIT_SHA="$(git -C "${REPO_ROOT}" rev-parse HEAD)"
echo "crcommit ${CRSQLITE_COMMIT_SHA}"


pushd "${EMSDK_DIR}" >/dev/null
./emsdk install 3.1.45
./emsdk activate 3.1.45
# shellcheck disable=SC1091
source ./emsdk_env.sh
popd >/dev/null

pushd "${WA_SQLITE_DIR}" >/dev/null
MAKE="${MAKE:-$(command -v gmake || command -v make)}"
"${MAKE}" deps
"${MAKE}"
cp dist/crsqlite.wasm "${SCRIPT_DIR}/build/wasm/crsqlite.wasm"
cp dist/crsqlite.mjs "${SCRIPT_DIR}/build/wasm/crsqlite.mjs"
if [ -f "dist/crsqlite-sync.wasm" ]; then
  cp dist/crsqlite-sync.wasm "${SCRIPT_DIR}/build/wasm/crsqlite-sync.wasm"
fi
if [ -f "dist/crsqlite-sync.mjs" ]; then
  cp dist/crsqlite-sync.mjs "${SCRIPT_DIR}/build/wasm/crsqlite-sync.mjs"
fi
popd >/dev/null
