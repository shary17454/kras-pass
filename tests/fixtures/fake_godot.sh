#!/bin/sh
# Only used by the shell wrapper regression test; never a production engine.
printf '%s\n' "${KRAS_FAKE_OUTPUT:-wrapper success probe}"
exit "${KRAS_FAKE_EXIT:-0}"
