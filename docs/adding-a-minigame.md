# Adding a mini-game

Two files. Nothing else in the project needs to change, and the new game picks
up physics, camera, HUD, countdown, pause, sudden death, power-ups, results, AI
opponents, statistics, achievements and its own automated test for free.

---

## 1. Declare it

`data/minigames.json`, in the `games` array:

```json
{
  "id": "tug_of_ring",
  "category": "push_out",
  "scoring": "points",
  "arenas": ["vortex_ring", "bumper_bowl"],
  "duration": 85.0,
  "rounds": 2,
  "sudden_death": true,
  "controls": ["move", "attack", "dash"],
  "glyph": "◎",
  "tags": ["chaos"],
  "difficulty_curve": 1.0,
  "unlock": {"type": "trophies", "amount": 5}
}
```

| Field | Meaning |
|---|---|
| `id` | Must match the script filename (`src/minigames/<id>.gd`) |
| `category` | One of `push_out`, `ball_zone`, `vehicle`, `collect`, `control`, `crates`, `race`, `reaction`, `survival`, `combat`. Decides which power-ups are eligible |
| `scoring` | `points` (high wins), `survival` (elimination order), `race_time` (**low** wins), `lives` |
| `arenas` | One or more arena ids; Quick Play lets the player choose between them |
| `duration` | Round length in seconds |
| `rounds` | Default number of rounds |
| `sudden_death` | Whether a tie at the whistle triggers overtime |
| `controls` | Glyph keys for the pre-round card. **Also gates the verbs**: a game without `"jump"` disables jumping, without `"attack"` disables attacking |
| `unlock` | Omit for a game available from the start |

## 2. Write the rules

`src/minigames/tug_of_ring.gd`:

```gdscript
extends MiniGameController
## One-paragraph description of what the player is doing and why it is fun.

const RING_OUT_POINTS := 2


func configure() -> void:
    # Called before anything is built. Declare how the shared systems behave.
    eliminate_on_fall = false     # false = respawn, true = you are out
    lives_per_player = 99


func build() -> void:
    # The arena and the fighters already exist. Spawn your own objects here.
    pass


func tick(delta: float) -> void:
    # Your rules. Only called while the match is live (PLAYING / SUDDEN_DEATH),
    # and always after movement has been integrated for this tick.
    pass


func on_credited_knockout(attacker: int, victim: int) -> void:
    ctx.add_score(attacker, RING_OUT_POINTS)
    ctx.bump_detail(attacker, "knockouts")
```

## 3. Add the strings

Both `data/loc/ar.json` and `data/loc/en.json` need three keys:

```json
"game.tug_of_ring.name":  "…",
"game.tug_of_ring.desc":  "one line for the card",
"game.tug_of_ring.rules": "two sentences the player reads before the countdown"
```

`Registry.validate()` fails the build if any of these is missing, in either
language.

---

## What you get from `ctx` (`MatchContext`)

| | |
|---|---|
| `ctx.fighter(slot)` | The `Fighter` for a slot |
| `ctx.fighters` | All of them, indexed by slot |
| `ctx.is_alive(slot)`, `ctx.alive_count()`, `ctx.alive_slots()` | Liveness |
| `ctx.add_score(slot, n)`, `ctx.set_score(slot, n)` | Scoring — fires the HUD |
| `ctx.bump_detail(slot, key, n)` | Per-player stats for the results screen |
| `ctx.eliminate(slot)` | Removes a player and records elimination order |
| `ctx.time_left`, `ctx.round_index`, `ctx.sudden_death` | Match state |
| `ctx.rng` | Seeded RNG — use this, never `randf()`, or replays and daily challenges desync |
| `ctx.arena` | The `Arena`: `is_inside()`, `edge_distance()`, `tiles`, `spawn_points` |
| `ctx.world_root` | Parent your objects here |
| `ctx.powerups.point_multiplier(slot)` | Apply to any score you award |
| `ctx.early_finish` | Set true to end the round now |

## Overridable hooks

| Hook | Default |
|---|---|
| `locomotion()` | `WALK` — also `DRIVE` (karts) and `FLOAT` |
| `camera_mode()` | `ARENA` — also `TOP_DOWN`, `ISOMETRIC`, `THIRD_PERSON`, `RACE` |
| `uses_powerups()` | `true` |
| `music_track()` | `"arena"` — also `arena_b`, `tension`, `menu`, `victory`, `adventure` |
| `compute_scores()` | Survival order, or the running score |
| `is_round_over()` | One player left, for survival/lives games |
| `is_tied()` | Whether sudden death should trigger |
| `hud_value(slot)` | The number on the player's chip |
| `hud_banner()` | Extra line under the clock |
| `detail_rows()` | Which stats the results screen shows |
| `ai_script()` | `generic_brain.gd` |
| `on_round_start()`, `on_round_end()`, `on_sudden_death()` | — |
| `on_fighter_fell(slot)`, `on_fighter_knocked_out(slot, by)` | Shared fall handling |
| `cleanup()` | Free anything `build()` created outside `world_root` |

## Writing an AI for it

Only if the generic brawler is wrong for your game. Create
`src/ai/brains/my_brain.gd`:

```gdscript
extends AIBrain

func decide(_delta: float) -> void:
    var me := self_body()
    if me == null:
        return
    var target := priority_rival()
    if target >= 0:
        steer_to(predict(target, 0.3))   # NOT the live position
        maybe_attack(target, 2.5)
    keep_off_edge()
```

and point `ai_script()` at it.

**The one rule:** never read a live position. Use `perceive(slot)` (delayed by
`reaction_time`) or `predict(slot, lead)` (delayed, then extrapolated by
`prediction`). Game-specific state is fine to read from `controller` — it is on
screen for the human too — but delay-free tracking of a moving target is not.

Helpers available: `steer_to`, `steer_away`, `drive_to` (for `DRIVE`
locomotion), `keep_off_edge`, `maybe_dash`, `maybe_attack`, `maybe_jump`,
`press`, `nearest_rival`, `leader_rival`, `priority_rival`,
`nearest_in_group`.

## Verify

```bash
godot --headless --path . tests/compile_check.tscn
godot --headless --fixed-fps 60 --path . tests/test_runner.tscn
```

`test_matches.gd` iterates `Registry.minigames()`, so your game is played to
completion on the next run with no test to write. It will assert that the match
produces a valid result, awards a first place, logs no errors, that the AI
actually moved, and that the camera stayed on the arena.
