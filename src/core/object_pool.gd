extends Node
## Reusable node pools. Autoload name: `Pool`.
##
## Mini-games spawn a lot of short-lived nodes — pickups, projectiles, shards,
## floating score labels. Allocating and freeing them mid-match is the main
## source of frame spikes on the mobile renderer, so anything that appears more
## than a few times per round is checked out from here instead.

var _pools := {}
var _factories := {}
var _live := {}
var _peak := {}


## Register how to build one instance of `key`. Safe to call repeatedly.
func define(key: String, factory: Callable, prewarm: int = 0) -> void:
	_factories[key] = factory
	if not _pools.has(key):
		_pools[key] = []
		_live[key] = 0
		_peak[key] = 0
	for i in prewarm:
		var n = factory.call()
		if n is Node:
			n.set_process(false)
			n.set_physics_process(false)
			_pools[key].append(n)


func acquire(key: String) -> Node:
	if not _factories.has(key):
		Log.e("pool '%s' used before define()" % key, "Pool")
		return null
	var list: Array = _pools[key]
	var n: Node
	if list.is_empty():
		n = _factories[key].call()
	else:
		n = list.pop_back()
	if n == null:
		return null
	n.set_process(true)
	n.set_physics_process(true)
	if n.has_method("on_acquired"):
		n.call("on_acquired")
	_live[key] = int(_live[key]) + 1
	_peak[key] = maxi(int(_peak[key]), int(_live[key]))
	return n


func release(key: String, node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	# Deliberately does NOT reparent: removing a CollisionObject during a
	# physics callback is illegal in Godot, and pools here are per-match
	# (MatchScene.teardown drains them), so leaving the node in place is both
	# safe and cheaper.
	node.set_process(false)
	node.set_physics_process(false)
	if node.has_method("on_released"):
		node.call("on_released")
	if not _pools.has(key):
		_pools[key] = []
	_pools[key].append(node)
	_live[key] = maxi(0, int(_live.get(key, 0)) - 1)


## Frees every pooled instance. Called when a match tears down so an arena's
## bespoke objects do not leak into the next one.
func drain(key: String = "") -> void:
	var keys := [key] if key != "" else _pools.keys()
	for k in keys:
		for n in _pools.get(k, []):
			if is_instance_valid(n):
				n.queue_free()
		_pools[k] = []
		_live[k] = 0
		if key != "":
			_factories.erase(k)
	if key == "":
		_factories.clear()


func stats() -> Dictionary:
	var out := {}
	for k in _pools:
		out[k] = {"free": _pools[k].size(), "live": _live.get(k, 0), "peak": _peak.get(k, 0)}
	return out
