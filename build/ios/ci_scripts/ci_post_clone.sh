#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CI_PRIMARY_REPOSITORY_PATH="$ROOT" "$ROOT/ci_scripts/ci_post_clone.sh"
