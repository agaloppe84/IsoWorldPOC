#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$REPO_ROOT/IsoWorldPOC/IsoWorldPOC.xcodeproj"
SAFE_XCODEBUILD="$REPO_ROOT/scripts/xcodebuild-safe.sh"
SAFE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
LIST_SCHEMES_WITH_XCODEBUILD=false

if [[ "${1:-}" == "--list-schemes" ]]; then
  LIST_SCHEMES_WITH_XCODEBUILD=true
fi

section() {
  printf '\n== %s ==\n' "$1"
}

run_optional() {
  local label="$1"
  shift

  printf '%s: ' "$label"
  if "$@" 2>&1; then
    return 0
  fi

  printf '%s unavailable\n' "$label"
}

section "IsoWorld toolchain doctor"
date
printf 'Repo root: %s\n' "$REPO_ROOT"
printf 'Project: %s\n' "$PROJECT_PATH"

section "Global developer state"
run_optional "xcode-select path" xcode-select -p
printf 'DEVELOPER_DIR env: %s\n' "${DEVELOPER_DIR:-<unset>}"

section "Safe Xcode state"
printf 'Safe DEVELOPER_DIR: %s\n' "$SAFE_DEVELOPER_DIR"
"$SAFE_XCODEBUILD" -version
DEVELOPER_DIR="$SAFE_DEVELOPER_DIR" xcrun swift --version
printf 'swift path: %s\n' "$(DEVELOPER_DIR="$SAFE_DEVELOPER_DIR" xcrun --find swift)"
printf 'metal path: %s\n' "$(DEVELOPER_DIR="$SAFE_DEVELOPER_DIR" xcrun --find metal)"

section "Project schemes"
printf 'Known schemes:\n'
printf '  EngineCore\n'
printf '  IsoWorldPOC\n'
if [[ "$LIST_SCHEMES_WITH_XCODEBUILD" == true ]]; then
  "$SAFE_XCODEBUILD" -project "$PROJECT_PATH" -list
else
  printf 'Pass --list-schemes to run xcodebuild -list explicitly.\n'
fi

section "Recommended build command"
printf './scripts/xcodebuild-safe.sh -project IsoWorldPOC/IsoWorldPOC.xcodeproj -scheme IsoWorldPOC -destination '\''platform=macOS'\'' build\n'
