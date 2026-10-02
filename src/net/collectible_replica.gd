extends Node3D
## Shared visual-only item reconciler. Stable host IDs survive pool reuse and
## reconnects; no physics bodies, pickup callbacks or local RNG run here.

const MAX_ITEMS := 256
var views: Dictionary = {}


static func capture(items: Array) -> Array:
	var rows: Array = []
	for item: Collectible in items:
		if not is_instance_valid(item) or not item.available or not item.visible:
			continue
		var p := item.global_position.snapped(Vector3.ONE * 0.001)
		rows.append({"id": str(item.get_instance_id()), "kind": item.kind,
			"position": [p.x, p.y, p.z], "rotation": snappedf(wrapf(item._mesh.rotation.y, -PI, PI), 0.001),
			"color": item.visual_color.to_html(), "size": item.visual_size, "value": item.value})
	return rows


static func valid(rows: Variant, kind: String) -> bool:
	if not rows is Array or rows.size() > MAX_ITEMS:
		return false
	var ids := {}
	for row in rows:
		if not row is Dictionary or row.get("kind") != kind:
			return false
		var id: Variant = row.get("id")
		if not id is String or id.is_empty() or id.length() > 20 or not id.is_valid_int() \
				or id.to_int() <= 0 or id != str(id.to_int()) or ids.has(id):
			return false
		ids[id] = true
		if not row.get("position") is Array or row.position.size() != 3:
			return false
		for component in row.position:
			if not _number(component) or absf(float(component)) > 10000.0:
				return false
		if not _number(row.get("rotation")) or absf(float(row.rotation)) > 3.142:
			return false
		if not _number(row.get("size")) or row.size < 0.05 or row.size > 3.0:
			return false
		if not _number(row.get("value")) or row.value != floorf(float(row.value)) or row.value < 1 or row.value > 1000000:
			return false
		var color: Variant = row.get("color")
		if not color is String or color.length() != 8:
			return false
		for character in color.to_lower():
			if not "0123456789abcdef".contains(character):
				return false
	return true


func apply(rows: Array) -> void:
	var present := {}
	for row: Dictionary in rows:
		var id: String = row.id
		present[id] = true
		var style := "%s:%s:%s" % [row.kind, row.color, row.size]
		if views.has(id) and views[id].get_meta("style") != style:
			_remove(id)
		if not views.has(id):
			var visual := Collectible.make_visual(row.kind, Color.html(row.color), float(row.size))
			visual.set_meta("style", style)
			add_child(visual)
			views[id] = visual
		var view: Node3D = views[id]
		view.global_position = Vector3(row.position[0], row.position[1], row.position[2])
		view.rotation.y = float(row.rotation)
	for id in views.keys():
		if not present.has(id):
			_remove(id)


func _remove(id: String) -> void:
	var view: Node3D = views[id]
	view.hide()
	view.queue_free()
	views.erase(id)


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
