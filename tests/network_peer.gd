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
var observed_relic_holder := false
var observed_relic_score := false
var observed_tag_change := false
var last_hunter := -1
var hunter_round := -1
var observed_carrying := false
var observed_scrub := false
var observed_warning := false
var observed_magnet := false
var observed_magnet_hold := false
var observed_storm_warning := false
var observed_storm_volley := false
var observed_sky_warning := false
var observed_sky_tilt := false
var observed_crumble_warning := false
var observed_crumble_fall := false
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
	last_hunter = -1
	hunter_round = -1
	game = load("res://src/match/match_scene.gd").new()
	add_child(game)
	game.setup({"config": cfg, "on_finished": _finished})
	if game.machine != null or game.ctx.machine != null:
		_fail("unreplicated hover machine created in online match")
		return
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
	if game_id == "crumble_court":
		for tile: ArenaTile in game.arena.tiles:
			observed_crumble_warning = observed_crumble_warning or tile.state == ArenaTile.State.WARNING
			observed_crumble_fall = observed_crumble_fall or tile.state in [ArenaTile.State.FALLING, ArenaTile.State.GONE]
	if game_id == "sky_court":
		observed_sky_warning = observed_sky_warning or game.controller._warn > 0
		observed_sky_tilt = observed_sky_tilt or game.controller._bank > 0.5
	if game_id == "storm_heart":
		observed_storm_warning = observed_storm_warning or game.controller.is_winding()
		var sequence: int = game.controller._volley_sequence if host else int(game._network_replica.target.get("world", {}).get("volley_sequence", 0))
		observed_storm_volley = observed_storm_volley or sequence > 0
	if game_id == "magnet_court":
		observed_magnet_hold = observed_magnet_hold or not game.controller._held.is_empty()
		for active in game.controller._magnet_until:
			observed_magnet = observed_magnet or active > 0
	if game_id == "mukharrib":
		observed_warning = observed_warning or game.controller._target != null
		var sequence: int = game.controller._scrub_sequence if host else int(game._network_replica.target.get("world", {}).get("scrub_sequence", 0))
		observed_scrub = observed_scrub or sequence > 0
	if game_id == "zone_hold":
		for score in game.ctx.scores:
			observed_zone_score = observed_zone_score or score > 0
	if game_id == "relic_hold":
		observed_relic_holder = observed_relic_holder or game.controller.holder() >= 0
		for score in game.ctx.scores:
			observed_relic_score = observed_relic_score or score > 0
	if game_id == "tag_hunt":
		var hunter: int = game.controller.hunter()
		if hunter_round == game._round_index and last_hunter >= 0 and hunter >= 0 and hunter != last_hunter:
			observed_tag_change = true
		last_hunter = hunter
		hunter_round = game._round_index
	if slot >= 0:
		var movement := Vector2(0.2, -0.2)
		var buttons := 0
		if game_id == "magnet_court":
			var position: Vector3 = game.ctx.fighters[slot].global_position
			var nearest: GameBall = null
			for ball: GameBall in game.controller.balls:
				if nearest == null or position.distance_squared_to(ball.global_position) < position.distance_squared_to(nearest.global_position):
					nearest = ball
			if nearest != null:
				movement = Vector2(nearest.global_position.x - position.x, nearest.global_position.z - position.z).limit_length()
				if position.distance_to(nearest.global_position) <= game.controller.MAGNET_RADIUS and game.controller.magnet_ready(slot):
					buttons = InputFrame.Btn.ABILITY
		if game_id in ["paint_grid", "mnatiq", "mukharrib"]:
			var angle := float(Time.get_ticks_msec() - started_at) / 1800.0 + slot * PI / 2.0
			var target: Vector3 = game.arena.global_position + Vector3(cos(angle), 0, sin(angle)) * 7.0
			var direction: Vector3 = target - game.ctx.fighters[slot].global_position
			movement = Vector2(direction.x, direction.z).limit_length()
		if game_id == "tag_hunt":
			var direction: Vector3 = game.arena.global_position - game.ctx.fighters[slot].global_position
			movement = Vector2(direction.x, direction.z).limit_length()
		if game_id == "relic_hold":
			var position: Vector3 = game.ctx.fighters[slot].global_position
			var target: Vector3 = game.controller.relic_position()
			if not host and game.controller.holder() < 0 and is_instance_valid(game._network_replica._relic):
				var views: Dictionary = game._network_replica._relic.items.views
				if not views.is_empty():
					target = views.values()[0].global_position
			if game.controller.holder() == slot:
				target = game.arena.global_position + Vector3(cos(slot + 1.0), 0, sin(slot + 1.0)) * 5.0
			elif game.controller.holder() >= 0:
				buttons = InputFrame.Btn.ATTACK
			movement = Vector2(target.x - position.x, target.z - position.z).limit_length()
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
	if not host and game_id == "crumble_court":
		var rows: Array = game._network_replica.target.get("world", {}).get("tiles", [])
		if world_snapshots < 5 or rows.size() != game.arena.tiles.size():
			_fail("missing crumble world")
			return
		for i in rows.size():
			var tile: ArenaTile = game.arena.tiles[i]
			if tile.state != int(rows[i][0]) or absf(tile.position.y - float(rows[i][2])) > 0.001:
				_fail("crumble floor presentation diverged")
				return
	if not host and game_id in ["goal_guard", "magnet_court", "storm_heart", "sky_court"] and (world_snapshots < 5 or game.controller.balls.is_empty()):
		_fail("missing goal world")
		return
	if not host and game_id in ["goal_guard", "magnet_court", "storm_heart", "sky_court"]:
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
		if game_id == "storm_heart":
			if absf(game.controller._windup - float(world.windup)) > 0.001 \
					or absf(game.controller._volley_timer - float(world.volley_timer)) > 0.001 \
					or absf(angle_difference(game.controller._blades.rotation.y, float(world.rotor))) > 0.001:
				_fail("turbine presentation diverged")
				return
		if game_id == "sky_court":
			if game.controller._warning_engine != int(world.engine) or absf(game.controller._bank - float(world.bank)) > 0.001 \
					or absf(game.controller._warn - float(world.warning)) > 0.001:
				_fail("sky court state diverged")
				return
		if game_id == "magnet_court":
			for slot in game.ctx.player_count():
				if absf(game.controller._charge[slot] - float(world.magnet_charge[slot])) > 0.001 \
						or absf(game.controller._magnet_until[slot] - float(world.magnet_active[slot])) > 0.001:
					_fail("magnet meter diverged")
					return
			for i in game.controller.balls.size():
				if int(game.controller._held.get(game.controller.balls[i].get_instance_id(), -1)) != int(world.held[i]):
					_fail("magnet ball ownership diverged")
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
	if not host and game_id == "relic_hold":
		var world: Dictionary = game._network_replica.target.get("world", {})
		var view = game._network_replica._relic
		if world_snapshots < 5 or not is_instance_valid(view) or game.controller.holder() != int(world.get("holder", -2)) \
				or view.items.views.size() != world.get("items", []).size():
			_fail("relic world diverged")
			return
		for row in world.items:
			if not view.items.views.has(row.id) or view.items.views[row.id].global_position.distance_to(Vector3(row.position[0], row.position[1], row.position[2])) > 0.1:
				_fail("loose relic presentation diverged")
				return
		for i in game.ctx.player_count():
			if game.ctx.fighters[i].carrying != (1 if i == int(world.holder) else 0):
				_fail("relic carrier state diverged")
				return
	if not host and game_id == "tag_hunt":
		var world: Dictionary = game._network_replica.target.get("world", {})
		if world_snapshots < 5 or game.controller.hunter() != int(world.get("hunter", -2)) \
				or absf(game.controller.handover_grace() - float(world.get("grace", -1))) > 0.001:
			_fail("hunter role presentation diverged")
			return
	if not host and game_id in ["paint_grid", "mnatiq", "mukharrib"]:
		var world: Dictionary = game._network_replica.target.get("world", {})
		var painted := false
		if world_snapshots < 5 or world.get("owners", []).size() != 169:
			_fail("missing paint world")
			return
		for tile: ArenaTile in game.controller._tiles:
			var index := (tile.grid_x + 6) * 13 + tile.grid_z + 6
			if tile.owner_slot != int(world.owners[index]):
				_fail("paint ownership diverged")
				return
			painted = painted or tile.owner_slot >= 0
		if not painted:
			_fail("paint match never claimed a tile")
			return
		if game_id == "mukharrib":
			var position := Vector3(world.drone[0], world.drone[1], world.drone[2])
			var actual_target: int = -1 if game.controller._target == null else (game.controller._target.grid_x + 6) * 13 + game.controller._target.grid_z + 6
			if not game.controller._drone.global_position.is_equal_approx(position) or actual_target != int(world.target):
				_fail("drone or warning presentation diverged")
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
	if game_id == "relic_hold" and (not observed_relic_holder or not observed_relic_score):
		_fail("relic finished without observed ownership and scoring")
		return
	if game_id == "tag_hunt" and not observed_tag_change:
		_fail("match never transferred hunter role during a round")
		return
	if game_id == "mukharrib" and (not observed_scrub or not observed_warning):
		_fail("drone never warned and scrubbed during match")
		return
	if game_id == "magnet_court" and (not observed_magnet or not observed_magnet_hold):
		_fail("match never activated and caught a ball with a magnet")
		return
	if game_id == "storm_heart" and (not observed_storm_warning or not observed_storm_volley):
		_fail("turbine never warned and fired a volley")
		return
	if game_id == "sky_court" and (not observed_sky_warning or not observed_sky_tilt):
		_fail("sky court never warned and tilted")
		return
	if game_id == "crumble_court" and (not observed_crumble_warning or not observed_crumble_fall):
		_fail("crumble court never warned and collapsed")
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
