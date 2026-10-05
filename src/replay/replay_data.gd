class_name ReplayData
extends RefCounted
## A recorded match, stored as seed + input frames + metadata.
##
## **This is a hybrid recording, not a deterministic one — deliberately.**
##
## Measured: replaying identical inputs through Godot's physics diverges within
## half a second. Four bodies shoving each other resolve in an order the solver
## does not guarantee, and once a fighter is launched, a centimetre of
## difference becomes metres. Input-only replay would show a *plausible* match,
## not *the* match.
##
## So the format carries both: inputs at every tick for motion and feel, and a
## light position keyframe ten times a second that playback snaps to. Drift is
## corrected at those intervals; unsaved object state can still diverge.
## Four-player raw inputs cost 2160 bytes/s and keyframes 600 bytes/s at 60 Hz,
## excluding events, hashes, container overhead and JSON/base64 encoding.

const VERSION := 5
const HASH_INTERVAL := 30    # ticks between state checkpoints
const KEYFRAME_INTERVAL := 6 # ticks between position corrections (10 Hz)
## Position, liveness, score — and velocity, which is the half that was
## missing. Correcting where a body is without correcting where it is going
## puts it back on the recorded spot still carrying the wrong momentum, so it
## re-diverges immediately and the next correction is a teleport. That was
## invisible while bodies only walked; a shove that differs by a few metres per
## second re-opens metres of gap inside the six ticks between corrections.
const KEYFRAME_BYTES_PER_PLAYER := 15

var id := ""
var version := VERSION
var created_at := 0
var engine_build := ""

# --- what to replay --------------------------------------------------------
var minigame_id := ""
var arena_id := ""
var seed_value := 0
var rounds := 1
var duration_override := 0.0
var rules := {}
var allow_powerups := true
var sudden_death := true
var mutators: PackedStringArray = []
var chaos := false
var players: Array = []      # [{slot, character, name, human, difficulty}]
var tick_rate := 60

# --- the recording ---------------------------------------------------------
## One entry per physics tick: `InputFrame.BYTES` per player, in slot order.
var frames: Array[PackedByteArray] = []
## tick -> state hash, every HASH_INTERVAL ticks.
var hashes := {}
## tick -> the world decisions taken on that tick, in order.
##
## Positions and inputs are enough to reproduce a brawl. They are not enough to
## reproduce a system that *chooses* — the hover machine picks a target from
## where bodies happen to be standing, and a hair of divergence sends its beam
## at a different player, which is not drift, it is a different match. Those
## decisions are recorded and replayed verbatim, the same way keyframes make
## positions authoritative.
var events := {}
## tick -> packed authoritative state, every KEYFRAME_INTERVAL ticks.
## Per player: int16 x*100, int16 y*100, int16 z*100, uint8 alive, int16 score.
var keyframes := {}

# --- what happened ---------------------------------------------------------
var scores: Array[int] = []
var places: Array[int] = []
var highlights: Array = []
var duration := 0.0


static func from_match(config: MatchConfig, captured: Array, checkpoints: Dictionary,
		keys: Dictionary, result: MatchResult, world_events: Dictionary = {}) -> ReplayData:
	var r := ReplayData.new()
	r.id = "%d_%s" % [Time.get_unix_time_from_system(), Crypto.new().generate_random_bytes(16).hex_encode()]
	r.created_at = int(Time.get_unix_time_from_system())
	r.engine_build = Engine.get_version_info().get("string", "")
	r.minigame_id = config.minigame_id
	r.arena_id = config.arena_id
	r.seed_value = config.seed
	r.rounds = config.rounds
	r.duration_override = config.duration_override
	r.rules = config.rules.duplicate(true)
	r.allow_powerups = config.allow_powerups
	r.sudden_death = config.sudden_death
	r.mutators = config.mutators.duplicate()
	r.chaos = config.chaos
	r.tick_rate = int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	for p in config.players:
		r.players.append({
			"slot": p.slot,
			"character": p.character_id,
			"name": p.display_name(),
			"human": p.is_human,
			"difficulty": p.ai_difficulty,
			"team": p.team,
			"palette": p.cosmetic_palette() if p.is_human or not p.palette_id.is_empty() else "classic",
		})
	# `captured` is an untyped Array; assigning it straight to a typed
	# Array[PackedByteArray] fails at runtime, silently losing the recording.
	for packet in captured:
		r.frames.append(packet)
	r.hashes = checkpoints.duplicate()
	r.keyframes = keys.duplicate()
	r.events = world_events
	if result != null:
		r.scores = result.scores.duplicate()
		r.places = result.places.duplicate()
		r.duration = result.duration
	return r


func player_count() -> int:
	return players.size()


func tick_count() -> int:
	return frames.size()


func length_seconds() -> float:
	return float(frames.size()) / float(maxi(tick_rate, 1))


## Rebuild the exact configuration this replay was recorded from. Every player
## becomes a virtual slot — the AI does not think during playback, its recorded
## decisions are replayed.
func to_config() -> MatchConfig:
	var cfg := MatchConfig.new()
	cfg.minigame_id = minigame_id
	cfg.arena_id = arena_id
	cfg.seed = seed_value
	cfg.rounds = rounds
	cfg.duration_override = duration_override
	cfg.rules = rules.duplicate(true)
	cfg.allow_powerups = allow_powerups
	cfg.sudden_death = sudden_death
	cfg.mutators = mutators.duplicate()
	cfg.chaos = chaos
	cfg.context = MatchConfig.Context.QUICK
	for p in players:
		var pc := PlayerConfig.new()
		pc.slot = int(p["slot"])
		pc.character_id = String(p["character"])
		pc.is_human = false
		pc.ai_difficulty = int(p.get("difficulty", 1))
		pc.team = int(p.get("team", -1))
		pc.display_name_override = String(p.get("name", ""))
		pc.palette_id = String(p.get("palette", "classic"))
		cfg.players.append(pc)
	return cfg


## Decode one tick into the given frames, in slot order. Returns false past the
## end of the recording.
func apply_tick(tick: int, out: Array) -> bool:
	if tick < 0 or tick >= frames.size():
		return false
	var packet: PackedByteArray = frames[tick]
	for i in mini(out.size(), packet.size() / InputFrame.BYTES):
		(out[i] as InputFrame).decode(packet, i * InputFrame.BYTES)
	return true


## Pack the authoritative state of a tick. Positions and velocities are
## centimetre-quantised int16, which covers +/-327 m and +/-327 m/s — far
## beyond any arena or any launch.
static func encode_keyframe(fighters: Array, scores: Array, alive: Array) -> PackedByteArray:
	var buf := PackedByteArray()
	buf.resize(fighters.size() * KEYFRAME_BYTES_PER_PLAYER)
	for i in fighters.size():
		var at := i * KEYFRAME_BYTES_PER_PLAYER
		var p: Vector3 = fighters[i].global_position if is_instance_valid(fighters[i]) else Vector3.ZERO
		buf.encode_s16(at + 0, clampi(int(round(p.x * 100.0)), -32768, 32767))
		buf.encode_s16(at + 2, clampi(int(round(p.y * 100.0)), -32768, 32767))
		buf.encode_s16(at + 4, clampi(int(round(p.z * 100.0)), -32768, 32767))
		buf[at + 6] = 1 if (i < alive.size() and alive[i]) else 0
		buf.encode_s16(at + 7, clampi(int(scores[i]) if i < scores.size() else 0, -32768, 32767))
		var v: Vector3 = fighters[i].velocity if is_instance_valid(fighters[i]) else Vector3.ZERO
		buf.encode_s16(at + 9, clampi(int(round(v.x * 100.0)), -32768, 32767))
		buf.encode_s16(at + 11, clampi(int(round(v.y * 100.0)), -32768, 32767))
		buf.encode_s16(at + 13, clampi(int(round(v.z * 100.0)), -32768, 32767))
	return buf


## The decisions taken on a tick, or an empty array.
func events_at(tick: int) -> Array:
	return events.get(str(tick), [])


func has_keyframe(tick: int) -> bool:
	return keyframes.has(str(tick))


## Returns [{position, velocity, alive, score}] for a recorded tick, or an
## empty array.
func keyframe(tick: int) -> Array:
	var buf = keyframes.get(str(tick))
	if buf == null:
		return []
	var packed: PackedByteArray = buf
	var out: Array = []
	var count := packed.size() / KEYFRAME_BYTES_PER_PLAYER
	for i in count:
		var at := i * KEYFRAME_BYTES_PER_PLAYER
		out.append({
			"position": Vector3(
				packed.decode_s16(at + 0) / 100.0,
				packed.decode_s16(at + 2) / 100.0,
				packed.decode_s16(at + 4) / 100.0),
			"velocity": Vector3(
				packed.decode_s16(at + 9) / 100.0,
				packed.decode_s16(at + 11) / 100.0,
				packed.decode_s16(at + 13) / 100.0),
			"alive": packed[at + 6] == 1,
			"score": packed.decode_s16(at + 7),
		})
	return out


func has_checkpoint(tick: int) -> bool:
	return hashes.has(str(tick))


func checkpoint(tick: int) -> int:
	return int(hashes.get(str(tick), 0))


func display_name() -> String:
	var m := Registry.minigame(minigame_id)
	return m.display_name() if m != null else minigame_id


func winner_name() -> String:
	for i in places.size():
		if places[i] == 1 and i < players.size():
			return String(players[i].get("name", ""))
	return ""


func date_string() -> String:
	var d := Time.get_datetime_dict_from_unix_time(created_at)
	return "%04d-%02d-%02d %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]


func approx_bytes() -> int:
	var n := 0
	for f in frames:
		n += f.size()
	return n


# --- serialization ---------------------------------------------------------

func to_dict() -> Dictionary:
	# Frames are one flat buffer, base64'd: an array of arrays in JSON would be
	# roughly twenty times the size.
	var flat := PackedByteArray()
	for f in frames:
		flat.append_array(f)
	return {
		"version": VERSION,
		"id": id,
		"created_at": created_at,
		"engine_build": engine_build,
		"minigame_id": minigame_id,
		"arena_id": arena_id,
		"seed": seed_value,
		"rounds": rounds,
		"duration_override": duration_override,
		"rules": rules,
		"allow_powerups": allow_powerups,
		"sudden_death": sudden_death,
		"mutators": Array(mutators),
		"chaos": chaos,
		"tick_rate": tick_rate,
		"players": players,
		"tick_count": frames.size(),
		"frames_b64": "" if flat.is_empty() else Marshalls.raw_to_base64(flat),
		"hashes": hashes,
		"events": events,
		"keyframe_ticks": keyframes.keys(),
		"keyframes_b64": _pack_keyframes(),
		"scores": scores,
		"places": places,
		"highlights": highlights,
		"duration": duration,
	}


static func from_dict(d: Dictionary) -> ReplayData:
	if not _valid_schema(d):
		Log.w("replay metadata has an invalid schema", "Replay")
		return null
	var v := int(d.get("version", 1))
	if v > VERSION:
		Log.w("replay is from a newer build (v%d > v%d)" % [v, VERSION], "Replay")
		return null
	var payload := _validated_payload(d, v)
	if payload.is_empty():
		Log.w("replay binary channels are incomplete or invalid", "Replay")
		return null
	var r := ReplayData.new()
	r.version = v
	r.id = String(d.get("id", ""))
	r.created_at = int(d.get("created_at", 0))
	r.engine_build = String(d.get("engine_build", ""))
	r.minigame_id = String(d.get("minigame_id", ""))
	r.arena_id = String(d.get("arena_id", ""))
	r.seed_value = int(d.get("seed", 0))
	r.rounds = int(d.get("rounds", 1))
	r.duration_override = float(d.get("duration_override", 0.0))
	var saved_rules = d.get("rules", {})
	r.rules = saved_rules.duplicate(true) if saved_rules is Dictionary else {}
	r.allow_powerups = bool(d.get("allow_powerups", true))
	r.sudden_death = bool(d.get("sudden_death", true))
	for modifier in d.get("mutators", []):
		r.mutators.append(String(modifier))
	r.chaos = bool(d.get("chaos", false))
	r.tick_rate = int(d.get("tick_rate", 60))
	r.players = d.get("players", [])
	r.hashes = d.get("hashes", {})
	r.events = d.get("events", {})
	r.duration = float(d.get("duration", 0.0))
	r._unpack_keyframes(d.get("keyframe_ticks", []), String(d.get("keyframes_b64", "")),
		maxi(1, (d.get("players", []) as Array).size()))
	r.highlights = d.get("highlights", [])
	for s in d.get("scores", []):
		r.scores.append(int(s))
	for p in d.get("places", []):
		r.places.append(int(p))

	var stride := maxi(1, r.players.size()) * InputFrame.BYTES
	var flat: PackedByteArray = payload["frames"]
	var count := int(d.get("tick_count", flat.size() / stride))
	for i in count:
		var from := i * stride
		if from + stride > flat.size():
			break
		r.frames.append(flat.slice(from, from + stride))
	return _migrate(r, v)


static func _validated_payload(d: Dictionary, v: int) -> Dictionary:
	var inputs: String = d.get("frames_b64", "")
	var corrections: String = d.get("keyframes_b64", "")
	if not _base64_shape(inputs) or not _base64_shape(corrections):
		return {}
	var flat := Marshalls.base64_to_raw(inputs)
	var keys := Marshalls.base64_to_raw(corrections)
	var encoded_inputs := "" if flat.is_empty() else Marshalls.raw_to_base64(flat)
	var encoded_keys := "" if keys.is_empty() else Marshalls.raw_to_base64(keys)
	if encoded_inputs != inputs or encoded_keys != corrections:
		return {}
	# Pre-v4 channels use obsolete packet layouts and are cleared by migration.
	if v >= 4:
		var stride := maxi(1, d.get("players", []).size()) * InputFrame.BYTES
		if flat.size() % stride != 0:
			return {}
		var count := flat.size() / stride
		if d.has("tick_count") and int(d["tick_count"]) != count:
			return {}
		if not keys.is_empty():
			var ticks: Array = d.get("keyframe_ticks", [])
			if keys.size() != ticks.size() * maxi(1, d.get("players", []).size()) * KEYFRAME_BYTES_PER_PLAYER:
				return {}
			var seen := {}
			for tick in ticks:
				var normalized := str(int(tick))
				if seen.has(normalized):
					return {}
				seen[normalized] = true
	return {"frames": flat}


static func _base64_shape(value: String) -> bool:
	if value.length() % 4 != 0:
		return false
	var padding := 0
	for i in value.length():
		var c := value[i]
		if c == "=":
			padding += 1
			if i < value.length() - 2 or padding > 2:
				return false
		elif padding > 0 or not c in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/":
			return false
	return true


static func _valid_schema(d: Dictionary) -> bool:
	for key in ["id", "engine_build", "minigame_id", "arena_id", "frames_b64", "keyframes_b64"]:
		if d.has(key) and not d[key] is String:
			return false
	for key in ["version", "created_at", "seed", "rounds", "tick_rate", "tick_count"]:
		if d.has(key) and not _integer_value(d[key]):
			return false
	for key in ["duration", "duration_override"]:
		if d.has(key) and not _finite_number(d[key]):
			return false
	for key in ["allow_powerups", "sudden_death", "chaos"]:
		if d.has(key) and not d[key] is bool:
			return false
	for key in ["rules", "hashes", "events"]:
		if d.has(key) and not d[key] is Dictionary:
			return false
	for key in ["players", "mutators", "highlights", "scores", "places", "keyframe_ticks"]:
		if d.has(key) and not d[key] is Array:
			return false
	if int(d.get("version", 1)) < 1 or int(d.get("tick_rate", 60)) <= 0:
		return false
	if int(d.get("tick_count", 0)) < 0 or int(d.get("rounds", 1)) < 1:
		return false
	var roster: Array = d.get("players", [])
	if roster.size() > 4:
		return false
	var slots := {}
	for player in roster:
		if not player is Dictionary or not _integer_value(player.get("slot")):
			return false
		var slot := int(player["slot"])
		if slot < 0 or slot > 3 or slots.has(slot) or not player.get("character") is String:
			return false
		slots[slot] = true
		for key in ["name", "palette"]:
			if player.has(key) and not player[key] is String:
				return false
		for key in ["team", "difficulty"]:
			if player.has(key) and not _integer_value(player[key]):
				return false
		if player.has("human") and not player["human"] is bool:
			return false
	for modifier in d.get("mutators", []):
		if not modifier is String:
			return false
	for key in ["scores", "places"]:
		for value in d.get(key, []):
			if not _integer_value(value):
				return false
	for tick in d.get("keyframe_ticks", []):
		if not _tick_value(tick):
			return false
	for tick in d.get("hashes", {}):
		if not _tick_value(tick) or not _integer_value(d["hashes"][tick]):
			return false
	for tick in d.get("events", {}):
		if not _tick_value(tick) or not d["events"][tick] is Array:
			return false
	for highlight in d.get("highlights", []):
		if not highlight is Dictionary or not highlight.get("kind") is String:
			return false
		if not _integer_value(highlight.get("tick")) or int(highlight["tick"]) < 0:
			return false
	return true


static func _tick_value(value: Variant) -> bool:
	if value is String:
		return value.is_valid_int() and int(value) >= 0
	return _integer_value(value) and int(value) >= 0


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _integer_value(value: Variant) -> bool:
	return _finite_number(value) and float(value) == floor(float(value))


func _pack_keyframes() -> String:
	if keyframes.is_empty():
		return ""
	var flat := PackedByteArray()
	for k in keyframes.keys():
		flat.append_array(keyframes[k])
	if flat.is_empty():
		return ""
	return Marshalls.raw_to_base64(flat)


func _unpack_keyframes(ticks: Array, b64: String, player_count: int) -> void:
	keyframes.clear()
	if ticks.is_empty() or b64 == "":
		return
	var flat := Marshalls.base64_to_raw(b64)
	var stride := player_count * KEYFRAME_BYTES_PER_PLAYER
	for i in ticks.size():
		var from := i * stride
		if from + stride > flat.size():
			break
		keyframes[str(ticks[i])] = flat.slice(from, from + stride)


## Older recordings predate a feature; they still play, just with less to
## verify or correct against. Each bump adds one clause rather than discarding.
static func _migrate(r: ReplayData, from_version: int) -> ReplayData:
	if from_version < 2:
		r.hashes = {}
	if from_version < 3:
		# Input-only recordings. They will drift, and the player is told so.
		r.keyframes = {}
	if from_version < 4:
		# The stick widened from one byte per axis to two, so an older packet
		# cannot be re-read at the new stride — it would decode as noise and
		# play back a match nobody ever had. Better an honest empty recording.
		r.frames.clear()
		r.keyframes = {}
	r.version = VERSION
	return r


func verifiable() -> bool:
	return not hashes.is_empty()


## True when playback can correct itself against recorded state rather than
## hoping the physics reproduces.
func correctable() -> bool:
	return not keyframes.is_empty()
