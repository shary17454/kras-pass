"""Lightweight pipeline contracts; never invoke Godot, Xcode or signing tools."""
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
EXPORT = (ROOT / 'tools/export_ios.sh').read_text()
ARCHIVE = (ROOT / 'tools/archive_ios_local.sh').read_text()


def python_block(script, marker):
    tail = script.split(marker, 1)[1]
    return tail.split("<<'PY'\n", 1)[1].split('\nPY\n', 1)[0]


@contextmanager
def arguments(*values):
    with patch.object(sys, 'argv', ['fixture', *map(str, values)]):
        yield


class LocalPipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def launch_fixture(self, name='Launch Screen'):
        app = self.root / 'KrasPass'
        app.mkdir()
        self.info = app / 'KrasPass-Info.plist'
        self.info.write_bytes(plistlib.dumps({'UILaunchStoryboardName': name,
                                             'UIUserInterfaceStyle': 'Dark',
                                             'UIUserInterfaceStyle~ipad': 'Light'}))
        self.storyboard = app / 'Launch Screen.storyboard'
        self.storyboard.write_text('''<?xml version="1.0"?>
<document appearance="dark"><scenes><scene><objects>
<viewController userInterfaceStyle="dark"><view key="view">
<color key="backgroundColor" red="0.1" green="0.1" blue="0.1"/>
</view></viewController></objects></scene></scenes></document>''')

    def adapt_launch(self):
        code = python_block(EXPORT, '# A launch-screen-only adaptation')
        with arguments(self.root):
            exec(compile(code, '<launch-fixture>', 'exec'), {})

    def test_launch_background_adapts_without_forcing_app_style(self):
        self.launch_fixture()
        self.adapt_launch()
        info = plistlib.loads(self.info.read_bytes())
        self.assertNotIn('UIUserInterfaceStyle', info)
        self.assertNotIn('UIUserInterfaceStyle~ipad', info)
        document = ET.parse(self.storyboard).getroot()
        self.assertEqual(document.get('useTraitCollections'), 'YES')
        colors = document.findall(".//view/color[@key='backgroundColor']")
        self.assertEqual(len(colors), 1)
        self.assertEqual(colors[0].attrib, {'key': 'backgroundColor',
                                          'systemColor': 'systemBackgroundColor'})
        self.assertIsNotNone(document.find("./resources/systemColor[@name='systemBackgroundColor']"))
        fallback = document.find("./resources/systemColor[@name='systemBackgroundColor']/color")
        self.assertEqual(fallback.attrib, {'red': '1', 'green': '1', 'blue': '1',
                                          'alpha': '1', 'colorSpace': 'custom',
                                          'customColorSpace': 'sRGB'})
        self.assertIsNotNone(document.find("./dependencies/capability[@name='System colors in document resources']"))
        for element in document.iter():
            for key in ('appearance', 'userInterfaceStyle', 'overrideUserInterfaceStyle'):
                self.assertNotIn(key, element.attrib)
        self.adapt_launch()
        self.assertEqual(len(ET.parse(self.storyboard).findall('.//systemColor')), 1)

    def test_missing_launch_screen_fails_closed(self):
        self.launch_fixture()
        self.storyboard.unlink()
        with self.assertRaisesRegex(SystemExit, 'missing'):
            self.adapt_launch()

    def test_unsafe_launch_name_fails_closed(self):
        self.launch_fixture('../Launch Screen')
        with self.assertRaisesRegex(SystemExit, 'unsafe'):
            self.adapt_launch()

    def test_missing_root_view_fails_closed(self):
        self.launch_fixture()
        self.storyboard.write_text('<document><scenes/></document>')
        with self.assertRaisesRegex(SystemExit, 'root view'):
            self.adapt_launch()

    def test_shell_and_all_embedded_python_syntax(self):
        for name, script in [('export_ios.sh', EXPORT), ('archive_ios_local.sh', ARCHIVE)]:
            result = subprocess.run(['bash', '-n', str(ROOT / 'tools' / name)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            blocks = re.findall(r"<<'PY'\n(.*?)\nPY(?:\n|$)", script, re.S)
            self.assertTrue(blocks)
            for index, code in enumerate(blocks):
                compile(code, f'{name}:{index}', 'exec')

    def privacy_fixture(self, **changes):
        self.privacy = self.root / 'PrivacyInfo.xcprivacy'
        value = {'NSPrivacyTracking': False, 'NSPrivacyCollectedDataTypes': [],
                 'NSPrivacyAccessedAPITypes': [{'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryUserDefaults',
                     'NSPrivacyAccessedAPITypeReasons': ['CA92.1']}]}
        value.update(changes)
        self.privacy.write_bytes(plistlib.dumps(value))

    def adapt_privacy(self):
        with arguments(self.privacy):
            exec(compile(python_block(EXPORT, '# Preserve generated required-reason'), '<privacy>', 'exec'), {})

    def test_privacy_merge_preserves_api_reasons_and_is_idempotent(self):
        self.privacy_fixture()
        original = plistlib.loads(self.privacy.read_bytes())['NSPrivacyAccessedAPITypes']
        self.adapt_privacy()
        self.adapt_privacy()
        value = plistlib.loads(self.privacy.read_bytes())
        self.assertEqual(value['NSPrivacyAccessedAPITypes'], original)
        self.assertEqual(len(value['NSPrivacyCollectedDataTypes']), 1)
        self.assertIs(value['NSPrivacyCollectedDataTypes'][0]['NSPrivacyCollectedDataTypeLinked'], True)

    def test_privacy_schema_fails_closed(self):
        for changes in ({'NSPrivacyTracking': True}, {'NSPrivacyCollectedDataTypes': [{}]},
                        {'NSPrivacyCollectedDataTypes': {}},
                        {'NSPrivacyAccessedAPITypes': [{'NSPrivacyAccessedAPIType': 'x'}]}):
            with self.subTest(changes=changes):
                self.privacy_fixture(**changes)
                with self.assertRaises(SystemExit):
                    self.adapt_privacy()

    def coverage_fixture(self):
        self.launch_fixture()
        info = plistlib.loads(self.info.read_bytes())
        orientations = ['UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight',
                        'UIInterfaceOrientationPortrait']
        info.update(UIDeviceFamily=[1, 2], UISupportedInterfaceOrientations=orientations)
        info['UISupportedInterfaceOrientations~ipad'] = [*orientations, 'UIInterfaceOrientationPortraitUpsideDown']
        icon = {'CFBundlePrimaryIcon': {'CFBundleIconName': 'AppIcon', 'CFBundleIconFiles': ['Icon']}}
        info.update(CFBundleIcons=icon, **{'CFBundleIcons~ipad': icon})
        info.pop('UIUserInterfaceStyle')
        info.pop('UIUserInterfaceStyle~ipad')
        info.update(CFBundleIdentifier='com.shary.kraspass', MinimumOSVersion='18.0')
        self.info.write_bytes(plistlib.dumps(info))
        project = self.root / 'KrasPass.xcodeproj'
        project.mkdir()
        self.project = project / 'project.pbxproj'
        self.project.write_text('TARGETED_DEVICE_FAMILY = "1,2";')
        self.catalog = self.info.parent / 'Images.xcassets/AppIcon.appiconset'
        self.catalog.mkdir(parents=True)
        (self.catalog / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'icon.png'}]}))
        (self.catalog / 'icon.png').write_bytes(b'mocked-icon')
        self.source = self.root / 'source'
        bridge = Path('native/apple/bin/KrasApple.xcframework/ios-arm64/libKrasApple.a')
        for base in (self.source, self.root / 'KrasPass/dylibs'):
            target = base / bridge
            target.parent.mkdir(parents=True)
            target.write_bytes(b'mocked-current-bridge')

    def validate_coverage(self):
        with arguments(self.root, self.source):
            exec(compile(python_block(EXPORT, '# Validate generated device coverage'), '<coverage>', 'exec'), {})

    def test_icons_orientations_families_and_current_bridge(self):
        self.coverage_fixture()
        self.validate_coverage()
        for bad in ('TARGETED_DEVICE_FAMILY = 1;', 'TARGETED_DEVICE_FAMILY = "1,2"; TARGETED_DEVICE_FAMILY = 2;'):
            self.project.write_text(bad)
            with self.assertRaisesRegex(SystemExit, 'both iPhone and iPad'):
                self.validate_coverage()
        self.project.write_text('TARGETED_DEVICE_FAMILY = "1,2";')
        (self.catalog / 'icon.png').unlink()
        with self.assertRaisesRegex(SystemExit, 'icon asset'):
            self.validate_coverage()
        (self.catalog / 'icon.png').write_bytes(b'fixture')
        info = plistlib.loads(self.info.read_bytes())
        info['UISupportedInterfaceOrientations~ipad'].pop()
        self.info.write_bytes(plistlib.dumps(info))
        with self.assertRaisesRegex(SystemExit, 'orientation'):
            self.validate_coverage()

    def archive_fixture(self):
        self.coverage_fixture()
        self.run = self.root / 'run'
        self.run.mkdir()
        app = self.info.parent
        (app / 'Info.plist').write_bytes(self.info.read_bytes())
        (app / 'Launch Screen.storyboardc').mkdir()
        (app / 'Assets.car').write_bytes(b'mocked-assets')
        self.privacy_fixture()
        self.adapt_privacy()
        (app / 'PrivacyInfo.xcprivacy').write_bytes(self.privacy.read_bytes())
        self.entitlements = {'application-identifier': '4HM66AD594.com.shary.kraspass',
            'com.apple.developer.team-identifier': '4HM66AD594', 'get-task-allow': False,
            'com.apple.developer.applesignin': ['Default']}
        (self.run / 'entitlements.plist').write_bytes(plistlib.dumps(self.entitlements))
        options = (ROOT / 'tools/ExportOptions.app-store-connect.plist').read_bytes()
        (self.run / 'ExportOptions.plist').write_bytes(options)
        self.profile = {'Name': plistlib.loads(options)['provisioningProfiles']['com.shary.kraspass'],
            'TeamIdentifier': ['4HM66AD594'],
            'ExpirationDate': (datetime.now(timezone.utc) + timedelta(days=1)).replace(tzinfo=None),
            'Entitlements': dict(self.entitlements), 'DeveloperCertificates': [b'mocked-leaf']}
        (self.run / 'signer-0').write_bytes(b'mocked-leaf')
        (self.run / 'macho-build.txt').write_text('    minos 18.0\n    sdk 27.2\n')

    def validate_archive(self):
        (self.run / 'profile.plist').write_bytes(plistlib.dumps(self.profile))
        with arguments(self.info.parent, self.run, self.root, self.source):
            exec(compile(python_block(ARCHIVE, 'xcrun vtool -show-build'), '<archive>', 'exec'), {})

    def test_archive_profile_certificate_expiry_and_device_policy(self):
        self.archive_fixture()
        self.validate_archive()
        for key, bad in [('DeveloperCertificates', [b'wrong-leaf']),
                         ('ExpirationDate', (datetime.now(timezone.utc) - timedelta(days=1)).replace(tzinfo=None)),
                         ('ProvisionedDevices', []), ('ProvisionsAllDevices', True),
                         ('Name', 'Development profile'), ('TeamIdentifier', ['OTHER'])]:
            with self.subTest(key=key):
                original = self.profile.copy()
                self.profile[key] = bad
                with self.assertRaisesRegex(SystemExit, 'distribution profile'):
                    self.validate_archive()
                self.profile = original

    def test_archive_rejects_missing_icons_and_device_coverage(self):
        self.archive_fixture()
        original = plistlib.loads((self.info.parent / 'Info.plist').read_bytes())
        for key in ('CFBundleIcons~ipad', 'UISupportedInterfaceOrientations~ipad', 'UIDeviceFamily'):
            info = original.copy()
            info.pop(key)
            (self.info.parent / 'Info.plist').write_bytes(plistlib.dumps(info))
            with self.subTest(key=key), self.assertRaises(SystemExit):
                self.validate_archive()

    def test_current_bridge_mismatch_is_rejected(self):
        self.coverage_fixture()
        bridge = self.source / 'native/apple/bin/KrasApple.xcframework/ios-arm64/libKrasApple.a'
        bridge.write_bytes(b'stale-bridge')
        with self.assertRaisesRegex(SystemExit, 'current committed bridge'):
            self.validate_coverage()

    def test_archive_rejects_wrong_minimum_sdk_and_debug_entitlements(self):
        self.archive_fixture()
        for build in ('minos 17.0\nsdk 27.2\n', 'minos 18.0\nsdk 26.0\n', ''):
            (self.run / 'macho-build.txt').write_text(build)
            with self.subTest(build=build), self.assertRaisesRegex(SystemExit, 'Mach-O'):
                self.validate_archive()
        (self.run / 'macho-build.txt').write_text('minos 18.0\nsdk 27.2\n')
        self.entitlements['get-task-allow'] = True
        (self.run / 'entitlements.plist').write_bytes(plistlib.dumps(self.entitlements))
        with self.assertRaisesRegex(SystemExit, 'distribution entitlements'):
            self.validate_archive()

    def test_toolchain_and_compile_only_contracts(self):
        for script in (EXPORT, ARCHIVE):
            self.assertIn('XCODE_MAJOR < 27', script)
            self.assertIn('IPHONEOS_DEPLOYMENT_TARGET=18.0', script)
        self.assertIn('SDK_MAJOR < 27', ARCHIVE)
        self.assertIn('"$REQUIRED_IOS_SDK" "27.0"', EXPORT)
        self.assertIn('Unsigned compilation passed; runtime and release qualification remain required', EXPORT)
        self.assertNotIn('signed_archive_verified', EXPORT)

    def test_changed_source_or_failed_attestation_never_writes_success(self):
        before = {'commit': 'fixture-commit', 'tree': 'fixture-tree', 'inputs_sha256': 'fixture-hash'}
        (self.root / 'source-before.json').write_text(json.dumps(before))
        code = python_block(ARCHIVE, 'python3 - "$ROOT" "$EXPORT" "$RUN"')
        for current, verified in [({**before, 'commit': 'changed'}, True), (before, False)]:
            evidence = {'source_identity': lambda root: current,
                        'verify': lambda root, export: verified}
            with self.subTest(current=current, verified=verified):
                with arguments(self.root, self.root / 'export', self.root):
                    with patch('runpy.run_path', return_value=evidence):
                        with self.assertRaisesRegex(SystemExit, 'changed during archive'):
                            exec(compile(code, '<final-attestation>', 'exec'), {})
                self.assertFalse((self.root / 'release-evidence.json').exists())

    def preflight(self, *, free_gib=20, threshold=12, options=None, inside=False):
        source = ROOT / 'tools/ExportOptions.app-store-connect.plist'
        value = plistlib.loads(source.read_bytes()) if options is None else options
        target = self.root / 'options.plist'
        target.write_bytes(plistlib.dumps(value))
        export = self.root / 'export'
        destination = export / 'archive' if inside else self.root / 'release'
        code = python_block(ARCHIVE, '# Check space on the destination volume')
        with arguments(destination, threshold, target, export):
            with patch.object(shutil, 'disk_usage', return_value=SimpleNamespace(free=free_gib * 1024 ** 3)):
                exec(compile(code, '<archive-preflight>', 'exec'), {})

    def test_archive_preflight_accepts_local_distribution_policy(self):
        self.preflight()

    def test_archive_refuses_low_space_and_invalid_threshold(self):
        with self.assertRaisesRegex(SystemExit, 'Insufficient disk space'):
            self.preflight(free_gib=5.5)
        for threshold in (0, -1, 'nan', 'inf'):
            with self.subTest(threshold=threshold):
                with self.assertRaisesRegex(SystemExit, 'greater than zero'):
                    self.preflight(threshold=threshold)
        self.preflight(free_gib=6, threshold=5)

    def export_preflight(self, threshold=8, free_gib=20):
        code = python_block(EXPORT, '# Fail before creating export/import directories')
        with arguments(threshold, self.root, self.root / 'output', self.root / 'logs'):
            with patch.object(shutil, 'disk_usage', return_value=SimpleNamespace(free=free_gib * 1024 ** 3)):
                exec(compile(code, '<export-preflight>', 'exec'), {})

    def test_export_disk_guard_defaults_override_and_invalid_values(self):
        self.export_preflight()
        self.export_preflight(threshold=1, free_gib=2)
        for threshold in (0, -1, 'inf', 'nan'):
            with self.subTest(threshold=threshold):
                with self.assertRaisesRegex(SystemExit, 'greater than zero'):
                    self.export_preflight(threshold=threshold)
        with self.assertRaisesRegex(SystemExit, 'Insufficient disk space'):
            self.export_preflight(free_gib=0.1)
        self.assertLess(EXPORT.index('# Fail before creating export/import directories'),
                        EXPORT.index('mkdir -p "$ROOT/build"'))
        self.assertLess(ARCHIVE.index('# Check space on the destination volume'),
                        ARCHIVE.index('python3 "$EVIDENCE" verify'))

    def test_archive_rejects_upload_and_version_mutation(self):
        options = plistlib.loads((ROOT / 'tools/ExportOptions.app-store-connect.plist').read_bytes())
        for key, bad in [('destination', 'upload'), ('method', 'development'),
                         ('manageAppVersionAndBuildNumber', True), ('uploadSymbols', True),
                         ('signingStyle', 'automatic')]:
            with self.subTest(key=key):
                with self.assertRaises(SystemExit):
                    self.preflight(options={**options, key: bad})

    def test_archive_output_cannot_pollute_verified_export(self):
        with self.assertRaisesRegex(SystemExit, 'outside'):
            self.preflight(inside=True)

    def test_signing_requires_explicit_opt_in(self):
        result = subprocess.run(['bash', str(ROOT / 'tools/archive_ios_local.sh')],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Usage:', result.stderr)

    def test_cloud_environment_is_rejected_before_tools_run(self):
        environment = {**os.environ, 'CI_XCODE_CLOUD': 'TRUE'}
        for script, args in [('export_ios.sh', ['project']),
                             ('archive_ios_local.sh', ['--sign', '/missing/export', '/missing/output'])]:
            with self.subTest(script=script):
                result = subprocess.run(['bash', str(ROOT / 'tools' / script), *args],
                                        env=environment, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Xcode Cloud', result.stderr)

    def test_existing_evidence_and_log_gates_remain_in_export(self):
        for value in ('check-ios-export-log.mjs', 'check-ios-simulator-arch.mjs',
                      'CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO',
                      'python3 "$EVIDENCE" source', 'python3 "$EVIDENCE" record',
                      'python3 "$EVIDENCE" verify'):
            self.assertIn(value, EXPORT)
        self.assertLess(EXPORT.index('cleanup_apple_export\ntrap - EXIT'),
                        EXPORT.index('python3 "$EVIDENCE" record'))
        for obsolete in ('MANIFEST_BACKUP', 'KEEP_MARKERS', 'Apple Development'):
            self.assertNotIn(obsolete, EXPORT)

    def test_archive_rechecks_source_and_never_enables_remote_provisioning(self):
        self.assertGreaterEqual(ARCHIVE.count('python3 "$EVIDENCE" verify'), 2)
        self.assertIn("evidence['source_identity'](root) != before", ARCHIVE)
        self.assertIn('CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES', ARCHIVE)
        self.assertIn('IPHONEOS_DEPLOYMENT_TARGET=18.0', ARCHIVE)
        self.assertIn("key == 'UIUserInterfaceStyle'", ARCHIVE)
        self.assertIn("app.rglob(launch + '.storyboardc')", ARCHIVE)
        for unsafe in ('-allowProvisioningUpdates', '-allowProvisioningDeviceRegistration',
                       'altool', 'notarytool', 'git commit', 'git push', 'xcode-select --switch'):
            self.assertNotIn(unsafe, ARCHIVE)

    def test_archive_registry_is_process_local_and_isolated(self):
        self.assertIn('mkdir "$RUN/ArchiveRegistry"', ARCHIVE)
        self.assertEqual(ARCHIVE.count('-IDECustomDistributionArchivesLocation="$RUN/ArchiveRegistry"'), 2)
        self.assertNotIn('defaults write', ARCHIVE)

    def test_codesign_optional_certificate_prefix_uses_equals(self):
        self.assertIn('codesign -d --extract-certificates="$RUN/signer-" "$APP"', ARCHIVE)
        self.assertNotIn('--extract-certificates "$RUN/signer-"', ARCHIVE)


if __name__ == '__main__':
    unittest.main()
