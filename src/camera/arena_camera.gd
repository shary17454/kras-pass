class_name ArenaCamera
extends Camera3D
## Framing for 2–4 competitors at once.
##
## The camera's job in a party game is simple to state and easy to get wrong:
## every player who still matters must stay on screen, and the frame must not
## jitter while doing it. It tracks the bounding box of live targets, zooms to
## fit with padding, and clamps so a single leftover player does not push the
## view to a useless extreme.

enum Mode { ARENA, TOP_DOWN, ISOMETRIC, THIRD_PERSON, RACE, WORLD, CHASE, COURT }
var local_target: Node3D
var shared_world := false
var shared_touch_count := 0
var shared_hud_bottom: Callable
var follow_distance := 10.0
var follow_height := 6.0
var follow_lookahead := 5.0
var close_follow := false

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
## How much of the arena diameter to keep framed, as a multiple of its radius.
var _arena_fit := 1.45
var _zoom := 1.0
var _target_zoom := 1.0
var _shake := 0.0
var _shake_decay := 5.5
var _max_shake := 0.9
var _yaw := 0.0
var _noise_t := 0.0
## Pre-round establishing shot. While this is counting down the camera orbits
## the arena from a low, wide angle instead of framing the players, which is how
## the spec wants a round to open: show the venue, the hazards and the drone,
## then drop into the play angle.
var _intro_left := 0.0
var _intro_total := 0.0
var _intro_yaw := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var t := Balance.table("tuning").get("camera", {})
	_distance = float(t.get("distance", 15.0))
	_height = float(t.get("height", 15.5))
	_pitch = float(t.get("pitch_deg", -46.0))
	_follow_lerp = float(t.get("follow_lerp", 3.6))
	_zoom_lerp = float(t.get("zoom_lerp", 2.4))
	_min_zoom = float(t.get("min_zoom", 0.72))
	_max_zoom = float(t.get("max_zoom", 1.85))
	_padding = float(t.get("padding", 7.5))
	_arena_fit = float(t.get("arena_fit", 1.45))
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
		Mode.WORLD:
			_height = 7.0
			_distance = 12.0
			_yaw = 0.0
		Mode.TOP_DOWN:
			_pitch = -78.0
			_height = 22.0
			_distance = _height / tan(deg_to_rad(absf(_pitch)))
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


## Start the establishing orbit. Called by the match layer when the INTRO phase
## begins, with the phase's own length so the two cannot drift apart.
func begin_intro(seconds: float) -> void:
	if seconds <= 0.05 or arena == null:
		return
	_intro_total = seconds
	_intro_left = seconds
	_intro_yaw = _yaw - deg_to_rad(70.0)


func is_intro_active() -> bool:
	return _intro_left > 0.0


func _process(delta: float) -> void:
	var started := DevTools.operations.begin()
	_update_camera(delta)
	DevTools.operations.finish("camera.update", started)


func _update_camera(delta: float) -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var view := get_viewport().get_visible_rect().size
	keep_aspect = Camera3D.KEEP_WIDTH if view.x < view.y else Camera3D.KEEP_HEIGHT
	var sensitivity := float(UserSettings.get_value("camera_sensitivity"))
	if mode == Mode.COURT and arena != null:
		_intro_left = 0.0
		_frame_court(view)
		return
	if _intro_left > 0.0:
		_tick_intro(delta)
		return
	if shared_world:
		_frame_shared_world(delta, view)
		return
	if mode == Mode.CHASE and is_instance_valid(local_target):
		var heading: Vector3 = local_target.facing.normalized()
		var subject: Vector3 = local_target.get_global_transform_interpolated().origin
		var wanted := subject - heading * follow_distance + Vector3.UP * follow_height
		var candidate := global_position.lerp(wanted, 1.0 - exp(-5.0 * delta))
		# Keep the camera on the driver's side of tunnel walls and ceilings.
		var anchor := subject + Vector3.UP * 1.2
		var query := PhysicsRayQueryParameters3D.create(anchor, candidate, 1, [local_target.get_rid()])
		query.hit_back_faces = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			candidate = hit.position + (anchor - hit.position).normalized() * 0.5
		global_position = candidate
		focus = subject
		look_at(subject + heading * follow_lookahead + Vector3.UP)
		return
	_update_focus_and_zoom(false)
	_shake = maxf(0.0, _shake - _shake_decay * delta)
	_noise_t += delta * 34.0
	_apply(clampf(_follow_lerp * sensitivity * delta, 0.0, 1.0), delta)


func _frame_court(view: Vector2) -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect := view.x / maxf(view.y, 1.0)
	var top := 0.05
	if shared_hud_bottom.is_valid():
		top = clampf((float(shared_hud_bottom.call()) + 20.0) / view.y, 0.05, 0.70)
	var bottom := 0.95
	if shared_touch_count > 1:
		bottom = TouchSource.party_region(view, 0, shared_touch_count).position.y / view.y - 0.02
	elif shared_touch_count == 1:
		bottom = 0.76 if view.x < view.y else 0.80
	var centre := arena.global_position
	global_position = centre + Vector3(0, 30, 17)
	look_at(centre, Vector3.UP)
	# Fit the projected court, including banking and keeper height, inside the
	# HUD/control safe area instead of centring it behind the portrait scoreboard.
	var diameter := arena.def.radius * 2.0 + 2.8
	var projected_height := diameter * absf(global_basis.y.z) + 4.0 * absf(global_basis.y.y)
	var world_height := maxf(diameter / (aspect * 0.92), projected_height / maxf(0.10, bottom - top))
	size = world_height * aspect if view.x < view.y else world_height
	global_position += global_basis.y * (((top + bottom) * 0.5 - 0.5) * world_height)
	focus = centre


func _frame_shared_world(delta: float, view: Vector2) -> void:
	var live := _live_targets()
	if live.is_empty():
		return
	var minimum: Vector3 = live[0].global_position
	var maximum := minimum
	for player in live:
		minimum = minimum.min(player.global_position)
		maximum = maximum.max(player.global_position)
	var centre := (minimum + maximum) * 0.5
	var portrait := view.x < view.y
	var aspect := view.x / maxf(view.y, 1.0)
	var top := 0.29 if portrait else 0.20
	if shared_hud_bottom.is_valid():
		top = maxf(0.12, (float(shared_hud_bottom.call()) + 30.0) / view.y)
	var bottom := 1.0
	if shared_touch_count > 1:
		bottom = TouchSource.party_region(view, 0, shared_touch_count).position.y / view.y
	var safe_height := maxf(0.1, bottom - top - 0.08)
	var width := maxf((maximum.x - minimum.x + 10.0) / 0.90,
		(maximum.z - minimum.z + 10.0) * aspect / safe_height)
	# A fixed, north-up shared view avoids privileging one driver's heading.
	# Bound the zoom to the authored world, never an unbounded falling target.
	var limit := maxf(80.0, arena.current_radius * 5.0) if arena != null else 400.0
	width = clampf(width, 24.0, limit)
	projection = Camera3D.PROJECTION_ORTHOGONAL
	var target_size := width if portrait else width / aspect
	var blend := 1.0 - exp(-5.0 * delta)
	size = maxf(target_size, lerpf(size, target_size, blend))
	var world_height := size / aspect if portrait else size
	centre.z += (0.5 - (top + bottom) * 0.5) * world_height
	focus = centre
	global_position = centre + Vector3.UP * maxf(160.0, width)
	look_at(centre, Vector3.FORWARD)


## A slow sweep around the ring at a low angle, close enough to the deck that
## the barriers, the surface and the hovering machine all pass through frame.
## Nothing here touches `focus` or `_zoom`, so when the orbit ends the normal
## framing resumes from wherever it already was and the camera swoops into the
## play angle on its own follow lerp — no cut, no extra state.
func _tick_intro(delta: float) -> void:
	_intro_left = maxf(0.0, _intro_left - delta)
	var t: float = 1.0 - clampf(_intro_left / maxf(_intro_total, 0.01), 0.0, 1.0)
	_intro_yaw += delta * 0.55
	var centre := arena.global_position
	var radius: float = maxf(arena.def.radius, 6.0)
	# Pulls back and lifts as it goes, so the last frame of the orbit is already
	# close to the height the gameplay camera wants.
	var dist: float = radius * lerpf(1.35, 1.9, t)
	var height: float = radius * lerpf(0.42, 0.95, t)
	global_position = centre + Vector3(sin(_intro_yaw) * dist, height, cos(_intro_yaw) * dist)
	look_at(centre + Vector3(0, 1.4, 0), Vector3.UP)
	if _intro_left <= 0.0:
		# Hand the framing back where it can see everyone, without a jump: the
		# focus and zoom were never touched, so this only re-seeds the yaw the
		# gameplay camera orbits from.
		_yaw = 0.0 if mode == Mode.WORLD else _intro_yaw
		_update_focus_and_zoom(false)


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
	if mode == Mode.WORLD:
		_target_zoom = 1.0
		if instant:
			focus = _wanted_focus()
			_zoom = 1.0
		return
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
	if arena != null and mode != Mode.RACE:
		# Keep the arena boundary in shot even when everyone is bunched up. In a
		# push-out game the edge is the most important pixel on screen, and a
		# zoom driven only by player spread will happily crop it away.
		var fit := (arena.current_radius * _arena_fit + _padding) / 18.0
		_target_zoom = clampf(maxf(_target_zoom, fit), _min_zoom, _max_zoom)
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
		live_focus = wanted if close_follow and mode == Mode.WORLD else focus.lerp(wanted, weight)
		focus = live_focus
		_zoom = lerp(_zoom, _target_zoom, clampf(_zoom_lerp * delta, 0.0, 1.0))

	var framing := clampf(float(UserSettings.get_value("camera_distance")), 0.75, 1.4)
	if mode != Mode.RACE:
		framing = maxf(framing, 1.12)
	var offset := Vector3(sin(_yaw), 0.0, cos(_yaw)) * _distance * _zoom * framing
	var look_focus := live_focus + Vector3.UP
	if mode == Mode.WORLD and is_instance_valid(local_target):
		var heading: Vector3 = local_target.facing.normalized()
		offset = -heading * _distance * framing
		look_focus += heading * follow_lookahead
	var height := _height
	if mode == Mode.ARENA:
		var view := get_viewport().get_visible_rect().size
		var portrait_blend := clampf((1.0 - view.x / maxf(view.y, 1.0)) / 0.4, 0.0, 1.0)
		# A steeper portrait angle exposes the floor rather than enlarging it
		# past the rim. Safe-region projection below still owns the final fit.
		height *= lerpf(1.0, 1.65, portrait_blend)
	var pos := live_focus + Vector3(offset.x, height * _zoom * framing, offset.z)
	if mode == Mode.WORLD and is_inside_tree():
		var ray := PhysicsRayQueryParameters3D.create(live_focus + Vector3.UP * 2, pos, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			pos = hit.position + hit.normal * 0.6
	if _shake > 0.001:
		var s := minf(_shake, _max_shake)
		pos += Vector3(sin(_noise_t * 1.7), cos(_noise_t * 2.3), sin(_noise_t * 1.1)) * s * 0.9
	global_position = pos
	look_at(look_focus, Vector3.UP)
	rotation.x = clampf(rotation.x, deg_to_rad(-88.0), deg_to_rad(-8.0))
	if mode in [Mode.ARENA, Mode.TOP_DOWN, Mode.ISOMETRIC] and arena != null:
		_fit_arena_region()


func arena_safe_rect(view: Vector2) -> Rect2:
	var inset := Platform.safe_insets()
	var top := maxf(view.y * 0.06, inset.y)
	if shared_hud_bottom.is_valid():
		top = maxf(top, float(shared_hud_bottom.call()) + 24.0)
	var bottom := view.y * 0.92 - inset.w
	if shared_touch_count > 1:
		bottom = TouchSource.party_region(view, 0, shared_touch_count).position.y - 20.0
	elif shared_touch_count == 1:
		bottom = view.y * (0.76 if view.x < view.y else 0.80) - inset.w
	var left := view.x * 0.06 + inset.x
	var right := view.x * 0.94 - inset.z
	return Rect2(Vector2(left, top), Vector2(maxf(32.0, right - left), maxf(32.0, bottom - top)))


func _fit_arena_region() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	if is_zero_approx(get_camera_projection().determinant()):
		return
	var safe := arena_safe_rect(view)
	var points: Array[Vector3] = []
	var radius := arena.current_radius
	if arena.def.shape in ["square", "grid", "tiles"]:
		for x in [-radius, radius]:
			for z in [-radius, radius]:
				for height in [0.0, 3.0]:
					points.append(arena.global_position + Vector3(x, height, z))
	else:
		for index in 16:
			var angle := TAU * index / 16.0
			for height in [0.0, 3.0]:
				points.append(arena.global_position + Vector3(cos(angle) * radius, height, sin(angle) * radius))
	for target in _live_targets():
		points.append(target.global_position + Vector3.UP * 1.8)
	# Correct projection, not the world focus: retain the current viewing angle
	# while fitting the whole playable rim above the on-screen controls.
	for iteration in 4:
		var inverse := get_camera_transform().affine_inverse()
		var minimum_depth := INF
		for point in points:
			minimum_depth = minf(minimum_depth, -(inverse * point).z)
		if minimum_depth <= near:
			global_position += global_basis.z * (near - minimum_depth + maxf(radius, 1.0))
			continue
		var bounds := Rect2(unproject_position(points[0]), Vector2.ZERO)
		var behind := false
		for point in points:
			behind = behind or is_position_behind(point)
			bounds = bounds.expand(unproject_position(point))
		var depth := maxf(1.0, -to_local(arena.global_position).z)
		var ratio := maxf(bounds.size.x / safe.size.x, bounds.size.y / safe.size.y)
		if behind or ratio > 0.98:
			global_position += global_basis.z * depth * (clampf(ratio * 1.04, 1.04, 2.0) - 1.0)
			continue
		if mode == Mode.ARENA and view.x < view.y and ratio < 0.92:
			global_position += global_basis.z * depth * (maxf(0.5, ratio / 0.94) - 1.0)
			continue
		global_position += project_position(bounds.get_center(), depth) - project_position(safe.get_center(), depth)


func _wanted_focus() -> Vector3:
	if mode == Mode.WORLD:
		var survivors := _live_targets()
		if is_instance_valid(local_target) and local_target in survivors:
			return _bounded_world_focus(local_target.global_position)
		return _bounded_world_focus(survivors[0].global_position if not survivors.is_empty() else focus)
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


func _bounded_world_focus(p: Vector3) -> Vector3:
	if arena == null:
		return p
	if arena.def.shape not in ["square", "grid", "tiles"]:
		return _clamped_to_arena(p)
	var origin := arena.global_position
	var radius := arena.current_radius
	# A world follow camera must preserve playable square corners, not clamp
	# them to the inscribed circle used for compact shared arenas.
	return origin + Vector3(clampf(p.x - origin.x, -radius, radius),
		clampf(p.y - origin.y, -1.0, 14.0), clampf(p.z - origin.z, -radius, radius))


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
