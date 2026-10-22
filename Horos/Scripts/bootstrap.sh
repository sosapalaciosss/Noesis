#!/usr/bin/env bash
# HOROS — one-shot local bootstrap for macOS.
#   1. checks that Xcode is installed and selected
#   2. installs XcodeGen (Homebrew, or the prebuilt release binary as fallback)
#   3. generates Horos.xcodeproj
#   4. builds all five targets for a generic iOS Simulator (no signing)
#   5. opens the project in Xcode
#
# Usage:  ./Scripts/bootstrap.sh [--no-open] [--no-build]
set -uo pipefail

cd "$(dirname "$0")/.."
OPEN=1
BUILD=1
for arg in "$@"; do
  case "$arg" in
    --no-open) OPEN=0 ;;
    --no-build) BUILD=0 ;;
  esac
done

# ── 1. Xcode ─────────────────────────────────────────────────────────────────
XCODE_APP=""
# Prefer whatever xcode-select already points at, if it is a full Xcode.
CURRENT_DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
case "$CURRENT_DEV_DIR" in
  */Contents/Developer) XCODE_APP="${CURRENT_DEV_DIR%/Contents/Developer}" ;;
esac
# Otherwise look in the usual folders, then ask Spotlight (finds it anywhere,
# e.g. still sitting in Downloads or on the Desktop).
if [ ! -d "$XCODE_APP" ]; then
  XCODE_APP=""
  for candidate in /Applications/Xcode*.app "$HOME/Applications"/Xcode*.app \
                   "$HOME/Downloads"/Xcode*.app "$HOME/Desktop"/Xcode*.app; do
    [ -d "$candidate" ] && XCODE_APP="$candidate" && break
  done
fi
if [ -z "$XCODE_APP" ] && command -v mdfind >/dev/null 2>&1; then
  XCODE_APP="$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null | head -1)"
fi
if [ -n "$XCODE_APP" ] && [ ! -x "$XCODE_APP/Contents/Developer/usr/bin/xcodebuild" ]; then
  echo "✖ Found $XCODE_APP but it is not a complete Xcode (no xcodebuild inside)." >&2
  XCODE_APP=""
fi

if [ -z "$XCODE_APP" ]; then
  cat >&2 <<'MSG'
✖ Xcode is not installed.
  On macOS 14 or newer: install Xcode from the App Store.
  On macOS 13: the App Store will not show it. Download Xcode 15.2 instead:
    1. Open https://developer.apple.com/download/all/ in Safari and sign in
       with your Apple ID (free, no developer program needed).
    2. Search for "Xcode 15.2" and download Xcode_15.2.xip (about 7 GB).
    3. Double-click the .xip in Downloads, wait for it to unpack, then drag
       the Xcode app into your Applications folder.
  Open Xcode once, accept the license, let it finish "Installing components"
  (tick iOS if it asks which platforms to install), then run this script again.
MSG
  exit 1
fi

echo "▸ Found Xcode at: $XCODE_APP"
DEVELOPER_DIR_CURRENT="$(xcode-select -p 2>/dev/null || true)"
case "$DEVELOPER_DIR_CURRENT" in
  "$XCODE_APP/Contents/Developer") ;;
  *)
    echo "▸ Pointing the command line tools at $XCODE_APP (you may be asked for your Mac password)"
    sudo xcode-select -s "$XCODE_APP/Contents/Developer" || exit 1
    ;;
esac

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "▸ Accepting the Xcode license (you may be asked for your Mac password)"
  sudo xcodebuild -license accept || exit 1
fi
echo "▸ Using $(xcodebuild -version | head -1) at $(xcode-select -p)"

# ── 2. XcodeGen ──────────────────────────────────────────────────────────────
TOOLS="$HOME/.horos/tools"
export PATH="$TOOLS/xcodegen/bin:$PATH"

if ! command -v xcodegen >/dev/null 2>&1; then
  INSTALLED=0
  if command -v brew >/dev/null 2>&1; then
    echo "▸ Trying to install XcodeGen with Homebrew…"
    if brew install xcodegen >/dev/null 2>&1; then
      INSTALLED=1
    fi
  fi
  if [ "$INSTALLED" = "0" ]; then
    echo "▸ Downloading the prebuilt XcodeGen release…"
    mkdir -p "$TOOLS"
    curl -fL --progress-bar -o "$TOOLS/xcodegen.zip" \
      https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip || {
        echo "✖ Could not download XcodeGen. Check your internet connection and try again." >&2
        exit 1
      }
    (cd "$TOOLS" && rm -rf xcodegen && unzip -q -o xcodegen.zip) || exit 1
    chmod +x "$TOOLS/xcodegen/bin/xcodegen"
  fi
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "✖ XcodeGen is still not available." >&2
  exit 1
fi
echo "▸ XcodeGen $(xcodegen --version 2>/dev/null | head -1)"

# ── 3. Generate ──────────────────────────────────────────────────────────────
echo "▸ Generating Horos.xcodeproj"
xcodegen generate || exit 1

# ── 4. Build ─────────────────────────────────────────────────────────────────
if [ "$BUILD" = "1" ]; then
  echo "▸ Building all targets for the iOS Simulator (unsigned) — this can take several minutes the first time"
  xcodebuild \
    -project Horos.xcodeproj \
    -scheme Horos \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    build > build.log 2>&1
  BUILD_STATUS=$?

  grep -E "error:|BUILD" build.log | sort -u | head -40 || true

  if [ "$BUILD_STATUS" = "0" ] && grep -q "BUILD SUCCEEDED" build.log; then
    echo "✔ BUILD SUCCEEDED"
  else
    echo "✖ Build failed — the lines above show why; the full log is in Horos/build.log" >&2
    [ "$OPEN" = "1" ] && open Horos.xcodeproj
    exit 1
  fi
fi

# ── 5. Open ──────────────────────────────────────────────────────────────────
if [ "$OPEN" = "1" ]; then
  echo "▸ Opening in Xcode"
  open Horos.xcodeproj
fi
