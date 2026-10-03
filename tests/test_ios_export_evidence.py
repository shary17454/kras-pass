import importlib.util
import json
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


if __name__ == "__main__":
    unittest.main()
