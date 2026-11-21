#!/usr/bin/env bash
# Explicitly signed local archive from a verified, committed-source export.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
usage() {
	echo "Usage: bash tools/archive_ios_local.sh --sign EXPORT_DIR NEW_OUTPUT_DIR [--export-ipa]" >&2
}
if [[ $# -lt 3 || $# -gt 4 || "${1:-}" != "--sign" ]]; then usage; exit 1; fi
if [[ $# -eq 4 && "$4" != "--export-ipa" ]]; then usage; exit 1; fi
if [[ -n "${CI_XCODE_CLOUD:-}${CI_PRIMARY_REPOSITORY_PATH:-}" ]]; then
	echo "Local Xcode only; Xcode Cloud is not supported" >&2; exit 1
fi
EXPORT="$(cd "$2" && pwd)"
RUN="$3"
[[ ! -e "$RUN" ]] || { echo "Output must not exist: $RUN" >&2; exit 1; }
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-27.app/Contents/Developer}"
test -d "$DEVELOPER_DIR" || { echo "Missing local Xcode: $DEVELOPER_DIR" >&2; exit 1; }
EVIDENCE="$ROOT/tools/ios_export_evidence.py"
OPTIONS="$ROOT/tools/ExportOptions.app-store-connect.plist"
# Check space on the destination volume before allocating or invoking signing.
python3 - "$RUN" "${KRAS_IOS_MIN_FREE_GB:-12}" "$OPTIONS" "$EXPORT" <<'PY'
import math, plistlib, shutil, sys
from pathlib import Path
destination = Path(sys.argv[1]).resolve()
export = Path(sys.argv[4]).resolve()
if export == destination or export in destination.parents:
    raise SystemExit('Archive output must be outside the verified export directory')
parent = destination.parent
while not parent.exists():
    parent = parent.parent
required = float(sys.argv[2])
if not math.isfinite(required) or required <= 0:
    raise SystemExit("Archive free-space threshold must be finite and greater than zero")
if shutil.disk_usage(parent).free < required * 1024 ** 3:
    raise SystemExit(f"Insufficient disk space: need at least {required:g} GiB free")
with open(sys.argv[3], 'rb') as stream:
    options = plistlib.load(stream)
expected = {'method': 'app-store-connect', 'destination': 'export',
            'signingStyle': 'manual', 'teamID': '4HM66AD594',
            'signingCertificate': 'Apple Distribution: Shary ALADHYANI (4HM66AD594)',
            'provisioningProfiles': {'com.shary.kraspass': 'Kras Pass App Store Xcode 27 2026-09-20'}}
if any(options.get(key) != value for key, value in expected.items()):
    raise SystemExit("Unexpected local distribution ExportOptions")
if options.get('manageAppVersionAndBuildNumber') is not False or options.get('uploadSymbols') is not False:
    raise SystemExit("Version changes and symbol uploads must be disabled")
PY
python3 "$EVIDENCE" verify "$ROOT" "$EXPORT" || {
	echo "Export is stale, dirty, incomplete or violates privacy policy; export committed inputs first" >&2
	exit 1
}
XCODE_VERSION="$(xcodebuild -version)"
XCODE_MAJOR="$(printf '%s\n' "$XCODE_VERSION" | awk '/^Xcode / {split($2,v,"."); print v[1]}')"
if [[ ! "$XCODE_MAJOR" =~ ^[0-9]+$ ]] || (( XCODE_MAJOR < 27 )); then
	echo "Xcode 27 or newer is required" >&2; exit 1
fi
SDK="$(xcrun --sdk iphoneos --show-sdk-version)"
SDK_MAJOR="${SDK%%.*}"
if [[ ! "$SDK_MAJOR" =~ ^[0-9]+$ ]] || (( SDK_MAJOR < 27 )); then
	echo "iPhoneOS SDK 27 or newer is required" >&2; exit 1
fi
mkdir -p "$(dirname "$RUN")"
mkdir "$RUN"
RUN="$(cd "$RUN" && pwd)"
python3 "$EVIDENCE" source "$ROOT" "$EXPORT" > "$RUN/source-before.json"
printf '%s\n%s\nSDK %s\n' "$DEVELOPER_DIR" "$XCODE_VERSION" "$SDK" > "$RUN/toolchain.txt"
cp "$OPTIONS" "$RUN/ExportOptions.plist"
PROFILE="$(/usr/libexec/PlistBuddy -c 'Print :provisioningProfiles:com.shary.kraspass' "$RUN/ExportOptions.plist")"
CERTIFICATE="$(/usr/libexec/PlistBuddy -c 'Print :signingCertificate' "$RUN/ExportOptions.plist")"
ARCHIVE="$RUN/KrasPass.xcarchive"
mkdir "$RUN/ArchiveRegistry"
# No automatic provisioning updates, cloud execution or upload flags.
xcodebuild -project "$EXPORT/KrasPass.xcodeproj" -scheme KrasPass \
	-IDECustomDistributionArchivesLocation="$RUN/ArchiveRegistry" \
	-configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
	-derivedDataPath "$RUN/DerivedData" -archivePath "$ARCHIVE" \
	IPHONEOS_DEPLOYMENT_TARGET=18.0 DEVELOPMENT_TEAM=4HM66AD594 \
	CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$CERTIFICATE" \
	PROVISIONING_PROFILE_SPECIFIER="$PROFILE" \
	CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES archive > "$RUN/archive.stdout" 2>&1
APP="$ARCHIVE/Products/Applications/KrasPass.app"
codesign --verify --deep --strict "$APP" > "$RUN/codesign-verify.stdout" 2>&1
codesign -d --entitlements :- "$APP" > "$RUN/entitlements.plist" 2> "$RUN/codesign-entitlements.stderr"
codesign -dv --verbose=4 "$APP" > "$RUN/codesign-details.stdout" 2>&1
grep -Fqx "Authority=$CERTIFICATE" "$RUN/codesign-details.stdout"
security cms -D -i "$APP/embedded.mobileprovision" > "$RUN/profile.plist"
codesign -d --extract-certificates="$RUN/signer-" "$APP" > "$RUN/codesign-certificates.stdout" 2>&1
xcrun vtool -show-build "$APP/KrasPass" > "$RUN/macho-build.txt"
python3 - "$APP" "$RUN" "$EXPORT" "$ROOT" <<'PY'
from datetime import datetime, timezone
import plistlib, re, sys
from pathlib import Path
app, run, export, root = map(Path, sys.argv[1:])
bridge = Path('native/apple/bin/KrasApple.xcframework/ios-arm64/libKrasApple.a')
if (root / bridge).read_bytes() != (export / 'KrasPass/dylibs' / bridge).read_bytes():
    raise SystemExit('Exported iOS bridge differs from current committed bridge')
with (app / 'Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
with (run / 'entitlements.plist').open('rb') as stream:
    entitlements = plistlib.load(stream)
if info.get('CFBundleIdentifier') != 'com.shary.kraspass' or info.get('MinimumOSVersion') != '18.0':
    raise SystemExit('Unexpected archive bundle or minimum iOS')
if any(key == 'UIUserInterfaceStyle' or key.startswith('UIUserInterfaceStyle~') for key in info):
    raise SystemExit('Archived app forces a UI appearance')
launch = info.get('UILaunchStoryboardName')
if (not isinstance(launch, str) or not launch or Path(launch).name != launch
        or not list(app.rglob(launch + '.storyboardc'))):
    raise SystemExit('Compiled launch screen is missing')
if info.get('UIDeviceFamily') != [1, 2]:
    raise SystemExit('Archive must support both iPhone and iPad')
landscape = {'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight',
             'UIInterfaceOrientationPortrait'}
for key, expected in [('UISupportedInterfaceOrientations', landscape),
                      ('UISupportedInterfaceOrientations~ipad', landscape | {'UIInterfaceOrientationPortraitUpsideDown'})]:
    values = info.get(key)
    if not isinstance(values, list) or set(values) != expected or len(values) != len(expected):
        raise SystemExit('Invalid archived orientation coverage')
for key in ('CFBundleIcons', 'CFBundleIcons~ipad'):
    primary = info.get(key, {}).get('CFBundlePrimaryIcon', {})
    if not primary.get('CFBundleIconName') or not primary.get('CFBundleIconFiles'):
        raise SystemExit('Missing archived primary app icon')
if not (app / 'Assets.car').is_file():
    raise SystemExit('Missing compiled asset catalog')
with (run / 'profile.plist').open('rb') as stream:
    profile = plistlib.load(stream)
with (run / 'ExportOptions.plist').open('rb') as stream:
    options = plistlib.load(stream)
profile_entitlements = profile.get('Entitlements', {})
expiry = profile.get('ExpirationDate')
if (profile.get('Name') != options['provisioningProfiles']['com.shary.kraspass']
        or profile.get('TeamIdentifier') != ['4HM66AD594']
        or not isinstance(expiry, datetime)
        or expiry.replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc)
        or 'ProvisionedDevices' in profile or profile.get('ProvisionsAllDevices', False) is not False
        or profile_entitlements.get('application-identifier') != '4HM66AD594.com.shary.kraspass'
        or profile_entitlements.get('com.apple.developer.team-identifier') != '4HM66AD594'
        or profile_entitlements.get('get-task-allow') is not False
        or profile_entitlements.get('com.apple.developer.applesignin') != ['Default']
        or (run / 'signer-0').read_bytes() not in profile.get('DeveloperCertificates', [])):
    raise SystemExit('Invalid embedded distribution profile or signing certificate')
with (app / 'PrivacyInfo.xcprivacy').open('rb') as stream:
    privacy = plistlib.load(stream)
with (export / 'PrivacyInfo.xcprivacy').open('rb') as stream:
    original_privacy = plistlib.load(stream)
if privacy != original_privacy:
    raise SystemExit('Archive privacy manifest differs from attested export')
collected = privacy.get('NSPrivacyCollectedDataTypes')
if (privacy.get('NSPrivacyTracking') is not False
        or privacy.get('NSPrivacyTrackingDomains', []) != []
        or not isinstance(collected, list) or not collected
        or any(not isinstance(entry, dict)
               or not isinstance(entry.get('NSPrivacyCollectedDataType'), str)
               or type(entry.get('NSPrivacyCollectedDataTypeLinked')) is not bool
               or entry.get('NSPrivacyCollectedDataTypeTracking') is not False
               or not isinstance(entry.get('NSPrivacyCollectedDataTypePurposes'), list)
               or not entry['NSPrivacyCollectedDataTypePurposes']
               for entry in collected)):
    raise SystemExit('Invalid archived collected-data schema')
if (entitlements.get('application-identifier') != '4HM66AD594.com.shary.kraspass'
        or entitlements.get('com.apple.developer.team-identifier') != '4HM66AD594'
        or entitlements.get('get-task-allow') is not False
        or entitlements.get('com.apple.developer.applesignin') != ['Default']):
    raise SystemExit('Unexpected distribution entitlements')
build = (run / 'macho-build.txt').read_text()
minimums = re.findall(r'^\s*minos\s+(\S+)', build, re.M)
sdks = re.findall(r'^\s*sdk\s+(\S+)', build, re.M)
if not minimums or any(value != '18.0' for value in minimums):
    raise SystemExit('Unexpected Mach-O deployment target')
if not sdks or any(int(value.split('.')[0]) < 27 for value in sdks):
    raise SystemExit('Unexpected Mach-O SDK')
PY
python3 "$EVIDENCE" verify "$ROOT" "$EXPORT"
if [[ "${4:-}" == "--export-ipa" ]]; then
	xcodebuild -exportArchive -archivePath "$ARCHIVE" \
		-IDECustomDistributionArchivesLocation="$RUN/ArchiveRegistry" \
		-exportOptionsPlist "$RUN/ExportOptions.plist" -exportPath "$RUN/ipa" > "$RUN/export.stdout" 2>&1
	test -f "$RUN/ipa/KrasPass.ipa"
fi
python3 - "$ROOT" "$EXPORT" "$RUN" <<'PY'
import json, plistlib, runpy, sys
from pathlib import Path
root, export, run = map(Path, sys.argv[1:])
evidence = runpy.run_path(str(root / 'tools/ios_export_evidence.py'))
before = json.loads((run / 'source-before.json').read_text())
if evidence['source_identity'](root) != before or not evidence['verify'](root, export):
    raise SystemExit('Source or exported inputs changed during archive/export')
with (run / 'KrasPass.xcarchive/Products/Applications/KrasPass.app/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
with (export / 'KrasPass/KrasPass-Info.plist').open('rb') as stream:
    original = plistlib.load(stream)
for key in ('CFBundleIdentifier', 'CFBundleShortVersionString', 'CFBundleVersion'):
    if not info.get(key) or info[key] != original.get(key):
        raise SystemExit(f'Archive metadata differs from committed export: {key}')
result = {'schema_version': 1, 'source': before, 'signed_archive_verified': True,
          'uploaded': False, 'bundle': {key: info[key] for key in
          ('CFBundleIdentifier', 'CFBundleShortVersionString', 'CFBundleVersion', 'MinimumOSVersion')},
          'export_stamp_sha256': evidence['sha_file'](export / evidence['STAMP']),
          'artifacts': evidence['outputs'](run / 'KrasPass.xcarchive'),
          'ipa': evidence['outputs'](run / 'ipa'),
          'export_options_sha256': evidence['sha_file'](run / 'ExportOptions.plist'),
          'toolchain': (run / 'toolchain.txt').read_text()}
(run / 'release-evidence.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
PY
echo "Verified signed local archive: $ARCHIVE"
echo "Evidence: $RUN/release-evidence.json (not uploaded)"
