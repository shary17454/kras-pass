class_name OperationTrace
extends RefCounted
## Opt-in CPU wall intervals; nested operations are inclusive, not additive.

const MAX_TAGS := 32
const MAX_SAMPLES := 8
const SLOW_USEC := 4000
const MAX_CONTACTS := 8

var enabled := false
var _costs := {}
var _slow: Array[Dictionary] = []
var _slow_count := 0
var _physics_slow: Array[Dictionary] = []
var _physics_slow_count := 0


func configure(debug_allowed: bool, requested: bool) -> void:
	enabled = debug_allowed and requested
	reset()


func reset() -> void:
	_costs.clear()
	_slow.clear()
	_slow_count = 0
	_physics_slow.clear()
	_physics_slow_count = 0


func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0


func finish(tag: String, started: int) -> void:
	if not enabled or started <= 0:
		return
	record(tag, started, Time.get_ticks_usec(), Engine.get_physics_frames(), Engine.get_process_frames())


func finish_physics(actor: CharacterBody3D, slot: int, started: int) -> void:
	if not enabled or started <= 0:
		return
	# Stop the timer before collecting optional diagnostics.
	var ended := Time.get_ticks_usec()
	record("fighter.physics", started, ended, Engine.get_physics_frames(), Engine.get_process_frames())
	if ended - started < SLOW_USEC or not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	var contacts: Array[Dictionary] = []
	for index in mini(actor.get_slide_collision_count(), MAX_CONTACTS):
		var collider = actor.get_slide_collision(index).get_collider()
		if is_instance_valid(collider) and collider is Node:
			var contact := {"node": String(collider.name).left(64), "class": collider.get_class()}
			if not contacts.has(contact):
				contacts.append(contact)
	var p := actor.global_position
	_physics_slow_count += 1
	_physics_slow.append({"slot": slot, "elapsed_usec": ended - started,
		"physics_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(),
		"position": [p.x, p.y, p.z], "contacts": contacts})
	_physics_slow.sort_custom(func(a, b): return a.elapsed_usec > b.elapsed_usec)
	if _physics_slow.size() > MAX_SAMPLES:
		_physics_slow.resize(MAX_SAMPLES)


func record(tag: String, started: int, ended: int, physics_frame: int, process_frame: int) -> void:
	if not enabled or started <= 0 or ended < started or tag.is_empty() or tag.length() > 64:
		return
	if not _costs.has(tag) and _costs.size() >= MAX_TAGS:
		return
	var elapsed := ended - started
	var cost: Dictionary = _costs.get(tag, {"calls": 0, "total_usec": 0, "max_usec": 0})
	cost.calls += 1
	cost.total_usec += elapsed
	cost.max_usec = maxi(cost.max_usec, elapsed)
	_costs[tag] = cost
	if elapsed < SLOW_USEC:
		return
	_slow_count += 1
	_slow.append({"tag": tag, "elapsed_usec": elapsed, "started_usec": started,
		"ended_usec": ended, "physics_frame": physics_frame, "process_frame": process_frame})
	_slow.sort_custom(func(a, b): return a.elapsed_usec > b.elapsed_usec)
	if _slow.size() > MAX_SAMPLES:
		_slow.resize(MAX_SAMPLES)


func report() -> Dictionary:
	return {"costs": _costs.duplicate(true), "slow_count": _slow_count,
		"retained": _slow.duplicate(true), "threshold_usec": SLOW_USEC,
		"physics_contacts": _physics_slow.duplicate(true), "physics_slow_count": _physics_slow_count,
		"scope": "inclusive-script-wall-intervals-not-GPU-or-exclusive-CPU"}
