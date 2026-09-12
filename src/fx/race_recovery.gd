extends Node3D
## Original rescue effect, driven by match time so pausing freezes it too.
var rings: Array[Node3D] = []


func _ready() -> void:
	name = "RecoveryHalo"
	for i in 3:
		var ring := MeshFactory.torus(0.95 + i * 0.12, 1.03 + i * 0.12, Color("76e1e8"), 0.6)
		ring.position.y = i * 0.55
		ring.rotation.x = i * 0.4
		add_child(ring)
		rings.append(ring)


func animate(progress: float) -> void:
	for i in rings.size():
		rings[i].rotation.y = progress * TAU * (2.0 + i * 0.5)
		rings[i].rotation.z = sin(progress * TAU + i) * 0.35
		if bool(UserSettings.get_value("reduce_effects")):
			rings[i].visible = i == 0
