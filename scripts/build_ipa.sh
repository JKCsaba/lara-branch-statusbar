#!/bin/bash
set -euo pipefail

rm -rf build/
mkdir -p build

echo "Build Started!"
echo

xcodebuild \
  -project lara.xcodeproj \
  -scheme lara \
  -configuration Debug \
  -sdk iphoneos \
  -arch arm64e \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="Config/lara.entitlements" \
  archive \
  -archivePath "$PWD/build/lara.xcarchive" 2>&1 | xcpretty

APP_PATH="$PWD/build/lara.xcarchive/Products/Applications/lara.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Missing app at $APP_PATH"
  exit 1
fi
rm -rf "$PWD/build/Payload"
mkdir -p "$PWD/build/Payload"
cp -R "$APP_PATH" "$PWD/build/Payload/"

# A separate image supplies executable SpringBoard callbacks after Lara exits.
# Its architecture and signature must match the phone and the sideloaded app.
mkdir -p "$PWD/build/Payload/lara.app/Frameworks"
xcrun --sdk iphoneos clang -arch arm64e -dynamiclib -fobjc-arc -fblocks \
  -miphoneos-version-min=18.0 -O2 \
  -framework Foundation -framework UIKit -framework QuartzCore \
  -Wl,-install_name,@rpath/LaraRotationHook.dylib \
  RotationHook/LaraRotationHook.m \
  -o "$PWD/build/Payload/lara.app/Frameworks/LaraRotationHook.dylib"

plutil -replace UIFileSharingEnabled -bool YES "$PWD/build/Payload/lara.app/Info.plist"

if ! command -v ldid >/dev/null 2>&1; then
  echo "ERROR: ldid not installed. Install with: brew install ldid" >&2
  exit 1
fi
ldid -SConfig/lara.entitlements "$PWD/build/Payload/lara.app/lara"
ldid -SConfig/lara.entitlements "$PWD/build/Payload/lara.app/Frameworks/LaraRotationHook.dylib"
(cd "$PWD/build" && /usr/bin/zip -qry lara.ipa Payload)

echo
echo "build successful!"
echo "ipa at: build/lara.ipa"
exit 0
