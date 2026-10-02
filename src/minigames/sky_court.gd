extends "res://src/minigames/goal_guard.gd"
## Sky Court — Goal Guard on a platform that stops flying level.
##
## Four engines hold the court in the sky, and every so often one of them
## coughs. The platform heels toward the dead engine and, for as long as it
## takes to recover, everything on court rolls downhill: balls curve toward
## the low corner and keepers fight a slope while they defend. The tilt is a
## real acceleration on every moving thing, not a backdrop — a ball that was
## heading safely wide starts bending at your goal the moment the deck goes
## over, and reading which engine died is the round's second game.

const TILT_PERIOD := 9.0
const TILT_WARN := 1.2
const TILT_TIME := 4.0
const TILT_ANGLE := 0.11          # radians, ~6.3 degrees
const TILT_PULL := 3.1            # m/s^2 along the slope — g * sin(angle)
const FIGHTER_PULL := 1.6         # keepers feel it too, but they have legs

var _cycle := TILT_PERIOD
var _warn := 0.0
var _tilting := 0.0
var _down := Vector3.ZERO
var _engines: Array = []
var _bank := 0.0
var _warning_engine := -1
var _warning_sequence := 0
var _tilt_sequence := 0
var _court_transforms := {}


func build() -> void:
	super.build()
	var arena := ctx.arena as Arena
	if arena == null:
		return
	for child in get_children():
		if child is MeshInstance3D and not paddles.has(child):
			_court_transforms[child] = arena.global_transform.affine_inverse() * child.global_transform
	var r := arena.def.radius * 0.82
	for i in 4:
		var corner := Vector3(r * (1 if i % 2 == 0 else -1), -0.9, r * (1 if i < 2 else -1))
		var engine := MeshFactory.cylinder(0.9, 1.4, UIKit.ACCENT_2, 0.7)
		engine.position = arena.global_position + corner
		engine.rotation.x = PI
		ctx.world_root.add_child(engine)
		_engines.append(engine)
		_court_transforms[engine] = arena.global_transform.affine_inverse() * engine.global_transform


func on_round_start() -> void:
	super.on_round_start()
	_cycle = TILT_PERIOD
	_warn = 0.0
	_tilting = 0.0
	_reset_platform()


func tick(delta: float) -> void:
	super.tick(delta)
	_tick_hazard(delta)
	_tick_platform(delta)


func _tick_hazard(delta: float) -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	if _tilting > 0.0:
		_tilting -= delta
		_apply_slope(delta)
		if _tilting <= 0.0:
			_level_out()
		return
	if _warn > 0.0:
		_warn -= delta
		if _warn <= 0.0:
			_start_tilt(arena)
		return
	_cycle -= delta
	if _cycle <= 0.0:
		_cycle = TILT_PERIOD
		_warn = TILT_WARN
		# Telegraph: the doomed engine sputters before the deck goes over.
		var idx := ctx.rng.randi_range(0, 3)
		_warning_engine = idx
		_down = engine_direction(idx)
		_warning_sequence += 1
		present_warning()


func _start_tilt(_arena: Arena) -> void:
	_tilting = TILT_TIME
	_tilt_sequence += 1
	present_tilt()


func present_warning() -> void:
	AudioManager.play_sfx("wrong", ctx.arena_center())


func present_tilt() -> void:
	EventBus.shake(0.3, 0.4)
	AudioManager.play_sfx("explode", ctx.arena_center())


static func engine_direction(index: int) -> Vector3:
	if index < 0:
		return Vector3.ZERO
	return Vector3(1 if index % 2 == 0 else -1, 0, 1 if index < 2 else -1).normalized()


func _level_out() -> void:
	_tilting = 0.0


func _reset_platform() -> void:
	_bank = 0.0
	_down = Vector3.ZERO
	_warning_engine = -1
	_tick_platform(0.0)


func _tick_platform(delta: float) -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	# Advance only with match simulation: pause and replay do not use wall time.
	var target := 1.0 if _tilting > 0.0 else 0.0
	_bank = move_toward(_bank, target, delta / (0.5 if target > 0 else 0.6))
	var axis := Vector3(_down.z, 0, -_down.x).normalized()
	var eased := _bank * _bank * (3.0 - 2.0 * _bank)
	arena.quaternion = Quaternion(axis, TILT_ANGLE * eased) if axis.length_squared() > 0.5 else Quaternion.IDENTITY
	for mesh in _court_transforms:
		if is_instance_valid(mesh):
			mesh.global_transform = arena.global_transform * _court_transforms[mesh]
	for ball: GameBall in balls:
		if is_instance_valid(ball):
			ball._height = _surface_height(ball.global_position) + 0.9
			ball.global_position.y = ball._height
	for slot in ctx.player_count():
		var fighter := ctx.fighter(slot)
		if is_instance_valid(fighter) and fighter.alive:
			fighter.global_position.y = _surface_height(fighter.global_position) + 0.9
			paddles[slot].global_position.y = _surface_height(paddles[slot].global_position) + 0.9
			paddles[slot].quaternion = arena.quaternion * Quaternion(Vector3.UP, PI * 0.5 if side_for(slot) < 2 else 0.0)
	for i in _engines.size():
		if not is_instance_valid(_engines[i]):
			continue
		var size := 1.0
		if i == _warning_engine and _warn > 0:
			var elapsed := minf(TILT_WARN - _warn, 1.08)
			var phase := fposmod(elapsed / 0.36, 1.0)
			size -= 0.3 * (1.0 - absf(phase * 2.0 - 1.0))
		_engines[i].scale = Vector3.ONE * size


func _surface_height(point: Vector3) -> float:
	var normal: Vector3 = ctx.arena.global_basis.y
	var origin: Vector3 = ctx.arena.global_position
	return origin.y - (normal.x * (point.x - origin.x) + normal.z * (point.z - origin.z)) / normal.y


## The slope is a force, not a visual: balls and keepers both accelerate
## toward the dead engine while the deck is over.
func _apply_slope(delta: float) -> void:
	for b in balls:
		if is_instance_valid(b):
			b.velocity = (b.velocity + _down * TILT_PULL * delta).limit_length(b.max_speed)
			b.speed = b.velocity.length()
	for i in ctx.player_count():
		var f := ctx.fighter(i)
		if f != null and is_instance_valid(f) and ctx.is_alive(i):
			f.apply_impulse(_down * FIGHTER_PULL * delta)


func hud_banner() -> String:
	if _warn > 0.0 or _tilting > 0.0:
		return "⚠"
	return ""


func cleanup() -> void:
	super.cleanup()
	_tilting = 0.0
	_warn = 0.0
	_reset_platform()
	for e in _engines:
		if is_instance_valid(e):
			e.queue_free()
	_engines.clear()
	_court_transforms.clear()
