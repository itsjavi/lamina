#!/usr/bin/env bash
# Assembles build/<Name>.app from the SwiftPM product.
#   scripts/build-app.sh            # "Compositor.app": release build with the updater
#   scripts/build-app.sh dev        # "Compositor Dev.app": debug build, separate id, sandbox container and prefs, no updater
#   SIGN_IDENTITY="Developer ID Application: …"   # sign with a real identity (default: ad-hoc)
#   HARDENED=1                                    # hardened runtime + secure timestamp (release.sh sets it)
#   ARCH=arm64                                    # build for one architecture (default: this Mac's)
#   VERSION=1.2.3 BUILD=456                       # override ./VERSION and the commit-count build number
set -euo pipefail
cd "$(dirname "$0")/.."

VARIANT="${1:-release}"
BUNDLE_ID="com.itsjavi.compositor"
case "$VARIANT" in
  release) CONFIG="${CONFIG:-release}"; NAME="Compositor"; ID="$BUNDLE_ID" ;;
  dev)     CONFIG="${CONFIG:-debug}";   NAME="Compositor Dev"; ID="$BUNDLE_ID.dev" ;;
  *) echo "unknown variant: $VARIANT (use release or dev)" >&2; exit 64 ;;
esac
APP="build/$NAME.app"

# The version lives in ./VERSION; the build number counts commits, so it only ever grows
# (Sparkle compares it). CI sets both from the tag and a full clone.
VERSION="${VERSION:-$(tr -d '[:space:]' < VERSION)}"
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

SWIFT_FLAGS=(-c "$CONFIG" --disable-keychain)  # never a Keychain prompt when packages download
if [ -n "${ARCH:-}" ]; then SWIFT_FLAGS+=(--arch "$ARCH"); fi
swift build "${SWIFT_FLAGS[@]}" --product Compositor
BIN_DIR="$(swift build "${SWIFT_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
# Sparkle (updates); ditto keeps the framework's symlinks.
ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
# Sparkle ships universal; a one-architecture build keeps only that slice (signed again below).
if [ -n "${ARCH:-}" ]; then
  find "$APP/Contents/Frameworks/Sparkle.framework" -type f -perm -u+x | while read -r binary; do
    archs="$(lipo -archs "$binary" 2>/dev/null || true)"
    if [[ " $archs " == *" $ARCH "* && "$archs" != "$ARCH" ]]; then lipo -thin "$ARCH" "$binary" -output "$binary"; fi
  done
fi
cp "$BIN_DIR/Compositor" "$APP/Contents/MacOS/Compositor"
# SwiftPM also adds this checkout's build folder as an rpath; the bundle only needs @-relative ones.
otool -l "$APP/Contents/MacOS/Compositor" | awk '/LC_RPATH/ { getline; getline; print $2 }' | { grep '^/' || true; } |
  while read -r path; do install_name_tool -delete_rpath "$path" "$APP/Contents/MacOS/Compositor" 2>/dev/null; done
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
# Third-party license notices, shown by the standard About panel; fails if a package has no license file.
swift scripts/acknowledgements.swift Package.resolved .build/checkouts "$APP/Contents/Resources/Credits.html"

# The Icon Composer icon (Resources/AppIcon.icon) → Assets.car (Liquid Glass; light, dark and tinted),
# plus AppIcon.icns for anything that can't read it. Info.plist already names both (CFBundleIconName,
# CFBundleIconFile), so actool's partial Info.plist is only a required by-product. Absolute paths:
# actool hands them to a long-lived daemon, which resolves relative ones against the folder of the
# build that started it.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# actool reports problems in its output and can still exit 0, so check for the compiled files too.
if ! xcrun actool "$PWD/Resources/AppIcon.icon" --compile "$PWD/$APP/Contents/Resources" --app-icon AppIcon \
    --platform macosx --target-device mac --minimum-deployment-target 26.0 \
    --output-partial-info-plist "$WORK/icon.plist" --errors --warnings >"$WORK/actool.log" ||
  [[ ! -f "$APP/Contents/Resources/Assets.car" || ! -f "$APP/Contents/Resources/AppIcon.icns" ]]; then
  cat "$WORK/actool.log" >&2
  echo "✗ actool couldn't compile Resources/AppIcon.icon" >&2
  exit 1
fi

PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" \
  -c "Add :CFBundleVersion string $BUILD" "$PLIST"
# Updates (Sparkle): the feed URL is in Info.plist; the public EdDSA key comes from
# Resources/SparklePublicKey.txt. The Dev build has no updater, so it never replaces itself.
if [ "$VARIANT" = dev ]; then
  /usr/libexec/PlistBuddy -c "Delete :SUFeedURL" -c "Set :CFBundleIdentifier $ID" \
    -c "Set :CFBundleName $NAME" -c "Set :CFBundleDisplayName $NAME" "$PLIST"
else
  SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-$(cat Resources/SparklePublicKey.txt 2>/dev/null | tr -d '[:space:]')}"
  if [ -n "$SPARKLE_PUBLIC_KEY" ]; then
    /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_KEY" "$PLIST"
  else
    echo "⚠ No Resources/SparklePublicKey.txt: this build can't update itself" >&2
  fi
fi

# The App Sandbox entitlements, naming this variant's Sparkle services.
ENTITLEMENTS="$WORK/Compositor.entitlements"
sed "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$ID/g" Resources/Compositor.entitlements > "$ENTITLEMENTS"
SIGN_FLAGS=(--force --sign "${SIGN_IDENTITY:--}")
if [ -n "${HARDENED:-}" ]; then
  SIGN_FLAGS+=(--options runtime)
  if [ -n "${SIGN_IDENTITY:-}" ] && [ "$SIGN_IDENTITY" != "-" ]; then
    # Notarization wants a secure timestamp, which ad-hoc signatures can't have.
    SIGN_FLAGS+=(--timestamp)
  else
    # Ad-hoc signatures have no Team ID, so library validation would refuse Sparkle.framework.
    /usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$ENTITLEMENTS"
  fi
fi

# codesign without its "replacing existing signature" note (Sparkle's parts come pre-signed).
sign() { codesign "$@" 2> >(grep -v ': replacing existing signature$' >&2); }

# Nested code is signed before the bundle that contains it, innermost first (Sparkle's order;
# the Downloader service keeps its own entitlements).
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
sign "${SIGN_FLAGS[@]}" "$SPARKLE/XPCServices/Installer.xpc"
sign "${SIGN_FLAGS[@]}" --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
sign "${SIGN_FLAGS[@]}" "$SPARKLE/Autoupdate"
sign "${SIGN_FLAGS[@]}" "$SPARKLE/Updater.app"
sign "${SIGN_FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
sign "${SIGN_FLAGS[@]}" --entitlements "$ENTITLEMENTS" "$APP"
echo "✓ Built $APP ($VERSION, build $BUILD)"
