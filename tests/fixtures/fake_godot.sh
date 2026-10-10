#!/bin/sh
# Only used by the shell wrapper regression test; never a production engine.
if [ -n "${KRAS_FAKE_TRACE:-}" ]; then
  printf '%s\n' "$*" >> "$KRAS_FAKE_TRACE"
fi
case "$*" in
  *--human-matrix*)
    if [ "${KRAS_FAKE_MATRIX_EXIT:-0}" -ne 0 ]; then
      exit "$KRAS_FAKE_MATRIX_EXIT"
    fi
    ;;
esac
printf '%s\n' "${KRAS_FAKE_OUTPUT-ALL TESTS PASSED - 1 assertions}"
exit "${KRAS_FAKE_EXIT:-0}"
