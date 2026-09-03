extends MiniGameController
## Drift Floes — the floor moves, and it is taking you with it.
##
## The spec asks for a stage fought on moving platforms. Raising them into the
## air would have meant a step a walking body cannot climb, so the floes sit
## flush with the ice instead: you cross onto one without noticing and then
## realise your feet are no longer where you left them. Two orbit the ring and
## one breathes in and out through the middle, so the danger is not falling off
## a platform — it is being carried to the water while you are busy fighting.

const FLOE_COUNT := 3
const KNOCKOUT_POINTS := 2

var _floes: Array = []
var _time := 0.0


func configure() -> void:
	eliminate_on_fall = true
	lives_per_player = 1
	# A derby where the floor does half the work still has to reward the player
	# who did the shoving, or drifting quietly to last place pays best.
	survival_knockout_weight = 2


func build() -> void:
	var arena := ctx.arena as Arena
	if arena == null:
		return
	for i in FLOE_COUNT:
		_floes.append(_make_floe(arena, i))


func on_round_start() -> void:
	_time = 0.0
	var arena := ctx.arena as Arena
	if arena != null:
		arena.reset_hazards()


func _make_floe(arena: Arena, index: int) -> Dictionary:
	var radius: float = arena.def.radius * (0.3 + 0.075 * float(index))
	var orbit: float = arena.def.radius * (0.34 + 0.2 * float(index % 2))
	var body := AnimatableBody3D.new()
	body.name = "Floe%d" % index
	body.collision_layer = 1
	body.collision_mask = 0
	# Without this the platform teleports and a body standing on it is left
	# behind; with it, Godot moves the plate kinematically and carries whoever
	# is on top.
	body.sync_to_physics = true
	ctx.world_root.add_child(body)

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 0.3
	shape.shape = cyl
	body.add_child(shape)

	var plate := MeshFactory.cylinder(radius, 0.3, Color(0.55, 0.82, 0.98), 0.1, 30)
	plate.material_override = MeshFactory.ice(Color(0.58, 0.84, 1.0), 0.95)
	body.add_child(plate)
	var rim := MeshFactory.torus(radius - 0.2, radius + 0.04, Color(0.32, 0.68, 0.95), 0.8)
	rim.position = Vector3(0, 0.16, 0)
	body.add_child(rim)
	# Chevrons pointing the way the plate travels. Ice on ice is nearly
	# invisible from the arena camera, and a platform you cannot see carrying
	# you is not a mechanic, it is a glitch: the arrows are how a player reads
	# which way the floor under their feet is going.
	for c in 3:
		var chevron := Node3D.new()
		chevron.position = Vector3(0, 0.17, radius * (-0.4 + 0.4 * float(c)))
		for side in [-1.0, 1.0]:
			var arm := MeshFactory.box(Vector3(radius * 0.42, 0.03, 0.16), Color(0.86, 0.97, 1.0), 0.5)
			arm.position = Vector3(radius * 0.16 * side, 0.0, 0.0)
			arm.rotation.y = 0.6 * side
			chevron.add_child(arm)
		body.add_child(chevron)

	# Flush with the deck: top face two centimetres above the ice, so crossing
	# onto a floe is a surprise rather than a wall.
	var y: float = arena.global_position.y - 0.13
	var mode := "radial" if index == FLOE_COUNT - 1 else "orbit"
	var phase := TAU * float(index) / float(FLOE_COUNT)
	body.global_position = arena.global_position + Vector3(cos(phase) * orbit, y, sin(phase) * orbit)
	return {"body": body, "orbit": orbit, "phase": phase, "mode": mode, "y": y,
		"speed": 0.34 + 0.09 * float(index), "radius": radius}


func tick(delta: float) -> void:
	_time += delta
	var arena := ctx.arena as Arena
	if arena == null:
		return
	for floe in _floes:
		var body: AnimatableBody3D = floe["body"]
		if not is_instance_valid(body):
			continue
		var ang: float = float(floe["phase"]) + _time * float(floe["speed"])
		var dist: float = float(floe["orbit"])
		if String(floe["mode"]) == "radial":
			# In and out through the centre: this is the one that shoves people
			# over the rim without anybody touching them.
			dist = arena.current_radius * (0.14 + 0.42 * (0.5 + 0.5 * sin(_time * 0.42)))
			ang = float(floe["phase"]) + _time * 0.16
		else:
			# Orbits stay inside the live radius, so a shrinking ring does not
			# leave a plate hanging over the water.
			dist = minf(dist, maxf(arena.current_radius - float(floe["radius"]) - 0.6, 0.5))
		body.global_position = arena.global_position + Vector3(cos(ang) * dist, float(floe["y"]), sin(ang) * dist)


func on_sudden_death() -> void:
	# Faster plates, tighter ring: the spec wants the hazards to lean on a
	# stalemate rather than wait it out.
	for floe in _floes:
		floe["speed"] = float(floe["speed"]) * 1.8
	var arena := ctx.arena as Arena
	if arena == null:
		return
	for h in arena.get_children():
		if h is ArenaHazards.ShrinkRing:
			h.start_delay = 0.0
			h.rate = maxf(h.rate, 1.1)
			h.min_radius = 1.2


func on_credited_knockout(attacker: int, _victim: int) -> void:
	ctx.bump_detail(attacker, "knockouts", 0)


func hud_value(slot: int) -> String:
	if not ctx.is_alive(slot):
		return Loc.t("hud.eliminated")
	return "●"


func detail_rows() -> Array:
	return [{"key": "results.stat.knockouts", "field": "knockouts"}]


func cleanup() -> void:
	for floe in _floes:
		var body: AnimatableBody3D = floe["body"]
		if is_instance_valid(body):
			body.queue_free()
	_floes.clear()
