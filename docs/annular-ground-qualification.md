# Annular ground and moving capture zone

## Source defects reproduced

- Ring and oval floor boxes had their short tangent dimension facing radially.
  Authored walkable bands therefore contained physical gaps.
- Extending a segment only to the centerline circumference still left gaps near
  the outer edge after correcting its rotation.
- Ring walls had the same rotation error, pointing long segments into the track.
- Ring/oval inside queries used inner radii inconsistent with their floor definitions.
- Zone Hold interpolated a straight chord between valid ring targets, crossing
  the central hole.

## Changes

- Rotate annular floor and wall segments tangentially.
- Size floor segments for the outer circumference, with a small seam overlap.
- Align inner-edge queries with authored ratios: ring 0.45, oval 0.55.
- Move the capture zone along the shortest circular arc, preserving the existing
  3.2 units/second speed and target RNG sequence. Scoring rules are unchanged.
- Move the existing scoring test fixture onto valid ground rather than the hole.

## Evidence

Godot 4.7.1, isolated saves, existing warmed test checkout (not an App Store archive):

- Initial regression: 279 passed / 165 failed. Log: `/tmp/kras-zone-ground-baseline.log`.
- Rotation and arc alone: 424 passed / 20 failed, revealing outer seam gaps.
  Log: `/tmp/kras-zone-ground-fixed.log`.
- Final regression: **1516 assertions passed**. Log: `/tmp/kras-zone-ground-final.log`.
- Compilation: **324 scripts passed**. Log: `/tmp/kras-ring-compile.log`.
- Both final logs pass `tools/check_godot_log.sh`.
- A byte comparison of 352 tracked `.gd`, `.json`, `.tscn` and `project.godot`
  inputs under src/tests/data/scenes against the warmed runtime found zero
  mismatches. This is not a clean release export or native-asset comparison.

Coverage includes ring band rays at segment centers and seams; signed inner-edge
queries; constant-radius capture motion to an opposite target; its speed bound
and arrival; existing scoring/reset/network replica behavior; translated oval
physics and query agreement; tangent wall orientation. Rays distinguish the top
of a boundary wall from playable floor.

The first attempted test invocation incorrectly used `--script` without the
project autoload scene. It produced an AudioManager compile error and is not
counted as a test result. Subsequent runs use `tests/test_runner.tscn`.
The macOS sandbox CA lookup diagnostic is unrelated to these physics tests and
does not prove production TLS connectivity.

## Still required

- Full integration regression completion and current-source balance campaign.
  The local integration run `/tmp/kras-ring-matches.log` was deliberately stopped
  with SIGINT during the real Rocket Rally race to avoid duplicate exhaustive
  execution on the busy Mac. It had no completion summary and is **not passed**.
  Exact implementation commit `d858611` is targeted by Game Quality CI run
  `37145129237`; its core job runs `tools/check_party.sh`, including the full
  integration suite, and separate jobs cover all 39 peer scenarios. Results
  must be inspected after completion; queued is not a pass.
- Investigate AI paths around the central hole; this change does not add routing.
- Do not infer that the historical spawn advantage is fixed from geometry tests.
- Real iPhone/iPad rendering, touch, frame-rate, thermal and battery qualification.
- This branch is not merged to main and is not an archive, upload or review submission.

## Production and remote qualification snapshot

- PR #28 contains the new geometry fixes; implementation commit:
  `d85861137c7663fb2f84899a0e27100f58f90cfc`.
- GitHub Game Quality run `37145129237` targets that commit and was queued at
  inspection. No CI completion is claimed.
- Main remains `2759b89a04571cccd79fcd15ed31af3e88312184`.
- Railway deployment `c95c8cf1-4810-4d4b-ad1f-98f51fb77b5d` reports SUCCESS for
  that exact main commit, repository `shary17454/kras-pass`, branch main.
- Production `/health`: ok=true, authentication_ready=true,
  multiplayer_enabled=false. This does not prove a real Apple authentication
  exchange, app-to-server connectivity, or production online play.
- Last 40 deployment log lines showed normal container startup, no startup
  errors in the returned sample, and a configuration-as-code deprecation warning
  requiring migration before 2026-12-01. Bounded logs do not prove absence of
  errors across the full service history.
- Earlier main run `37139354043` is completed/cancelled, not passed. The new main
  run `37144298835` was queued at inspection.
