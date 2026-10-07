# Teardown regression follow-up

Tested runtime commit: 7bf1f4fb1e59b13f5a390ff6c23a9e1e72365efc.
The tree was clean during the full run. No runtime source edits occurred.

## Retained failing full run

`GODOT_BIN=/opt/homebrew/bin/godot TMPDIR=/tmp sh tools/check_party.sh`
returned exit 1 at the main tests stage. Evidence:
`/tmp/kras-party-check.i8DMbk`.

Compilation passed for 415 scripts; inventory passed with 514 resources,
22 autoloads, 27 routes, eight characters and zero structural issues.
The main suite took 463.0 seconds and reported 388329 passed, 240 failed.
All 240 failures were collection bridge walking after the first slot, with
`body->get_space()` null diagnostics. Later independent race/boss/stability
stages were NOT executed because the gate stops on failure.

The collection fixture called `scene.teardown()` inside its `for slot in 4`
loop, while queue_free remained outside that loop. Previously teardown did
not stop the scene, so later slots could still be moved despite cleanup.
The new production teardown correctly retires the scene; the fixture was
therefore using retired physics bodies for slots 1-3.

## Corrected fixture and executed verification

Moved teardown outside the slot loop, immediately before queue_free. Added
one assertion per slot that the scene has not been retired. Existing walking
and supporting-ground assertions were retained; no gameplay geometry or
runtime movement was changed and no checks were skipped.

Collection network isolated suite: 1237 assertions, 14.6 seconds, exit 0,
runtime guard passed. Includes actual bridges on two arenas, all eight
characters, five islands in both directions and shared AI steering routes.
Evidence: `/tmp/kras-teardown-collection-fixed.stdout` and `.log`.
The earlier isolated reproduction also failed; retain
`/tmp/kras-teardown-collection-isolated.log` as failed evidence.

Full server suite: 204 passed, zero failed/cancelled/skipped, exit 0.
`/tmp/kras-teardown-server-tests.log`. All six KRAS_*_WORLD_FIXTURE variables
pointed to armed/siege/forge/dreadnought/sovereign/colossus-world.json in
THIS full run's `/tmp/kras-party-check.i8DMbk/saves-tests` directory.
These independent world captures were generated before collection failures;
server success does not turn the failing Godot gate into a passing one.
Only loopback networking was allowed; no production account operation.

`npm ci --ignore-scripts --no-audit` installed the locked dependencies.
`npm audit --json` exited 0 and reported zero known dependency vulnerabilities.
This is not proof of application security or production AUTH correctness.
`git diff --check` passed.

## Completed old-source natural campaign evidence

Downloaded all 39 natural-balance artifacts from run 37577604329, source
c5fa1f9813478ed8ab3a6ef26033e93b57b65928, offset 1200000.
`node tools/balance-report.mjs /tmp/kras-campaign-37577604329-all39
c5fa1f9813478ed8ab3a6ef26033e93b57b65928 37577604329 --paired
--seed-offset=1200000` verified source/checkout IDs, 24 baseline seeds,
16 mirrored same-character difficulty matches and two stress matches per game.
1638 matches completed, no missing game, pairing verified.
Summary: `campaign-37577604329-all39.json`.

Four retained review warnings: base_siege and blast_ball expert performance;
sabaq_sawarikh and star_rush character advantage. Base Siege expert edge
0.50920245398773; armed racing character bias 0.25 with Barq nine and Nabta
eight baseline wins out of 24. Neither changing thresholds nor hiding flags
is an accepted fix. Current-source reproduction/acceptance remains required.

Boss baseline defeated counts: Colossus 22/24, Dreadnought 24/24, Forge 24/24,
Sovereign 23/24. All paired boss samples defeated the boss, but several stress
matches ended with the boss surviving. Completion is not an objective victory.
At final inspection 40 jobs had completed successfully; workflow still queued
with empty conclusion. Artifact verification is complete, not release approval.

## Next gates

The main-suite fixture correction needs a fresh complete gate, followed by
independent race/boss/stability stages. Existing current-parent balance run
37616445234 remains live/queued with two successful jobs at inspection; it
does not test the later teardown patch. No duplicate campaign was dispatched.

No source promotion to main, production export/deployment, physical device
installation, new Distribution archive, upload or review submission occurred.
Candidate 111 is preserved but is not the release containing this fix.
