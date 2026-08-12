# DAWWAMA — دوّامة

**An original party game of competitive mini-games.**
*كأس الدوّامة الكبرى — لعبة حفلات ومنافسات مصغّرة.*

Eight competitors from eight realms are pulled into the Dawwama, a great vortex
that hosts a tournament of short, chaotic contests. Twenty-one mini-games, five
realms of adventure, local multiplayer for up to four, and an AI that plays by
the same rules you do.

Built in **Godot 4** with **no imported assets** — every mesh, arena, sound
effect and music loop is generated at runtime from parameters in `data/`.
Nothing in this repository is derived from, extracted from, or modelled on any
existing game. The name, world, characters, arenas, rules and audio are original
to this project.

---

## Contents

- [Quick start](#quick-start)
- [What is in the box](#what-is-in-the-box)
- [Architecture](#architecture)
- [How to add content](#how-to-add-content)
- [The AI](#the-ai)
- [Save system](#save-system)
- [Multiplayer](#multiplayer)
- [Localization and accessibility](#localization-and-accessibility)
- [Tests](#tests)
- [Platforms](#platforms)
- [Known limitations](#known-limitations)

---

## Quick start

**Requirements:** Godot 4.4 or newer (developed on 4.7.1), any desktop OS.
No plugins, no addons, no asset packs.

```bash
# install the engine (macOS)
brew install --cask godot

# play
godot --path .

# run the automated suite (headless, ~2 minutes)
godot --headless --fixed-fps 60 --path . tests/test_runner.tscn

# verify every script compiles (fast, run this after a refactor)
godot --headless --path . tests/compile_check.tscn
```

**Controls**

| Action | Keyboard 1 | Keyboard 2 | Gamepad |
|---|---|---|---|
| Move | `WASD` | Arrows | Left stick / D-pad |
| Jump | `Space` | `Num 0` | A |
| Attack | `F` | `Num 1` | X |
| Action | `E` | `Num 2` | B |
| Dash / Boost | `Shift` | `Num 3` | RB or RT |
| Ability | `Q` | `Num 4` | Y |
| Pause | `Esc` | — | Start |
| Dev menu (debug builds only) | `F1` | — | — |

All keyboard bindings are remappable in **Settings → Controls**.

---

## What is in the box

| | |
|---|---|
| Playable characters | 8, each with a distinct stat spread, silhouette, colour, victory animation and unlock condition |
| Mini-games | 21, across 10 categories |
| Arenas | 23, procedurally generated from 10 shape families |
| Adventure | 5 realms × 5 stages (4 qualifiers + 1 championship) = 25 stages |
| Power-ups | 12, fully data-driven |
| Achievements | 42 |
| Modes | Adventure, Quick Play, Tournament, Local Party, Training, Daily Challenge |
| Languages | Arabic (RTL) and English, at full parity |
| Players | 1–4 local, human or AI in any mix |

### The mini-games

| Category | Games |
|---|---|
| Push-out | Ring Rumble, Crumble Court, Bumper Bowl |
| Ball & zone | Goal Guard, Blast Ball |
| Vehicle | Scrap Karts, Turret Duel |
| Collection | Gem Grab, Star Rush |
| Territory | Paint Grid, Zone Hold |
| Crates | Crate Smash, Crate Relay |
| Racing | Hurdle Dash, Kart Sprint |
| Reaction & memory | Colour Stand, Symbol Echo, Quick Draw |
| Survival | Rising Tide, Sweeper Storm |
| Light combat | Duel Pit |

### The roster

| Character | Realm | Plays like |
|---|---|---|
| Nabta / نبتة | Green Vale | Quick and nimble, easy to knock about |
| Sakhra / صخرة | Stone Reach | Slow, immovable, hits hardest |
| Fanoos / فانوس | Ember Souq | Perfectly balanced — the reference character |
| Ramla / رملة | Dune Sea | Explosive acceleration, poor top-end control |
| Barq / برق | Storm Rim | Fastest in the game and the lightest |
| Mowja / موجة | Tide Hollow | Best air and turn control |
| Ghaim / غيم | Sky Loft | Huge jump, floats, weak on the ground |
| Turs / ترس | Cogworks | Heavy bruiser, second only to Sakhra |

Every character's six stats sum to the same budget (asserted by
`tests/suites/test_content.gd`), so the roster is a set of trade-offs rather
than a power ladder.

---

## Architecture

### Why Godot

The environment had no engine installed, so the choice was open. Godot 4 was
selected over Unity and Unreal because:

- **No licence, no account, no seat management.** The whole project is a folder
  of text files that any developer can clone and run.
- **Headless CI is a first-class feature.** `godot --headless` runs the full
  game loop with no display, which is what makes the integration suite here
  possible: every one of the 21 mini-games is actually *played* on every test
  run. Neither of the alternatives makes that as cheap.
- **Native arm64 on this machine**, with export templates for macOS, Windows,
  Linux, iOS and Android from the same project.
- **GDScript's iteration speed** suits a project that is 21 small rule-sets
  sharing one engine, rather than one large simulation.
- Unreal would have been the better choice had this been a graphics-led
  product; it is not. Unity would have imposed a licence and an editor-bound
  workflow for no benefit here.

Rendering uses the **mobile** renderer so the same project runs unchanged on
desktop and on phones.

### Layout

```
project.godot          engine config + autoload registration
data/                  ALL tuning, content and text (JSON)
  tuning.json          every gameplay constant in the game
  characters.json      the roster
  minigames.json       the catalogue
  arenas.json          venue recipes
  powerups.json        pickup definitions
  adventure.json       realms, stages, completion rewards
  achievements.json    achievement definitions
  ai.json              difficulty profiles
  loc/ar.json,en.json  every user-facing string
src/
  core/                Logger, Balance, Registry, EventBus, SceneRouter, Pool
  data/                typed wrappers: CharacterData, MiniGameDef, ArenaDef, PowerUpDef
  input/               InputFrame + InputRouter (device → slot routing)
  actors/              Fighter, GameBall, Collectible, Projectile
  arenas/              Arena generator, ArenaTile, ArenaHazards
  camera/              ArenaCamera
  match/               MatchConfig, MatchContext, MatchPhase, MatchResult,
                       MatchScene, TournamentSession, AdventureSession
  minigames/           MiniGameController + 21 games
  ai/                  AIBrain + 19 specialised brains
  powerups/            PowerUpSystem, PowerUpPickup
  ui/                  UIKit, Widgets, Screen, MatchHUD, screens/
  audio/               Synth, AudioManager
  save/                SaveSystem
  progression/         Progression, Stats, Achievements
  settings/            UserSettings
  net/                 Net (online abstraction layer)
  debug/               DevTools
  fx/                  MeshFactory, burst effect
tests/                 headless suite + compile check
docs/                  design bible, QA scenarios, how-to guides
```

### The three ideas that hold it together

**1. Everything is an `InputFrame`.**
A gamepad, a keyboard profile, an AI brain, a replay file and (later) a network
packet all produce the identical 5-byte struct, and `Fighter` cannot tell them
apart. This is why every mini-game works with bots, with four local players, and
will work online, with no per-source branching anywhere in gameplay code.

```
device / AI / replay / network  →  InputFrame  →  InputRouter  →  Fighter
```

**2. The match layer owns everything that is not a rule.**
A mini-game owns its objects, its win condition and its AI policy. It does *not*
own the clock, the arena, the fighters, the camera, the HUD, scoring arithmetic,
elimination bookkeeping, power-ups, the results screen or the state machine.
That is why the twenty-first game took a fraction of the code of the first, and
why ties behave identically in all of them.

**3. Nothing is hard-coded and nothing is imported.**
Balance numbers live in `data/tuning.json`. Content lives in `data/*.json`.
Strings live in `data/loc/`. Geometry, characters, arenas, sound effects and
music are generated at runtime by `MeshFactory` and `Synth`. The repository has
zero binary assets, which means zero licensing questions and a build that is
entirely reviewable as text.

### Match lifecycle

```
LOADING → INTRO → INSTRUCTIONS → COUNTDOWN → PLAYING
                       ↑                        ↓
                       │              SUDDEN_DEATH (only if tied)
                       │                        ↓
                  NEXT_ROUND ← RESULTS ← FINISH
                       ↓
                     DONE
```

Legal transitions are declared as a table in `MatchPhase.LEGAL` and every change
goes through `MatchScene._set_phase()`, which refuses illegal edges and logs
them. Combined with a `_phase_locked` flag, this rules out the classic party-game
race where a last-second knockout and the clock hitting zero both try to end the
round.

Physics order per tick is fixed and deliberate:

1. AI brains think and publish input frames
2. `InputRouter` refreshes all frames (priority `-100`)
3. Fighters integrate
4. Arena hazards update
5. Mini-game rules run
6. Out-of-bounds checks
7. Clock

Rules run *after* movement, so a game never reacts to a stale position.

---

## How to add content

### A new mini-game

Two steps. Nothing else in the project needs editing.

**1.** Add an entry to `data/minigames.json`:

```json
{
  "id": "my_game",
  "category": "push_out",
  "scoring": "points",
  "arenas": ["vortex_ring"],
  "duration": 90.0,
  "rounds": 1,
  "controls": ["move", "attack", "dash"],
  "glyph": "◆",
  "unlock": {"type": "trophies", "amount": 5}
}
```

**2.** Create `src/minigames/my_game.gd`:

```gdscript
extends MiniGameController

func configure() -> void:
    eliminate_on_fall = false     # respawn instead of removing
    lives_per_player = 99

func build() -> void:
    # spawn your objects; the arena and fighters already exist
    pass

func tick(delta: float) -> void:
    # your rules; only called while the match is live
    pass

func on_credited_knockout(attacker: int, victim: int) -> void:
    ctx.add_score(attacker, 2)
```

**3.** Add `game.my_game.name`, `.desc` and `.rules` to both
`data/loc/ar.json` and `data/loc/en.json`.

You now have a game with working physics, collisions, hit reactions, camera,
HUD, countdown, pause, sudden death, power-ups, results, AI opponents,
statistics and achievement tracking. `tests/suites/test_matches.gd` will pick it
up automatically and play it on the next test run.

Useful overrides: `locomotion()` (walk / drive / float), `camera_mode()`,
`uses_powerups()`, `music_track()`, `compute_scores()`, `is_round_over()`,
`hud_value()`, `hud_banner()`, `ai_script()`, `on_sudden_death()`.

### A new character

Add to `data/characters.json`. Stats are 0..1 and should sum to ~3.00 (the test
suite enforces the band). `body` picks a procedural silhouette:

```json
{
  "id": "newcomer",
  "color": "#7be5ff",
  "accent": "#ffffff",
  "unlock": {"type": "wins", "amount": 20},
  "stats": {"speed": 0.6, "accel": 0.5, "weight": 0.4,
            "jump": 0.5, "power": 0.5, "control": 0.5},
  "body": {"shape": "orb", "head": "sphere", "height": 1.0,
           "girth": 1.0, "accessory": "spark"},
  "celebration": "leap"
}
```

Then add `char.newcomer.name`, `.realm` and `.tagline` to both locale files.
Shapes: `capsule`, `boulder`, `orb`, `shard`, `drum`. Accessories: `leaf`,
`crack`, `spark`, `flame`, `wave`, `puff`, `grain`, `cog`.

### A new arena

Add to `data/arenas.json`. `shape` selects a generator: `disc`, `square`, `ring`,
`cross`, `tiles`, `grid`, `track`, `oval`, `pit`, `islands`. Hazards are
declarative:

```json
{
  "id": "my_arena",
  "shape": "disc",
  "radius": 13.0,
  "wall_height": 0.0,
  "palette": {"floor": "#2e3358", "accent": "#f2a03f",
              "sky_top": "#141a3c", "sky_bottom": "#6b3d6b"},
  "hazards": [
    {"type": "shrink", "start_delay": 18.0, "rate": 0.3, "min_radius": 5.0},
    {"type": "sweeper", "count": 2, "speed": 1.1, "length": 9.0}
  ]
}
```

Hazard types: `shrink`, `sweeper`, `bumper`, `pillars`, `hurdles`, `crumble`,
`rising`. Add `arena.my_arena.name` to both locale files and reference the arena
from at least one mini-game (an unused arena is flagged by `Registry.validate()`).

### A new power-up

Add to `data/powerups.json` — no code:

```json
{"id": "haste", "kind": "speed", "duration": 5.0, "magnitude": 1.6,
 "color": "#7be5ff", "glyph": "»", "weight": 1.0,
 "categories": ["push_out", "race"]}
```

Kinds handled by `PowerUpSystem`: `speed`, `slow`, `push`, `weight`, `points`,
`magnet`, `shield`, `dash`, `boost`, `freeze`, `bomb`, `heal`. A genuinely new
*kind* is one `match` arm in `PowerUpSystem._recompute()` or `_apply()`.

---

## The AI

The design rule, enforced by construction:

> **An AI may only read what a human player can see on screen, and only after a
> human-plausible delay.**

Every world query goes through `AIBrain.perceive()`, which returns a position
from `reaction_time` seconds ago. `predict()` extrapolates it, scaled by the
profile's `prediction` value. Aim is perturbed by `(1 - accuracy)`. There is no
hidden state, no perfect information and no rubber-banding: Expert opponents run
at the same speed and take the same damage as Easy ones.

The four tiers differ in:

| | Easy | Medium | Hard | Expert |
|---|---|---|---|---|
| Reaction time | 0.46 s | 0.30 s | 0.20 s | 0.13 s |
| Aim accuracy | 0.55 | 0.72 | 0.85 | 0.94 |
| Prediction | 0.15 | 0.38 | 0.62 | 0.85 |
| Strategy (target the leader) | 0.20 | 0.50 | 0.78 | 0.95 |
| Aggression | 0.28 | 0.48 | 0.68 | 0.82 |
| Risk tolerance | 0.20 | 0.38 | 0.55 | 0.70 |
| Deliberate mistakes | 22% | 11% | 5% | 2% |
| Input noise | 0.24 | 0.14 | 0.08 | 0.04 |

Two details make the bots read as people rather than machines:

- **Deliberate lapses.** `mistake_chance` occasionally makes a bot freeze or
  wander for a quarter-second. Easy opponents feel distracted, not slow.
- **Sticky wrong answers.** In the memory game, a bot that misremembers a step
  keeps misremembering it; re-rolling each tick would average the error away and
  make it accidentally perfect.

Nineteen specialised brains express per-game strategy — the keeper stands on its
line and clears toward rivals, the kart driver backs off to build a run-up, the
crate smasher judges a crate's colour (and can be wrong), the climber shoves
whoever is above it. All of them inherit the shared decision clock, edge safety
and noise.

---

## Save system

Two independent slots under `user://`: `profile.json` (progression, unlocks,
achievements, statistics, records) and `settings.json`.

Writes are atomic and versioned:

1. Serialize with an MD5 envelope to `<slot>.tmp`
2. Rotate the current good file to `<slot>.bak`
3. Rename the tmp into place

Loads walk **main → backup → empty**. A checksum mismatch or a parse failure
falls through to the backup, so a power cut mid-write costs at most one session
rather than the whole profile. `_migrate()` is the forward-compatibility hook for
future schema changes. Corruption recovery is covered by
`tests/suites/test_save.gd`, which deliberately truncates a save and asserts the
backup is used.

---

## Multiplayer

**Local:** fully implemented. 1–4 players in any mix of humans and AI, on
gamepads and two keyboard profiles. The Local Party screen uses
press-a-button-to-join rather than menu navigation, so someone can pick up a pad
mid-lobby. A controller disconnecting mid-match pauses the game with an
explanatory message instead of stranding the player.

**Online:** the transport is **not** shipped in 1.0, and the reason is stated
plainly rather than hidden behind a grey button. Shipping half-working netcode
would destabilise the local game, which is the product. What *is* implemented is
the seam:

- `Net` (`src/net/net_service.gd`) defines the full session model: hosting,
  room codes, join, peer list, ready state, lobby config, match start, and
  disconnect handling.
- A `LocalBackend` satisfies that entire interface today, and the Online screen
  runs the real lobby flow against it — a real room code, real ready-up, and a
  real `MatchConfig` at the end.
- The input transport contract is `publish_input()` / `consume_input()`, keyed
  on `(slot, tick)` and carrying the same 5-byte `InputFrame` the local game
  already uses.

Turning it on means implementing those two methods against
`ENetMultiplayerPeer` or WebRTC and setting `Net.online_available = true`.
No mini-game, AI brain or match-layer code changes.

---

## Localization and accessibility

**Languages.** Arabic (primary, right-to-left) and English, at full key parity —
`tests/suites/test_content.gd` fails the build if either locale is missing a
string the other has. No user-facing text exists in code; everything goes through
`Loc.t()`.

RTL is genuine, not cosmetic: `UIKit` mirrors container order, text alignment and
the direction of the back arrow when `Loc.is_rtl()` is true. Fonts use
`SystemFont` with OS fallback, which gives correct Arabic shaping and bidi on
macOS, Windows, iOS and Android without shipping or licensing a font file.

**Accessibility options** (Settings → Accessibility):

- Text size scaling (0.8×–1.6×), applied across every screen
- High contrast mode
- Reduce flashing
- Reduce effects (fewer particles, no bloom, smaller bursts)
- Screen shake slider, down to zero
- Colour-vision modes: protanopia, deuteranopia, tritanopia — applied to every
  player, team and pickup colour via `UIKit.adapt()`
- Full keyboard remapping for both local profiles
- Controller vibration toggle

---

## Tests

```bash
godot --headless --path . tests/compile_check.tscn          # every script compiles
godot --headless --fixed-fps 60 --path . tests/test_runner.tscn   # full suite
```

The suite backs up your real profile before running and restores it afterwards.
It exits non-zero on failure, so it can gate CI directly.

| Suite | Covers |
|---|---|
| `test_scoring` | Placement, ties, four-way draws, race-time inversion, multi-round aggregation, survival ordering, tournament points and tie-sharing, deterministic schedules |
| `test_content` | Registry validation, content counts, character stat-budget parity, locale parity, every achievement condition type, phase-machine legality |
| `test_save` | Atomic write/read, checksum rejection, backup recovery, garbage-file degradation, unlock rules, adventure records, completion maths, settings persistence |
| `test_systems` | Input frame edges and replay encoding, AI profile ordering, object pooling, power-up stacking/refresh/expiry, and a walk of **every screen** asserting it builds and can reach the menu |
| `test_matches` | **Plays all 21 mini-games to completion** with four AI competitors and asserts a valid result, a first place, no logged errors and that the bots actually moved. Plus multi-round aggregation, pause/restart/quit, controller loss and Expert-vs-Easy separation |

The QA scenarios that are checked on every run are listed in
`docs/qa-scenarios.md`, along with the manual ones that are not.

---

## Platforms

Developed and verified on **macOS (arm64)**. The project is not tied to it:
rendering is the mobile renderer, input is device-agnostic, and there is no
platform-specific code.

| Target | Status |
|---|---|
| macOS | Verified — developed here |
| Windows / Linux | Should build unchanged; export templates required. Not verified in this environment |
| iOS / iPadOS | Architecture supports it (mobile renderer, touch-free UI is gamepad-navigable). Requires an Apple developer account and a touch control layer, neither of which exists here |
| Apple TV / consoles | Not claimed. Console SDKs and licences are not available in this environment |

Only macOS is verified. Everything else is a supported-by-architecture claim, not
a tested one.

---

## Known limitations

Stated plainly, because a list of caveats is more useful than an optimistic one:

1. **Online multiplayer is not implemented.** The abstraction layer, lobby,
   room codes and input transport contract exist and work locally; the network
   transport does not. See [Multiplayer](#multiplayer).
2. **Replays are recorded but not played back.** Every match captures its input
   frames (~1.2 KB/s for four players) and the format round-trips correctly, but
   there is no playback UI. `InputRouter.playback_mode` is the hook.
3. **Art is procedural placeholder-quality by design.** The look is deliberate
   and consistent, but these are primitives with toon shading, not authored
   models. `MeshFactory` is the single swap point.
4. **Audio is synthesized.** Six music loops and ~25 effects, generated at
   runtime. They fit the game; they are not a composed soundtrack.
5. **Touch controls do not exist.** Required before a phone release.
6. **No cloud save**, no analytics backend, no store integration.
7. **The Daily Challenge date is local**, so a device with a wrong clock gets a
   different challenge.
8. **Balance is first-pass.** The stat budgets are equal and the AI tiers are
   separated, but the games have not had the hundreds of hours of live play that
   real party-game balance needs.

---

## Licence and originality

All code, data, text, geometry and audio in this repository were written for this
project. No assets, names, characters, arenas, music or mechanics were copied
from any existing game. The design is informed by the party mini-game genre in
general; the execution is original throughout.
