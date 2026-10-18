# Arabic Round Progress and Rendered Qualification

Base: `e16b88ed3fa239fa3b762ba93f09c6cfc590bad1`.
Runtime change: `6bcf90ab3737ebdc65e2b96bebb08b13f987021d` on
`fix/kras-round-label-clarity`. No main merge or release upload occurred.

## Reproduced Issue

In the actual Arabic portrait capture, round 1 of 3 appeared as `3 / 1`.
The text mixed an RTL sentence with a slash-separated numeric fraction.
The Arabic localization now uses a word between values: round 1 of 3.
The English string and all scoring/round lifecycle behavior are unchanged.

The localized HUD test failed one assertion before (10 passing), then passed
11 assertions after. The content/localization suite passed 121 assertions.
Strict log guards passed. A fresh rendered portrait capture was inspected;
the intended current/total order is readable without a bidi fraction.

Evidence:

- `/tmp/kras-round-label-red.log`
- `/tmp/kras-round-label-green.log`
- `/tmp/kras-round-label-content.log`
- `/tmp/kras-round-label-before-portrait.png`
- `/tmp/kras-round-label-after-portrait.png`

## Rendered Checks

Godot 4.7.1 official on Metal Forward Mobile, Apple M5; these are desktop
windows at 1280x720 and 540x960, not physical iPhone/iPad viewports.

Before the text change, `party_visual_check` passed with zero failures:
Arabic/English menus, tournament standings/podium, local profiles/settings,
touch customization, four-touch match HUD, vehicles and racing in both
orientations. Its repeated run after the change also passed with zero failures.
Log: `/tmp/kras-round-label-party-visual.log`.

The all-game Arabic run on the unchanged base completed 78 captures, zero
failures: 39 registered games, default arena, one touch-configured human and
three bots, both orientations and one additional second of play per scene.
Report: `release-qualified-all39-ar-visual-report.json`.
Log: `/tmp/kras-qualified-all39-ar-visual.log`.
Its Arabic run predates the text correction; it is not a new full all-game
rendered qualification of the changed source.

The corresponding English all-game run on the changed source completed with
78 captures, zero failures and a passing strict log guard, using the same
player count, default arenas, orientations and additional play duration.
Report: `release-qualified-all39-en-visual-report.json`.
Log: `/tmp/kras-qualified-all39-en-visual.log`.

Manual inspection found an open portrait tank HUD defect: the objective line
crosses the radar. The automated smoke test does not check that intersection.
Evidence: `/tmp/kras-qualified-all39-en-visual-save/screenshots/tank_arena-portrait.png`.
`tank_radar.gd` uses a fixed portrait Y of 450, while the portrait objective
has a fixed Y of 460; these independently positioned overlays overlap.
The next fix needs a shared clearance rule and a rendered regression, not a
suppressed objective or a blanket READY classification.

Nonblank sampled pixels, expected fighter count and no new logged gameplay
errors are rendering-smoke evidence. They do not prove all map variants,
input-device/player combinations, complete matches, balanced AI or polished
content. Selected captures were manually inspected; not all captures received
manual visual acceptance. No READY promotion follows from these results.

## Device and Release Gates

Fresh local Xcode 27 devicectl reports the physical iPhone 16 Pro Max as
unavailable. No native device performance, thermal, battery or gameplay
acceptance was obtained in this run; simulators are not substitute proof.
All-game balance/perception/polish, physical-device QA, approved source
promotion, production protocol/API/auth/backup/deployment acceptance,
frozen release version/build, local Distribution Archive, signature validation,
upload, processing and separate App Review submission remain incomplete.
No Xcode Cloud build, certificate import/change or Apple submission occurred.
