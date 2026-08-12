extends MiniGameController
## Zone Hold — contest a moving capture circle.
##
## Only an *uncontested* occupant scores, so the game is as much about shoving
## company out as it is about standing in the right place. The zone drifts
## around the ring so nobody can camp.

const CAPTURE_RATE := 1.0
const CONTESTED_COLOR := Color("#ff5f6d")

var zone_position := Vector3.ZERO
var zone_radius := 3.4
var _marker: Node3D
var _ring: MeshInstance3D
var _move_timer := 0.0
var _accum: Array[float] = []
var _target := Vector3.ZERO


func configure() -> void:
	eliminate_on_fall = false
	lives_per_player = 99


func build() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	_accum.resize(ctx.player_count())
	_accum.fill(0.0)
	_marker = Node3D.new()
	ctx.world_root.add_child(_marker)
	var disc := MeshFactory.cylinder(zone_radius, 0.1, UIKit.ACCENT_2, 0.7, 28)
	disc.position = Vector3(0, 0.08, 0)
	_marker.add_child(disc)
	_ring = MeshFactory.torus(zone_radius - 0.2, zone_radius + 0.15, UIKit.ACCENT_2, 1.4)
	_ring.position = Vector3(0, 0.14, 0)
	_marker.add_child(_ring)
	_pick_new_spot()
	zone_position = _target
	_marker.global_position = zone_position


func _pick_new_spot() -> void:
	var arena := ctx.arena as Arena
	var ang := ctx.rng.randf() * TAU
	# Dune Ring is a donut: keep the zone on the walkable band.
	var band := arena.def.radius * (0.72 if arena.def.shape == "ring" else 0.55)
	_target = arena.global_position + Vector3(cos(ang) * band, 0, sin(ang) * band)
	_move_timer = ctx.rng.randf_range(7.0, 11.0)


func tick(delta: float) -> void:
	zone_position = zone_position.move_toward(_target, 3.2 * delta)
	if _marker != null and is_instance_valid(_marker):
		_marker.global_position = zone_position
	_move_timer -= delta
	if _move_timer <= 0.0 and zone_position.distance_to(_target) < 0.4:
		_pick_new_spot()

	var inside: Array[int] = []
	for i in ctx.fighters.size():
		if not ctx.is_alive(i):
			continue
		var f := ctx.fighter(i)
		if f == null or not is_instance_valid(f):
			continue
		var to: Vector3 = f.global_position - zone_position
		to.y = 0.0
		if to.length() <= zone_radius:
			inside.append(i)

	var contested := inside.size() != 1
	if _ring != null and is_instance_valid(_ring):
		var col := CONTESTED_COLOR if inside.size() > 1 else (
			UIKit.adapt(ctx.config.players[inside[0]].color()) if inside.size() == 1 else UIKit.ACCENT_2)
		_ring.material_override = MeshFactory.toon(col, 1.4)
	if contested:
		return
	var slot := inside[0]
	_accum[slot] += CAPTURE_RATE * delta * ctx.powerups.point_multiplier(slot)
	while _accum[slot] >= 1.0:
		_accum[slot] -= 1.0
		ctx.add_score(slot, 1)
		ctx.bump_detail(slot, "collected")
		AudioManager.play_sfx("tick", zone_position, 1.2)


func on_sudden_death() -> void:
	zone_radius *= 0.6
	_pick_new_spot()


func is_round_over() -> bool:
	return ctx.early_finish


func ai_script() -> Script:
	return load("res://src/ai/brains/zone_brain.gd")


func hud_banner() -> String:
	return ""


func detail_rows() -> Array:
	return [{"key": "results.stat.collected", "field": "collected"}]
