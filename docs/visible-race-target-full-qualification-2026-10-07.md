# Race target full regression and release state

Repository: shary17454/kras-pass, origin Git SSH.
Branch: fix/kras-visible-race-item-target, draft PR 182.
Tested commit: 37c0dcf9070a37c8bd75f600feadf177e8a57d18.
Tested tree: 34d07fa530946ee1c85a589c348cfec7908d5b5b.
Checkout was clean throughout; only evidence documents were added afterward.

## Current-source full qualification

Command: `GODOT_BIN=/opt/homebrew/bin/godot TMPDIR=/tmp sh tools/check_party.sh`.
Godot 4.7.1 official, headless, fixed simulation FPS 60, isolated saves.
Overall exit 0, evidence: `/tmp/kras-party-check.8cvPs7`.

- All 415 scripts compile.
- Inventory: 514 resources, 22 autoloads, 27 routes, eight characters, zero issues.
- Main suite: 388613 assertions pass, 512.5 seconds.
- Independent Party Race: PASS, all four drivers completed three actual laps.
- Six independent boss checks: Colossus seeds 345/9614/172 and
  Forge/Dreadnought/Sovereign seed 9614; all defeated=true and PASS.
- One stability cycle: 39 matches, zero failures.
- Every stage passed the existing strict Godot runtime/test log guard.
- Server: 204 tests pass, zero failed/cancelled/skipped, exit 0, Node 24.18.0.
  Evidence: `/tmp/kras-race-visible-full-server-tests.log`. All six
  KRAS_*_WORLD_FIXTURE inputs came from this gate's saves-tests folder.
  Loopback only, no production accounts or protected backup operations.
- Fresh `npm audit --json`: zero reported known vulnerabilities. Dependencies
  installed with `npm ci --ignore-scripts --no-audit --no-fund`.

The known macOS CA diagnostic was retained. Error-line inspection also found
the intentional failed-save-write and three Router-load failures in the save
retry/transition recovery fixtures. The stability memory warning is deliberately
injected. Settled texture/material/mesh/audio cache counts were zero; process
memory was 140227310 bytes and script resources remained cached. One short
headless cycle is not proof of long-session leak absence or iPhone FPS/heat/battery.

## Preserved parent-source Rocket Rally warning

The already-running natural test used the unchanged parent source
83f65131b64385cc359fa2dc0090e39a60b60123, NOT the target-selection fix.
Offset 1200000, 24 baseline games, 16 paired comparisons, two stress checks;
authored round window 140 seconds. Process and log guard exited 0, but balance
flag `character advantage` remained: bias 0.25, Expert share 0.7, slot bias
0.125, zero ties. Baseline wins: Barq 9, Nabta 8, Ramla 4, Ghaim 2, Mowja 1;
the remaining three characters had no wins in this sample. Average duration
131.4 seconds. This warning is an unresolved release gate, not a passing
balance qualification, and cannot be erased by the new targeted AI regression.

Raw `rocket-parent-natural-1200000.json` SHA256:
279e0bdcbc6ce4ea8f3cca0cde006a154d1753e5c747c71723175bad62401bd0.
Start/end simulation fingerprint both:
befd16c8f87806665ff89a9de87a83a4ecc7455438ce29c74e5fc7bb4223087e.
The parent checkout remained clean; no source edits occurred during simulation.

## Existing natural GitHub campaign

Run 37616445234, source 96c53f359cbb48663a9a99d3fec5ecf6e16d16af,
remained queued overall with nine completed jobs, no failures. Downloaded eight
available game artifacts into
`/tmp/kras-campaign-37616445234-progress8-20261007` and validated with:

```sh
node tools/balance-report.mjs \
  /tmp/kras-campaign-37616445234-progress8-20261007 \
  96c53f359cbb48663a9a99d3fec5ecf6e16d16af 37616445234 \
  --partial --paired --seed-offset=1200000
```

336 completed runs, eight games, no review flags in these artifacts,
31 games missing. Summary: `campaign-37616445234-partial8.json`.
Source/seed/mirrored-character/stress checks passed per game; overall completion,
balance acceptance and release readiness remain false. This parent campaign is
not a literal qualification of commit 37c0dcf. No duplicate run was started.

## Fresh App Store Connect observation

Read-only Chrome UI inspection of app 6801506973 confirmed the deliverable
version 1.1.10, selected build 107, status Ready for Distribution. App Review
showed no pending submission in the current list. The latest submission,
3b56e07c-a0d2-48a3-a1dd-12179264a9f5, submitted September 28 at 03:25,
was Review Completed and its item 1.1.10 (107) explicitly Approved.
This approval belongs to the old build, NOT the current source or candidate 111.
No previous submission was withdrawn, no version was created, and no metadata
was edited. A new qualified build/version is needed for the requested update.

## Asset provenance spot-check and remaining gates

The six natural-asset manifests contain 27 source files; all exist and match
their recorded MD5 digests, no missing or mismatched files. Their recorded
CC0-1.0 license agrees with the publisher's current
[asset-license statement](https://polyhaven.com/license).
This checks this manifest only, not every asset or a blanket legal clearance.

Complete current-source natural balance, resolve the race character advantage,
finish gameplay/device/performance/Internet/production qualification, and obtain
the outstanding specific approvals before protected operations or phone install.
Do not ship development-beta networking as a verified production feature.
Candidate 111 still lacks teardown and this AI fix. Freeze an approved release
commit, use LOCAL Xcode 27 and the existing Keychain Distribution identity, then
verify the new archive before upload/processing/correct-build review submission.
No main merge, production deployment, phone install, new archive, upload or
review submission occurred in this step. No Xcode Cloud or certificate change.
