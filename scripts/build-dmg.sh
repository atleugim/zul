#!/bin/zsh
# Builds a Release Zul.app and packages it as build/Zul-<version>.dmg.
set -euo pipefail

root=${0:A:h:h}
build_dir=$root/build
staging=$build_dir/dmg

[[ -d $root/Vendor/build/MediaRemoteAdapter.framework ]] || "$root/scripts/build-adapter.sh"

# The generic destination builds a universal binary; without it only the host's architecture is built.
xcodebuild -quiet -project "$root/Zul.xcodeproj" -scheme Zul -configuration Release \
  -destination "generic/platform=macOS" -derivedDataPath "$build_dir/DerivedData" build

app=$build_dir/DerivedData/Build/Products/Release/Zul.app
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")
dmg=$build_dir/Zul-$version.dmg

rm -rf "$staging"
mkdir -p "$staging"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname Zul -srcfolder "$staging" -ov -format UDZO "$dmg"
rm -rf "$staging"

echo "$dmg"
