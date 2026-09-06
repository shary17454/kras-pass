#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CPP="${GODOT_CPP_PATH:?Set GODOT_CPP_PATH to the godot-cpp checkout}"
SCONS="${SCONS:-scons}"
PIN="714c9e2c165db2dcb7e6ea57e62a04204d3cfbfa"
test "$(git -C "$CPP" rev-parse HEAD)" = "$PIN" || { echo "Wrong godot-cpp revision" >&2; exit 1; }
DEVELOPER="$(xcode-select -p)"
cd "$ROOT/native/apple"
for variant in device simulator; do
  ARCH=arm64
  SIM=no
  LIB="libgodot-cpp.ios.template_release.arm64.a"
  if [[ "$variant" == simulator ]]; then
    ARCH=universal
    SIM=yes
    LIB="libgodot-cpp.ios.template_release.universal.simulator.a"
  fi
  GODOT_CPP_PATH="$CPP" "$SCONS" platform=ios target=template_release arch="$ARCH" \
    ios_simulator="$SIM" ios_min_version=15.0 build_profile=build_profile.json \
    IOS_TOOLCHAIN_PATH="$DEVELOPER/Toolchains/XcodeDefault.xctoolchain" -j6
  mkdir -p "bin/$variant"
  xcrun libtool -static -o "bin/$variant/libKrasApple.a" "bin/libKrasApple.$variant" "$CPP/bin/$LIB"
done
STAGING="$(mktemp -d)"
xcodebuild -create-xcframework -library bin/device/libKrasApple.a \
  -library bin/simulator/libKrasApple.a -output "$STAGING/KrasApple.xcframework"
if [[ -d bin/KrasApple.xcframework ]]; then
  mv bin/KrasApple.xcframework "$STAGING/previous.xcframework"
fi
mv "$STAGING/KrasApple.xcframework" bin/KrasApple.xcframework
