# Magnet Owner Release

## Defect and Fix

`MagnetCourt._release` previously cleared the entire held-ball ownership map
when its keeper body was missing. This also discarded unrelated keepers'
captures and left the departing keeper's ball parked with zero speed.

Release now follows the existing owner-specific launch and erase paths even
without a keeper body. The launch uses the existing goal-side direction,
release speed, seeded fan jitter and scoring credit. Spatial audio is skipped
only when the keeper body is unavailable. Other owners are not changed.
No character stats, AI advantages or balance thresholds were changed.

## Verification

A regression in `tests/suites/test_magnet_network.gd` temporarily removes one
keeper from the context while two keepers each hold a ball, then restores the
body before teardown. It checks owner isolation, launch generation, shot speed,
scoring credit and unchanged position/velocity of the other held ball.

- Before fix: 193 assertions passed, four failed. Log:
  `/tmp/kras-magnet-owner-red.stdout`.
- After fix: all 197 magnet network assertions passed. Log:
  `/tmp/kras-magnet-owner-green.stdout`; strict test log guard passed.
- Shared AI visibility: 2091 assertions passed. Log:
  `/tmp/kras-magnet-owner-visibility.stdout`; strict test log guard passed.
- Actual local WebSocket server and four independent Godot clients passed.
  Every client moved and agreed on scores `[23,23,16,22]`. The designated guest
  reconnected; the host result-submission reconnect also passed. This does not
  prove arbitrary host migration. Log: `/tmp/kras-magnet-owner-network.stdout`.
  Peer evidence: `/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-5oITOc`.
- `git diff --check` passed.

The network harness uses scripted inputs, shortened rounds and local transport,
not human play or production Internet connectivity. Full immutable-source CI,
the natural balance campaign, phone QA and release signing remain separate
gates. No main merge, production change, archive or App Store upload occurred.
