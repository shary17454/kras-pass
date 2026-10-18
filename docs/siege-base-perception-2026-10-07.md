# Rendered Siege-Base Observation

Repository: shary17454/kras-pass. Remote: origin.
Branch: fix/kras-siege-rendered-base-observation.
Runtime/test commit: cbfe94087763ca7e314e2798921a14e4d7a0b842.
Parent: 650d79a8c2b1995e521b9703c8948605b0130013.

## Defects and Fixes

The siege brain previously treated hierarchy-visible bases as observed,
immediately read their live positions and fractional health, and could retain
its previous movement with no visible target. A base behind the camera or
cover remained attackable. The controller now provides base_observation:
an actual observable crystal, its instance identity, rendered X/Z location
projected onto the known arena floor, and the same whole health percentage
displayed in HUD. Existing unfiltered getters remain for HUD/replay/tooling.

Each base has bounded HISTORY_CAP observation samples. The difficulty's
reaction deadline gates first visibility, health and moving crystal position.
Hidden/out-of-camera/occluded crystals and replacement identities invalidate
old knowledge. Round restart and reconfiguration clear history. Defence and
offence use the same cue; absent targets clear stale movement. The existing
seeded selection jitter, damage, collision shape, score and network payloads
remain unchanged. Changed target eligibility can alter natural outcomes.

The physics-cover regression also showed that base collision proxies were
not associated with visible geometry, so AI saw through foreground bases.
Each proxy now references its named Crystal. The shared sight predicate
recognizes its own referenced cue without self-occlusion, and recognizes
compound visual groups as opaque cover. Metadata reference following is
disabled while traversing that reference, preventing reference cycles.

## Focused Evidence

- Initial actual-scene four-tier regression: 9 passed, 36 failed.
  Log: /tmp/kras-siege-observation-red.log.
- First corrected path: 45 passed. Expanded memory/movement/camera checks:
  77 passed. Logs: /tmp/kras-siege-observation-green.log and
  /tmp/kras-siege-observation-expanded.log.
- Actual foreground base-cover probe: 81 passed, 4 failed. Retained logs:
  /tmp/kras-siege-cover-red.log and /tmp/kras-siege-cover-probe.log.
  The centre physics ray hit the foreground proxy, but its compound visual
  cue was treated as geometry-free. The earlier green-named diagnostic also
  failed and is not passing evidence.
- Final four-tier suite: 85 assertions passed, including real collision
  cover, self-proxy visibility, camera bounds, crystal replacement, 32-sample
  cap, HUD health rounding, delayed moving position and round reset.
  Log: /tmp/kras-siege-cover-final.log.
- Existing visible-target suite: 3997 assertions passed.
  Log: /tmp/kras-siege-ai-visibility.log.
- git diff --check passed. The legacy synthetic base fixture now supplies
  actual crystal geometry; it does not bypass the observation contract.

## Exact-Source Full Gate

The full gate on cbfe94087763ca7e314e2798921a14e4d7a0b842 exited 0:

- 404 scripts compile; inventory: 497 resources, 22 autoloads, 27 routes,
  eight characters, zero issues.
- 373190 assertions passed in 338.6 seconds.
- Separate real three-lap race and six boss regression probes passed.
- Stability: 39 matches, zero failures. Materials, meshes, textures and
  audio PCM caches drained to zero; settled memory: 141688548 bytes.
  This one-cycle probe does not qualify long-term leaks or physical phones.
- Strict Godot log guards passed; the OS memory warning is an intentional
  stability fixture.
- Final server run: 204 passed, zero failures/cancellations/skips,
  1232.1755 ms, all six fresh current-run Godot world fixtures supplied.
  The earlier attempt ran before the fixtures were available: 198 passed,
  six ENOENT failures. It is retained and not counted as a success.

Evidence directory:
/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.9f3rVl
Logs: /tmp/kras-siege-observation-full.log,
/tmp/kras-siege-observation-server.log (initial failed attempt),
/tmp/kras-siege-observation-server-final.log.
Runtime/tests remained unchanged during qualification. The rendering smoke
ran concurrently for part of this gate; elapsed times are not performance
improvement evidence.

## Natural Balance Sample

Current-source base_siege at offset 600000 completed with exit 0 and strict
log guard PASS: 24 baseline, 16 matched-seed/character difficulty comparisons
and two mutator matches. Wall duration: 94.9 seconds. Source fingerprints
before/after both equal
d6c037c965cb39a4de84a2690d17d0b704cc10e507ba5574a4b59f1d7c920700.
Expert edge: 0.563636363636364; slot bias: 0.125; character bias:
0.166666666666667; average natural round: 77.8229166666635 seconds;
baseline tie rate: zero. No flags in this sample. No paired pre-change
campaign or READY promotion; absence of flags does not prove full balance.
Report: siege-base-natural-600000.json.
Log: /tmp/kras-siege-observation-natural.log.

Mac rendering smoke: two captures, no blank images, exit 0. Both actual
images were visually inspected. The landscape HUD health percentage is
partly obscured by character portraits and remains a polish defect despite
the automated nonblank checks passing. This has not been fixed in this
observation commit. Portrait/landscape images:
/tmp/kras-siege-base-visual/screenshots/base_siege-portrait.png
/tmp/kras-siege-base-visual/screenshots/base_siege-landscape.png
Log: /tmp/kras-siege-base-visual.log. Existing Compatibility AA warning is
retained. This desktop rendering probe is not physical iPhone/iPad QA.

## Four-Peer Local Network Smoke

The same runtime/test commit passed the actual four-Godot-peer localhost
base_siege smoke (seed 609001), exit 0. All peers moved and received the
same scores [9, 24, 43, 19]; the host and one guest reconnected. The server
closed the results room normally when the host left. This uses scripted
human inputs and a shortened fixture, not four physical players or Internet
production acceptance.

Server loop summary maximum: 87 ms. Detailed operation maxima include
16.0945 ms input, 5.369792 ms snapshot and 17.886125 ms leave. The timing
report recorded no threshold stalls; these values do not prove sustained
frame rate or network latency. No replacement run was used to hide timing.
Log: /tmp/kras-siege-four-peer.log.
Evidence: /var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-m3mC47
(including server-timing.json and four peer logs).

## Release Limits

No main merge or production rollout. All-game current-source balance,
independent physical iPhone/iPad gameplay, performance/thermal/battery and
Internet production acceptance remain outstanding. No new signed local
Xcode 27 Archive, upload, processing or Apple review submission is proven by
this fix. No P12 import, new certificate or certificate revocation.

Draft PR: https://github.com/shary17454/kras-pass/pull/159, based on the
hover-machine observation branch. Attaching to the task failed at the
existing 100-identity cap; unrelated task attachments were not removed.
