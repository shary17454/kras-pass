class_name Collectible
extends Area3D
## A pickup-able object: gem, star, crate fragment, dropped loot.
##
## Pooled and reused. Joins the `magnetic` group so the Magnet power-up works on
## every collection game without those games knowing the power-up exists.

signal taken(item: Collectible, slot: int)

var kind := "gem"
var value := 1
var available := true
var owner_slot := -1
var lifetime := 0.0        ## 0 = permanent
var visual_color := Color.WHITE
var visual_size := 0.42

var _mesh: Node3D
var _bob := 0.0
var _base_y := 0.9
var _age := 0.0
var _grace := 0.0          ## brief window where the dropper cannot re-take it


func _init() -> void:
	collision_layer = 4
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.85
	cs.shape = s
	add_child(cs)
	add_to_group("collectibles")
	add_to_group("magnetic")


func configure(item_kind: String, color: Color, item_value: int = 1, size: float = 0.42) -> void:
	kind = item_kind
	value = item_value
	visual_color = color
	visual_size = size
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.queue_free()
	_mesh = make_visual(item_kind, color, size)
	add_child(_mesh)


static func make_visual(item_kind: String, color: Color, size: float) -> Node3D:
	match item_kind:
		"star":
			var visual := Node3D.new()
			for i in 2:
				var b := MeshFactory.box(Vector3(size * 2.0, size * 0.5, size * 0.5), color, 1.3)
				b.rotation.y = PI * 0.25 + PI * 0.5 * i
				visual.add_child(b)
			return visual
		"crate":
			return MeshFactory.crate(size * 2.2, color, color.lightened(0.35))
		_:
			return MeshFactory.gem(size, color)


func place(p: Vector3) -> void:
	global_position = p
	_base_y = p.y
	_bob = float(p.x * 1.31 + p.z * 2.17)
	_age = 0.0
	available = true
	visible = true
	set_deferred("monitoring", true)


## Thrown loot: an arc away from the dropper so it does not land underfoot.
func scatter_from(p: Vector3, dropper: int, rng: RandomNumberGenerator) -> void:
	var ang := rng.randf() * TAU
	var dist := rng.randf_range(1.4, 3.2)
	place(p + Vector3(cos(ang) * dist, 0, sin(ang) * dist))
	owner_slot = dropper
	_grace = 0.7


func tick(delta: float, rng: RandomNumberGenerator = null, can_take: Callable = Callable()) -> void:
	if not available:
		return
	_bob += delta
	_age += delta
	_grace = maxf(0.0, _grace - delta)
	global_position.y = _base_y + sin(_bob * 3.0) * 0.16
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.rotate_y(delta * 2.2)
	if lifetime > 0.0 and _age > lifetime:
		available = false
		set_deferred("monitoring", false)
		visible = false
		return
	if not is_monitoring():
		return
	var collector := _select_collector(get_overlapping_bodies(), rng, can_take)
	if collector != null:
		available = false
		set_deferred("monitoring", false)
		taken.emit(self, collector.slot)


func _select_collector(bodies: Array, rng: RandomNumberGenerator = null, can_take: Callable = Callable()) -> Fighter:
	if bodies.is_empty():
		return null
	var nearest := INF
	var candidates: Array[Fighter] = []
	for body in bodies:
		if not is_instance_valid(body) or not (body is Fighter) or not body.alive:
			continue
		if _grace > 0.0 and body.slot == owner_slot:
			continue
		if can_take.is_valid() and not can_take.call(body):
			continue
		var distance := global_position.distance_squared_to(body.global_position)
		if distance < nearest:
			nearest = distance
			candidates.clear()
			candidates.append(body)
		elif distance == nearest:
			candidates.append(body)
	if candidates.is_empty():
		return null
	if candidates.size() == 1:
		return candidates[0]
	# Physics overlap order is not a gameplay priority or a replay identity.
	candidates.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.slot < b.slot)
	return candidates[rng.randi_range(0, candidates.size() - 1)] if rng != null else candidates[0]


func is_available() -> bool:
	return available


func on_acquired() -> void:
	available = true
	visible = true
	set_deferred("monitoring", true)
	owner_slot = -1
	_grace = 0.0
	lifetime = 0.0


func on_released() -> void:
	available = false
	visible = false
	set_deferred("monitoring", false)
