#!/usr/bin/env python3
"""Bind a generated iOS export to the current inputs and verify cached outputs."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

INPUT_ROOTS = ("src/", "data/", "assets/", "native/apple/", "tools/", "ci_scripts/")
INPUT_FILES = {"project.godot", "export_presets.cfg"}
STAMP = ".kras-source-export.json"
REQUIRED_OUTPUTS = {"KrasPass.pck", "KrasPass.xcodeproj/project.pbxproj",
                    "KrasPass.xcframework/ios-arm64/libgodot.a",
                    "KrasPass/dylibs/native/apple/bin/KrasApple.xcframework/ios-arm64/libKrasApple.a"}


def sha_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def source_identity(root):
    def git(*args):
        return subprocess.check_output(["git", "-C", str(root), *args]).decode().strip()
    paths = [value.rstrip("/") for value in INPUT_ROOTS] + sorted(INPUT_FILES)
    if git("diff", "--name-only", "HEAD", "--", *paths):
        raise RuntimeError("Commit release inputs before exporting iOS")
    if git("ls-files", "--others", "--exclude-standard", "--", *paths):
        raise RuntimeError("Untracked release inputs must be committed before exporting iOS")
    files = git("ls-files", "-z").split("\0")
    inputs = {name: sha_file(root / name) for name in files
              if name in INPUT_FILES or name.startswith(INPUT_ROOTS)}
    digest = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
    return {"commit": git("rev-parse", "HEAD"), "tree": git("rev-parse", "HEAD^{tree}"),
            "inputs_sha256": digest}


def outputs(root):
    return {str(path.relative_to(root)): sha_file(path) for path in sorted(root.rglob("*"))
            if path.is_file() and path.name != STAMP
            and "lfs_parts" not in path.relative_to(root).parts}


def verify(root, out):
    try:
        evidence = json.loads((out / STAMP).read_text())
        return (isinstance(evidence, dict) and type(evidence.get("schema_version")) is int
                and evidence["schema_version"] == 1
                and evidence["source"] == source_identity(root)
                and isinstance(evidence["outputs"], dict)
                and REQUIRED_OUTPUTS.issubset(evidence["outputs"])
                and evidence["outputs"] == outputs(out))
    except (OSError, ValueError, KeyError, TypeError, RuntimeError, subprocess.CalledProcessError):
        return False


def main():
    mode, root_arg, out_arg = sys.argv[1:4]
    root, out = Path(root_arg), Path(out_arg)
    if mode == "source":
        print(json.dumps(source_identity(root), sort_keys=True))
    elif mode == "verify":
        sys.exit(0 if verify(root, out) else 1)
    elif mode == "record":
        before = json.loads(Path(sys.argv[4]).read_text())
        current = source_identity(root)
        if current != before:
            raise RuntimeError("Source inputs changed during iOS export")
        evidence = {"schema_version": 1, "source": current, "outputs": outputs(out)}
        if not REQUIRED_OUTPUTS.issubset(evidence["outputs"]):
            raise RuntimeError("Missing fresh game pack, project or engine/bridge library")
        (out / STAMP).write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    else:
        raise ValueError("Unknown evidence mode")


if __name__ == "__main__":
    main()
