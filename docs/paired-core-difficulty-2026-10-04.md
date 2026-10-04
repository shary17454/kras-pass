# Paired core difficulty comparison

## Source and defect

Based on `b205f9727c319c0cd4e200a3218a74b961f9a0c3`, the core integration
comparison alternated Expert/Easy slots while changing the world seed every
match. Its claim to cancel spawn advantage with mirrored seeds was incorrect.
The preceding full core run failed Gem Grab at 72 versus 74 points. That failure
is retained in `/tmp/kras-threaded-resource-core.log`; it is not reclassified
as a passing run.

The comparison now runs both assignments for each of the original eight seeds
(100, 137, 174, 211, 248, 285, 322, 359): 16 matches per game rather than eight.
All competitors still use Fanoos, powerups remain disabled, the configured
round duration stays 30 seconds, and normal match tie handling remains active.
No runtime AI, movement, character, scoring or perception code was changed.

The strict aggregate Expert > Easy gate remains. A new completion assertion
requires all 16 matches to return results; failed matches cannot silently
reduce the sample count. Each sample logs its game, seed, assignment and scores.

## Executed evidence

```sh
/opt/homebrew/bin/godot --headless --fixed-fps 60 --path . \
  --log-file /tmp/kras-paired-core-difficulty.log tests/test_runner.tscn -- \
  --test-data-dir=/tmp/kras-paired-core-difficulty-save \
  --suite=matches --difficulty-only
```

Godot 4.7.1 on macOS: exit 0, five assertions passed, 160.3 seconds.
The runtime log guard passed. An independent log check required 32 samples,
exactly two opposing assignments for every expected seed, and strict aggregate
separation for both games:

| Game | Seeds | Completed matches | Expert points | Easy points |
| --- | ---: | ---: | ---: | ---: |
| gem_grab | 8 | 16 | 180 | 125 |
| crate_smash | 8 | 16 | 666 | 183 |

Compilation: 341 scripts passed, exit 0; log guard passed.
Log: `/tmp/kras-paired-core-compile.log`. `git diff --check` passed.
The macOS headless run emitted the previously observed system CA lookup
warning; no script error or resource leak was reported by the log guard.

## Qualification limits

This repairs the comparison instrument and passes this specific gate. It does
not prove every character, map or minigame is balanced, nor does it establish
cross-platform deterministic replay. All eight seeds were retained rather than
selecting only favorable samples. Individual Expert samples can still lose.

The full core suite must be rerun on the committed final source; the older
30,860-pass/one-failure run remains a failed, older-source qualification.
Complete network CI, graphical four-player online QA, phone/tablet orientation,
frame pacing, thermal and battery tests, production deployment and a verified
Distribution archive/upload/App Review submission remain open release gates.
This branch is not merged into main and does not change the App Store version.
