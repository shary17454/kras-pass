extends Node3D
## Host bomb presentation only: no fuse tick, pickups, throws or blast damage.

const Number = preload("res://src/net/goal_guard_replica.gd")
const Bomb = preload("res://src/minigames/fawda.gd")
const EVENTS := ["drop", "pickup", "throw", "explode"]
var views := {}
var _round := -1
var _sequences := {}


static func capture(game: Node) -> Dictionary:
	var bombs: Array = []
	for b in game._bombs:
		if is_instance_valid(b.node):
			bombs.append({"id": b.id, "position": Number._vec(b.node.global_position),
				"velocity": Number._vec(b.vel), "fuse": maxf(0.0, b.fuse), "held": b.held, "thrower": b.thrower})
	var carrying: Array = []
	for f in game.ctx.fighters: carrying.append(f.carrying)
	var events := {}
	for kind in EVENTS:
		var event: Dictionary = game.bomb_events[kind]
		events[kind] = {"sequence": event.sequence, "position": Number._vec(event.position)}
	return {"bombs": bombs, "carrying": carrying, "events": events}


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 3:
		return false
	if not world.get("bombs") is Array or world.bombs.size() > Bomb.MAX_LIVE \
		or not world.get("carrying") is Array or world.carrying.size() != count:
		return false
	for value in world.carrying:
		if not _integer(value, 0, 1): return false
	var ids := {}
	var holders := {}
	for b in world.bombs:
		if not b is Dictionary or b.size() != 6 or not _integer(b.get("id"), 1, 1000000):
			return false
		if ids.has(b.id) or not _vector(b.get("position")) or not _vector(b.get("velocity")) \
			or not Number._number(b.get("fuse")) or b.fuse < 0 or b.fuse > Bomb.FUSE_TIME \
			or not _integer(b.get("held"), -1, count - 1) or not _integer(b.get("thrower"), -1, count - 1):
			return false
		ids[b.id] = true
		if b.held >= 0:
			if holders.has(b.held): return false
			holders[b.held] = true
	if not world.get("events") is Dictionary or world.events.size() != EVENTS.size(): return false
	for kind in EVENTS:
		var event: Variant = world.events.get(kind)
		if not event is Dictionary or event.size() != 2 or not _integer(event.get("sequence"), 0, 1000000) \
			or not _vector(event.get("position")): return false
	return true


static func _integer(value: Variant, low: int, high: int) -> bool:
	return Number._number(value) and value == floorf(value) and value >= low and value <= high


static func _vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	for v in value:
		if not Number._number(v) or absf(v) > 10000.0: return false
	return true


func render(game: Node, world: Dictionary, round_index: int, feedback: bool) -> void:
	var baseline := _round != round_index
	if baseline:
		for id in views.keys(): _remove(id)
	var present := {}
	for b in world.bombs:
		var id := int(b.id)
		present[id] = true
		if not views.has(id):
			var visual := Bomb.make_bomb_visual()
			add_child(visual.node)
			views[id] = visual
		var visual: Dictionary = views[id]
		visual.node.global_position = Vector3(b.position[0], b.position[1], b.position[2])
		Bomb.update_bomb_visual(visual, float(b.fuse))
	for id in views.keys():
		if not present.has(id): _remove(id)
	for slot in game.ctx.player_count(): game.ctx.fighter(slot).carrying = int(world.carrying[slot])
	for kind in EVENTS:
		var event: Dictionary = world.events[kind]
		if feedback and not baseline and int(event.sequence) > int(_sequences.get(kind, 0)):
			var pos := Vector3(event.position[0], event.position[1], event.position[2])
			match kind:
				"drop": AudioManager.play_sfx("tick", pos, 0.7)
				"pickup": AudioManager.play_sfx("pickup", pos)
				"throw": AudioManager.play_sfx("swing", pos)
				"explode": game.present_bomb_explosion(pos)
		_sequences[kind] = int(event.sequence)
	_round = round_index


func _remove(id: int) -> void:
	var visual: Dictionary = views[id]
	visual.node.hide()
	visual.node.queue_free()
	views.erase(id)
