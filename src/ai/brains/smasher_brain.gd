extends "res://src/ai/brains/generic_brain.gd"
## Crate Smash: break safe crates, avoid the rigged ones.
##
## Crucially the bot does **not** read the `bomb` flag. It reads the crate's
## colour — the same tell the player gets — and its chance of reading it
## correctly is `accuracy`. An Easy bot blows itself up regularly; an Expert bot
## almost never does, but still can.

const BOMB_COLOR := Color("#3a2b3f")

var _judgements := {}


func decide(_delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		return
	var target: Node3D = _pick_crate()
	if target == null:
		super.decide(_delta)
		return
	var pos: Vector3 = target.global_position
	steer_to(pos)
	if distance_to(pos) < 2.4:
		press(Btn.ATTACK)
	elif distance_to(pos) > 6.0:
		maybe_dash(0.6)
	keep_off_edge()


func _pick_crate() -> Node3D:
	var entries: Array = controller.call("crate_entries") if controller.has_method("crate_entries") else []
	var me := self_body()
	if me == null:
		return null
	var best: Node3D = null
	var best_d := INF
	for entry in entries:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		var id := node.get_instance_id()
		if not _judgements.has(id):
			# Judge it once, from the visible colour, and live with the verdict.
			var reads_bomb: bool = bool(entry["bomb"]) if rng.randf() < accuracy else not bool(entry["bomb"])
			_judgements[id] = reads_bomb
		if bool(_judgements[id]):
			continue
		var d: float = me.global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best
