extends "res://src/ai/brains/generic_brain.gd"
## Crate Smash: break safe crates, avoid the rigged ones.
##
## Crucially the bot does **not** read the `bomb` flag. It reads the crate's
## colour — the same tell the player gets — and its chance of reading it
## correctly is `accuracy`. An Easy bot blows itself up regularly; an Expert bot
## almost never does, but still can.

const BOMB_COLOR := Color("#3a2b3f")

var _judgements := {}


func on_configured() -> void:
	super.on_configured()
	_judgements.clear()


func on_round_start() -> void:
	super.on_round_start()
	_judgements.clear()


func decide(_delta: float) -> void:
	var me := self_body()
	if me == null or controller == null:
		return
	var target: Node3D = _pick_crate()
	if target == null:
		super.decide(_delta)
		return
	var pos := perceived_object_position(target)
	steer_to(pos)
	if distance_to(pos) < 2.4:
		tap(Btn.ATTACK)
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
	var observed := {}
	for entry in entries:
		var node: Node3D = entry["node"]
		var position := perceived_object_position(node)
		if position == Vector3.INF:
			continue
		var cue := _visible_bomb_cue(node)
		if cue < 0:
			continue
		var id := node.get_instance_id()
		observed[id] = true
		if not _judgements.has(id):
			# Judge it once, from the visible colour, and live with the verdict.
			var reads_bomb: bool = cue == 1 if rng.randf() < accuracy else cue != 1
			_judgements[id] = reads_bomb
		if bool(_judgements[id]):
			continue
		var d: float = me.global_position.distance_squared_to(position)
		if d < best_d:
			best_d = d
			best = node
	for id in _judgements.keys():
		if not observed.has(id):
			_judgements.erase(id)
	return best


func _visible_bomb_cue(node: Node3D) -> int:
	var body := node.find_child("CrateBody", true, false) as MeshInstance3D
	if not can_observe(body) or body.mesh == null or body.mesh.get_surface_count() == 0:
		return -1
	var material := body.get_active_material(0) as BaseMaterial3D
	if material == null:
		return -1
	return 1 if material.albedo_color.is_equal_approx(BOMB_COLOR) else 0
