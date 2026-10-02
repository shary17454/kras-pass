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
var tournament_mode := false
var game_id := "ring_rumble"
var world_snapshots := 0
var observed_collection_score := false
var observed_zone_score := false
var observed_carrying := false
var finished_matches := 0
var result_drop: ResultDropTransport
var _last_frame_ms := 0
var _max_frame_gap_ms := 0
var _next_diagnostic_ms := 0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _last_frame_ms > 0:
		_max_frame_gap_ms = maxi(_max_frame_gap_ms, now - _last_frame_ms)
	_last_frame_ms = now
	if now >= _next_diagnostic_ms:
		_next_diagnostic_ms = now + 10000
		print("NETWORK_TIMING=" + JSON.stringify({"epoch": Net.epoch, "state": Net.room_state,
			"phase": game.phase if is_instance_valid(game) else -1, "running": Net.match_running,
			"max_frame_gap_ms": _max_frame_gap_ms, "snapshots": snapshots}))

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
		if arg == "--tournament": tournament_mode = true
		if arg.begins_with("--game="): game_id = arg.trim_prefix("--game=")
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
	Net.snapshot_received.connect(func(data):
		snapshots += 1
		if data.get("world") is Dictionary: world_snapshots += 1)
	Net.online_error.connect(func(reason): _fail("protocol " + reason))
	Net.connection_lost.connect(func(reason):
		if not completed: _fail("closed " + reason))
	get_tree().create_timer(300 if tournament_mode else 150).timeout.connect(func(): _fail("timeout"))
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
	var between_rounds := Net.room_state == "results" and not Net.tournament.is_empty() and not bool(Net.tournament.complete)
	if Net.room_state != "lobby" and not between_rounds:
		return
	if between_rounds and game != null:
		return
	if host and not configured:
		configured = true
		var cfg := Net.lobby_config.duplicate(true)
		cfg["rounds"] = 2
		if game_id != "ring_rumble":
			cfg["game"] = game_id
			cfg["arena"] = Net.ONLINE_ARENAS[game_id][0]
		if tournament_mode:
			cfg["tournament"] = {"mode": "points", "target": 3, "rotation": "random_no_repeat", "points": [5, 3, 2, 1],
				"entries": [{"game": "ring_rumble", "arena": "vortex_ring"}, {"game": "ring_rumble", "arena": "storm_ring"}]}
			cfg["tournament"]["entries"] = []
			for arena_id in Net.ONLINE_ARENAS[game_id]:
				cfg["tournament"]["entries"].append({"game": game_id, "arena": arena_id})
		Net.set_lobby_config(cfg)
		return
	if host and int(Net.lobby_config.get("rounds", 0)) != 2:
		return
	if not requested_ready:
		requested_ready = true
		Net.set_ready(Net.local_peer_id, true)
	if host and not started and Net.peers.size() == count and Net.all_ready():
		started = true
		if between_rounds: Net.next_tournament_round()
		else: Net.request_start(null)


func _start(cfg: MatchConfig) -> void:
	if game != null:
		_fail("duplicate match")
		return
	cfg.duration_override = 4.0 if game_id == "ring_rumble" else 15.0
	cfg.sudden_death = false
	initial_positions.clear()
	moved = false
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
	if game_id in ["gem_grab", "star_rush"]:
		for score in game.ctx.scores:
			observed_collection_score = observed_collection_score or score > 0
		for fighter in game.ctx.fighters:
			observed_carrying = observed_carrying or fighter.carrying > 0
	var slot := Net.local_slot()
	if game_id == "zone_hold":
		for score in game.ctx.scores:
			observed_zone_score = observed_zone_score or score > 0
	if slot >= 0:
		var movement := Vector2(0.2, -0.2)
		var buttons := 0
		if game_id == "zone_hold":
			var p: Vector3 = game.ctx.fighters[slot].global_position - game.arena.global_position
			var zone: Vector3 = game.controller.zone_position - game.arena.global_position
			var angle := atan2(zone.z, zone.x) + slot * 0.9
			var current := atan2(p.z, p.x)
			var next := current + clampf(wrapf(angle - current, -PI, PI), -0.25, 0.25)
			var target: Vector3 = Vector3(cos(next), 0, sin(next)) * game.arena.def.radius * 0.72
			movement = Vector2(target.x - p.x, target.z - p.z).limit_length()
		if game_id in ["gem_grab", "star_rush"]:
			movement = _collection_movement(slot)
			if game_id == "gem_grab" and (Time.get_ticks_msec() / 500) % 2 == 0:
				buttons = InputFrame.Btn.JUMP
		InputRouter.push_virtual(slot, movement, Vector2.ZERO, buttons)
		moved = moved or game.ctx.fighters[slot].global_position.distance_to(initial_positions[slot]) > 0.3
	if not host and Net.local_peer_id == 2 and snapshots >= 8 and not disconnected_once:
		disconnected_once = true
		before_id = Net.local_peer_id
		Net.transport.socket.close()


func _collection_movement(slot: int) -> Vector2:
	var fighter: Fighter = game.ctx.fighters[slot]
	var target: Vector3 = fighter.global_position
	if game_id == "star_rush" and fighter.carrying > 0:
		target = game.controller.base_position(slot)
	else:
		var candidates: Array = []
		if host:
			for item in game.controller._items:
				if item.available: candidates.append(item.global_position)
		elif is_instance_valid(game._network_replica._collectibles):
			for view in game._network_replica._collectibles.views.values():
				candidates.append(view.global_position)
		var nearest := INF
		for position: Vector3 in candidates:
			var distance := fighter.global_position.distance_squared_to(position)
			if distance < nearest:
				nearest = distance
				target = position
	var direction := target - fighter.global_position
	return Vector2(direction.x, direction.z).limit_length()


func _finished(result: MatchResult) -> void:
	var contenders: Array = game.config.rule("online_contenders", [])
	var spectator := not contenders.is_empty() and not contenders.has(Net.local_slot())
	print("NETWORK_ROUND=" + JSON.stringify({"epoch": Net.epoch, "game": game.config.minigame_id,
		"arena": game.config.arena_id, "scores": result.scores, "spectator": spectator, "moved": moved}))
	if spectator and game.ctx.is_alive(Net.local_slot()):
		_fail("spectator remained active")
		return
	if not moved and not spectator:
		_fail("player did not move")
		return
	if not host and snapshots < 5:
		_fail("no snapshots")
		return
	if not host and game_id == "goal_guard" and (world_snapshots < 5 or game.controller.balls.is_empty()):
		_fail("missing goal world")
		return
	if not host and game_id == "goal_guard":
		var world: Dictionary = game._network_replica.target.get("world", {})
		if game.controller.balls.size() != world.get("balls", []).size():
			_fail("replica ball count diverged")
			return
		for i in game.controller.balls.size():
			var ball: GameBall = game.controller.balls[i]
			var row: Dictionary = world.balls[i]
			var position := Vector3(row.position[0], row.position[1], row.position[2])
			if ball.global_position.distance_to(position) > 1.0 or ball.heavy != bool(row.heavy):
				_fail("replica ball presentation diverged")
				return
	if not host and game_id in ["gem_grab", "star_rush"]:
		var view = game._network_replica._collectibles
		var world: Dictionary = game._network_replica.target.get("world", {})
		if world_snapshots < 5 or not is_instance_valid(view) or view.views.size() != world.get("items", []).size():
			_fail("missing collection world")
			return
		for row in world.items:
			if not view.views.has(row.id) or view.views[row.id].global_position.distance_to(Vector3(row.position[0], row.position[1], row.position[2])) > 0.1:
				_fail("collection presentation diverged")
				return
		if game.ctx.fighters[Net.local_slot()].carrying != int(world.carrying[Net.local_slot()]):
			_fail("carrying state diverged")
			return
	if not host and game_id == "zone_hold":
		var world: Dictionary = game._network_replica.target.get("world", {})
		if world_snapshots < 5 or world.is_empty():
			_fail("missing zone world")
			return
		var position := Vector3(world.position[0], world.position[1], world.position[2])
		if game.controller._marker.global_position.distance_to(position) > 0.01 \
				or absf(game.controller.zone_radius - float(world.radius)) > 0.001 \
				or game.controller._ring_color.to_html() != world.color:
			_fail("zone presentation diverged")
			return
	if disconnected_once and not restored:
		_fail("identity not restored")
		return
	if host and Net._inputs.size() < count - 1:
		_fail("missing remote inputs")
		return
	finished_matches += 1
	if tournament_mode and not bool(Net.tournament.get("complete", false)):
		call_deferred("_continue_tournament")
		return
	if game_id in ["gem_grab", "star_rush"] and not observed_collection_score:
		_fail("collection finished without any scoring")
		return
	if game_id == "star_rush" and not observed_carrying:
		_fail("star carrying was never observed")
		return
	if game_id == "zone_hold" and not observed_zone_score:
		_fail("zone finished without capture scoring")
		return
	completed = true
	print("NETWORK_FINISHED=" + JSON.stringify({"id": Net.local_peer_id, "scores": result.scores,
		"snapshots": snapshots, "reconnected": restored, "humans": count, "moved": moved,
		"matches": finished_matches, "tournament": Net.tournament, "world_snapshots": world_snapshots,
		"collection_scored": observed_collection_score, "carrying_seen": observed_carrying}))
	call_deferred("_finish_cleanup")


func _continue_tournament() -> void:
	game.teardown()
	game.queue_free()
	game = null
	requested_ready = false
	started = false
	await get_tree().process_frame
	await get_tree().process_frame
	_room()


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
