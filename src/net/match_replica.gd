extends RefCounted
## Shared presentation-only player snapshots with explicit game-world adapters.
## Clients never tick rules, collisions, scores or eliminations. Each additional
## game needs a world-state adapter before it enters Net.ONLINE_GAMES.
const P := MatchPhase.P
const GoalGuardReplica = preload("res://src/net/goal_guard_replica.gd")
const MagnetReplica = preload("res://src/net/magnet_replica.gd")
const StormReplica = preload("res://src/net/storm_replica.gd")
const SkyReplica = preload("res://src/net/sky_replica.gd")
const CrumbleReplica = preload("res://src/net/crumble_replica.gd")
const BlastReplica = preload("res://src/net/blast_replica.gd")
const ColorReplica = preload("res://src/net/color_replica.gd")
const DrawReplica = preload("res://src/net/draw_replica.gd")
const EchoReplica = preload("res://src/net/echo_replica.gd")
const CrateReplica = preload("res://src/net/crate_replica.gd")
const HurdleReplica = preload("res://src/net/hurdle_replica.gd")
const TideReplica = preload("res://src/net/tide_replica.gd")
const SweeperReplica = preload("res://src/net/sweeper_replica.gd")
const DuelReplica = preload("res://src/net/duel_replica.gd")
const BumperReplica = preload("res://src/net/bumper_replica.gd")
const DuoReplica = preload("res://src/net/duo_replica.gd")
const FloeReplica = preload("res://src/net/floe_replica.gd")
const TurretReplica = preload("res://src/net/turret_replica.gd")
const TankReplica = preload("res://src/net/tank_replica.gd")
const ScrapReplica = preload("res://src/net/scrap_replica.gd")
const FawdaReplica = preload("res://src/net/fawda_replica.gd")
const KartReplica = preload("res://src/net/kart_replica.gd")
const CollectibleReplica = preload("res://src/net/collectible_replica.gd")
const ZoneReplica = preload("res://src/net/zone_replica.gd")
const RelicReplica = preload("res://src/net/relic_replica.gd")
const TagReplica = preload("res://src/net/tag_replica.gd")
const PaintReplica = preload("res://src/net/paint_replica.gd")
const SaboteurReplica = preload("res://src/net/saboteur_replica.gd")
const PAINT_GAMES := ["paint_grid", "mnatiq"]
const COLLECTION_GAMES := {"gem_grab": "gem", "star_rush": "star", "crate_relay": "crate"}
var _collectibles: Node3D
var _relic: Node3D
var _saboteur: RefCounted
var _storm: RefCounted
var _sky: RefCounted
var _crumble: RefCounted
var _blast: RefCounted
var _color: RefCounted
var _draw: RefCounted
var _echo: RefCounted
var _crates: Node3D
var _hurdle: RefCounted
var _bumper: RefCounted
var _duo: RefCounted
var _turret: Node3D
var _tank: Node3D
var _scrap: RefCounted
var _fawda: Node3D
var _kart: Node3D
var _event_received_at := 0
var target: Dictionary = {}
var received_at := 0
var _last_phase := -1
var _last_round := -1
var _countdown := -1


func capture(scene: Node) -> Dictionary:
	var fighters: Array = []
	for f in scene.ctx.fighters:
		fighters.append({"position": _vec(f.global_position), "velocity": _vec(f.velocity),
			"facing": _vec(f.facing), "health": f.health, "visible": f.visible,
			"alive": f.alive, "dash": f._dash_time, "attack": f._attack_time, "stun": f._stun})
	var packet := {"fighters": fighters, "scores": Array(scene.ctx.scores), "alive": Array(scene.ctx.alive),
		"time": scene.ctx.time_left, "phase": scene.phase, "round": scene._round_index,
		"countdown": scene._countdown_value, "radius": scene.arena.current_radius}
	if scene.config.minigame_id == "goal_guard":
		packet["world"] = GoalGuardReplica.capture(scene.controller)
	elif scene.config.minigame_id == "hurdle_dash":
		packet["world"] = HurdleReplica.capture(scene.controller)
	elif scene.config.minigame_id == "rising_tide":
		packet["world"] = TideReplica.capture(scene.controller)
	elif scene.config.minigame_id == "sweeper_storm":
		packet["world"] = SweeperReplica.capture(scene.controller)
	elif scene.config.minigame_id == "duel_pit":
		packet["world"] = DuelReplica.capture(scene.controller)
	elif scene.config.minigame_id == "bumper_bowl":
		packet["world"] = BumperReplica.capture(scene.controller)
	elif scene.config.minigame_id == "duo_clash":
		packet["world"] = DuoReplica.capture(scene.controller)
	elif scene.config.minigame_id == "drift_floes":
		packet["world"] = FloeReplica.capture(scene.controller)
	elif scene.config.minigame_id == "turret_duel":
		packet["world"] = TurretReplica.capture(scene.controller)
	elif scene.config.minigame_id == "tank_arena":
		packet["world"] = TankReplica.capture(scene.controller)
	elif scene.config.minigame_id == "scrap_karts":
		packet["world"] = ScrapReplica.capture(scene.controller)
	elif scene.config.minigame_id == "fawda":
		packet["world"] = FawdaReplica.capture(scene.controller)
	elif scene.config.minigame_id == "kart_sprint":
		packet["world"] = KartReplica.capture(scene.controller)
	elif scene.config.minigame_id == "magnet_court":
		packet["world"] = MagnetReplica.capture(scene.controller)
	elif scene.config.minigame_id == "storm_heart":
		packet["world"] = StormReplica.capture(scene.controller)
	elif scene.config.minigame_id == "sky_court":
		packet["world"] = SkyReplica.capture(scene.controller)
	elif scene.config.minigame_id == "crumble_court":
		packet["world"] = CrumbleReplica.capture(scene.controller)
	elif scene.config.minigame_id == "blast_ball":
		packet["world"] = BlastReplica.capture(scene.controller)
	elif scene.config.minigame_id == "color_stand":
		packet["world"] = ColorReplica.capture(scene.controller)
	elif scene.config.minigame_id == "quick_draw":
		packet["world"] = DrawReplica.capture(scene.controller)
	elif scene.config.minigame_id == "symbol_echo":
		packet["world"] = EchoReplica.capture(scene.controller)
	elif scene.config.minigame_id in ["crate_smash", "lab_crates"]:
		packet["world"] = CrateReplica.capture(scene.controller, scene.config.minigame_id == "lab_crates")
	elif scene.config.minigame_id == "zone_hold":
		packet["world"] = ZoneReplica.capture(scene.controller)
	elif scene.config.minigame_id == "relic_hold":
		packet["world"] = RelicReplica.capture(scene.controller)
	elif scene.config.minigame_id == "tag_hunt":
		packet["world"] = TagReplica.capture(scene.controller)
	elif PAINT_GAMES.has(scene.config.minigame_id):
		packet["world"] = PaintReplica.capture(scene.controller)
	elif scene.config.minigame_id == "mukharrib":
		packet["world"] = SaboteurReplica.capture(scene.controller)
	elif COLLECTION_GAMES.has(scene.config.minigame_id):
		var carrying: Array = []
		for fighter in scene.ctx.fighters:
			carrying.append(fighter.carrying)
		packet["world"] = {"items": CollectibleReplica.capture(scene.controller._items), "carrying": carrying}
	return packet


func accept(data: Dictionary, count: int, game_id: String = "ring_rumble", arena_id := "", expected_checkpoints: int = 0) -> bool:
	if count < 2 or count > 4:
		return false
	if game_id == "goal_guard":
		if not GoalGuardReplica.valid(data.get("world"), count):
			return false
	elif game_id == "kart_sprint":
		if not KartReplica.valid(data.get("world"), count, expected_checkpoints):
			return false
	elif game_id == "hurdle_dash":
		if not HurdleReplica.valid(data.get("world"), count):
			return false
	elif game_id == "rising_tide":
		if not TideReplica.valid(data.get("world")):
			return false
	elif game_id == "sweeper_storm":
		if not SweeperReplica.valid(data.get("world")):
			return false
	elif game_id == "duel_pit":
		if not DuelReplica.valid(data.get("world"), count):
			return false
	elif game_id == "bumper_bowl":
		if not BumperReplica.valid(data.get("world")):
			return false
	elif game_id == "duo_clash":
		if not DuoReplica.valid(data.get("world"), count, arena_id):
			return false
	elif game_id == "drift_floes":
		if not FloeReplica.valid(data.get("world")):
			return false
	elif game_id == "turret_duel":
		if not TurretReplica.valid(data.get("world"), count):
			return false
	elif game_id == "tank_arena":
		if not TankReplica.valid(data.get("world"), count):
			return false
	elif game_id == "scrap_karts":
		if not ScrapReplica.valid(data.get("world"), count):
			return false
	elif game_id == "fawda":
		if not FawdaReplica.valid(data.get("world"), count):
			return false
	elif game_id == "magnet_court":
		if not MagnetReplica.valid(data.get("world"), count):
			return false
	elif game_id == "storm_heart":
		if not StormReplica.valid(data.get("world"), count):
			return false
	elif game_id == "sky_court":
		if not SkyReplica.valid(data.get("world"), count):
			return false
	elif game_id == "crumble_court":
		if not CrumbleReplica.valid(data.get("world")):
			return false
	elif game_id == "blast_ball":
		if not BlastReplica.valid(data.get("world")):
			return false
	elif game_id == "color_stand":
		if not ColorReplica.valid(data.get("world")):
			return false
	elif game_id == "quick_draw":
		if not DrawReplica.valid(data.get("world"), count):
			return false
	elif game_id == "symbol_echo":
		if not EchoReplica.valid(data.get("world"), count):
			return false
	elif game_id in ["crate_smash", "lab_crates"]:
		if not CrateReplica.valid(data.get("world"), count, game_id == "lab_crates"):
			return false
	elif game_id == "zone_hold":
		if not ZoneReplica.valid(data.get("world")):
			return false
	elif game_id == "relic_hold":
		if not RelicReplica.valid(data.get("world"), count):
			return false
	elif game_id == "tag_hunt":
		if not TagReplica.valid(data.get("world"), count):
			return false
	elif PAINT_GAMES.has(game_id):
		if not PaintReplica.valid(data.get("world"), count):
			return false
	elif game_id == "mukharrib":
		if not SaboteurReplica.valid(data.get("world"), count):
			return false
	elif COLLECTION_GAMES.has(game_id):
		var world: Variant = data.get("world")
		if not world is Dictionary or not CollectibleReplica.valid(world.get("items"), COLLECTION_GAMES[game_id]):
			return false
		if not world.get("carrying") is Array or world.carrying.size() != count:
			return false
		if game_id == "crate_relay" and (world.size() != 2 or world.items.size() > 8):
			return false
		for carried in world.carrying:
			if not _integer(carried, 0, 1 if game_id == "crate_relay" else 8):
				return false
	elif game_id != "ring_rumble":
		return false
	for key in ["fighters", "scores", "alive"]:
		if not data.get(key) is Array or data[key].size() != count:
			return false
	for key in ["time", "phase", "round", "countdown", "radius"]:
		if not _number(data.get(key)):
			return false
	if not _integer(data.phase, 0, P.PAUSED) or not _integer(data.round, 0, 9) \
			or not _integer(data.countdown, 0, 10):
		return false
	if float(data.radius) < 0.1 or float(data.radius) > 1000.0 or float(data.time) < 0.0 or float(data.time) > 3600.0:
		return false
	for i in count:
		if not _integer(data.scores[i], -1000000, 1000000) or not data.alive[i] is bool:
			return false
		var row: Variant = data.fighters[i]
		if not row is Dictionary:
			return false
		for key in ["position", "velocity", "facing"]:
			if not row.get(key) is Array or row[key].size() != 3:
				return false
			for component in row[key]:
				if not _number(component) or absf(float(component)) > 10000.0:
					return false
		for key in ["health", "dash", "attack", "stun"]:
			if not _number(row.get(key)) or absf(float(row[key])) > 10000.0:
				return false
		if not row.get("visible") is bool or not row.get("alive") is bool:
			return false
	target = data.duplicate(true)
	received_at = Time.get_ticks_msec()
	return true


func render(scene: Node, delta: float) -> void:
	if target.is_empty():
		return
	if scene.config.minigame_id == "kart_sprint" and int(target.world.checkpoints) != scene.controller._checkpoints.size():
		return
	var snap := _last_round != int(target.round)
	for i in scene.ctx.fighters.size():
		var f: Fighter = scene.ctx.fighters[i]
		var row: Dictionary = target.fighters[i]
		var position := Vector3(row.position[0], row.position[1], row.position[2])
		f.global_position = position if snap or f.global_position.distance_to(position) > 6.0 \
			else f.global_position.lerp(position, clampf(delta * 22.0, 0.0, 1.0))
		f.velocity = Vector3(row.velocity[0], row.velocity[1], row.velocity[2])
		f.facing = Vector3(row.facing[0], row.facing[1], row.facing[2])
		f.health = float(row.health)
		f.alive = bool(row.alive)
		f.visible = bool(row.visible)
		f._dash_time = float(row.dash)
		f._attack_time = float(row.attack)
		f._stun = float(row.stun)
		f._update_visual(delta, f.velocity)
		scene.ctx.scores[i] = int(target.scores[i])
		scene.ctx.alive[i] = bool(target.alive[i])
	if scene.config.minigame_id == "goal_guard":
		GoalGuardReplica.render(scene.controller, target.world, delta, snap)
	elif scene.config.minigame_id == "magnet_court":
		MagnetReplica.render(scene.controller, target.world, delta, snap)
	elif scene.config.minigame_id == "storm_heart":
		if _storm == null:
			_storm = StormReplica.new()
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_storm.render(scene.controller, target.world, delta, snap, fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "zone_hold":
		ZoneReplica.render(scene.controller, target.world)
	elif scene.config.minigame_id == "rising_tide":
		TideReplica.render(scene.controller, target.world)
	elif scene.config.minigame_id == "sweeper_storm":
		SweeperReplica.render(scene.controller, target.world)
	elif scene.config.minigame_id == "drift_floes":
		FloeReplica.render(scene.controller, target.world, delta, snap)
	elif scene.config.minigame_id == "turret_duel":
		if not is_instance_valid(_turret):
			_turret = TurretReplica.new()
			scene.ctx.world_root.add_child(_turret)
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_turret.render(scene.controller, target.world, int(target.round), delta, snap, fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "tank_arena":
		if not is_instance_valid(_tank):
			_tank = TankReplica.new()
			scene.ctx.world_root.add_child(_tank)
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_tank.playing = int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH]
		_tank.render(scene.controller, target.world, int(target.round), delta, snap, fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "scrap_karts":
		if _scrap == null:
			_scrap = ScrapReplica.new()
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_scrap.render(scene.controller, target.world, int(target.round), fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "fawda":
		if not is_instance_valid(_fawda):
			_fawda = FawdaReplica.new()
			scene.add_child(_fawda)
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_fawda.render(scene.controller, target.world, int(target.round), fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "kart_sprint":
		if not is_instance_valid(_kart):
			_kart = KartReplica.new()
			scene.add_child(_kart)
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_kart.render(scene.controller, target.world, int(target.round), fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH, P.FINISH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "duel_pit":
		DuelReplica.render(scene.controller, target.world)
	elif scene.config.minigame_id == "bumper_bowl":
		if _bumper == null:
			_bumper = BumperReplica.new()
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_bumper.render(scene.controller, target.world, int(target.round), fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "duo_clash":
		if _duo == null:
			_duo = DuoReplica.new()
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_duo.render(scene.controller, target.world, int(target.round), fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "hurdle_dash":
		if _hurdle == null:
			_hurdle = HurdleReplica.new()
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_hurdle.render(scene.controller, target.world, int(target.round), fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "color_stand":
		if _color == null:
			_color = ColorReplica.new()
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_color.render(scene.controller, target.world, fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "symbol_echo":
		if _echo == null:
			_echo = EchoReplica.new()
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_echo.render(scene.controller, target.world, fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id in ["crate_smash", "lab_crates"]:
		if not is_instance_valid(_crates):
			_crates = CrateReplica.new()
			scene.ctx.world_root.add_child(_crates)
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_crates.render(scene.controller, target.world, delta, snap, fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "quick_draw":
		if _draw == null:
			_draw = DrawReplica.new()
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_draw.render(scene.controller, target.world, fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "blast_ball":
		if _blast == null:
			_blast = BlastReplica.new()
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_blast.render(scene.controller, target.world, delta, snap, fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "crumble_court":
		if _crumble == null:
			_crumble = CrumbleReplica.new()
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_crumble.render(scene.controller, target.world, fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "sky_court":
		if _sky == null:
			_sky = SkyReplica.new()
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_sky.render(scene.controller, target.world, delta, snap, fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "tag_hunt":
		TagReplica.render(scene.controller, target.world, delta)
	elif PAINT_GAMES.has(scene.config.minigame_id):
		PaintReplica.render(scene.controller, target.world)
	elif scene.config.minigame_id == "mukharrib":
		if _saboteur == null:
			_saboteur = SaboteurReplica.new()
		var fresh := _event_received_at > 0 and received_at - _event_received_at <= 1000
		_saboteur.render(scene.controller, target.world, fresh and not snap and int(target.phase) in [P.PLAYING, P.SUDDEN_DEATH])
		_event_received_at = received_at
	elif scene.config.minigame_id == "relic_hold":
		if not is_instance_valid(_relic):
			_relic = RelicReplica.new()
			scene.ctx.world_root.add_child(_relic)
		_relic.render(scene.controller, target.world, delta)
	elif COLLECTION_GAMES.has(scene.config.minigame_id):
		if not is_instance_valid(_collectibles):
			scene.controller.cleanup()
			_collectibles = CollectibleReplica.new()
			scene.ctx.world_root.add_child(_collectibles)
		_collectibles.apply(target.world.items)
		for slot in scene.ctx.player_count():
			scene.ctx.fighters[slot].carrying = int(target.world.carrying[slot])
		if scene.config.minigame_id == "crate_relay":
			scene.controller._update_carry_visuals()
	scene.arena.apply_network_radius(float(target.radius))
	scene.arena._tick_arctic_water(delta)
	scene.ctx.time_left = float(target.time)
	scene.hud.set_time(scene.ctx.time_left, 5.0)
	scene.phase = int(target.phase)
	scene.ctx.phase = scene.phase
	scene._round_index = int(target.round)
	scene.hud.set_round(scene._round_index, scene.config.rounds)
	if _last_phase != scene.phase or snap:
		scene.hud.show_rules(scene.phase == P.INSTRUCTIONS)
		scene.hud.show_hints(scene.phase not in [P.INTRO, P.INSTRUCTIONS])
		for source in scene.touch_sources:
			var contenders: Array = scene.config.rule("online_contenders", [])
			var spectator := not contenders.is_empty() and not contenders.has(Net.local_slot())
			source.visible = not spectator and scene.phase not in [P.INTRO, P.INSTRUCTIONS]
			source.set_process_input(source.visible)
		if scene.phase == P.PLAYING:
			scene.hud.announce(Loc.t("hud.go"), UIKit.OK, 0.4)
			AudioManager.play_sfx("go")
		elif scene.phase == P.FINISH:
			scene.hud.announce(Loc.t("hud.finish"), UIKit.ACCENT, 1.0)
			AudioManager.play_sfx("whistle")
		elif scene.phase == P.SUDDEN_DEATH:
			scene.hud.announce(Loc.t("hud.sudden_death"), UIKit.DANGER, 1.0)
	if scene.phase == P.COUNTDOWN and _countdown != int(target.countdown):
		_countdown = int(target.countdown)
		scene.hud.announce(str(_countdown), UIKit.TEXT, 0.4)
		AudioManager.play_sfx("countdown")
	if scene.phase != P.COUNTDOWN:
		_countdown = -1
	_last_phase = scene.phase
	_last_round = int(target.round)


static func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value) and float(value) == floorf(float(value)) \
		and value >= minimum and value <= maximum
