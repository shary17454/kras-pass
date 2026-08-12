class_name PowerUpPickup
extends Area3D
## A floating power-up. Pooled — never freed mid-match.

signal collected(pickup: PowerUpPickup, slot: int)

var def: PowerUpDef
var active := false

var _visual: Node3D
var _label: Label3D
var _bob := 0.0
var _base_y := 1.1


func _init() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.05
	cs.shape = sphere
	add_child(cs)
	body_entered.connect(_on_body_entered)


func configure(d: PowerUpDef) -> void:
	def = d
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
	_visual = MeshFactory.pickup_shell(d.color)
	add_child(_visual)
	if _label == null:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.font_size = 96
		_label.pixel_size = 0.006
		_label.outline_size = 24
		_label.position = Vector3(0, 0.05, 0)
		add_child(_label)
	_label.text = d.glyph
	_label.modulate = Color.WHITE
	active = true
	visible = true
	set_deferred("monitoring", true)


func on_acquired() -> void:
	active = true
	visible = true
	set_deferred("monitoring", true)
	scale = Vector3.ONE


func on_released() -> void:
	active = false
	visible = false
	set_deferred("monitoring", false)


func tick(delta: float, spin: float, bob_height: float) -> void:
	if not active:
		return
	_bob += delta
	position.y = _base_y + sin(_bob * 2.4) * bob_height
	if _visual != null and is_instance_valid(_visual):
		_visual.rotate_y(spin * delta)


func place(p: Vector3) -> void:
	_base_y = p.y
	position = p
	_bob = float(_base_y * 7.13) + float(p.x * 1.31 + p.z * 2.17)


func _on_body_entered(body: Node) -> void:
	if not active or not (body is Fighter) or not body.alive:
		return
	active = false
	set_deferred("monitoring", false)
	collected.emit(self, body.slot)
