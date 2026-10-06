# Island Bridge Walking Qualification

Base: 8a393da147c90eb0738440ffa25fa23dbfe580b0.
Branch: fix/kras-island-bridge-gradients.

## Defect and Change

Gem Hollow and Glass Terrace used flat bridges below the raised satellite
floors. Actual movement-only crossings failed at the raised islands.
Replace those bridges with inclined boxes whose top faces meet the central
floor and each satellite's inner floor edge. The slope starts inside the
central island to leave walking headroom for all eight characters. Mesh and
collision use the same transform. Island heights, scoring, spawns, AI,
random calls and network protocol are unchanged.

## Actual Physics Regression

The test uses real Fighter.tick and world collision, with no jump, dash or
teleport during movement. All eight characters cross all five bridges in
both directions on both maps: 160 crossing attempts. Initial placement is
only fixture setup; other fighters' collisions are disabled to isolate
walkability from combat. Each crossing must reach the target on ground.

- Original flat bridges: 1013 assertions passed, 128 failed.
- Initial steep ramp: 1140 passed, one heavy-character crossing failed.
- Final gentler ramp: all 1141 collection/network assertions passed.
- Arena respawn/scoring: 112 assertions passed.
- Arena tiles: 169 assertions passed.
- Compile check: all 396 scripts compile.
- Runtime/test log guards and git diff --check passed.
- macOS engine emitted its existing CA-access diagnostic; these checks
  do not establish certificate-store access or a clean import log.

Logs: /tmp/kras-island-walking-red2.log,
/tmp/kras-island-walking-green.log,
/tmp/kras-island-walking-green2.log,
/tmp/kras-island-bridges-respawn.log,
/tmp/kras-island-bridges-tiles.log,
/tmp/kras-island-bridges-compile.log.

## Rendered Check

Godot 4.7.1 mobile renderer / Metal / Apple M5 rendered Glass Terrace at
1280x720. The screenshot was inspected and is nonblank with inclined
bridges visible. The short five-second steady sample is not physical
iPhone QA, a thermal/battery test or long-session leak qualification.

Artifacts: /tmp/kras-island-bridges-visual.png,
/tmp/kras-island-bridges-visual.json,
/tmp/kras-island-bridges-visual.log.

## Natural Balance Remains Unqualified

Seed offset 900000, unchanged thresholds: 24 baseline matches, 16 paired
difficulty samples and mutated/chaos smoke matches finished naturally.
Mean baseline duration: 88.76875 seconds. Expert edge: 0.51123595505618.
Slot bias: 0.25. Both flags remain: spawn slot advantage and expert bots
no better than easy. Frequent AI falls remain observable; routing across
internal gaps is not fixed by this geometry correction.

Source fingerprint before/after:
6a38459c23a657ed7cdeaf19ffc2cd5140856f47fa69f68eda5417e5e2207c26.
Report: /tmp/kras-island-bridges-natural-report/report.json.
Log: /tmp/kras-island-bridges-natural.log; runtime guard passed.

No full release gate, main merge, Railway deployment, Distribution
archive, App Store upload or review submission qualifies this change yet.
