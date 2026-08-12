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
var powerups: PowerUpSystem

var phase: int = P.LOADING
var _phase_timer := 0.0
var _phase_locked := false
var _round_results: Array[MatchResult] = []
var _round_index := 0
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
var _tick_index := 0
var _aborted := false
var _sudden_death_used := false


# --- lifecycle -------------------------------------------------------------

func setup(args: Dictionary) -> void:
	config = args.get("config")
	_on_finished = args.get("on_finished", Callable())
	if config == null:
		Log.e("match started without a config", "Match")
		SceneRouter.go_to("main_menu", {}, false)
		return
	_tuning = Balance.table("tuning").get("match", {})
	_total_rounds = maxi(1, config.rounds)
	_replay_enabled = bool(UserSettings.get_value("replay_capture")) and config.context != MatchConfig.Context.TRAINING
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
		f.setup(p.slot, character, mode)
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
	for p in config.players:
		if not p.is_human:
			InputRouter.assign_virtual(p.slot)
		elif p.device_type == 1:
			InputRouter.assign_pad(p.slot, p.device_id)
		else:
			InputRouter.assign_keyboard(p.slot, p.device_id)


func teardown() -> void:
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


func _enter_phase(p: int) -> void:
	match p:
		P.INTRO:
			hud.announce(ctx.definition.display_name(), UIKit.ACCENT, 0.6)
			hud.show_hints(false)
			_phase_timer = float(_tuning.get("intro_seconds", 1.6))
		P.INSTRUCTIONS:
			hud.show_rules(true)
			var known := not UserSettings.should_show_tutorial(ctx.definition.id)
			_phase_timer = float(_tuning.get("instructions_seconds_known", 1.6)) if known \
				else float(_tuning.get("instructions_seconds", 4.0))
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
	for f in _fighters:
		f.control_enabled = true
	hud.announce(Loc.t("hud.go"), UIKit.OK, 0.4)
	AudioManager.play_sfx("go")
	controller.on_round_start()
	for b in _brains:
		if b != null:
			b.on_round_start()
	EventBus.round_started.emit(_round_index)


func _round_duration() -> float:
	if config.context == MatchConfig.Context.TRAINING:
		return 999.0
	if config.duration_override > 0.0:
		return config.duration_override
	return ctx.definition.duration


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
			_tick_live(delta)
		P.FINISH:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_set_phase(P.RESULTS)


func _process(delta: float) -> void:
	if hud != null and is_instance_valid(hud) and ctx != null:
		hud.tick(delta)


func _advance_timed_phase(delta: float) -> void:
	_phase_timer -= delta
	# Any button skips the intro and the rules card once a player is ready.
	if phase == P.INSTRUCTIONS and _any_human_pressed() and _phase_timer < float(_tuning.get("instructions_seconds", 4.0)) - 0.4:
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
	# 1. AI thinks
	for b in _brains:
		if b != null:
			b.tick(delta)
	# 2. fighters integrate (InputRouter has already refreshed frames)
	for f in _fighters:
		if is_instance_valid(f):
			f.tick(InputRouter.frame(f.slot), delta)
	_record_replay_tick()
	# 3. arena
	arena.tick(delta)
	arena.check_water(_fighters)
	# 4. rules
	controller.process_respawns(delta)
	controller.tick(delta)
	powerups.tick(delta)
	# 5. bounds
	_check_out_of_bounds()
	# 6. clock
	if not (DevTools.available() and DevTools.freeze_timer):
		ctx.time_left = maxf(0.0, ctx.time_left - delta)
	EventBus.match_time_changed.emit(ctx.time_left)
	hud.set_time(ctx.time_left, float(_tuning.get("hurry_time", 5.0)))
	_evaluate_end(delta)


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
		if f.global_position.y < arena.fall_y:
			f.on_fell_out()
			continue
		if arena.current_radius < arena.def.radius - 0.01 and not arena.is_inside(f.global_position, -1.2):
			# The ring shrank out from under them: give a shove outward so the
			# fall reads as a consequence rather than a teleport.
			f.apply_impulse(Vector3(f.global_position.x, 0, f.global_position.z).normalized() * 4.0)


func _on_fell_out(slot: int) -> void:
	if not MatchPhase.is_live(phase):
		return
	controller.on_fighter_fell(slot)


func _on_knocked_out(slot: int, by_slot: int) -> void:
	if not MatchPhase.is_live(phase):
		return
	controller.on_fighter_knocked_out(slot, by_slot)


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
	result.duration = _round_duration() - ctx.time_left
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
	Stats.record_match(config, aggregate)
	Achievements.evaluate_all()
	EventBus.match_finished.emit(aggregate)
	_set_phase(P.DONE)
	finished.emit(aggregate)
	if _on_finished.is_valid():
		# Tournament / adventure own the follow-up screen.
		_on_finished.call(aggregate)
	else:
		SceneRouter.go_to("results", {
			"result": aggregate,
			"config": config,
			"replay": _replay if _replay_enabled else [],
		}, false)


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
	card.custom_minimum_size = Vector2(520, 0)
	centre.add_child(card)
	var v := UIKit.vbox(12)
	card.add_child(v)
	v.add_child(UIKit.centered(Loc.t("pause.title"), UIKit.SIZE_HEADING, UIKit.ACCENT, true))
	if message != "":
		var m := UIKit.centered(message, UIKit.SIZE_SMALL, UIKit.DANGER)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.custom_minimum_size = Vector2(460, 0)
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
