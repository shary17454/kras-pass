extends Node3D
## The match runtime. Owns the arena, the fighters, the camera, the HUD and the
## state machine; hosts one `MiniGameController`.
##
## Every transition goes through `_set_phase()`, which refuses illegal edges
## (see `MatchPhase.LEGAL`). Combined with `_phase_locked`, that removes the
## whole family of party-game race conditions where a last-second knockout and
## the clock hitting zero both try to end the round.
##
## Physics order per tick is fixed and deliberate:
##   1. AI brains think and publish input frames
##   2. InputRouter refreshes all frames (its own _physics_process, priority -100)
##   3. fighters integrate
##   4. arena hazards
##   5. mini-game rules
##   6. out-of-bounds checks
## Rules run *after* movement so a game never reacts to a stale position.

const P := MatchPhase.P

signal finished(result: MatchResult)

var config: MatchConfig
var ctx: MatchContext
var controller: MiniGameController
var arena: Arena
var camera: ArenaCamera
var hud: MatchHUD
var touch: TouchSource
var powerups: PowerUpSystem
var mutators: MutatorSystem
var machine: HoverMachine

var phase: int = P.LOADING
var _phase_timer := 0.0
## What `_phase_timer` was set to on entry. The skip grace period has to be
## measured against the timer actually running, not against a constant: a rules
## card for a game you already know starts at 3.5 s, which is below the
## first-time constant, so comparing to that constant made the card skippable
## on the very first frame and it flashed past before it could be read.
var _phase_duration := 0.0
var _phase_locked := false
var _round_results: Array[MatchResult] = []
var _round_index := 0
## Actual simulated seconds spent in PLAYING/SUDDEN_DEATH this round. Recorded
## directly rather than derived as `_round_duration() - ctx.time_left`: sudden
## death resets `ctx.time_left` to its own, larger budget
## (`sudden_death_seconds`), so that subtraction went negative for any round
## that reached sudden death — see docs/qa-scenarios.md.
var _round_elapsed := 0.0
var _total_rounds := 1
var _brains: Array = []
var _fighters: Array[Fighter] = []
var _countdown_value := 3
var _paused := false
var _pause_menu: CanvasLayer
var _on_finished: Callable = Callable()
var _tuning := {}
var _replay: Array = []
var _replay_enabled := false
## tick -> state hash, written while recording and checked while replaying.
var _checkpoints := {}
## tick -> authoritative positions/scores, written while recording.
var _keyframes := {}
## Decisions a world system took, keyed by tick. See ReplayData.events.
var _world_events := {}
## Largest positional correction playback had to apply, in metres.
var playback_drift := 0.0
## Notable events with tick stamps, fed to the highlight detector at the end.
var _timeline: Array = []

# --- playback --------------------------------------------------------------
## Set to replay a recording instead of playing. Every slot becomes virtual and
## is driven from the recorded frames; no AI brain thinks.
var playback: ReplayData = null
var playback_paused := false
var playback_speed := 1.0
var playback_tick := 0
var desync_tick := -1
var _speed_accum := 0.0
var _playback_frames: Array[InputFrame] = []

signal playback_progress(tick: int, total: int)
signal playback_finished()
signal desync_detected(tick: int)
var _tick_index := 0
var _aborted := false
var _sudden_death_used := false
var _noted_leader := -1
var _noted_last := -1
var _warn_second := -1


# --- lifecycle -------------------------------------------------------------

func setup(args: Dictionary) -> void:
	playback = args.get("replay")
	config = args.get("config")
	if playback != null:
		config = playback.to_config()
	_on_finished = args.get("on_finished", Callable())
	if config == null:
		Log.e("match started without a config", "Match")
		SceneRouter.go_to("main_menu", {}, false)
		return
	_tuning = Balance.table("tuning").get("match", {})
	_total_rounds = maxi(1, config.rounds)
	_replay_enabled = playback == null \
		and bool(UserSettings.get_value("replay_capture")) \
		and config.context != MatchConfig.Context.TRAINING
	DevTools.register_match(self)
	_build()


func _build() -> void:
	var def := config.definition()
	if def == null:
		Log.e("unknown mini-game '%s'" % config.minigame_id, "Match")
		_abort()
		return
	var arena_def := Registry.arena(config.arena_id)
	if arena_def == null:
		arena_def = Registry.arena(def.arena_ids[0]) if def.arena_ids.size() > 0 else null
	if arena_def == null:
		Log.e("mini-game '%s' has no usable arena" % def.id, "Match")
		_abort()
		return

	AudioManager.warm_match_bank()

	Fighter.clear_impact_state()
	ctx = MatchContext.new()
	ctx.config = config
	ctx.definition = def
	ctx.arena_def = arena_def
	ctx.rng = config.make_rng()
	ctx.scores.resize(config.player_count())
	ctx.scores.fill(0)
	ctx.alive.resize(config.player_count())
	ctx.alive.fill(true)
	for i in config.player_count():
		ctx.details.append({})

	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build(arena_def)
	arena.fighter_submerged.connect(_on_submerged)
	# Heavy hits fracture the floor they land on. The arena has no idea who the
	# players are, so the match layer resolves the victim and hands over a point.
	EventBus.player_hit.connect(_on_hit_for_floor)
	ctx.arena = arena

	var world := Node3D.new()
	world.name = "GameWorld"
	add_child(world)
	ctx.world_root = world

	var script: Script = load(def.controller_script)
	if script == null:
		Log.e("cannot load controller '%s'" % def.controller_script, "Match")
		_abort()
		return
	controller = script.new()
	controller.name = "MiniGame"
	world.add_child(controller)
	# Bind before spawning: `_spawn_fighters` asks the controller which verbs
	# this game allows, and those answers are derived from the definition.
	controller.bind(ctx)

	_spawn_fighters(def)
	ctx.fighters = _fighters

	powerups = PowerUpSystem.new()
	powerups.name = "PowerUps"
	world.add_child(powerups)
	ctx.powerups = powerups

	controller.setup(ctx)
	powerups.setup(ctx)
	# The hover machine delivers through PowerUpSystem, so it goes on after it.
	if controller.uses_machine():
		machine = HoverMachine.new()
		machine.name = "HoverMachine"
		world.add_child(machine)
		machine.setup(ctx)
		machine.scripted = playback != null
		machine.recorder = _record_world_event
		ctx.machine = machine
	# Mutators go on after the game has built itself, so a game that spawns its
	# own objects is never surprised mid-construction.
	mutators = MutatorSystem.new()
	mutators.setup(ctx, config.mutators, config.chaos)
	powerups.enabled = powerups.enabled and controller.uses_powerups()

	camera = ArenaCamera.new()
	camera.name = "Camera"
	add_child(camera)
	camera.targets = _fighters
	camera.configure(controller.camera_mode(), arena)
	camera.current = true

	hud = MatchHUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(ctx, controller)
	hud.set_round(_round_index, _total_rounds)

	_create_brains()
	_assign_inputs()
	_create_touch_controls()
	AudioManager.play_music(controller.music_track())
	EventBus.match_started.emit(config)
	_set_phase(P.INTRO)


func _spawn_fighters(def: MiniGameDef) -> void:
	var mode: int = controller.locomotion()
	for p in config.players:
		var f := Fighter.new()
		f.name = "Fighter%d" % p.slot
		add_child(f)
		f.add_to_group("fighters")
		var character := p.character()
		if character == null:
			character = Registry.characters()[p.slot % maxi(1, Registry.characters().size())]
		f.setup(p.slot, character, mode, arena.def.theme)
		f.can_jump = controller.allows_jump()
		f.can_attack = controller.allows_attack()
		f.can_dash = controller.allows_dash()
		var spawn := arena.global_position + arena.spawn_points[p.slot % arena.spawn_points.size()]
		f.global_position = spawn
		f.set_spawn(spawn)
		f.control_enabled = false
		f.knocked_out.connect(_on_knocked_out)
		f.fell_out.connect(_on_fell_out)
		_fighters.append(f)


func _create_brains() -> void:
	_brains.clear()
	if playback != null:
		for p in config.players:
			_brains.append(null)
		return
	for p in config.players:
		if p.is_human:
			_brains.append(null)
			continue
		var difficulty := p.ai_difficulty
		if DevTools.available() and DevTools.forced_ai_difficulty >= 0:
			difficulty = DevTools.forced_ai_difficulty
		_brains.append(controller.create_ai(p.slot, difficulty))


func _assign_inputs() -> void:
	InputRouter.clear_all()
	if playback != null:
		# The recording is the only input source; nothing polls hardware and no
		# brain thinks, which is what makes playback reproduce rather than
		# re-simulate.
		InputRouter.playback_mode = true
		_playback_frames.clear()
		for p in config.players:
			InputRouter.assign_virtual(p.slot)
			_playback_frames.append(InputFrame.new())
		return
	InputRouter.playback_mode = false
	for p in config.players:
		if not p.is_human:
			InputRouter.assign_virtual(p.slot)
		elif p.device_type == 1:
			InputRouter.assign_pad(p.slot, p.device_id)
		else:
			InputRouter.assign_keyboard(p.slot, p.device_id)


## On-screen controls for the first local human, when the platform wants them.
## Built from the mini-game's declared control profile, so no game knows it is
## being played with a thumb.
func _create_touch_controls() -> void:
	if playback != null or not TouchSource.should_show():
		return
	var humans := config.human_slots()
	if humans.is_empty():
		return
	var slot: int = humans[0]
	InputRouter.assign_touch(slot)
	var layer := CanvasLayer.new()
	layer.layer = 8   # under the HUD, over the world
	layer.name = "TouchLayer"
	add_child(layer)
	touch = TouchSource.new()
	touch.name = "TouchControls"
	layer.add_child(touch)
	touch.setup(slot, ctx.definition)


func teardown() -> void:
	InputRouter.playback_mode = false
	if controller != null and is_instance_valid(controller):
		controller.cleanup()
	InputRouter.clear_all()
	Pool.drain()
	AudioManager.stop_music(0.5)
	DevTools.register_match(null)


# --- state machine ---------------------------------------------------------

func _set_phase(next: int) -> void:
	if phase == next:
		return
	if not MatchPhase.can_go(phase, next):
		Log.w("illegal phase %s -> %s ignored" % [MatchPhase.name_of(phase), MatchPhase.name_of(next)], "Match")
		return
	phase = next
	ctx.phase = next
	_phase_timer = 0.0
	_phase_locked = false
	EventBus.match_phase_changed.emit(next)
	_enter_phase(next)
	_phase_duration = _phase_timer


func _enter_phase(p: int) -> void:
	match p:
		P.INTRO:
			hud.announce(ctx.definition.display_name(), UIKit.ACCENT, 0.6)
			hud.show_hints(false)
			_phase_timer = float(_tuning.get("intro_seconds", 1.6))
			# Nobody is watching an all-AI match — the balance simulator and the
			# automated match tests both run one — so the establishing shot is
			# dead time there, exactly like the rules card below.
			if config != null and config.human_slots().is_empty():
				_phase_timer = minf(_phase_timer, 0.6)
			camera.begin_intro(_phase_timer)
		P.INSTRUCTIONS:
			hud.show_rules(true)
			var known := not UserSettings.should_show_tutorial(ctx.definition.id)
			_phase_timer = float(_tuning.get("instructions_seconds_known", 3.5)) if known \
				else float(_tuning.get("instructions_seconds", 7.0))
			# An all-AI match has nobody reading the card. Holding it up is
			# pure dead time in demos, replays and the automated match tests.
			if config != null and config.human_slots().is_empty():
				_phase_timer = minf(_phase_timer, 1.0)
		P.COUNTDOWN:
			hud.show_rules(false)
			hud.show_hints(true)
			UserSettings.mark_tutorial_seen(ctx.definition.id)
			_countdown_value = int(_tuning.get("countdown_seconds", 3))
			_phase_timer = 1.0
			hud.announce(str(_countdown_value), UIKit.TEXT, 0.4)
			AudioManager.play_sfx("countdown")
			EventBus.countdown_tick.emit(_countdown_value)
		P.PLAYING:
			_begin_play()
		P.SUDDEN_DEATH:
			_sudden_death_used = true
			# The spec asks for the machine to lean on a stalemate rather than
			# watch one, so its cycle tightens for the decider.
			if machine != null and is_instance_valid(machine):
				machine.set_urgency(Balance.num("tuning", "machine.sudden_death_urgency", 1.7))
			_phase_timer = float(_tuning.get("sudden_death_seconds", 30.0))
			ctx.sudden_death = true
			ctx.time_left = _phase_timer
			hud.announce(Loc.t("hud.sudden_death"), UIKit.DANGER, 1.0)
			AudioManager.play_music("tension")
			AudioManager.play_sfx("whistle")
			controller.on_sudden_death()
			EventBus.sudden_death_started.emit()
		P.FINISH:
			_phase_timer = float(_tuning.get("finish_seconds", 2.2))
			hud.announce(Loc.t("hud.finish"), UIKit.ACCENT_2, 1.2)
			AudioManager.play_sfx("whistle")
			_freeze_fighters()
			controller.on_round_end()
		P.RESULTS:
			_finish_round()
		P.NEXT_ROUND:
			_phase_timer = float(_tuning.get("next_round_seconds", 1.2))
		P.DONE:
			pass


func _begin_play() -> void:
	ctx.time_left = _round_duration()
	_round_elapsed = 0.0
	for f in _fighters:
		f.control_enabled = true
	hud.announce(Loc.t("hud.go"), UIKit.OK, 0.4)
	AudioManager.play_sfx("go")
	_warn_second = -1
	controller.on_round_start()
	if machine != null and is_instance_valid(machine):
		machine.reset()
	for b in _brains:
		if b != null:
			b.on_round_start()
	EventBus.round_started.emit(_round_index)


func _round_duration() -> float:
	if config.context == MatchConfig.Context.TRAINING:
		return 999.0
	var scale := mutators.round_length_scale() if mutators != null else 1.0
	if config.duration_override > 0.0:
		return config.duration_override * scale
	return ctx.definition.duration * scale


# --- main loop -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if ctx == null or _aborted:
		return
	if _paused:
		return
	match phase:
		P.INTRO, P.INSTRUCTIONS, P.NEXT_ROUND:
			_advance_timed_phase(delta)
		P.COUNTDOWN:
			_tick_countdown(delta)
		P.PLAYING, P.SUDDEN_DEATH:
			if playback != null:
				_tick_playback(delta)
			else:
				_tick_live(delta)
		P.FINISH:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_set_phase(P.RESULTS)


func _process(delta: float) -> void:
	if hud != null and is_instance_valid(hud) and ctx != null:
		hud.tick(delta)


## Playback runs the same tick function, just more or fewer times per frame.
## Speeds are exact multiples of the recorded rate, so 2x is genuinely every
## tick twice rather than a bigger delta — the simulation never sees a
## different timestep.
func _tick_playback(delta: float) -> void:
	if playback_paused:
		return
	_speed_accum += playback_speed
	var steps := int(_speed_accum)
	_speed_accum -= float(steps)
	for i in steps:
		if phase == P.DONE:
			break
		_tick_live(delta)
	if playback_tick >= playback.tick_count():
		playback_finished.emit()


func _advance_timed_phase(delta: float) -> void:
	_phase_timer -= delta
	# Any button skips the intro and the rules card once a player is ready.
	if phase == P.INSTRUCTIONS and _any_human_pressed() and _phase_timer < _phase_duration - 0.4:
		_phase_timer = 0.0
	if _phase_timer > 0.0:
		return
	match phase:
		P.INTRO:
			_set_phase(P.INSTRUCTIONS)
		P.INSTRUCTIONS:
			_set_phase(P.COUNTDOWN)
		P.NEXT_ROUND:
			_start_next_round()


func _tick_countdown(delta: float) -> void:
	_phase_timer -= delta
	if _phase_timer > 0.0:
		return
	_countdown_value -= 1
	if _countdown_value <= 0:
		_set_phase(P.PLAYING)
		return
	_phase_timer = 1.0
	hud.announce(str(_countdown_value), UIKit.TEXT, 0.4)
	AudioManager.play_sfx("countdown", Vector3.ZERO, 1.0 + (3 - _countdown_value) * 0.1)
	EventBus.countdown_tick.emit(_countdown_value)


func _tick_live(delta: float) -> void:
	_tick_index += 1
	# 1. AI thinks — or, in playback, the recording speaks for it
	if playback != null:
		_feed_playback_tick()
	else:
		for b in _brains:
			if b != null:
				b.tick(delta)
	# 2. fighters integrate (InputRouter has already refreshed frames)
	for f in _fighters:
		if is_instance_valid(f):
			f.tick(InputRouter.frame(f.slot), delta)
	# Body-to-body shoves are resolved here, after every body has moved, so the
	# exchange does not depend on the order the fighters were ticked in.
	Fighter.resolve_impacts(delta)
	_record_replay_tick()
	_apply_world_events()
	_checkpoint_or_verify()
	_record_or_apply_keyframe()
	# 3. arena
	arena.tick(delta)
	arena.check_water(_fighters)
	# 4. rules
	controller.process_respawns(delta)
	controller.tick(delta)
	powerups.tick(delta)
	if machine != null and is_instance_valid(machine):
		machine.tick(delta)
	mutators.tick(delta)
	# 5. bounds
	_check_out_of_bounds()
	# 6. clock
	if not (DevTools.available() and DevTools.freeze_timer):
		ctx.time_left = maxf(0.0, ctx.time_left - delta)
		_round_elapsed += delta
	EventBus.match_time_changed.emit(ctx.time_left)
	hud.set_time(ctx.time_left, float(_tuning.get("hurry_time", 5.0)))
	_tick_time_warning()
	_evaluate_end(delta)


## The closing seconds, made audible. `warn_time` was in the tuning table from
## the start and nothing read it: a round simply ran out. One pip per remaining
## second, pitched up as it goes, and the music switches to the tension loop on
## the way in — the spec's "raise the tempo in the last ten seconds", and the
## one moment a party game must not be quiet.
func _tick_time_warning() -> void:
	var warn := float(_tuning.get("warn_time", 10.0))
	if ctx.time_left <= 0.0 or ctx.time_left > warn:
		return
	var second := int(ceil(ctx.time_left))
	if second == _warn_second:
		return
	var first := _warn_second == -1
	_warn_second = second
	AudioManager.play_sfx("tick", Vector3.ZERO, 1.0 + float(int(warn) - second) * 0.055)
	if first and not ctx.sudden_death and AudioManager.current_track() != "tension":
		AudioManager.play_music("tension", 0.7)
	EventBus.time_warning.emit(second)


## A world system's decision, stored against the tick it was taken on. Only
## while recording: during playback the decisions arrive from the file instead.
func _record_world_event(kind: String, data: Dictionary) -> void:
	if playback != null or not _replay_enabled:
		return
	var key := str(_tick_index)
	if not _world_events.has(key):
		_world_events[key] = []
	data["kind"] = kind
	_world_events[key].append(data)


## Hands this tick's recorded decisions back to whoever made them. Inputs and
## keyframes reproduce a body; only this reproduces a choice.
func _apply_world_events() -> void:
	if playback == null:
		return
	var list: Array = playback.events_at(_tick_index)
	if list.is_empty():
		return
	for e in list:
		if machine != null and is_instance_valid(machine):
			machine.apply_event(e)


## Records a state fingerprint every N ticks while playing, and compares
## against it while replaying. Godot physics is not bit-exact across builds, so
## rather than claim determinism this reports the exact tick where a replay
## stopped matching.
func _checkpoint_or_verify() -> void:
	if _tick_index % ReplayData.HASH_INTERVAL != 0:
		return
	var h := _state_hash()
	if playback == null:
		if _replay_enabled:
			_checkpoints[str(_tick_index)] = h
		return
	if desync_tick >= 0 or not playback.has_checkpoint(_tick_index):
		return
	if playback.checkpoint(_tick_index) != h and not playback.correctable():
		# Only meaningful for input-only recordings from before keyframes: a
		# correctable replay is re-synchronised every sixth tick, so a hash
		# mismatch between corrections is expected and not worth reporting.
		desync_tick = _tick_index
		Log.w("replay diverged at tick %d" % _tick_index, "Replay")
		desync_detected.emit(_tick_index)


## Deliberately coarse: a quarter of a metre horizontally, and vertical position
## ignored entirely.
##
## Godot's physics is not bit-exact — solver iteration order across four
## touching bodies varies enough that positions drift by centimetres even from
## identical inputs. A fingerprint tight enough to catch that would report a
## divergence on every replay while the match played out identically. This
## catches what actually matters: a fighter somewhere *else*, a different score,
## a different set of survivors.
const HASH_UNITS_PER_METRE := 4.0


func _state_hash() -> int:
	var acc := 2166136261
	for f in _fighters:
		if not is_instance_valid(f):
			continue
		for v in [f.global_position.x, f.global_position.z]:
			acc = (acc ^ int(round(v * HASH_UNITS_PER_METRE))) * 16777619
	for s in ctx.scores:
		acc = (acc ^ s) * 16777619
	for a in ctx.alive:
		acc = (acc ^ (1 if a else 0)) * 16777619
	return acc & 0x7FFFFFFF


## The hybrid half of replay. While recording, an authoritative snapshot is
## written ten times a second. While replaying, that snapshot is applied, which
## bounds drift to a tenth of a second instead of letting one shove compound
## into a different match.
func _record_or_apply_keyframe() -> void:
	if _tick_index % ReplayData.KEYFRAME_INTERVAL != 0:
		return
	if playback == null:
		if _replay_enabled:
			_keyframes[str(_tick_index)] = ReplayData.encode_keyframe(_fighters, ctx.scores, ctx.alive)
		return
	var frame := playback.keyframe(_tick_index)
	if frame.is_empty():
		return
	for i in mini(frame.size(), _fighters.size()):
		var f := _fighters[i]
		if not is_instance_valid(f):
			continue
		var want: Vector3 = frame[i]["position"]
		# Drift is only meaningful for a body that is actually in play. A player
		# waiting to respawn is parked at y=-500, so a respawn landing one tick
		# apart in the recording and the replay reported five hundred metres of
		# "drift" — the instrument, not the simulation. Compare the ones that
		# are on the field.
		var parked := f.global_position.y < arena.fall_y - 5.0 or want.y < arena.fall_y - 5.0
		if not parked and ctx.alive[i] and bool(frame[i]["alive"]):
			playback_drift = maxf(playback_drift, f.global_position.distance_to(want))
		f.global_position = want
		# Momentum is authoritative too. Without it a corrected body carries on
		# in the direction the replay had it going and is metres away again
		# before the next correction lands.
		f.velocity = frame[i].get("velocity", f.velocity)
		var should_live: bool = bool(frame[i]["alive"])
		if should_live != ctx.alive[i]:
			# Elimination is authoritative too: a replay must not keep someone
			# alive that the recording removed.
			if should_live:
				ctx.revive(i)
				f.visible = true
				f.alive = true
			else:
				ctx.eliminate(i)
		ctx.scores[i] = int(frame[i]["score"])


func _feed_playback_tick() -> void:
	if playback == null:
		return
	if not playback.apply_tick(playback_tick, _playback_frames):
		ctx.early_finish = true
		return
	for i in _playback_frames.size():
		InputRouter.apply_playback_frame(i, _playback_frames[i])
	playback_tick += 1
	playback_progress.emit(playback_tick, playback.tick_count())


func _evaluate_end(_delta: float) -> void:
	if _phase_locked:
		return
	if controller.is_round_over():
		_phase_locked = true
		_set_phase(P.FINISH)
		return
	if ctx.time_left > 0.0:
		return
	_phase_locked = true
	if phase == P.PLAYING and config.sudden_death and ctx.definition.supports_sudden_death and controller.is_tied():
		_set_phase(P.SUDDEN_DEATH)
	else:
		_set_phase(P.FINISH)


## Out-of-bounds is decided here, not by each game, so "fell off" means the same
## thing everywhere: below the arena's kill plane, or outside a ring that has
## shrunk past you.
func _check_out_of_bounds() -> void:
	for f in _fighters:
		if not is_instance_valid(f) or not f.alive or not ctx.is_alive(f.slot):
			continue
		# The fighter has no arena reference of its own, so the one place that
		# already measures every body against the rim also tells it how close
		# the drop is. That is what the panic pose reads.
		f.set_edge_margin(arena.edge_distance(f.global_position))
		f.set_surface_grip(arena.surface_grip(f.global_position))
		if f.global_position.y < arena.fall_y:
			f.on_fell_out()
			continue
		if arena.current_radius < arena.def.radius - 0.01 and not arena.is_inside(f.global_position, -1.2):
			# The ring shrank out from under them: give a shove outward so the
			# fall reads as a consequence rather than a teleport.
			f.apply_impulse(Vector3(f.global_position.x, 0, f.global_position.z).normalized() * 4.0)


func _note(kind: String, slot: int, value: float = 0.0, other: int = -1) -> void:
	if not _replay_enabled or _timeline.size() > 512:
		return
	_timeline.append({"tick": _tick_index, "type": kind, "slot": slot, "value": value, "other": other})


func _on_fell_out(slot: int) -> void:
	if not MatchPhase.is_live(phase):
		return
	_note("fell", slot)
	controller.on_fighter_fell(slot)


func _on_knocked_out(slot: int, by_slot: int) -> void:
	if not MatchPhase.is_live(phase):
		return
	controller.on_fighter_knocked_out(slot, by_slot)


## Leaves a crack where a shove landed. Arctic arenas only, capped, and ignored
## entirely when effects are reduced — the arena decides all of that.
func _on_hit_for_floor(_attacker: int, victim: int, strength: float) -> void:
	if arena == null or not is_instance_valid(arena) or not MatchPhase.is_live(phase):
		return
	var f := ctx.fighter(victim)
	if f != null and is_instance_valid(f):
		arena.spawn_impact_crack(f.global_position, strength)


func _on_submerged(f) -> void:
	if not MatchPhase.is_live(phase) or f == null:
		return
	controller.on_fighter_fell(f.slot)


func _freeze_fighters() -> void:
	for f in _fighters:
		if is_instance_valid(f):
			f.control_enabled = false
			f.velocity = Vector3.ZERO


func _any_human_pressed() -> bool:
	for p in config.players:
		if p.is_human and InputRouter.frame(p.slot).any_pressed():
			return true
	return false


# --- round / match completion ----------------------------------------------

func _finish_round() -> void:
	var scores: Array[int] = controller.compute_scores()
	var result := MatchResult.make(config.minigame_id, config.arena_id, scores, ctx.definition.higher_is_better())
	result.round_index = _round_index
	result.duration = _round_elapsed
	result.elimination_order = ctx.elimination_order.duplicate()
	result.sudden_death_used = _sudden_death_used
	result.details = ctx.details.duplicate(true)
	_round_results.append(result)
	EventBus.round_finished.emit(result)
	_celebrate(result)

	if _round_index + 1 < _total_rounds:
		_set_phase(P.NEXT_ROUND)
	else:
		_complete_match()


func _celebrate(result: MatchResult) -> void:
	var winners := result.winners()
	for f in _fighters:
		if is_instance_valid(f):
			f.celebrate(winners.has(f.slot))
	AudioManager.play_sfx("win" if winners.size() > 0 else "lose")


func _complete_match() -> void:
	var aggregate := MatchResult.aggregate(config.minigame_id, _round_results, ctx.definition.higher_is_better())
	aggregate.arena_id = config.arena_id
	aggregate.finished_naturally = not _aborted
	if playback == null:
		Stats.record_match(config, aggregate)
		Achievements.evaluate_all()
		_store_replay(aggregate)
	EventBus.match_finished.emit(aggregate)
	_set_phase(P.DONE)
	finished.emit(aggregate)
	if playback != null:
		# A replay ends where the recording ends. It must not push the player
		# into a results screen for a match they did not just play.
		playback_finished.emit()
		return
	if _on_finished.is_valid():
		# Tournament / adventure own the follow-up screen.
		_on_finished.call(aggregate)
	else:
		SceneRouter.go_to("results", {
			"result": aggregate,
			"config": config,
			"replay": _replay if _replay_enabled else [],
		}, false)


## Turn the recording into a stored replay, with its highlights already found.
func _store_replay(result: MatchResult) -> void:
	if not _replay_enabled or _replay.is_empty():
		return
	var data := ReplayData.from_match(config, _replay, _checkpoints, _keyframes, result, _world_events)
	data.highlights = ReplayHighlights.detect(_timeline, result, _replay.size(), data.tick_rate)
	Replays.save(data)


# --- playback controls -----------------------------------------------------

func pb_toggle_pause() -> void:
	playback_paused = not playback_paused


func pb_set_speed(value: float) -> void:
	playback_speed = clampf(value, 0.25, 4.0)


## Seeking re-simulates from the start rather than storing snapshots: the whole
## point of an input recording is that the state is derivable, and a 90-second
## round fast-forwards in well under a second.
func pb_seek(target_tick: int) -> void:
	if playback == null:
		return
	target_tick = clampi(target_tick, 0, playback.tick_count())
	if target_tick < playback_tick:
		_restart_playback()
	var guard := 0
	while playback_tick < target_tick and phase != P.DONE and guard < 60 * 60 * 10:
		_tick_live(1.0 / 60.0)
		guard += 1


func _restart_playback() -> void:
	playback_tick = 0
	desync_tick = -1
	playback_drift = 0.0
	_round_index = 0
	_round_results.clear()
	_phase_locked = false
	ctx.early_finish = false
	ctx.elimination_order.clear()
	ctx.alive.fill(true)
	ctx.scores.fill(0)
	for i in ctx.details.size():
		ctx.details[i] = {}
	arena.reset_hazards()
	powerups.clear_all()
	controller.reset_lives()
	for f in _fighters:
		if is_instance_valid(f):
			f.reset_damage()
			f.respawn_at(arena.global_position + arena.spawn_points[f.slot % arena.spawn_points.size()])
			f.control_enabled = true
			f.carrying = 0


func _start_next_round() -> void:
	_round_index += 1
	_sudden_death_used = false
	ctx.sudden_death = false
	ctx.early_finish = false
	ctx.elimination_order.clear()
	ctx.alive.fill(true)
	ctx.scores.fill(0)
	for i in ctx.details.size():
		ctx.details[i] = {}
	arena.reset_hazards()
	powerups.clear_all()
	controller.reset_lives()
	for f in _fighters:
		if is_instance_valid(f):
			f.reset_damage()
			f.respawn_at(arena.global_position + arena.spawn_points[f.slot % arena.spawn_points.size()])
			f.control_enabled = false
			f.carrying = 0
	controller.on_round_start()
	hud.set_round(_round_index, _total_rounds)
	AudioManager.play_music(controller.music_track())
	_set_phase(P.INSTRUCTIONS)


func _abort() -> void:
	_aborted = true
	SceneRouter.go_to("main_menu", {}, false)


# --- pause -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if ctx == null or phase == P.DONE:
		return
	if event.is_action_pressed("pause") and MatchPhase.is_live(phase):
		_toggle_pause()


func _toggle_pause() -> void:
	_paused = not _paused
	if _paused:
		_show_pause_menu()
		AudioManager.play_ui("ui_back")
	else:
		if _pause_menu != null and is_instance_valid(_pause_menu):
			_pause_menu.queue_free()
			_pause_menu = null


func _show_pause_menu(message: String = "") -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_pause_menu = layer
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(centre)
	var card := UIKit.panel(UIKit.PANEL, 22)
	card.custom_minimum_size = Vector2(640, 0)
	centre.add_child(card)
	var v := UIKit.vbox(12)
	card.add_child(v)
	v.add_child(UIKit.centered(Loc.t("pause.title"), UIKit.SIZE_HEADING, UIKit.ACCENT, true))
	if message != "":
		var m := UIKit.centered(message, UIKit.SIZE_SMALL, UIKit.DANGER)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.custom_minimum_size = Vector2(570, 0)
		v.add_child(m)
	var resume := UIKit.button(Loc.t("pause.resume"))
	resume.pressed.connect(_toggle_pause)
	v.add_child(resume)
	var restart := UIKit.button(Loc.t("pause.restart"))
	restart.pressed.connect(func():
		_toggle_pause()
		debug_restart_round())
	v.add_child(restart)
	var settings := UIKit.button(Loc.t("pause.settings"))
	settings.pressed.connect(func(): SceneRouter.go_to("settings"))
	v.add_child(settings)
	var quit := UIKit.button(Loc.t("pause.quit_match"))
	quit.pressed.connect(func():
		_paused = false
		_aborted = true
		SceneRouter.go_to("main_menu", {}, false))
	v.add_child(quit)
	resume.grab_focus()
	UIKit.animate_in(card)


func _ready() -> void:
	EventBus.player_device_lost.connect(_on_device_lost)
	Platform.app_backgrounded.connect(_on_app_backgrounded)
	EventBus.player_hit.connect(func(by, victim, strength): _note("hit", by, strength, victim))
	EventBus.player_eliminated.connect(func(slot, place): _note("eliminated", slot, float(place)))
	EventBus.score_changed.connect(_on_score_noted)


## Lead and last-place changes are what the comeback and late-swing detectors
## look for, so they are derived here rather than polled.
func _on_score_noted(_slot: int, _value: int) -> void:
	if ctx == null or not _replay_enabled:
		return
	var leader := ctx.leader_slot()
	if leader != _noted_leader:
		_noted_leader = leader
		_note("lead", leader)
	var worst := -1
	var worst_score := 2147483647
	for i in ctx.scores.size():
		if ctx.scores[i] < worst_score:
			worst_score = ctx.scores[i]
			worst = i
	if worst != _noted_last:
		_noted_last = worst
		_note("last_place", worst)


## iOS can take the app away at any moment. Pausing on the way out means the
## player comes back to the round they left, not to a result they never saw.
func _on_app_backgrounded() -> void:
	if ctx == null or not MatchPhase.is_live(phase) or _paused:
		return
	_paused = true
	_show_pause_menu()


func _on_device_lost(slot: int) -> void:
	if ctx == null or not MatchPhase.is_live(phase) or _paused:
		return
	var p := config.player_at(slot)
	if p == null or not p.is_human:
		return
	_paused = true
	_show_pause_menu(Loc.t("pause.device_lost"))


# --- replay ----------------------------------------------------------------

## Records one input frame per player per tick. At 5 bytes per player that is
## ~1.2 KB per second for four players — cheap enough to keep on by default and
## enough to replay a round deterministically once playback is wired up.
func _record_replay_tick() -> void:
	if not _replay_enabled:
		return
	if _replay.size() > 60 * 60 * 4:  # hard cap: four minutes
		return
	var packet := PackedByteArray()
	for f in _fighters:
		packet.append_array(InputRouter.frame(f.slot).encode())
	_replay.append(packet)


func replay_data() -> Array:
	return _replay


# --- debug hooks (called by DevTools) --------------------------------------

func debug_add_score(slot: int, amount: int) -> void:
	if ctx != null:
		ctx.add_score(slot, amount)


func debug_end_round() -> void:
	if MatchPhase.is_live(phase):
		ctx.time_left = 0.0
		ctx.early_finish = true


func debug_restart_round() -> void:
	if phase == P.DONE:
		return
	_round_index = maxi(0, _round_index - 1)
	_round_results.pop_back()
	_phase_locked = false
	phase = P.NEXT_ROUND
	_start_next_round()
