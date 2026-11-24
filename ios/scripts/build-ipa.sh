#!/bin/sh
# Builds an unsigned Release IPA for sideloading (SideStore / AltStore sign it with your Apple ID on import).
# Usage: ios/scripts/build-ipa.sh   →   ios/build/OpenAcoustic.ipa
set -eu

cd "$(dirname "$0")/.."
OUT="$PWD/build"
DD="$OUT/DerivedData"

xcodebuild -project OpenAcoustic.xcodeproj -scheme OpenAcoustic -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build -quiet

APP="$DD/Build/Products/Release-iphoneos/OpenAcoustic.app"
STAGE="$OUT/ipa"
rm -rf "$STAGE" "$OUT/OpenAcoustic.ipa"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"
(cd "$STAGE" && zip -qry "$OUT/OpenAcoustic.ipa" Payload)
rm -rf "$STAGE"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")
echo "Built $OUT/OpenAcoustic.ipa (version $VERSION, $(du -h "$OUT/OpenAcoustic.ipa" | cut -f1))"
