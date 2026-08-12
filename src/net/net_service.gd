extends Node
## Online play abstraction. Autoload name: `Net`.
##
## The online transport is deliberately *not* implemented in 1.0 — shipping a
## half-working netcode would destabilise the local game, which is the product.
## What is implemented is the seam: a session model, room codes, ready state,
## lobby synchronisation and an input-frame transport contract, with a working
## `LocalBackend` that satisfies the whole interface in single-machine play.
##
## Because every actor is driven by `InputFrame`s (see `InputRouter`), turning
## this on means implementing `_send_inputs`/`_receive_inputs` against
## ENetMultiplayerPeer or WebRTC and flipping `backend`. Nothing in the
## mini-games, AI or match layer changes.

signal session_state_changed(state: int)
signal peer_joined(peer: Dictionary)
signal peer_left(peer_id: int)
signal peer_ready_changed(peer_id: int, ready: bool)
signal lobby_config_changed(config: Dictionary)
signal match_start_requested(config: MatchConfig)
signal connection_lost(reason: String)

enum State { OFFLINE, HOSTING, JOINING, LOBBY, IN_MATCH, DISCONNECTED }
enum Mode { LOCAL, ONLINE_HOST, ONLINE_CLIENT }

const ROOM_CODE_LENGTH := 5
const ROOM_ALPHABET := "ACDEFGHJKLMNPQRTUVWXY3456789"  # no ambiguous glyphs

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
	room_code = _generate_code()
	lobby_config = {"max_players": max_players, "game": "", "rounds": 1, "difficulty": 1}
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
	var id := peers.size() + 1
	_add_peer(id, name_key, false)
	return id


func _add_peer(id: int, name_key: String, ready: bool) -> void:
	peers[id] = {"id": id, "name": name_key, "ready": ready, "character": "", "slot": peers.size()}
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
	if not peers.has(id):
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


func request_start(config: MatchConfig) -> void:
	_set_state(State.IN_MATCH)
	match_start_requested.emit(config)


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


func _generate_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s := ""
	for i in ROOM_CODE_LENGTH:
		s += ROOM_ALPHABET[rng.randi_range(0, ROOM_ALPHABET.length() - 1)]
	return s
