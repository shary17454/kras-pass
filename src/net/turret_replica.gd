extends Node3D
## Presentation-only shots. Reused pooled bodies get a distinct launch generation.

const Fields = preload("res://src/net/crate_replica.gd")
var shots := {}
var initialized := false
var last_round := -1


static func capture(game: Node) -> Dictionary:
	var projectiles: Array = []
	for shot in game._shots:
		if is_instance_valid(shot) and shot.active:
			projectiles.append({"id": str(shot.get_instance_id()), "generation": shot.launch_serial,
				"position": Fields._vec(shot.global_position), "direction": Fields._vec(shot.direction), "shooter": shot.shooter})
	var damage: Array = []
	for fighter in game.ctx.fighters:
		damage.append(fighter.damage_percent)
	return {"shots": projectiles, "cooldowns": game._cooldowns.duplicate(), "damage": damage}


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 3:
		return false
	for field in ["cooldowns", "damage"]:
		if not world.get(field) is Array or world[field].size() != count:
			return false
		for value in world[field]:
			if not Fields.Number._number(value) or value < 0.0 or value > (60.0 if field == "cooldowns" else 10000.0):
				return false
	if not world.get("shots") is Array or world.shots.size() > 128:
		return false
	var ids := {}
	for row in world.shots:
		if not row is Dictionary or row.size() != 5 or not Fields._id(row.get("id"), ids) or not Fields._integer(row.get("generation"), 1, 1000000) \
			or not Fields._integer(row.get("shooter"), 0, count - 1) or not Fields._vector(row.get("position")) or not Fields._vector(row.get("direction")):
			return false
		var direction := Vector3(row.direction[0], row.direction[1], row.direction[2])
		if absf(direction.length_squared() - 1.0) > 0.01 or absf(direction.y) > 0.001:
			return false
	return true


func render(game: Node, world: Dictionary, round_index: int, delta: float, snap: bool, play_events: bool) -> void:
	if not initialized:
		game.cleanup()
		initialized = true
	var new_round := last_round != round_index
	if new_round:
		for key in shots.keys():
			_remove(key)
	last_round = round_index
	for slot in game.ctx.player_count():
		game._cooldowns[slot] = float(world.cooldowns[slot])
		game.ctx.fighter(slot).damage_percent = float(world.damage[slot])
	var present := {}
	for row in world.shots:
		var key: String = row.id + ":" + str(int(row.generation))
		present[key] = true
		if shots.has(key) and shots[key].get_meta("shooter") != int(row.shooter):
			_remove(key)
		var created := not shots.has(key)
		if created:
			var view := Node3D.new()
			var color: Color = UIKit.adapt(game.ctx.config.players[int(row.shooter)].color())
			view.add_child(MeshFactory.sphere(0.26, color, 2.0))
			var tail := MeshFactory.box(Vector3(0.16, 0.16, 0.9), color, 1.4)
			tail.position.z = 0.5
			view.add_child(tail)
			view.set_meta("shooter", int(row.shooter))
			add_child(view)
			shots[key] = view
		var view: Node3D = shots[key]
		var position := Vector3(row.position[0], row.position[1], row.position[2])
		view.global_position = position if created or snap else view.global_position.lerp(position, clampf(delta * 22.0, 0.0, 1.0))
		view.look_at(view.global_position + Vector3(row.direction[0], row.direction[1], row.direction[2]), Vector3.UP)
		if created and play_events and not new_round:
			AudioManager.play_sfx("swing", position, 0.7)
	for key in shots.keys():
		if not present.has(key):
			_remove(key)


func _remove(key: String) -> void:
	shots[key].hide()
	shots[key].queue_free()
	shots.erase(key)
