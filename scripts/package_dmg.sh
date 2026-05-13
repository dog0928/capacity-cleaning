#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="capacity-cleaning"
CONFIGURATION="${CONFIGURATION:-release}"
DMG_NAME="${DMG_NAME:-$APP_NAME.dmg}"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_DIR="$ROOT_DIR/.build/package"
APP_DIR="$PACKAGE_DIR/$APP_NAME.app"
DMG_ROOT="$PACKAGE_DIR/dmg-root"
BACKGROUND_DIR="$DMG_ROOT/.background"
BACKGROUND_PATH="$BACKGROUND_DIR/background.png"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_PATH="$DIST_DIR/$DMG_NAME"
MOUNT_DIR=""

cleanup() {
    if [ -n "$MOUNT_DIR" ]; then
        /usr/bin/hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || /usr/bin/hdiutil detach -force "$MOUNT_DIR" -quiet 2>/dev/null || true
    fi
}
trap cleanup EXIT

cd "$ROOT_DIR"

/usr/bin/swift build -c "$CONFIGURATION"

/bin/rm -rf "$APP_DIR" "$DMG_ROOT"
/bin/mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$DIST_DIR"

/bin/cp ".build/$CONFIGURATION/$APP_NAME" "$MACOS_DIR/$APP_NAME"
/bin/chmod 755 "$MACOS_DIR/$APP_NAME"
/bin/cp "$ROOT_DIR/packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
/usr/bin/swift "$ROOT_DIR/scripts/create_app_icon.swift" "$PACKAGE_DIR/AppIcon.iconset"
/usr/bin/iconutil -c icns "$PACKAGE_DIR/AppIcon.iconset" -o "$RESOURCES_DIR/AppIcon.icns"

if [ -x /usr/bin/codesign ]; then
    /usr/bin/codesign --force --sign - "$APP_DIR"
fi

/bin/mkdir -p "$DMG_ROOT"
/bin/cp -R "$APP_DIR" "$DMG_ROOT/$APP_NAME.app"
/bin/mkdir -p "$BACKGROUND_DIR"
/usr/bin/swift "$ROOT_DIR/scripts/create_dmg_background.swift" "$BACKGROUND_PATH" "$APP_NAME"
/bin/cp "$BACKGROUND_PATH" "$DMG_ROOT/Drop $APP_NAME.app to Applications.png"

/bin/rm -f "$DMG_PATH"
/bin/rm -f "$PACKAGE_DIR/$APP_NAME-rw.dmg"
/usr/bin/hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -fs HFS+ \
    -format UDRW \
    "$PACKAGE_DIR/$APP_NAME-rw.dmg"

MOUNT_DIR="$(/usr/bin/hdiutil attach "$PACKAGE_DIR/$APP_NAME-rw.dmg" -readwrite -noverify -noautoopen | /usr/bin/awk '/Apple_HFS/ {for (i = 3; i <= NF; i++) printf "%s%s", $i, (i < NF ? OFS : ORS); exit}')"
if [ -z "$MOUNT_DIR" ] || [ ! -d "$MOUNT_DIR" ]; then
    echo "error: failed to mount writable DMG" >&2
    exit 1
fi

if ! /usr/bin/osascript >/dev/null <<EOF
tell application "Finder"
    make new alias file at (POSIX file "$MOUNT_DIR" as alias) to (POSIX file "/Applications" as alias) with properties {name:"Applications"}
end tell
EOF
then
    echo "warning: Finder alias could not be created; using /Applications symlink fallback." >&2
    /bin/ln -sf /Applications "$MOUNT_DIR/Applications"
fi

if LAYOUT_RESULT="$(/usr/bin/osascript <<EOF
tell application "Finder"
    set backgroundWasApplied to false
    set dmgFolder to (POSIX file "$MOUNT_DIR" as alias)
    open dmgFolder
    delay 1
    set dmgWindow to container window of dmgFolder
    try
        set current view of dmgWindow to icon view
    end try
    try
        set toolbar visible of dmgWindow to false
    end try
    try
        set statusbar visible of dmgWindow to false
    end try
    try
        set bounds of dmgWindow to {120, 120, 840, 560}
    end try
    set viewOptions to icon view options of dmgWindow
    tell viewOptions
        set arrangement to not arranged
        set icon size to 96
        try
            set background picture to (file "background.png" of folder ".background" of dmgFolder as alias)
            set backgroundWasApplied to true
        on error
            try
                set background picture to (POSIX file "$MOUNT_DIR/.background/background.png" as alias)
                set backgroundWasApplied to true
            end try
        end try
    end tell
    delay 0.5
    try
        set position of item "$APP_NAME.app" of dmgFolder to {166, 238}
    end try
    try
        set position of item "Applications" of dmgFolder to {560, 238}
    end try
    try
        set position of item "Drop $APP_NAME.app to Applications.png" of dmgFolder to {360, 356}
    end try
    try
        close dmgWindow
    end try
    try
        open dmgFolder
    end try
    try
        update dmgFolder without registering applications
    end try
    do shell script "/bin/sync"
    delay 2
    return backgroundWasApplied as string
end tell
EOF
)"; then
    :
else
    LAYOUT_RESULT="false"
fi

if [ "$LAYOUT_RESULT" = "true" ]; then
    /usr/bin/chflags hidden "$MOUNT_DIR/Drop $APP_NAME.app to Applications.png" 2>/dev/null || true
    /usr/bin/chflags hidden "$MOUNT_DIR/.background" 2>/dev/null || true
    /usr/bin/SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || true
else
    echo "warning: Finder DMG background could not be applied; leaving install PNG visible as fallback." >&2
fi

/usr/bin/hdiutil detach "$MOUNT_DIR" -quiet
MOUNT_DIR=""

/usr/bin/hdiutil convert "$PACKAGE_DIR/$APP_NAME-rw.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" \
    -quiet

/usr/bin/du -h "$DMG_PATH"
