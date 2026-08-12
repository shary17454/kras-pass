class_name GameBall
extends Area3D
## A deterministic arena ball.
##
## Deliberately **not** a RigidBody3D. Party-game balls need to be predictable
## enough to defend against and to speed up on a schedule; a physics body gives
## neither cheaply. This integrates by hand: constant-speed travel, mirror
## bounces off the arena bounds, and a deflection when a fighter touches it that
## depends on where they hit it, so a well-timed swipe aims the ball.

signal deflected(ball: GameBall, slot: int)
signal scored_on(ball: GameBall, side: int)
signal exploded(ball: GameBall, position: Vector3)

enum Bounds { DISC, SQUARE }

var velocity := Vector3.ZERO
var speed := 9.0
var max_speed := 26.0
var ramp := 0.35
var radius := 0.55
var bounds: Bounds = Bounds.DISC
var bound_size := 12.0
var heavy := false
var explosive := false
var fuse := 0.0
var fuse_max := 5.0
var last_toucher := -1
var goals_enabled := false
var arena_center := Vector3.ZERO

var _mesh: Node3D
var _label: Label3D
var _touch_cooldown := {}
var _color := Color.WHITE
var _height := 0.9


func _init() -> void:
	collision_layer = 16
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.75
	cs.shape = s
	add_child(cs)


func configure(color: Color, r: float, is_heavy: bool = false, is_explosive: bool = false) -> void:
	_color = color
	radius = r
	heavy = is_heavy
	explosive = is_explosive
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.queue_free()
	_mesh = Node3D.new()
	add_child(_mesh)
	var body := MeshFactory.sphere(r, color, 1.2 if explosive else 0.35)
	_mesh.add_child(body)
	if heavy:
		var band := MeshFactory.torus(r * 0.9, r * 1.15, color.darkened(0.4))
		_mesh.add_child(band)
	if explosive:
		if _label == null:
			_label = Label3D.new()
			_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_label.font_size = 80
			_label.pixel_size = 0.006
			_label.outline_size = 20
			_label.position = Vector3(0, r + 0.6, 0)
			add_child(_label)
		_label.visible = true
	elif _label != null:
		_label.visible = false


func launch(from: Vector3, direction: Vector3, start_speed: float) -> void:
	global_position = from
	_height = from.y
	speed = start_speed
	direction.y = 0.0
	velocity = direction.normalized() * speed
	fuse = fuse_max
	last_toucher = -1
	_touch_cooldown.clear()


func tick(delta: float) -> void:
	speed = minf(max_speed, speed + ramp * delta)
	if velocity.length() > 0.01:
		velocity = velocity.normalized() * speed
	global_position += velocity * delta
	global_position.y = _height
	_bounce()
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.rotate_x(delta * speed * 0.35)
	for k in _touch_cooldown.keys():
		_touch_cooldown[k] = float(_touch_cooldown[k]) - delta
		if float(_touch_cooldown[k]) <= 0.0:
			_touch_cooldown.erase(k)
	if explosive:
		fuse -= delta
		if _label != null:
			_label.text = "%.1f" % maxf(0.0, fuse)
			_label.modulate = Color.WHITE.lerp(Color(1, 0.3, 0.25), 1.0 - clampf(fuse / maxf(fuse_max, 0.01), 0.0, 1.0))
		if fuse <= 0.0:
			exploded.emit(self, global_position)
	_check_contacts()


func _bounce() -> void:
	var local := global_position - arena_center
	match bounds:
		Bounds.SQUARE:
			var limit := bound_size - radius
			# Goal sides report a score instead of bouncing, so the same ball
			# serves both Goal Guard and a plain enclosed arena.
			if absf(local.x) > limit:
				if goals_enabled:
					scored_on.emit(self, 0 if local.x > 0.0 else 1)
					return
				velocity.x = -velocity.x
				global_position.x = arena_center.x + signf(local.x) * limit
				AudioManager.play_sfx("bounce", global_position)
			if absf(local.z) > limit:
				if goals_enabled:
					scored_on.emit(self, 2 if local.z > 0.0 else 3)
					return
				velocity.z = -velocity.z
				global_position.z = arena_center.z + signf(local.z) * limit
				AudioManager.play_sfx("bounce", global_position)
		_:
			var flat := Vector2(local.x, local.z)
			var limit_r := bound_size - radius
			if flat.length() > limit_r:
				var n := flat.normalized()
				var v := Vector2(velocity.x, velocity.z)
				v = v - 2.0 * v.dot(n) * n
				velocity = Vector3(v.x, 0, v.y)
				var clamped := n * limit_r
				global_position = arena_center + Vector3(clamped.x, 0, clamped.y)
				global_position.y = _height
				AudioManager.play_sfx("bounce", global_position)


func _check_contacts() -> void:
	if not is_monitoring():
		return
	for body in get_overlapping_bodies():
		if not (body is Fighter) or not body.alive:
			continue
		if _touch_cooldown.has(body.slot):
			continue
		_touch_cooldown[body.slot] = 0.25
		_deflect_from(body)


func _deflect_from(f: Fighter) -> void:
	var away: Vector3 = global_position - f.global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	away = away.normalized()
	# An attacking fighter sends the ball where they are facing; a passive one
	# just repels it. That difference is the entire skill ceiling of Goal Guard.
	var aim := away
	if f.is_attacking() or f.is_dashing():
		aim = (f.facing.normalized() * 0.75 + away * 0.45).normalized()
		speed = minf(max_speed, speed * 1.18)
	velocity = aim * speed
	last_toucher = f.slot
	var push := Balance.num("tuning", "ball.deflect_power", 13.0) * (2.0 if heavy else 1.0)
	f.take_hit(-1, -aim, push * (0.55 if not heavy else 1.0), 0.0, true)
	AudioManager.play_sfx("bounce", global_position, 1.15)
	deflected.emit(self, f.slot)


func on_acquired() -> void:
	visible = true
	set_deferred("monitoring", true)


func on_released() -> void:
	visible = false
	set_deferred("monitoring", false)
	velocity = Vector3.ZERO
