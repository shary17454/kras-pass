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
if [ "${KRAS_FAKE_OUTPUT+x}" != x ]; then
  case "$*" in
    *tests/compile_check.tscn*)
      printf '%s\n' 'compile check: 1 scripts' 'OK - every script compiles'
      ;;
  esac
fi
printf '%s\n' "${KRAS_FAKE_OUTPUT-ALL TESTS PASSED - 1 assertions}"
exit "${KRAS_FAKE_EXIT:-0}"
