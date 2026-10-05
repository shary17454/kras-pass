# Bounded Burst Node Reuse

## Source and Scope

Exact runtime source: `bef534f7d92d7054bb3288dc4202b31672caa904`.
Base: the frame-attribution branch, including the compound-actor perception
fix. This branch is not production main or an App Store archive.

`MeshFactory.burst` now checks out visual-only roots from the existing Pool
autoload. Repeated effects reuse their shard nodes rather than rebuilding
every shard. Configuration resets age, root and shard transforms, velocity,
active count, visibility, lifetime and material colour. Unused spare shards
are hidden. All active shards retain their original motion and visual style.

Idle retention is limited to eight roots, each with at most 32 shards.
Concurrent peaks can still allocate. Authored counts above 32 keep their full
count through the unpooled path, then expire normally; no visual-quality
reduction or silent count clamp is introduced. The current authored effect
calls fit the pooled size range.

Pool gains `has_pool` and an optional `max_idle` argument on `release`.
Existing release calls keep their previous behavior. Overflow retirement still
decrements checked-out bookkeeping. Visual-only roots are detached when
acquired so callers can attach them to their required parent; collision-object
pools retain the existing no-reparent release policy.

An idle guard prevents duplicate retirement. Expiry after a torn-down factory
does not recreate the pool. Existing per-match drain and memory-pressure trim
remain in use; factories/live effects survive trim while idle roots are freed.

## Reproduction and Lifecycle Tests

- `/tmp/kras-burst-reuse-before.log`: one passed, four failed. Before the fix,
  expired roots were queued for deletion, stayed visible until deletion, and
  subsequent effects used different root and shard instance IDs.
- `/tmp/kras-burst-reuse-lifecycle.log`: 36 assertions passed. Tests actual
  instance identity reuse, smaller/larger effects, colour and transform reset,
  motion, repeated retirement, another parent, twelve simultaneous effects,
  the eight-root cap, overflow bookkeeping, pressure trimming with a live
  effect, unpooled forty-shard visuals and teardown/late expiry.

## Full Integrated Qualification

Godot 4.7.1 official `a13da4feb`, exact source `bef534f`.
`tools/check_party.sh` exited zero.
Log: `/tmp/kras-burst-full-check.log`.
Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-party-check.GyX2nK`.

- 373 scripts compile.
- 413 resources, 21 autoloads, 27 routes, eight characters: zero inventory
  issues.
- 360177 assertions pass in 156.6 seconds.
- Three-lap race and six authored boss probes pass.
- One stability cycle completes all 39 matches with zero failures.
- Server tests using all six fresh Godot world captures: 192 pass, zero fail,
  zero skip (`/tmp/kras-burst-server-captures.log`).

Headless completion and this small stability run do not certify all content,
physics variants, internet peers or long-session leak freedom.

## Rendered Sample

Same Forge seed/configuration, Mac Apple M5, Metal Mobile, 1280x720,
four moving Bots and at least ten live seconds / 400 samples per repeat.
No full-suite CPU load was running during the rendered probe.
Log: `/tmp/kras-burst-forge-pipeline-trace.log`; Godot error-log guard passes.

| Repeat | Mean ms | P95 ms | Worst ms | Slow intervals >=25 ms | Setup ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| First | 17.37 | 17.25 | 137.15 | 7 | 2318 |
| Second | 16.67 | 17.07 | 21.69 | 0 | 45 |

First repeat still reports 11 draw and 14 surface pipeline compilations;
the second reports zero. The frame-attribution baseline had worst intervals
138.91 ms / 50.14 ms and seven / five slow intervals respectively. Those
short samples are variable, share warmed driver caches and are not repeated
statistical performance certification. Reuse is established by node identity
and lifecycle tests, not by claiming every hitch was caused by allocations.

Active-round node count is 455 versus the earlier 438: seventeen additional
nodes match one retained sixteen-shard idle effect. Both repeats return to
50 nodes after teardown, matching the start count. The bounded idle bank is
an intentional memory-for-reuse tradeoff, not evidence of globally constant
allocation or zero leaks. Engine static-memory numbers are not iPhone RSS.

## Remaining Product and Release Work

First-use rendering spikes are unresolved. Sustained iPhone/iPad frame pacing,
GPU/RSS, battery and thermal measurements remain required, as do outstanding
balance/content readiness, online real-peer/reconnect qualification, replay
fidelity and signed exact-source release gates.

No main merge, Railway flag/configuration change, archive, Apple upload,
processing or App Review submission was performed for this source. Keep the
full product goal active; this change is not completion of all requirements.
