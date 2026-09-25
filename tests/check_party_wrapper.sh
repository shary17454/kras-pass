#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
OUT="$(mktemp -d "${TMPDIR:-/tmp}/kras-wrapper-test.XXXXXX")"
export TMPDIR="$OUT"
export GODOT_BIN="$PWD/tests/fixtures/fake_godot.sh"
sh tools/check_party.sh > "$OUT/success.stdout" 2>&1
for pattern in \
  'SCRIPT ERROR: runtime failure' \
  'Parse Error: invalid script' \
  'FAIL: invalid result' \
  'FAILED - 1 failed' \
  'Required object "obj" is null' \
  'WARNING: 2 ObjectDB instances were leaked at exit' \
  'ERROR: 1 resources still in use at exit' \
  'ERROR: 1 RID allocations of type' \
  'ERROR: PagedAllocator: pages in use'; do
  if KRAS_FAKE_OUTPUT="$pattern" sh tools/check_party.sh > "$OUT/failure.stdout" 2>&1; then
    printf 'FAILED: wrapper accepted %s\n' "$pattern" >&2
    exit 1
  fi
done
if KRAS_FAKE_EXIT=2 sh tools/check_party.sh > "$OUT/exit.stdout" 2>&1; then
  printf 'FAILED: wrapper ignored an engine failure\n' >&2
  exit 1
fi
printf 'Wrapper checks passed: success path and 10 failure cases. Evidence: %s\n' "$OUT"
