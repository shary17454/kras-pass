extends RefCounted

const Driver = preload("res://tests/network_peer.gd")
const Preparation = preload("res://src/match/match_resource_preparation.gd")

class PendingPreparation extends "res://src/match/match_resource_preparation.gd":
	var evidence: Dictionary
	var worker_state := ResourceLoader.THREAD_LOAD_IN_PROGRESS
	func _status(_path: String) -> int:
		return worker_state
	func _take(_path: String) -> Resource:
		evidence.retrieved += 1
		evidence.active_retrieval = worker_state == ResourceLoader.THREAD_LOAD_IN_PROGRESS
		return Resource.new()
	func _process(delta: float) -> void:
		evidence.frames += 1
		if evidence.frames == 3:
			worker_state = ResourceLoader.THREAD_LOAD_LOADED
		super._process(delta)


func run(t: TestHarness, host: Node) -> void:
	t.suite("network failure drains pending resource preparation")
	var tree := host.get_tree()
	var evidence := {"frames": 0, "retrieved": 0, "active_retrieval": false}
	var job := PendingPreparation.new()
	job.evidence = evidence
	job._pending_path = "res://src/match/match_scene.gd"
	host.add_child(job)
	await Driver.drain_preparation(job, tree)
	t.ok(not is_instance_valid(job), "failure cleanup waits until preparation node is freed")
	t.equal(evidence.retrieved, 1, "native worker is drained once after completion")
	t.ok(not evidence.active_retrieval, "in-progress worker is never retrieved synchronously")
	t.equal(evidence.frames, 3, "cleanup keeps yielding while native work is pending")
	var empty := Preparation.new()
	host.add_child(empty)
	await Driver.drain_preparation(empty, tree)
	t.ok(not is_instance_valid(empty), "empty bank is released without an outstanding worker")
	await Driver.drain_preparation(null, tree)
	t.ok(true, "no preparation is a safe cleanup no-op")
