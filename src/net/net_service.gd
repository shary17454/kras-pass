extends Node
## Online play abstraction. Autoload name: `Net`.
##
## Local sessions and protocol-v1 hosted rooms. Online is gated on a configured
## endpoint; the lobby server, not a client, assigns identities and slots.

signal session_state_changed(state: int)
signal peer_joined(peer: Dictionary)
signal peer_left(peer_id: int)
signal peer_ready_changed(peer_id: int, ready: bool)
signal lobby_config_changed(config: Dictionary)
signal match_start_requested(config: MatchConfig)
signal connection_lost(reason: String)
signal room_updated
signal rooms_received(rooms: Array)
signal online_error(code: String)
signal snapshot_received(data: Dictionary)
signal online_result(scores: Array)

const RoomClient = preload("res://src/net/room_client.gd")
const ONLINE_GAMES := ["ring_rumble", "goal_guard", "gem_grab", "star_rush", "zone_hold", "relic_hold", "tag_hunt", "paint_grid", "mnatiq", "mukharrib", "magnet_court", "storm_heart", "sky_court", "crumble_court", "blast_ball", "color_stand", "quick_draw", "symbol_echo", "crate_smash", "lab_crates", "crate_relay", "hurdle_dash", "rising_tide", "sweeper_storm", "duel_pit", "bumper_bowl", "duo_clash", "drift_floes", "turret_duel", "tank_arena", "scrap_karts", "fawda"]
const ONLINE_ARENAS := {"fawda": ["vortex_ring", "storm_ring"], "scrap_karts": ["scrap_yard"], "tank_arena": ["tank_foundry", "tank_oasis", "tank_frost"], "ring_rumble": ["vortex_ring", "storm_ring"], "goal_guard": ["quad_court"],
	"gem_grab": ["gem_hollow", "glass_terrace"], "star_rush": ["star_meadow"], "zone_hold": ["dune_ring"],
	"relic_hold": ["star_meadow", "gem_hollow"], "tag_hunt": ["star_meadow", "paint_grid"],
	"paint_grid": ["paint_grid"], "mnatiq": ["paint_grid"], "mukharrib": ["paint_grid"], "magnet_court": ["quad_court"], "storm_heart": ["quad_court"], "sky_court": ["quad_court"], "crumble_court": ["crumble_court"], "blast_ball": ["ember_pit"], "color_stand": ["color_floor"], "quick_draw": ["draw_stage"], "symbol_echo": ["echo_hall"],
	"crate_smash": ["crate_yard"], "lab_crates": ["crate_yard"], "crate_relay": ["relay_docks"], "hurdle_dash": ["hurdle_track"], "rising_tide": ["tide_spire"], "sweeper_storm": ["sweeper_ring"], "duel_pit": ["duel_pit"], "bumper_bowl": ["bumper_bowl"], "duo_clash": ["sweeper_ring", "bumper_bowl"], "drift_floes": ["vortex_ring", "storm_ring"], "turret_duel": ["iron_flats"]}
var transport: Node
var endpoint := ""
var room_state := ""
var match_data := {}
var epoch := 0
var match_running := false
var ping_ms := 0
var local_device_type := 0
var local_device_id := 0
var _token := ""
var _retry_at := 0
var _retry_until := 0
var _ping_at := 0
var _inputs := {}
var _sequence := 0
var _last_snapshot := -1
var _result_epoch := -1
var _pending_result := {}

enum State { OFFLINE, HOSTING, JOINING, LOBBY, IN_MATCH, DISCONNECTED }
enum Mode { LOCAL, ONLINE_HOST, ONLINE_CLIENT }

var state: State = State.OFFLINE
var mode: Mode = Mode.LOCAL
var room_code := ""
var is_host := true
var local_peer_id := 1
var peers := {}          # peer_id -> {"id", "name", "ready", "character", "slot"}
var lobby_config := {}
var tournament := {}
## Endpoint configuration gate, not a claim that a deployment is healthy.
var online_available := false


func _ready() -> void:
	reset()
	endpoint = OS.get_environment("KRAS_MULTIPLAYER_URL")
	if endpoint.is_empty():
		endpoint = String(ProjectSettings.get_setting("kras/online/endpoint", ""))
	online_available = not endpoint.is_empty()
	transport = RoomClient.new()
	add_child(transport)
	transport.message_received.connect(_receive)
	transport.transport_lost.connect(_transport_lost)
	process_mode = Node.PROCESS_MODE_ALWAYS


func reset() -> void:
	if transport != null:
		transport.close()
	_token = ""
	_retry_until = 0
	_retry_at = 0
	room_state = ""
	match_data.clear()
	_inputs.clear()
	match_running = false
	_sequence = 0
	_last_snapshot = -1
	_result_epoch = -1
	_pending_result.clear()
	state = State.OFFLINE
	mode = Mode.LOCAL
	room_code = ""
	lobby_config.clear()
	tournament.clear()
	peers.clear()
	is_host = true
	local_peer_id = 1
	_set_state(State.OFFLINE)


# --- session ---------------------------------------------------------------

## Starts a local "session" that behaves exactly like a hosted room. Local play
## and online play therefore run the same lobby code path, which is what keeps
## the seam honest instead of theoretical.
func host_local(max_players: int = 4) -> void:
	reset()
	mode = Mode.LOCAL
	is_host = true
	var capacity := clampi(max_players, 1, 4)
	lobby_config = {"max_players": capacity, "game": "", "rounds": 1, "difficulty": 1}
	_add_peer(1, "player.you", true)
	_set_state(State.LOBBY)


func host_online(max_players: int = 4, public_room := false, player_name := "Player") -> bool:
	if not online_available:
		Log.w("online endpoint is not configured", "Net")
		return false
	reset()
	mode = Mode.ONLINE_HOST
	_set_state(State.HOSTING)
	return _connect({"op": "create", "capacity": clampi(max_players, 2, 4), "public": public_room, "name": player_name})


func join_online(code: String, player_name := "Player") -> bool:
	if not online_available:
		Log.w("online endpoint is not configured", "Net")
		return false
	if code.length() != 6:
		return false
	reset()
	mode = Mode.ONLINE_CLIENT
	is_host = false
	_set_state(State.JOINING)
	return _connect({"op": "join", "code": code.to_upper(), "name": player_name})


func leave() -> void:
	if transport != null:
		transport.send({"op": "leave"})
	reset()


func _set_state(s: State) -> void:
	state = s
	session_state_changed.emit(int(s))


# --- lobby -----------------------------------------------------------------

func add_local_participant(name_key: String) -> int:
	if state != State.LOBBY or mode != Mode.LOCAL or peers.size() >= int(lobby_config.get("max_players", 4)):
		return -1
	var id := 1
	while peers.has(id):
		id += 1
	_add_peer(id, name_key, false)
	return id


func _add_peer(id: int, name_key: String, ready: bool) -> void:
	var used_slots := {}
	for peer in peers.values():
		used_slots[int(peer["slot"])] = true
	var slot := 0
	while used_slots.has(slot):
		slot += 1
	peers[id] = {"id": id, "name": name_key, "ready": ready, "character": "", "slot": slot}
	peer_joined.emit(peers[id])


func remove_peer(id: int) -> void:
	if mode != Mode.LOCAL:
		transport.send({"op": "kick", "id": id})
		return
	if not peers.has(id):
		return
	peers.erase(id)
	peer_left.emit(id)
	if state == State.IN_MATCH:
		# A disconnect mid-match hands the slot to the AI rather than aborting
		# the round: the remaining players keep playing.
		Log.w("peer %d dropped mid-match; slot handed to AI" % id, "Net")


func set_ready(id: int, ready: bool) -> void:
	if mode != Mode.LOCAL:
		if id == local_peer_id:
			transport.send({"op": "ready", "ready": ready})
		return
	if state != State.LOBBY or not peers.has(id):
		return
	peers[id]["ready"] = ready
	peer_ready_changed.emit(id, ready)


func all_ready() -> bool:
	if peers.is_empty():
		return false
	for p in peers.values():
		if not bool(p["ready"]) or (mode != Mode.LOCAL and not bool(p.get("connected", false))):
			return false
	return true


func set_lobby_config(cfg: Dictionary) -> void:
	if mode != Mode.LOCAL:
		transport.send({"op": "configure", "config": cfg})
		return
	lobby_config = cfg.duplicate(true)
	lobby_config_changed.emit(lobby_config)



func request_start(config: MatchConfig) -> bool:
	if mode != Mode.LOCAL:
		return is_host and all_ready() and transport.send({"op": "start"})
	if state != State.LOBBY or mode != Mode.LOCAL or not is_host or not all_ready() or config == null:
		return false
	var def := config.definition()
	if def == null or config.players.size() != peers.size() \
			or config.players.size() > int(lobby_config.get("max_players", 4)) \
			or config.players.size() < def.min_players or config.players.size() > def.max_players:
		return false
	var assigned_slots := {}
	for player in config.players:
		if player.slot < 0 or player.slot >= config.players.size() or assigned_slots.has(player.slot):
			return false
		if player.character() == null:
			return false
		assigned_slots[player.slot] = true
	_set_state(State.IN_MATCH)
	match_start_requested.emit(config)
	return true


func end_match() -> void:
	if mode != Mode.LOCAL:
		if is_host:
			transport.send({"op": "lobby"})
		return
	if state == State.IN_MATCH:
		_set_state(State.LOBBY)


func next_tournament_round() -> void:
	if mode != Mode.LOCAL and is_host and all_ready():
		transport.send({"op": "next"})


# --- input transport contract ----------------------------------------------

## Called every physics tick by the match layer for locally-owned slots. The
## local backend is a no-op; a network backend would batch and send.
func publish_input(slot: int, frame: InputFrame, _tick: int) -> void:
	if mode == Mode.LOCAL or not match_running or slot != local_slot():
		return
	_sequence += 1
	transport.send({"op": "input", "epoch": epoch, "sequence": _sequence,
		"axes": [frame.move.x, frame.move.y, frame.aim.x, frame.aim.y], "bits": frame.bits & 31})


## Returns true when the frame for a remote slot at `tick` is available. The
## local backend always returns false, which makes the match layer fall back to
## the AI brain — exactly the behaviour wanted when a remote player drops.
func consume_input(slot: int, frame: InputFrame, _tick: int) -> bool:
	if not _inputs.has(slot) or Time.get_ticks_msec() - int(_inputs[slot]["time"]) > 250:
		frame.clear()
		return false
	var packet: Dictionary = _inputs[slot]
	frame.move = Vector2(packet.axes[0], packet.axes[1]).limit_length()
	frame.aim = Vector2(packet.axes[2], packet.axes[3]).limit_length()
	frame.bits = int(packet.bits) & 31
	return true


func _connect(first: Dictionary) -> bool:
	var error: Error = transport.connect_room(endpoint, first)
	if error != OK:
		_transport_lost()
	return error == OK


func list_rooms() -> void:
	if online_available:
		if not transport.send({"op": "list"}):
			_connect({"op": "list"})


func select_character(index: int) -> void:
	transport.send({"op": "character", "character": index})


func local_slot() -> int:
	return int(peers.get(local_peer_id, {}).get("slot", -1))


func loaded() -> void:
	transport.send({"op": "loaded", "epoch": epoch})


func publish_snapshot(data: Dictionary, tick: int) -> void:
	if is_host and match_running:
		transport.send({"op": "snapshot", "epoch": epoch, "tick": tick, "data": data})


func publish_result(scores: Array[int]) -> void:
	if is_host:
		match_running = false
		_pending_result = {"op": "result", "epoch": epoch, "scores": scores.duplicate()}
		transport.send(_pending_result)


func make_match_config() -> MatchConfig:
	if match_data.is_empty():
		return null
	var cfg := MatchConfig.new()
	cfg.context = MatchConfig.Context.ONLINE
	cfg.minigame_id = String(match_data.config.game)
	cfg.arena_id = String(match_data.config.arena)
	cfg.rounds = int(match_data.config.rounds)
	cfg.seed = int(match_data.seed)
	# The initial online ruleset excludes unreplicated machine drops/power-ups.
	cfg.allow_powerups = false
	cfg.rules["online_push"] = cfg.minigame_id == "ring_rumble"
	var standings: Dictionary = match_data.get("tournament") if match_data.get("tournament") is Dictionary else {}
	if not standings.get("contenders", []).is_empty():
		var contenders: Array[int] = []
		for slot in standings.contenders:
			contenders.append(int(slot))
		cfg.rules["online_contenders"] = contenders
		cfg.duration_override = 20.0
		cfg.rules["maximum_duration"] = 25.0
		cfg.sudden_death = false
	var characters := Registry.characters()
	for row in match_data.players:
		var p := PlayerConfig.new()
		p.slot = int(row.slot)
		p.peer_id = int(row.id)
		p.is_human = p.peer_id == local_peer_id
		p.character_id = characters[int(row.character) % characters.size()].id
		p.display_name_override = String(row.name)
		p.palette_id = "classic"
		if p.is_human:
			p.device_type = local_device_type
			p.device_id = local_device_id
		p.ai_difficulty = int(match_data.config.difficulty)
		cfg.players.append(p)
	return cfg


func _receive(m: Dictionary) -> void:
	match String(m.get("op", "")):
		"welcome":
			local_peer_id = int(m.id)
			_token = String(m.token)
			_retry_until = 0
		"rooms": rooms_received.emit(m.get("rooms", []))
		"error":
			var code := String(m.get("code", "invalid_request"))
			if code == "session_expired":
				reset()
				connection_lost.emit(code)
			elif code != "session_active":
				online_error.emit(code)
		"pong": ping_ms = maxi(0, Time.get_ticks_msec() - int(m.get("stamp", 0)))
		"room":
			tournament = m.tournament.duplicate(true) if m.get("tournament") is Dictionary else {}
			room_code = String(m.code)
			room_state = String(m.state)
			if room_state == "lobby":
				match_running = false
				_inputs.clear()
				_pending_result.clear()
			is_host = int(m.host) == local_peer_id
			mode = Mode.ONLINE_HOST if is_host else Mode.ONLINE_CLIENT
			peers.clear()
			for p in m.players:
				peers[int(p.id)] = p
			lobby_config = m.config.duplicate(true)
			lobby_config["max_players"] = int(m.capacity)
			_set_state(State.LOBBY if room_state in ["lobby", "results"] else State.IN_MATCH)
			room_updated.emit()
		"start":
			var fresh := int(m.epoch) != epoch or match_data.is_empty()
			epoch = int(m.epoch)
			match_data = m.duplicate(true)
			if fresh:
				_sequence = 0
				_last_snapshot = -1
				_inputs.clear()
				_pending_result.clear()
				match_running = false
				match_start_requested.emit(make_match_config())
			elif room_state in ["loading", "playing"]:
				loaded()
		"go":
			if int(m.epoch) == epoch and _result_epoch != epoch:
				# Retry only after the server confirms this epoch is still playing.
				if is_host and int(_pending_result.get("epoch", -1)) == epoch:
					match_running = false
					transport.send(_pending_result)
				else:
					match_running = true
		"input":
			if int(m.epoch) == epoch and is_host:
				m["time"] = Time.get_ticks_msec()
				_inputs[int(m.slot)] = m
		"snapshot":
			if int(m.epoch) == epoch and int(m.tick) > _last_snapshot and not is_host:
				_last_snapshot = int(m.tick)
				snapshot_received.emit(m.data)
		"result":
			if int(m.epoch) == epoch and room_state in ["loading", "playing", "results"] and _result_epoch != epoch:
				tournament = m.tournament.duplicate(true) if m.get("tournament") is Dictionary else {}
				_result_epoch = epoch
				_pending_result.clear()
				match_running = false
				online_result.emit(m.scores)
		"closed":
			var reason := String(m.get("reason", "disconnected"))
			reset()
			connection_lost.emit(reason)


func _transport_lost(reason := "connect_failed") -> void:
	Log.w("online transport lost: " + reason, "Net")
	if not _token.is_empty():
		if _retry_until == 0:
			_retry_until = Time.get_ticks_msec() + 30000
		_retry_at = Time.get_ticks_msec() + 1000
		_set_state(State.DISCONNECTED)
	else:
		_set_state(State.OFFLINE)
		online_error.emit("unavailable")


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _retry_until > 0:
		if now >= _retry_until:
			reset()
			connection_lost.emit("reconnect_timeout")
		elif now >= _retry_at:
			_retry_at = now + 11000
			_connect({"op": "resume", "token": _token})
	if now >= _ping_at and transport != null:
		_ping_at = now + 5000
		transport.send({"op": "ping", "stamp": now})
