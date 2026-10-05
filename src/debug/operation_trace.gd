class_name OperationTrace
extends RefCounted
## Opt-in CPU wall intervals; nested operations are inclusive, not additive.

const MAX_TAGS := 32
const MAX_SAMPLES := 8
const SLOW_USEC := 4000

var enabled := false
var _costs := {}
var _slow: Array[Dictionary] = []
var _slow_count := 0


func configure(debug_allowed: bool, requested: bool) -> void:
	enabled = debug_allowed and requested
	reset()


func reset() -> void:
	_costs.clear()
	_slow.clear()
	_slow_count = 0


func begin() -> int:
	return Time.get_ticks_usec() if enabled else 0


func finish(tag: String, started: int) -> void:
	if not enabled or started <= 0:
		return
	record(tag, started, Time.get_ticks_usec(), Engine.get_physics_frames(), Engine.get_process_frames())


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
		"scope": "inclusive-script-wall-intervals-not-GPU-or-exclusive-CPU"}
