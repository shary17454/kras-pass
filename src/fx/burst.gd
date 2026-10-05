extends Node3D
## Self-cleaning shard burst used for hits, breaks and knockouts.
##
## Deliberately not a GPUParticles node: a handful of solid shards reads far
## better against a busy 4-player arena than a soft particle cloud. Bounded
## idle bursts retain their shards; new concurrent peaks can still allocate.

const MAX_IDLE := 8
var pool_key := ""

var _shards: Array = []
var _velocities: Array = []
var _life := 0.5
var _age := 0.0
var _gravity := 14.0
var _active_count := 0
var _idle := false


func configure(color: Color, count: int, spread: float, life: float) -> void:
	on_acquired()
	_life = maxf(0.001, life)
	_active_count = maxi(0, count)
	_velocities.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while _shards.size() < _active_count:
		var m := MeshFactory.box(Vector3(0.16, 0.16, 0.16), color, 0.8)
		add_child(m)
		_shards.append(m)
	for i in _shards.size():
		var shard: MeshInstance3D = _shards[i]
		shard.transform = Transform3D.IDENTITY
		shard.visible = i < _active_count
		if i >= _active_count:
			continue
		shard.material_override = MeshFactory.toon(color, 0.8)
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.3, 1.2), rng.randf_range(-1, 1)).normalized()
		_velocities.append(dir * spread * rng.randf_range(0.7, 1.4))
	set_process(true)


func on_acquired() -> void:
	_idle = false
	_age = 0.0
	transform = Transform3D.IDENTITY
	show()


func on_released() -> void:
	_idle = true
	hide()
	_active_count = 0
	_velocities.clear()


func _process(delta: float) -> void:
	if _idle:
		return
	_age += delta
	var t := _age / _life
	if t >= 1.0:
		if not pool_key.is_empty() and Pool.has_pool(pool_key):
			Pool.release(pool_key, self, MAX_IDLE)
		else:
			queue_free()
		return
	for i in _active_count:
		var s: Node3D = _shards[i]
		var v: Vector3 = _velocities[i]
		v.y -= _gravity * delta
		_velocities[i] = v
		s.position += v * delta
		s.rotate_y(delta * 8.0)
		s.scale = Vector3.ONE * maxf(0.02, 1.0 - t)
