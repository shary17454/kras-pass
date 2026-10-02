extends Node3D
## Host-owned crates and lab shots. Views have no collisions or damage callbacks.
const Number = preload("res://src/net/goal_guard_replica.gd")
const COLORS := [Color("#ffc46b"), Color("#3a2b3f"), Color("#5ad6a0")]
const ACCENTS := [Color("#fff0c2"), Color("#ff5f8d"), Color("#eafff3")]
const SOUNDS := ["crate_break", "explode", "explode", "shoot", "score"]
var crates := {}
var shots := {}
var initialized := false
var last_break := -1


static func capture(game: Node, lab: bool) -> Dictionary:
	var rows: Array = []
	for entry in game._crates:
		if is_instance_valid(entry.node):
			rows.append({"id": str(entry.node.get_instance_id()), "kind": 2 if entry.get("weapon", false) else (1 if entry.bomb else 0),
				"position": _vec(entry.node.global_position)})
	var projectiles: Array = []
	if lab:
		for shot in game._shots:
			if is_instance_valid(shot) and shot.active:
				projectiles.append({"id": str(shot.get_instance_id()), "position": _vec(shot.global_position),
					"direction": _vec(shot.direction), "shooter": shot.shooter})
	return {"crates": rows, "shots": projectiles, "break_sequence": game.break_sequence,
		"break_kind": game.break_kind, "break_position": _vec(game.break_position)}


static func valid(world: Variant, count: int, lab: bool) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 5:
		return false
	if not _integer(world.get("break_sequence"), 0, 1000000) or not _integer(world.get("break_kind"), 0, 4 if lab else 1) or not _vector(world.get("break_position")):
		return false
	if not world.get("crates") is Array or world.crates.size() > 14 or not world.get("shots") is Array or world.shots.size() > (128 if lab else 0):
		return false
	var ids := {}
	for row in world.crates:
		if not row is Dictionary or row.size() != 3 or not _id(row.get("id"), ids) or not _vector(row.get("position")) or not _integer(row.get("kind"), 0, 2 if lab else 1):
			return false
	for row in world.shots:
		if not row is Dictionary or row.size() != 4 or not _id(row.get("id"), ids) or not _vector(row.get("position")) or not _vector(row.get("direction")) or not _integer(row.get("shooter"), 0, count - 1):
			return false
		var direction := Vector3(row.direction[0], row.direction[1], row.direction[2])
		if absf(direction.length_squared() - 1.0) > 0.01 or absf(direction.y) > 0.001:
			return false
	return true


static func _id(value: Variant, seen: Dictionary) -> bool:
	if not value is String or value.is_empty() or value.length() > 18 or not value.is_valid_int() or value.to_int() <= 0 or str(value.to_int()) != value or seen.has(value):
		return false
	seen[value] = true
	return true


static func _integer(value: Variant, low: int, high: int) -> bool:
	return Number._number(value) and value == floorf(value) and value >= low and value <= high


static func _vector(value: Variant) -> bool:
	return value is Array and value.size() == 3 and value.all(func(component): return Number._number(component) and absf(component) <= 10000.0)


static func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func render(game: Node, world: Dictionary, delta: float, snap: bool, play_events: bool) -> void:
	if not initialized:
		game.cleanup()
		initialized = true
	var present := {}
	for row in world.crates:
		present[row.id] = true
		if crates.has(row.id) and crates[row.id].get_meta("kind") != int(row.kind):
			_remove(crates, row.id)
		if not crates.has(row.id):
			var view := MeshFactory.crate(1.5, COLORS[int(row.kind)], ACCENTS[int(row.kind)])
			view.set_meta("kind", int(row.kind))
			add_child(view)
			crates[row.id] = view
		crates[row.id].global_position = Vector3(row.position[0], row.position[1], row.position[2])
	_prune(crates, present)
	present.clear()
	for row in world.shots:
		present[row.id] = true
		if shots.has(row.id) and shots[row.id].get_meta("shooter") != int(row.shooter):
			_remove(shots, row.id)
		var created := not shots.has(row.id)
		if created:
			var view := Node3D.new()
			var color: Color = UIKit.adapt(game.ctx.config.players[int(row.shooter)].color())
			view.add_child(MeshFactory.sphere(0.26, color, 2.0))
			var tail := MeshFactory.box(Vector3(0.16, 0.16, 0.9), color, 1.4)
			tail.position.z = 0.5
			view.add_child(tail)
			view.set_meta("shooter", int(row.shooter))
			add_child(view)
			shots[row.id] = view
		var view: Node3D = shots[row.id]
		var position := Vector3(row.position[0], row.position[1], row.position[2])
		view.global_position = position if created or snap else view.global_position.lerp(position, clampf(delta * 22, 0, 1))
		view.look_at(view.global_position + Vector3(row.direction[0], row.direction[1], row.direction[2]), Vector3.UP)
	_prune(shots, present)
	var sequence := int(world.break_sequence)
	if play_events and last_break >= 0 and sequence > last_break:
		var kind := int(world.break_kind)
		var position := Vector3(world.break_position[0], world.break_position[1], world.break_position[2])
		AudioManager.play_sfx(SOUNDS[kind], position)
		var burst := MeshFactory.burst(ACCENTS[1] if kind == 1 else COLORS[2 if kind >= 2 else 0], 14)
		add_child(burst)
		burst.global_position = position
	last_break = maxi(last_break, sequence)


func _prune(views: Dictionary, present: Dictionary) -> void:
	for id in views.keys():
		if not present.has(id):
			_remove(views, id)


func _remove(views: Dictionary, id: String) -> void:
	views[id].hide()
	views[id].queue_free()
	views.erase(id)
