extends RefCounted
## Shared presentation-only player snapshots with explicit game-world adapters.
## Clients never tick rules, collisions, scores or eliminations. Each additional
## game needs a world-state adapter before it enters Net.ONLINE_GAMES.
const P := MatchPhase.P
const GoalGuardReplica = preload("res://src/net/goal_guard_replica.gd")
const CollectibleReplica = preload("res://src/net/collectible_replica.gd")
const ZoneReplica = preload("res://src/net/zone_replica.gd")
const RelicReplica = preload("res://src/net/relic_replica.gd")
const COLLECTION_GAMES := {"gem_grab": "gem", "star_rush": "star"}
var _collectibles: Node3D
var _relic: Node3D
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
	elif scene.config.minigame_id == "zone_hold":
		packet["world"] = ZoneReplica.capture(scene.controller)
	elif scene.config.minigame_id == "relic_hold":
		packet["world"] = RelicReplica.capture(scene.controller)
	elif COLLECTION_GAMES.has(scene.config.minigame_id):
		var carrying: Array = []
		for fighter in scene.ctx.fighters:
			carrying.append(fighter.carrying)
		packet["world"] = {"items": CollectibleReplica.capture(scene.controller._items), "carrying": carrying}
	return packet


func accept(data: Dictionary, count: int, game_id: String = "ring_rumble") -> bool:
	if count < 2 or count > 4:
		return false
	if game_id == "goal_guard":
		if not GoalGuardReplica.valid(data.get("world"), count):
			return false
	elif game_id == "zone_hold":
		if not ZoneReplica.valid(data.get("world")):
			return false
	elif game_id == "relic_hold":
		if not RelicReplica.valid(data.get("world"), count):
			return false
	elif COLLECTION_GAMES.has(game_id):
		var world: Variant = data.get("world")
		if not world is Dictionary or not CollectibleReplica.valid(world.get("items"), COLLECTION_GAMES[game_id]):
			return false
		if not world.get("carrying") is Array or world.carrying.size() != count:
			return false
		for carried in world.carrying:
			if not _integer(carried, 0, 8):
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
	elif scene.config.minigame_id == "zone_hold":
		ZoneReplica.render(scene.controller, target.world)
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
