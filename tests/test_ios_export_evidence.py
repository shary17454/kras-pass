import importlib.util
import json
import os
import plistlib
from pathlib import Path
import subprocess
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    "evidence", Path(__file__).parents[1] / "tools/ios_export_evidence.py")
EVIDENCE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EVIDENCE)


class ExportEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.out = self.root / "build/ios"
        self.git("init", "-q")
        self.git("config", "user.name", "Export Test")
        self.git("config", "user.email", "test@example.invalid")
        self.input = self.root / "src/match.gd"
        self.input.parent.mkdir()
        self.input.write_text("extends Node\n")
        self.git("add", "src")
        self.git("commit", "-qm", "Initial test source")
        for name in EVIDENCE.REQUIRED_OUTPUTS:
            path = self.out / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"test output")
        self.stamp = self.out / EVIDENCE.STAMP
        self.record()

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args])

    def record(self):
        self.stamp.write_text(json.dumps({"schema_version": 1,
            "source": EVIDENCE.source_identity(self.root), "outputs": EVIDENCE.outputs(self.out)}))

    def test_current_export_is_reusable(self):
        self.assertTrue(EVIDENCE.verify(self.root, self.out))

    def test_changed_input_requires_commit_and_new_export(self):
        self.input.write_text("extends Node3D\n")
        self.assertFalse(EVIDENCE.verify(self.root, self.out))
        with self.assertRaises(RuntimeError):
            EVIDENCE.source_identity(self.root)
        self.git("add", "src")
        self.git("commit", "-qm", "Change game")
        self.assertFalse(EVIDENCE.verify(self.root, self.out))
        self.record()
        self.assertTrue(EVIDENCE.verify(self.root, self.out))

    def test_changed_pack_is_rejected(self):
        (self.out / "KrasPass.pck").write_bytes(b"old content")
        self.assertFalse(EVIDENCE.verify(self.root, self.out))

    def test_untracked_game_cannot_enter_an_attested_pack(self):
        (self.root / "src/extra.gd").write_text("extends Node\n")
        self.assertFalse(EVIDENCE.verify(self.root, self.out))
        with self.assertRaises(RuntimeError):
            EVIDENCE.source_identity(self.root)

    def test_changed_scene_requires_commit_and_new_export(self):
        scene = self.root / "scenes/boot.tscn"
        scene.parent.mkdir()
        scene.write_text('[gd_scene format=3]\n[node name="Boot" type="Node"]\n')
        self.git("add", "scenes")
        self.git("commit", "-qm", "Add boot scene")
        before = EVIDENCE.source_identity(self.root)
        self.record()
        scene.write_text('[gd_scene format=3]\n[node name="Changed" type="Node"]\n')
        self.assertFalse(EVIDENCE.verify(self.root, self.out))
        with self.assertRaises(RuntimeError):
            EVIDENCE.source_identity(self.root)
        self.git("add", "scenes")
        self.git("commit", "-qm", "Change boot scene")
        self.assertNotEqual(EVIDENCE.source_identity(self.root)["inputs_sha256"],
                            before["inputs_sha256"])
        self.assertFalse(EVIDENCE.verify(self.root, self.out))

    def test_untracked_scene_or_addon_cannot_enter_an_attested_pack(self):
        for name in ["scenes/extra.tscn", "addons/helper/helper.gd"]:
            with self.subTest(name=name):
                path = self.root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("fixture\n")
                self.assertFalse(EVIDENCE.verify(self.root, self.out))
                with self.assertRaises(RuntimeError):
                    EVIDENCE.source_identity(self.root)
                path.unlink()

    def test_changed_addon_requires_commit_and_new_export(self):
        addon = self.root / "addons/helper/helper.gd"
        addon.parent.mkdir(parents=True)
        addon.write_text("extends Node\n")
        self.git("add", "addons")
        self.git("commit", "-qm", "Add helper addon")
        before = EVIDENCE.source_identity(self.root)
        self.record()
        addon.write_text("extends Node3D\n")
        self.assertFalse(EVIDENCE.verify(self.root, self.out))
        with self.assertRaises(RuntimeError):
            EVIDENCE.source_identity(self.root)
        self.git("add", "addons")
        self.git("commit", "-qm", "Change helper addon")
        self.assertNotEqual(EVIDENCE.source_identity(self.root)["inputs_sha256"],
                            before["inputs_sha256"])
        self.assertFalse(EVIDENCE.verify(self.root, self.out))

    def test_generated_script_uid_must_be_committed(self):
        uid = self.input.with_suffix(".gd.uid")
        uid.write_text("uid://teststableidentity\n")
        with self.assertRaises(RuntimeError):
            EVIDENCE.source_identity(self.root)
        self.git("add", "src")
        self.git("commit", "-qm", "Preserve Godot script identity")
        self.assertFalse(EVIDENCE.verify(self.root, self.out))
        before = EVIDENCE.source_identity(self.root)
        uid.write_text("uid://differentidentity\n")
        with self.assertRaises(RuntimeError):
            EVIDENCE.source_identity(self.root)
        uid.write_text("uid://teststableidentity\n")
        self.assertEqual(EVIDENCE.source_identity(self.root), before)
        self.record()
        self.assertTrue(EVIDENCE.verify(self.root, self.out))

    def test_changed_native_bridge_is_rejected(self):
        path = next(name for name in EVIDENCE.REQUIRED_OUTPUTS if "libKrasApple" in name)
        (self.out / path).write_bytes(b"old bridge")
        self.assertFalse(EVIDENCE.verify(self.root, self.out))

    def test_missing_output_is_rejected(self):
        (self.out / "KrasPass.pck").unlink()
        self.assertFalse(EVIDENCE.verify(self.root, self.out))

    def test_missing_stamp_is_rejected(self):
        self.stamp.unlink()
        self.assertFalse(EVIDENCE.verify(self.root, self.out))

    def test_malformed_stamp_is_rejected(self):
        for data in ["[]", "null", "{", '{"schema_version":true}', '{"schema_version":2}']:
            self.stamp.write_text(data)
            self.assertFalse(EVIDENCE.verify(self.root, self.out))

    def test_extra_generated_file_invalidates_export(self):
        (self.out / "unexpected.pck").write_bytes(b"stale")
        self.assertFalse(EVIDENCE.verify(self.root, self.out))

    def fetch(self, expected):
        tools = self.root / "fake-tools"
        tools.mkdir()
        godot = tools / "godot"
        godot.write_text("#!/bin/sh\necho 4.7.1.stable.fixture\n")
        scons = tools / "scons"
        scons.write_text("#!/bin/sh\necho 'SCons: v4.11.1.fixture'\n")
        godot.chmod(0o755)
        scons.chmod(0o755)
        home = self.root / "home"
        templates = home / "Library/Application Support/Godot/export_templates/4.7.1.stable"
        templates.mkdir(parents=True)
        (templates / "ios.zip").write_bytes(b"fixture")
        original = tools / "original.zip"
        original.write_bytes(b"verified bytes")
        destination = tools / "downloaded.zip"
        destination.write_bytes(b"stale cache")
        env = dict(os.environ, ROOT=str(self.root), HOME=str(home), GODOT=str(godot),
                   SCONS=str(scons), GODOT_CPP_PATH=str(tools))
        helper = Path(__file__).parents[1] / "ci_scripts/prepare_ios_tools.sh"
        result = subprocess.run(["bash", "-c",
            'source "$1"; fetch_verified "$2" "$3" "$4"', "fetch-test",
            str(helper), original.as_uri(), str(destination), expected],
            env=env, capture_output=True)
        return result, destination

    def test_verified_download_replaces_bad_cache(self):
        expected = EVIDENCE.hashlib.sha256(b"verified bytes").hexdigest()
        result, destination = self.fetch(expected)
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        self.assertEqual(destination.read_bytes(), b"verified bytes")

    def test_wrong_checksum_cannot_promote_download(self):
        result, destination = self.fetch("0" * 64)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(destination.read_bytes(), b"stale cache")


class DistributionExportPolicyTests(unittest.TestCase):
    def test_export_preserves_frozen_build_and_existing_manual_identity(self):
        filename = Path(__file__).parents[1] / "tools/ExportOptions.app-store-connect.plist"
        with filename.open("rb") as source:
            options = plistlib.load(source)
        self.assertIs(options.get("manageAppVersionAndBuildNumber"), False)
        self.assertEqual(options.get("signingStyle"), "manual")
        self.assertEqual(options.get("signingCertificate"),
                         "Apple Distribution: Shary ALADHYANI (4HM66AD594)")
        self.assertEqual(options.get("teamID"), "4HM66AD594")
        self.assertEqual(options.get("method"), "app-store-connect")
        self.assertEqual(options.get("provisioningProfiles"), {
            "com.shary.kraspass": "Kras Pass App Store Xcode 27 2026-09-20"})


if __name__ == "__main__":
    unittest.main()
