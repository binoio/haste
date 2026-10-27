#!/bin/zsh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

VERSION=$(tr -d '[:space:]' < VERSION)
TAG="v${VERSION}"
REPO="binoio/haste"
APP_BUNDLE="Haste.app"
ZIP_NAME="Haste.zip"

echo "==> Preparing Haste release ${VERSION} (${TAG})..."

# Check git status
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Notice: Uncommitted changes detected. Committing version ${VERSION}..."
    git add -A
    git commit -m "Prepare release ${VERSION}" || true
    git push origin main
fi

# Run test suite
echo "==> Running test suite..."
./test.sh

# Run notarization
echo "==> Building, signing, and notarizing..."
./notarize.sh

# Check if tag exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Warning: Tag $TAG already exists locally. Skipping local tag creation."
else
    git tag "$TAG"
    git push origin "$TAG"
fi

# Publish GitHub Release with notarized zip
echo "==> Publishing release $TAG to GitHub..."
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" "$ZIP_NAME" --repo "$REPO" --clobber
else
    gh release create "$TAG" "$ZIP_NAME" --repo "$REPO" --title "Haste ${VERSION}" --generate-notes
fi

echo "==> Release ${TAG} published successfully to https://github.com/${REPO}/releases/tag/${TAG}!"
