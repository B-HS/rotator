#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_dir="$project_dir/build/Rotator.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/App/Info.plist")
archive="$project_dir/dist/Rotator-$version-macOS-universal.zip"

test -d "$app_dir"
test -f "$archive"

if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$archive" --keychain-profile "$NOTARY_PROFILE" --wait
elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
    xcrun notarytool submit "$archive" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_APP_SPECIFIC_PASSWORD" \
        --team-id "$APPLE_TEAM_ID" \
        --wait
else
    echo "NOTARY_PROFILE 또는 APPLE_ID / APPLE_APP_SPECIFIC_PASSWORD / APPLE_TEAM_ID가 필요합니다." >&2
    exit 2
fi
xcrun stapler staple "$app_dir"
xcrun stapler validate "$app_dir"

rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"
echo "공증 완료: $archive"
