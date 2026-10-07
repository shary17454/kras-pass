# Platform Visible Shove

Base: 879e3ac96277538fbaa4878a600726bdf8f80ae4 (PR 151).
Runtime: e72616fa1349daf9d0b5726214bccf73a9c350e1.
Branch: fix/kras-platform-visible-shove. No main merge or deployment.

Platform AI could use the live state of a hidden tile under a visible rival
to trigger an opportunistic attack. Visibility of the rival does not establish
visibility of the floor. The warning-based branch now requires can_observe
on the tile, reusing the existing visibility, camera and occlusion logic.
Ordinary aggression attacks remain permitted without reading hidden floor
state. No speed, physics, difficulty, round duration or balance thresholds
were changed. This is a perception fix, not a complete balance redesign.

## Regression Evidence

The same three-state fixture before the runtime change failed all three new
assertions, with 3962 existing assertions passing. After the runtime change,
all 3965 passed: hidden warning gives no attack request, showing it enables
one request, and hiding it removes warning-based credit. The probe overrides
only attack execution to count requests; it uses the actual decision and
observation implementation. Aggression is zero to isolate this warning cue.

Additional suites: platform_ground_routing 41 passed;
ai_compound_visibility 26 passed; all 398 scripts compile. Strict log guards
and git diff --check passed. Logs:
`/tmp/kras-platform-shove-{red,green,routing,compound,compile}.log`.

The full 371697-assertion and unsigned Xcode 27 qualification in
sweeper-full-qualification-2026-10-07.md belongs to the parent source,
not this changed runtime. Fresh integrated regression and export are required
before a final archive; no current Apple archive/signature/upload is claimed.

## Natural Crumble Court Sample

24 baseline matches, 16 matched-character/seed difficulty matches and two
mutator/chaos matches completed naturally, with no forced winner or shortened
clock. Seed offset 600000. Expert score share .59375, slot bias .0833333,
character bias .0833333, average duration 12.6125 seconds, zero flags.
Both stress cases passed. Runtime fingerprint start=end:
`7759b43921521f721534f21d8554f5c99c077080661c2838cc78a7cc2ae60776`.
Report: platform-visible-shove-natural-600000.json.
Log: `/tmp/kras-platform-shove-natural.log`; strict log guard passed.

The measurement used exactly this runtime before committing it, with no
runtime edits during the run. There is no paired baseline in this experiment,
so it does not prove the visibility correction caused better balance. One
clean sample does not erase earlier difficulty warnings or certify READY.

## First Completed Current Campaign Artifact

GitHub run 37549144464, natural-balance-ring_rumble artifact 11452929254,
source 3c4bbdb6d7437803cd53bba3e721b872ebb4675f, offset 900000:
24 baseline + 16 matched difficulty + two stress completed naturally.
Expert score share .583850931677019, slot bias .0416667, character bias
.0833333, mean duration 44.3993 seconds, zero flags; both stress cases passed.
Fingerprint start=end:
`cc80fc3c03e82587d7454edc8a401cfbda70d9133c4c7f9f3f10462efb06beaf`.
Report: hud-campaign-ring-natural-900000.json.
Downloaded evidence: `/tmp/kras-hud-campaign-ring-report`.
Its balance-source.json and report counts were checked. This source predates
the Sweeper and Platform fixes. Other campaign jobs remain outstanding;
neither all-39 completion nor current-source READY is claimed.

## Open Release Gates

Current all-game balance/polish/perception; physical iPhone/iPad gameplay,
FPS, thermal, battery and controller acceptance; approved source promotion;
production backup/restore/migration and coordinated network protocol rollout;
production API/native Apple auth/Internet acceptance; valid ASC session and
fresh version/build inventory; frozen source and local Xcode 27 Distribution
Archive/signature verification, upload, processing and separate submission.
No P12 import, certificate change, production account export or Xcode Cloud use.
