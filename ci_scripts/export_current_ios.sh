#!/usr/bin/env bash
set -euo pipefail
ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
OUT="$ROOT/build/ios"
EVIDENCE="$ROOT/tools/ios_export_evidence.py"
if python3 "$EVIDENCE" verify "$ROOT" "$OUT"; then
	echo "Verified current-source iOS export; keeping the existing generated project."
	exit 0
fi
source "$ROOT/ci_scripts/prepare_ios_tools.sh"
mkdir -p "$ROOT/build"
STAGING="$(mktemp -d "$ROOT/build/cloud-export.XXXXXX")"
BEFORE="$(mktemp)"
python3 "$EVIDENCE" source "$ROOT" "$OUT" > "$BEFORE"
GODOT_CPP_PATH="$GODOT_CPP_PATH" SCONS="$SCONS" bash "$ROOT/tools/build_apple_bridge.sh"
KRAS_IOS_EXPORT_OUT="$STAGING" GODOT="$GODOT" bash "$ROOT/tools/export_ios.sh" project
# Preserve Cloud hooks and manifest while replacing exported content, not sources.
ditto "$STAGING" "$OUT"
python3 "$EVIDENCE" record "$ROOT" "$OUT" "$BEFORE"
python3 "$EVIDENCE" verify "$ROOT" "$OUT"
echo "Fresh iOS export verified from $(git -C "$ROOT" rev-parse HEAD)."
