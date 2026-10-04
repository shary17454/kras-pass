class_name OffscreenPlayerCue
extends Control
## One reusable marker per slot; positions are in the HUD viewport, not pixels.

var direction := Vector2.DOWN
var tint := Color.WHITE
var _symbol: Label


func configure(player: PlayerConfig) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(56, 56)
	tint = UIKit.adapt(player.color())
	_symbol = UIKit.centered(player.symbol(), 26, Color.WHITE, true)
	_symbol.set_anchors_preset(Control.PRESET_FULL_RECT)
	_symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_symbol)
	visible = false


func place(cue: Dictionary) -> void:
	visible = not cue.is_empty()
	if not visible:
		return
	position = cue.position - size * 0.5
	direction = cue.direction
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	draw_circle(centre, 22.0, Color(0.04, 0.07, 0.09, 0.94))
	draw_arc(centre, 22.0, 0.0, TAU, 24, tint, 3.0, true)
	var tip := centre + direction * 28.0
	var base := centre + direction * 20.0
	var side := direction.orthogonal() * 7.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), tint)


static func eligible(context: MatchContext, slot: int) -> bool:
	if context == null or not MatchPhase.is_live(context.phase) or not context.is_alive(slot):
		return false
	var fighter := context.fighter(slot)
	return is_instance_valid(fighter) and fighter.is_inside_tree() \
		and not fighter.is_queued_for_deletion() and fighter.is_visible_in_tree()


static func project(camera: Camera3D, world: Vector3, bounds: Rect2) -> Dictionary:
	if not is_instance_valid(camera) or not camera.is_inside_tree() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return {}
	var view := camera.global_transform.orthonormalized()
	view.origin += view.basis.x * camera.h_offset + view.basis.y * camera.v_offset
	var local := view.affine_inverse() * world
	var clip: Vector4 = camera.get_camera_projection() * Vector4(local.x, local.y, local.z, 1.0)
	if not clip.is_finite():
		return {}
	if local.z < -camera.near and clip.w > 0.0 and absf(clip.x) <= clip.w and absf(clip.y) <= clip.w:
		return {}
	# abs(w) avoids mirrored arrows behind a perspective camera. Orthographic
	# cameras also need local.z: their homogeneous w is always positive.
	var vector := Vector2(clip.x, -clip.y) / maxf(absf(clip.w), 0.001)
	vector *= camera.get_viewport().get_visible_rect().size * 0.5
	if vector.length_squared() < 0.001:
		vector = Vector2.DOWN
	var half := bounds.size * 0.5
	var factor := maxf(absf(vector.x) / half.x, absf(vector.y) / half.y)
	return {"position": bounds.get_center() + vector / factor, "direction": vector.normalized()}


static func separate(cues: Array[Dictionary], bounds: Rect2) -> void:
	var occupied: Array[Vector2] = []
	for cue in cues:
		if cue.is_empty():
			continue
		var original: Vector2 = cue.position
		var vertical := is_equal_approx(original.x, bounds.position.x) or is_equal_approx(original.x, bounds.end.x)
		var found := false
		for step in [0, -1, 1, -2, 2, -3, 3]:
			var candidate := original + (Vector2.DOWN if vertical else Vector2.RIGHT) * float(step) * 60.0
			if not bounds.grow(0.01).has_point(candidate):
				continue
			var clear := true
			for point in occupied:
				if candidate.distance_squared_to(point) < 56.0 * 56.0:
					clear = false
					break
			if clear:
				cue.position = candidate
				occupied.append(candidate)
				found = true
				break
		# A viewport with no room for another marker must not draw unreadable
		# overlapping symbols. The score chips still identify every player.
		if not found:
			cue.clear()
