# Current-source four-local visual smoke

Source `34cb00f` is a documentation-only descendant of gameplay source
`78d11abdb35144a6c754414487606093dd5c1435`. Unchanged simulation fingerprint
before/after both rendered sweeps:
`b90edfc4d8fb5f0b42fa8063f41e564f252a0c9f40ea09e2f3e2db1fa990d553`.

Ran `tests/stage_zero_visual.tscn` twice with official Godot 4.7.1, actual
Metal 4.0 / Forward+ on Apple M5: Arabic and English. Four configured human
touch slots, zero AI, one extra play second per capture. Isolated test storage,
not actual human input. Both runs exit zero and pass strict runtime log guards.

## Verified automatic coverage

Each language: 39 games, one default arena each, 1280x720 landscape and
540x960 portrait, 78 captures, zero failures. Independently checked both JSON
reports for exact counts, unique game IDs, all passed rows, four human slots,
touch slots `[0,1,2,3]`, bounded controls and nonblank sampled colors. Total
156 captures. Raw reports: `qa/contact-four-local-2026-10-08/{ar,en}.json`.

These checks do not detect every aesthetic/readability problem or verify
physical finger ergonomics. They skip introduction waiting by following legal
lifecycle transitions and do not establish first-launch or tutorial quality.

## Manual image observations and remaining polish

Inspected Arabic tank_arena landscape/portrait, goal_guard portrait,
blast_ball portrait and boss_colossus portrait; English goal_guard portrait
and tank_arena landscape. Images are nonblank, opponents are present, the
reviewed controls are separated, and vehicle views show each local player.

The four-human Colossus portrait capture leaves relatively small characters
inside the shared arena. Automated nonblank/control-bound checks pass, but
the capture does not sign off player recognizability or touch gameplay on a
phone. Retain a real-device readability/playability polish gate; do not infer
READY or certify all 156 images from this seven-image manual review.

All images, raw reports and engine logs are retained outside Git under the
workspace sibling `qualification-contact-visual-2026-10-08/{ar,en}/`.
Report image paths preserve their original `/tmp` capture provenance; retained
copies have the same filenames under each locale's `screenshots` directory.
No local profile, account secret or replay library is committed.

## Release boundaries

No physical iPhone/iPad or native safe-area test, gamepad/touch interaction,
sustained frame-time/thermal/battery measurement or Internet test occurred.
Current full network matrix `37812970245` and natural campaign `37813002835`
were verified running/queued on the exact gameplay source, not completed.
No restart/cancellation, main merge, Railway change, native archive, upload,
review withdrawal or App Store submission was performed.
