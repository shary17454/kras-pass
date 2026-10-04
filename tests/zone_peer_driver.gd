extends RefCounted


static func input(arena: Arena, fighters: Array, slot: int, zone: Vector3,
		radius: float, elapsed_ms: int) -> InputFrame:
	var frame := InputFrame.new()
	var me: Fighter = fighters[slot]
	var p := me.global_position - arena.global_position
	var offset := zone - arena.global_position
	var angle := atan2(offset.z, offset.x) + slot * 0.9
	var current := atan2(p.z, p.x)
	var next := current + clampf(wrapf(angle - current, -PI, PI), -0.25, 0.25)
	var target := arena.global_position + Vector3(cos(next), 0, sin(next)) * arena.def.radius * 0.72
	var flat := me.global_position - zone
	flat.y = 0.0
	if flat.length() <= radius:
		var nearest := INF
		var rival: Fighter = null
		for other: Fighter in fighters:
			if other == me or not other.alive or not other.is_visible_in_tree():
				continue
			var to_zone := other.global_position - zone
			to_zone.y = 0.0
			var to := other.global_position - me.global_position
			to.y = 0.0
			if to_zone.length() <= radius and to.length() < nearest:
				nearest = to.length()
				rival = other
		if rival != null:
			# Exercise real contest-clearing input, not direct score or body writes.
			target = rival.global_position
			var toward := target - me.global_position
			toward.y = 0.0
			if nearest <= 2.1 and me.facing.normalized().dot(toward.normalized()) > 0.85 \
					and elapsed_ms % 700 < 160:
				frame.bits = InputFrame.Btn.ATTACK
	target = arena.annular_waypoint(me.global_position, target)
	frame.move = Vector2(target.x - me.global_position.x, target.z - me.global_position.z).limit_length()
	return frame
