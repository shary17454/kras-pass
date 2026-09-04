extends Node3D
class_name SkyDome
## The weather over an arctic arena: drifting cloud decks, falling snow, and a
## far horizon that moves.
##
## The spec asks for a sky with layers, clouds, distant snow and parallax, and
## for it to cost little. Three rules keep that promise:
##
## 1. **No particle system.** Snow is a `MultiMeshInstance3D` — one draw call
##    for hundreds of flakes — and it is animated by moving the whole node and
##    wrapping it, never by rewriting transforms per frame. The rest of the
##    project already avoids GPUParticles for the same reason (see burst.gd).
## 2. **Parallax comes from geometry, not from a shader.** Three cloud decks at
##    three heights turning at three speeds separate by themselves, and the
##    nearest deck moving fastest is the whole of the effect.
## 3. **It is skippable.** Reduced-effects builds get none of it, and the whole
##    dome is one node to delete.

const CLOUD_DECKS := 3
const SNOW_COLUMNS := 3
const FLAKES_PER_COLUMN := 90

var _decks: Array = []      # {node, speed}
var _columns: Array = []    # {node, speed, span, base_y}
var _time := 0.0


func build(radius: float, tint: Color) -> void:
	_build_clouds(radius, tint)
	_build_snow(radius)


func tick(delta: float) -> void:
	_time += delta
	for deck in _decks:
		var node: Node3D = deck["node"]
		if is_instance_valid(node):
			node.rotation.y += float(deck["speed"]) * delta
	for column in _columns:
		var node: Node3D = column["node"]
		if not is_instance_valid(node):
			continue
		# Fall, then wrap. A column is one span tall and the flakes inside it
		# are distributed over exactly that span, so resetting by a whole span
		# is seamless — there is no frame where the sky is empty.
		var span: float = column["span"]
		node.position.y -= float(column["speed"]) * delta
		if node.position.y <= float(column["base_y"]) - span:
			node.position.y += span
		# A slow sway, so snow does not fall like rain on a still day.
		node.position.x = sin(_time * float(column["sway_rate"])) * float(column["sway"])


## Three decks: low and fast, high and slow. Each is a ring of flat slabs rather
## than a textured plane, because the project ships no textures and a slab
## catching the sun reads as cloud from below just fine.
func _build_clouds(radius: float, tint: Color) -> void:
	for deck in CLOUD_DECKS:
		var node := Node3D.new()
		node.name = "CloudDeck%d" % deck
		add_child(node)
		# Low and very far, not high and near. The arena camera sits about 20 m
		# up and pitches down 46 degrees, so with a 58-degree field the top of
		# the frame is still 17 degrees *below* horizontal: this game never
		# looks at the sky. Clouds overhead are geometry nobody will ever see,
		# and clouds overhead-but-close — the first attempt, 24 m over a 16 m
		# ring — fill a quarter of the screen instead. What reads is a bank near
		# the horizon, far enough out that the fog does half the work.
		var height := 12.0 + 7.0 * float(deck)
		var ring := radius * (6.5 + 1.4 * float(deck))
		var count := 9 + deck * 3
		for i in count:
			var ang := TAU * float(i) / float(count) + float(deck) * 0.7
			var size := Vector3(radius * (1.5 + 0.7 * float(i % 3)), 0.8,
				radius * (0.5 + 0.3 * float(i % 2)))
			var slab := MeshFactory.box(size, tint.lightened(0.25 - 0.06 * float(deck)))
			slab.material_override = MeshFactory.transparent(
				tint.lightened(0.34 - 0.07 * float(deck)), 0.42 - 0.09 * float(deck))
			slab.position = Vector3(cos(ang) * ring, height + 3.0 * sin(float(i) * 1.7), sin(ang) * ring)
			slab.rotation.y = -ang
			node.add_child(slab)
		# Nearest deck fastest: that difference *is* the parallax.
		_decks.append({"node": node, "speed": 0.016 - 0.004 * float(deck)})


func _build_snow(radius: float) -> void:
	var span := 34.0
	for column in SNOW_COLUMNS:
		var mesh := BoxMesh.new()
		var scale := 0.055 + 0.035 * float(column)
		mesh.size = Vector3(scale, scale, scale)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.94, 0.98, 1.0, 0.85 - 0.18 * float(column))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.no_depth_test = false
		mesh.material = mat

		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = FLAKES_PER_COLUMN
		# Deterministic layout: the same seed lays the same snow every match, so
		# a replay of a round snows exactly the way the round did.
		var rng := RandomNumberGenerator.new()
		rng.seed = 9001 + column * 137
		var spread := radius * (1.1 + 0.5 * float(column))
		for i in FLAKES_PER_COLUMN:
			var ang := rng.randf() * TAU
			var r := sqrt(rng.randf()) * spread
			multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(
				cos(ang) * r, rng.randf() * span, sin(ang) * r)))

		var node := MultiMeshInstance3D.new()
		node.name = "Snow%d" % column
		node.multimesh = multi
		node.position = Vector3(0, 1.0, 0)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_columns.append({"node": node, "span": span, "base_y": node.position.y,
			"speed": 1.6 + 0.9 * float(column),
			"sway": 0.8 + 0.5 * float(column), "sway_rate": 0.3 + 0.08 * float(column)})
