extends RefCounted
## Zone state is presentation-only on guests; capture progress stays on host.

static func capture(game: Node) -> Dictionary:
	var p: Vector3 = game.zone_position
	return {"position": [p.x, p.y, p.z], "radius": game.zone_radius,
		"color": game._ring_color.to_html()}


static func valid(world: Variant) -> bool:
	if not world is Dictionary or not world.get("position") is Array or world.position.size() != 3:
		return false
	for value in world.position:
		if not _number(value) or absf(float(value)) > 10000.0:
			return false
	if not _number(world.get("radius")) or world.radius < 0.1 or world.radius > 10.0:
		return false
	var color: Variant = world.get("color")
	if not color is String or color.length() != 8:
		return false
	for character in color.to_lower():
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func render(game: Node, world: Dictionary) -> void:
	game.zone_position = Vector3(world.position[0], world.position[1], world.position[2])
	game.zone_radius = float(world.radius)
	game._marker.global_position = game.zone_position
	game._sync_radius()
	game._set_ring_color(Color.html(world.color))


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
