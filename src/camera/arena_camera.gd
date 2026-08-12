class_name ArenaCamera
extends Camera3D
## Framing for 2–4 competitors at once.
##
## The camera's job in a party game is simple to state and easy to get wrong:
## every player who still matters must stay on screen, and the frame must not
## jitter while doing it. It tracks the bounding box of live targets, zooms to
## fit with padding, and clamps so a single leftover player does not push the
## view to a useless extreme.

enum Mode { ARENA, TOP_DOWN, ISOMETRIC, THIRD_PERSON, RACE }

var mode: Mode = Mode.ARENA
var targets: Array = []
var focus := Vector3.ZERO
var arena: Arena

var _distance := 15.0
var _height := 15.5
var _pitch := -46.0
var _follow_lerp := 3.6
var _zoom_lerp := 2.4
var _min_zoom := 0.72
var _max_zoom := 1.85
var _padding := 7.5
var _zoom := 1.0
var _target_zoom := 1.0
var _shake := 0.0
var _shake_decay := 5.5
var _max_shake := 0.9
var _yaw := 0.0
var _noise_t := 0.0


func _ready() -> void:
	var t := Balance.table("tuning").get("camera", {})
	_distance = float(t.get("distance", 15.0))
	_height = float(t.get("height", 15.5))
	_pitch = float(t.get("pitch_deg", -46.0))
	_follow_lerp = float(t.get("follow_lerp", 3.6))
	_zoom_lerp = float(t.get("zoom_lerp", 2.4))
	_min_zoom = float(t.get("min_zoom", 0.72))
	_max_zoom = float(t.get("max_zoom", 1.85))
	_padding = float(t.get("padding", 7.5))
	_shake_decay = float(t.get("shake_decay", 5.5))
	_max_shake = float(t.get("max_shake", 0.9))
	fov = 58.0
	EventBus.camera_shake_requested.connect(_on_shake)


func configure(m: Mode, a: Arena) -> void:
	mode = m
	arena = a
	if a != null:
		focus = a.global_position
		_target_zoom = clampf(a.def.radius / 12.0, _min_zoom, _max_zoom)
		_zoom = _target_zoom
	match mode:
		Mode.TOP_DOWN:
			_pitch = -78.0
			_height = 22.0
		Mode.ISOMETRIC:
			_pitch = -38.0
			_yaw = deg_to_rad(35.0)
		Mode.THIRD_PERSON:
			_pitch = -22.0
			_distance = 10.0
		Mode.RACE:
			_pitch = -30.0
			_distance = 13.0
	_snap()


## Jump straight to the framing without interpolation — used at round start so
## the first frame of gameplay is already correct.
func _snap() -> void:
	_update_focus_and_zoom(true)
	_apply(1.0, 0.0)


func _process(delta: float) -> void:
	var sensitivity := float(UserSettings.get_value("camera_sensitivity"))
	_update_focus_and_zoom(false)
	_shake = maxf(0.0, _shake - _shake_decay * delta)
	_noise_t += delta * 34.0
	_apply(clampf(_follow_lerp * sensitivity * delta, 0.0, 1.0), delta)


## Targets worth framing: alive, and still part of the fight.
##
## A player who has just been launched off the rim is technically alive for the
## second and a half it takes them to fall past the kill plane. Following them
## drags the view off the arena and hides everyone still playing — so anyone
## already past the edge or below the floor stops counting as a subject.
func _live_targets() -> Array:
	var live: Array = []
	var fallback: Array = []
	for t in targets:
		if t == null or not is_instance_valid(t):
			continue
		if t is Fighter and not t.alive:
			continue
		fallback.append(t)
		if arena != null:
			var p: Vector3 = t.global_position
			if p.y < arena.global_position.y - 2.5:
				continue
			if arena.edge_distance(p) < -1.5:
				continue
		live.append(t)
	# If everyone left is falling, keep framing them rather than nothing at all.
	return live if not live.is_empty() else fallback


func _update_focus_and_zoom(instant: bool) -> void:
	var live := _live_targets()
	if live.is_empty():
		if arena != null:
			focus = focus.lerp(arena.global_position, 0.05)
		return

	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var sum := Vector3.ZERO
	for t in live:
		var p: Vector3 = t.global_position
		sum += p
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.z)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.z)
	var centre := sum / float(live.size())
	# In race mode the pack leader matters more than the average, otherwise the
	# camera drifts behind and the leader runs off screen.
	if mode == Mode.RACE and live.size() > 1:
		centre = centre.lerp(_leader_position(live), 0.45)
	var goal := Vector3(centre.x, centre.y, centre.z)
	if arena != null and mode != Mode.RACE:
		# Bias toward the arena centre so a lone survivor at the rim does not
		# swing the view wildly.
		goal = goal.lerp(arena.global_position, 0.18)
	goal = _clamped_to_arena(goal)
	focus = goal if instant else focus

	var spread := maxf(max_p.x - min_p.x, max_p.y - min_p.y)
	_target_zoom = clampf((spread + _padding) / 18.0, _min_zoom, _max_zoom)
	if arena != null:
		_target_zoom = maxf(_target_zoom, arena.current_radius / 15.0)
	if instant:
		_zoom = _target_zoom


func _leader_position(live: Array) -> Vector3:
	var best: Vector3 = live[0].global_position
	for t in live:
		if t.global_position.z < best.z:
			best = t.global_position
	return best


func _apply(weight: float, delta: float) -> void:
	var live_focus := focus
	if delta > 0.0:
		var wanted := _wanted_focus()
		live_focus = focus.lerp(wanted, weight)
		focus = live_focus
		_zoom = lerp(_zoom, _target_zoom, clampf(_zoom_lerp * delta, 0.0, 1.0))

	var offset := Vector3(sin(_yaw), 0.0, cos(_yaw)) * _distance * _zoom
	var pos := live_focus + Vector3(offset.x, _height * _zoom, offset.z)
	if _shake > 0.001:
		var s := minf(_shake, _max_shake)
		pos += Vector3(sin(_noise_t * 1.7), cos(_noise_t * 2.3), sin(_noise_t * 1.1)) * s * 0.9
	global_position = pos
	look_at(live_focus + Vector3(0, 1.0, 0), Vector3.UP)
	rotation.x = clampf(rotation.x, deg_to_rad(-88.0), deg_to_rad(-8.0))


func _wanted_focus() -> Vector3:
	var live := _live_targets()
	if live.is_empty():
		return arena.global_position if arena != null else focus
	var sum := Vector3.ZERO
	for t in live:
		sum += t.global_position
	var centre := sum / float(live.size())
	if mode == Mode.RACE and live.size() > 1:
		centre = centre.lerp(_leader_position(live), 0.45)
	elif arena != null:
		centre = centre.lerp(arena.global_position, 0.18)
	return _clamped_to_arena(centre)


## Final guard: the focus never leaves the play area, whatever the targets do.
func _clamped_to_arena(p: Vector3) -> Vector3:
	if arena == null or mode == Mode.RACE:
		return p
	var origin := arena.global_position
	var flat := Vector2(p.x - origin.x, p.z - origin.z)
	# Ring and oval arenas are played on their rim, so the focus has to be
	# allowed most of the way out; solid arenas keep it nearer the middle.
	var ring_shaped := arena.def.shape == "ring" or arena.def.shape == "oval"
	var limit := arena.current_radius * (0.95 if ring_shaped else 0.7)
	if flat.length() > limit:
		flat = flat.normalized() * limit
	return Vector3(origin.x + flat.x, clampf(p.y, origin.y - 1.0, origin.y + 14.0), origin.z + flat.y)


func _on_shake(strength: float, _duration: float) -> void:
	_shake = minf(_max_shake, _shake + strength)
