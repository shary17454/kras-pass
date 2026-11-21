#!/bin/sh
set -eu

printf '%s\n' 'Xcode Cloud builds are disabled. Use tools/export_ios.sh and tools/archive_ios_local.sh with local Xcode 27 or newer.' >&2
exit 1
