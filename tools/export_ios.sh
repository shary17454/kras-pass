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
mkdir -p "$ROOT/build"
OUT="$(mktemp -d "$ROOT/build/ios-export.XXXXXX")"
TARGET="${1:-device}"
GODOT="${GODOT:-godot}"
MANIFEST="$ROOT/build/ios/KrasPass.xcodeproj/xcshareddata/xcodecloud/manifest.json"
MANIFEST_BACKUP=""

cd "$ROOT"

REQUIRED_IOS_SDK="${REQUIRED_IOS_SDK:-26.5}"
XCODE_VERSION="$(xcodebuild -version | tr '\n' ' ')"
IPHONEOS_SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
IPHONEOS_SDK_BUILD="$(xcrun --sdk iphoneos --show-sdk-build-version)"

version_ge() {
	local lhs="$1"
	local rhs="$2"
	[[ "$(printf '%s\n%s\n' "$rhs" "$lhs" | sort -V | tail -1)" == "$lhs" ]]
}

echo "==> Toolchain"
echo "    xcode     : $XCODE_VERSION"
echo "    iphoneos  : $IPHONEOS_SDK_VERSION ($IPHONEOS_SDK_BUILD)"
if ! version_ge "$IPHONEOS_SDK_VERSION" "$REQUIRED_IOS_SDK"; then
	echo "iphoneos SDK $IPHONEOS_SDK_VERSION is older than required $REQUIRED_IOS_SDK" >&2
	exit 1
fi

echo "==> Exporting iOS project"
test -d native/apple/bin/KrasApple.xcframework || {
	echo "Build the Apple bridge first with tools/build_apple_bridge.sh" >&2
	exit 1
}
# Generate the iOS-only extension for export, not desktop editor sessions.
RUNTIME="$ROOT/addons/kras_apple_runtime"
mkdir -p "$RUNTIME"
cp native/apple/kras_apple.gdextension.template "$RUNTIME/kras_apple.gdextension"
cleanup_apple_export() {
	rm -f "$RUNTIME/kras_apple.gdextension" "$RUNTIME/kras_apple.gdextension.uid"
	rmdir "$RUNTIME" 2>/dev/null || true
	if [[ -f "$ROOT/.godot/extension_list.cfg" ]]; then
		perl -ni -e 'print unless m{^res://addons/kras_apple_runtime/kras_apple\.gdextension\s*$}' "$ROOT/.godot/extension_list.cfg"
	fi
}
trap cleanup_apple_export EXIT
"$GODOT" --headless --editor --import --log-file /tmp/kraspass_apple_import.log --path . >/tmp/kraspass_apple_import_console.log 2>&1
if [[ -f "$MANIFEST" ]]; then
	MANIFEST_BACKUP="$(mktemp)"
	cp "$MANIFEST" "$MANIFEST_BACKUP"
fi
# Export into an isolated directory: the checked-in ios folder contains the
# archive parts required by Xcode Cloud and must survive failed exports.
KEEP_MARKERS=""
"$GODOT" --headless --log-file /tmp/kraspass_export_godot.log --path . --export-release "iOS" "$OUT/KrasPass.ipa" >/tmp/kraspass_export.log 2>&1 || {
	echo "Godot export failed:" >&2
	tail -30 /tmp/kraspass_export.log >&2
	exit 1
}
test -d "$OUT/KrasPass.xcodeproj" || { echo "no Xcode project produced" >&2; exit 1; }
# Godot recreates the xcframework folders; the markers that keep them in git do
# not survive, so put them back.
if [[ -n "$KEEP_MARKERS" ]]; then
	while IFS= read -r MARKER; do
		[[ -z "$MARKER" ]] && continue
		mkdir -p "$OUT/$(dirname "$MARKER")"
		# A newline, not an empty file: that is what is committed, and `touch`
		# writing zero bytes shows up as a modification to every marker on
		# every export.
		printf '\n' > "$OUT/$MARKER"
	done <<< "$KEEP_MARKERS"
fi
if [[ -n "$MANIFEST_BACKUP" ]]; then
	EXPORTED_MANIFEST="$OUT/KrasPass.xcodeproj/xcshareddata/xcodecloud/manifest.json"
	mkdir -p "$(dirname "$EXPORTED_MANIFEST")"
	cp "$MANIFEST_BACKUP" "$EXPORTED_MANIFEST"
fi

# --- orientation patch ------------------------------------------------------
# Godot 4.7 writes a single interface orientation per device family, and picks
# opposite ones for iPhone and iPad. A party game gets passed around a table, so
# it has to accept the device being flipped; without this the screen stays
# upside down until you flip it back.
PLIST="$OUT/KrasPass/KrasPass-Info.plist"
ENTITLEMENTS="$OUT/KrasPass/KrasPass.entitlements"
/usr/libexec/PlistBuddy -c 'Delete :com.apple.developer.applesignin' "$ENTITLEMENTS" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :com.apple.developer.applesignin array' "$ENTITLEMENTS"
/usr/libexec/PlistBuddy -c 'Add :com.apple.developer.applesignin:0 string Default' "$ENTITLEMENTS"
PRIVACY="$OUT/PrivacyInfo.xcprivacy"
/usr/libexec/PlistBuddy -c 'Add :NSPrivacyCollectedDataTypes array' "$PRIVACY"
/usr/libexec/PlistBuddy -c 'Add :NSPrivacyCollectedDataTypes:0 dict' "$PRIVACY"
/usr/libexec/PlistBuddy -c 'Add :NSPrivacyCollectedDataTypes:0:NSPrivacyCollectedDataType string NSPrivacyCollectedDataTypeUserID' "$PRIVACY"
/usr/libexec/PlistBuddy -c 'Add :NSPrivacyCollectedDataTypes:0:NSPrivacyCollectedDataTypeLinked bool true' "$PRIVACY"
/usr/libexec/PlistBuddy -c 'Add :NSPrivacyCollectedDataTypes:0:NSPrivacyCollectedDataTypeTracking bool false' "$PRIVACY"
/usr/libexec/PlistBuddy -c 'Add :NSPrivacyCollectedDataTypes:0:NSPrivacyCollectedDataTypePurposes array' "$PRIVACY"
/usr/libexec/PlistBuddy -c 'Add :NSPrivacyCollectedDataTypes:0:NSPrivacyCollectedDataTypePurposes:0 string NSPrivacyCollectedDataTypePurposeAppFunctionality' "$PRIVACY"
echo "==> Patching supported orientations (both landscape, both families)"
for KEY in "UISupportedInterfaceOrientations" "UISupportedInterfaceOrientations~ipad"; do
	/usr/libexec/PlistBuddy -c "Delete :$KEY" "$PLIST" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :$KEY array" "$PLIST"
	/usr/libexec/PlistBuddy -c "Add :$KEY:0 string UIInterfaceOrientationLandscapeLeft" "$PLIST"
	/usr/libexec/PlistBuddy -c "Add :$KEY:1 string UIInterfaceOrientationLandscapeRight" "$PLIST"
done

# --- game controller declaration -------------------------------------------
# Spec item 55 wants the Game Controller capability declared, and item 5 wants
# four players on four pads. Godot's exporter writes neither key, so the App
# Store has no way to know the game supports controllers and iOS treats a
# second pad as a duplicate of the first.
echo "==> Declaring game controller support"
for KEY in "GCSupportsControllerUserInteraction" "GCSupportsMultipleMicroGamepads"; do
	/usr/libexec/PlistBuddy -c "Delete :$KEY" "$PLIST" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :$KEY bool true" "$PLIST"
done

echo "==> Removing unused permission usage descriptions"
for KEY in "NSCameraUsageDescription" "NSMicrophoneUsageDescription" "NSPhotoLibraryUsageDescription"; do
	/usr/libexec/PlistBuddy -c "Delete :$KEY" "$PLIST" 2>/dev/null || true
done

if [[ -f "$OUT/KrasPass/dummy.h" ]]; then
	perl -0pi -e 's/\n#pragma once\n/\n/' "$OUT/KrasPass/dummy.h"
fi

perl -0pi -e 's/CODE_SIGN_IDENTITY = "Apple Distribution";/CODE_SIGN_IDENTITY = "Apple Development";/g' \
	"$OUT/KrasPass.xcodeproj/project.pbxproj"
perl -0pi -e 's/(OTHER_LDFLAGS = "[^"]*)";/$1 -framework AuthenticationServices -framework Security";/g' \
	"$OUT/KrasPass.xcodeproj/project.pbxproj"
perl -0pi -e 's/\n+\z/\n/' \
	"$OUT/KrasPass.xcodeproj/project.pbxproj" \
	"$OUT/KrasPass/export_options.plist"

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
BINARY_SDK="$(xcrun vtool -show-build "$APP/KrasPass" | awk '/ sdk / {print $2; exit}')"
if [[ -z "$BINARY_SDK" ]]; then
	echo "could not read LC_BUILD_VERSION sdk from the built app binary" >&2
	exit 1
fi
if ! version_ge "$BINARY_SDK" "$REQUIRED_IOS_SDK"; then
	echo "built app binary SDK $BINARY_SDK is older than required $REQUIRED_IOS_SDK" >&2
	exit 1
fi

echo "==> BUILD SUCCEEDED"
echo "    bundle    : $APP"
echo "    size      : $(du -sh "$APP" | cut -f1)"
echo "    binary    : $(file -b "$APP/KrasPass")"
echo "    sdk       : $BINARY_SDK"
echo "    identifier: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
echo "    min iOS   : $(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist")"
echo "    families  : $(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily' "$APP/Info.plist" | tr -d '\n ' )"
echo "    landscape : $(/usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations' "$APP/Info.plist" | grep -c Landscape) orientation(s)"

# Signing and upload are a separate, credentialed step:
#   xcodebuild -project build/ios/KrasPass.xcodeproj -scheme KrasPass \
#     -sdk iphoneos -configuration Release archive -archivePath build/KrasPass.xcarchive
#   xcodebuild -exportArchive -archivePath build/KrasPass.xcarchive \
#     -exportOptionsPlist tools/ExportOptions.plist -exportPath build/ipa
