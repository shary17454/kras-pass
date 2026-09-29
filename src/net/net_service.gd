extends Node
## Online play abstraction. Autoload name: `Net`.
##
## Lobby/session primitives for local development. There is no online transport
## or room-code service in this build; never report this local state as a
## networked room. Actors already consume InputFrames, but packet authority,
## matchmaking, reconnect and relay service still require a real backend.

signal session_state_changed(state: int)
signal peer_joined(peer: Dictionary)
signal peer_left(peer_id: int)
signal peer_ready_changed(peer_id: int, ready: bool)
signal lobby_config_changed(config: Dictionary)
signal match_start_requested(config: MatchConfig)
signal connection_lost(reason: String)

enum State { OFFLINE, HOSTING, JOINING, LOBBY, IN_MATCH, DISCONNECTED }
enum Mode { LOCAL, ONLINE_HOST, ONLINE_CLIENT }

var state: State = State.OFFLINE
var mode: Mode = Mode.LOCAL
var room_code := ""
var is_host := true
var local_peer_id := 1
var peers := {}          # peer_id -> {"id", "name", "ready", "character", "slot"}
var lobby_config := {}
## True when a real transport is compiled in. The UI reads this to show the
## online entries as "coming soon" instead of dead buttons.
var online_available := false


func _ready() -> void:
	reset()


func reset() -> void:
	state = State.OFFLINE
	mode = Mode.LOCAL
	room_code = ""
	lobby_config.clear()
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


func host_online(_max_players: int = 4) -> bool:
	if not online_available:
		Log.w("online transport not built in this release", "Net")
		return false
	return false


func join_online(_code: String) -> bool:
	if not online_available:
		Log.w("online transport not built in this release", "Net")
		return false
	return false


func leave() -> void:
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
	if not peers.has(id):
		return
	peers.erase(id)
	peer_left.emit(id)
	if state == State.IN_MATCH:
		# A disconnect mid-match hands the slot to the AI rather than aborting
		# the round: the remaining players keep playing.
		Log.w("peer %d dropped mid-match; slot handed to AI" % id, "Net")


func set_ready(id: int, ready: bool) -> void:
	if state != State.LOBBY or not peers.has(id):
		return
	peers[id]["ready"] = ready
	peer_ready_changed.emit(id, ready)


func all_ready() -> bool:
	if peers.is_empty():
		return false
	for p in peers.values():
		if not bool(p["ready"]):
			return false
	return true


func set_lobby_config(cfg: Dictionary) -> void:
	lobby_config = cfg.duplicate(true)
	lobby_config_changed.emit(lobby_config)



func request_start(config: MatchConfig) -> bool:
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
	if state == State.IN_MATCH:
		_set_state(State.LOBBY)


# --- input transport contract ----------------------------------------------

## Called every physics tick by the match layer for locally-owned slots. The
## local backend is a no-op; a network backend would batch and send.
func publish_input(_slot: int, _frame: InputFrame, _tick: int) -> void:
	pass


## Returns true when the frame for a remote slot at `tick` is available. The
## local backend always returns false, which makes the match layer fall back to
## the AI brain — exactly the behaviour wanted when a remote player drops.
func consume_input(_slot: int, _frame: InputFrame, _tick: int) -> bool:
	return false
