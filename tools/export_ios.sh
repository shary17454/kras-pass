#!/usr/bin/env bash
# Export Kras Pass for iOS and build the resulting Xcode project.
#
#   bash tools/export_ios.sh [device|simulator|project]
#
# Local export and unsigned compilation only. Signing is an explicit,
# separate operation in tools/archive_ios_local.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${CI_XCODE_CLOUD:-}${CI_PRIMARY_REPOSITORY_PATH:-}" ]]; then
	echo "This pipeline requires local Xcode, not Xcode Cloud" >&2
	exit 1
fi
# Fail before creating export/import directories or invoking any generator.
python3 - "${KRAS_IOS_EXPORT_MIN_FREE_GB:-8}" "$ROOT" "${KRAS_IOS_EXPORT_OUT:-$ROOT/build}" "${KRAS_IOS_LOG_DIR:-${TMPDIR:-/tmp}}" <<'PY'
import math, shutil, sys
from pathlib import Path
required = float(sys.argv[1])
if not math.isfinite(required) or required <= 0:
    raise SystemExit('Export free-space threshold must be finite and greater than zero')
for value in sys.argv[2:]:
    path = Path(value).resolve()
    while not path.exists():
        path = path.parent
    free = shutil.disk_usage(path).free / 1024 ** 3
    if free < required:
        raise SystemExit(f'Insufficient disk space at {path}: {free:.2f} GiB free; need {required:g} GiB')
PY
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-27.app/Contents/Developer}"
test -d "$DEVELOPER_DIR" || { echo "Missing local Xcode: $DEVELOPER_DIR" >&2; exit 1; }
mkdir -p "$ROOT/build"
TARGET="${1:-device}"
case "$TARGET" in device|simulator|project) ;; *) echo "Unknown export target: $TARGET" >&2; exit 1 ;; esac
OUT="${KRAS_IOS_EXPORT_OUT:-$(mktemp -d "$ROOT/build/ios-export.XXXXXX")}"
mkdir -p "$OUT"
if [[ -n "$(find "$OUT" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
	echo "Export output must be an empty directory: $OUT" >&2
	exit 1
fi
LOG_DIR="${KRAS_IOS_LOG_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/kras-ios-check.XXXXXX")}"
mkdir -p "$LOG_DIR"
if [[ -n "$(find "$LOG_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
	echo "Export log directory must be empty: $LOG_DIR" >&2
	exit 1
fi
echo "==> Export evidence: $LOG_DIR"
OUT="$(cd "$OUT" && pwd)"
LOG_DIR="$(cd "$LOG_DIR" && pwd)"
case "$LOG_DIR/" in "$OUT/"*) echo "Logs must be outside the export directory" >&2; exit 1 ;; esac
case "$OUT/" in "$LOG_DIR/"*) echo "Export must be outside the log directory" >&2; exit 1 ;; esac
GODOT="${GODOT:-godot}"

cd "$ROOT"

REQUIRED_IOS_SDK="${REQUIRED_IOS_SDK:-27.0}"
XCODE_VERSION="$(xcodebuild -version | tr '\n' ' ')"
XCODE_MAJOR="$(printf '%s\n' "$XCODE_VERSION" | awk '{split($2,v,"."); print v[1]}')"
if [[ ! "$XCODE_MAJOR" =~ ^[0-9]+$ ]] || (( XCODE_MAJOR < 27 )); then
	echo "Xcode 27 or newer is required: $XCODE_VERSION" >&2
	exit 1
fi
IPHONEOS_SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
IPHONEOS_SDK_BUILD="$(xcrun --sdk iphoneos --show-sdk-build-version)"

version_ge() {
	local lhs="$1"
	local rhs="$2"
	[[ "$lhs" =~ ^[0-9]+(\.[0-9]+)*$ && "$rhs" =~ ^[0-9]+(\.[0-9]+)*$ ]] || return 1
	[[ "$(printf '%s\n%s\n' "$rhs" "$lhs" | sort -V | tail -1)" == "$lhs" ]]
}

echo "==> Toolchain"
echo "    xcode     : $XCODE_VERSION"
echo "    iphoneos  : $IPHONEOS_SDK_VERSION ($IPHONEOS_SDK_BUILD)"
if ! version_ge "$REQUIRED_IOS_SDK" "27.0"; then
	echo "REQUIRED_IOS_SDK cannot be lower than 27.0" >&2
	exit 1
fi
if ! version_ge "$IPHONEOS_SDK_VERSION" "$REQUIRED_IOS_SDK"; then
	echo "iphoneos SDK $IPHONEOS_SDK_VERSION is older than required $REQUIRED_IOS_SDK" >&2
	exit 1
fi
printf '%s\n%s\n%s (%s)\n' "$DEVELOPER_DIR" "$XCODE_VERSION" "$IPHONEOS_SDK_VERSION" "$IPHONEOS_SDK_BUILD" > "$LOG_DIR/toolchain.txt"
EVIDENCE="$ROOT/tools/ios_export_evidence.py"
python3 - "$ROOT/export_presets.cfg" <<'PY'
import configparser, sys
config = configparser.ConfigParser(interpolation=None)
config.read(sys.argv[1])
if config['preset.0.options']['application/min_ios_version'].strip('"') != '18.0':
    raise SystemExit('The iOS preset must declare minimum iOS 18.0')
PY
python3 "$EVIDENCE" source "$ROOT" "$OUT" > "$LOG_DIR/source-before.json"

echo "==> Exporting iOS project"
test -d native/apple/bin/KrasApple.xcframework || {
	echo "Build the Apple bridge first with tools/build_apple_bridge.sh" >&2
	exit 1
}
# Generate the iOS-only extension for export, not desktop editor sessions.
RUNTIME="$ROOT/addons/kras_apple_runtime"
if [[ -e "$RUNTIME/kras_apple.gdextension" || -e "$RUNTIME/kras_apple.gdextension.uid" ]]; then
	echo "Refusing to overwrite an existing Apple runtime export file" >&2
	exit 1
fi
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
"$GODOT" --headless --editor --import --log-file "$LOG_DIR/import.log" --path . >"$LOG_DIR/import.stdout" 2>&1
node "$ROOT/tools/check-ios-export-log.mjs" "$LOG_DIR/import.stdout"
# Always export into an isolated directory; never preserve generated Cloud files.
"$GODOT" --headless --log-file "$LOG_DIR/export.log" --path . --export-release "iOS" "$OUT/KrasPass.ipa" >"$LOG_DIR/export.stdout" 2>&1 || {
	echo "Godot export failed:" >&2
	tail -30 "$LOG_DIR/export.stdout" >&2
	exit 1
}
node "$ROOT/tools/check-ios-export-log.mjs" "$LOG_DIR/export.stdout"
test -d "$OUT/KrasPass.xcodeproj" || { echo "no Xcode project produced" >&2; exit 1; }

# --- orientation patch ------------------------------------------------------
# Preserve portrait and landscape support when regenerating the iOS export.
PLIST="$OUT/KrasPass/KrasPass-Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :CADisableMinimumFrameDurationOnPhone' "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :CADisableMinimumFrameDurationOnPhone bool true' "$PLIST"
ENTITLEMENTS="$OUT/KrasPass/KrasPass.entitlements"
/usr/libexec/PlistBuddy -c 'Delete :com.apple.developer.applesignin' "$ENTITLEMENTS" 2>/dev/null || true
/usr/libexec/PlistBuddy -c 'Add :com.apple.developer.applesignin array' "$ENTITLEMENTS"
/usr/libexec/PlistBuddy -c 'Add :com.apple.developer.applesignin:0 string Default' "$ENTITLEMENTS"
PRIVACY="$OUT/PrivacyInfo.xcprivacy"
# Preserve generated required-reason declarations; merge the account disclosure.
python3 - "$PRIVACY" <<'PY'
import plistlib, sys
from pathlib import Path
path = Path(sys.argv[1])
privacy = plistlib.loads(path.read_bytes())
if not isinstance(privacy, dict) or privacy.get('NSPrivacyTracking') is not False:
    raise SystemExit('Invalid privacy manifest tracking declaration')
if privacy.get('NSPrivacyTrackingDomains', []) != []:
    raise SystemExit('Tracking domains are not permitted')
collected = privacy.get('NSPrivacyCollectedDataTypes', [])
purposes = {'NSPrivacyCollectedDataTypePurpose' + value for value in
            ('ThirdPartyAdvertising', 'DeveloperAdvertising', 'Analytics',
             'ProductPersonalization', 'AppFunctionality', 'Other')}
if not isinstance(collected, list):
    raise SystemExit('Invalid collected-data schema')
for entry in collected:
    if (not isinstance(entry, dict) or not isinstance(entry.get('NSPrivacyCollectedDataType'), str)
            or type(entry.get('NSPrivacyCollectedDataTypeLinked')) is not bool
            or entry.get('NSPrivacyCollectedDataTypeTracking') is not False
            or not isinstance(entry.get('NSPrivacyCollectedDataTypePurposes'), list)
            or not entry['NSPrivacyCollectedDataTypePurposes']
            or any(not isinstance(value, str) or value not in purposes
                   for value in entry['NSPrivacyCollectedDataTypePurposes'])):
        raise SystemExit('Invalid collected-data schema')
apis = privacy.get('NSPrivacyAccessedAPITypes', [])
if not isinstance(apis, list) or any(
        not isinstance(entry, dict) or not isinstance(entry.get('NSPrivacyAccessedAPIType'), str)
        or not isinstance(entry.get('NSPrivacyAccessedAPITypeReasons'), list)
        or not entry['NSPrivacyAccessedAPITypeReasons']
        or any(not isinstance(reason, str) or not reason for reason in entry['NSPrivacyAccessedAPITypeReasons'])
        for entry in apis):
    raise SystemExit('Invalid required-reason API schema')
user = {'NSPrivacyCollectedDataType': 'NSPrivacyCollectedDataTypeUserID',
        'NSPrivacyCollectedDataTypeLinked': True, 'NSPrivacyCollectedDataTypeTracking': False,
        'NSPrivacyCollectedDataTypePurposes': ['NSPrivacyCollectedDataTypePurposeAppFunctionality']}
existing = [entry for entry in collected if entry['NSPrivacyCollectedDataType'] == user['NSPrivacyCollectedDataType']]
if existing and existing != [user]:
    raise SystemExit('Conflicting UserID privacy declaration')
privacy['NSPrivacyCollectedDataTypes'] = collected if existing else [*collected, user]
path.write_bytes(plistlib.dumps(privacy))
PY
echo "==> Patching supported orientations (portrait and landscape)"
for KEY in "UISupportedInterfaceOrientations" "UISupportedInterfaceOrientations~ipad"; do
	/usr/libexec/PlistBuddy -c "Delete :$KEY" "$PLIST" 2>/dev/null || true
	/usr/libexec/PlistBuddy -c "Add :$KEY array" "$PLIST"
	/usr/libexec/PlistBuddy -c "Add :$KEY:0 string UIInterfaceOrientationLandscapeLeft" "$PLIST"
	/usr/libexec/PlistBuddy -c "Add :$KEY:1 string UIInterfaceOrientationLandscapeRight" "$PLIST"
	/usr/libexec/PlistBuddy -c "Add :$KEY:2 string UIInterfaceOrientationPortrait" "$PLIST"
	if [ "$KEY" = "UISupportedInterfaceOrientations~ipad" ]; then
		/usr/libexec/PlistBuddy -c "Add :$KEY:3 string UIInterfaceOrientationPortraitUpsideDown" "$PLIST"
	fi
done

# A launch-screen-only adaptation, not a claim of application-wide dark mode.
python3 - "$OUT" <<'PY'
import plistlib, sys
from pathlib import Path
import xml.etree.ElementTree as ET
out = Path(sys.argv[1])
plist = out / 'KrasPass/KrasPass-Info.plist'
with plist.open('rb') as stream:
    info = plistlib.load(stream)
for key in list(info):
    if key == 'UIUserInterfaceStyle' or key.startswith('UIUserInterfaceStyle~'):
        del info[key]
name = info.get('UILaunchStoryboardName')
if not isinstance(name, str) or not name or Path(name).name != name:
    raise SystemExit('Missing or unsafe launch storyboard name')
matches = list((out / 'KrasPass').rglob(name + '.storyboard'))
if not matches:
    raise SystemExit('Launch storyboard is missing')
for path in matches:
    tree = ET.parse(path)
    document = tree.getroot()
    document.set('useTraitCollections', 'YES')
    dependencies = document.find('dependencies')
    if dependencies is None:
        dependencies = ET.SubElement(document, 'dependencies')
    if dependencies.find("capability[@name='System colors in document resources']") is None:
        ET.SubElement(dependencies, 'capability', name='System colors in document resources',
                      minToolsVersion='11.0')
    for element in document.iter():
        for key in ('appearance', 'userInterfaceStyle', 'overrideUserInterfaceStyle'):
            element.attrib.pop(key, None)
    views = document.findall('./scenes/scene/objects/viewController/view')
    if not views:
        raise SystemExit('No launch-screen root view found')
    for view in views:
        colors = list(view.findall("./color[@key='backgroundColor']"))
        position = list(view).index(colors[0]) if colors else len(view)
        for color in colors:
            view.remove(color)
        view.insert(position, ET.Element('color', key='backgroundColor', systemColor='systemBackgroundColor'))
    resources = document.find('resources')
    if resources is None:
        resources = ET.SubElement(document, 'resources')
    system = resources.find("systemColor[@name='systemBackgroundColor']")
    if system is None:
        system = ET.SubElement(resources, 'systemColor', name='systemBackgroundColor')
        ET.SubElement(system, 'color', white='1', alpha='1', colorSpace='custom',
                      customColorSpace='genericGamma22GrayColor')
    # systemBackgroundColor is available before iOS 18; no newer UIKit API needed.
    if any(element.get(key) is not None for element in document.iter()
           for key in ('appearance', 'userInterfaceStyle', 'overrideUserInterfaceStyle')):
        raise SystemExit('Launch screen forces an appearance')
    tree.write(path, encoding='utf-8', xml_declaration=True)
with plist.open('wb') as stream:
    plistlib.dump(info, stream)
with plist.open('rb') as stream:
    if any(key == 'UIUserInterfaceStyle' or key.startswith('UIUserInterfaceStyle~')
           for key in plistlib.load(stream)):
        raise SystemExit('The exported app forces a UI appearance')
PY

# Validate generated device coverage and icon assets before attestation.
python3 - "$OUT" "$ROOT" <<'PY'
import hashlib, json, plistlib, sys
from pathlib import Path
out, root = map(Path, sys.argv[1:])
bridge = Path('native/apple/bin/KrasApple.xcframework/ios-arm64/libKrasApple.a')
if (hashlib.sha256((root / bridge).read_bytes()).digest() !=
        hashlib.sha256((out / 'KrasPass/dylibs' / bridge).read_bytes()).digest()):
    raise SystemExit('Exported iOS bridge differs from current committed bridge')
info = plistlib.loads((out / 'KrasPass/KrasPass-Info.plist').read_bytes())
landscape = {'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight',
             'UIInterfaceOrientationPortrait'}
for key, expected in [('UISupportedInterfaceOrientations', landscape),
                      ('UISupportedInterfaceOrientations~ipad', landscape | {'UIInterfaceOrientationPortraitUpsideDown'})]:
    values = info.get(key)
    if not isinstance(values, list) or set(values) != expected or len(values) != len(expected):
        raise SystemExit('Invalid orientation coverage: ' + key)
project = (out / 'KrasPass.xcodeproj/project.pbxproj').read_text()
import re
families = re.findall(r'TARGETED_DEVICE_FAMILY\s*=\s*"?([0-9, ]+)"?\s*;', project)
if not families or any({v.strip() for v in value.split(',')} != {'1', '2'} for value in families):
    raise SystemExit('Export must target both iPhone and iPad')
catalogs = list((out / 'KrasPass').rglob('*.appiconset/Contents.json'))
if not catalogs:
    raise SystemExit('Missing app icon catalog')
for catalog in catalogs:
    images = json.loads(catalog.read_text()).get('images', [])
    if not images:
        raise SystemExit('Empty app icon catalog')
    for entry in images:
        name = entry.get('filename')
        if not isinstance(name, str) or not name or Path(name).name != name:
            raise SystemExit('Missing or unsafe app icon filename')
        icon = catalog.parent / name
        if not icon.is_file() or not icon.stat().st_size:
            raise SystemExit('Missing or empty app icon asset')
PY

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

perl -0pi -e 's/(OTHER_LDFLAGS = "[^"]*)";/$1 -framework AuthenticationServices -framework Security";/g' \
	"$OUT/KrasPass.xcodeproj/project.pbxproj"
perl -0pi -e 's/\n+\z/\n/' \
	"$OUT/KrasPass.xcodeproj/project.pbxproj" \
	"$OUT/KrasPass/export_options.plist"

# Remove only our temporary addon before checking committed input identity.
cleanup_apple_export
trap - EXIT
python3 "$EVIDENCE" record "$ROOT" "$OUT" "$LOG_DIR/source-before.json"
python3 "$EVIDENCE" verify "$ROOT" "$OUT"

# --- build ------------------------------------------------------------------
if [[ "$TARGET" == "project" ]]; then
	echo "==> Current-source iOS project exported: $OUT"
	exit 0
fi
if [[ "$TARGET" == "simulator" ]]; then
	SDK="iphonesimulator"
	SIM_ARCH="${KRAS_IOS_SIM_ARCH:-$(uname -m)}"
	SIM_LIBRARY="$OUT/KrasPass.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
	node "$ROOT/tools/check-ios-simulator-arch.mjs" "$SIM_LIBRARY" "$SIM_ARCH"
	EXTRA=(-arch "$SIM_ARCH")
	echo "==> Simulator compilation only; launch on a matching runtime remains required"
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
	IPHONEOS_DEPLOYMENT_TARGET=18.0 \
	CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
	"${EXTRA[@]+"${EXTRA[@]}"}" build >"$LOG_DIR/xcodebuild.stdout" 2>&1 || {
	echo "xcodebuild failed:" >&2
	grep -E "error:|BUILD FAILED" "$LOG_DIR/xcodebuild.stdout" | tail -20 >&2
	exit 1
}

APP="$(find "$DD/Build/Products" -maxdepth 2 -name 'KrasPass.app' -print -quit)"
test -n "$APP" || { echo "no .app produced" >&2; exit 1; }
BINARY_SDK="$(xcrun vtool -show-build "$APP/KrasPass" | awk '/ sdk / {print $2; exit}')"
if [[ -z "$BINARY_SDK" ]]; then
	echo "could not read LC_BUILD_VERSION sdk from the built app binary" >&2
	exit 1
fi
MIN_IOS="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist")"
[[ "$MIN_IOS" == "18.0" ]] || { echo "Unexpected minimum iOS: $MIN_IOS" >&2; exit 1; }
BINARY_MIN="$(xcrun vtool -show-build "$APP/KrasPass" | awk '/ minos / {print $2; exit}')"
[[ "$BINARY_MIN" == "18.0" ]] || { echo "Unexpected Mach-O minimum iOS: $BINARY_MIN" >&2; exit 1; }
if ! version_ge "$BINARY_SDK" "$REQUIRED_IOS_SDK"; then
	echo "built app binary SDK $BINARY_SDK is older than required $REQUIRED_IOS_SDK" >&2
	exit 1
fi

echo "==> Unsigned compilation passed; runtime and release qualification remain required"
echo "    bundle    : $APP"
echo "    size      : $(du -sh "$APP" | cut -f1)"
echo "    binary    : $(file -b "$APP/KrasPass")"
echo "    sdk       : $BINARY_SDK"
echo "    identifier: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
echo "    min iOS   : $(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist")"
echo "    families  : $(/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily' "$APP/Info.plist" | tr -d '\n ' )"
echo "    landscape : $(/usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations' "$APP/Info.plist" | grep -c Landscape) orientation(s)"

# Signing requires a separate, explicit invocation; see docs/local-ios-release.md.
