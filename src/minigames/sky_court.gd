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


func build() -> void:
	super.build()
	var arena := ctx.arena as Arena
	if arena == null:
		return
	var r := arena.def.radius * 0.82
	for i in 4:
		var corner := Vector3(r * (1 if i % 2 == 0 else -1), -0.9, r * (1 if i < 2 else -1))
		var engine := MeshFactory.cylinder(0.9, 1.4, UIKit.ACCENT_2, 0.7)
		engine.position = arena.global_position + corner
		engine.rotation.x = PI
		ctx.world_root.add_child(engine)
		_engines.append(engine)


func on_round_start() -> void:
	super.on_round_start()
	_cycle = TILT_PERIOD
	_warn = 0.0
	_tilting = 0.0
	_level_out()


func tick(delta: float) -> void:
	super.tick(delta)
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
		_down = Vector3(1 if idx % 2 == 0 else -1, 0, 1 if idx < 2 else -1).normalized()
		if idx < _engines.size() and is_instance_valid(_engines[idx]):
			var tw: Tween = _engines[idx].create_tween()
			tw.set_loops(3)
			tw.tween_property(_engines[idx], "scale", Vector3(0.7, 0.7, 0.7), 0.18)
			tw.tween_property(_engines[idx], "scale", Vector3.ONE, 0.18)
		AudioManager.play_sfx("wrong", arena.global_position)


func _start_tilt(arena: Arena) -> void:
	_tilting = TILT_TIME
	var axis := Vector3(-_down.z, 0, _down.x).normalized()
	var tw := arena.create_tween()
	tw.tween_property(arena, "quaternion",
		Quaternion(axis, TILT_ANGLE), 0.5).set_trans(Tween.TRANS_CUBIC)
	EventBus.shake(0.3, 0.4)
	AudioManager.play_sfx("explode", arena.global_position)


func _level_out() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	var tw := arena.create_tween()
	tw.tween_property(arena, "quaternion", Quaternion.IDENTITY, 0.6).set_trans(Tween.TRANS_CUBIC)


## The slope is a force, not a visual: balls and keepers both accelerate
## toward the dead engine while the deck is over.
func _apply_slope(delta: float) -> void:
	for b in balls:
		if is_instance_valid(b):
			b.velocity += _down * TILT_PULL * delta
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
	_level_out()
	for e in _engines:
		if is_instance_valid(e):
			e.queue_free()
	_engines.clear()
