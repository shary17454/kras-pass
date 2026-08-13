class_name MiniGameController
extends Node3D
## Base class for every mini-game.
##
## A game owns its rules, its objects and its AI policy. It does **not** own the
## clock, the arena, the fighters, the camera, the HUD, scoring arithmetic,
## power-ups, elimination bookkeeping, the results screen or the state machine —
## those are the match layer's job and are identical everywhere. That split is
## why the 21st game in this project took a fraction of the code of the first.
##
## Minimum viable subclass:
##   extends MiniGameController
##   func build() -> void: ...            # spawn your objects
##   func tick(delta) -> void: ...        # run your rules
##   func compute_scores() -> Array[int]  # only if not using the default
##
## See docs/adding-a-minigame.md.

var ctx: MatchContext
var def: MiniGameDef

## Fall handling shared by most games. A game sets these in `configure()`.
var eliminate_on_fall := true      # false = respawn instead
var respawn_delay := 1.4
var lives_per_player := 1
var _respawn_timers := {}
var _lives: Array[int] = []


## Attach the context without building anything. The match layer calls this
## before it spawns fighters, because `locomotion()`, `allows_attack()` and
## friends are answered from the definition and must be correct at spawn time.
func bind(context: MatchContext) -> void:
	ctx = context
	def = context.definition


func setup(context: MatchContext) -> void:
	bind(context)
	respawn_delay = Balance.num("tuning", "match.respawn_delay", 1.4)
	_lives.resize(ctx.player_count())
	_lives.fill(lives_per_player)
	configure()
	_lives.fill(lives_per_player)
	build()


# --- overridable declaration -----------------------------------------------

## Declare how this game wants the shared systems set up. Called before `build`.
func configure() -> void:
	pass


## Create the game's own objects. The arena and fighters already exist.
func build() -> void:
	pass


## Per-tick rules. Only called while the match is live (PLAYING/SUDDEN_DEATH).
func tick(_delta: float) -> void:
	pass


func on_round_start() -> void:
	pass


func on_round_end() -> void:
	pass


## Called once when the timer expires but the game is still tied.
func on_sudden_death() -> void:
	pass


func on_fighter_fell(slot: int) -> void:
	_handle_out(slot)


func on_fighter_knocked_out(slot: int, _by_slot: int) -> void:
	_handle_out(slot)


func cleanup() -> void:
	pass


# --- presentation choices --------------------------------------------------

func locomotion() -> int:
	return Fighter.Locomotion.WALK


func camera_mode() -> int:
	return ArenaCamera.Mode.ARENA


func uses_powerups() -> bool:
	return true


func music_track() -> String:
	return "arena"


## Buttons the fighter is allowed to use. Games that do not want jumping (most
## top-down brawls) simply return false here rather than filtering input.
func allows_jump() -> bool:
	return def != null and def.control_hints.has("jump")


func allows_attack() -> bool:
	return def != null and (def.control_hints.has("attack") or def.control_hints.has("shoot"))


func allows_dash() -> bool:
	return def == null or def.control_hints.has("dash") or def.control_hints.has("boost")


## How many items `Fighter.carrying` can hold before it is full. Games that
## carry-and-deliver (Star Rush, Crate Relay) override this; the AI's courier
## brain reads it to decide when to bank rather than keep foraging. Default is
## "effectively unlimited" for games that do not use `carrying` at all.
func max_carry() -> int:
	return 99


# --- scoring ---------------------------------------------------------------

## Default: survival games rank by elimination order, everything else uses the
## running score the game has been adding to `ctx`.
func compute_scores() -> Array[int]:
	if def != null and def.scoring == MiniGameDef.Scoring.SURVIVAL:
		return ctx.survival_scores()
	return ctx.scores.duplicate()


## True when the round should end before the clock runs out.
func is_round_over() -> bool:
	if ctx.early_finish:
		return true
	if def != null and (def.scoring == MiniGameDef.Scoring.SURVIVAL or def.scoring == MiniGameDef.Scoring.LIVES):
		return ctx.alive_count() <= 1
	return false


## Is the round currently a tie at the top? Drives sudden death.
func is_tied() -> bool:
	var scores := compute_scores()
	if scores.size() < 2:
		return false
	var best := scores[0]
	for s in scores:
		best = maxi(best, s)
	var count := 0
	for s in scores:
		if s == best:
			count += 1
	return count > 1


# --- HUD -------------------------------------------------------------------

## What each player's HUD chip shows. Override for games where a raw score is
## not the interesting number (lives, laps, carried items…).
func hud_value(slot: int) -> String:
	if def != null and def.scoring == MiniGameDef.Scoring.LIVES:
		return "♥ %d" % lives(slot)
	if def != null and def.scoring == MiniGameDef.Scoring.SURVIVAL:
		return Loc.t("hud.eliminated") if not ctx.is_alive(slot) else "●"
	return str(ctx.scores[slot]) if slot < ctx.scores.size() else "0"


## Optional banner under the timer, e.g. "Sequence 4" or "Lap 2/3".
func hud_banner() -> String:
	return ""


## Extra per-player stat rows on the results screen.
func detail_rows() -> Array:
	return []


# --- AI --------------------------------------------------------------------

## Return the brain class for this game. Default is a competent generic brawler.
func ai_script() -> Script:
	return load("res://src/ai/brains/generic_brain.gd")


func create_ai(slot: int, difficulty: int) -> AIBrain:
	var script := ai_script()
	var brain: AIBrain = script.new() if script != null else AIBrain.new()
	brain.controller = self
	brain.configure(slot, ctx, difficulty, ctx.config.seed)
	return brain


# --- shared helpers for subclasses -----------------------------------------

func lives(slot: int) -> int:
	return _lives[slot] if slot < _lives.size() else 0


func spend_life(slot: int) -> int:
	if slot < _lives.size():
		_lives[slot] = maxi(0, _lives[slot] - 1)
	return lives(slot)


func spawn_position(slot: int) -> Vector3:
	var arena := ctx.arena as Arena
	if arena == null:
		return Vector3(0, 1.5, 0)
	var points := arena.spawn_points
	if points.is_empty():
		return arena.global_position + Vector3(0, 1.5, 0)
	return arena.global_position + points[slot % points.size()]


## Safe respawn point: prefers the player's own spawn, falls back toward the
## centre if that spot has since collapsed or shrunk out of the arena.
func safe_respawn_position(slot: int) -> Vector3:
	var arena := ctx.arena as Arena
	var p := spawn_position(slot)
	if arena == null or arena.is_inside(p, 1.0):
		return p
	return arena.global_position + Vector3(0, p.y, 0)


func _handle_out(slot: int) -> void:
	if not ctx.is_alive(slot):
		return
	ctx.bump_detail(slot, "falls")
	var attacker: int = ctx.fighter(slot).last_attacker() if ctx.fighter(slot) != null else -1
	if attacker >= 0 and attacker != slot:
		ctx.bump_detail(attacker, "knockouts")
		on_credited_knockout(attacker, slot)
	if eliminate_on_fall:
		if spend_life(slot) <= 0:
			ctx.eliminate(slot)
		else:
			_queue_respawn(slot)
	else:
		_queue_respawn(slot)


## Hook for games that score knockouts (Bumper Bowl, Duel Pit).
func on_credited_knockout(_attacker: int, _victim: int) -> void:
	pass


func _queue_respawn(slot: int) -> void:
	# Idempotent by construction, not just by convention: a fighter parked at
	# the holding position is still below `fall_y` and still processed by
	# `_check_out_of_bounds()` every tick. Without `f.alive = false`,
	# `Fighter.on_fell_out()` has nothing to stop it firing again on the very
	# next tick, which re-enters here, resets the countdown back to
	# `respawn_delay`, and re-teleports to the same spot — a fighter that falls
	# once in a non-eliminating game would never respawn at all. Setting
	# `alive = false` makes Fighter's own guard swallow the repeat signal, and
	# `respawn_at()` already flips it back to true when the wait is over.
	if _respawn_timers.has(slot):
		return
	var f := ctx.fighter(slot)
	if f != null and is_instance_valid(f):
		f.alive = false
		f.visible = false
		f.velocity = Vector3.ZERO
		f.global_position = Vector3(0, -500, 0)
	_respawn_timers[slot] = respawn_delay


## Called by MatchScene every live tick, before `tick()`.
func process_respawns(delta: float) -> void:
	if _respawn_timers.is_empty():
		return
	for slot in _respawn_timers.keys():
		_respawn_timers[slot] = float(_respawn_timers[slot]) - delta
		if float(_respawn_timers[slot]) <= 0.0:
			_respawn_timers.erase(slot)
			var f := ctx.fighter(slot)
			if f != null and is_instance_valid(f):
				f.reset_damage()
				f.respawn_at(safe_respawn_position(slot))


func reset_lives() -> void:
	_lives.fill(lives_per_player)
	_respawn_timers.clear()


## Convenience: spawn a mesh into the game's own subtree.
func attach(node: Node3D, pos: Vector3) -> Node3D:
	add_child(node)
	node.global_position = pos
	return node
