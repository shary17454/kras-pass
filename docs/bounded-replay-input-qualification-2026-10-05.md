# Bounded long replay input qualification

## Change

Input recording and playback now use `ReplayInputBuffer`: fixed-stride byte
chunks of 3600 ticks and one active tail. They no longer retain an Array entry
and packed allocation for every tick. Loading the existing flat base64 payload
also reconstructs chunks rather than per-tick objects. Sealed chunks are never
modified; snapshots duplicate the mutable tail. Packet reads return slices.

Replay file version remains 5, with the same frame byte layout and metadata.
Existing legacy migrations and strict schema/payload validation remain active.
The internal `ReplayData.frames` container is no longer an Array: current source
uses its append/size/clear methods and `packet_at`; extensions indexing or
iterating that internal field must migrate. `MatchScene.replay_data()` retains
its Array return contract, materialising only when explicitly requested; no
current game-loop caller uses it. The unused result payload now carries the
compact buffer instead of forcing a second full per-tick Array allocation.

## Bounds

- Capture maximum: 108000 ticks (30 minutes at the project's 60 Hz physics).
- Raw input maximum: 8 MiB; no partial packet can cross that budget.
- World-event maximum: 30000 records or 4 MiB of serialized event payload.
- Recorded event data is deep-copied so caller mutation cannot evade accounting.
- Tick duration bounds hash/keyframe container growth; timeline remains bounded.
- Any exhausted channel discards all capture channels and refuses a partial
  replay without stopping the actual match.
- Existing 64 MiB file and total library budgets/atomic storage remain unchanged.

These are explicit software bounds, not measured iOS process-memory guarantees.
Serialization still temporarily builds flat/base64/JSON payloads. This is
in-memory chunking, not an unbounded disk-spooled recorder, and training beyond
the capture budget remains playable without a complete replay.

## Evidence

Runtime source: `a610aa324a6c77fd91788e8a6f927fba99118163`, parent
`f3e682c35311f52a8ad017e00d77119e67c4f673`. Final successful tests used these
runtime files before commit; no runtime files changed during each test.

| Check | Assertions | Log |
| --- | --- | --- |
| Chunks, snapshots, budgets, actual long capture/playback | 89 | `/tmp/kras-replay-chunk-long-audit.log` |
| Existing actual capture/playback and legacy migration | 71 | `/tmp/kras-replay-chunk-integration-final.log` |
| Schema rejection/compatibility | 75 | `/tmp/kras-replay-chunk-schema.log` |
| Binary payload integrity | 29 | `/tmp/kras-replay-chunk-payload.log` |
| Atomic storage/file budgets | 33 | `/tmp/kras-replay-chunk-storage.log` |
| Newer-save downgrade protection | 64 | `/tmp/kras-replay-chunk-future-save.log` |

All above returned exit 0. Total: 361 assertions. Compile check covers 363
scripts. Explicit scans of successful logs found no script/native ERROR, crash
or leak markers. Deliberately invalid replay/budget/storage fixtures emit
expected warnings. `git diff --check` passed.

The long-match fixture runs actual Zone Control for 250 simulated seconds,
saves approximately 925.9 KiB, reloads from disk and replays to its natural end
with identical scores/places, no unrecoverable desync and zero logged errors.
This directly crosses the former four-minute capture limit; it is not just a
synthetic buffer size assertion. Separate 1-4-player buffer fixtures cross every
minute boundary and the old cutoff. They check exact bytes, out-of-range reads,
source mutation, snapshot isolation and incompatible stride rejection.

The first chunk test found eight failed assertions: the snapshot's active tail
was shared, so subsequent append changed its flattened payload. This was fixed
with an explicit duplicate and all checks rerun. That failing log is retained at
`/tmp/kras-replay-chunk-long.log`; it is not counted as passing qualification.

## Remaining gates

Actual 30-minute captures, all 39 games' replay fidelity, seeking/highlight
quality, physical iPhone/iPad peak memory and thermal checks remain unverified.
Replay index/orphan recovery and world-event-specific payload validation remain
separate work. Full CI, source integration, Railway synchronization and
Distribution archive/upload/App Review are not established by this change.
No automatic main merge, production deployment, or Apple submission occurred.
