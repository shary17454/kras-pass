#!/usr/bin/env bash
# Sourced by the Cloud export: keep tool installations scoped to the build cache.
set -euo pipefail
CACHE="${KRAS_IOS_TOOL_CACHE:-$ROOT/build/cloud-tools}"
mkdir -p "$CACHE"
VERSION=4.7.1
RELEASE="https://github.com/godotengine/godot-builds/releases/download/$VERSION-stable"

fetch_verified() {
	local url="$1" file="$2" sha="$3"
	if [[ ! -f "$file" ]] || ! printf '%s  %s\n' "$sha" "$file" | shasum -a 256 -c - >/dev/null 2>&1; then
		curl --fail --location --retry 3 --max-time 900 "$url" --output "$file.download"
		printf '%s  %s\n' "$sha" "$file.download" | shasum -a 256 -c -
		mv "$file.download" "$file"
	fi
}

if [[ -z "${GODOT:-}" ]]; then
	fetch_verified "$RELEASE/Godot_v${VERSION}-stable_macos.universal.zip" "$CACHE/godot.zip" \
		897cb7f9799796c717ae75f31446aed883dc92b1d6c3b33d893cc7843fff2fa9
	unzip -q -o "$CACHE/godot.zip" -d "$CACHE/godot"
	GODOT="$CACHE/godot/Godot.app/Contents/MacOS/Godot"
fi
[[ "$("$GODOT" --version)" == "$VERSION.stable."* ]] || { echo "Unexpected Godot version" >&2; exit 1; }
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$VERSION.stable"
if [[ ! -f "$TEMPLATES/ios.zip" ]]; then
	fetch_verified "$RELEASE/Godot_v${VERSION}-stable_export_templates.tpz" "$CACHE/templates.tpz" \
		86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72
	mkdir -p "$CACHE/templates" "$TEMPLATES"
	unzip -q -o "$CACHE/templates.tpz" 'templates/ios.zip' 'templates/version.txt' -d "$CACHE/templates"
	cp "$CACHE/templates/templates/ios.zip" "$CACHE/templates/templates/version.txt" "$TEMPLATES/"
fi
if [[ -z "${SCONS:-}" ]]; then
	if [[ ! -x "$CACHE/python/bin/python" ]]; then python3 -m venv "$CACHE/python"; fi
	"$CACHE/python/bin/python" -m pip install --disable-pip-version-check scons==4.11.1
	SCONS="$CACHE/python/bin/scons"
fi
"$SCONS" --version | grep -F 'SCons: v4.11.1.' >/dev/null
if [[ -z "${GODOT_CPP_PATH:-}" ]]; then
	GODOT_CPP_PATH="$CACHE/godot-cpp"
	if [[ ! -d "$GODOT_CPP_PATH/.git" ]]; then
		git clone https://github.com/godotengine/godot-cpp.git "$GODOT_CPP_PATH"
	fi
	git -C "$GODOT_CPP_PATH" checkout --detach 714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa
fi
export GODOT SCONS GODOT_CPP_PATH
