#!/bin/sh
# Run with an isolated save directory and fail on GDScript runtime errors too.
set -eu
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/kras-party-check.XXXXXX")"
printf 'Evidence: %s\n' "$OUT"
run_check() {
  label="$1"
  scene="$2"
  shift 2
  code=0
  "$GODOT_BIN" --headless --fixed-fps 60 --path . --log-file "$OUT/$label.log" "$scene" -- --test-data-dir="$OUT/saves-$label" "$@" >"$OUT/$label.stdout" 2>&1 || code=$?
  tail -n 22 "$OUT/$label.stdout"
  if grep -Eq 'SCRIPT ERROR:|Parse Error:|FAIL:|FAILED|Required object .* is null|ObjectDB instances (were )?leaked|resources still in use|RID allocations|PagedAllocator.*pages in use' "$OUT/$label.stdout"; then
    code=1
  fi
  if [ "$code" -ne 0 ]; then
    printf 'Failed: %s (see %s)\n' "$label" "$OUT/$label.stdout" >&2
    exit "$code"
  fi
}
run_check compile tests/compile_check.tscn
run_check inventory tools/stage_zero_audit.tscn
run_check tests tests/test_runner.tscn
run_check race_regression tests/party_race_check.tscn
run_check stability tests/stage_zero_stability.tscn --cycles="${KRAS_STABILITY_CYCLES:-1}"
printf 'Compile and tests passed; inspect device performance separately.\n'
