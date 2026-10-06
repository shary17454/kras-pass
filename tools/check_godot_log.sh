#!/bin/sh
# Engine exit zero is insufficient when a GDScript suite aborts.
set -eu
log="$1"
mode="${2:-runtime}"
if [ ! -f "$log" ]; then
  printf 'Missing Godot log: %s\n' "$log" >&2
  exit 1
fi
if grep -Eq 'SCRIPT ERROR:|Parse Error:|Failed to load|Error importing|FAIL:|FAILED|Required object .* is null|ObjectDB instances? (was |were )?leaked|resources still in use|RID allocations|PagedAllocator.*pages in use|Texture with GL ID.*leaked' "$log"; then
  printf 'Godot failure in %s\n' "$log" >&2
  exit 1
fi
if [ "$mode" = import ] && grep -q 'ERROR:' "$log"; then
  printf 'Godot import error in %s\n' "$log" >&2
  exit 1
fi
if [ "$mode" = tests ] && ! grep -Eq '^ALL TESTS PASSED[^0-9]*[1-9][0-9]* assertions$' "$log"; then
  printf 'Missing positive completed test summary in %s\n' "$log" >&2
  exit 1
fi
