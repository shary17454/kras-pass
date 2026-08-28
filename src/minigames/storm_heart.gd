extends "res://src/minigames/goal_guard.gd"
## Storm Heart — Goal Guard around a machine that shoots back.
##
## A turbine sits at centre court. Every few seconds it winds up — plainly,
## loudly — then whirls and hurls every ball outward at once. Between volleys
## the court plays like classic Goal Guard; the volley is the moment that
## punishes a keeper who wandered, because four balls leave the heart on four
## different bearings and only one of them is yours to stop.

const VOLLEY_PERIOD := 8.0
const WINDUP_TIME := 1.6
const MAX_EXTRA_BALLS := 2

var _volley_timer := VOLLEY_PERIOD
var _windup := 0.0
var _heart: Node3D
var _blades: Node3D


func build() -> void:
	super.build()
	var arena := ctx.arena as Arena
	if arena == null:
		return
	_heart = Node3D.new()
	_heart.position = arena.global_position
	ctx.world_root.add_child(_heart)
	var base := MeshFactory.cylinder(1.5, 0.8, UIKit.PANEL_HI, 0.4)
	base.position.y = 0.4
	_heart.add_child(base)
	_blades = Node3D.new()
	_blades.position.y = 1.1
	_heart.add_child(_blades)
	for i in 3:
		var blade := MeshFactory.box(Vector3(2.6, 0.18, 0.5), UIKit.ACCENT, 0.9)
		blade.rotation.y = TAU * i / 3.0
		_blades.add_child(blade)


func on_round_start() -> void:
	super.on_round_start()
	_volley_timer = VOLLEY_PERIOD
	_windup = 0.0


func tick(delta: float) -> void:
	super.tick(delta)
	if _blades != null and is_instance_valid(_blades):
		# Idle spin sells the machine; the wind-up spin is the telegraph.
		var rate: float = 0.8 if _windup <= 0.0 else lerpf(2.5, 14.0, 1.0 - _windup / WINDUP_TIME)
		_blades.rotate_y(rate * delta)
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			_fire_volley()
		return
	_volley_timer -= delta
	if _volley_timer <= 0.0:
		_volley_timer = VOLLEY_PERIOD
		_windup = WINDUP_TIME
		AudioManager.play_sfx("countdown", _heart.global_position if _heart != null else ctx.arena_center())


func _fire_volley() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	# One fresh ball per volley until the cap, then the volley recycles what is
	# on court: every ball snaps back to the heart and leaves on its own
	# bearing, which is the whole terror of the machine.
	if balls.size() < ctx.player_count() + MAX_EXTRA_BALLS:
		_spawn_ball(balls.size() >= 3)
	var n := 0
	for b in balls:
		if not is_instance_valid(b):
			continue
		var ang := ctx.rng.randf() * TAU if n > 0 else float(ctx.rng.randi_range(0, 3)) * (TAU * 0.25)
		b.launch(arena.global_position + Vector3(0, 0.9, 0), Vector3(cos(ang), 0, sin(ang)),
			Balance.num("tuning", "ball.base_speed", 9.0) * 1.35)
		n += 1
	EventBus.shake(0.45, 0.3)
	AudioManager.play_sfx("shoot", arena.global_position)


## True while the turbine is winding up — the same warning the spin and the
## sound give a player.
func is_winding() -> bool:
	return _windup > 0.0


func ai_script() -> Script:
	return load("res://src/ai/brains/storm_keeper_brain.gd")


func hud_banner() -> String:
	if _windup > 0.0:
		return "⚠"
	return ""


func cleanup() -> void:
	super.cleanup()
	if _heart != null and is_instance_valid(_heart):
		_heart.queue_free()
