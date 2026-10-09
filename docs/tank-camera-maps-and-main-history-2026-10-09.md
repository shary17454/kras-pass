# Tank Camera Maps And Main History

Tested runtime commit: `e8b83fe74e39a6905882c27e545adb37f90b673e`.
Runtime fingerprint:
`879ddd3bd82bebf03430f1b74fc98c0255c2e7ac949f598fbfb977be84c5e86f`.

## Expanded Camera Smoke

Three sequential real local Metal sessions completed, each exit 0 and six
captures without capture failures:

- Arabic, one human and three bots, all three tank maps, both orientations.
- Arabic, four human touch slots, all three maps, both orientations.
- English, four human touch slots, all three maps, both orientations.

Each capture ran two additional seconds after live play began. Independent
JSON checks verify six unique map/orientation pairs per session, actual arena
matches requested arena, human count, valid control bounds, no active pause or
pause menu, nonblank colours and nonempty PNG. All three engine logs pass the
runtime checker. This is smoke evidence, not human input, full match completion
or physical iPhone/iPad/controller/performance acceptance.

Manually inspected four images: Arabic four-player foundry portrait, Arabic
four-player frost landscape, Arabic single-player oasis portrait, English
four-player oasis landscape. Full manual visual acceptance of all 18 images
is not claimed. Evidence is retained at
`../qualification-tank-camera-maps-2026-10-09/`.

## Content Finding

Map identifiers do not imply their displayed themes. Current localized names
are Rocky Pass / الممر الصخري, Woodland Valley / وادي الغابة and Pine Highlands /
مرتفعات الصنوبر. In particular `tank_frost` currently is not a snow world.
All three use tank_world.gd's same 5x5 road graph, same ground-height algorithm,
shared battlefield terrain shader, shared vegetation and exterior river;
variant changes noise seed, rock selection and vegetation seed. The inspected
images still look like closely related rocky terrain. This does not satisfy
the requested radically distinct world layouts and environments. That content
rework remains open; passing nonblank/camera smoke must not mark it READY.

## Main History Reconciliation Without Production Promotion

Read-only merge-tree produced tree
`6e9d15201d62afac1274cec2567d1ebb6f0f1a63`, identical to tested e8b83fe's tree.
There was no content conflict or additional untested main content. The three
main-only commits were historical merge commits, not three missing fixes.

Merged origin/main `062a40992b92958573e28e19d8c8c1840560797a` into the feature
branch with commit `89392d49ea08eb0acfc0825ca86f0c98e85f26d4`. Parents are
e8b83fe and 062a409; resulting tree exactly matches the tested tree above.
`git merge-base --is-ancestor origin/main HEAD` exits 0. No force push,
history rewriting, worktree reset, main push or production deployment occurred.
Main can now be promoted by fast-forward after acceptance gates, rather than
requiring a conflicting-content merge. Recheck remote main before promotion.

## Ongoing Qualification

Core run 37974597119 was confirmed in progress on e8b83fe, importing assets.
Network run 37970339411 and balance run 37971414154 remain queued on d9841d2,
which predates the camera change; they cannot qualify this runtime. No run was
cancelled or restarted. Current signed archive/IPA predates the camera fix.
No App Store upload or review submission occurred. Production-data operations
and device replacement still require their specific pending authorization.
