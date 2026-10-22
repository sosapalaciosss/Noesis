#!/usr/bin/env bash
# HOROS — one-shot local bootstrap for macOS.
#   1. installs XcodeGen via Homebrew if missing
#   2. generates Horos.xcodeproj
#   3. builds all five targets for a generic iOS Simulator (no signing)
#   4. opens the project in Xcode
#
# Usage:  ./Scripts/bootstrap.sh [--no-open] [--no-build]
set -euo pipefail

cd "$(dirname "$0")/.."
OPEN=1
BUILD=1
for arg in "$@"; do
  case "$arg" in
    --no-open) OPEN=0 ;;
    --no-build) BUILD=0 ;;
  esac
done

if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to install XcodeGen: https://brew.sh" >&2
    exit 1
  fi
  echo "▸ Installing XcodeGen…"
  brew install xcodegen
fi

echo "▸ Generating Horos.xcodeproj"
xcodegen generate

if [ "$BUILD" = "1" ]; then
  echo "▸ Building all targets for the iOS Simulator (unsigned)"
  xcodebuild \
    -project Horos.xcodeproj \
    -scheme Horos \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    build | tee build.log | grep -E "error:|warning:|BUILD" || true

  if grep -q "BUILD SUCCEEDED" build.log; then
    echo "✔ BUILD SUCCEEDED"
  else
    echo "✖ Build failed — see build.log" >&2
    exit 1
  fi
fi

if [ "$OPEN" = "1" ]; then
  echo "▸ Opening in Xcode"
  open Horos.xcodeproj
fi
