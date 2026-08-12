#!/usr/bin/env bash
# Export Kras Pass for iOS and build the resulting Xcode project.
#
#   tools/export_ios.sh [device|simulator]
#
# This is the whole iOS pipeline: Godot writes an Xcode project, we patch one
# thing Godot gets wrong, then xcodebuild proves it actually compiles. Run it in
# CI — "the GDScript parses" is not evidence that an iOS build works.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/build/ios"
TARGET="${1:-device}"
GODOT="${GODOT:-godot}"

cd "$ROOT"

echo "==> Exporting iOS project"
rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path . --export-release "iOS" "$OUT/KrasPass.ipa" >/tmp/kraspass_export.log 2>&1 || {
	echo "Godot export failed:" >&2
	tail -30 /tmp/kraspass_export.log >&2
	exit 1
}
test -d "$OUT/KrasPass.xcodeproj" || { echo "no Xcode project produced" >&2; exit 1; }

# --- orientation patch ------------------------------------------------------
# Godot 4.7 writes a single interface orientation per device family, and picks
# opposite ones for iPhone and iPad. A party game gets passed around a table, so
# it has to accept the device being flipped; without this the screen stays
# upside down until you flip it back.
PLIST="$OUT/KrasPass/KrasPass-Info.plist"
echo "==> Patching supported orientations (both landscape, both families)"
for KEY in "UISupportedInterfaceOrientations" "UISupportedInterfaceOrientations~ipad"; do
	/usr/libexec/PlistBuddy -c "Delete :$KEY" "$PLIST" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :$KEY array" "$PLIST"
	/usr/libexec/PlistBuddy -c "Add :$KEY:0 string UIInterfaceOrientationLandscapeLeft" "$PLIST"
	/usr/libexec/PlistBuddy -c "Add :$KEY:1 string UIInterfaceOrientationLandscapeRight" "$PLIST"
done

# --- build ------------------------------------------------------------------
if [[ "$TARGET" == "simulator" ]]; then
	SDK="iphonesimulator"
	# The simulator slice of Godot's static library is x86_64-only in this
	# release, so an arm64 simulator build links nothing. Pin the architecture.
	EXTRA=(-arch x86_64)
else
	SDK="iphoneos"
	EXTRA=()
fi

echo "==> Building for $SDK"
DD="$(mktemp -d)"
xcodebuild -project "$OUT/KrasPass.xcodeproj" \
	-scheme KrasPass \
	-sdk "$SDK" \
	-configuration Release \
	-derivedDataPath "$DD" \
	CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
	"${EXTRA[@]+"${EXTRA[@]}"}" build >/tmp/kraspass_xcodebuild.log 2>&1 || {
	echo "xcodebuild failed:" >&2
	grep -E "error:|BUILD FAILED" /tmp/kraspass_xcodebuild.log | tail -20 >&2
	exit 1
}

APP="$(find "$DD/Build/Products" -maxdepth 2 -name 'KrasPass.app' -print -quit)"
test -n "$APP" || { echo "no .app produced" >&2; exit 1; }

echo "==> BUILD SUCCEEDED"
echo "    bundle    : $APP"
echo "    size      : $(du -sh "$APP" | cut -f1)"
echo "    binary    : $(file -b "$APP/KrasPass")"
echo "    identifier: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
echo "    min iOS   : $(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist")"
echo "    families  : $(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily' "$APP/Info.plist" | tr -d '\n ' )"
echo "    landscape : $(/usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations' "$APP/Info.plist" | grep -c Landscape) orientation(s)"

# Signing and upload are a separate, credentialed step:
#   xcodebuild -project build/ios/KrasPass.xcodeproj -scheme KrasPass \
#     -sdk iphoneos -configuration Release archive -archivePath build/KrasPass.xcarchive
#   xcodebuild -exportArchive -archivePath build/KrasPass.xcarchive \
#     -exportOptionsPlist tools/ExportOptions.plist -exportPath build/ipa
