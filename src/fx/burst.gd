extends Node3D
## Self-cleaning shard burst used for hits, breaks and knockouts.
##
## Deliberately not a GPUParticles node: a handful of solid shards reads far
## better against a busy 4-player arena than a soft particle cloud, and it costs
## nothing on the mobile renderer. Shards are returned to the pool on death, so
## a long match does not allocate.

var _shards: Array = []
var _velocities: Array = []
var _life := 0.5
var _age := 0.0
var _gravity := 14.0


func configure(color: Color, count: int, spread: float, life: float) -> void:
	_life = life
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		var m := MeshFactory.box(Vector3(0.16, 0.16, 0.16), color, 0.8)
		add_child(m)
		_shards.append(m)
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.3, 1.2), rng.randf_range(-1, 1)).normalized()
		_velocities.append(dir * spread * rng.randf_range(0.7, 1.4))


func _process(delta: float) -> void:
	_age += delta
	var t := _age / _life
	if t >= 1.0:
		queue_free()
		return
	for i in _shards.size():
		var s: Node3D = _shards[i]
		var v: Vector3 = _velocities[i]
		v.y -= _gravity * delta
		_velocities[i] = v
		s.position += v * delta
		s.rotate_y(delta * 8.0)
		s.scale = Vector3.ONE * maxf(0.02, 1.0 - t)
