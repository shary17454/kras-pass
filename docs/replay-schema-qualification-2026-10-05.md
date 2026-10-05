# Replay Metadata Validation

Implementation: `c4fdad7175700615bc071da3b27eb6432d7e55d4`.
Parent: `363c82116b69d41e7487ebf9a7d46534b604de12`.

## Scope

The replay reader previously iterated or assigned unchecked Variant metadata
to typed containers. Validate metadata before decoding or creating ReplayData:
scalar types, finite numeric fields, integral counters, required player keys,
valid unique slots, container/member types, correction ticks, checkpoint
hashes, world-event channel arrays and playback highlight markers.
Invalid metadata returns null with a warning, without deleting the file.
The existing library/player already handles an unreadable recording.

Preserve numeric values parsed by JSON as floating point when integral.
Preserve historical string correction-tick keys emitted by to_dict(). No
format version bump, invented inputs, score changes or migration downgrade.
Older pre-v4 recordings still follow their existing input-format migration.

## Verified Locally

Godot 4.7.1, headless macOS, explicit logs, isolated synthetic saves:

| Check | Result | Log |
| --- | --- | --- |
| Schema, v1-v5 and actual corrupt JSON disk reads | 75 assertions passed | `/tmp/kras-replay-schema-disk-final.log` |
| Existing record/save/replay integration | 71 assertions passed | `/tmp/kras-replay-schema-integration-final.log` |
| Profiles, rewards and replay configuration integration | 133 assertions passed | `/tmp/kras-replay-schema-progress.log` |
| All scripts compile | 354 scripts passed | `/tmp/kras-replay-schema-compile.log` |

All final processes exited zero and passed completed-summary and runtime/leak
log guards. Warnings for deliberately malformed metadata, future versions
and the existing capture budget are expected test behavior, not hidden errors.
No player's actual saves were accessed or replaced.

The first integration run rejected valid historical string correction ticks:
41 assertions passed, 2 failed (`/tmp/kras-replay-schema-integration.log`).
Production validation was corrected to accept the original format; the
existing round-trip and real playback assertions were not relaxed. The final
integration records and replays Zone Hold and a chaotic Ring Rumble fixture,
not every minigame or every map at natural duration.

## Still Required

This is not complete hostile-file validation: base64 payload integrity,
world-event-specific schemas, byte/retention budgets and atomic storage still
need qualification. The current four-minute capture limit remains; long
race replays and all-game correction fidelity are not certified here.
No online, physics, assets or production Railway configuration changes.
Full CI, physical-device QA, source integration and exact-source App Store
distribution/review remain distinct pending release gates.
