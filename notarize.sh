#!/bin/zsh
set -e

# Notarization script for macOS apps
# Usage: ./notarize.sh ["Developer ID Application: Michael Bino (43L352U8Y8)"] ["kona-notary"]

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

IDENTITY="${1:-${HASTE_SIGN_IDENTITY:-Developer ID Application: Michael Bino (43L352U8Y8)}}"
PROFILE="${2:-${HASTE_NOTARY_PROFILE:-kona-notary}}"
APP_BUNDLE="Haste.app"
ZIP_NAME="Haste.zip"
FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"

echo "==> Notarization target: $APP_BUNDLE"
echo "==> Signing Identity: $IDENTITY"
echo "==> Notary Keychain Profile: $PROFILE"

# Verify Developer ID certificate presence
if ! security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "error: Signing identity '$IDENTITY' not found in keychain." >&2
    exit 1
fi

# Build fresh bundle
./build.sh

echo "==> Signing inside-out with hardened runtime (-o runtime)..."
if [[ -d "$FRAMEWORK" ]]; then
    codesign -f -s "$IDENTITY" -o runtime "$FRAMEWORK/Versions/B/Autoupdate"
    codesign -f -s "$IDENTITY" -o runtime "$FRAMEWORK/Versions/B/Updater.app"
    codesign -f -s "$IDENTITY" -o runtime --preserve-metadata=entitlements "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc"
    codesign -f -s "$IDENTITY" -o runtime --preserve-metadata=entitlements "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc"
    codesign -f -s "$IDENTITY" -o runtime "$FRAMEWORK"
fi

codesign -f -s "$IDENTITY" -o runtime "$APP_BUNDLE"

echo "==> Verifying codesign integrity..."
codesign --verify --deep --strict "$APP_BUNDLE"

echo "==> Packaging into $ZIP_NAME for Apple notarization..."
rm -f "$ZIP_NAME"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

echo "==> Submitting to Apple Notary Service via notarytool..."
xcrun notarytool submit "$ZIP_NAME" --keychain-profile "$PROFILE" --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "$APP_BUNDLE"

echo "==> Assessing Gatekeeper acceptance..."
spctl --assess --type execute --verbose "$APP_BUNDLE"

echo "==> Re-packaging stapled app into $ZIP_NAME..."
rm -f "$ZIP_NAME"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

echo "==> Success: $APP_BUNDLE has been signed, notarized, stapled, and packaged into $ZIP_NAME."
