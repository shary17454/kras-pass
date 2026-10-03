# Colossus online qualification checkpoint

Source: `5bc5715726f145197f864146b23accc475dd9785` on
`feature/kras-online-release`. The nine changed source/test/doc files were
checksum-compared between `/tmp/kras-online-release` (runtime assets present)
and the independent `/tmp/kras-impact-publish` Git checkout before the run.

## Two human peers plus bots: PASS

Command: `node network-smoke.js --game=boss_colossus --humans=2 --seed=9614`.
Evidence directory:
`/var/folders/77/ng2sccd50bd8dtpjwd7jqgj00000gn/T/kras-network-smoke-CTBsEY`.

Both actual Godot processes completed one two-round match. Both ordinary rounds
had real boss damage, warnings/strikes, carved ground and boss defeat. The guest
received 5199 world snapshots, matched the host scores `[990,330,110,220]`, and
passed presentation-only/collision-ownership checks. Both peers reconnected,
including the host's dropped-result recovery. The Node process exited zero and
reported `humans:2,status:PASS`.

This is functional evidence only. Host frame gap reached 17740 ms and server
loop delay reached 15032 ms on the heavily loaded shared macOS host. It does not
prove 60 FPS, battery/thermal suitability or production latency. No deadline,
boss health, attack damage, exposure window or round duration was altered.

## Remaining qualification

The four-peer run at the same seed, `kras-network-smoke-YKhSVn` under the same
temporary parent directory, defeated the boss in round zero and entered round
one, but the existing Node 450-second deadline then expired. Its last sampled
round-one elapsed time was 0.78 seconds. It is FAILED, not a complete four-peer
match. Host frame gap reached 11108 ms and server loop delay 7046 ms.

Four human peers, multi-match tournaments, final/tiebreak rounds and fresh
cross-engine CI therefore remain unqualified. This passing two-peer run is not
permission to enable or advertise all 39 games in production.

The CI matrix now includes `boss_colossus`, previously absent: 39 real game
scenarios plus the core gate. Its job budget is 50 minutes to cover both ordinary
peer groups (2 x 450 seconds), both tournament groups (2 x 800 seconds) and setup.
The underlying peer/game deadlines remain unchanged. This adds coverage and
does not assert that the new job has passed.

## Other observed CI failures

The older feature run `37081719185`, source
`70e0981b3b7055af99adf806981be74aeb961c9a`, is terminal FAILURE. It had two failed
jobs: `111083481085` (`network-kart_sprint`) and `111083481357`
(`network-base_siege`). These are not results for the new source.

- Kart Sprint's 150-second peer watchdog expired during the second ordinary
  round. The first round completed all four three-lap races at 94.63 simulation
  seconds. The fixture currently uses the generic whole-session 150-second
  budget despite testing two complete untimed races; its Node process budget
  is also the generic 180 seconds. Any repair must keep a finite watchdog and
  actual lap completion assertions, not skip the second round or force finishes.
- Base Siege's ordinary tournament rounds showed real destruction. The failed
  guest in a subsequent final was a spectator; contenders scored three actual
  hits, but no full crystal destruction was observed within that short final.
  The fixture currently requires full destruction in every final as well as
  ordinary rounds. Review the final's actual contract before changing gameplay
  or evidence gates. Do not weaken ordinary hit/destruction qualification.

Main-source run `37087154064` was observed queued, source
`c14e384d599476c7a71691c4fd524bf4c51af686`. No success is inferred from queuing.
No Railway deployment, archive, upload or App Store submission was performed.
