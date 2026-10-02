extends Node3D
## Host-owned weapon inventory and road hazards, with no guest simulation.

const Kart = preload("res://src/net/kart_replica.gd")
const Shots = preload("res://src/net/turret_replica.gd")
const Fields = preload("res://src/net/crate_replica.gd")
const Race = preload("res://src/minigames/sabaq_sawarikh.gd")
var race: Node3D = Kart.new()
var projectiles: Node3D = Shots.new()
var bombs := {}
var _round := -1


func _init() -> void:
	add_child(race)
	add_child(projectiles)


static func capture(game: Node) -> Dictionary:
	var crates: Array = []
	for crate in game._crates:
		crates.append({"cooldown": maxf(0.0, crate.cooldown), "rotation": wrapf(crate.node.rotation.y, -PI, PI)})
	var hazards: Array = []
	for bomb in game._bombs:
		hazards.append({"id": str(bomb.node.get_instance_id()), "position": Fields._vec(bomb.pos),
			"owner": bomb.owner, "arm": bomb.arm, "life": bomb.life})
	return {"race": Kart.capture(game), "held": Array(game.held), "shields": Array(game.shielded),
		"crates": crates, "bombs": hazards, "shots": Shots.capture_shots(game._missiles)}


static func valid(world: Variant, count: int, checkpoints: int = 0, crate_count: int = 20) -> bool:
	if not world is Dictionary or world.size() != 6 or not Kart.valid(world.get("race"), count, checkpoints):
		return false
	for field in ["held", "shields"]:
		if not world.get(field) is Array or world[field].size() != count: return false
	for slot in count:
		if not Fields._integer(world.held[slot], Race.Item.NONE, Race.Item.SHIELD) \
			or not Fields.Number._number(world.shields[slot]) or world.shields[slot] < 0.0 or world.shields[slot] > 6.0:
			return false
	if not world.get("crates") is Array or world.crates.size() != crate_count or crate_count < 1 or crate_count > 20:
		return false
	for crate in world.crates:
		if not crate is Dictionary or crate.size() != 2 or not Fields.Number._number(crate.get("cooldown")) \
			or crate.cooldown < 0.0 or crate.cooldown > Race.CRATE_RESPAWN \
			or not Fields.Number._number(crate.get("rotation")) or absf(crate.rotation) > PI:
			return false
	if not world.get("bombs") is Array or world.bombs.size() > 64: return false
	var seen := {}
	for bomb in world.bombs:
		if not bomb is Dictionary or bomb.size() != 5 or not Fields._id(bomb.get("id"), seen) \
			or not Fields._vector(bomb.get("position")) or not Fields._integer(bomb.get("owner"), 0, count - 1) \
			or not Fields.Number._number(bomb.get("arm")) or bomb.arm < -Race.BOMB_LIFETIME or bomb.arm > Race.BOMB_ARM_DELAY \
			or not Fields.Number._number(bomb.get("life")) or bomb.life <= 0.0 or bomb.life > Race.BOMB_LIFETIME:
			return false
	var empty: Array = []
	empty.resize(count)
	empty.fill(0.0)
	return Shots.valid({"shots": world.get("shots"), "cooldowns": empty, "damage": empty}, count, false)


func render(game: Node, world: Dictionary, round_index: int, delta: float, snap: bool, feedback: bool) -> void:
	if _round != round_index:
		for key in bombs.keys(): _remove_bomb(key)
	race.render(game, world.race, round_index, feedback)
	game.held.assign(world.held)
	game.shielded.assign(world.shields)
	for index in game._crates.size():
		var crate: Dictionary = game._crates[index]
		crate.cooldown = float(world.crates[index].cooldown)
		crate.node.visible = crate.cooldown <= 0.0
		crate.node.rotation.y = float(world.crates[index].rotation)
	var present := {}
	for bomb in world.bombs:
		present[bomb.id] = true
		if not bombs.has(bomb.id):
			var mesh := MeshFactory.sphere(0.42, UIKit.DANGER, 0.9)
			add_child(mesh)
			bombs[bomb.id] = mesh
		var view: Node3D = bombs[bomb.id]
		view.global_position = Vector3(bomb.position[0], bomb.position[1], bomb.position[2])
		view.scale = Vector3.ONE * (1.0 + sin(float(bomb.life) * 9.0) * 0.09)
	for key in bombs.keys():
		if not present.has(key): _remove_bomb(key)
	projectiles.render_shots(game, world.shots, round_index, delta, snap, feedback)
	_round = round_index


func _remove_bomb(key: String) -> void:
	bombs[key].hide()
	bombs[key].queue_free()
	bombs.erase(key)
