#!/bin/sh
set -eu

ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(pwd)}"
PARTS="$ROOT/build/ios/lfs_parts"

restore_archive() {
	target="$1"
	sha="$2"
	source_dir="$PARTS/$target"
	output="$ROOT/$target"

	if [ ! -d "$source_dir" ]; then
		echo "Missing archive parts: $source_dir" >&2
		exit 1
	fi

	mkdir -p "$(dirname "$output")"
	cat "$source_dir"/*.part > "$output"

	actual="$(shasum -a 256 "$output" | awk '{print $1}')"
	if [ "$actual" != "$sha" ]; then
		echo "Checksum mismatch for $target" >&2
		echo "expected: $sha" >&2
		echo "actual  : $actual" >&2
		exit 1
	fi
}

restore_archive "build/ios/KrasPass.xcframework/ios-arm64/libgodot.a" "c4a7f859aa8ae630f991a170a2eb7d8b3cc5daff0ba4445e143a0fe302d4d273"
restore_archive "build/ios/KrasPass.xcframework/ios-arm64_x86_64-simulator/libgodot.a" "50d00a3bb22c998e78dd30ccc5546283add7553cc086940f77d2454401c7066e"
restore_archive "build/ios/MoltenVK.xcframework/ios-arm64/libMoltenVK.a" "3f0aba9dac0779b09950824b392469b62f8b1621691d646b44ab1c231a88e1fb"
restore_archive "build/ios/MoltenVK.xcframework/ios-arm64_x86_64-simulator/libMoltenVK.a" "aa0582836a65e041d3506bea67e7872683b99062bb31f36423ddc72ec29ae572"

echo "Restored iOS static archives from repository parts."
