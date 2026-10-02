extends "res://src/net/turret_replica.gd"
## Shares projectile presentation, never ammunition, fuse or armor simulation.

const Turret = preload("res://src/net/turret_replica.gd")
const Tank = preload("res://src/minigames/tank_arena.gd")
var playing := false


static func capture(game: Node) -> Dictionary:
	var world := Turret.capture(game)
	var active: Array = []
	for shot in game._shots:
		if is_instance_valid(shot) and shot.active:
			active.append(shot)
	for index in world.shots.size():
		world.shots[index]["kind"] = active[index].shell_kind
		world.shots[index]["fuse"] = maxf(-1.0, active[index]._sticky_left)
	world["armor"] = game.armor.duplicate()
	world["ammo"] = game.ammo.duplicate()
	world["shell_types"] = game.shell_types.duplicate()
	var crates: Array = []
	for crate in game.crates:
		crates.append({"cooldown": crate.cooldown, "rotation": wrapf(crate.node.rotation.y, -PI, PI)})
	world["crates"] = crates
	return world


static func valid(world: Variant, count: int, horizontal := false) -> bool:
	if not world is Dictionary or world.size() != 7 or not world.get("shots") is Array or world.shots.size() > 128:
		return false
	var base_shots: Array = []
	for row in world.shots:
		if not row is Dictionary or row.size() != 7 or not Fields._integer(row.get("kind"), 0, 6) \
			or not Fields.Number._number(row.get("fuse")) or row.fuse < -1.0 or row.fuse > 2.0 \
			or (row.fuse < 0.0 and row.fuse != -1.0) or (row.kind != 6 and row.fuse != -1.0):
			return false
		var base: Dictionary = row.duplicate()
		base.erase("kind")
		base.erase("fuse")
		base_shots.append(base)
	if not Turret.valid({"shots": base_shots, "cooldowns": world.get("cooldowns"), "damage": world.get("damage")}, count, horizontal):
		return false
	for field in ["armor", "ammo", "shell_types"]:
		if not world.get(field) is Array or world[field].size() != count:
			return false
		for value in world[field]:
			if not Fields._integer(value, 0, 100 if field == "armor" else 6):
				return false
	for slot in count:
		var ammo := int(world.ammo[slot])
		var kind := int(world.shell_types[slot])
		if (ammo == 0) != (kind == 0) or ammo > (6 if kind == 1 else 3):
			return false
	if not world.get("crates") is Array or world.crates.size() != 5:
		return false
	for row in world.crates:
		if not row is Dictionary or row.size() != 2 or not Fields.Number._number(row.get("cooldown")) \
			or row.cooldown < 0.0 or row.cooldown > Tank.CRATE_RESPAWN \
			or not Fields.Number._number(row.get("rotation")) or absf(row.rotation) > PI:
			return false
	return true


func render(game: Node, world: Dictionary, round_index: int, delta: float, snap: bool, play_events: bool) -> void:
	for row in world.shots:
		var key: String = row.id + ":" + str(int(row.generation))
		if shots.has(key) and int(shots[key].get_meta("kind", -1)) != int(row.kind):
			_remove(key)
	super.render(game, world, round_index, delta, snap, play_events)
	for slot in game.ctx.player_count():
		game.armor[slot] = int(world.armor[slot])
		game.ammo[slot] = int(world.ammo[slot])
		game.shell_types[slot] = int(world.shell_types[slot])
	for index in game.crates.size():
		var crate: Dictionary = game.crates[index]
		crate.cooldown = float(world.crates[index].cooldown)
		crate.node.visible = crate.cooldown <= 0.0
		crate.node.rotation.y = float(world.crates[index].rotation)
	for row in world.shots:
		var key: String = row.id + ":" + str(int(row.generation))
		var view: Node3D = shots[key]
		view.set_meta("kind", int(row.kind))
		view.set_meta("fuse", float(row.fuse))
		view.scale = Vector3.ONE * (1.0 + (0.18 * sin(float(row.fuse) * 18.0) if row.fuse >= 0.0 else 0.0))
	if is_instance_valid(game._engine):
		var speed := -1.0
		if playing:
			for slot in game.ctx.player_count():
				if InputRouter.is_human(slot) and game.ctx.is_alive(slot):
					speed = game.ctx.fighter(slot).velocity.length()
					break
		if speed < 0.0:
			game._engine.stop()
		else:
			game._engine.pitch_scale = lerpf(game._engine.pitch_scale, 0.7 + minf(speed / 10.0, 1.4), clampf(delta * 5.0, 0.0, 1.0))
			if not game._engine.playing:
				game._engine.play()


func _shot_color(_game: Node, row: Dictionary) -> Color:
	return Tank.SHELL_COLORS[int(row.kind)]


func _launch_sound(row: Dictionary, position: Vector3) -> void:
	AudioManager.play_sfx("cannon_fire", position, 0.7 if int(row.kind) == 2 else 1.0)
