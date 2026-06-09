#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export SWIFTPM_MODULECACHE_OVERRIDE="$REPO_ROOT/EngineCore/.build/module-cache"
export SWIFTPM_TESTS_MODULECACHE="$REPO_ROOT/EngineCore/.build/tests-module-cache"
export CLANG_MODULE_CACHE_PATH="$REPO_ROOT/EngineCore/.build/clang-module-cache"

cd "$REPO_ROOT"

xcrun swift test \
  --package-path EngineCore \
  --scratch-path EngineCore/.build \
  --cache-path EngineCore/.build/cache \
  --config-path EngineCore/.build/config \
  --security-path EngineCore/.build/security \
  --manifest-cache local \
  --disable-sandbox
