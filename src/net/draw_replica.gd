extends RefCounted
## Present host decisions without leaking the hidden pre-signal countdown.
const Number = preload("res://src/net/goal_guard_replica.gd")
const EVENTS := {"signal_sequence": "go", "correct_sequence": "correct",
	"wrong_sequence": "wrong", "resolve_sequence": "score"}
var sequences := {}


static func capture(game: Node) -> Dictionary:
	var locked: Array = []
	for slot in game.ctx.player_count():
		locked.append(game.is_locked(slot))
	var world := {"stage": game._stage, "prompt": game._round_no,
		"order": Array(game._order), "locked": locked}
	for key in EVENTS:
		world[key] = game.get(key)
	return world


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary:
		return false
	# Reject hidden timing fields as well as unknown protocol extensions.
	if world.size() != 8 or not _integer(world.get("stage"), 2) or not _integer(world.get("prompt"), 1000000):
		return false
	for key in EVENTS:
		if not _integer(world.get(key), 1000000):
			return false
	if not world.get("locked") is Array or world.locked.size() != count:
		return false
	for value in world.locked:
		if not value is bool:
			return false
	if not world.get("order") is Array or world.order.size() > count:
		return false
	var seen := {}
	for slot in world.order:
		if not _integer(slot, count - 1) or seen.has(int(slot)) or world.locked[int(slot)]:
			return false
		seen[int(slot)] = true
	return int(world.stage) != 0 or world.order.is_empty()


static func _integer(value: Variant, limit: int) -> bool:
	return Number._number(value) and value == floorf(value) and value >= 0 and value <= limit


func render(game: Node, world: Dictionary, play_events: bool) -> void:
	game._stage = int(world.stage)
	game._round_no = int(world.prompt)
	game._order.clear()
	game._locked.clear()
	for slot in world.order:
		game._order.append(int(slot))
	for slot in world.locked.size():
		if world.locked[slot]:
			game._locked[slot] = true
	if is_instance_valid(game._pillar):
		game._pillar.material_override = MeshFactory.toon(Color("#ffd23f"), 2.4) if int(world.stage) == 1 else MeshFactory.toon(UIKit.PANEL_HI)
	for key in EVENTS:
		var sequence := int(world[key])
		if play_events and sequences.has(key) and sequence > int(sequences[key]):
			if key != "resolve_sequence" or not world.order.is_empty():
				AudioManager.play_sfx(EVENTS[key])
		sequences[key] = maxi(int(sequences.get(key, -1)), sequence)
