class_name ReplayData
extends RefCounted
## A recorded match, stored as seed + input frames + metadata.
##
## A full state recording of a four-player match would be megabytes; this is
## ~1.2 KB per second, because the simulation is reproducible from the same
## seed and the same inputs. That is the same property the network layer will
## need, so the format is deliberately the transport format too.
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
## therefore bounded to a tenth of a second and the replay always shows what
## actually happened. The cost is about 220 bytes per second on top of the
## inputs — a rounding error against being wrong.

const VERSION := 3
const HASH_INTERVAL := 30    # ticks between state checkpoints
const KEYFRAME_INTERVAL := 6 # ticks between position corrections (10 Hz)
const KEYFRAME_BYTES_PER_PLAYER := 9

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
var allow_powerups := true
var sudden_death := true
var players: Array = []      # [{slot, character, name, human, difficulty}]
var tick_rate := 60

# --- the recording ---------------------------------------------------------
## One entry per physics tick: 5 bytes per player, in slot order.
var frames: Array[PackedByteArray] = []
## tick -> state hash, every HASH_INTERVAL ticks.
var hashes := {}
## tick -> packed authoritative state, every KEYFRAME_INTERVAL ticks.
## Per player: int16 x*100, int16 y*100, int16 z*100, uint8 alive, int16 score.
var keyframes := {}

# --- what happened ---------------------------------------------------------
var scores: Array[int] = []
var places: Array[int] = []
var highlights: Array = []
var duration := 0.0


static func from_match(config: MatchConfig, captured: Array, checkpoints: Dictionary,
		keys: Dictionary, result: MatchResult) -> ReplayData:
	var r := ReplayData.new()
	r.id = "%d_%s" % [Time.get_unix_time_from_system(), config.minigame_id]
	r.created_at = int(Time.get_unix_time_from_system())
	r.engine_build = Engine.get_version_info().get("string", "")
	r.minigame_id = config.minigame_id
	r.arena_id = config.arena_id
	r.seed_value = config.seed
	r.rounds = config.rounds
	r.duration_override = config.duration_override
	r.allow_powerups = config.allow_powerups
	r.sudden_death = config.sudden_death
	r.tick_rate = int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	for p in config.players:
		r.players.append({
			"slot": p.slot,
			"character": p.character_id,
			"name": p.display_name(),
			"human": p.is_human,
			"difficulty": p.ai_difficulty,
		})
	# `captured` is an untyped Array; assigning it straight to a typed
	# Array[PackedByteArray] fails at runtime, silently losing the recording.
	for packet in captured:
		r.frames.append(packet)
	r.hashes = checkpoints.duplicate()
	r.keyframes = keys.duplicate()
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
	cfg.allow_powerups = allow_powerups
	cfg.sudden_death = sudden_death
	cfg.context = MatchConfig.Context.QUICK
	for p in players:
		var pc := PlayerConfig.new()
		pc.slot = int(p["slot"])
		pc.character_id = String(p["character"])
		pc.is_human = false
		pc.ai_difficulty = int(p.get("difficulty", 1))
		pc.display_name_override = String(p.get("name", ""))
		cfg.players.append(pc)
	return cfg


## Decode one tick into the given frames, in slot order. Returns false past the
## end of the recording.
func apply_tick(tick: int, out: Array) -> bool:
	if tick < 0 or tick >= frames.size():
		return false
	var packet: PackedByteArray = frames[tick]
	for i in mini(out.size(), packet.size() / 5):
		(out[i] as InputFrame).decode(packet, i * 5)
	return true


## Pack the authoritative state of a tick. Positions are centimetre-quantised
## int16, which covers +/-327 m — far beyond any arena.
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
	return buf


func has_keyframe(tick: int) -> bool:
	return keyframes.has(str(tick))


## Returns [{position, alive, score}] for a recorded tick, or an empty array.
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
		"allow_powerups": allow_powerups,
		"sudden_death": sudden_death,
		"tick_rate": tick_rate,
		"players": players,
		"tick_count": frames.size(),
		"frames_b64": Marshalls.raw_to_base64(flat),
		"hashes": hashes,
		"keyframe_ticks": keyframes.keys(),
		"keyframes_b64": _pack_keyframes(),
		"scores": scores,
		"places": places,
		"highlights": highlights,
		"duration": duration,
	}


static func from_dict(d: Dictionary) -> ReplayData:
	var v := int(d.get("version", 1))
	if v > VERSION:
		Log.w("replay is from a newer build (v%d > v%d)" % [v, VERSION], "Replay")
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
	r.allow_powerups = bool(d.get("allow_powerups", true))
	r.sudden_death = bool(d.get("sudden_death", true))
	r.tick_rate = int(d.get("tick_rate", 60))
	r.players = d.get("players", [])
	r.hashes = d.get("hashes", {})
	r.duration = float(d.get("duration", 0.0))
	r._unpack_keyframes(d.get("keyframe_ticks", []), String(d.get("keyframes_b64", "")),
		maxi(1, (d.get("players", []) as Array).size()))
	r.highlights = d.get("highlights", [])
	for s in d.get("scores", []):
		r.scores.append(int(s))
	for p in d.get("places", []):
		r.places.append(int(p))

	var stride := maxi(1, r.players.size()) * 5
	var flat := Marshalls.base64_to_raw(String(d.get("frames_b64", "")))
	var count := int(d.get("tick_count", flat.size() / stride))
	for i in count:
		var from := i * stride
		if from + stride > flat.size():
			break
		r.frames.append(flat.slice(from, from + stride))
	return _migrate(r, v)


func _pack_keyframes() -> String:
	var flat := PackedByteArray()
	for k in keyframes.keys():
		flat.append_array(keyframes[k])
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
	r.version = VERSION
	return r


func verifiable() -> bool:
	return not hashes.is_empty()


## True when playback can correct itself against recorded state rather than
## hoping the physics reproduces.
func correctable() -> bool:
	return not keyframes.is_empty()
