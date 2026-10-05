# Network preparation cleanup qualification

## Scope and source

Branch: `fix/kras-network-preparation-cleanup`.
Parent: `1e4eb5c751b988ade94f8e482f299b919dd73679` (draft PR 71).

The network smoke peer now retains its outstanding preparation job. Its failure
path still marks failure, logs NETWORK_FAIL, tears down the game and leaves the
room, but drains the preparation node asynchronously before quitting with code
1. No active native request is retrieved synchronously. Game references are
cleared before subsequent frames and late start signals after failure are
ignored. Normal completion is unchanged.

This does not extend any match, loading, reconnect or process deadline. The
outer Node smoke runner retains its original process deadline and terminates an
unresponsive child. A permanently stuck native worker can still reach that
deadline; this change does not claim native cancellation support.

## Focused verification

- Synthetic delayed-worker suite exercises three yielded frames, one retrieval
  after completion, no active retrieval, bank removal and empty/null cleanup.
  7 assertions passed, exit 0.
  Restricted-session log: `/tmp/kras-network-preparation-cleanup.log` (native
  macOS CA retrieval error remains).
- Same suite in local macOS session: 7 assertions passed, exit 0; no native CA
  retrieval error, script error or ObjectDB warning in this log.
  `/tmp/kras-network-preparation-cleanup-local.log`.
- Local compile check: all 359 scripts compiled, exit 0, no native/script error
  or ObjectDB warning found. `/tmp/kras-network-preparation-cleanup-compile.log`.
- Existing log guard passed for the local focused test. This is a delayed-worker
  fixture, not a destructive filesystem or real permanently stuck-worker test.

## Actual seeded network match

Two human input peers plus two bots, seed 716952317, completed successfully
under the original actual-defeat gate. Both natural rounds defeated the boss;
host observations record defeat rounds [0,1], health 0 at the final round, and
elapsed approximately 82.45 / 93.38 seconds. Host and guest results agree:
scores [825,415,275,85]. Both peers exercised reconnect; the guest received
4004 snapshots/world snapshots. The process exited 0.

Evidence:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-ntawKW`.
Both peer logs were searched for SCRIPT ERROR, NETWORK_FAIL, Parse Error and
ObjectDB warnings with no matches. This successful run did not exercise the
failed threaded-preparation exit path. It is not a battery, thermal, mobile FPS,
Internet-multiplayer or physical-device qualification.

## Parent CI evidence and remaining failure

Run 37266377294 for parent 1e4eb5c completed with conclusion FAILURE, not success.
The jobs connector returned only the first 30 jobs (all success, including core)
and cannot prove the complete matrix. The Colossus artifact was inspected
separately:

- Artifact ID 11331192659; retained ZIP `/tmp/kras-colossus-ci-37266377294.zip`.
- SHA256 d7ed41e47f8bd25cf05e188818366fce2c80473940ac892fb70409fb59166cc6,
  equal to the artifact's reported digest.
- Source record: checkout c70d6d0a97a8faddd04df3def83b720e93334ece,
  intended head 1e4eb5c751b988ade94f8e482f299b919dd73679,
  checkout tree befc68660af309c80fc187010a66a6bfcbbb5574, tracked changes empty.
  That tree matches the local parent tree exactly.
- Ordinary two-human/bot and four-human Colossus matches passed, including
  host/guest reconnect and replicated result equality. Four-human scores:
  [635,360,330,275]. These are scripted input peers, not four people on phones.
- The subsequent tournament failed during epoch 2, round 0, seed 1872897823:
  natural 150-second fight ended without actual boss defeat. Last sampled boss
  health was 85, with 4.5167 seconds left. The previous tournament match had
  reached results successfully. Failure remains real and retained; do not
  lower health, extend duration or waive actual defeat to claim qualification.

The complete tournament, all difficulty/balance cases, current full CI and
real-device qualification remain required. No main merge, Railway deployment,
Distribution archive, Apple upload or review submission occurred here.
