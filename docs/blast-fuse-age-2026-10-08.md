# Visible Fuse Age Qualification

Runtime fix: `8884daa08c485ca7ffb383e5e2953d8bcd032976`.
Runtime fingerprint:
`160a0600b0616ed7e26dc2706782afdec832130ea902dd46caf3fb20ab7af1c1`.

## Reproduced Defect

Blast Ball reserved travel and escape time against the delayed displayed
countdown, but did not deduct elapsed time since that display was sampled.
The regression failed on the preceding implementation: 376 assertions passed,
one failed. The fix adds sample age to a copied perception result and deducts
it when planning contact with an armed ball. The original delayed fuse value,
reaction delay, visibility requirements, launch-generation isolation and
retained history remain intact. No private fuse or velocity is read by the
planner. Difficulty profiles, RNG, rules and acceptance thresholds are unchanged.

## Tests

- Blast Ball: 377 assertions passed.
- AI visibility: 4071 assertions passed, including actual sampled age and
  mutation isolation.
- One-shot AI actions: 430 assertions passed.
- Script compilation: all 423 scripts passed.
- Full Godot suite: 391990 assertions passed; exit zero, 347.5 seconds.
- Existing log guards passed for each completed positive run.
- `git diff --check` passed.

The full log retains expected negative fixtures: deliberately failed save
writes and deliberately unavailable router scripts. These originate from
`test_save._failed_write` and `test_router_recovery.FaultRouter`; their
recovery assertions passed. This is not a claim of a log without ERROR lines.

## Matched Natural Sample

Retained evidence: `qa/blast-fuse-age-2026-10-08/`.
Official Godot 4.7.1; fixed simulation FPS 60; isolated save directories.
Both sources used the same 96 baseline seeds, 48 paired seed/character/seat
configurations, seed offset 1800000, and authored 90-second round window.
Both completed all attempts plus mutator and chaos smoke checks.

| Source fingerprint | Expert placement share | Slot wins | Flags |
| --- | --- | --- | --- |
| 523906225b6ea660b7726e763b468fe4528b4d604e18bf9d28abe10926e338e3 | 0.5104166667 | See parent report | expert bots no better than easy |
| 160a0600b0616ed7e26dc2706782afdec832130ea902dd46caf3fb20ab7af1c1 | 0.5583333333 | 24, 21, 26, 25 | none |

Candidate source fingerprints match at simulation start and end. Mean natural
duration was 21.39375 seconds. Matching configurations were independently
compared with Node before retaining the reports. This controlled sample
supports the correction, not a population-level balance guarantee or device
performance claim. Independent held-out seeds remain required.

## Current Acceptance Limits

Content audit: zero structural errors, READY 0, NEEDS_POLISH 1,
NEEDS_BALANCE 38, REWORK 0, BROKEN 0. Blast Ball is NEEDS_POLISH, not READY.
The other 38 games still require accepted evidence for the changed global
runtime fingerprint. The previous campaign cannot qualify this new source.
The supplied audit `--out` argument is not supported; the actual default
`build/party/content-audit.json` was retained, not an assumed output file.

The sample-history index retains the preceding warning as stale-source
evidence and explicitly reports releaseReady=false and
campaignAttestationVerified=false. It does not silently replace a warning
with release approval. All-game qualification, device gameplay/performance,
production rollout and positive client connectivity, final version/build,
local Xcode 27 Distribution archive, upload, processing and App Review
submission remain outstanding. No Apple or production mutation occurred.
