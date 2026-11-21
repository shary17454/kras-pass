extends RefCounted

const CAPTURE_TURN_MS := 6000


static func active_participant_slots(config: MatchConfig) -> Array[int]:
	var contenders: Array = config.rule("online_contenders", [])
	var slots: Array[int] = []
	for slot in config.human_competitor_slots():
		if contenders.is_empty() or contenders.has(slot):
			slots.append(slot)
	return slots


static func capture_evidence(config: MatchConfig, slot: int, scores: Array,
		observed_score: bool, alive: bool) -> bool:
	if slot < 0 or slot >= config.player_count() or scores.size() != config.player_count() \
			or not config.human_competitor_slots().has(slot):
		return false
	var contenders: Array = config.rule("online_contenders", [])
	var seen: Array[int] = []
	for contender in contenders:
		if typeof(contender) != TYPE_INT or contender < 0 or contender >= config.player_count() \
				or seen.has(contender):
			return false
		seen.append(contender)
	if active_participant_slots(config).has(slot):
		return observed_score and scores[slot] > 0
	# Only a configured online final can exclude a human. Temporary death cannot.
	return config.context == MatchConfig.Context.ONLINE and not contenders.is_empty() \
		and not alive and not observed_score and scores[slot] == 0


static func minimum_match_seconds(player_count: int) -> float:
	return float(CAPTURE_TURN_MS) * float(maxi(1, player_count) + 1) / 1000.0


static func capture_owner(elapsed_ms: int, player_count: int,
		scores: Array = [], participant_slots: Array = []) -> int:
	if player_count <= 0:
		return -1
	# Bot opponents do not follow this fixture's turn schedule. Keep a network
	# participant's turn until actual host scoring proves capture, not just travel.
	if scores.size() == player_count:
		for slot: int in participant_slots:
			if slot >= 0 and slot < player_count and scores[slot] <= 0:
				return slot
	return int(maxi(0, elapsed_ms) / CAPTURE_TURN_MS) % player_count


static func standby_position(arena: Arena, zone: Vector3, radius: float, slot: int) -> Vector3:
	var band := arena.def.radius * 0.72
	var offset := zone - arena.global_position
	# Stage outside the capture circle without spending the next turn crossing
	# half the arena. Alternating sides also keeps waiting peers apart.
	var separation := radius + 1.5 + float(slot / 2) * 1.5
	var side := 1.0 if slot % 2 == 0 else -1.0
	var angle := atan2(offset.z, offset.x) + side * 2.0 * asin(clampf(separation / (2.0 * band), 0.0, 0.95))
	return arena.global_position + Vector3(cos(angle), 0, sin(angle)) * band


static func input(arena: Arena, fighters: Array, slot: int, zone: Vector3,
		radius: float, elapsed_ms: int, scores: Array = [],
		participant_slots: Array = []) -> InputFrame:
	var frame := InputFrame.new()
	var me: Fighter = fighters[slot]
	var p := me.global_position - arena.global_position
	var waiting := standby_position(arena, zone, radius, slot) - arena.global_position
	var angle := atan2(waiting.z, waiting.x)
	var current := atan2(p.z, p.x)
	var next := current + clampf(wrapf(angle - current, -PI, PI), -0.25, 0.25)
	var target := arena.global_position + Vector3(cos(next), 0, sin(next)) * arena.def.radius * 0.72
	var capturing := slot == capture_owner(elapsed_ms, fighters.size(), scores, participant_slots)
	if capturing:
		target = zone
	var flat := me.global_position - zone
	flat.y = 0.0
	if capturing and flat.length() <= radius:
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
