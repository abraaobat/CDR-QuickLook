#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
BUILD_ROOT="$SCRIPT_DIR/build"
OUTPUT_ROOT=${1:-"$SCRIPT_DIR/dist"}
APP_NAME="CDR QuickLook.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SCRIPT_DIR/Resources/Host-Info.plist")
APP="$BUILD_ROOT/$APP_NAME"
PREVIEW="$APP/Contents/PlugIns/CDRPreview.appex"
THUMBNAIL="$APP/Contents/PlugIns/CDRThumbnail.appex"
COMMON="$SCRIPT_DIR/Sources/Common/CDRArchive.m"
INCLUDE="-I$SCRIPT_DIR/Sources/Common"
BASE_FLAGS=(-arch arm64 -arch x86_64 -mmacosx-version-min=12.4 -Os -fobjc-arc -fmodules
            -fmodules-cache-path="$BUILD_ROOT/ModuleCache" -Wall -Wextra)

rm -rf "$BUILD_ROOT"
mkdir -p "$APP/Contents/MacOS" \
         "$PREVIEW/Contents/MacOS" \
         "$THUMBNAIL/Contents/MacOS" \
         "$OUTPUT_ROOT"

cp "$SCRIPT_DIR/Resources/Host-Info.plist" "$APP/Contents/Info.plist"
cp "$SCRIPT_DIR/Resources/Preview-Info.plist" "$PREVIEW/Contents/Info.plist"
cp "$SCRIPT_DIR/Resources/Thumbnail-Info.plist" "$THUMBNAIL/Contents/Info.plist"

clang "${BASE_FLAGS[@]}" \
    "$SCRIPT_DIR/Sources/Host/main.m" \
    -framework AppKit -framework Foundation \
    -o "$APP/Contents/MacOS/CDRQuickLook"

clang "${BASE_FLAGS[@]}" -fapplication-extension $INCLUDE \
    "$SCRIPT_DIR/Sources/Preview/PreviewProvider.m" "$COMMON" \
    -Wl,-e,_NSExtensionMain \
    -framework AppKit -framework Foundation -framework PDFKit -framework QuickLookUI \
    -lz -o "$PREVIEW/Contents/MacOS/CDRPreview"

clang "${BASE_FLAGS[@]}" -fapplication-extension $INCLUDE \
    "$SCRIPT_DIR/Sources/Thumbnail/ThumbnailProvider.m" "$COMMON" \
    -Wl,-e,_NSExtensionMain \
    -framework CoreGraphics -framework Foundation -framework ImageIO \
    -framework QuickLookThumbnailing \
    -lz -o "$THUMBNAIL/Contents/MacOS/CDRThumbnail"

clang "${BASE_FLAGS[@]}" $INCLUDE \
    "$SCRIPT_DIR/Sources/Common/ArchiveTest.m" "$COMMON" \
    -framework Foundation -lz \
    -o "$BUILD_ROOT/cdrarchive-test"

plutil -lint "$APP/Contents/Info.plist" "$PREVIEW/Contents/Info.plist" "$THUMBNAIL/Contents/Info.plist"
codesign --force --sign - --entitlements "$SCRIPT_DIR/Resources/Extension.entitlements" "$PREVIEW"
codesign --force --sign - --entitlements "$SCRIPT_DIR/Resources/Extension.entitlements" "$THUMBNAIL"
codesign --force --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

rm -rf "$OUTPUT_ROOT/$APP_NAME"
rm -f "$OUTPUT_ROOT/CDR-QuickLook.zip" \
      "$OUTPUT_ROOT/CDR-QuickLook-$VERSION.zip" \
      "$OUTPUT_ROOT/CDR-QuickLook-$VERSION.dmg"
ditto "$APP" "$OUTPUT_ROOT/$APP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT_ROOT/CDR-QuickLook-$VERSION.zip"
cp "$OUTPUT_ROOT/CDR-QuickLook-$VERSION.zip" "$OUTPUT_ROOT/CDR-QuickLook.zip"

DMG_ROOT="$BUILD_ROOT/dmg-root"
mkdir -p "$DMG_ROOT"
ditto "$APP" "$DMG_ROOT/$APP_NAME"
ln -s /Applications "$DMG_ROOT/Applications"
cp "$SCRIPT_DIR/Resources/DMG-README.txt" "$DMG_ROOT/LEIA-ME.txt"
hdiutil create -quiet -volname "CDR QuickLook" -srcfolder "$DMG_ROOT" \
    -ov -format UDZO "$OUTPUT_ROOT/CDR-QuickLook-$VERSION.dmg"
if [[ ! -f "$OUTPUT_ROOT/CDR-QuickLook-$VERSION.dmg" ]]; then
    echo "Falha ao criar o instalador DMG." >&2
    exit 1
fi

echo "$OUTPUT_ROOT/$APP_NAME"
