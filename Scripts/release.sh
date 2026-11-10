#!/bin/bash
# Builds a universal, ad-hoc signed JayceMouse.app and packages it for a GitHub release.
# Usage: Scripts/release.sh [version]   (default: 1.0.0)
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${1:-1.0.0}"
ZIP="dist/JayceMouse-${VERSION}.zip"

UNIVERSAL=1 VERSION="$VERSION" Scripts/build-app.sh

mkdir -p dist
rm -f "$ZIP" "$ZIP.sha256" dist/JayceMouse.zip
ditto -c -k --norsrc --noextattr --keepParent build/JayceMouse.app "$ZIP"
(cd dist && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
# Same file under a fixed name, so releases/latest/download/JayceMouse.zip always serves the newest build.
cp "$ZIP" dist/JayceMouse.zip

lipo -archs build/JayceMouse.app/Contents/MacOS/JayceMouse
echo "Packaged $ZIP"
