#!/bin/bash
# Builds a universal, ad-hoc signed copyPaster.app and attaches it as a zip to a GitHub release.
#
# Usage: scripts/release.sh [tag]
#   tag defaults to v<MARKETING_VERSION>. The tag must already exist on GitHub and point at HEAD.
#   Re-running replaces the zip on that release.
set -euo pipefail

cd "$(dirname "$0")/.."

version=$(grep -m1 'MARKETING_VERSION' copyPaster.xcodeproj/project.pbxproj | sed -E 's/.*= *([^;]+);/\1/')
tag=${1:-v$version}
zip_name="copyPaster-$version.zip"
derived=build/release

if [[ -n $(git status --porcelain) ]]; then
    echo "error: working tree has uncommitted changes" >&2
    exit 1
fi
if [[ $(git rev-list -n1 "$tag" 2>/dev/null) != $(git rev-parse HEAD) ]]; then
    echo "error: tag $tag does not point at HEAD" >&2
    exit 1
fi
gh release view "$tag" >/dev/null

rm -rf "$derived"
xcodebuild -project copyPaster.xcodeproj -scheme copyPaster -configuration Release \
    -derivedDataPath "$derived" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
    -quiet build

app="$derived/Build/Products/Release/copyPaster.app"
lipo -info "$app/Contents/MacOS/copyPaster"
codesign --verify --deep --strict "$app"

ditto -c -k --keepParent "$app" "build/$zip_name"
gh release upload "$tag" "build/$zip_name" --clobber
echo "Uploaded $zip_name to $tag"
