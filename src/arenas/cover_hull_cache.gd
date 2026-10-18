extends RefCounted


static func mesh_digest(mesh: Mesh) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for surface in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		context.update(vertices.to_byte_array())
	return context.finish().hex_encode()


static func resolve(mesh: Mesh, index: int) -> ConvexPolygonShape3D:
	if not OS.get_cmdline_user_args().has("--original-cover-hulls"):
		var path := "res://data/collision/rock_cover_%d.tres" % index
		if ResourceLoader.exists(path):
			var candidate := load(path) as ConvexPolygonShape3D
			if candidate != null and candidate.get_meta("source_digest", "") == mesh_digest(mesh):
				return candidate
	return mesh.create_convex_shape()
