extends Node
## Launched by server/network-smoke.js; each peer has an isolated user profile.
var game: Node
var code := ""
var host := false
var count := 4
var announced := false
var configured := false
var started := false
var requested_ready := false
var snapshots := 0
var disconnected_once := false
var restored := false
var before_id := 0
var started_at := 0
var failed := false
var completed := false
var initial_positions: Array[Vector3] = []
var moved := false
var result_drop: ResultDropTransport

class ResultDropTransport extends Node:
	var delegate: Node
	var on_drop: Callable
	var dropped := false
	func send(message: Dictionary) -> bool:
		if message.get("op") == "result" and not dropped:
			dropped = true
			on_drop.call()
			delegate.socket.close()
			return false
		return delegate.send(message)
	func close() -> void:
		delegate.close()
	func connect_room(url: String, first: Dictionary) -> Error:
		return delegate.connect_room(url, first)


func _ready() -> void:
	UserSettings.set_value("graphics_quality", 0)
	UserSettings.set_value("fps_limit", 60)
	for arg in OS.get_cmdline_user_args():
		if arg == "--host": host = true
		if arg.begins_with("--room="): code = arg.trim_prefix("--room=")
		if arg.begins_with("--humans="): count = int(arg.trim_prefix("--humans="))
	if host and "--drop-host-result" in OS.get_cmdline_user_args():
		result_drop = ResultDropTransport.new()
		result_drop.delegate = Net.transport
		result_drop.on_drop = func():
			disconnected_once = true
			before_id = Net.local_peer_id
		Net.add_child(result_drop)
		Net.transport = result_drop
	Net.room_updated.connect(_room)
	Net.match_start_requested.connect(_start)
	Net.snapshot_received.connect(func(_data): snapshots += 1)
	Net.online_error.connect(func(reason): _fail("protocol " + reason))
	Net.connection_lost.connect(func(reason):
		if not completed: _fail("closed " + reason))
	get_tree().create_timer(150).timeout.connect(func(): _fail("timeout"))
	if host:
		Net.host_online(4, true, "Host")
	else:
		Net.join_online(code, "Guest")


func _room() -> void:
	if not announced and host and not Net.room_code.is_empty():
		announced = true
		print("NETWORK_ROOM=" + Net.room_code)
	if disconnected_once and Net.state != Net.State.DISCONNECTED and Net.local_peer_id == before_id:
		restored = true
	if Net.room_state != "lobby":
		return
	if host and not configured:
		configured = true
		var cfg := Net.lobby_config.duplicate(true)
		cfg["rounds"] = 2
		Net.set_lobby_config(cfg)
		return
	if host and int(Net.lobby_config.get("rounds", 0)) != 2:
		return
	if not requested_ready:
		requested_ready = true
		Net.set_ready(Net.local_peer_id, true)
	if host and not started and Net.peers.size() == count and Net.all_ready():
		started = true
		Net.request_start(null)


func _start(cfg: MatchConfig) -> void:
	if game != null:
		_fail("duplicate match")
		return
	cfg.duration_override = 4.0
	cfg.sudden_death = false
	game = load("res://src/match/match_scene.gd").new()
	add_child(game)
	game.setup({"config": cfg, "on_finished": _finished})
	for fighter in game.ctx.fighters:
		initial_positions.append(fighter.global_position)
	InputRouter.assign_virtual(Net.local_slot())
	started_at = Time.get_ticks_msec()


func _physics_process(_delta: float) -> void:
	if game == null or completed:
		return
	var slot := Net.local_slot()
	if slot >= 0:
		InputRouter.push_virtual(slot, Vector2(0.2, -0.2), Vector2.ZERO, 0)
		moved = moved or game.ctx.fighters[slot].global_position.distance_to(initial_positions[slot]) > 0.3
	if not host and Net.local_peer_id == 2 and snapshots >= 8 and not disconnected_once:
		disconnected_once = true
		before_id = Net.local_peer_id
		Net.transport.socket.close()


func _finished(result: MatchResult) -> void:
	if not moved:
		_fail("player did not move")
		return
	if not host and snapshots < 5:
		_fail("no snapshots")
		return
	if disconnected_once and not restored:
		_fail("identity not restored")
		return
	if host and Net._inputs.size() < count - 1:
		_fail("missing remote inputs")
		return
	completed = true
	print("NETWORK_FINISHED=" + JSON.stringify({"id": Net.local_peer_id, "scores": result.scores,
		"snapshots": snapshots, "reconnected": restored, "humans": count, "moved": moved}))
	call_deferred("_finish_cleanup")


func _finish_cleanup() -> void:
	game.teardown()
	game.queue_free()
	game = null
	Net.leave()
	if result_drop != null:
		Net.transport = result_drop.delegate
		result_drop.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)


func _fail(reason: String) -> void:
	if failed or completed:
		return
	failed = true
	push_error("NETWORK_FAIL=" + reason)
	if game != null:
		game.teardown()
		game.queue_free()
	Net.leave()
	get_tree().quit(1)
