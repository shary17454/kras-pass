# Prepared Impact Bursts

Runtime: `4802ba0ded1e2c0dbb12f9c9340a258fbd56024c`.
Branch: `perf/kras-prepared-impact-bursts`, based on PR 110.

## Changes

Rendered match preparation now retains eight idle burst roots with 32 shard
nodes each, matching the existing eight-root idle budget and pooled count
ceiling. Materials for selected character accents are prepared before play.
Burst shards share a single immutable rounded-box mesh through MeshFactory's
existing cache. Color, active count, motion and large authored effects remain
unchanged; no visual count reduction is used. Headless match setup skips the
visual preparation, while focused tests exercise it directly.

The final factory still allocates overflow on demand. An intermediate factory
would have allocated 32 shards for a ninth burst requesting two. A regression
reproduced this: 321 passed, one failed (got 32, expected two). Preparation now
configures only its retained eight roots; ordinary overflow retains its actual
requested count. `fighter.impacts` separates the previously unmeasured impact
resolution interval within `match.fighters`; traces remain debug opt-in.

## Tests

- Burst suite: 322 assertions passed, including eight distinct prepared roots,
  shared geometry, unchanged vertices/normals/bounds/colors/count, repeated
  preparation and demand-sized overflow. `/tmp/kras-burst-overflow-green.stdout`.
- Red overflow reproduction: `/tmp/kras-burst-overflow-red.stdout`.
- Local party: 4171 passed on final runtime;
  `/tmp/kras-prepared-burst-final-party.stdout`.
- Final compilation: 389 scripts; `/tmp/kras-prepared-burst-final-compile.stdout`.
- Contact lifetime: five passed on intermediate `956cd76`, not a new full
  final-runtime run; `/tmp/kras-prepared-burst-contact.stdout`.
- Console guards and `git diff --check` passed.

## Rendered Evidence

Both completed observations used local macOS Metal/Mobile, portrait 720x1280,
quality 2, cap 60, four Expert Bots plus synthetic touch HUD, seed 72,
`tag_hunt` / `star_meadow`. Each completed 28 live seconds and 25 steady seconds,
with normal cleanup and a passing console gate. Final screenshot was inspected:
Arabic, symbols, touch controls and the arena rim are visible.

| Source | Steady FPS | Worst Frame | Frames >100 ms | Setup | Nodes Before/After |
| --- | ---: | ---: | ---: | ---: | --- |
| Intermediate `956cd76` | 59.52 | 90.587 ms | 0 | 3259.645 ms | 51 / 51 |
| Final `4802ba0` | 59.88 | 65.002 ms | 0 | 2359.441 ms | 51 / 51 |

Intermediate files: `/tmp/kras-prepared-burst-render-resumed.{json,png,stdout,log}`.
Final files: `/tmp/kras-prepared-burst-final-render.{json,png,stdout,log}`.
Final p95 17.539 ms, p99 19.03 ms, three frames >50 ms; impact interval maximum
0.880 ms and whole fighter interval maximum 1.537 ms. Static RAM peak 133.30 MiB,
after cleanup 129.36 MiB. This includes bounded idle geometry during play.

The first intermediate attempt was interrupted before a completed report.
Its handles were missing on resume; process inspection confirmed it was no
longer running before the new attempt. `/tmp/kras-prepared-burst-render.stdout`
is retained as incomplete, not counted as a passing observation.

The preceding font-change observation had worst frame 145.805 ms and 59.01 FPS,
but these short desktop runs are not controlled statistical comparisons.
Do not claim all hitches are fixed: frames above 50 ms and startup latency
remain. Node cleanup is not proof of no memory leaks. These results do not
qualify physical iPhone/iPad FPS, heat, battery or every minigame/world.

## External Gates

At the live check, PR 110 run `37411885788` had completed SUCCESS for
`network-ring_rumble` and `network-goal_guard`; balance was SKIPPED and the
remaining matrix was unfinished. This is evidence for those jobs only, not
qualification of PR 111, all 39 games or four humans over Internet.
No main integration, Railway deployment, new signed Archive, upload or Apple
review submission occurred. Release remains local Xcode 27, not Xcode Cloud.
Full post-change regression, balance/polish, remaining CI/network scenarios,
production acceptance and physical-device checks remain required.
