extends Control

var ctx: MatchContext
var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(22, 410 if get_viewport().get_visible_rect().size.x < get_viewport().get_visible_rect().size.y else 115)
	size = Vector2(120, 120)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.1:
		_elapsed = 0.0
		queue_redraw()


func _draw() -> void:
	if ctx == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.09, 0.1, 0.82))
	var world = ctx.arena.get_meta("tank_world", null)
	if world != null:
		for id in world.roads.get_point_ids():
			var from: Vector3 = world.roads.get_point_position(id)
			for other in world.roads.get_point_connections(id):
				if other < id:
					continue
				var to: Vector3 = world.roads.get_point_position(other)
				draw_line(Vector2(60, 60) + Vector2(from.x, from.z) * 1.15,
					Vector2(60, 60) + Vector2(to.x, to.z) * 1.15, Color("647d80"), 5)
	for f in ctx.fighters:
		if not f.alive:
			continue
		var p := Vector2(60, 60) + Vector2(f.position.x, f.position.z) * 1.15
		var human := ctx.config.human_slots().has(f.slot)
		draw_circle(p, 4 if human else 3, Color.WHITE if human else Color("ff805e"))
		if human:
			draw_line(p, p + Vector2(f.facing.x, f.facing.z) * 9, Color.WHITE, 2)
