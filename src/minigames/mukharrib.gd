extends "res://src/minigames/paint_grid.gd"
## Mukharrib — Paint Grid with a machine that answers to nobody.
##
## A drone patrols the board on its own errand. It marks a square, counts down
## in plain sight, then scrubs that square and its neighbours back to bare
## floor — nobody's colour, nobody's points. It is not an obstacle to dodge so
## much as a clock to plan around: territory near the drone is rented, not
## owned, and the player who reads its route keeps painting where it has just
## been instead of where it is going.

const SCRUB_PERIOD := 3.4
const MARK_TIME := 1.5
const DRONE_SPEED := 5.5

var _drone: Node3D
var _rotor: Node3D
var _target: ArenaTile
var _mark := 0.0
var _cycle := SCRUB_PERIOD
var _markers: Array = []


func build() -> void:
	super.build()
	var arena := ctx.arena as Arena
	if arena == null:
		return
	_drone = Node3D.new()
	_drone.add_child(MeshFactory.sphere(0.7, Color("#c8ccd8"), 0.3))
	var eye := MeshFactory.sphere(0.28, Color("#ff5f8d"), 2.2)
	eye.position.y = -0.4
	_drone.add_child(eye)
	_rotor = MeshFactory.box(Vector3(2.2, 0.1, 0.2), Color("#8f96ab"), 0.4)
	_rotor.position.y = 0.7
	_drone.add_child(_rotor)
	ctx.world_root.add_child(_drone)
	_drone.global_position = arena.global_position + Vector3(0, 3.2, 0)


func on_round_start() -> void:
	super.on_round_start()
	_clear_markers()
	_target = null
	_mark = 0.0
	_cycle = SCRUB_PERIOD


func tick(delta: float) -> void:
	super.tick(delta)
	if _drone == null or not is_instance_valid(_drone):
		return
	if is_instance_valid(_rotor):
		_rotor.rotate_y(12.0 * delta)
	if _target != null and is_instance_valid(_target):
		_drone.global_position = _drone.global_position.move_toward(
			_target.global_position + Vector3(0, 3.2, 0), DRONE_SPEED * delta)
		_mark -= delta
		if _mark <= 0.0:
			_scrub()
		return
	_cycle -= delta
	if _cycle <= 0.0:
		_cycle = SCRUB_PERIOD
		_choose_target()


## Head for the most valuable patch on the board — whoever is winning has the
## most to lose, which keeps the drone from being a private tax on one player.
func _choose_target() -> void:
	var leader := -1
	var best := -1
	for i in ctx.player_count():
		if ctx.scores[i] > best:
			best = ctx.scores[i]
			leader = i
	var owned: Array[ArenaTile] = []
	for t in _tiles:
		if t.owner_slot == leader:
			owned.append(t)
	if owned.is_empty():
		owned = _tiles
	if owned.is_empty():
		return
	_target = owned[ctx.rng.randi_range(0, owned.size() - 1)]
	_mark = MARK_TIME
	_show_markers(_target)
	AudioManager.play_sfx("countdown", _target.global_position)


## Paint the doomed squares white before the scrub, so the warning is a place
## on the floor rather than a HUD icon.
func _show_markers(centre: ArenaTile) -> void:
	_clear_markers()
	for t in _scrub_set(centre):
		var m := MeshFactory.box(Vector3(1.7, 0.08, 1.7), Color("#ffffff"), 1.6)
		m.position = t.global_position + Vector3(0, 0.35, 0)
		ctx.world_root.add_child(m)
		_markers.append(m)


func _scrub_set(centre: ArenaTile) -> Array[ArenaTile]:
	var out: Array[ArenaTile] = []
	for t in _tiles:
		if absi(t.grid_x - centre.grid_x) <= 1 and absi(t.grid_z - centre.grid_z) <= 1:
			out.append(t)
	return out


func _scrub() -> void:
	if _target == null or not is_instance_valid(_target):
		_target = null
		return
	var wiped := 0
	for t in _scrub_set(_target):
		if t.owner_slot >= 0:
			wiped += 1
		t.owner_slot = -1
		t.set_color(t.base_color)
	_clear_markers()
	var burst := MeshFactory.burst(Color("#c8ccd8"), 12)
	ctx.world_root.add_child(burst)
	burst.global_position = _target.global_position + Vector3(0, 0.6, 0)
	AudioManager.play_sfx("explode", _target.global_position)
	EventBus.shake(0.25, 0.18)
	# Anyone standing in the blast is shoved clear — the drone does not paint
	# for them either, so being caught costs tempo on top of territory.
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var away: Vector3 = f.global_position - _target.global_position
		away.y = 0.0
		if away.length() < 2.6:
			f.take_hit(-1, away.normalized() if away.length() > 0.1 else Vector3.FORWARD, 14.0, 0.0, true)
	if wiped > 0:
		_recount_scores()
	_target = null


func _clear_markers() -> void:
	for m in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()


## Where the drone is about to strike, for brains that plan around it. It is
## marked on the floor in white, so this is public information.
func scrub_target() -> Vector3:
	if _target == null or not is_instance_valid(_target):
		return Vector3.INF
	return _target.global_position


func ai_script() -> Script:
	return load("res://src/ai/brains/saboteur_painter_brain.gd")


func hud_banner() -> String:
	return "⚠" if _target != null else ""


func cleanup() -> void:
	_clear_markers()
	if _drone != null and is_instance_valid(_drone):
		_drone.queue_free()
