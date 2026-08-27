#!/usr/bin/env bash
set -euo pipefail
mkdir -p "./build/wasm"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EMSDK_DIR="${REPO_ROOT}/deps/emsdk"
WA_SQLITE_DIR="${REPO_ROOT}/wa-sqlite"

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
"${MAKE}"
cp dist/crsqlite.wasm "../core/build/wasm/crsqlite.wasm"
cp dist/crsqlite.mjs "../core/build/wasm/crsqlite.mjs"
popd >/dev/null
