#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build-cache/clang"
export MACOSX_DEPLOYMENT_TARGET=13.0
swift test --package-path "$ROOT/native" --scratch-path "$ROOT/.build-cache/swift" --disable-sandbox "$@"
