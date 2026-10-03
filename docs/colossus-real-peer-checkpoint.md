# Colossus Real Peer Qualification Checkpoint

## Driver

The peer fixture now drives Colossus using ordinary movement and attack input.
It reads the presented exposed-fist plan and visible warnings. Candidate movement
segments are checked against the same carved-ground query available to the guest.
It never changes boss health or awards damage directly.

Each ordinary round must show actual damage, a strike, a crater and boss defeat.
Guest verification also requires world snapshots, presentation-only authority,
no simulated crater ownership and no carved-floor physics body.
Ordinary duration remains authored; no timeout was increased to obtain a pass.

## First Actual Run: Failed

Command: `node network-smoke.js --game=boss_colossus --humans=2 --seed=9614`

Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-YRv6GN`

The real WebSocket host and guest loaded `vortex_ring`, disconnected/resumed,
and exchanged thousands of snapshots. The fixture ultimately failed with
`2-players-0 timeout`; this is not a passing network match or boss qualification.

Observed preparation frame gaps were approximately 24952/25014 ms. Server loop
maximum was 4962 ms. Guest snapshot progress slowed sharply later in the run.
The old diagnostic lacked round elapsed time and boss-health summaries, so the
evidence does not isolate driving, geometry rebuild cost or slowed simulation.

## Next Diagnosis

- The fixture now logs round, elapsed/remaining simulation time, boss health,
  crater count, exposure, fighter states and observed damage/defeat rounds.
- Repeat the same seed and inspect those measurements before changing gameplay
  or deadlines. Keep unrelated heavy workloads out of the timed run.
- Profile geometry rebuilding if crater growth correlates with slowed simulation.
- Do not treat room-contract success as actual match or performance qualification.

No Railway deployment, production activation or App Store submission occurred.
