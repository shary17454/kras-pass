extends RefCounted
## Presentation-only snapshots for the online push variant. Clients never tick
## rules, collisions, scores or eliminations. Other games require their own
## world-state adapter before they can enter Net.ONLINE_GAMES.
const P := MatchPhase.P
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
	return {"fighters": fighters, "scores": Array(scene.ctx.scores), "alive": Array(scene.ctx.alive),
		"time": scene.ctx.time_left, "phase": scene.phase, "round": scene._round_index,
		"countdown": scene._countdown_value, "radius": scene.arena.current_radius}


func accept(data: Dictionary, count: int) -> bool:
	for key in ["fighters", "scores", "alive"]:
		if not data.get(key) is Array or data[key].size() != count:
			return false
	for key in ["time", "phase", "round", "countdown", "radius"]:
		if not _number(data.get(key)):
			return false
	if int(data.phase) < 0 or int(data.phase) > P.PAUSED or int(data.round) < 0 or int(data.round) > 9:
		return false
	if float(data.radius) < 0.1 or float(data.radius) > 1000.0 or float(data.time) < 0.0 or float(data.time) > 3600.0:
		return false
	for i in count:
		if not _number(data.scores[i]) or not data.alive[i] is bool:
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
			if not _number(row.get(key)):
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
			source.visible = scene.phase not in [P.INTRO, P.INSTRUCTIONS]
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
