#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build_dir="$project_dir/build"
dist_dir="$project_dir/dist"
app_dir="$build_dir/Rotator.app"
iconset_dir="$build_dir/AppIcon.iconset"
icon_file="$build_dir/AppIcon.icns"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/App/Info.plist")
build_number="${BUILD_NUMBER:-1}"

cd "$project_dir"
swift build -c release --arch arm64 --disable-sandbox
swift build -c release --arch x86_64 --disable-sandbox

rm -rf "$iconset_dir"
swift "$project_dir/scripts/generate-icon.swift" "$iconset_dir"
iconutil -c icns "$iconset_dir" -o "$icon_file"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
lipo -create \
    "$project_dir/.build/arm64-apple-macosx/release/Rotator" \
    "$project_dir/.build/x86_64-apple-macosx/release/Rotator" \
    -output "$app_dir/Contents/MacOS/Rotator"
cp "$project_dir/App/Info.plist" "$app_dir/Contents/Info.plist"
cp "$icon_file" "$app_dir/Contents/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app_dir/Contents/Info.plist"

if [ "${SIGNING_IDENTITY:--}" = "-" ]; then
    codesign --force --sign - "$app_dir"
else
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app_dir"
fi

codesign --verify --deep --strict "$app_dir"

mkdir -p "$dist_dir"
archive="$dist_dir/Rotator-$version-macOS-universal.zip"
rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"

echo "앱: $app_dir"
echo "배포 파일: $archive"
