#!/bin/sh
# Only used by the shell wrapper regression test; never a production engine.
printf '%s\n' "${KRAS_FAKE_OUTPUT-ALL TESTS PASSED - 1 assertions}"
exit "${KRAS_FAKE_EXIT:-0}"
