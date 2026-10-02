# Online beta: protocol 1

## Implemented boundary

### Finished racers cannot absorb road weapons

After `fe136deaac251a6a73e26327f0fcc582fc0bc55c`, the inherited Sabaq
weapon controller was checked before network migration. Completed racers
remained logically alive, so missile target selection could choose them and
their parked bodies could trigger an armed road bomb. They could also consume
a shield after a late weapon contact. Finished racers now neither attract new
missile targets nor trigger bombs, receive blast/spin punishment or grant hit
credit. Unfinished racers still use the original weapon rules and penalties.

The initial regression in `/tmp/kras-race-weapons-before.log` reported 31
passes and three failures. `/tmp/kras-race-weapons-after.log` passed 35
assertions, including unshielded finished-racer immunity and a real bomb
trigger against an unfinished racer. These are controller fixtures using
ordered checkpoints, not Internet or physical-device qualification.
`/tmp/kras-race-weapons-compile.log` compiled all 293 scripts.
The separate real four-bot driving test in
`/tmp/kras-race-weapons-driving.log` passed the unchanged three-lap race in
145.43 simulated seconds, with crates, hits and off-track recovery active.
The native macOS certificate-store lookup emitted an error during headless
startup; the above processes nevertheless exited zero. This does not verify
TLS access, Apple signing, or online Sabaq support, which remains excluded.
The complete Godot test runner subsequently passed all 19,481 assertions in
462.0 wall-clock seconds (`/tmp/kras-race-weapons-all-tests.log`), including
the existing real three-lap tests on every configured race course. This run
is not a new repeated stability, physical-device or Internet qualification.

### Seeded Kart tournament and finished-racer collision

Source `3c26b94bf4a4f2da4685f53cddc6676f68943e33` introduced an internal
Rooms seed provider for diagnostic runs. Production defaults still use
`crypto.randomInt`; the public protocol cannot choose the seed. The provider
rejects invalid bounds/types. `/tmp/kras-kart-seed-contract.log` passed all
91 Node tests. The smoke runner accepts `--seed` and reports the actual seed
on every peer. This fixes simulation randomness, not network scheduling or
cross-platform physics determinism.

`kras-network-smoke-ojyNKb` reran the original timeout's seed `443020368`
with four humans and passed two three-lap rounds: scores
`[5673,4477,4062,4522]`, 1,622-to-1,642 guest snapshots, matching results,
guest resume and host-result transport recovery. The earlier timeout is not
erased by this success and its root cause remains unconfirmed.

`kras-network-smoke-O9gxUo` then passed an actual four-human tournament on
that same source/seed: three ordinary three-lap matches followed by one actual
one-lap tiebreak. The permitted uniform table `[1,1,1,1]` intentionally makes
the ordinary total points tie; the real controller still drives and scores
every race, without fabricated positions or results. All peers reported four
matches, points `[3,3,3,3]`, unchanged cups `[0,3,0,0]`, no extra final awards,
one tie attempt and champion slot 1. Final race times were
`[1137,675,698,713]`, with 3,037-to-3,056 guest snapshots and sampled maximum
server loop delay 49 ms. This run is independent-process tournament evidence,
but not Internet, mobile performance or general stability qualification.

A subsequent real PhysicsServer motion probe proved a separate concrete
problem: a completed kart remained an obstacle to an unfinished racer.
`/tmp/kras-finished-collision-before.log` retained the failing regression
(26 passes, one failure). Kart now removes only the player layer/mask bits
when recording a finish. World collision remains, so floor support is
preserved; new-round and cleanup paths restore the exact saved layer/mask.
The shared race controller applies the fix to Sabaq as well. The visible
kart is retained, and no race time, checkpoint, score, boost or rescue penalty
is changed. `/tmp/kras-finished-collision-after.log` passed all 27 assertions,
including actual blocked motion before finish, clear passage afterward and
restored contact in the next round. This narrow collider fixture does not
prove the original network timeout had that same cause.

After the collision fix, `kras-network-smoke-aTfZmy` passed the seeded
four-human ordinary race with scores `[6034,4460,5710,4510]` and
1,787-to-1,806 guest snapshots, all required laps, real boost/rescue and both
reconnect paths. Sampled server loop delay reached 302 ms on this run; this
is functional acceptance, not a performance pass. The tournament evidence
above predates the collider fix and is not claimed as a post-fix tournament
run. `/tmp/kras-finished-collision-compile.log` compiled all 293 scripts.

### Kart development-room integration (experimental)

The development allowlists now accept Kart Sprint on `circuit_loop` only.
Node snapshot dispatch binds its eight authored checkpoints and effective lap
limit to the current room rules. The host can select 3-to-10 laps independently
of match rounds; the server rejects fractional, boolean, string, null and
out-of-range selections. Older configurations default to three laps. Ready
invalidation, host-only configuration/results and reconnect identity/state
remain governed by Rooms. Guests restore the selected lap count through the
shared MatchConfig and existing HUD.

Tournament race finals use one lap and a 120-second maximum-duration safety
deadline, rather than the arena final's 25-second deadline. Kart completion
checks authoritative contenders, including bot finalists, without waiting for
spectators or letting a spectator's finish settle the final. The focused
`/tmp/kras-kart-final-rules.log` passed 20 assertions and
`/tmp/kras-kart-room-routing.log` passed 58. All 90 Node tests passed in
`/tmp/kras-kart-room-contract.log`, including a complete Rooms-model sequence
into a tied race final, rejection of lobby-length final snapshots, and
reconnection with 3-, 7- and 10-lap configuration/state. That Rooms-model
sequence is not independent physical tournament evidence.

The real smoke fixture drives each human through virtual input, aiming at
the host's next checkpoint. Slot zero deliberately steers off the road during
normal driving so the original controller performs rescue; no position,
checkpoint, score or result is fabricated. The ordinary match runs two rounds
of three laps each, requires all humans to finish, observes real pad/rescue
state and verifies guest lap/time presentation without guest rescue rules.

`kras-network-smoke-Tm8Bb4` passed the two-human/two-bot case with scores
`[6075,3996,1999998324,1999998326]` and 1,703 guest snapshots, including guest
resume and host-result transport recovery. Its four-human case timed out in
the second round; that failed evidence is retained. Detailed periodic Kart
diagnostics were then added. `kras-network-smoke-EMNRYG`, an explicit four-human
rerun, passed with scores `[5265,4472,4040,4072]`, 1,541-to-1,560 guest snapshots,
identity-preserving reconnects and maximum sampled server loop delay 55 ms.
Every process agreed on results and completed the required human laps.

The failed run's root cause is not established: the diagnostic rerun's success
does not prove the earlier timeout was fixed. Consequently this is an
experimental development-room integration, not a stable online release.
Repeated seeded four-human races, actual tournaments/finals, Internet/mobile
transport, controller/device QA and performance qualification remain required.
The runner's optional `--humans=2|4` selects a diagnostic roster; its default
still tests both. Production online remains disabled, and no Railway or App
Store deployment/submission occurred here.

Full gate `kras-party-check.NGqCjS` on this integration compiled 293 scripts,
audited 330 resources with zero issues, passed 19,466 assertions, passed the
existing real three-lap offline race and completed all 39 stability matches
with zero failures. It does not negate the independent four-human timeout
above or establish Internet/device stability.

### Kart world presentation and source verification

Commit `ba6d5dd80cf173d25f760580f9b3da9e506addd9` was verified on
`origin/main`. It includes the Kart world adapter, not Kart room enablement.
The exact nine-field world schema carries elapsed time, finish times, laps,
next checkpoint indices, started flags, effective lap limit, checkpoint count,
rescue progress and boost counters/recharge. Both Godot and Node enforce
finite bounds, roster sizes, finish/lap consistency and a four-pad layout.
MatchScene binds the checkpoint count to its actual course before accepting a
packet. Standalone rendering also checks course geometry before mutating any
fighter, so a schema-valid but mismatched course cannot move guest players.

Guest racers only render host state. Their original rescue halo follows the
replicated rider and host rescue progress; it has no collision body, local
respawn callback, boost impulse, lap advancement or clock ticking. Fresh
sampled lap/boost cues play once, including finish cues first observed during
ENDING. Baseline, duplicate and round-reset snapshots do not replay old cues.
This sampled counter path is not a lossless audio/event replay stream.
Host short-race lap limits are restored for the existing HUD rather than
silently reverting to the guest's three-lap default.

`/tmp/kras-kart-network.log` passed 110 focused assertions on the pushed source;
`/tmp/kras-kart-world-server.log` passed all 88 Node tests. The subsequent
`/tmp/kras-kart-network-edges.log` passed 121 assertions, adding mismatched
course/no-mutation checks, invalid pad roster and boolean checks, and a real
one-lap controller result restored into a separate guest scene. These fixtures
position source riders at checkpoints to exercise rule transitions; they are
not independent-process driving, Internet or device performance evidence.

Full gate `kras-party-check.iMnBfE` on `ba6d5dd` compiled 293 scripts, audited
330 resources with zero issues, passed 19,445 assertions, finished the existing
physical three-lap offline race and completed all 39 stability matches with
zero failures. The eleven additional edge assertions above ran afterward as a
focused suite, not as part of that full-gate count. Godot emitted a macOS
`get_system_ca_certificates` warning; the commands exited successfully, but
this gate does not qualify production TLS or Keychain access.

At this adapter-preparation commit Kart remained excluded from development room allowlists. Its server geometry
dispatch, selectable 3-to-10 network laps, real driving across independent
peers, recovery/reconnect and tournament results must be qualified next.
Production online is still disabled. No Railway deployment, signed iOS archive,
upload or App Review submission is established by these tests or the Git push.

### Kart integration prerequisites

Before adding Kart Sprint to rooms, source inspection found three actual
integration blockers. Kart/Sabaq encode unfinished progress beneath a
one-billion sentinel, whereas the room/tournament result checks previously
rejected anything above one million. `validResultScore` now uses the checked-in
game catalogue and allows that sentinel only for those two kart games, scaled
by the configured 1-to-10 ordinary-match rounds. Tournament records remain
single-round bounded. Race results must be nonnegative integers; ordinary
arena games retain their existing signed one-million limit. No ranking flag or
range can be supplied by the client. Snapshot score checks remain unchanged,
because those represent context counters rather than aggregated final results.

Kart round start now clears every pad's per-player cooldown, so a preceding
round cannot suppress the first boost of the next. Kart completion now uses
`MatchConfig.human_competitor_slots()`: remote peers are human competitors in
online matches even though they are not local device owners. `human_slots()`
and input-device routing are unchanged. This prevents the host's finish alone
ending a race while a remote human is still driving, while preserving offline
rules and the existing policy that unfinished bots do not block all humans.
Sabaq inherits the same race controller fixes.

`/tmp/kras-race-score-contract.log` passed all 87 Node tests. New cases verify
unfinished-progress ranking behind finishers, up to ten summed race rounds,
duplicate result rejection, integer/type/range bounds, unchanged arena limits
and a complete pure Tournament-model sequence. This is not room or network
race qualification. `/tmp/kras-race-round-reset-final.log` passed 16 focused
assertions. Real pad contact starts recharge, round start restores availability,
and the next contact is accepted. Ordered checkpoint ticks finish the host's
three laps without ending the race until the remote human also finishes.
That rule-level fixture positions riders at checkpoints; it is not physical
driving, performance or independent-process evidence. At this prerequisite
commit Kart remained excluded from room allowlists, before the world adapter
and recovery presentation described above were implemented. Actual online
racing and final tournament qualification remain outstanding.
Full gate `kras-party-check.bkVDQo` compiled 291 scripts, audited 328 resources
with zero issues, passed 19,336 assertions, passed the real three-lap race and
completed 39 stability matches with zero failures. That physical race regression
is offline; it does not establish a race across independent online peers or
complete release readiness.

### Fawda bomb adapter preparation

Fawda now assigns round-local monotonic bomb identities and records sampled
drop, pickup, throw and explosion counters with their most recent positions.
The host's visible bomb rows include identity, position, velocity, remaining
fuse, holder and last thrower. Both Godot and Node validate an exact bounded
schema: at most four live bombs, unique positive identities, valid roster
indices, no two bombs bound to one holder, five-second fuse bounds, carrying
flags and all four event types. Carrying and holder fields are individually
bounded rather than enforcing an invariant that could reject a legitimate
one-tick dropped-by-hit transition before the host releases its holder.

Bomb mesh/wick construction and fuse visual updates are shared with the
existing offline game. Explosion presentation is separated from blast damage.
Guest views have no collision bodies and never tick a fuse, drop a bomb, handle
pickup/throw input or award eliminations. Fresh events play their matching
sounds once; baseline/duplicate/stale bomb events do not replay. Snapshot
sampling can merge multiple same-kind events and does not claim a lossless
impact-audio stream. New rounds discard previous bomb views before reusing IDs.

`/tmp/kras-fawda-network-final.log` passed 130 focused assertions, including an
actual drop, pickup, attack-input throw, in-flight update and detonation from
the real controller, rendered into a separate scene after JSON serialization.
The fixture checks carrying/HUD state, wick scaling, host trajectory, removal,
no guest damage or score changes, duplicate/stale sound suppression and round
identity reuse. `/tmp/kras-fawda-network.log` retained one failed fixture
assertion that counted the round's separate UI go cue as bomb feedback. The
test now explicitly requires that go cue, without muting it in product code.
`/tmp/kras-fawda-network-fixed.log` passed the earlier 114-assertion fixture;
the final expanded fixture passed 130. All 84 Node tests passed, recorded in
`/tmp/kras-fawda-server-tests.log`.

At the adapter-preparation commit, Fawda was not in client/server room allowlists. Independent-process matches,
tournaments, authored-map acceptance, Internet and physical-device behavior
remain unqualified. Production online remains disabled. Full gate
`kras-party-check.nIHgkC` compiled 290 scripts, audited 327 resources with zero
issues, passed 19,321 assertions, passed the real three-lap race and completed
39 stability matches with zero failures. Its headless results do not establish
device audio/rendering quality or the complete product's release readiness.

### Fawda room integration

Development client/server allowlists now include Fawda only on its two authored
arenas, `vortex_ring` and `storm_ring`. Snapshot dispatch applies the exact
Fawda validator rather than accepting fighter-only frames. Room-contract tests
exercise both arenas, reject an unrelated map, missing world data, invalid
carrying/fuse values, absent event types and duplicate bomb identities. Guests
cannot publish snapshots or final results. A real Rooms disconnect/resume
preserves the same identity, selected map and bomb/carry/event baseline.
All 85 Node tests passed in `/tmp/kras-fawda-room-contract.log`, and
`/tmp/kras-fawda-room-compile.log` compiled all 290 scripts.

The independent-process fixture uses only real movement and attack inputs.
Players seek visible loose bombs, then aim at a visible opponent and release
the carried bomb. Every match resets its drop/pickup/throw/explosion evidence.
Guests must match bomb count, position, wick scale and carrying state without
creating local rule bombs. Ordinary fixture `kras-network-smoke-JMiF5g` passed
two humans plus bots with scores `[8,5,16,17]`, and four humans with scores
`[14,18,8,10]`. All peers observed actual drop, pickup, throw and explosion
events. Guests received 1,315 to 1,454 world snapshots; guest identity resume
and the intentionally dropped host-result connection both recovered. Guest
final bomb counts/positions/wicks and carrying state matched the host baseline,
and guests never created live rule bombs. No script/parse failures or object
leak warnings were found in these peer logs. Maximum local server-loop delay
was 121 ms; this is not Internet latency or device FPS.

Tournament fixture `kras-network-smoke-yJW5yb` passed both rosters, each
completing three matches and visiting both authored arenas. Two humans plus
bots finished with points `[6,5,9,13]`, cups `[0,0,1,2]` and champion 3; four
humans finished with points `[4,10,6,13]`, cups `[0,1,0,2]` and champion 3.
All peers matched tournament results and final bomb/carry presentation, with
1,810 to 1,949 guest snapshots. Each match independently observed real drop,
pickup, throw and explosion; no local rule bombs ran on guests. Reconnect and
dropped-host-result recovery passed. Maximum local server-loop delay was
115 ms. Neither roster required a final tiebreak, so this is not actual Fawda
tiebreak qualification. No script/parse failures or object-leak warnings were
found in these logs. CI now includes Fawda ordinary/tournament acceptance, but
no new Linux result is claimed. Post-integration gate `kras-party-check.LU01ob`
compiled 290 scripts, audited 327 resources with zero issues, passed 19,321
assertions, passed the real three-lap race and completed 39 stability matches
with zero failures. There are now 32 development-room games; Kart Sprint,
the four bosses, Sabaq Sawarikh and Base Siege remain excluded.
Production online remains disabled. Device graphics/audio, Internet behavior,
complete event-stream parity and the rest of the product's release gates remain
unqualified.

### Scrap collision adapter and room preparation

`scrap_karts` now replicates the host's health, maximum health, collision serial,
last collision position and per-player wreck count. Godot and Node validate an
exact five-field schema. A wreck is limited to one per player per round and
requires zero health. Guests update the existing health bars without resolving
contacts, assigning damage or awarding eliminations. Fresh collision/wreck
feedback plays once; duplicate, baseline and stale/reconnect frames remain
quiet. Collision feedback is sampled at snapshot frequency, not a lossless
stream of every impact.

Round start now clears `_hit_cooldown`, preventing a contact from the previous
round suppressing the same pair's first contact in the next round. The focused
test uses actual controller contacts and destruction before rendering their
JSON-round-tripped state. `/tmp/kras-scrap-network-final.log` passed 75 assertions.
The earlier `/tmp/kras-scrap-network.log` failed on inferred baseline typing and
aborted before fixture cleanup; its leak warnings are retained as failed-run
evidence, not successful qualification. Explicit boolean typing fixed the parse
failure, and the final focused run completed without those leak warnings.

Before room integration, `kras-party-check.vAhrTU` compiled 288 scripts, audited
325 resources with zero issues, passed 19,192 assertions, passed the real
three-lap regression and completed 39 stability matches without failure.
This headless gate does not prove mobile graphics performance.

Development rooms accept only the authored `scrap_yard` arena. The room contract
rejects an unrelated arena, missing/extra world fields, excessive health,
contradictory wreck health, negative serials and non-finite positions. Guests
cannot send snapshots/results. Real Rooms disconnect/resume preserves the same
identity, arena and health/impact baseline. All 83 Node tests passed, recorded in
`/tmp/kras-scrap-room-contract.log`. Client development-room allowlists now also
include Scrap; production online remains disabled.

CI run `37009902360` on `10911cff4773e437ed5d1a584d33a75770880719` is terminal
cancelled: 19 jobs succeeded and 11 were cancelled, including crate relay.
The workflow has `cancel-in-progress: true`. The newer main-source run
`37016043902` on `6b226ca7c513903aeb3cbb6335df3374382805e0` was queued when
checked. Neither run proves the earlier Linux crate-relay failure resolved.

The first independent-process Scrap attempt, `kras-network-smoke-KJmISj`,
failed its final fixture array comparison after reaching results and reconnect.
`/tmp/kras-json-array-probe.log` reproduces Godot's unequal comparison between
`Array[int]` and a JSON-deserialized array of floating-point numbers despite
equal numeric values. The fixture now compares each wreck counter explicitly
as an integer, as it already does for tank inventory. No product state, damage,
scores or acceptance requirements were altered to bypass the failure.

The corrected ordinary fixture, `kras-network-smoke-3R4AXr`, passed both
two-human-plus-bots and four-human rosters. Real drive/boost inputs caused
accepted rams and reduced health. Every guest's final health, wreck counters
and impact serial matched its authoritative baseline, with no guest contact
cooldowns. The two-human scores were `[12,36,6,10]`, and four-human scores were
`[14,20,18,12]`. Guests received 754 to 816 world snapshots. Guest identity
resume and the deliberately dropped host result both recovered. The local
server's maximum observed loop delay was 70 ms; this is not Internet latency
or device FPS.

Tournament fixture `kras-network-smoke-ZBOJLE` passed both rosters. The two-human
roster completed three matches with points `[10,13,6,4]`, cups `[1,2,0,0]` and
champion 1. Four humans tied at points `[12,6,12,3]` after three matches, then
completed one actual contender-only tiebreak with champion 0. The tiebreak
awarded no extra tournament points; final cups were `[2,0,2,0]`. Each match
resets the fixture's collision/damage observation flags, so a previous game's
contact cannot satisfy the next game's requirement. Guests received 1,310 to
2,218 snapshots, retained their identity on resume, and never populated local
contact cooldowns. The maximum local server-loop delay was 100 ms. This does
not qualify physical-device performance, Internet behavior, ranked anti-cheat,
complete impact audio or all other mini games.

Post-integration gate `kras-party-check.wJeVdE` passed: 288 scripts compiled,
325 resources audited with zero issues, 19,192 assertions, the real three-lap
race and 39 stability matches with zero failures. CI now includes the Scrap
ordinary/tournament scenario, but no Linux CI result for this new integration
has been claimed. There are 31 development-room games; the remaining eight
are Fawda, Kart Sprint, the four bosses, Sabaq Sawarikh and Base Siege.

### Armed ATV snapshot adapter

The `tank_arena` adapter reuses Turret Duel's pooled-launch presentation and
adds all seven shell kinds, sticky fuse state, armor, ammunition, held weapon
type and the five authored refill crates. A pooled projectile now carries a
presentation kind that resets on release and standard firing. Each real tank
launch assigns its own kind after firing; damage and weapon rules are unchanged.

Both Godot and Node require an exact bounded world schema, consistent ammo/type
pairs and valid per-roster armor. Guided shells may follow terrain in three
dimensions; Turret Duel still requires horizontal directions. Vertical guest
trajectories use a non-collinear up vector. Guests render the actual shell colors,
sticky pulse, crate availability/rotation, cooldown and HUD weapon state, without
spending ammunition, advancing fuses, collecting crates or awarding eliminations.
The engine follows replicated local-player speed only during active play and
stops in results. Fresh launches play cannon audio once; baselines, duplicates
and stale/reconnect launches do not replay prior shots.

`/tmp/kras-tank-network.log` passed 139 focused assertions, using real launches
of every shell type and real projectile-pool reuse. All 80 Node tests passed.
An initial parse check caught and resolved the inherited validator signature.
Explicit audio-enabled tests initially failed because their roster had no human
and counted the HUD's separate go cue as cannon audio; the fixture now uses one
human and isolates that cue without suppressing product sounds. Earlier
headless audio-enabled exits retained one WAV stream/playback pair. Verbose
`/tmp/kras-tank-network-verbose.log` identified them; after shutdown the test
runner now gives the mixer 100 ms of real wall time rather than only two fast
fixed-FPS frames. `/tmp/kras-tank-audio-drain.log` and the final focused run
completed without object-leak warnings. This delay is confined to the test
runner; it is not a gameplay pause or proof of device audio quality.

Final integration gate `kras-party-check.xfeLyI` compiled 286 scripts, audited
323 resources with zero issues, passed 19,114 assertions, passed the real
three-lap race regression and completed 39 stability matches without failure.
The earlier `kras-party-check.f7j1dk` gate failed the two audio-fixture
assertions described above and was not accepted as passing evidence.

Development rooms now accept `tank_arena` on its three authored maps in both
the server and Godot client. Independent-process acceptance is recorded below.
Physical-device and Internet qualification, sampled-event limitations and
impact/collection sound parity remain unresolved. Production online remains
disabled.

The development server now recognizes only the three authored ATV arenas:
`tank_foundry`, `tank_oasis` and `tank_frost`. Its snapshot dispatch uses the
existing exact `validTankWorld` validator rather than accepting fighter-only
frames. The room-contract regression exercises each arena, rejects an unrelated
arena, missing world state, invalid armor, inconsistent ammunition, missing
crates, zero launch generations and a non-sticky shell with a sticky fuse.
Guests cannot publish snapshots or results. A real Rooms disconnect/resume
restores the same identity, arena and authoritative inventory baseline without
directly modifying room internals. All 81 Node tests passed; their full output
is preserved in `/tmp/kras-tank-room-contract.log`. This initial server-side
preparation alone was not treated as client or production qualification.

### Armed ATV independent-process acceptance

The client now uses the same three-map allowlist as the server. The real-input
fixture drives, steers, fires and pursues available refill crates through the
authored road graph, without injecting contacts, inventory or scores. Each
match must observe actual launches, armor damage and nonzero ammunition.
Guests require converged launch generations/positions, shell kinds/fuses,
cooldowns, damage, armor, ammo and held types, plus all five crates' cooldowns,
rotation and availability. Their controller must not simulate local shots.
Tournament checks reset those observations for every match and require visits
to all three maps; one successful map cannot mask an untested later map.

Initial run `kras-network-smoke-EqZmO7` passed two humans plus two bots but
failed four humans because no ammunition was observed (shots and armor damage
were observed). That failed run is retained. The driver's per-frame AStar
nearest-node recalculation could direct it back toward the starting node before
crossing a road segment's midpoint. The fixture now retains and consumes its
waypoints, replanning only when its destination moves significantly or its
path is exhausted. It selects available crates explicitly rather than treating
a proximity-limited "no crate" return as a destination. This is a fixture change,
not a modification of product AI, vehicle speed, map collision or loot rules.
The focused regression reproduces the old backward waypoint and verifies forward
progress before/after each node. An initial test parse error from untyped dynamic
node creation was corrected with `Node` typing. The final focused run passed
143 assertions (`/tmp/kras-tank-routing-regression.log`).

Ordinary run `kras-network-smoke-CUsOJK` passed both rosters on `tank_foundry`:
scores `[600,972,935,918]` / `[950,897,960,600]`, with 1,689-1,708 guest
snapshots. These runs observed real elimination, weapon pickups and armor damage.
Host interrupted-result recovery and guest identity recovery passed. Maximum
local server event-loop delay was 47 ms.

Tournament run `kras-network-smoke-Skds8n` passed both rosters and all three
maps. Two humans plus bots completed three matches: points `[7,12,8,9]`, cups
`[1,2,1,1]`, champion slot 1. Four humans completed three matches: points
`[9,7,13,5]`, cups `[1,0,2,0]`, champion slot 2. Final standings agreed across
all peers. Guests received 2,568-2,587 snapshots; identity and interrupted-result
recovery passed. Each map independently satisfied shot/armor/inventory checks.
No final tiebreak was needed, so this is not ATV sudden-death acceptance.
Maximum local server event-loop delay was 96 ms, not an iPhone FPS measurement.
No script/parse/normalization/object-leak errors were found in either accepted
run's preserved logs. CI now includes the ATV ordinary and tournament scenario;
adding that scenario is not evidence that hosted CI has passed it.

Final integration gate `kras-party-check.Q6D3RC` compiled 286 scripts, audited
323 resources with zero issues, passed 19,118 assertions, passed the real
three-lap race regression and completed 39 stability matches without failure.
The existing macOS sandbox system-CA lookup warning remains; this gate is not
proof of iOS certificate trust, thermal behavior, frame rate or device audio.
No production deployment, iOS archive, upload or review submission was performed
for this development-room acceptance.

### Outstanding CI collection acceptance

Run `37001208281` on historical source
`6567c803b07064f941dfbfd0c29699ae0796378e` reported a failure in job
`110819091468` (`network-crate_relay`). Its 2-human/2-bot match passed with
scores `[21,3,12,15]`; the 4-human match reached results `[18,0,12,6]`,
but peer 2 failed the fixture's per-local-player scoring assertion. The
message says "without any scoring", although other players scored. This
is an unresolved acceptance failure, not a passed room test. A fresh inspection
confirmed the run is terminal: 27 jobs passed and this one failed. No full CI
success is claimed.
Preserved artifact `11226595746` contains the peer logs. Inspect the fixture's
pickup/return routing and reproduce on Linux before changing either gameplay
or the test requirement; do not convert this to a passing aggregate assertion
or rerun blindly to erase the failure.

The diagnostic fixture now reports each relay player's position, velocity,
cargo and score. Its failure message identifies the local slot and actual
result scores; the per-local-player delivery assertion remains unchanged.
Periodic timing diagnostics additionally report the match seed for future
failure investigation. These changes do not award points or move players.

An isolated Linux ARM64 reproduction used the official Godot 4.7.1 binary
with archive SHA-256
`8f527179cd4ae58b402fa265fe817dc505e5b6b14574f309efe57113be562ac1`.
Asset import completed without script/parse/leak errors and `npm ci
--ignore-scripts` reported zero dependency vulnerabilities. This is a native
ARM64 Linux container, not the historical GitHub runner's AMD64 environment.
Source `10911cff4773e437ed5d1a584d33a75770880719` was exercised without the
later seed-log addition. Independent-process evidence
`/tmp/kras-relay-linux/evidence/kras-network-smoke-BObbQH` passed both rosters:
scores `[9,6,21,18]` for two humans plus two bots and `[15,15,12,12]` for four
humans. Every human observed their own cargo and scoring; guest snapshots
numbered 1,088-1,107. Host interrupted-result delivery and guest identity
recovery passed. Maximum server event-loop delay was 56 ms. No script,
normalization or object-leak errors were found in the preserved peer logs.
This passing reproduction does not explain or resolve the historical failure.

Linux tournament evidence
`/tmp/kras-relay-linux/evidence/kras-network-smoke-Y4MZ21` also passed both
rosters, each completing three actual matches. The two-human/two-bot standings
were points `[13,11,5,6]`, cups `[2,1,0,0]`, champion slot 0. Four-human
standings were points `[7,11,8,8]`, cups `[1,2,1,1]`, champion slot 1. All
peers agreed on final standings and retained their own cargo/scoring observations.
Guests received 1,665-1,684 snapshots; host/guest recovery passed. No tiebreak
was needed in these runs, so they are not sudden-death evidence. Maximum server
event-loop delay was 107 ms; this is not a mobile performance qualification.
No script/parse/normalization/leak errors were found in the preserved logs.

The later seed-log edit passed the project's autoload-aware compile scene:
`/tmp/kras-relay-diagnostics-compile.log` reports all 286 scripts compiling.
A preliminary standalone `--check-only --script` invocation was not valid
evidence: without an explicit writable log path it crashed in engine logging,
and with that path it could not resolve the `Net` autoload in standalone mode.
The proper compile scene passed, with the existing sandbox macOS system-CA
lookup warning. No full integration gate was rerun for this logging-only edit.

### Turret Duel rooms and tournament acceptance

Development rooms accept `turret_duel` only on its authored `iron_flats`
arena. Host-only snapshots require bounded launch generations, damage and
cooldowns; guests cannot publish authoritative world state. The smoke runner
now uses the server's game allowlist instead of maintaining a duplicate list.
All 79 Node tests passed. An initial sandboxed run failed the local WebSocket
listen with `EPERM`; rerunning with local-listen permission passed every test.

Independent-process run `kras-network-smoke-mZM3bb` passed both 2 humans plus
2 bots and 4 humans. Scores were `[10,12,0,0]` / `[8,2,1,6]`. Guests received
1,489-1,508 world snapshots. Human input used actual steering and firing,
without injected projectile contacts or score changes. Every peer observed
shots, damage and hit points. Guest views converged to host launch generations,
positions, cooldowns and damage without independent projectile physics.
Host and guest identity recovery and interrupted result delivery passed.
Maximum local server event-loop delay was 42 ms.

Tournament run `kras-network-smoke-ld3Y2O` passed both rosters. The 2-human/
2-bot roster completed three regular matches and two actual tiebreaks:
points `[12,12,5,5]`, cups `[2,2,0,0]`, champion slot 0 and final awards
`[0,0,0,0]`. The 4-human roster completed three matches: points `[9,11,8,8]`,
cups `[2,3,2,2]`, champion slot 1. Its final match was a scoreless draw;
shot/damage/score observation is an aggregate tournament assertion, not proof
that every individual round scored a hit. Guests received 2,268-3,746 world
snapshots. Reconnect, world presentation and final tournament agreement passed.
Maximum local server loop delay was 85 ms. Both run directories had no script,
parse, network-failure, normalization or object-leak errors.

Full integration gate `kras-party-check.YOUvmT` compiled 284 scripts, audited
321 resources with zero issues, passed 18,976 assertions, passed the real
three-lap race regression and completed 39 stability matches without failure.
The macOS system-CA lookup warning appeared in sandboxed headless runs;
compilation and all listed checks still passed. HTTPS/device trust remains
a separate release verification requirement.

The development allowlist contains 29 games; 10 still need independent
network acceptance. Production online remains disabled. These localhost
headless tests do not qualify Internet latency, visual quality or phone FPS,
thermal/battery performance. Impact/score sound parity remains unverified;
sampled launch presentation is not a lossless event stream.

### Turret Duel snapshot adapter

Host world snapshots carry active shots (pooled-body identity plus launch
generation, position, direction and shooter), per-player cooldowns and
damage. `Projectile.fire` increments the body's launch serial; returning it
to the pool does not reset that serial. This distinguishes a new trajectory
from a previously visible launch without changing projectile damage rules.

Both Godot and Node reject missing/extra fields, invalid counts, duplicate
body identities, noncanonical IDs, invalid launch generations/shooters,
non-finite values and non-horizontal/non-unit directions. The guest releases
its independent physics shots, then displays collision-free meshes. Stable
launches reuse their visual, recycled launches replace the old trajectory,
and expired launches disappear. Host cooldowns and damage are copied, never
simulated or used to award points on the guest.

`/tmp/kras-turret-network.log` passed all 70 focused assertions, including
real pool reuse, interpolation, no visual collision nodes, state rejection,
and audio-pool advancement for a new launch only. Initial/new-round baselines,
duplicates and stale/reconnect updates suppress old launch sounds. The first
test iteration counted the shared HUD's legitimate `go` cue as launch audio;
the fixture now isolates HUD transitions without suppressing them in the
product. All 78 Node tests passed.

Full gate `kras-party-check.Rcpn4a` compiled 284 scripts, audited 321 resources
with zero issues, passed 18,976 assertions, passed the three-lap race
regression and completed all 39 stability matches without failure.

This historical adapter checkpoint preceded the room acceptance above.
Physical-device QA remains required. Launch audio is sampled presentation,
not a lossless event stream; impact/score sound parity is not established.
Production online remains disabled.

### Turret Duel round and projectile prerequisites

Turret Duel previously retained active pooled shots and firing cooldowns into
the next round. Its round-start hook now releases old shots and clears all
cooldowns. The shared Projectile previously emitted `hit_fighter` even when
`Fighter.take_hit` refused the hit due to invulnerability, shield or a
teammate. This incorrectly awarded Turret Duel hit points without damage.
Generic shots now emit the scoring event only after an accepted hit; a
blocked collision still consumes the shot. `notify_only` weapons retain their
delegated reaction path and do not apply generic damage.

`/tmp/kras-turret-rounds-before.log` showed 18 failures across three round
resets and actual physics-overlap contacts. After the fix,
`/tmp/kras-turret-rounds-after.log` passed all 58 executed assertions,
covering invulnerability, shields, teammates, ordinary hits and delegated
hits. The assertion count differs because rejected hits no longer invoke
the callback's shooter/victim checks; those blocked callbacks are explicitly
asserted absent. This does not enable Turret Duel online: projectile world
presentation and independent-process acceptance remain to be implemented.

Full gate `kras-party-check.7f32qe` compiled 282 scripts, audited 319 resources
with zero issues, passed 18,907 assertions, passed the three-lap race
regression and completed all 39 stability matches without failure. This
covers the shared projectile change locally, not online or device acceptance.

### Drift Floes rooms

Development rooms now accept `drift_floes` only on `vortex_ring` and
`storm_ring`. The server requires bounded host-only platform snapshots and
rejects invalid arena selections or malformed/missing world payloads. All
77 Node tests passed, including both arenas and denial of guest publication.

Independent-process run `kras-network-smoke-Hf4LTG` passed for 2 humans plus
2 bots and 4 humans on `vortex_ring`. Aggregate scores were `[12,12,18,12]`
/ `[6,12,12,14]`. Guests received 855-1,328 snapshots. All peers observed
moving platforms and falls; guests converged to host platform transforms
and motion age with collision/physics synchronization disabled. Guest
identity recovery and interrupted host result delivery passed. Logs had no
script, parse, network-failure, normalization or object-leak errors.
Maximum local server event-loop delay was 166 ms; this is not a phone frame
rate or Internet-latency measurement.

Tournament run `kras-network-smoke-kgPKDl` passed for both rosters and visited
both authored arenas in each. The 2-human/2-bot roster completed three regular
matches plus a real tiebreak: points `[5,4,12,12]`, cups `[0,0,2,2]`, champion
slot 2, final awards `[0,0,0,0]`. Both human spectators remained inactive in
the bot final; their lack of movement in that final is intentional. The
4-human roster completed three matches: points `[4,5,11,13]`, cups
`[0,0,1,2]`, champion slot 3. Guests received 1,059-2,821 snapshots, with a
maximum local server loop delay of 79 ms. Host/guest identity recovery,
world-presentation comparison and final tournament agreement passed. Logs
had no script, parse, network-failure, normalization or object-leak errors.
Production online remains disabled; Internet/device qualification is pending.

Full integration gate `kras-party-check.tx6bmB` compiled 281 scripts, audited
318 resources with zero issues, passed 18,850 assertions, passed the three-lap
race regression and completed all 39 stability matches without failure.
The development allowlist now contains 28 games; 11 other games still need
their own network integration and independent-process acceptance.

### Drift Floes lifecycle and snapshot adapter

The moving plates previously retained sudden-death speed multipliers and
their last positions until the next gameplay tick. New rounds now restore
each authored base speed and place all three plates at their time-zero
positions before countdown. `/tmp/kras-floe-reset-before.log` demonstrated
18 failing assertions; `/tmp/kras-floe-reset-after.log` passed all 22
assertions across three consecutive reset cycles.

The adapter publishes exactly three bounded platform positions and a bounded
motion age. Both Godot and Node reject missing/extra fields, wrong counts,
non-finite values and JSON type coercion. Guest platforms interpolate toward
host positions, snap on a new round and have no collision layers or kinematic
physics synchronization. Rendering does not run carry physics, elimination,
respawn, scoring or difficulty updates. `/tmp/kras-floe-network.log` passed
all 41 focused assertions; all 76 Node tests passed.

Full gate `kras-party-check.EdrXr7` compiled 281 scripts, audited 318 resources
with zero issues, passed 18,850 assertions, passed the three-lap race
regression and completed all 39 stability matches without failure.

This adapter checkpoint preceded the room integration above. Its unit tests
alone do not establish independent-process transport or device quality.
Production online remains disabled.

### Duo Clash integration

Development rooms accept both authored team arenas: `sweeper_ring` and
`bumper_bowl`. World snapshots include two team totals, per-slot lives/damage
and the selected arena's existing hazard presentation. Both Godot and Node
bind hazard state to the selected arena and reject malformed scores, rosters,
life counts and alternate hazard payloads. Presentation never awards points
or schedules respawns. All 101 focused Godot assertions and 75 Node tests
passed. The CI matrix includes the game; this is not an external CI result.

Ordinary run `kras-network-smoke-edZCRV` passed for 2 humans plus 2 bots and
4 humans on `sweeper_ring`. Aggregate two-round scores were
`[114,93,111,91]` / `[163,103,164,102]`, guest snapshots 830-1,031,
maximum local server loop delay 34 ms. Every peer observed team scoring,
life loss and damage. Guest HUD, lives/damage and hazard transforms matched
the host; guest identity recovery and interrupted host result transport
passed. Logs contained no script, parse, network-failure, normalization or
object-leak errors.

Tournament run `kras-network-smoke-QF6WlG` passed for both rosters, visiting
both authored arenas. Each completed three matches. Points were
`[9,10,5,9]` / `[7,8,8,11]`, cups `[1,1,0,1]` / `[1,1,1,2]`, champions
slots 1 / 3. Guests received 1,407-1,737 snapshots; maximum local server
loop delay was 96 ms. Host and guest reconnection passed.

The forced equal-points final first failed in `kras-network-smoke-SGI0HM`:
Godot array equality distinguishes JSON floating-point numbers from integer
literals, even when their numeric values match. An isolated probe confirmed
`JSON.parse_string("[3,3,3,3]") == [3,3,3,3]` is false. The fixture now checks
all four numeric values and retains the original cup baseline, with actual
values in its failure diagnostic; no production scoring rule was weakened.
Rerun `kras-network-smoke-fiUGn3` passed with four human processes: three
team rounds plus one individual `duel_pit` final, champion slot 1, points
`[3,3,3,3]`, unchanged cups `[2,0,1,0]`, and final awards `[0,0,0,0]`.
Guests received 2,341-2,360 snapshots; maximum local server loop delay was
74 ms. Host/guest reconnect and final-state agreement passed. Logs contained
no script, parse, network-failure, normalization or object-leak errors.

Team-tournament finalists cannot duel under friendly-fire protection.
The server therefore selects `duel_pit` for tied Duo Clash finalists,
retains it for successive tie attempts and preserves the original points,
cups and playlist. The new Node test failed before this change and passed
afterward, including a tie between slots 0 and 2 and spectator exclusion.
Local tournaments already use their existing individual Quick Draw final.
Production online remains disabled; local headless transport tests do not
establish physical-device performance or Internet qualification.

Full gate `kras-party-check.nfMBku` compiled 278 scripts, audited 315 resources
with zero issues, passed 18,789 assertions, passed the three-lap race
regression and completed all 39 stability matches without failure. A fresh
`npm test` run passed all 75 server tests. These are local headless checks,
not evidence of iPhone frame rate, battery use or thermal behavior.

External CI run `36993022044` completed successfully with all 25 jobs for
`6197bf466043b6ca86cc3e95d187d2d9efa825d1`. It predates the Duel, Bumper
and Duo integrations and must not be treated as validation of this source.

### Duo Clash scoring prerequisite

The common arena out-handler already credits personal knockouts. Duo Clash
credited them again, doubling the statistic and its personal result tiebreak.
The team hook now only pays the team and publishes its shared score.
`/tmp/kras-duo-credit-before.log` reproduced three failed assertions;
`/tmp/kras-duo-credit-after.log` passed 112 assertions, including two
legitimate enemy knockouts, unchanged team points, partner score sharing,
friendly-fire rejection, duplicate out callbacks and result score 42 rather
than 44. This targeted repair does not enable Duo Clash online.

### Bumper Bowl room integration

Development rooms accept `bumper_bowl` only on its authored `bumper_bowl`
arena. The server rejects guest world publication, missing/invalid bumper
state and mismatched arenas. All 72 Node tests passed. CI configuration now
includes the game; this is not a passing external CI result.

Ordinary independent-process run `kras-network-smoke-b8EQNO` passed with
2 humans plus 2 bots and 4 humans. Aggregate two-round scores were
`[11,13,19,18]` / `[15,21,31,22]`, guests received 1,700-1,720 snapshots,
and maximum local server event-loop delay was 102 ms. Every peer had to
observe a bumper hit and a player returning after a fall; guest bumper scales
matched the host world. Guest identity recovery and interrupted host result
transport passed. Logs contained no script, parse, network-failure,
normalization or object-leak errors.
These checks are local headless evidence, not Internet or mobile performance
qualification. Production online remains disabled.

Tournament run `kras-network-smoke-ZbAho7` passed for both rosters. The
2-human roster completed three regular rounds and two actual tiebreaks:
points `[5,4,12,12]`, cups `[0,0,2,2]`, champion slot 2. Tiebreak awards were
all zero, preserving the original standings. The 4-human roster completed
three rounds with points `[3,6,15,9]`, cups `[0,0,3,0]`, champion slot 2.
Guests received 2,641-4,016 snapshots; maximum local server loop delay was
41 ms. Guest identity recovery and interrupted host result transport passed,
and logs contained no script, parse, network-failure, normalization or
object-leak errors. Device smoothness and Internet latency remain unverified.

Full gate `kras-party-check.H3tHak`: 276 scripts compiled, 313 resources
audited with zero issues, 18,671 assertions passed, race regression passed
and all 39 stability matches passed. The development allowlist now contains
26 games; production online remains disabled.

### Bumper Bowl snapshot adapter

Host snapshots now carry the five authored bumper mesh scales and bounded
hit serials. Godot and Node reject missing/extra fields, wrong counts,
non-finite/coercible values and scales outside the authored squash range.
Guests apply visual scales without ticking collision detection or awarding
points. New hit serials trigger bounce audio once; initial/reconnect and
new-round baselines, duplicates and stale updates do not replay old sounds.
This is sampled presentation, not lossless collision-event delivery.

`/tmp/kras-bumper-network.log`: all 52 assertions passed, including actual
audio-pool voice advancement and duplicate suppression with audio debounce
cleared. All 71 Node tests passed. This adapter-only checkpoint preceded
the room integration and independent-process verification documented above.

Full gate `kras-party-check.XsFti5`: 276 scripts compiled, 313 resources
audited with zero issues, 18,671 assertions passed, race regression passed
and all 39 stability matches passed. This includes the hazard reset repair.
No production deployment, mobile performance qualification or App Store
submission is established by these local headless checks.

### Bumper hazard lifecycle prerequisite

Bumpers now clear per-player cooldowns and restore their visual shape at
round reset. Repeated hits replace the existing squash tween instead of
stacking animations on the same mesh. The arena resets all five bumpers.
`/tmp/kras-bumper-reset.log`: 94 assertions passed, including three successive
round resets and repeated-hit tween cancellation. This is not room enablement.

### Bumper Bowl survival-score correction

Match-alive players waiting offstage for respawn were incorrectly receiving
survival points when another fighter fell. The scoring loop now excludes
pending respawns; returned players are eligible again. Attacker credit and
active survivors' points are unchanged.

`/tmp/kras-bumper-survivor-before.log` reproduced two failed assertions;
`/tmp/kras-bumper-survivor-after.log` passed all 31 assertions, including
absent-player exclusion, active-survivor credit and restored eligibility.
This repair alone does not enable Bumper Bowl online.

Full gate `kras-party-check.z1Ggug`: 274 scripts compiled, 311 resources
audited with zero issues, 18,557 assertions passed, race regression passed
and all 39 stability matches passed. All 70 Node tests passed after allowing
the real WebSocket test to open its local listener; the sandbox-only attempt
reported `listen EPERM`, not a gameplay assertion failure. These checks do
not establish physical-device performance or production readiness.

### Duel Pit room integration

Development rooms now allow `duel_pit` only on its authored `duel_pit` arena.
The server requires bounded host lives/damage and rejects guest publication,
wrong arenas and invalid world fields. All 70 Node tests passed. The CI matrix
includes Duel Pit; this is not itself a passing CI result.

Ordinary independent-process matches `kras-network-smoke-JuROSs` passed for
2 humans plus 2 bots and 4 humans. Aggregate scores were `[27,16,4,13]` and
`[16,18,2,5]`, guest snapshots 1,256-1,686, maximum local server event-loop
delay 38 ms. Both modes recovered guest identity and interrupted host result
transport. Scripted humans approach opponents and pulse attack; every peer
must observe damage, life loss and a returned living fighter with fewer than
three lives. Guests compare HUD damage/lives against host snapshots. These
checks are local headless evidence, not mobile or Internet qualification.

Tournament run `kras-network-smoke-SzHsCn` passed three matches for each
roster. Points were `[6,5,13,10]` / `[15,6,8,7]`, champion slot 2 / 0,
with 2,197-2,559 guest snapshots and maximum local server loop delay 53 ms.
Host and designated guest reconnect passed, as did actual damage, life loss,
respawn and host/guest world agreement checks. No final tie occurred. Logs
contained no script, parse, network-failure, normalization or object-leak
errors. Production online remains disabled.

Full gate `kras-party-check.Fncpr6`: 274 scripts compiled, 311 resources
audited with zero issues, 18,553 assertions passed, race regression passed,
and all 39 stability matches passed. Physical-device and Internet testing
remain separate release requirements.

### Duel Pit snapshot adapter

Duel snapshots now include per-slot lives and accumulated damage for the
guest HUD. Godot and Node require both arrays to match the roster, lives to
be integers in 0-3, and damage to be finite in 0-10,000. Missing/extra fields,
coercible values and mismatched rosters are rejected. Guest presentation
updates only these fields; it does not spend lives, award points or schedule
respawns. New-round snapshots restore lives and clear damage.

`/tmp/kras-duel-network.log`: all 39 assertions passed, including the visible
damage text and idempotent repeated rendering. All 69 Node tests passed.
This adapter-only checkpoint preceded room enablement and the independent
combat, respawn, reconnect and tournament checks documented above.
Full gate `kras-party-check.CnwV0b`: 274 scripts compiled, 311 resources
audited with zero issues, 18,553 assertions passed, race regression passed
and all 39 stability matches passed. This is desktop headless evidence, not
physical-device performance, Internet connectivity or App Store readiness.

### Arena respawn scoring prerequisite

Duel Pit credited each knockout twice: the common out-handler incremented
the statistic before the game incremented it again. Duplicate out callbacks
while a fighter waited for respawn could also spend another life and count
another fall. The shared handler now rejects slots already waiting for
respawn, Duel Pit relies on the common single credit, and Bumper Bowl pays
survivors only for the first accepted out event.

`/tmp/kras-arena-credit-before.log` reproduced eight failed assertions.
`/tmp/kras-arena-credit-after.log` passed the initial 21 assertions; expanded
`/tmp/kras-arena-credit-final.log` passed 27, including a fresh legitimate
knockout after respawn. The score snapshot assertion uses a duplicate array
so subsequent mutations cannot change its expected value. Neither game is
online-enabled by this scoring repair; world/HUD replication and real room
verification remain required.
Full gate `kras-party-check.2UPhDF`: 272 scripts compiled, 309 resources
audited with zero issues, 18,515 assertions passed, race regression passed
and 39 stability matches completed without failures. Device performance and
production deployment are not established by this headless test run.

### Sweeper Storm room integration

Development rooms now accept `sweeper_storm` only on `sweeper_ring` and
require all three host-owned arm angles. All 68 server tests passed, including
wrong-arena, guest-publication and malformed-world rejection. The CI matrix
includes Sweeper Storm; matrix configuration is not a successful CI run.

Ordinary matches `kras-network-smoke-v4oI3D` passed with 2 humans plus 2 bots
and 4 humans. Aggregate scores were `[6,6,15,15]` / `[4,8,12,16]`, guests
received 646-959 snapshots, and host/guest reconnect succeeded. Guest arm
angles matched the host world; all three host arms advanced. Maximum local
server event-loop delay was 32 ms. No script, parse, network-failure,
normalization or object-leak errors appeared. This is local headless transport
and presentation evidence, not Internet or physical-device smoothness QA.

Tournament run `kras-network-smoke-WrphJP` passed three matches per roster.
Points were `[4,5,13,11]` / `[4,5,15,9]`, champion slot 2 in both cases,
with 1,094-1,254 guest snapshots and maximum local server loop delay 38 ms.
The host had to observe an actual environmental hit with positive force;
guests had to observe replicated stun feedback. Both guest reconnect and
interrupted host result transport passed. No final tournament tie occurred,
and the logs contain no script, parse, network-failure, normalization or
object-leak errors. Production online remains disabled.
Final gate `kras-party-check.jAHEM5`: 271 scripts compiled, 308 resources
audited with zero issues, 18,489 assertions passed, race regression passed
and all 39 stability matches passed.

External CI run `36986801070` completed successfully: all 22 jobs on commit
`92ed5948f64825bd655115e2623196fe0a10c594` passed. That run covers the core
and 21 room games through Crate Relay, not the subsequently added Hurdle,
Tide or Sweeper integrations. Newer commits need their own CI result.

### Sweeper Storm snapshot adapter

Snapshots now carry the three authored sweeper angles in stable arena order.
Capture wraps angles to [-PI, PI]; both Godot and Node reject missing/extra
fields, the wrong arm count, non-finite values, strings, booleans and angles
outside that range. Guest presentation sets only arm transforms and never
ticks acceleration or collision checks. New-round snapshots replace the
previous seeded orientations.

`/tmp/kras-sweeper-network.log`: all 26 assertions passed, including unchanged
scores/alive state and acceleration age during repeated rendering. All 67
Node tests passed. This adapter initially remained outside room allowlists;
subsequent independent-process room and tournament evidence appears above.
These tests do not establish smoothness or visual fidelity on a physical
device; the current adapter applies authoritative angles without prediction.
Full gate `kras-party-check.2OzdHE`: 271 scripts compiled, 308 resources
audited with zero issues, 18,489 assertions passed, race regression passed,
and 39 stability matches completed without failures. The sandbox system-CA
lookup diagnostic does not establish or invalidate production TLS readiness.

### Rising Tide room integration

Development rooms accept `rising_tide` only on `tide_spire` and require the
host's bounded water snapshot. All 66 server tests passed, including wrong
arena, guest publication and invalid-world rejection. The CI matrix includes
Tide; that configuration alone is not passing CI evidence.

The first local run `kras-network-smoke-LGQBAB` failed before entering a room:
GDScript could not infer the scripted movement target's type. An explicit
Vector3 declaration fixed the test fixture. No gameplay rules changed.

Ordinary matches `kras-network-smoke-ptMv8f` passed with 2 humans plus 2 bots
and 4 humans: aggregate scores `[4,8,13,20]` / `[4,9,13,16]`, 975-994 guest
snapshots, guest reconnect and interrupted host result transport. The fixture
circles the base platform and requires positive water height and an eliminated
player; guests compare their water height to the received host snapshot.
Maximum local server event-loop delay was 130 ms. The logs contain no script,
parse, normalization, network-failure or leaked-object errors. This does not
certify physical-device rendering, latency or production readiness.

The first tournament run `kras-network-smoke-OGRCPl` also passed transport
checks (three matches for both rosters, points `[3,6,9,15]`, champion slot 3,
1,497-1,516 snapshots, maximum loop delay 83 ms), but exposed a scoring defect:
players submerged on the same tick received different ranks by slot iteration
order. Those results are not evidence of fair final scoring.

`kras-tide-scoring-before-valid.log` reproduced both all-player and partial
ties incorrectly ranked by slot. Tide now records the authoritative hazard
age at elimination and ranks equal-age victims equally; earlier victims
still score lower and surviving players retain their lead. Knockout rewards
are preserved. `kras-tide-scoring-after.log`: all three assertions passed.
The first fixture attempt used an illegal intro-to-playing transition and
was corrected before the valid pre-fix reproduction. Full gate
`kras-party-check.sIIPhC` started before this scoring repair and must not be
treated as verification of the new scoring code.

Post-fix tournament `kras-network-smoke-94sWVd` passed both rosters and
required a nonempty host submersion ledger. Two humans plus bots completed
three matches, points `[6,7,8,15]`, champion slot 3 and 1,496 guest snapshots.
Four humans completed three regular matches plus three actual tied finals:
points `[9,9,9,9]`, final scores `[2,2,2,2]`, and the existing bounded-tie
policy returned shared champions `[0,1,2,3]` instead of awarding by slot.
Guests received 2,943-2,962 snapshots. Maximum local server loop delay was
52 ms. Host/guest reconnect and all tournament views matched. This run
supersedes the earlier tournament scoring evidence, not its transport history.
No runtime, parse, network-failure, axis-normalization or leaked-object errors
were found in the post-fix logs. Final gate `kras-party-check.hehzco` compiled
269 scripts, audited 306 resources with zero issues, passed 18,464 assertions
and the race regression, and completed 39 stability matches without failures.
Production online remains disabled; device and Internet qualification remain.

### Rising Tide snapshot adapter

The shared snapshot path now supports host-owned water level and wave age.
Guests restore the water plane and wave phase without advancing hazards,
checking submersion or awarding points. The normal online guest loop returns
after presentation, before arena simulation. Godot and Node validators reject
missing/extra fields, non-finite values, coercible strings/booleans, heights
outside +/-1,000 and ages outside 0-3,600 seconds.

`/tmp/kras-tide-network.log`: 28 assertions passed, including serialized state,
repeated rendering without simulation, and new-round water reset. All 65
Node tests passed. This initial adapter validation preceded the room
integration and independent-process evidence documented above.
Full gate `kras-party-check.ZuzOJ5`: 268 scripts compiled, 305 resources
audited with zero issues, 18,460 assertions passed, race regression passed
and all 39 stability matches passed. This remains headless desktop evidence,
not mobile rendering, Internet connectivity or release approval.

### Survival hazard lifecycle prerequisite

Rising Tide retained the sudden-death water speed in later rounds; Sweeper
Storm also retained acceleration age and multiplied spin speed. Arena reset
now restores authored speeds with the selected hazard mutator multiplier,
clears sweeper age, and resets the water's visual wave offset along with its
level, age and submerged-player history.

`/tmp/kras-survival-before.log` reproduced 16 failures across three rounds.
`/tmp/kras-survival-after.log` passed all 31 assertions, including preservation
of double-speed configuration. Neither game is online-enabled by this fix:
authoritative hazard replication and independent-process checks remain.
Full gate `kras-party-check.PutZyC`: 266 scripts compiled, 303 resources
audited with zero issues, 18,433 assertions passed, race regression passed
and 39 stability matches completed with zero failures. The sandbox CA lookup
diagnostic remains an environment limitation, not proof of working TLS.

### Hurdle Dash room integration

Development rooms now allow `hurdle_dash` only on `hurdle_track`. The server
rejects guest snapshots, missing worlds, future finish times and negative
clocks. Tournament ranking ignores client scoring-direction flags. All 64
Node tests passed with local socket access; the sandbox-only run failed its
WebSocket test with `listen EPERM`, not an application assertion.

Independent Godot processes tested 2 humans plus 2 bots and 4 humans:

- Ordinary matches `kras-network-smoke-lWCmzd`: both passed, aggregate times
  `[1395,1355,2950,2948]` / `[1412,1372,1322,1315]`, 770-1,129 guest
  snapshots, maximum local server event-loop delay 34 ms.
- Tournaments `kras-network-smoke-Ev1bAr`: three matches per case, points
  `[9,15,6,3]` / `[6,10,9,8]`, champion slot 1 in both cases,
  1,181-2,292 guest snapshots, maximum event-loop delay 34 ms.

Every active runner, including bots, had to finish. Guests verified the
host clock and finish times. Both modes exercised guest reconnect and host
result-transport loss. No final tournament tie occurred. Neither passing
run reported script, parse, network-failure, normalization or object-leak
errors. These are local headless tests, not Internet or physical-device QA.

Earlier runs `kras-network-smoke-XVM0AY` and `kras-network-smoke-NtBDGo`
failed because the scripted runner held jump after detecting an obstacle
while airborne. Landing then produced no new jump edge. Position diagnostics
isolated the stalled runner; the fixture now pulses jump while an obstacle
is visible. Game rules were not weakened to pass the fixture.

The CI matrix includes Hurdle Dash; that definition is not a completed CI
run. Production online remains unchanged and disabled.

Full gate `kras-party-check.aBaIew`: 265 scripts compiled, 302 resources
audited with zero issues, 18,403 assertions passed, race regression passed
and all 39 stability matches passed. The sandbox emitted the macOS system
CA lookup diagnostic; these checks do not certify production TLS access.

### Hurdle Dash snapshot adapter

Hurdle snapshots now carry only the host elapsed clock and per-slot finish
times. The fixed authored obstacles need no dynamic world payload. Godot
and Node reject extra/missing fields, roster mismatches, non-finite values,
out-of-range times and finishes later than the elapsed clock. The existing
unfinished sentinel is preserved. Guests restore the timer/banner, finish
count and HUD values without ticking race logic or awarding points.
Finish feedback tracks previous times per round, with silent first/reconnect
snapshots and no repeated cue for an unchanged finish.

The initial fixture compared JSON float arrays against integer game arrays
and failed despite equal values (`/tmp/kras-hurdle-network.log`); changing
the assertions to compare each integer time fixed that test-only mismatch.
`/tmp/kras-hurdle-network-after.log`: all 38 assertions passed. Server tests:
63 passed. These tests cover state validation and round reset, not audible
device QA. This adapter originally remained outside room allowlists; the
subsequent integration and multi-process verification are documented above.
Full gate `kras-party-check.YurKl9`: 265 scripts compiled, 302 resources
audited with zero issues, 18,403 assertions passed, race regression passed
and all 39 stability matches passed.

### Race result ordering

Server tournament ranking now reads each game's scoring mode from the shared
`data/minigames.json` catalogue. Race times rank ascending for points, cups
and final tiebreaks; other game scores still rank descending. Client-supplied
ranking flags are ignored. Unknown game IDs and results before selecting a
round are rejected without changing accounting. Godot's network result path
also passes the game's scoring direction into MatchResult.

Two new server regressions failed before the fix. The Godot regression in
`/tmp/kras-race-result-before.log` incorrectly selected unfinished slot 3;
`/tmp/kras-race-result-after.log` passes all 26 assertions including winner
slot 0 and duplicate-result protection. All 62 Node tests passed locally
and inside the built Linux container, covering mixed playlists, cups,
unknown games, and faster spectators excluded from a race tiebreak.

Docker now copies the catalogue to `/app/data/minigames.json`. Local image
`kras-pass-scoring-check` built successfully (config ID
`6eeebef8aabb8421e627688684729bdd1e2042a678a290df9e873e9bfcb1c5d7`).
A network-isolated container started the real server with a temporary SQLite
database and test owner address: `/health` returned HTTP 200 with `ok=true`,
`authentication_ready=false`, `multiplayer_enabled=false`. This is packaging
evidence, not Railway deployment or Apple authentication verification.

Full gate `kras-party-check.ZAQbsp`: 263 scripts compiled, 300 resources
audited with zero issues, 18,366 assertions passed, race regression passed
and all 39 stability matches passed. Hurdle world replication and real
race-room tests remain required before enabling races in the allowlist.

### Hurdle Dash lifecycle prerequisite

Straight-track queries now use the authored half-width (already stored in
`current_radius`) and both longitudinal edges, including clearance margins.
Hurdle finish detection requires a living active runner above the floor and
inside the track, rather than accepting any position beyond the finish Z.
Fall recovery is bounded to the track and remains before the finish line.
The visible elapsed banner resets each round. Only fastest-time ties count,
and inactive contenders neither finish nor hold the round open.

`/tmp/kras-hurdle-before.log`: 14 assertions failed before the fix.
`/tmp/kras-hurdle-after.log`: all 23 assertions passed, including immutable
finish times, out-of-track/fallen/spectator rejection, bounded rescue and
active-contender completion. Hurdle Dash is not online-enabled yet; its
world adapter and independent-process tests remain required.
Full gate `kras-party-check.KPjNfF`: 263 scripts compiled, 300 resources
audited with zero issues, 18,363 assertions passed, race regression passed
and all 39 stability matches passed. The subsequent lower-is-better
tournament/result repair is documented above.

### Crate Relay room integration

Development rooms now allow `crate_relay` only on `relay_docks`. The server
requires bounded host-owned crate/carrying snapshots and rejects guest
publication, wrong arenas and invalid cargo. All 58 server tests passed.
The CI matrix includes Relay, but a matrix definition is not a passing run.

Independent Godot processes exercised 2 humans plus 2 bots and 4 humans.
Each human had to carry a crate and earn delivery points. Scripted input
uses visible pickups and routes via the center if a straight path leaves
the cross-shaped floor. Guests compare pickup identities/transforms and
carried visuals against host snapshots, rather than running pickup rules.

- Ordinary matches `kras-network-smoke-LTCN5U`: both passed, scores
  `[27,6,6,12]` and `[18,12,12,12]`, 1,088-1,107 guest snapshots,
  maximum local server event-loop delay 71 ms.
- Tournaments `kras-network-smoke-lDQYgT`: three matches in each case,
  standings `[10,8,11,8]` / `[8,11,8,9]`, champion slots 2 / 1,
  1,665-1,684 guest snapshots, maximum local event-loop delay 59 ms.

Both test modes exercised guest reconnect and host result transport loss.
No final tournament tie occurred. No script, network-failure, parse,
axis-normalization or leaked-object reports appeared in these logs.
These are local headless tests, not Internet, physical-device performance,
visual QA or production deployment approval. Production online is unchanged.
Full gate `kras-party-check.B06uGA`: 262 scripts compiled, 299 resources
audited with zero issues, 18,341 assertions passed, race regression passed,
and all 39 stability matches passed.

### Crate Relay snapshot adapter

Relay now reuses the existing collectible reconciler for host-owned crate
identities and transforms, and publishes each player's single-crate carrying
state. Guests release their generated pickups, disconnect the hit observer,
and update carried visuals without running collection or delivery rules.
Relay payloads permit only `items` and `carrying`, at most eight field crates,
and carrying values of zero or one. Node and Godot enforce those bounds.

`/tmp/kras-relay-network.log`: all 99 collection-network assertions passed
across Gem Grab, Star Rush and Crate Relay, including collider-free replicas,
carried visuals, observer removal, malformed payloads and score neutrality.
The server suite at that adapter step passed all 57 tests. Room integration
and independent-process evidence are recorded above.
Full gate `kras-party-check.fI21yO`: 262 scripts compiled, 299 resources
audited with zero issues, 18,341 assertions passed, race regression passed
and 39 stability matches completed without failure.

### Crate Relay lifecycle and input prerequisite

Crate Relay now restores four center crates and the spawn clock between
rounds, clears carried visuals/cargo without duplicating docks, and restores
the controller's allowed attack state. Rejected second pickups re-enable
monitoring with a deferred write after Collectible's deferred disable; the
previous immediate write left the available crate permanently unmonitored.

The control declaration now exposes `attack` rather than unused `action`.
Ordinary hit events spill carried cargo without falsely recording a knockout;
cleanup disconnects that observer and is repeatable. Actual knockouts retain
their existing callbacks and cannot duplicate an already-spilled crate.

`/tmp/kras-relay-regression-before.log`: 8 lifecycle/pickup failures before
the fix. `/tmp/kras-relay-after.log`: all 34 assertions passed, including
deferred pickup ordering, restart, unique pool entries, once-only delivery,
ordinary-hit drops and observer cleanup. An earlier fixture compile error
in `/tmp/kras-relay-before.log` was corrected before measuring regressions.
Full gate `kras-party-check.ZwR2Xu`: 261 scripts compiled, 298 resources
audited with zero issues, 18,041 assertions passed, race regression passed
and 39 stability matches completed with zero failures.

Cross-arena queries now measure the exposed boundary of the two floor arms
and central disc, rather than falling back to circular bounds. The signed
distance ignores internal overlapping edges and supports cargo clearance.
Dropped cargo returns above the reachable floor, retaining pickup grace;
existing stranded available cargo recovers without awarding delivery points.
`/tmp/kras-relay-floor-before.log` records the failing geometry/recovery
regression. `/tmp/kras-relay-floor-after.log` passes 266 assertions, including
81 physical ground raycasts compared with the authored shape and queries.
Full gate `kras-party-check.wZkXOL`: 262 scripts compiled, 299 resources
audited with zero issues, 18,306 assertions passed, race regression passed,
and all 39 stability matches passed. No script errors, leaked-object reports
or axis-normalization errors appeared in the test output.
These geometry and lifecycle headless checks are not device QA. Subsequent
world-adapter and room evidence is recorded above.

### Crate and lab room integration

The development room/client allowlists now include `crate_smash` and
`lab_crates`, both on `crate_yard`. The server requires their bounded world
snapshots and rejects non-host publication, invalid arenas and lab-only
weapons in ordinary Crate Smash. Server tests: 56 passed.

Real independent Godot processes with scripted human input exercised 2 humans
plus 2 bots and 4 humans for each game. Every human had to earn points; the
lab additionally required observation of a weapon effect and an active volley.
Guest crate identities, types, positions and projectile counts matched host
snapshots. All runs exercised guest reconnect and host result transport loss.

- Initial Crate Smash run `kras-network-smoke-cfjRPG` failed with four zero
  scores: the fixture held attack continuously, but attacks use rising edges.
  Input now presses/releases attack every 800 ms, and the assertion checks
  the local human's score rather than accepting bot-only scoring. Game rules
  were not weakened to make the test pass.
- Crate matches `kras-network-smoke-o7oVlh`: both passed; scores
  `[24,7,18,8]` and `[16,13,19,20]`; 906-925 guest snapshots, max local
  server event-loop delay 48 ms.
- Crate tournaments `kras-network-smoke-2fMOTl`: three rounds in both cases;
  points `[10,9,7,8]` and `[14,7,8,4]`, champion slot 0 in each case;
  1,425-1,445 snapshots, max event-loop delay 56 ms.
- Lab matches `kras-network-smoke-NGLg1z`: both passed with observed volleys;
  scores `[10,10,9,15]` and `[19,28,10,11]`; 906-925 snapshots, max delay 77 ms.
- Lab tournaments `kras-network-smoke-k7swQO`: three rounds in both cases;
  points `[13,8,8,6]` and `[11,7,6,9]`, champion slot 0 in each case;
  1,438-1,460 snapshots, max delay 38 ms.

These local headless tests did not produce a final tournament tie and do not
certify Internet latency, device FPS, thermal/battery behavior or visual QA.
Production remains disabled; these results are not an App Store submission.
Final integration gate `kras-party-check.8dy6Z0`: 260 scripts compiled,
297 resources audited with zero issues, 18,008 assertions passed, race
regression passed and 39 stability matches completed with zero failures.

### Crate and lab snapshot adapter preparation

`crate_smash` and `lab_crates` now share a presentation adapter for normal,
bomb and lab weapon crates. Lab volleys include stable projectile identities,
position, direction and shooter slot. The guest discards its procedurally
generated crates/projectiles and reconciles visual-only nodes. It never runs
crate collision, damage, spawning or scoring. Crate views retain their node
while their identity/style is unchanged; expired shots are removed.

Strict matching Godot/Node validators bound the field to 14 crates and lab
volleys to 128 active shots, reject duplicate/noncanonical IDs, nonfinite
coordinates, unsupported kinds, invalid shooter slots and nonhorizontal or
unnormalized directions. Non-lab snapshots cannot introduce lab weapons.
Host break counters select feedback without replaying it on first snapshot,
duplicate update or reconnect. Only the latest break feedback in a snapshot
is presented; this is not lossless replay of every cosmetic event.

- `/tmp/kras-crate-network-final.log`: 125 assertions passed, covering shared
  dispatch, JSON, invalid packets, generated-body cleanup, noncolliding views,
  identity reuse, unchanged score/spawn clock, removal and feedback freshness.
- `npm test`: 55 tests passed including actual WebSocket transport tests and
  the new crate-world validator tests.
- At the adapter-only commit both games were excluded from room allowlists.
  The integration section below records subsequent match/room verification;
  portrait/landscape and real-device QA remain separate release gates.
- Full gate `kras-party-check.VOxBTB`: 260 scripts compiled, 297 resources
  audited with zero issues, 18,008 assertions passed, race regression passed
  and 39 stability matches completed with zero failures.

### Crate-game lifecycle prerequisite

Before adapting crate games to networking, `crate_smash` and `lab_crates`
now reset the field and spawn timer at each round start. Prior static crates
lose collision and visibility immediately before deferred deletion. The lab
also deactivates and reclaims its prior volley. Resetting neither awards nor
deducts points. Bomb-crate feedback now appears at the broken crate instead
of the world origin.

`tests/suites/test_crate_rounds.gd` exercises both controllers, a partially
destroyed field, stale spawn timing, an active lab volley, preserved scoring,
explosion placement and repeated cleanup. Before the fix:
`/tmp/kras-crate-rounds-before.log` had 75 failures. After:
`/tmp/kras-crate-rounds-after.log` passed all 80 assertions. This does not
enable crate-game networking; snapshots for crates and lab projectiles are
still required, followed by actual multi-engine tests.
Full gate `kras-party-check.dYNKR9`: 258 scripts compiled, 295 resources
audited with zero issues, 17,872 assertions passed, race regression passed,
and 39 stability matches completed with zero failures.

### Symbol Echo room integration

`symbol_echo` now has a bounded presentation adapter and matching Node/Godot
world validators. It publishes the currently visible pad/step, public sequence
length, phase, progress, mistakes, finishers and monotonic feedback counters.
It does not put the answer sequence or hidden phase timer in snapshots. Guest
presentation discards its locally generated sequence and cannot score or tick
the host rules. This is payload minimization, not a cryptographic secrecy or
anti-cheat guarantee: the broader protocol still shares deterministic seeds.

The development room allowlists now include `symbol_echo` on `echo_hall`.
Ordinary and tournament multi-process matches passed, including reconnect.
Adapter tests cover malformed/missing/extra fields, inconsistent finishers,
JSON round trips, repeated symbols, score/timer immutability and stale-audio
suppression. `/tmp/kras-echo-network.log`: 120 assertions passed. Server tests:
53 passed with local WebSocket listener permission; the sandbox-only attempt
failed at `listen EPERM` and is not counted as a passing transport run.
Full gate `kras-party-check.30MKH5`: 257 scripts compiled, 294 resources audited
with zero issues, 17,793 assertions passed, the three-lap race regression
passed and all 39 stability matches completed with zero failures. This is
desktop headless coverage, not iPhone performance or App Store approval.

Room integration evidence:
- Server tests: 54 passed, including host-only publication, invalid-arena
  rejection and rejection of an extra private-answer field.
- `kras-network-smoke-66fCC1`: ordinary 2-human/2-bot and 4-human matches passed.
  Every human observed a cue and received points for an observed answer;
  guest presentation matched authoritative phase/progress/mistakes. Results
  were `[14,10,3,14]` and `[4,14,26,21]`. Guests received 1,087-1,107 snapshots.
- `kras-network-smoke-EZS8Qo`: both tournament configurations passed. The
  2-human tournament ran three regular rounds and three contender-only tie
  rounds, finishing with points `[10,10,7,9]` and champion slot 0. The 4-human
  tournament completed three rounds with `[4,9,15,5]` and champion slot 2.
  Guest state and tournament accounting matched; reconnect and interrupted
  host result delivery were exercised. Guests received 1,665-3,279 snapshots.
- Maximum measured local server event-loop delay was 57 ms in ordinary
  matches and 101 ms in the tournament. This is diagnostic data, not a network
  latency, mobile frame-rate or competitive fairness certification.
- Scripted input remembers only displayed cues; it does not read
  `expected_pad()` or the private sequence. These are desktop headless engine
  instances, not four physical devices. Production remains disabled.
- Final integration gate `kras-party-check.W35Gbc`: 257 scripts compiled,
  294 resources audited with zero issues, 17,793 assertions passed, race
  regression passed and 39 stability matches completed with zero failures.

The existing local match runtime remains authoritative on the host device.
The Node service authenticates **connection ownership**, not Apple accounts,
and controls room membership, readiness, loading barriers, slot assignment,
match epochs and access to snapshot/result publication. Guests cannot publish
another player's input or a result. The host is trusted: this is not a dedicated
anti-cheat simulation and is not suitable for ranked rewards.

Public discovery and six-character private codes use real WebSockets at
`/multiplayer`. Up to four people can join; empty places can be filled by host
AI. The lobby has character selection, readiness, host kick, arena, difficulty
and 1-10 rounds. Local input remains keyboard, gamepad or touch.

The development allowlist contains twenty-eight explicitly adapted rulesets; verification
limits for each are recorded below. These include `ring_rumble` on `vortex_ring`
/ `storm_ring`, without machine drops, random power-ups or bombs, and
`goal_guard` on `quad_court`. Offline Ring Rumble is unchanged. Goal Guard
replicates normal/heavy balls, launch generations and keeper charges; the guest
does not tick ball physics or evaluate goals. `gem_grab` uses `gem_hollow` /
`glass_terrace`, and `star_rush` uses `star_meadow`. Both share the bounded,
stable-ID collectible presenter; carried star counts come from the host too.
`zone_hold` on `dune_ring` replicates capture position, radius and ring color;
only the host advances capture progress or awards points.
`relic_hold` presents the loose relic or its carrier exclusively; pickup,
drop and held-time scoring remain host-only. Its configured arenas are
`star_meadow` and `gem_hollow`; see the verification limits below.
`tag_hunt` on `star_meadow` / `paint_grid` replicates the hunter and handover
grace; guests do not perform contact detection or free-time scoring.
`paint_grid` and `mnatiq` replicate all 169 tile owners on `paint_grid`;
capture, enclosed-region rewards and recounting remain host-only.
`mukharrib` adds the drone, warnings and sequenced scrub feedback on `paint_grid`.
`magnet_court` on `quad_court` adds charge, active timers and held-ball ownership
by ball slot, never by engine instance ID. Guests do not simulate attraction,
release, recharge or goals.
`storm_heart` on the same court adds turbine rotation, windup and volley timers,
two additional ball slots, and sequenced warning/volley feedback.
`sky_court` adds the selected engine, bank amount, warning/tilt timers and
sequenced feedback. Guests present the tilted surface without applying forces.
`crumble_court` replicates all 113 authored tiles: phase, warning/fall/respawn
timer, local height and monotonic collapse count. Guests never advance floor
physics or emit gameplay collapse signals; sound events are freshness-gated.
`blast_ball` on `ember_pit` replicates the explosive ball, fuse, launch identity
and sequenced explosion feedback. Elimination and rearming stay on the host.
`color_stand` on `color_floor` adds the 121-tile palette, called color, floor
states, phase timers and call/drop cues. Guests never choose a new color.
`quick_draw` on `draw_stage` adds visible prompt state and accepted responses,
without exposing the hidden wait countdown. Reaction latency is not compensated;
the local scripted test exhibits host advantage and is not a balance approval.
`symbol_echo` on `echo_hall` presents visible memory cues and authoritative
progress without running a second scoring simulation on guests.
`crate_smash` and `lab_crates` on `crate_yard` replicate crate fields, lab
volleys and break feedback; only the host handles attacks, weapons and scores.
Optional random power-ups remain disabled in online beta configurations.
The other 19 games are not
online-enabled. The room service supports points/cups tournaments for
these supported arenas, with stable rosters, readiness between matches, seeded
no-repeat rotation, and server-owned cumulative accounting. Only the host can
advance the tournament. The configured points table is validated server-side.

Final ties run short contender-only matches. Other players retain their slots
as spectators. At most three tie-breaks are allowed; persistent ties produce
shared champions, not an arbitrary slot-based winner. Cup tournaments also
have a bounded regular-round limit. These are limited beta tournaments, not
39-game online tournaments.

Clients render host snapshots at 20 Hz with smoothing; they send input at
30 Hz. The host simulates at the engine physics frequency. Remote clients do
not evaluate scores, winners, collisions or timers. Snapshots include fighter
pose/velocity/status, shrinking radius, phase, round, countdown and scores.
Results travel once through the server after host completion. Online results
do not grant local progression or create misleading input-only replays.

## Recovery and bounded resources

- A cryptographically random bearer resume token is sent only to its owner.
  It is kept in memory, never logged, included in room discovery, or saved.
- The reconnect grace is 30 seconds. Slot/character/score identity survives a
  transport reconnect in the same running app. Stale inputs become neutral
  after 250 ms; this beta does not silently replace disconnected people by AI.
- A still-active old connection returns `session_active`; the client retries
  while the server heartbeat detects the dead connection.
- No host migration. A host loss pauses authoritative updates; expiry closes
  the room without fabricating a winner. Guest expiry during a match also
  aborts this beta rather than changing roster/scoring under the players.
- Loading has a 60-second timeout. Missing host snapshots have a 30-second
  watchdog. Idle rooms expire after 30 minutes.
- Limits: 200 rooms, 800 connections, 16 connections per socket IP, 64 KiB
  packets, 48 KiB snapshots, 90 messages/s, 12 control messages/s, 256 KiB
  outbound backlog. No compression and no arbitrary Godot object decoding.
- Browser Origins are denied unless explicitly allowlisted. Native clients
  omit Origin. Production clients require WSS; WS is loopback-only.

## Local verification

```sh
cd server
npm ci --ignore-scripts
npm test
node network-smoke.js
node network-smoke.js --tournament
cd ..
sh tools/check_party.sh
```

`network-smoke.js` starts an ephemeral loopback service and real isolated Godot
processes: two humans plus two bots, then four humans. Each runs two shortened
rounds, disconnects/reconnects one client, checks host receipt of remote input,
snapshot reception and identical results. It prints its evidence directory.
The tournament option also exercises repeated scene cleanup/loading, arena
rotation, next-round readiness and identical final standings on all peers.
This is a networking smoke test, not proof of Internet latency, phone thermal
behavior, game balance or visual/audio parity.

## Railway deployment gate

The account service and SQLite storage are preserved. Multiplayer is **off by
default**. Do not enable production just because the loopback tests pass.

1. Deploy the reviewed feature commit to a separate Railway staging service
   using the existing Dockerfile. Preserve account variables and `/data` volume
   if sharing an account-service instance. Never copy secrets into Git.
2. Set `MULTIPLAYER_ENABLED=true`. For native clients no Origin list is needed;
   set `MULTIPLAYER_ORIGINS` only to exact trusted browser origins if web export
   is used. Configure one replica: rooms live in process memory, not SQLite.
3. Verify `/health` and WebSocket upgrade to `wss://<staging-domain>/multiplayer`.
4. Run the client with `KRAS_MULTIPLAYER_URL` for desktop QA, or set the Godot
   project setting `kras/online/endpoint` in a staging export. The default
   shipping project has no enabled endpoint.
5. Test four physical devices, Wi-Fi/cellular transitions, backgrounding,
   high latency, packet loss, portrait/landscape and long sessions.
6. Only then enable a production endpoint in a reviewed build. Shutdown/redeploy
   closes active rooms explicitly; it cannot resume a simulation after a server
   or host process restart. Rollback: disable the endpoint/feature flag; local
   gameplay and Apple authentication remain available.

No Railway deployment, App Store upload, or review submission is implied by
these changes. Use actual deployment evidence to update that status.

## Verification record (2026-09-30)

- Node account + room tests: 11 passing, including four real WebSocket clients,
  malformed/unauthorized packets, reconnect identity, load timeout and host
  snapshot watchdog. Dependency install audit reported no vulnerabilities.
- Godot network unit suite: 17 assertions passed (snapshot validation, slot
  ownership, stale-input expiry and session cleanup).
- Final compile check: all 222 GDScript files compiled successfully; evidence
  `/tmp/kras-network-final-compile.log`. This does not replace runtime tests.
- An initial real-engine run passed two-human/two-bot and four-human sessions,
  two rounds each, with identical results and a guest reconnect:
  `/tmp`/macOS temporary directory `kras-network-smoke-A72oxL`.
- Subsequent runs were not reliably repeatable: connection expiry and process
  timeouts occurred while multiple Godot engines were running. The client now
  logs close codes, and the server heartbeat respects the scene-loading budget.
  One later run (`kras-network-smoke-swdSvl`) timed out before the two-player
  room started. These load-sensitive failures are retained as QA evidence.
- The final isolated run on the current code (`kras-network-smoke-JRi1Of`)
  passed both two-human/two-bot and four-human sessions. Every human moved,
  results matched across devices, and peer 2 reconnected in both sessions.
  Guests received 648-668 snapshots. This is loopback verification, not a
  guarantee under network loss, device suspension or heavy resource pressure.
- The full local regression run `kras-party-check.JYuHn9` passed compilation
  and content inventory but was stopped after prolonged integration execution;
  it has **no final passing result**. Re-run on an unloaded test host.
- A subsequent standalone lifecycle run completed **39 matches, 0 failures**
  with four AI players, shortened timed rounds and normal race laps. It checks
  result validity, cleanup, retained objects, input and global signal ownership.
  Evidence: `/tmp/kras-network-final-stability.log` and
  `/tmp/kras-network-final-stability-save/stability.json`. One cycle does not
  establish long-session memory stability or physical-device performance.
- Arabic lobby fixture screenshots were inspected in landscape and portrait;
  these are presentation fixtures, not evidence of device/network performance.

The follow-up below completes full local regression and adds multi-engine
checks. The release gate still requires staging deployment and physical-device
and Internet QA. General 39-game
online support and networked tournament rotation are still future work.

## Release preparation follow-up (2026-10-02 session)

Work is isolated on `feature/kras-online-release`, based on main commit
`9135a741c474371c347db7a1c6759efc2f39d28e`. Untracked duplicate files ending in
` 2` in the original checkout were not deleted or included.

Implemented and regression-tested:

- Reuse vacant lobby slots without assigning two participants the same slot.
- Clear old results on lobby return; do not replay them on lobby reconnect.
- Give a disconnected host the full reconnect grace independently of its last
  snapshot's age, while retaining the connected-host authority watchdog.
- Apply a result once per match epoch; clear remote input at match boundaries.
- Retain a pending host result in memory until acknowledged, and retry only
  after the server confirms that the same epoch is still playing.
- Track generated Godot script UIDs. Ignore release screenshots/source artwork
  and generated iOS resources during Godot import without removing those files.

Verification:

- Node: 14 passing tests. The three new server regressions failed before the
  repair and passed afterwards. Dependency audit: zero reported vulnerabilities.
- Full `tools/check_party.sh` passed on the slot/reconnect/idempotency changes:
  222 scripts compile, inventory has zero issues, 12,423 assertions pass,
  independent race regression passes, 39 lifecycle matches have zero failures.
  Evidence: `kras-party-check.55Plas` under the host temporary directory.
- Real two- and four-human Godot sessions passed with movement, equal results
  and guest reconnect: `kras-network-smoke-NCgcT9`.
- The subsequent pending-result delivery change passed the focused network
  suite (27 assertions) and another 222-script compile check. Logs:
  `/tmp/kras-reconnect-tests.log`, `/tmp/kras-resume-final-compile.log`.
- A second real-engine run deliberately dropped the host's first result packet
  by closing its transport. Both two- and four-human sessions completed with
  identical results, host reconnect and guest reconnect. Evidence:
  `kras-network-smoke-f35E6w`. This verifies the pending-result delivery path.
- The native bridge build script now honors DEVELOPER_DIR and rejects a tools
  directory without the full Xcode toolchain. Shell syntax was checked; this
  is preparation only, not an archive or a native bridge build result.
- Sandboxed Godot emitted a macOS CA lookup warning; initial editor import also
  could not save global editor preferences. These are not successful device
  signing or network-authentication tests.

Live read-only release checks:

- Apple app 6801506973 is `com.shary.kraspass`; version 1.1.10 is READY_FOR_SALE.
  Build 107 is the most recently uploaded entry returned, while build 108 also
  already exists. Do not reuse either number or infer archive source from them.
- Existing distribution identity for team 4HM66AD594 is accessible in Keychain.
  Xcode 27.0 (27A266a) and a connected physical iPhone were detected. No P12 was
  imported and no certificate was changed.
- Railway source is shary17454/kras-pass, production/main, but its observed
  successful deployment is still c61005fd33e3821323379b56d9cfedd4a7407ce0.
  Required Apple variables are present, client/team match, SQLite uses /data,
  health is OK, and unauthenticated /account returns 401. Multiplayer is off.
  The last-24-hours error-log query returned no error entries. These checks do
  not prove a signed-device login, database migration, or a new deployment.

No new Apple archive/upload/submission or Railway deploy is established by
this follow-up. The 38 remaining online adapters,
Internet/device QA and the production feature-enable gate remain outstanding.

## Tournament follow-up verification

- Server tests: 21 passed, including cup targets, shared ties, contender-only
  scoring, reconnect standings, invalid configuration and duplicate results.
- Focused Godot network tests: 36 assertions passed. Contender IDs are tested
  through JSON decoding, not only integer-valued local fixtures.
- Actual Godot tournaments passed with two humans plus two bots and with four
  humans: six matches each (three regular plus three tied finals), matching
  standings on every peer, movement every active round, and both host-result
  loss and guest reconnect. Evidence: `kras-network-smoke-GycbbH` under the
  macOS temporary directory. Initial failed runs exposed late input/snapshot
  publication and JSON numeric-type contender matching; those were fixed.
- The successful tournament run still logged duplicate `leave/not_joined`
  during simultaneous cleanup. Leave is now idempotent; server regression
  tests cover that final adjustment. This did not change tournament scoring.
- Renderer QA captured lobby and final standings in portrait and landscape.
  It caught a nested-scroll collapse hiding the portrait round table. The
  inner scroll is removed, and the fixture now checks four visible-sized rows.
  Log: `/tmp/kras-tournament-ui-final.log`; screenshots:
  `/tmp/kras-online-results-1080x1920.png` and
  `/tmp/kras-online-results-1920x1080.png` (plus lobby equivalents).
- These tests use loopback on macOS, not Internet matchmaking or an iPhone.
  No claim of 39 online-ready games, phone performance, or release readiness
  follows from them. No production enablement or Apple submission was made.
- Full regression attempt `kras-party-check.0CNKEb`: compile (222 scripts)
  and inventory passed, but the integration suite became abnormally slow and
  was stopped after more than 25 minutes without recent log progress. It is
  **incomplete, not passed**. No assertion failure had been reported before
  termination; that does not establish correctness. The process sample is
  `/tmp/kras-party-stall.sample` (about 886 MB footprint, stripped native
  symbols, insufficient to identify a root cause). TestHarness now prints
  each test start to make the next isolated reproduction attributable.
- The separate stability run completed all 39 default-arena matches with zero
  failures after that interrupted full-suite attempt. Evidence:
  `/tmp/kras-tournament-stability.log` and
  `/tmp/kras-tournament-stability-save/stability.json`. This is one cycle with
  four AI and shortened timed rounds, not comprehensive multiplayer/device QA
  or a long-duration memory-leak certification.
- Final ordinary-match compatibility retests did **not** pass:
  `kras-network-smoke-bWHju8` closed on authority timeout, and
  `kras-network-smoke-p4gbw1` expired the session during transport recovery.
  Neither run reached a completed result. They coincided with unusually slow
  local command execution, but the cause is not established. Do not dismiss
  them as environmental or widen watchdogs to turn the test green. Reproduce
  with host tick/transport timing on a responsive machine before merging or
  releasing. Earlier successful tournament results do not override this gate.

## Timing diagnosis follow-up

The next ordinary-match run, `kras-network-smoke-X5hkJc`, passed both two-human
and four-human sessions, including guest reconnect and lost host result
recovery. Scores matched on all peers. No production timeout was increased.
The new diagnostics measured a maximum server event-loop delay of 11,778 ms;
initial host scene loading also caused a roughly 10-second frame gap. This is
evidence of scheduling/load sensitivity, not proof that the prior failures
were exclusively environmental. Retain the failed-run evidence and require
repeatable CI and device testing before clearing the release gate.

The smoke harness now records bounded timing/state diagnostics without resume
tokens or credentials. Godot logs report epoch, phase, maximum frame gap and
snapshot count; the server reports loading/result transitions and event-loop
delay. This distinguishes a paused host from a stalled service in future runs.

## CI verification on 2026-10-02

GitHub Actions run [36954750408](https://github.com/shary17454/kras-pass/actions/runs/36954750408)
completed successfully for source `a5aad59d1f270a41d0eb722d78a30e676ef0ff28`:

- Ordinary real-engine sessions passed with two humans plus bots and four humans.
- Tournament sessions passed six matches per configuration, including reconnect,
  lost-result recovery, tied standings and bounded sudden-death rounds.
- The full Godot suite passed 12,438 assertions.
- Three stability cycles completed 117 matches with zero failures.
- Wrapper checks passed their success path and ten injected failure cases.

This clears the repeatable Linux CI check for that exact source, not native
iPhone performance or all-game online compatibility. It does not cover subsequent
monotonic-clock or snapshot-validation changes until those are tested separately.
The earlier failed local runs remain diagnostic evidence above.

The follow-up monotonic-deadline change passed all 22 server tests. Client
snapshot bounds passed 52 focused assertions using
`/tmp/kras-snapshot-validation-final.log`, including malformed scalar values,
unsupported roster sizes, last-valid-state preservation, and JSON numeric
round trips. macOS sandbox CA-certificate lookup reported its environment error;
the focused suite itself exited zero. Follow-up CI run
[36956121783](https://github.com/shary17454/kras-pass/actions/runs/36956121783)
passed for `e17f5eec4f59095cf1ded01e3227f6fcbd54be8d`: 12,454 assertions and
117 stability matches with zero failures, plus the real-network scenarios.
That run predates the Goal Guard adapter below.

## Goal Guard adapter verification

- `/tmp/kras-goal-replica-final2.log`: 120 focused assertions passed, including
  JSON validation, normal/heavy appearance, launch teleportation, round reset,
  spectator scores, and no guest ball simulation or scoring.
- `/tmp/kras-goal-compile.log`: all 223 scripts compiled.
- Server tests: 25 passed, including game-specific world validation and a
  tournament whose current game differs from the lobby default.
- `kras-network-smoke-65T0fU`: ordinary two-human/bot and four-human matches
  passed, with reconnect and lost host-result recovery. This used short rounds.
- `kras-network-smoke-OHeS55`: three-match tournaments passed for both player
  configurations using 15-second rounds. Each guest received more than 1,600
  world snapshots; ball presentation and final scores/standings agreed.
  Neither random tournament required a tie-break; spectator scoring is covered
  by the focused fixture, not claimed as a real-network tie-break result.
- `/tmp/kras-goal-online-ui.log`: rendered Arabic lobby/results fixtures passed
  at 1080x1920 and 1920x1080. Captures were visually inspected. These are desktop
  fixtures, not iPhone performance tests.

The CI workflow now repeats both ordinary and tournament Goal Guard scenarios.
Production deployment, real-device latency/audio QA and the remaining world
adapters are still outstanding. Guest collision/goal sound events are not yet
replicated; phase/countdown cues are shared by the existing match adapter.

## Collection adapters and resource cleanup verification

Gem Grab and Star Rush now share a visual-only collectible replica. The host
owns pickup, deposit and scoring; guests reconcile bounded stable item IDs and
carried-item counts. Unknown kinds, duplicate IDs, non-finite transforms and
oversized payloads are rejected before updating visible state.

- `/tmp/kras-collection-replica-limit.log`: 64 assertions passed, including
  worst-case snapshot size, JSON round trips, pool reuse and no guest physics.
- Server tests: 27 passed.
- `kras-network-smoke-YGtgxV`: Gem Grab three-match tournaments passed with
  two humans/two bots and four humans, reconnect and lost-result recovery.
- `kras-network-smoke-YmbjnX`: the same Star Rush configurations passed;
  every peer observed carrying and positive collection scores. Neither run
  needed a tie-break. These are localhost tests, not production latency tests.
- `/tmp/kras-collection-online-ui-clean.log`: portrait and landscape Arabic
  lobby fixtures rendered and were visually inspected. Audio shutdown now
  stops voices/tweens and releases cached streams; no exit leak was reported.
- `/tmp/kras-audio-shutdown-clean.log`: 248 system assertions passed without
  leak warnings after draining the isolated power-up fixture pool.
- The preceding source `c49505b57c325facd4eed9b897e207e8f26520de` passed
  [CI 36957648373](https://github.com/shary17454/kras-pass/actions/runs/36957648373).
  This is not evidence for the later collection changes. The new CI matrix
  separately checks core quality and each of the four online adapters.

Production remains disabled. Other minigames still need world adapters, and
guest pickup/deposit sound events and physical-device QA remain outstanding.
No iOS archive, upload or App Review submission is represented by these tests.

## Local capture-zone lifecycle regression

Zone Hold now scales its visible capture marker when sudden death shrinks the
scoring radius, and restores both at round start. Fractional capture points are
cleared between rounds. Unchanged ownership no longer reassigns the cached ring
material every tick. `/tmp/kras-zone-hold.log` passed 15 assertions covering
contested scoring, visual/rule agreement and repeatable round reset. That
lifecycle fix preceded the network adapter below. `/tmp/kras-zone-replay.log` also
passed 71 replay assertions, including an actual Zone Hold recording/playback
with matching scores and placements.

## Capture-zone network verification

- `/tmp/kras-zone-network-unit.log`: 35 assertions passed, including visual
  radius/ownership updates, invalid snapshot rejection and no guest scoring.
- `/tmp/kras-zone-network-compile.log`: 227 scripts compiled after fixing an
  inferred-type error in the new network test's steering fixture. The first
  network attempt (`kras-network-smoke-duYKIf`) failed before starting a match
  and is not counted as passing evidence.
- Server tests: 29 passed, including authoritative capture-world validation.
- `kras-network-smoke-wLRJs3`: ordinary two-round matches passed for two
  humans/two bots and four humans, including guest reconnect and lost-host-result
  recovery. Scores agreed: `[9,0,0,3]` and `[17,0,0,0]` respectively. Guests
  received over 1,000 world snapshots and checked capture presentation against
  authority. Steering is deliberately arranged to exercise capture scoring,
  not a character or spawn balance benchmark.
- `kras-network-smoke-paEdK1`: three-match Zone Hold tournaments passed for
  two humans/two bots and four humans. All peers agreed on the final points
  `[12,6,9,6]` and `[15,6,6,6]`, with champion slot 0. Guests received more
  than 1,600 world snapshots. Neither tournament required a tie-break. Late
  in-flight input after room closure was rejected as `not_joined`; no results
  were changed. These runs are not physical-device performance evidence.
- CI now includes ordinary and tournament Zone Hold scenarios. Device rendering
  and production-network QA remain unverified for this adapter.

## Completed collection CI baseline

[CI 36959389790](https://github.com/shary17454/kras-pass/actions/runs/36959389790)
completed successfully for `ba4d218dfe86962ee26d68bdbf7e2ba746824275`: all five
jobs passed, including ordinary/tournament networking for the four adapters at
that commit. Core quality recorded 225 scripts, 12,570 assertions and 117
stability matches with zero failures. This baseline predates the Zone Hold
adapter and subsequent Relic Hold lifecycle fix; those need their own CI run.

## Relic Hold round reset

The previous relic carrier now regains the game's configured attack permission
when a round starts or the controller cleans up. Carrying and fractional score
are cleared; repeated callbacks do not duplicate the relic. Dropping also uses
the declared attack permission rather than forcing attacks on unconditionally.
`/tmp/kras-relic-round-reset.log` passed 15 assertions without resource-leak
warnings. That lifecycle fix preceded the network adapter below.

## Relic Hold network verification

- `/tmp/kras-relic-replica-unit.log`: 45 assertions passed for loose/held state,
  malformed ownership, drop, respawn delay, no guest colliders/scoring, and
  stable visual reuse.
- `/tmp/kras-relic-replica-compile.log`: 229 scripts compiled.
- Server tests: 31 passed after integrating room-level relic validation.
  Four world-validator tests also passed after rejecting fractional roster sizes.
- `kras-network-smoke-m0vrgW`: two-round matches on `star_meadow` passed with
  two humans/two bots and four humans, including reconnect and dropped-result
  recovery. All peers agreed on `[28,0,0,4]` and `[34,0,0,0]`; guests received
  over 1,000 snapshots and checked holder, carrying and loose-item presentation.
- `/tmp/kras-relic-visual.log`: 49 graphical assertions passed, with no leak
  warnings. `/tmp/kras-relic-carrier.png` was visually inspected: the marker
  follows the carrier and the HUD identifies it. This was desktop OpenGL
  compatibility rendering, not physical iPhone or iPad QA.
- `kras-network-smoke-FAZK7M`: three-match relic tournaments passed for two
  humans/two bots and four humans, using both `gem_hollow` and `star_meadow`.
  Final points agreed across peers: `[12,6,7,10]` (champion 0) and `[9,6,12,6]`
  (champion 2). Guests received more than 1,600 snapshots. No tie-break occurred.
  The local server measured a maximum event-loop delay of 14,554 ms during this
  run. This is a functional pass, not latency/performance acceptance; the stall
  cause and physical-device performance remain unresolved.
- The new CI scenario covers ordinary matches and tournaments. Mobile rendering
  and production latency remain unverified. Production online remains disabled.

## Tag Hunt adapter and room integration

The shared replica can now present the hunter role and handover grace without
contact detection or scoring. Repeated snapshots cannot compound the role's
speed bonus, and clearing the role restores the original speed and marker.
`/tmp/kras-tag-replica-unit.log` passed 26 assertions; all five server world-state
validator tests also passed before room integration.

- Room-level validation now requires a valid hunter world. Server tests: 33
  passed. `/tmp/kras-tag-room-compile.log`: 231 scripts compiled.
- `kras-network-smoke-LfHts1`: two-round matches passed for two humans/two bots
  and four humans on `star_meadow`, with reconnect and dropped-result recovery.
  All peers observed an in-round hunter handover and agreed on `[36,36,10,16]`
  and `[34,38,10,13]`. Guests checked the hunter and grace against the latest
  authoritative snapshot and received over 1,000 world snapshots. This is not
  a balance benchmark; the fixture deliberately brings players together.
- `/tmp/kras-tag-visual.log`: 30 graphical assertions passed without leak
  warnings. `/tmp/kras-tag-hunter.png` was visually inspected for the marker
  and hunter HUD. This is desktop OpenGL compatibility rendering, not iOS QA.
- The CI matrix includes ordinary and tournament Tag Hunt scenarios. Its
  tournament, second arena and physical-device/network performance still need
  verification. Production online remains disabled.

## Completed five-adapter CI baseline

[CI 36960797391](https://github.com/shary17454/kras-pass/actions/runs/36960797391)
passed all six jobs for `63b10c626bfc3a832d07fa7a9db3804173bb9e74`, including
Zone Hold ordinary matches and tournaments. Core quality recorded 228 scripts,
12,618 assertions and 117 stability matches with zero failures. That source
predates the relic/tag network adapters; their results must be tracked separately.

## Paint-family reset and prepared ownership adapter

`ArenaTile.claim()` now changes the visible owner material without overwriting
the neutral floor color. This fixes old player colors remaining after a round
reset or Mukharrib scrub. `/tmp/kras-paint-reset.log` passed 34 assertions across
Paint Grid, Mnatiq and Mukharrib, including score reset and scrub visuals.

The prepared shared adapter for `paint_grid` and `mnatiq` sends 169 ownership
slots indexed by the authored tile coordinates. It does not send arbitrary
materials or run guest capture/recount logic. Tests check every coordinate
against the fixed protocol layout, so an arena size change requires an explicit
adapter update. `/tmp/kras-paint-replica-final.log` passed 722 assertions. All
six server world-validator tests passed. Development room routing now includes
both games; this does not enable production online play. Mukharrib
also needs its drone and warning-state adapter; tile ownership alone is not
sufficient to enable that game online.

- `/tmp/kras-paint-room-compile.log`: all 234 scripts compile.
- Server suite: 35 tests passed, including both paint rulesets rejecting missing,
  undersized, oversized, fractional and out-of-roster ownership updates.
- `kras-network-smoke-dEbU8k`: Paint Grid two-human/two-bot and four-human
  matches passed, including transport recovery, tile-owner comparison and final
  score agreement. Guests received 1087-1107 world snapshots. The test logged
  late `not_joined` input rejections after room closure, not during gameplay.
  Its server event-loop maximum was 3173 ms and initial loading frame gaps were
  about 36 seconds. This is functional evidence, not performance acceptance.
- `kras-network-smoke-PbVgDu`: Mnatiq two-human/two-bot and four-human matches
  passed with ownership, reconnect and score agreement. Guests received
  1087-1107 snapshots; server event-loop maximum was 2322 ms. This is also
  functional evidence only; the post-close input rejections occurred again.
- `/tmp/kras-paint-visual-final.log`: 726 assertions passed with the desktop
  compatibility renderer. Both `/tmp/kras-paint-guest-paint_grid.png` and
  `/tmp/kras-paint-guest-mnatiq.png` were inspected at 1280x720: roster colors
  reach the tile materials. These synthetic ownership fixtures are not complete
  gameplay, portrait-layout or iPhone QA. The first capture attempt failed on
  a test variable's inferred type; an explicit String fixed it before this run.
- `kras-network-smoke-e6T2ZW`: Paint Grid three-match tournaments passed with
  two humans/two bots and four humans. Identity, tile ownership and final
  standings agreed after reconnect; guests received 1661-1684 snapshots.
  A tied ordinary round shared awards correctly, but neither final standing
  required a sudden-death match. Server event-loop maximum was 1784 ms.
- `kras-network-smoke-g3Xzyy`: Mnatiq three-match tournaments passed with two
  humans/two bots and four humans. Final points/cups/champions agreed across all
  peers after reconnect; guests received 1664-1684 snapshots. Neither final
  required sudden death. Server event-loop maximum was 1835 ms; device latency
  and performance acceptance remain outstanding.

## Saboteur world adapter and event replay protection

`saboteur_replica.gd` combines fixed-grid ownership with bounded drone position,
rotor angle, target tile and warning/cycle timers. The guest renders the host's
warning cells without running target choice, scrub, damage or point logic.
Repeated snapshots reuse warning meshes; clearing/changing targets removes the
old warning. Both development room allowlists now include this game; production
online play remains disabled.

- `/tmp/kras-saboteur-unit.log`: 211 assertions passed, covering JSON capture,
  malformed/missing fields, last-valid-state retention, warning cells at centre
  and corner, no guest timer advancement or scrub, and host-driven clear/reset.
- All seven server world-validator tests passed.
- `/tmp/kras-saboteur-compile.log`: all 236 scripts compiled.
- `/tmp/kras-saboteur-visual-clean.log`: 212 graphical assertions passed.
  `/tmp/kras-saboteur-warning.png` was inspected: the drone and nine white
  warning tiles render above host-owned colors. This is a desktop fixture,
  not a device performance or full-layout acceptance test.
- The first graphical run leaked an AudioStreamWAV and its playback while
  quitting during a music fade. The shared test runner now explicitly shuts
  audio down and waits two frames before exit; the rerun has no leak warning.
- Import generated the new script UIDs. The sandbox reported inability to save
  the user's editor settings and read system CA certificates; these are not
  treated as product errors or proof of successful release building.
- Host warning/scrub sequences now survive round changes. Guest presentation
  consumes each new event once, and suppresses historical effects on first
  snapshot, round change or after a snapshot gap longer than one second.
  The controller exposes visual/audio scrub feedback separately from damage,
  tile ownership and scoring; guest feedback never applies those rules.
- `/tmp/kras-saboteur-events-unit.log`: 236 assertions passed, including repeated
  snapshots, reconnect gaps, first snapshots and monotonic host event capture.
- `/tmp/kras-saboteur-events-visual.log`: 240 assertions passed with actual
  pooled sound triggers and no leak warning. The capture is a test fixture.
- `/tmp/kras-saboteur-room-compile.log`: all 236 scripts compile; 36 server tests
  passed, including room rejection of ownership-only Saboteur packets.
- `kras-network-smoke-kVJ1mS`: ordinary Saboteur matches passed with two
  humans/two bots and four humans. The fixture requires an observed warning and
  scrub, compares drone/target/tile presentation against the final host snapshot,
  and verifies reconnect and identical scores. Guests received 1088-1107 world
  snapshots. Server event-loop maximum was 51 ms in this run, not an iOS FPS or
  network-latency certification.
- Saboteur's tournament run and device QA remain required; the CI matrix now
  includes ordinary/tournament scenarios for all ten development rulesets.

## Completed seven-game CI baseline

GitHub Actions run `36962406988`, source
`ea0653a1de827d1ef8e07c52b094ceaf187c0197`, completed all eight matrix jobs
successfully. Its core job `110698736499` compiled 231 scripts, passed 12,673
assertions, and completed 117 stability matches with zero failures. The other
jobs cover ordinary/tournament networking for the seven rulesets through Tag
Hunt. This is not evidence for the later paint or Saboteur commits or a release.

The newer run `36965027879`, source
`b80576dc01db01c380ddb3a105434d342eba6e7b`, has a successful core job
`110706801891`: 236 scripts, 13,662 assertions, and 117 stability matches with
zero failures. All eleven jobs completed successfully.
This core result covers paint and Saboteur, but predates the Magnet changes.
The matrix includes all ten rulesets' ordinary and tournament network checks.
A new run `36967949347`
uses source `94a5222dc333e0343f2582515fda27b9d8c5e12f` and includes Magnet and
Storm; it was verified queued, not completed. Neither run covers Sky changes.

## Magnet Court adapter and capture physics

The shared Goal Guard ball presenter is extended with bounded per-player magnet
meters and one owner per ball slot. Both room admission and guest validation
require the complete ball and magnet state. Reset/release reconstruct ownership
using guest-local ball IDs, without transferring engine identities.

Local gameplay also needed correction: the ordinary shield intercepted frontal
shots before magnet capture, and ball tick normalization restored speed while
the ball was held. The overridable shared ball-tick hook now catches swept paths
before shield interception and parks captured balls until release. Elimination
releases held balls and disables the magnet. Tests cover 30/60/120 Hz steps;
these are simulation tests, not measured device frame rates.

Magnet Court uses keeper controls instead of an unused second aiming stick.
Its dash and ability hit regions are tested at portrait and landscape sizes.

- `/tmp/kras-magnet-physics-release.log`: 175 assertions passed before the
  additional control-layout checks; Goal Guard regression passed 120 assertions
  in `/tmp/kras-magnet-goal-regression.log`.
- `/tmp/kras-magnet-visual-drawn.log`: 191 assertions passed, including capture
  to `/tmp/kras-magnet-held.png`. Earlier graphical fixtures produced six GL
  texture warnings on exit. Clearing the shared texture cache did not fix them
  and was reverted. Waiting for a rendered frame before disposing each fixture
  removed those warnings in the rerun. This is not a long-session memory test.
- `/tmp/kras-magnet-room-compile.log`: 238 scripts compiled. All 38 Node tests
  passed with loopback access; the sandbox-only attempt failed specifically
  with `listen EPERM` and is not counted as a successful integration run.
- Final compilation passed all 238 scripts in
  `/tmp/kras-magnet-final-compile-local.log`. The full local suite passed 13,779
  assertions in `/tmp/kras-magnet-full-tests.log`, with isolated save data.
  The quality wrapper now rejects GL texture-leak messages even on exit code
  zero; `tests/check_party_wrapper.sh` passed its success path and eleven
  failure cases (`kras-wrapper-test.TU6gfe`).
- `kras-network-smoke-wwrRq4`: ordinary matches passed with two humans/two bots
  and four humans, observed actual capture, verified reconnect/results and
  compared held-ball ownership and meters on guests. Guests received 1088-1107
  snapshots. The maximum server event-loop delay was 55 ms in that run, not an
  iPhone or Internet performance certification.
- `kras-network-smoke-LwbxqJ`: three-match points tournaments passed for both
  two humans/two bots and four humans. All peers agreed on standings and the
  champion after host/guest reconnect. Final points were `[9,13,6,6]` and
  `[7,10,9,9]`; no final sudden death was needed in these runs. Guests received
  1665-1684 snapshots, and the server event-loop maximum was 40 ms.
- Device QA and guest ability sound-event parity remain pending. Production
  online play is still disabled.

## Storm Heart turbine replication

The turbine presenter extends the shared ball state with bounded rotation,
warning/volley timers and monotonic event counters. Only this ruleset accepts
up to two extra balls beyond the player count; ordinary Goal Guard and Magnet
retain their original limits. The host still creates and launches all balls.
Guest effects cannot score, launch or spawn anything. Repeated snapshots,
first snapshots, round changes and reconnect gaps cannot replay old sounds.
The controller separates presentation from authoritative volley rules and
resets turbine rotation between rounds. Keeper controls remove an unused
second stick without removing attack or dash.

- `/tmp/kras-storm-unit.log`: 163 assertions passed for two-, three- and
  four-player state, bounds, extra balls, reset, events and host-only rules.
- `/tmp/kras-storm-events-final.log`: 185 graphical assertions passed, including
  pooled sounds, keeper controls and suppression across pause/resume.
  `/tmp/kras-storm-final.png` was inspected:
  the turbine, post-launch normal/heavy balls and four keepers are visible.
  This desktop fixture is not device performance or complete gameplay QA.
- `/tmp/kras-storm-import.log`: asset/class import completed;
  `/tmp/kras-storm-compile.log`: all 240 scripts compiled.
- All 40 server tests passed, including real WebSockets and room-level
  rejection of missing turbine state and excessive ball counts.
- `kras-network-smoke-x6ZN4N`: ordinary matches passed with two humans/two bots
  and four humans. All clients observed warning and volley, compared turbine
  state/balls with the host, and agreed on results after reconnect. Guests
  received 1088-1107 snapshots; the server event-loop maximum was 62 ms.
- `kras-network-smoke-lVEZ4U`: three-match points tournaments passed with two
  humans/two bots and four humans, including host/guest reconnect and identical
  final standings. Final points were `[7,4,12,11]` and `[7,13,9,5]`; neither run
  required final sudden death. Guests received 1665-1684 snapshots; the server
  event-loop maximum was 38 ms. Neither network run is an iOS performance test.
- `/tmp/kras-storm-full-tests.log`: the complete local suite passed 13,884
  assertions after these changes, including Goal Guard, Magnet, replay and
  full-length race regression cases. Device acceptance remains pending.
  The development CI matrix includes this ruleset. Production remains off.

## Sky Court lifecycle and tilted-world replication

Platform banking and engine pulses now advance with the match simulation, not
independent tweens. Pause freezes them and restart/cleanup level the arena
immediately. Slope acceleration updates retained ball speed, so the next ball
tick cannot discard it. Court markings, keeper paddles, engines and ball height
follow the tilted plane instead of clipping through the floor. Authored mesh
transforms are reused without cumulative transformation drift.

The network adapter extends the shared ball presenter with bounded bank, engine
index, warning/tilt/cycle timers and monotonic event sequences. The guest never
advances those timers or applies slope impulses. Invalid state is rejected at
both client and room boundaries; first, repeated, reconnected and next-round
snapshots cannot replay historical tilt feedback. The game now uses keeper
controls, retaining movement, attack and dash without an unused aim stick.

- `/tmp/kras-sky-surface.log`: 41 lifecycle/surface assertions passed, including
  pause, immediate reset, 30/60/120 Hz banking, retained speed and cleanup.
- `/tmp/kras-sky-network-unit.log`: 244 state/replication assertions passed.
- `/tmp/kras-sky-surface-visual.log`: 248 graphical assertions passed.
  `/tmp/kras-sky-surface.png` was inspected after correcting floor/marking
  alignment. A prior capture showed a background-triggered pause overlay; the
  fixture now resumes before capture. This is desktop QA, not device approval.
- All 42 server tests passed, including sky-specific room rejection checks.
- `/tmp/kras-sky-import.log`: import completed. `/tmp/kras-sky-compile.log`:
  all 243 scripts compiled.
- `kras-network-smoke-tY9qAU`: ordinary matches passed with two humans/two bots
  and four humans, including observed warning/banking, reconnect and matching
  results. Guests received 1088-1107 snapshots. The server event-loop maximum
  was 52 ms; this is not a device FPS or Internet-latency certification.
- A subsequent geometric regression (`/tmp/kras-sky-slope-direction-before.log`)
  failed: the visual slope rose in the force direction. The rotation axis was
  corrected and every authored direction is now covered. The initial network
  and graphical results above predate that correction; they are not final
  acceptance evidence for the corrected physics.
- Post-correction tournament `kras-network-smoke-ojwis6` passed three matches
  with two humans/two bots and four humans, including reconnect and agreed
  standings. Points were [6, 7, 9, 13] and [8, 6, 11, 9]; neither required a
  final tie-break. Guests received 1665-1684 snapshots; server loop maximum
  was 38 ms. A late input after room closure was rejected as `not_joined`.
- Portrait inspection then found the upper keeper behind the HUD. Shared
  COURT framing now fits the projected court below the measured HUD and above
  default touch areas, preserving north-up orientation. Regression projections
  cover both orientations and zero through four touch players.
- `/tmp/kras-sky-camera-tests.log`: 202 assertions passed (the unprivileged
  macOS run also logged a system-CA access warning; not an application test
  failure). `/tmp/kras-sky-camera-portrait.log` and
  `/tmp/kras-sky-camera-landscape.log`: 260 graphical assertions passed each.
  Both corresponding PNGs were inspected; all keepers are clear of the HUD.
  These are desktop fixtures, not physical-iPhone touch/performance approval.
- Final local quality gate `kras-party-check.fQzKhW` passed: 243 scripts compiled,
  280 resources/21 autoloads/27 routes/eight characters audited with zero issues,
  14,268 assertions, the real three-lap race regression, and 39 stability matches
  with zero failures. The gate also rejects runtime/leak diagnostics.
  The save suite deliberately logged a failed temporary-file write during
  `failed write stays dirty and can be retried`; that injected failure passed
  its retry/preservation assertions, rather than being an unexplained error.
- Final-source ordinary-network rerun `kras-network-smoke-gVm7OM` passed with
  two humans/two bots and four humans, including host/guest reconnect, warning
  and tilt observation and identical results. Scores were [16, 17, 20, 20]
  and [18, 12, 22, 10]; guests received 1088-1107 snapshots. Server loop
  maximum was 51 ms, not an iPhone rendering-performance measurement.
- Physical-device acceptance remains pending; production deployment is still
  disabled. CI run `36967949347` belongs to the preceding Storm Heart commit
  `94a5222dc333e0343f2582515fda27b9d8c5e12f`, not this Sky Court revision.

## Shared falling-floor lifecycle prerequisite

Before adapting Crumble Court, direct tests exposed shared ArenaTile defects:
forced collapse retained its collision layer and skipped the collapse event;
restore retained the warning mesh offset; warning shake used wall-clock time.
The same tile implementation is used by Color Stand and paint games.

Forced and timed collapse now share one idempotent state transition that
removes collision and emits the event once. Warning motion uses simulation
time, and one owned material is reused instead of filling the shared material
and texture caches with intermediate warning colors. Restore clears the offset.
Color Stand also resets its call stage, progression, timer and painted floor
at round start instead of resuming the previous round's drop phase.

- `/tmp/kras-tiles-before.log`: six failing assertions reproduced the original
  tile defects. `/tmp/kras-color-reset-before.log` additionally reproduced the
  missing Color Stand reset (97 failed assertions, many for individual tiles).
- `/tmp/kras-tiles-integration.log`: 142 assertions passed after correction,
  including real physics-ray collision removal, material identity/cache bounds,
  neutral-material isolation, warning pause, timed/forced fall, respawn and
  all Color Stand floor tiles on restart.
- Complete gate `kras-party-check.zpzb59` passed: 244 scripts compiled,
  281 resources audited with zero issues, 14,409 assertions, the real three-lap
  race regression and 39 stability matches with zero failures. These are
  desktop/headless checks, not physical-device performance certification.
- That prerequisite commit did not enable either game online. Crumble Court's
  subsequent adapter is described below; Color Stand remains offline-only.

## Crumble Court world adapter

The canonical tile ordering is checked against every authored coordinate for
two, three and four players. Both server and client reject missing tiles,
nonfinite/coerced numbers, fractional phases/event counters, out-of-bounds
heights and inconsistent solid/warning rows. Hidden tiles have a canonical
height, rather than transmitting arbitrary overshoot after a long tick.
The initial unit fixture deliberately used a two-second fall tick; its -60 m
hidden height exposed this boundary mismatch, fixed before acceptance.

- `/tmp/kras-crumble-unit-final.log`: 2509 assertions passed before the final
  online-scene fixture change. Node server tests: 44 passed.
- `kras-network-smoke-ouGSBG`: ordinary matches passed for two humans/two bots
  and four humans with real floor warning/fall, reconnect and matching results.
  Scores were [6, 10, 10, 14] and [4, 8, 12, 16]; guests received 667-700
  snapshots. Server loop maximum was 41 ms, not an iPhone FPS claim.
- Initial portrait/landscape desktop fixtures passed 2514 assertions each,
  but visibly included the hover machine. Investigation found the online
  runtime disabled ambient power-ups yet still constructed the machine,
  whose direct delivery bypassed that toggle. Previous claims above that
  machine drops were excluded were therefore too strong for those revisions.
  The shared match builder now omits the machine only in online context;
  offline behavior remains. Every real network peer now rejects a scene with
  a machine, so all adapted games exercise this invariant in subsequent CI.
- The initial ordinary-network and graphical evidence predates that runtime
  correction. The graphical fixture now uses online context with a stub
  transport rather than an offline scene.
- Post-correction tournament `kras-network-smoke-7EDCle` passed three matches
  with two humans/two bots and four humans. Both finished with [3, 6, 9, 15]
  points and no final tie-break. Guests received 1049-1075 snapshots and the
  server loop maximum was 47 ms. This scripted input test is not balance QA.
- `/tmp/kras-crumble-online-portrait-final.log` and
  `/tmp/kras-crumble-online-landscape-final.log`: 2518 assertions passed each.
  Corresponding PNGs were inspected with all four players and mixed floor
  phases visible. A prior online fixture capture had a local pause menu from
  window focus changes; the fixture now closes and checks that menu explicitly.
  These are desktop fixtures, not iPhone/iPad approval or live Internet QA.
- Final-source ordinary rerun `kras-network-smoke-qYFu7I` passed both rosters,
  including the new machine-absence invariant, warning/fall observation,
  reconnect and identical results. Scores were [4, 8, 14, 14] and
  [4, 8, 12, 16]; guests received 681-715 snapshots, server loop maximum 38 ms.
- Full local gate `kras-party-check.ItWpFi` passed: 246 scripts compiled,
  283 resources/21 autoloads/27 routes/eight characters with zero audit issues,
  16,920 assertions, the real three-lap race regression, and 39 stability
  matches with zero failures. The offline machine tests also still pass.
- Production online stays disabled; physical-device, Internet and new-source
  multi-engine checks for the other games remain release gates. The shared
  machine-absence assertion will run for every game in the next CI dispatch.
  Run `36967949347` still targets `94a5222`, before this correction.

## Blast Ball lifecycle prerequisite

Before adding its network adapter, tests exposed that a new round retained the
previous fuse, attacker credit, cooldowns, position and sudden-death fuse limit.
The shared GameBall also emitted an explosion on every subsequent tick when a
listener did not rearm it. Launch now clears a detonation latch and refreshes
the fuse label immediately; detonation emits once and returns before consulting
the previous physics overlap list after a listener has rearmed the ball.
Blast Ball round start now restores the configured fuse and launches anew.

Homing also used a fixed 12 percent blend per tick, making its strength depend
on update frequency. It now uses elapsed-time exponential response calibrated
to preserve the original 60 Hz blend.

- `/tmp/kras-blast-before.log`: nine assertions failed before the lifecycle fix.
- `/tmp/kras-blast-homing-before.log`: both 30/60 and 60/120 Hz comparisons
  failed before correcting steering response.
- `/tmp/kras-blast-lifecycle-final.log`: 15 assertions passed, including a
  rearming signal listener that must not consume old overlap contacts, renewed
  launch identity, cooldown/credit reset and heading agreement within 0.03 rad.
- This prerequisite does not enable Blast Ball online. Its authoritative ball,
  fuse, explosion presentation and multi-engine verification remain required.
- Full local gate `kras-party-check.oc9lX6`: 247 scripts compiled, 284 resources,
  21 autoloads, 27 routes and eight characters audited with zero issues;
  16,934 assertions, the real three-lap race regression and 39 stability
  matches passed with zero failures. This is not physical-device performance
  or App Store distribution evidence.
- GitHub run `36967949347` completed successfully for all 13 jobs on
  `94a5222dc333e0343f2582515fda27b9d8c5e12f`. It predates Sky Court,
  Crumble Court, the machine-creation guard and this lifecycle fix; a new
  source-pinned run is required for those changes.

## Expansion checklist per game

### Color Stand room integration

Both client/server room allowlists include `color_stand` only on `color_floor`.
Snapshots require complete `validColorWorld` data and host ownership. The
multi-engine harness verifies the called color, stage/timer, every tile's
palette tag, height/state and disabled guest collisions, plus an observed drop.
Scripted input seeks the nearest visibly called-color tile; it does not change
the host's rules, timer, palette or results.

- `npm test`: 48 tests passed, including room-level rejection of the wrong
  arena, absent call data and non-host snapshot publication.
- Ordinary run `kras-network-smoke-kvWMwO`: two-human/two-AI and four-human
  cases passed, with guest reconnect and host result-transport loss. Scores
  agreed at [16, 16, 6, 6] and [16, 16, 16, 16]. Guests received 1088-1107
  world snapshots, and the local server loop maximum was 63 ms. Scripted
  safe-tile input is a protocol test, not a balance or human-playability study.
- Tournament run `kras-network-smoke-9wJ5g6` passed six matches per case:
  three regular matches plus all three bounded tie-break attempts. Two-human
  standings [12, 12, 5, 4] ended with shared champions [0, 1]; four-human
  standings [9, 9, 9, 9] ended with shared champions [0, 1, 2, 3]. All clients
  agreed, including reconnects and spectator handling. Guests received
  3279-3298 world snapshots; local server loop maximum was 61 ms.
- Full gate `kras-party-check.REVpk0`: 250 scripts compiled, 287 resources
  audited with zero issues, 17,460 assertions passed, real three-lap race
  regression passed and 39 stability matches completed with zero failures.
- Replicated-floor orientation fixtures: `/tmp/kras-color-network-portrait.png`
  (540x960) and `/tmp/kras-color-network-landscape.png` (960x540), 441 assertions
  each. Both were visually inspected: four players, surviving yellow tiles,
  missing unsafe tiles and touch controls remain visible without overlap.
  These are static desktop snapshot fixtures, not recorded online gameplay
  or iPhone/iPad store screenshots.
- Production is not enabled by this room allowlist change; physical-device
  and Internet conditions remain unverified.

### Quick Draw room integration

Client/server development allowlists accept `quick_draw` only on `draw_stage`.
The server requires the validated draw-world payload and host ownership. The
multi-engine fixture reacts only after the visible signal, checks accepted
responses for each local participant and verifies replicated prompt, ordering
and false-start locks. It does not assert movement for this stationary game.

- `npm test`: 50 tests passed, including arena selection, missing state,
  forbidden hidden timing and non-host publication checks.
- Initial ordinary run `kras-network-smoke-e46C0x` failed on the test's array
  equality: decoded JSON slots were floats while the presenter stores ints.
  `/tmp/kras-draw-json.log` reproduced `[2, 0]` versus `[2.0, 0.0]` in isolation.
  Comparison now normalizes already-validated integer slot values, retaining
  order/count checks. No game score or state rule was weakened.
- Ordinary run `kras-network-smoke-qKIudT`: two humans/two bots and four humans
  passed, with results [18, 12, 3, 5] and [18, 8, 7, 8]. Guest reconnect and
  host result-transport loss recovered. Guests received 1087-1107 world
  snapshots; local server loop maximum was 43 ms.
- Tournament run `kras-network-smoke-NCUpwO`: both cases completed three matches
  and agreed on final points [15, 9, 4, 5] and [15, 8, 6, 5], champion slot 0.
  Guests received 1665-1684 world snapshots; loop maximum was 45 ms. Two
  in-flight inputs were rejected as `not_joined` after the four-human room
  closed; clients completed successfully. The subsequent bounded input-drain
  fix is recorded below. This run did not exercise a final tie-break.
- Full gate `kras-party-check.OM0eAT`: 253 scripts compiled, 290 resources
  audited with zero issues, 17,590 assertions passed, race regression passed
  and 39 stability matches completed with zero failures.
- The scripted immediate-response results show host transport advantage.
  Same-tick tie scoring does not solve Internet latency; this remains a
  development-only ruleset, not production or ranked-play approval.

### Symbol Echo lifecycle prerequisite

Each new match round resets sequence length, progress, pad-entry tracking,
mistakes, finish order, illumination and display cursor, then deals a fresh
sequence with a new serial for AI memory invalidation. Pad illumination now
advances only with controller simulation time, not an independent scene tween.
Same-tick sequence finishers share the placement bonus; completed sequences
cannot award it again on another input scan.

- `/tmp/kras-echo-before.log`: 22 assertions failed on stale round state and
  flash expiration while controller simulation was stopped.
- `/tmp/kras-echo-ties-before.log`: three failures reproduced slot-based bonus
  differences when all four participants finished in the same tick.
- `/tmp/kras-echo-final.log`: 36 assertions passed after both repairs.
- Full gate `kras-party-check.UJkgBy`: 254 scripts compiled, 291 resources
  audited with zero issues, 17,625 assertions passed, race regression passed
  and 39 stability matches completed with zero failures.
- At this lifecycle-repair commit Symbol Echo was offline-only. Its future adapter had to reveal only the
  currently shown symbol, not the secret sequence. At this lifecycle commit
  AI still queried the expected pad with recall errors. The subsequent observed
  memory repair is recorded below.

### Symbol Echo observed AI memory

The controller exposes only the currently illuminated symbol and its displayed
step, alongside visible phase/length and the player's own progress. Echo AI
samples this cue once, stores a difficulty-dependent remembered value and waits
its reaction delay before using it. It no longer calls `expected_pad` or receives
the true answer during input. Missed observations produce seeded guesses that
exclude disproven choices; repeated queries cannot reroll the same belief.

Miss feedback now invalidates the attempted step rather than progress zero after
a reset. Repeated-symbol movement leaves the pad fully before returning, avoiding
oscillation at its boundary. A real four-AI fixture observes [0, 0, 1] and checks
that a competitor can complete that repeated-symbol sequence.

- Initial perception unit run: 21 assertions passed.
- `/tmp/kras-echo-perception-movement.log`: real movement exposed non-normalized
  slerp-axis errors and failed repeated-symbol completion.
- `/tmp/kras-echo-movement-diagnostic.log`: planar yaw removed rotation errors;
  progress still stalled at [1, 1, 1, 2], identifying boundary oscillation.
- `/tmp/kras-echo-perception-final.log`: 38 assertions passed after explicit
  pad-exit state. The suite also includes direct near-opposite walking-turn
  checks in the subsequent full gate.
- Walking facing now interpolates planar yaw and reconstructs a normalized
  horizontal vector. This addresses the observed nearly opposite-direction
  failure without changing vehicle steering or movement acceleration.
- Full gate `kras-party-check.OojJ2s`: 255 scripts compiled, 292 resources
  audited with zero issues, 17,674 assertions passed, race regression passed
  and 39 stability matches completed with zero failures. No normalization,
  script or parse errors were found in this gate's logs.
- This is one AI category's perception repair, not a claim that every other
  brain has been audited or that Symbol Echo is online-ready.

### Closed-room input drain

Closing a played room now records a one-second, connection-local retired epoch.
Well-formed inputs for that closed epoch (or an earlier epoch in that room) are
discarded, never forwarded. Unknown connections, malformed inputs, future
epochs, snapshots and results remain rejected. Join/resume clear this marker;
closing a lobby that never played does not create an allowance. The existing
transport rate limits still apply, and session tokens are still removed.

- A regression test first reproduced `not_joined` for an in-flight input.
- `npm test`: 52 tests passed after the fix. Tests cover timeout, outsiders,
  malformed inputs, forbidden authority, no forwarding and another room.
- The real WebSocket integration test now closes a four-client match after
  reconnect, sends an old input followed by a ping barrier, and verifies no
  error message, room or session remains. Godot gameplay code is unchanged by
  this server-only repair; no new full Godot run is claimed for it.

### Quick Draw adapter verification

`draw_replica.gd` publishes the host's prompt phase, prompt number, accepted
response order, false-start locks and monotonic feedback counters. It excludes
the hidden random wait duration and signal age. Both Godot and Node validators
reject missing fields, unexpected timing fields, duplicate/out-of-range slots,
locked participants in the response order and responses during WAIT.

Guests present the pillar state and host decisions without advancing timers or
awarding points. Fresh events play once; initial snapshots, repeated rendering
and reconnect gaps suppress historical sounds.

- `/tmp/kras-draw-network.log`: 83 assertions passed, including JSON round trip,
  malformed state rejection, presentation, score/timer non-authority and event
  freshness. `npm test`: 49 server tests passed.
- Full gate `kras-party-check.DFgBMB`: 253 scripts compiled, 290 resources
  audited with zero issues, 17,552 assertions passed, race regression passed
  and 39 stability matches completed with zero failures.
- At the adapter-only commit room allowlists excluded Quick Draw; subsequent
  room work is recorded above. Actual mobile presentation and latency fairness
  remain pending. Response order is an ordered list of participants,
  not a unique placement: same-tick participants can share a scoring rank.

### Quick Draw simultaneous-response fairness

Responses sampled during the same simulation tick now share the same rank and
points. Later responses rank after all preceding participants (two first-place
responses earn three points each; the next response earns one point). This
removes the previous advantage assigned to lower-numbered player slots.

- `/tmp/kras-draw-ties-before.log`: 12 failures reproduced slot-order bias over
  all ordered pairs of distinct players.
- `/tmp/kras-draw-ties-after.log`: 47 assertions passed, including all pairs,
  later responses, match reset and spectator exclusion.
- Full gate `kras-party-check.tfBnE4`: 253 scripts compiled, 290 resources
  audited with zero issues, 17,588 assertions passed, race regression passed
  and 39 stability matches completed with zero failures.
- This fixes local same-tick fairness only. It does not compensate network
  transport delay or establish fairness across Internet connections.

### Quick Draw round reset

Each new match round now clears the prior signal age, response order and
false-start locks, resets the prompt counter and starts a fresh random wait.
Inactive players cannot register responses or false starts. This prevents
spectators from affecting reaction ranking and penalties.

- `/tmp/kras-quick-before.log`: eight failing assertions reproduced stale
  round state and spectator penalties before the fix.
- `/tmp/kras-quick-after.log`: 11 assertions passed after the fix.
- Full gate `kras-party-check.gxPb9f`: 251 scripts compiled, 288 resources
  audited with zero issues, 17,470 assertions passed, three-lap race regression
  passed and 39 stability matches completed with zero failures.
- At this lifecycle-repair commit Quick Draw remained excluded from online
  rooms. Subsequent adapter and room evidence is recorded above; the lifecycle
  repair alone was not evidence of network readiness.

### Color Stand snapshot adapter

`color_replica.gd` captures the authored 121-tile quilt, palette index per tile,
called color, phase and timer. It reuses the falling-floor codec/presenter with
an explicit internal tile-count parameter; Crumble Court still validates its
original 113-tile layout by default. Guests present tile heights/visibility and
palette without advancing floor physics, countdowns or scoring.

Monotonic call/drop sequences gate countdown/whistle feedback. First snapshots,
repeated snapshots and reconnect gaps cannot replay old cues. The shared match
dispatcher validates Color Stand state before applying it. The server has a
matching `validColorWorld` validator. Room integration is recorded above;
at the adapter-only commit this was not wired into room acceptance.

- `/tmp/kras-color-replica.log`: 430 assertions passed for JSON round-trip,
  missing/malformed fields, palette bounds, complete floor, host target,
  disabled guest collision, stopped countdown and feedback freshness.
- `npm test`: 47 tests passed, including new color bounds and existing
  Crumble Court validation/room regressions.
- Full gate `kras-party-check.88gtJ5`: 250 scripts compiled, 287 resources
  audited with zero issues, 17,460 assertions passed, real three-lap race
  regression passed and 39 stability matches completed with zero failures.
- At the adapter-only commit Color Stand was excluded from room allowlists. Remaining work then:
  room integration, multi-engine ordinary/tournament tests, reconnect state
  agreement and presentation captures from the replicated floor.

### Color Stand readability prerequisite

Reviewing the next candidate found that the HUD displayed only the game title
and timer, never the chosen color. The AI could read `called_tag`, but humans
could not learn that choice from the prompt. The HUD also kept the previous
nonempty banner when a controller intentionally returned an empty string.

The call now uses localized color names (all four in Arabic/English) and the
remaining timer. Shared HUD refresh accepts an empty banner, clearing the
expired hurry instruction during floor restoration.

- `/tmp/kras-color-call-before.log`: 17 assertions failed, covering missing
  color names in both languages and the stale restoration banner.
- `/tmp/kras-color-call-after.log`: 160 assertions passed after correction.
- Full gate `kras-party-check.8kVdKP`: 248 scripts compiled, 285 resources
  audited with zero issues, 17,031 assertions passed, real three-lap race
  regression passed and 39 stability matches completed with zero failures.
- `/tmp/kras-color-portrait.png` (540x960) and
  `/tmp/kras-color-landscape.png` (960x540) were inspected. Both show the
  called yellow color, time, four players, complete floor and touch movement.
  Their corresponding logs each passed 161 assertions. These are static
  desktop QA fixtures, not evidence of an online match or device performance.
- Color Stand remains excluded from online rooms until its tile palette,
  collapse states, called color and phase timers are authoritatively replicated
  and tested across connected engines. Naming colors does not yet provide
  non-color tile symbols for color-vision accessibility.

### Blast Ball room integration

Both room and client allowlists now permit only `ember_pit` for Blast Ball.
Room snapshots require `validBlastWorld` and retain host-only publication.
The engine harness and CI matrix include this ruleset, with assertions that a
decreasing fuse and an actual explosion occurred, and that guest fuse,
detonation, launch identity and collision mask agree with the final host state.

- `npm test`: 46 tests passed, including room-level missing-fuse rejection,
  incorrect-arena rejection, non-host snapshot denial and valid relay.
- Initial ordinary run `kras-network-smoke-oxaGdn` failed the explosion
  observation gate: fixed diagonal scripted inputs exited the arena too early.
  No gameplay fuse was shortened to make the test pass. Scripted humans now
  steer around an inner ring, allowing the actual five-second fuse to expire.
- Ordinary run `kras-network-smoke-YlbFzX` passed both two-human/two-AI and
  four-human cases, including guest reconnect and host result-transport loss.
  Final scores agreed: [16, 8, 11, 6] and [4, 12, 16, 16]. Guests received
  852 and 1065-1084 world snapshots; local server loop maximum was 64 ms.
  These scripted-input results are not a balance evaluation or mobile FPS test.
- Tournament run `kras-network-smoke-Uvid91` passed three matches for both
  two-human/two-AI and four-human cases, with matching final accounting and
  reconnections. Points were [13, 7, 6, 7] (champion slot 0) and [10, 7, 11, 7]
  (champion slot 2). Guests received 1353 and 1642-1661 world snapshots. Neither
  final standing required sudden death in these runs. A local server event-loop
  spike reached 143 ms; successful correctness checks do not certify latency.
- Final gate `kras-party-check.LJvbhj`: 248 scripts compiled, 285 resources
  audited with zero issues, 17,013 assertions passed, real three-lap race
  regression passed and 39 stability matches completed with zero failures.
- Physical-device QA remains pending for this integration. Production
  endpoint/configuration is unchanged. Desktop orientation evidence follows.

### Blast Ball orientation polish

The optional `--capture-blast=<path>` fixture renders a validated host snapshot
with all four players and one real touch-control layout. It is a static QA
fixture, not recorded online gameplay or an App Store marketing screenshot.

Initial portrait/landscape inspection found the above-ball fuse too small and
the description incorrectly suggesting a held-item mechanic. The explosive
Label3D now uses a larger pixel scale and higher anchor. Arabic and English
describe hitting the ball away and elimination within the blast radius.
The fixture also resets its round index before capture rather than inheriting
the preceding synthetic round-transition test.

- `/tmp/kras-blast-portrait-final.png` (540x960) and
  `/tmp/kras-blast-landscape-final.png` (960x540) were opened and inspected.
  Four players, the ball/fuse, HUD and touch actions are visible without overlap.
- Corresponding `*-final.log` files: 100 assertions passed in each graphical
  run, with no reported leaked rendering resources.
- `/tmp/kras-blast-polish-content.log`: 121 assertions passed, including
  localization key parity and content references.
- `/tmp/kras-blast-polish-goal.log`: 120 Goal Guard assertions passed after
  the shared GameBall label change; normal-ball rules remain unchanged.
- This targeted presentation change does not replace physical-device QA,
  safe-area checks on iPhone/iPad, or frame-time/battery measurements.

### Blast Ball adapter in development

`src/net/blast_replica.gd` now captures and presents host-owned position,
velocity, launch generation, fuse, terminal detonation and a monotonic
explosion sequence/location. The shared match snapshot dispatcher validates
this world before acceptance. Presentation does not tick physics or fuse and
cannot eliminate players or award points. Launch identity forces a snap;
ordinary movement interpolates. Exploded balls hide until the next launch.

Explosion feedback is separated from authoritative damage. First snapshots,
round changes and reconnect gaps suppress old feedback; repeated snapshots
cannot replay an already consumed event. `validBlastWorld` supplies the same
numeric/type bounds on the server. At the adapter-only commit it was not yet
wired into room acceptance; the integration status above supersedes that limit.

- `/tmp/kras-blast-replica-tests.log`: 94 assertions passed, including shared
  snapshot dispatch, malformed data rejection, unchanged scores/alive state,
  stopped fuse, teleport, visibility and feedback replay suppression.
- `npm test`: 45 tests passed after allowing the local WebSocket listener.
  The initial sandbox run failed only at `listen EPERM 127.0.0.1`; it was not
  counted as a passing transport test.
- Full gate `kras-party-check.Q4Nmkc`: 248 scripts compiled, 285 resources
  audited with zero issues, 17,013 assertions passed, real three-lap race
  regression passed and 39 stability matches completed with zero failures.
- At the adapter-only commit Blast Ball was excluded from room allowlists. Remaining acceptance then was:
  room-level validation, ordinary and tournament multi-engine tests with
  actual fuse/launch/explosion observations, and portrait/landscape captures.
  This work is not production activation or App Store readiness.

1. Define a bounded world-state adapter for all gameplay-visible dynamic objects
   (balls, projectiles, crates, hazards, ownership, effects), not just players.
2. Keep the host as the sole rules/score authority. Never simulate a second
   independent match on guests and call that synchronization.
3. Add malformed snapshot, reconnect, round reset and result tests.
4. Run real multiple-engine tests and device visual/audio QA.
5. Add the game to both server and client allowlists only after those pass.
6. Verify score direction and tournament placement for the new game, including
   contender-only tie-breaks, reconnect and host loss.

WebSocket is used here because the existing HTTP deployment can relay it;
its TCP latency tradeoff still requires real-network testing. References:
[Godot WebSocket guide](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html),
[ws](https://github.com/websockets/ws).

## Structure

```text
server/
  rooms.js             # protocol/state/ownership, independent of transport
  tournament.js        # points/cups, seeded rotation, bounded tie-breaks
  tournament.test.js   # accounting, ties, rotation and immutable views
  multiplayer.js       # bounded WebSocket transport, heartbeat, shutdown
  rooms.test.js        # state and actual four-socket integration tests
  network-smoke.js     # real multi-process Godot integration
src/net/
  net_service.gd       # local + online session coordinator
  room_client.gd       # Godot WebSocket transport
  match_replica.gd     # shared player/phase state and world adapter dispatch
  goal_guard_replica.gd # bounded ball/charge presentation, no guest simulation
  collectible_replica.gd # shared gem/star visual reconciliation without physics
tests/
  network_peer.gd      # actual match client used by the smoke test
  suites/test_network.gd
```
