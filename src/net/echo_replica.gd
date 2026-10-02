extends RefCounted
## Only the presently visible cue crosses the wire, never the answer sequence.
const Number = preload("res://src/net/goal_guard_replica.gd")
const EVENTS := {"flash_sequence": "tick", "correct_sequence": "correct",
	"wrong_sequence": "wrong", "finish_sequence": "score"}
var sequences := {}


static func capture(game: Node) -> Dictionary:
	var pad: int = game.visible_symbol()
	var world := {"stage": game._stage, "serial": game.sequence_serial(),
		"length": game.sequence_length(), "pad": pad, "step": game.visible_step(),
		"flash_left": game._flash_remaining if pad >= 0 else 0.0,
		"progress": Array(game._progress), "mistakes": Array(game._mistakes),
		"finished": Array(game._finished)}
	for key in EVENTS:
		world[key] = game.get(key)
	return world


static func valid(world: Variant, count: int) -> bool:
	if count < 2 or count > 4 or not world is Dictionary or world.size() != 13:
		return false
	if not _integer(world.get("stage"), 0, 2) or not _integer(world.get("serial"), 0, 1000000) or not _integer(world.get("length"), 1, 9):
		return false
	if not _integer(world.get("pad"), -1, 4) or not _integer(world.get("step"), -1, int(world.length) - 1):
		return false
	if not Number._number(world.get("flash_left")) or world.flash_left < 0 or world.flash_left > 5:
		return false
	if world.pad < 0:
		if world.step != -1 or world.flash_left != 0:
			return false
	elif world.stage != 0 or world.step < 0 or world.flash_left <= 0:
		return false
	for key in EVENTS:
		if not _integer(world.get(key), 0, 1000000):
			return false
	for key in ["progress", "mistakes"]:
		if not world.get(key) is Array or world[key].size() != count:
			return false
		for value in world[key]:
			if not _integer(value, 0, int(world.length) if key == "progress" else 1000000):
				return false
	if not world.get("finished") is Array or world.finished.size() > count:
		return false
	var seen := {}
	for slot in world.finished:
		if not _integer(slot, 0, count - 1) or seen.has(int(slot)) or world.progress[int(slot)] != world.length:
			return false
		seen[int(slot)] = true
	for slot in count:
		if (world.progress[slot] == world.length) != seen.has(slot):
			return false
		if world.stage == 0 and world.progress[slot] != 0:
			return false
	return true


static func _integer(value: Variant, low: int, high: int) -> bool:
	return Number._number(value) and value == floorf(value) and value >= low and value <= high


func render(game: Node, world: Dictionary, play_events: bool) -> void:
	game._sequence.clear()
	game._stage = int(world.stage)
	game._serial = int(world.serial)
	game._length = int(world.length)
	game._show_index = int(world.step) + 1
	game._finished.clear()
	for slot in world.finished:
		game._finished.append(int(slot))
	for slot in world.progress.size():
		game._progress[slot] = int(world.progress[slot])
		game._mistakes[slot] = int(world.mistakes[slot])
	game._reset_pad_colors()
	game._flash_index = int(world.pad)
	game._flash_remaining = float(world.flash_left)
	if world.pad >= 0:
		game._pads[int(world.pad)].mesh.material_override = MeshFactory.toon(UIKit.ACCENT, 1.6)
	for key in EVENTS:
		var sequence := int(world[key])
		if play_events and sequences.has(key) and sequence > int(sequences[key]):
			if key == "flash_sequence":
				if world.pad >= 0:
					AudioManager.play_sfx("tick", game.pad_position(int(world.pad)), 0.8 + float(world.pad) * 0.12)
			else:
				AudioManager.play_sfx(EVENTS[key])
		sequences[key] = maxi(int(sequences.get(key, -1)), sequence)
