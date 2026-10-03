#!/bin/sh
set -eu

ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(pwd)}"
bash "$ROOT/ci_scripts/export_current_ios.sh"
