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
var requested_game_id := ""
var duo_tiebreak := false
var race_tiebreak := false
var siege_tiebreak := false
var forge_tiebreak := false
var sovereign_tiebreak := false
var dread_tiebreak := false
var boss_final_cups: Array = []
var observed_boss_final := false
var observed_kart_final := false
var kart_final_cups: Array = []
var observed_duo_final := false
var duo_final_cups: Array = []
var duo_arenas_seen := {}
var floe_arenas_seen := {}
var floe_start_positions: Array = []
var observed_floe_moved := false
var observed_floe_fall := false
var observed_turret_shot := false
var observed_turret_damage := false
var observed_turret_score := false
var observed_tank_armor := false
var observed_tank_inventory := false
var observed_scrap_ram := false
var observed_scrap_damage := false
var observed_fawda_events := {}
var fawda_pickup_probe := {}
var observed_kart_boost := false
var observed_kart_rescue := false
var fawda_arenas_seen := {}
var tank_arenas_seen := {}
var tank_route := PackedVector3Array()
var tank_route_target := Vector3.INF
var observed_duo_score := false
var observed_duo_life_loss := false
var observed_duo_damage := false
var world_snapshots := 0
var observed_sweeper_hit := false
var observed_duel_damage := false
var observed_duel_life_loss := false
var observed_duel_respawn := false
var observed_bumper_hit := false
var observed_bumper_respawn := false
var bumper_waiting := {}
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
var observed_blast_fuse := false
var observed_blast_explosion := false
var observed_color_drop := false
var observed_draw_signal := false
var observed_draw_response := false
var draw_tap_sequence := -1
var observed_remote_input_slots := {}
var observed_echo_cue := false
var observed_echo_score := false
var observed_crate_break := false
var observed_crate_score := false
var observed_lab_weapon := false
var observed_lab_shot := false
var crate_attack_clock := 0.0
var echo_serial := -1
var echo_cues := {}
var echo_leaving := false
var finished_matches := 0
var result_drop: ResultDropTransport
var _last_frame_ms := 0
var _max_frame_gap_ms := 0
var _next_diagnostic_ms := 0
var observed_armed_pickup := false
var observed_armed_weapon := false
var observed_siege_hit := false
var observed_siege_destroyed := false
var siege_arenas_seen := {}
var observed_siege_final := false
var siege_final_cups: Array = []
var siege_target_slot := -1
var siege_via_center := true
var siege_route_round := -1
var siege_hits_by_round := {}
var siege_destruction_by_round := {}
var forge_damage_by_round := {}
var forge_slag_by_round := {}
var forge_strike_by_round := {}
var forge_defeat_by_round := {}
var dread_damage_by_round := {}
var dread_shot_by_round := {}
var dread_defeat_by_round := {}
var sovereign_damage_by_round := {}
var sovereign_orbs_by_round := {}
var sovereign_return_by_round := {}
var sovereign_shield_by_round := {}
var sovereign_defeat_by_round := {}
var colossus_damage_by_round := {}
var colossus_crater_by_round := {}
var colossus_strike_by_round := {}
var colossus_defeat_by_round := {}


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _last_frame_ms > 0:
		_max_frame_gap_ms = maxi(_max_frame_gap_ms, now - _last_frame_ms)
	_last_frame_ms = now
	if now >= _next_diagnostic_ms:
		_next_diagnostic_ms = now + 10000
		print("NETWORK_TIMING=" + JSON.stringify({"epoch": Net.epoch, "state": Net.room_state,
			"seed": game.config.seed if is_instance_valid(game) else 0,
			"phase": game.phase if is_instance_valid(game) else -1, "running": Net.match_running,
			"max_frame_gap_ms": _max_frame_gap_ms, "snapshots": snapshots}))
		if game_id == "boss_colossus" and is_instance_valid(game):
			var world := _colossus_world()
			var fighters: Array = []
			for fighter in game.ctx.fighters:
				fighters.append({"slot": fighter.slot, "position": str(fighter.global_position),
					"velocity": str(fighter.velocity), "alive": fighter.alive, "attack": fighter.is_attacking()})
			print("NETWORK_COLOSSUS=" + JSON.stringify({"round": game._round_index,
				"time_left": game.ctx.time_left, "elapsed": game._round_elapsed,
				"health": world.get("boss", {}).get("health", -1), "craters": world.get("craters", []).size(),
				"exposed": world.get("exposed", 0), "fighters": fighters,
				"damage_rounds": colossus_damage_by_round.keys(), "defeat_rounds": colossus_defeat_by_round.keys()}))
		if game_id == "hurdle_dash" and is_instance_valid(game):
			var runners: Array = []
			for fighter in game.ctx.fighters:
				runners.append({"slot": fighter.slot, "position": str(fighter.global_position), "velocity": str(fighter.velocity), "can_jump": fighter.can_jump, "control": fighter.control_enabled, "finish": game.controller.finish_times[fighter.slot]})
			print("NETWORK_HURDLES=" + JSON.stringify(runners))
		if game_id in ["kart_sprint", "sabaq_sawarikh"] and is_instance_valid(game):
			var racers: Array = []
			for fighter in game.ctx.fighters:
				racers.append({"slot": fighter.slot, "position": str(fighter.global_position), "velocity": str(fighter.velocity),
					"control": fighter.control_enabled, "alive": fighter.alive, "recovering": game.controller.is_recovering(fighter.slot),
					"lap": game.controller.lap[fighter.slot], "next": game.controller._next_cp[fighter.slot],
					"finish": game.controller.finish_times[fighter.slot]})
			print("NETWORK_KART=" + JSON.stringify({"round": game._round_index, "elapsed": game.controller._elapsed, "racers": racers}))
		if game_id == "base_siege" and is_instance_valid(game):
			var fighters: Array = []
			for fighter in game.ctx.fighters:
				fighters.append({"slot": fighter.slot, "position": str(fighter.global_position), "velocity": str(fighter.velocity),
					"facing": str(fighter.facing), "control": fighter.control_enabled, "attack": fighter.can_attack,
					"callback": fighter.attacked.is_connected(game.controller._on_attacked)})
			var bases: Array = []
			for base in game.controller._bases:
				bases.append({"slot": base.slot, "position": str(base.node.global_position), "health": base.health, "hits": base.hits})
			print("NETWORK_SIEGE=" + JSON.stringify({"fighters": fighters, "bases": bases, "view": game.controller.presentation_only}))
		if game_id == "boss_forge" and is_instance_valid(game):
			var fighters: Array = []
			for fighter in game.ctx.fighters:
				fighters.append({"slot": fighter.slot, "position": str(fighter.global_position),
					"velocity": str(fighter.velocity), "attack": fighter.is_attacking(), "control": fighter.control_enabled})
			print("NETWORK_FORGE=" + JSON.stringify({"round": game._round_index, "fighters": fighters,
				"world": _forge_world(), "damage_rounds": forge_damage_by_round.keys(),
				"slag_rounds": forge_slag_by_round.keys(), "strike_rounds": forge_strike_by_round.keys()}))
		if game_id == "boss_dreadnought" and is_instance_valid(game):
			print("NETWORK_DREAD=" + JSON.stringify({"round": game._round_index,
				"boss": _dread_world().get("boss", {}), "scores": Array(game.ctx.scores),
				"damage_rounds": dread_damage_by_round.keys(), "shot_rounds": dread_shot_by_round.keys(),
				"defeat_rounds": dread_defeat_by_round.keys()}))
		if game_id == "boss_sovereign" and is_instance_valid(game):
			print("NETWORK_SOVEREIGN=" + JSON.stringify({"round": game._round_index,
				"world": _sovereign_world(), "scores": Array(game.ctx.scores),
				"damage_rounds": sovereign_damage_by_round.keys(), "orb_rounds": sovereign_orbs_by_round.keys(),
				"return_rounds": sovereign_return_by_round.keys(), "shield_rounds": sovereign_shield_by_round.keys(),
				"defeat_rounds": sovereign_defeat_by_round.keys()}))
		if game_id == "crate_relay" and is_instance_valid(game):
			var players: Array = []
			for fighter in game.ctx.fighters:
				players.append({"slot": fighter.slot, "position": str(fighter.global_position), "velocity": str(fighter.velocity),
					"carrying": fighter.carrying, "score": game.ctx.scores[fighter.slot], "control": fighter.control_enabled})
			print("NETWORK_RELAY=" + JSON.stringify({"slot": Net.local_slot(), "players": players,
				"movement": str(_collection_movement(Net.local_slot())) if Net.local_slot() >= 0 else "none"}))
		if game_id == "tank_arena" and is_instance_valid(game):
			var positions: Array = []
			for fighter in game.ctx.fighters:
				positions.append(str(fighter.global_position))
			print("NETWORK_ATV=" + JSON.stringify({"positions": positions, "armor": game.controller.armor,
				"ammo": game.controller.ammo, "inventory_seen": observed_tank_inventory, "route": str(tank_route)}))

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
		if arg == "--duo-tiebreak": duo_tiebreak = true
		if arg == "--race-tiebreak": race_tiebreak = true
		if arg == "--siege-tiebreak": siege_tiebreak = true
		if arg == "--forge-tiebreak": forge_tiebreak = true
		if arg == "--sovereign-tiebreak": sovereign_tiebreak = true
		if arg == "--dread-tiebreak": dread_tiebreak = true
		if arg.begins_with("--game="): game_id = arg.trim_prefix("--game=")
		if arg.begins_with("--room="): code = arg.trim_prefix("--room=")
		if arg.begins_with("--humans="): count = int(arg.trim_prefix("--humans="))
	requested_game_id = game_id
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
	var deadline := (900 if tournament_mode else 600) if requested_game_id == "sabaq_sawarikh" else (750 if tournament_mode else 400) if requested_game_id in ["boss_forge", "boss_dreadnought", "boss_sovereign", "boss_colossus"] else (300 if tournament_mode else 150)
	if requested_game_id == "kart_sprint":
		deadline = preload("res://tests/network_smoke_config.gd").kart_deadline(tournament_mode)
	get_tree().create_timer(deadline).timeout.connect(func(): _fail("timeout"))
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
		if game_id in ["kart_sprint", "sabaq_sawarikh"]: cfg["race_laps"] = 3
		if game_id != "ring_rumble":
			cfg["game"] = game_id
			cfg["arena"] = Net.ONLINE_ARENAS[game_id][0]
		if tournament_mode:
			cfg["tournament"] = {"mode": "points", "target": 3, "rotation": "random_no_repeat", "points": [5, 3, 2, 1],
				"entries": [{"game": "ring_rumble", "arena": "vortex_ring"}, {"game": "ring_rumble", "arena": "storm_ring"}]}
			cfg["tournament"]["entries"] = []
			for arena_id in Net.ONLINE_ARENAS[game_id]:
				cfg["tournament"]["entries"].append({"game": game_id, "arena": arena_id})
			if duo_tiebreak or race_tiebreak or siege_tiebreak or forge_tiebreak or dread_tiebreak or sovereign_tiebreak:
				cfg["tournament"]["points"] = [1, 1, 1, 1]
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
	game_id = cfg.minigame_id
	draw_tap_sequence = -1
	observed_remote_input_slots.clear()
	if game_id == "duo_clash":
		duo_arenas_seen[cfg.arena_id] = true
	cfg.duration_override = 4.0 if game_id == "ring_rumble" else 15.0
	preload("res://tests/network_smoke_config.gd").configure_boss(cfg)
	if game_id in ["boss_forge", "boss_dreadnought", "boss_sovereign", "boss_colossus"] and not cfg.rule("online_contenders", []).is_empty():
		observed_boss_final = true
		if boss_final_cups.is_empty(): boss_final_cups = Net.tournament.get("cups", []).duplicate()
	if game_id == "hurdle_dash":
		cfg.duration_override = 35.0
	if game_id == "rising_tide":
		cfg.duration_override = 45.0
	if game_id == "duel_pit":
		cfg.duration_override = 35.0
	if game_id == "duo_clash":
		cfg.duration_override = 35.0
	if game_id == "drift_floes":
		cfg.duration_override = 25.0
		floe_arenas_seen[cfg.arena_id] = true
	if game_id == "bumper_bowl":
		cfg.duration_override = 35.0
	if game_id == "turret_duel":
		cfg.duration_override = 25.0
	if game_id == "tank_arena":
		cfg.duration_override = 30.0
		tank_arenas_seen[cfg.arena_id] = true
		tank_route.clear()
		tank_route_target = Vector3.INF
		observed_turret_shot = false
		observed_tank_armor = false
		observed_tank_inventory = false
	if game_id == "scrap_karts":
		cfg.duration_override = 30.0
		observed_scrap_ram = false
		observed_scrap_damage = false
	if game_id == "base_siege":
		cfg.duration_override = 45.0 if cfg.rule("online_contenders", []).is_empty() else 20.0
		if not cfg.rule("online_contenders", []).is_empty():
			observed_siege_final = true
			if siege_final_cups.is_empty(): siege_final_cups = Net.tournament.get("cups", []).duplicate()
		observed_siege_hit = false
		observed_siege_destroyed = false
		siege_arenas_seen[cfg.arena_id] = true
		siege_target_slot = -1
		siege_via_center = true
		siege_route_round = -1
		siege_hits_by_round.clear()
		siege_destruction_by_round.clear()
	if game_id == "boss_forge":
		forge_damage_by_round.clear()
		forge_slag_by_round.clear()
		forge_strike_by_round.clear()
		forge_defeat_by_round.clear()
	if game_id == "boss_dreadnought":
		dread_damage_by_round.clear()
		dread_shot_by_round.clear()
		dread_defeat_by_round.clear()
	if game_id == "boss_sovereign":
		sovereign_damage_by_round.clear()
		sovereign_orbs_by_round.clear()
		sovereign_return_by_round.clear()
		sovereign_shield_by_round.clear()
		sovereign_defeat_by_round.clear()
	if game_id == "boss_colossus":
		colossus_damage_by_round.clear()
		colossus_crater_by_round.clear()
		colossus_strike_by_round.clear()
		colossus_defeat_by_round.clear()
	if game_id == "fawda":
		cfg.duration_override = 25.0
		observed_fawda_events.clear()
		fawda_pickup_probe = {"samples": 0, "slow_loose_observations": 0,
			"in_range_pairs": 0, "minimum_distance": -1.0, "closest": {}}
		fawda_arenas_seen[cfg.arena_id] = true
	if game_id in ["kart_sprint", "sabaq_sawarikh"]:
		observed_kart_boost = false
		observed_kart_rescue = false
		observed_armed_pickup = false
		observed_armed_weapon = false
		if not cfg.rule("online_contenders", []).is_empty():
			observed_kart_final = true
			if kart_final_cups.is_empty(): kart_final_cups = Net.tournament.get("cups", []).duplicate()
	if requested_game_id == "duo_clash" and game_id == "duel_pit":
		cfg.duration_override = 20.0
		observed_duo_final = true
		if duo_final_cups.is_empty():
			duo_final_cups = Net.tournament.get("cups", []).duplicate()
	cfg.sudden_death = false
	initial_positions.clear()
	floe_start_positions.clear()
	moved = false
	last_hunter = -1
	hunter_round = -1
	echo_serial = -1
	echo_cues.clear()
	echo_leaving = false
	bumper_waiting.clear()
	game = load("res://src/match/match_scene.gd").new()
	add_child(game)
	game.setup({"config": cfg, "on_finished": _finished})
	if requested_game_id == "duo_clash" and game_id == "duel_pit":
		for fighter in game.ctx.fighters:
			if not fighter.teammates.is_empty():
				_fail("individual team tiebreak retained friendly-fire protection")
				return
	if host and game_id == "sweeper_storm" and not EventBus.player_hit.is_connected(_on_sweeper_hit):
		EventBus.player_hit.connect(_on_sweeper_hit)
	if game.machine != null or game.ctx.machine != null:
		_fail("unreplicated hover machine created in online match")
		return
	for fighter in game.ctx.fighters:
		initial_positions.append(fighter.global_position)
	InputRouter.assign_virtual(Net.local_slot())
	started_at = Time.get_ticks_msec()


func _on_sweeper_hit(attacker: int, _victim: int, strength: float) -> void:
	if attacker == -1 and strength > 0.0:
		observed_sweeper_hit = true


func _physics_process(_delta: float) -> void:
	if game == null or completed:
		return
	if game_id in ["crate_smash", "lab_crates"]:
		if game.phase in [MatchPhase.P.PLAYING, MatchPhase.P.SUDDEN_DEATH]:
			crate_attack_clock = fmod(crate_attack_clock + _delta, 0.8)
		else:
			crate_attack_clock = 0.0
	if host:
		for remote_slot in Net._inputs:
			observed_remote_input_slots[remote_slot] = true
	if game_id in ["kart_sprint", "sabaq_sawarikh"]:
		var world: Dictionary = load("res://src/net/kart_replica.gd").capture(game.controller) if host else game._network_replica.target.get("world", {})
		if game_id == "sabaq_sawarikh":
			var armed: Dictionary = load("res://src/net/armed_race_replica.gd").capture(game.controller) if host else world
			observed_armed_pickup = observed_armed_pickup or int(armed.get("events", {}).get("pickup", {}).get("sequence", 0)) > 0
			observed_armed_weapon = observed_armed_weapon or not armed.get("shots", []).is_empty() or not armed.get("bombs", []).is_empty()
			world = armed.get("race", {})
		for serial in world.get("boost", {}).get("serial", []):
			observed_kart_boost = observed_kart_boost or int(serial) > 0
		for progress in world.get("recovery", []):
			observed_kart_rescue = observed_kart_rescue or float(progress) >= 0.0
	if game_id == "fawda":
		var world: Dictionary = _fawda_world()
		_observe_fawda_pickup(world)
		for kind in world.get("events", {}):
			if int(world.events[kind].sequence) > 0:
				observed_fawda_events[kind] = true
	if game_id == "scrap_karts":
		observed_scrap_ram = observed_scrap_ram or game.controller.ram_serial > 0
		for health in game.controller.health:
			observed_scrap_damage = observed_scrap_damage or float(health) < game.controller._max_health
	if game_id == "base_siege":
		if siege_route_round != game._round_index:
			siege_route_round = game._round_index
			siege_target_slot = -1
			siege_via_center = true
		for base in game.controller._bases:
			observed_siege_hit = observed_siege_hit or int(base.hits) > 0
			observed_siege_destroyed = observed_siege_destroyed or float(base.health) <= 0.0
			if int(base.hits) > 0: siege_hits_by_round[game._round_index] = true
			if float(base.health) <= 0.0: siege_destruction_by_round[game._round_index] = true
	if game_id == "boss_colossus":
		var world := _colossus_world()
		for warning in world.get("warnings", []):
			if absf(float(warning.position[1]) - game.arena.global_position.y) > 0.01:
				_fail("colossus warning is not on arena floor")
				return
		if game.phase == MatchPhase.P.FINISH and game.config.rule("online_contenders", []).is_empty() \
			and not bool(world.get("boss", {}).get("defeated", false)):
			_fail("colossus round %d ended without actual boss defeat" % game._round_index)
			return
		if int(world.get("boss", {}).get("damage", 0)) > 0: colossus_damage_by_round[game._round_index] = true
		if int(world.get("boss", {}).get("strike", 0)) > 0: colossus_strike_by_round[game._round_index] = true
		if not world.get("craters", []).is_empty(): colossus_crater_by_round[game._round_index] = true
		if world.get("boss", {}).get("defeated", false): colossus_defeat_by_round[game._round_index] = true
	if game_id == "boss_forge":
		var world: Dictionary = _forge_world()
		if int(world.get("boss", {}).get("damage", 0)) > 0:
			forge_damage_by_round[game._round_index] = true
		if int(world.get("boss", {}).get("strike", 0)) > 0:
			forge_strike_by_round[game._round_index] = true
		if not world.get("slag", []).is_empty():
			forge_slag_by_round[game._round_index] = true
		if bool(world.get("boss", {}).get("defeated", false)):
			forge_defeat_by_round[game._round_index] = true
	if game_id == "boss_dreadnought":
		var world := _dread_world()
		if int(world.get("boss", {}).get("damage", 0)) > 0: dread_damage_by_round[game._round_index] = true
		if not world.get("shots", []).is_empty(): dread_shot_by_round[game._round_index] = true
		if world.get("boss", {}).get("defeated", false): dread_defeat_by_round[game._round_index] = true
	if game_id == "boss_sovereign":
		var world := _sovereign_world()
		for warning in world.get("warnings", []):
			if absf(float(warning.position[1]) - game.arena.global_position.y) > 0.01:
				_fail("sovereign warning is not on the arena floor")
				return
		if int(world.get("boss", {}).get("damage", 0)) > 0: sovereign_damage_by_round[game._round_index] = true
		if int(world.get("volleys", 0)) > 0: sovereign_orbs_by_round[game._round_index] = true
		if world.get("shielded", false): sovereign_shield_by_round[game._round_index] = true
		if int(world.get("returns", 0)) > 0: sovereign_return_by_round[game._round_index] = true
		if world.get("boss", {}).get("defeated", false): sovereign_defeat_by_round[game._round_index] = true
	if game_id in ["turret_duel", "tank_arena"]:
		var adapter = load("res://src/net/tank_replica.gd" if game_id == "tank_arena" else "res://src/net/turret_replica.gd")
		var world: Dictionary = adapter.capture(game.controller) if host else game._network_replica.target.get("world", {})
		observed_turret_shot = observed_turret_shot or not world.get("shots", []).is_empty()
		for value in world.get("damage", []):
			observed_turret_damage = observed_turret_damage or float(value) > 0.0
		for score in game.ctx.scores:
			observed_turret_score = observed_turret_score or score > 0
		if game_id == "tank_arena":
			for armor in world.get("armor", []):
				observed_tank_armor = observed_tank_armor or int(armor) < 100
			for ammo in world.get("ammo", []):
				observed_tank_inventory = observed_tank_inventory or int(ammo) > 0
	if game_id == "drift_floes":
		if floe_start_positions.is_empty():
			for floe in game.controller._floes:
				floe_start_positions.append(floe.body.global_position)
		if game.controller._time > 1.0:
			for index in 3:
				observed_floe_moved = observed_floe_moved or game.controller._floes[index].body.global_position.distance_to(floe_start_positions[index]) > 0.1
		observed_floe_fall = observed_floe_fall or game.ctx.alive.has(false)
	if game_id == "duo_clash":
		for slot in game.ctx.player_count():
			observed_duo_score = observed_duo_score or game.controller.team_score(slot % 2) > 0
			observed_duo_life_loss = observed_duo_life_loss or game.controller.lives(slot) < 2
			observed_duo_damage = observed_duo_damage or game.ctx.fighter(slot).damage_percent > 0.0
	if game_id == "bumper_bowl":
		var world: Dictionary = load("res://src/net/bumper_replica.gd").capture(game.controller) if host else game._network_replica.target.get("world", {})
		for serial in world.get("hits", []):
			observed_bumper_hit = observed_bumper_hit or int(serial) > 0
		if game.phase in [MatchPhase.P.PLAYING, MatchPhase.P.SUDDEN_DEATH]:
			for fighter in game.ctx.fighters:
				if not fighter.visible and not fighter.alive and game.ctx.is_alive(fighter.slot):
					bumper_waiting[fighter.slot] = true
				elif fighter.visible and fighter.alive and bumper_waiting.has(fighter.slot):
					observed_bumper_respawn = true
	if game_id == "duel_pit":
		for fighter in game.ctx.fighters:
			var lives: int = game.controller.lives(fighter.slot)
			observed_duel_damage = observed_duel_damage or fighter.damage_percent > 0.0
			observed_duel_life_loss = observed_duel_life_loss or lives < 3
			observed_duel_respawn = observed_duel_respawn or (lives > 0 and lives < 3 and fighter.alive and fighter.visible)
	if not host and game_id == "sweeper_storm":
		for fighter in game.ctx.fighters:
			observed_sweeper_hit = observed_sweeper_hit or fighter._stun > 0.0
	if game_id in ["gem_grab", "star_rush"]:
		for score in game.ctx.scores:
			observed_collection_score = observed_collection_score or score > 0
		for fighter in game.ctx.fighters:
			observed_carrying = observed_carrying or fighter.carrying > 0
	var slot := Net.local_slot()
	if game_id == "crate_relay" and slot >= 0:
		observed_collection_score = observed_collection_score or game.ctx.scores[slot] > 0
		observed_carrying = observed_carrying or game.ctx.fighters[slot].carrying > 0
	if game_id in ["crate_smash", "lab_crates"]:
		var world: Dictionary = load("res://src/net/crate_replica.gd").capture(game.controller, game_id == "lab_crates") if host else game._network_replica.target.get("world", {})
		observed_crate_break = observed_crate_break or int(world.get("break_sequence", 0)) > 0
		observed_lab_weapon = observed_lab_weapon or int(world.get("break_kind", 0)) >= 2
		observed_lab_shot = observed_lab_shot or not world.get("shots", []).is_empty()
		if slot >= 0:
			observed_crate_score = observed_crate_score or game.ctx.scores[slot] > 0
	if game_id == "symbol_echo":
		var serial: int = game.controller.sequence_serial()
		if serial != echo_serial:
			echo_serial = serial
			echo_cues.clear()
			echo_leaving = false
		var symbol: int = game.controller.visible_symbol()
		if symbol >= 0:
			echo_cues[game.controller.visible_step()] = symbol
			observed_echo_cue = true
		if slot >= 0:
			observed_echo_score = observed_echo_score or game.ctx.scores[slot] > 0
	if game_id == "quick_draw":
		observed_draw_signal = observed_draw_signal or game.controller.is_signalled()
		observed_draw_response = observed_draw_response or game.controller._order.has(slot)
	if game_id == "color_stand":
		observed_color_drop = observed_color_drop or game.controller.is_dropping()
	if game_id == "blast_ball":
		var ball: GameBall = game.controller.ball
		observed_blast_fuse = observed_blast_fuse or (ball.fuse > 0 and ball.fuse < ball.fuse_max - 0.5)
		var sequence: int = game.controller.explosion_sequence if host else int(game._network_replica.target.get("world", {}).get("explosion_sequence", 0))
		observed_blast_explosion = observed_blast_explosion or sequence > 0
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
		if game_id in ["kart_sprint", "sabaq_sawarikh"]:
			var fighter: Fighter = game.ctx.fighter(slot)
			var target: Vector3 = game.controller.next_checkpoint(slot)
			# Exercise actual fall/stall recovery through driving, not a teleported fixture.
			# A three-second steering window could end before the stall watchdog fired.
			if game_id == "kart_sprint" and slot == 0 and not observed_kart_rescue and game.controller._elapsed >= 2.0 and game.controller._elapsed < 18.0:
				target = fighter.global_position.normalized() * 40.0
			var direction := target - fighter.global_position
			var diff := wrapf(atan2(direction.x, direction.z) - atan2(fighter.facing.x, fighter.facing.z), -PI, PI)
			movement = Vector2(-clampf(diff * 1.8, -1.0, 1.0), -maxf(0.25, 1.0 - absf(diff) / PI * 1.1))
			if absf(diff) > 2.3 and fighter.speed_ratio() < 0.15:
				movement = Vector2(clampf(diff * 1.8, -1.0, 1.0), 0.85)
		var buttons := 0
		if game_id == "boss_colossus":
			var fighter: Fighter = game.ctx.fighter(slot)
			var plan: Dictionary = game.controller.attack_plan(fighter.global_position)
			var target: Vector3 = game.arena.retreat_point(fighter.global_position) if plan.is_empty() else plan.target
			var world := _colossus_world()
			for warning in world.get("warnings", []):
				var point := Vector3(warning.position[0], fighter.global_position.y, warning.position[2])
				if fighter.global_position.distance_to(point) < float(warning.radius) + 0.8:
					var away := fighter.global_position - point
					away.y = 0.0
					target = fighter.global_position + (away.normalized() if away.length() > 0.1 else Vector3.RIGHT) * 5.0
					break
			movement = _colossus_movement(fighter.global_position, target)
			if not plan.is_empty() and plan.attack and (Time.get_ticks_msec() - started_at) % 400 < 100:
				buttons = InputFrame.Btn.ATTACK
		if game_id == "boss_sovereign":
			var fighter: Fighter = game.ctx.fighter(slot)
			var world := _sovereign_world()
			var boss: Dictionary = world.get("boss", {})
			if boss.has("position"):
				var center := Vector3(boss.position[0], 0, boss.position[2])
				var angle := TAU * float(slot) / 4.0
				var target := center + Vector3(sin(angle), 0, cos(angle)) * 2.4
				var swing := not bool(world.get("shielded", false))
				if not swing:
					var nearest := INF
					for orb in world.get("orbs", []):
						if orb.returned: continue
						var point := Vector3(orb.position[0], 0, orb.position[2])
						var distance := fighter.global_position.distance_squared_to(point)
						if distance < nearest:
							nearest = distance
							target = point
							swing = true
				for warning in world.get("warnings", []):
					var point := Vector3(warning.position[0], 0, warning.position[2])
					if Vector2(point.x - fighter.global_position.x, point.z - fighter.global_position.z).length() < float(warning.radius) + 0.8:
						var away := fighter.global_position - point
						away.y = 0.0
						target = fighter.global_position + (away.normalized() if away.length() > 0.1 else Vector3(sin(angle), 0, cos(angle))) * 5.0
						swing = false
						break
				var direction := target - fighter.global_position
				direction.y = 0.0
				movement = Vector2(direction.x, direction.z).limit_length()
				if swing and direction.length() < 2.7 and (Time.get_ticks_msec() - started_at) % 500 < 120:
					buttons = InputFrame.Btn.ATTACK
		if game_id == "boss_dreadnought":
			var fighter: Fighter = game.ctx.fighter(slot)
			var world := _dread_world()
			var boss: Dictionary = world.get("boss", {})
			if boss.has("position") and boss.has("rotation"):
				var center := Vector3(boss.position[0], boss.position[1], boss.position[2])
				var back := Vector3(-sin(float(boss.rotation[1])), 0, -cos(float(boss.rotation[1])))
				var target := center + back * 4.5
				for warning in world.get("warnings", []):
					var point := Vector3(warning.position[0], warning.position[1], warning.position[2])
					if Vector2(point.x - fighter.global_position.x, point.z - fighter.global_position.z).length() < float(warning.radius) + 0.8:
						var away := fighter.global_position - point
						away.y = 0.0
						target = fighter.global_position + (away.normalized() if away.length() > 0.1 else back) * 5.0
						break
				var direction := target - fighter.global_position
				direction.y = 0.0
				movement = Vector2(direction.x, direction.z).limit_length()
				var vent := center + back * 3.6
				if Vector2(vent.x - fighter.global_position.x, vent.z - fighter.global_position.z).length() < 2.7 \
					and (Time.get_ticks_msec() - started_at) % 500 < 120:
					buttons = InputFrame.Btn.ATTACK
		if game_id == "boss_forge":
			var fighter: Fighter = game.ctx.fighter(slot)
			var world := _forge_world()
			var groups: Array = []
			for kind in ["slag", "crates"]:
				var points: Array = []
				for row in world.get(kind, []):
					points.append(Vector3(float(row.position[0]), float(row.position[1]), float(row.position[2])))
				groups.append(points)
			var plan: Dictionary = load("res://src/ai/forge_feeding_plan.gd").build(fighter.global_position,
				game.ctx.arena_center(), game.arena.current_radius, groups[0], groups[1])
			var target: Vector3 = plan.get("target", game.ctx.arena_center())
			var direction := target - fighter.global_position
			direction.y = 0.0
			movement = Vector2(direction.x, direction.z).limit_length(0.65 if plan.get("hot", false) else 1.0)
			if plan.get("attack", false) and (Time.get_ticks_msec() - started_at) % 500 < 120:
				buttons = InputFrame.Btn.ATTACK
		if game_id == "sabaq_sawarikh" and (Time.get_ticks_msec() - started_at) % 600 < 150:
			buttons = InputFrame.Btn.ATTACK
		if game_id == "base_siege":
			var fighter: Fighter = game.ctx.fighter(slot)
			if siege_target_slot < 0 or not game.ctx.is_alive(siege_target_slot) or game.controller.base_health(siege_target_slot) <= 0.0:
				siege_target_slot = -1
				siege_via_center = true
				var nearest := INF
				for other in game.ctx.player_count():
					if other == slot or not game.ctx.is_alive(other) or game.controller.base_health(other) <= 0.0:
						continue
					var position: Vector3 = game.controller.base_position(other)
					var distance: float = fighter.global_position.distance_squared_to(position)
					if distance < nearest:
						nearest = distance
						siege_target_slot = other
			var target: Vector3 = game.controller.base_position(siege_target_slot) if siege_target_slot >= 0 else fighter.global_position
			var center: Vector3 = game.ctx.arena_center()
			if Vector2(fighter.global_position.x - center.x, fighter.global_position.z - center.z).length() <= 1.5:
				siege_via_center = false
			# The authored pillars obstruct the straight diagonal to a rival base.
			var waypoint: Vector3 = center if siege_via_center else target
			var direction := waypoint - fighter.global_position
			direction.y = 0.0
			movement = Vector2(direction.x, direction.z).limit_length()
			var aim := target - fighter.global_position
			aim.y = 0.0
			if aim.length() <= 3.5 and fighter.facing.dot(aim.normalized()) > 0.3 and (Time.get_ticks_msec() - started_at) % 500 < 120:
				buttons = InputFrame.Btn.ATTACK
		if game_id == "fawda":
			var fighter: Fighter = game.ctx.fighter(slot)
			var target: Vector3 = game.arena.global_position
			var nearest := INF
			if fighter.carrying > 0:
				for other in game.ctx.fighters:
					var distance: float = fighter.global_position.distance_squared_to(other.global_position)
					if other.slot != slot and other.alive and other.visible and distance < nearest:
						nearest = distance
						target = other.global_position
			else:
				for bomb in _fawda_world().get("bombs", []):
					var position := Vector3(bomb.position[0], bomb.position[1], bomb.position[2])
					var velocity := Vector3(bomb.velocity[0], bomb.velocity[1], bomb.velocity[2])
					var distance: float = fighter.global_position.distance_squared_to(position)
					if int(bomb.held) < 0 and velocity.length_squared() <= 4.0 and distance < nearest:
						nearest = distance
						target = position
			var direction := target - fighter.global_position
			direction.y = 0.0
			movement = Vector2(direction.x, direction.z).limit_length()
			if fighter.carrying == 0 and nearest > 16.0 and nearest < INF \
				and fighter.can_afford_dash() and fighter._dash_cd <= 0.0 \
				and fighter.facing.dot(direction.normalized()) > 0.9:
				buttons = InputFrame.Btn.DASH
			if fighter.carrying > 0 and fighter.facing.dot(direction.normalized()) > 0.85 and (Time.get_ticks_msec() - started_at) % 600 < 150:
				buttons = InputFrame.Btn.ATTACK
		if game_id in ["turret_duel", "tank_arena", "scrap_karts"]:
			var fighter: Fighter = game.ctx.fighters[slot]
			var target: Vector3 = game.arena.global_position
			var distance := INF
			for other in game.ctx.fighters:
				if other.slot != slot and other.alive and other.visible:
					var d: float = fighter.global_position.distance_squared_to(other.global_position)
					if d < distance:
						distance = d
						target = other.global_position
			var to := target - fighter.global_position
			to.y = 0.0
			var combat_target := to
			if game_id == "tank_arena":
				if not observed_tank_inventory:
					var nearest := INF
					for crate in game.controller.crates:
						var d: float = fighter.global_position.distance_squared_to(crate.pos)
						if float(crate.cooldown) <= 0.0 and d < nearest:
							nearest = d
							target = crate.pos
				target = _tank_waypoint(fighter.global_position, target)
				to = target - fighter.global_position
				to.y = 0.0
			var desired := atan2(to.x, to.z)
			var current := atan2(fighter.facing.x, fighter.facing.z)
			var diff := wrapf(desired - current, -PI, PI)
			movement = Vector2(-clampf(diff * 1.8, -1.0, 1.0), -maxf(0.25, 1.0 - absf(diff) / PI))
			if to.length() < 8.0 and game_id == "turret_duel":
				movement.y = -0.2
			if fighter.facing.normalized().dot(combat_target.normalized()) > 0.9 and (Time.get_ticks_msec() - started_at) % 700 < 180:
				buttons = InputFrame.Btn.DASH if game_id == "scrap_karts" else InputFrame.Btn.ATTACK
		if game_id == "drift_floes":
			var fighter: Fighter = game.ctx.fighters[slot]
			var age := float(Time.get_ticks_msec() - started_at) * 0.001
			var radius := 3.0 if fmod(age, 15.0) < 8.0 else 20.0
			var angle := age * 0.4 + slot * TAU / 4.0
			var target: Vector3 = game.arena.global_position + Vector3(cos(angle), 0, sin(angle)) * radius
			movement = Vector2(target.x - fighter.global_position.x, target.z - fighter.global_position.z).limit_length()
		if game_id == "bumper_bowl":
			var fighter: Fighter = game.ctx.fighters[slot]
			var bumpers: Array = []
			for hazard in game.arena._hazards:
				if hazard is ArenaHazards.Bumper:
					bumpers.append(hazard)
			var target: Vector3 = bumpers[slot % bumpers.size()].global_position
			if (Time.get_ticks_msec() - started_at) % 20000 >= 12000:
				var angle := slot * TAU / 4.0
				target = game.arena.global_position + Vector3(cos(angle), 0, sin(angle)) * 20.0
			movement = Vector2(target.x - fighter.global_position.x, target.z - fighter.global_position.z).limit_length()
			if (Time.get_ticks_msec() - started_at) % 1400 < 180:
				buttons = InputFrame.Btn.DASH
		if game_id in ["duel_pit", "duo_clash"]:
			var fighter: Fighter = game.ctx.fighters[slot]
			var target: Vector3 = game.arena.global_position
			var distance := INF
			for other in game.ctx.fighters:
				if game_id == "duo_clash" and other.slot % 2 == slot % 2:
					continue
				if other.slot != slot and other.alive and other.visible:
					var d: float = fighter.global_position.distance_squared_to(other.global_position)
					if d < distance:
						distance = d
						target = other.global_position
			movement = Vector2(target.x - fighter.global_position.x, target.z - fighter.global_position.z).limit_length()
			if (Time.get_ticks_msec() - started_at) % 700 < 180:
				buttons = InputFrame.Btn.ATTACK
		if game_id == "rising_tide":
			# Circle on the base platform so rising water, not running off, ends the round.
			var fighter: Fighter = game.ctx.fighters[slot]
			var angle := float(Time.get_ticks_msec() - started_at) * 0.001 + slot * PI * 0.5
			var target: Vector3 = game.arena.global_position + Vector3(cos(angle) * 3.0, 0.0, sin(angle) * 3.0)
			movement = Vector2(target.x - fighter.global_position.x, target.z - fighter.global_position.z).limit_length()
		if game_id == "hurdle_dash":
			var fighter: Fighter = game.ctx.fighters[slot]
			movement = Vector2(clampf((game.arena.global_position.x + game.arena.lane_x(slot) - fighter.global_position.x) * 2.0, -1.0, 1.0), -1.0)
			var origin := fighter.global_position + Vector3.UP * 0.4
			var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.FORWARD * 3.0, 1)
			# A held jump that starts airborne has no new edge upon landing.
			if not fighter.get_world_3d().direct_space_state.intersect_ray(query).is_empty() and (Time.get_ticks_msec() - started_at) % 500 < 160:
				buttons = InputFrame.Btn.JUMP
		if game_id in ["crate_smash", "lab_crates"]:
			movement = _crate_movement(slot)
			if crate_attack_clock < 0.2:
				buttons = InputFrame.Btn.ATTACK
		if game_id == "symbol_echo":
			movement = _echo_movement(slot)
		if game_id == "quick_draw":
			movement = Vector2.ZERO
			if game.controller.is_signalled() and not game.controller.is_locked(slot) and not game.controller._order.has(slot) and draw_tap_sequence != game.controller.signal_sequence:
				draw_tap_sequence = game.controller.signal_sequence
				buttons = InputFrame.Btn.ATTACK
		if game_id == "color_stand":
			var fighter: Fighter = game.ctx.fighters[slot]
			var safe: ArenaTile = game.controller.safe_tile_near(fighter.global_position)
			if safe != null:
				var offset: Vector3 = safe.global_position - fighter.global_position
				movement = Vector2(offset.x, offset.z).limit_length()
		if game_id == "blast_ball":
			var angle := float(Time.get_ticks_msec() - started_at) / 2400.0 + slot * PI / 2.0
			var target: Vector3 = game.arena.global_position + Vector3(cos(angle), 0, sin(angle)) * 3.0
			var direction: Vector3 = target - game.ctx.fighters[slot].global_position
			movement = Vector2(direction.x, direction.z).limit_length()
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
			var frame: InputFrame = load("res://tests/zone_peer_driver.gd").input(game.arena,
				game.ctx.fighters, slot, game.controller.zone_position, game.controller.zone_radius,
				Time.get_ticks_msec() - started_at)
			movement = frame.move
			buttons = frame.bits
		if game_id in ["gem_grab", "star_rush", "crate_relay"]:
			movement = _collection_movement(slot)
			if game_id == "gem_grab" and (Time.get_ticks_msec() / 500) % 2 == 0:
				buttons = InputFrame.Btn.JUMP
		InputRouter.push_virtual(slot, movement, Vector2.ZERO, buttons)
		moved = moved or game.ctx.fighters[slot].global_position.distance_to(initial_positions[slot]) > 0.3
	if not host and Net.local_peer_id == 2 and snapshots >= 8 and not disconnected_once:
		disconnected_once = true
		before_id = Net.local_peer_id
		Net.transport.socket.close()


func _fawda_world() -> Dictionary:
	if host:
		return load("res://src/net/fawda_replica.gd").capture(game.controller)
	return game._network_replica.target.get("world", {})


func _observe_fawda_pickup(world: Dictionary) -> void:
	# Bounded read-only diagnostics; never move a fighter or alter bomb rules.
	fawda_pickup_probe.samples += 1
	for bomb in world.get("bombs", []):
		var velocity := Vector3(bomb.velocity[0], bomb.velocity[1], bomb.velocity[2])
		if int(bomb.held) >= 0 or velocity.length_squared() > 4.0:
			continue
		fawda_pickup_probe.slow_loose_observations += 1
		var position := Vector3(bomb.position[0], bomb.position[1], bomb.position[2])
		for fighter in game.ctx.fighters:
			if not game.ctx.is_alive(fighter.slot) or fighter.carrying > 0:
				continue
			var distance: float = fighter.global_position.distance_to(position)
			if distance <= 1.6:
				fawda_pickup_probe.in_range_pairs += 1
			if float(fawda_pickup_probe.minimum_distance) < 0.0 or distance < float(fawda_pickup_probe.minimum_distance):
				fawda_pickup_probe.minimum_distance = distance
				fawda_pickup_probe.closest = {"slot": fighter.slot, "bomb": bomb.id,
					"round": game._round_index, "fuse": bomb.fuse,
					"fighter": [fighter.global_position.x, fighter.global_position.y, fighter.global_position.z],
					"position": bomb.position.duplicate()}


func _tank_waypoint(origin: Vector3, target: Vector3) -> Vector3:
	if tank_route.is_empty() or target.distance_to(tank_route_target) > 6.0:
		tank_route = game.controller.world.route(origin, target)
		tank_route_target = target
	while not tank_route.is_empty() and origin.distance_to(tank_route[0]) < 3.0:
		tank_route.remove_at(0)
	return target if tank_route.is_empty() else tank_route[0]


func _collection_movement(slot: int) -> Vector2:
	var fighter: Fighter = game.ctx.fighters[slot]
	var target: Vector3 = fighter.global_position
	if game_id in ["star_rush", "crate_relay"] and fighter.carrying > 0:
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
	if game_id == "crate_relay":
		for step in range(1, 11):
			if not game.arena.is_inside(fighter.global_position.lerp(target, step / 10.0), 0.65):
				target = game.arena.global_position
				break
	var direction := target - fighter.global_position
	return Vector2(direction.x, direction.z).limit_length()


func _crate_movement(slot: int) -> Vector2:
	var position: Vector3 = game.ctx.fighters[slot].global_position
	var candidates: Array = []
	if host:
		for entry in game.controller._crates:
			candidates.append({"position": entry.node.global_position, "kind": 2 if entry.get("weapon", false) else (1 if entry.bomb else 0)})
	elif is_instance_valid(game._network_replica._crates):
		for view in game._network_replica._crates.crates.values():
			candidates.append({"position": view.global_position, "kind": view.get_meta("kind")})
	var target: Vector3 = game.ctx.arena_center()
	var best := INF
	for entry in candidates:
		var cost: float = position.distance_squared_to(entry.position)
		if entry.kind == 1:
			cost += 1000.0
		elif entry.kind == 2:
			cost -= 1000.0
		if cost < best:
			best = cost
			target = entry.position
	return Vector2(target.x - position.x, target.z - position.z).limit_length()


func _echo_movement(slot: int) -> Vector2:
	var position: Vector3 = game.ctx.fighters[slot].global_position
	var center: Vector3 = game.ctx.arena_center()
	var target := center
	var progress: int = game.controller.progress_of(slot)
	if echo_leaving and Vector2(position.x - center.x, position.z - center.z).length() < 1.5:
		echo_leaving = false
	if game.controller.accepts_sequence_input() and echo_cues.has(progress):
		var pad: int = echo_cues[progress]
		if game.controller.current_pad(slot) == pad:
			echo_leaving = true
		if not echo_leaving:
			target = game.controller.pad_position(pad)
	return Vector2(target.x - position.x, target.z - position.z).limit_length()


func _forge_world() -> Dictionary:
	return load("res://src/net/forge_replica.gd").capture(game.controller) if host else game._network_replica.target.get("world", {})


func _dread_world() -> Dictionary:
	return load("res://src/net/dreadnought_replica.gd").capture(game.controller) if host else game._network_replica.target.get("world", {})


func _sovereign_world() -> Dictionary:
	return load("res://src/net/sovereign_replica.gd").capture(game.controller) if host else game._network_replica.target.get("world", {})


func _colossus_world() -> Dictionary:
	return load("res://src/net/colossus_replica.gd").capture(game.controller) if host else game._network_replica.target.get("world", {})


func _colossus_movement(from: Vector3, target: Vector3) -> Vector2:
	var direction := target - from
	direction.y = 0.0
	if direction.length() < 0.15: return Vector2.ZERO
	var floor: Node = game.arena._crater_floor
	if not is_instance_valid(floor): return Vector2.ZERO
	var local_from: Vector3 = from - game.arena.global_position
	var best: Vector3 = floor.steering_direction(local_from, target - game.arena.global_position)
	return Vector2(best.x, best.z) * minf(1.0, direction.length())


func _finished(result: MatchResult) -> void:
	var contenders: Array = game.config.rule("online_contenders", [])
	var spectator := not contenders.is_empty() and not contenders.has(Net.local_slot())
	print("NETWORK_ROUND=" + JSON.stringify({"epoch": Net.epoch, "game": game.config.minigame_id,
		"arena": game.config.arena_id, "scores": result.scores, "spectator": spectator, "moved": moved}))
	if spectator and game.ctx.is_alive(Net.local_slot()):
		_fail("spectator remained active")
		return
	if not moved and not spectator and game_id != "quick_draw":
		_fail("player did not move")
		return
	if not host and snapshots < 5:
		_fail("no snapshots")
		return
	if game_id == "boss_colossus":
		for round in range(game._round_index + 1):
			if not colossus_damage_by_round.has(round) or (contenders.is_empty() and (
				not colossus_crater_by_round.has(round) or not colossus_strike_by_round.has(round)
				or not colossus_defeat_by_round.has(round))):
				print("NETWORK_COLOSSUS_FAILURE=" + JSON.stringify({"round": round, "host": host, "world": _colossus_world()}))
				_fail("colossus round %d lacks actual damage, crater, strike or defeat" % round)
				return
		if not host:
			var world := _colossus_world()
			if world_snapshots < 5 or world.is_empty() or not game.controller.presentation_only:
				_fail("colossus world missing or guest remained authoritative")
				return
			for frame in 30: game._network_replica.render(game, 0.016)
			if not game.controller._craters.is_empty() or not game.controller._telegraphs.is_empty() \
				or game.arena._crater_floor._body != null or absf(game.controller.boss_health - float(world.boss.health)) > 0.001:
				_fail("colossus guest simulated craters or diverged from host health")
				return
	if game_id == "boss_sovereign":
		for round in range(game._round_index + 1):
			if not sovereign_damage_by_round.has(round) or (contenders.is_empty() and (
				not sovereign_orbs_by_round.has(round) or not sovereign_return_by_round.has(round)
				or not sovereign_shield_by_round.has(round) or not sovereign_defeat_by_round.has(round))):
				_fail("sovereign round %d lacks real damage, orb return, shield or defeat" % round)
				return
		if not host:
			var world := _sovereign_world()
			if world_snapshots < 5 or world.is_empty() or not game.controller.presentation_only:
				_fail("sovereign world missing or guest remained authoritative")
				return
			for frame in 30: game._network_replica.render(game, 0.016)
			if not game.controller._orbs.is_empty() or not game.controller._shots.is_empty() or not game.controller._telegraphs.is_empty() \
				or absf(game.controller.boss_health - float(world.boss.health)) > 0.001:
				_fail("sovereign guest simulated objects or diverged from health")
				return
	if game_id == "boss_dreadnought":
		for round in range(game._round_index + 1):
			if not dread_damage_by_round.has(round) or not dread_shot_by_round.has(round) \
				or (contenders.is_empty() and not dread_defeat_by_round.has(round)):
				print("NETWORK_DREAD_FAILURE=" + JSON.stringify({"round": round, "host": host,
					"boss": _dread_world().get("boss", {}), "damage": dread_damage_by_round,
					"shots": dread_shot_by_round, "defeats": dread_defeat_by_round}))
				_fail("dreadnought round %d lacks actual damage, shells or boss defeat" % round)
				return
		if not host:
			var world := _dread_world()
			if world_snapshots < 5 or world.is_empty() or not game.controller.presentation_only:
				_fail("dreadnought world missing or guest remained authoritative")
				return
			for frame in 30: game._network_replica.render(game, 0.016)
			if not game.controller._mines.is_empty() or not game.controller._shots.is_empty() or not game.controller._telegraphs.is_empty() \
				or absf(game.controller.boss_health - float(world.boss.health)) > 0.001:
				_fail("dreadnought guest simulated objects or diverged from health")
				return
	if game_id == "boss_forge":
		for round in range(game._round_index + 1):
			if not forge_damage_by_round.has(round) or not forge_slag_by_round.has(round) or not forge_strike_by_round.has(round):
				_fail("forge round %d lacks real intake damage, crate break or strike" % round)
				return
			if contenders.is_empty() and not forge_defeat_by_round.has(round):
				_fail("forge round %d did not defeat the real boss within authored duration" % round)
				return
		if not host:
			var world := _forge_world()
			if world_snapshots < 5 or world.is_empty() or not game.controller.presentation_only:
				_fail("forge world missing or guest remained authoritative")
				return
			for frame in 30: game._network_replica.render(game, 0.016)
			if not game.controller._crates.is_empty() or not game.controller._slag.is_empty() or not game.controller._telegraphs.is_empty() \
					or absf(game.controller.boss_health - float(world.boss.health)) > 0.001:
				_fail("forge guest simulated physical objects or diverged from health")
				return
	if game_id == "base_siege":
		var evidence = preload("res://tests/network_smoke_config.gd")
		if not evidence.siege_evidence(observed_siege_hit, observed_siege_destroyed, contenders, result.scores):
			_fail("siege ordinary destruction or final contender damage/score evidence missing")
			return
		for round in range(game._round_index + 1):
			if not evidence.siege_evidence(siege_hits_by_round.has(round), siege_destruction_by_round.has(round), contenders, result.scores):
				_fail("siege round %d lacks ordinary destruction or final contender damage/score" % round)
				return
		if not host:
			var world: Dictionary = game._network_replica.target.get("world", {})
			if world_snapshots < 5 or world.is_empty() or not game.controller.presentation_only:
				_fail("siege world missing or guest remained authoritative")
				return
			for frame in 30: game._network_replica.render(game, 0.016)
			for slot in game.ctx.player_count():
				var base: Dictionary = game.controller._bases[slot]
				var row: Dictionary = world.bases[slot]
				if base.body.collision_layer != 0 or absf(base.health - float(row.health)) > 0.001 \
					or base.hits != int(row.hits) or base.node.visible != (float(row.health) > 0.0):
					_fail("siege crystal baseline or collision diverged")
					return
	if game_id in ["kart_sprint", "sabaq_sawarikh"]:
		if contenders.is_empty() and (not observed_kart_boost or (game_id == "kart_sprint" and not observed_kart_rescue)):
			_fail("physical race boost/rescue evidence missing: %s %s" % [observed_kart_boost, observed_kart_rescue])
			return
		if game_id == "sabaq_sawarikh" and contenders.is_empty() and (not observed_armed_pickup or not observed_armed_weapon):
			_fail("armed race pickup/weapon evidence missing")
			return
		for slot in count:
			if not contenders.is_empty() and not contenders.has(slot): continue
			if game.controller.lap[slot] != game.controller.laps():
				_fail("human race ended before required laps: slot=%s lap=%s target=%s" % [slot, game.controller.lap[slot], game.controller.laps()])
				return
		if not host:
			var world: Dictionary = game._network_replica.target.get("world", {})
			if game_id == "sabaq_sawarikh":
				if not game.controller._bombs.is_empty() or not game.controller._missiles.is_empty():
					_fail("guest simulated live race weapons")
					return
				world = world.get("race", {})
			if world.is_empty() or not game.controller._recoveries.is_empty():
				_fail("race world missing or guest ran live rescue rules")
				return
			for slot in game.ctx.player_count():
				if game.controller.lap[slot] != int(world.lap[slot]) or game.controller.finish_times[slot] != int(world.times[slot]):
					_fail("race host lap/time presentation diverged")
					return
	if game_id == "fawda":
		print("NETWORK_FAWDA_PICKUP=" + JSON.stringify({"host": host,
			"arena": game.config.arena_id, "seed": game.config.seed,
			"observed_events": observed_fawda_events, "probe": fawda_pickup_probe}))
		for kind in ["drop", "pickup", "throw", "explode"]:
			if not observed_fawda_events.has(kind):
				_fail("fawda real event missing: " + kind)
				return
		if not host:
			var world := _fawda_world()
			if world_snapshots < 5 or world.is_empty() or not is_instance_valid(game._network_replica._fawda) or not game.controller._bombs.is_empty():
				_fail("fawda world missing or guest simulated live bombs")
				return
			for frame in 30: game._network_replica.render(game, 0.016)
			var views: Dictionary = game._network_replica._fawda.views
			if views.size() != world.bombs.size():
				_fail("fawda bomb count diverged")
				return
			for bomb in world.bombs:
				var id := int(bomb.id)
				var position := Vector3(bomb.position[0], bomb.position[1], bomb.position[2])
				if not views.has(id) or views[id].node.global_position.distance_to(position) > 0.001 or absf(views[id].wick.scale.y - maxf(0.05, float(bomb.fuse) / 5.0)) > 0.001:
					_fail("fawda position or fuse visual diverged")
					return
			for slot in game.ctx.player_count():
				if game.ctx.fighter(slot).carrying != int(world.carrying[slot]):
					_fail("fawda carrying state diverged")
					return
	if game_id == "scrap_karts":
		if not observed_scrap_ram or not observed_scrap_damage:
			_fail("scrap collision/damage evidence missing: %s %s" % [observed_scrap_ram, observed_scrap_damage])
			return
		if not host:
			var world: Dictionary = game._network_replica.target.get("world", {})
			if world_snapshots < 5 or world.is_empty() or not game.controller._hit_cooldown.is_empty():
				_fail("scrap world missing or guest resolved its own collision")
				return
			for frame in 30:
				game._network_replica.render(game, 0.016)
			if game.controller.ram_serial != int(world.ram):
				_fail("scrap impact baseline diverged")
				return
			for slot in game.ctx.player_count():
				if absf(game.controller.health[slot] - float(world.health[slot])) > 0.001 or game.controller.wrecks[slot] != int(world.wrecks[slot]):
					_fail("scrap health or wreck baseline diverged")
					return
	if game_id in ["turret_duel", "tank_arena"] and not host:
		var world: Dictionary = game._network_replica.target.get("world", {})
		var view = game._network_replica._tank if game_id == "tank_arena" else game._network_replica._turret
		if world_snapshots < 5 or world.is_empty() or not is_instance_valid(view) or not game.controller._shots.is_empty():
			_fail("missing turret world or guest simulated its own shots")
			return
		for frame in 30:
			game._network_replica.render(game, 0.016)
		if view.shots.size() != world.shots.size():
			_fail("turret projectile count diverged")
			return
		for row in world.shots:
			var key: String = row.id + ":" + str(int(row.generation))
			var p: Array = row.position
			if not view.shots.has(key) or view.shots[key].global_position.distance_to(Vector3(p[0], p[1], p[2])) > 0.001:
				_fail("turret launch generation or position diverged")
				return
		for slot in game.ctx.player_count():
			if absf(game.controller._cooldowns[slot] - float(world.cooldowns[slot])) > 0.001 or absf(game.ctx.fighter(slot).damage_percent - float(world.damage[slot])) > 0.001:
				_fail("turret cooldown or damage diverged")
				return
			if game_id == "tank_arena" and (game.controller.armor[slot] != int(world.armor[slot]) or game.controller.ammo[slot] != int(world.ammo[slot]) or game.controller.shell_types[slot] != int(world.shell_types[slot])):
				_fail("ATV armor or inventory diverged")
				return
		if game_id == "tank_arena":
			for index in game.controller.crates.size():
				var crate: Dictionary = game.controller.crates[index]
				var row: Dictionary = world.crates[index]
				if absf(crate.cooldown - float(row.cooldown)) > 0.001 or crate.node.visible != (float(row.cooldown) <= 0.0) or absf(crate.node.rotation.y - float(row.rotation)) > 0.001:
					_fail("ATV refill crate diverged")
					return
			for row in world.shots:
				var key: String = row.id + ":" + str(int(row.generation))
				if int(view.shots[key].get_meta("kind")) != int(row.kind) or absf(float(view.shots[key].get_meta("fuse")) - float(row.fuse)) > 0.001:
					_fail("ATV shell type or fuse diverged")
					return
	if game_id == "drift_floes":
		if not observed_floe_moved or not observed_floe_fall:
			_fail("moving floe/fall evidence missing")
			return
		if not host:
			var world: Dictionary = game._network_replica.target.get("world", {})
			if world_snapshots < 5 or world.is_empty():
				_fail("missing moving floe snapshots")
				return
			for frame in 30:
				game._network_replica.render(game, 0.016)
			for index in 3:
				var body: AnimatableBody3D = game.controller._floes[index].body
				var p: Array = world.positions[index]
				if body.global_position.distance_to(Vector3(p[0], p[1], p[2])) > 0.001 or body.sync_to_physics or body.collision_layer != 0:
					_fail("guest floe transform/physics diverged")
					return
			if absf(game.controller._time - float(world.age)) > 0.001:
				_fail("guest floe clock diverged")
				return
	if game_id == "duo_clash" and not host:
		var world: Dictionary = game._network_replica.target.get("world", {})
		if world_snapshots < 5 or world.is_empty() or world.arena != game.config.arena_id:
			_fail("missing or wrong-arena duo world")
			return
		for slot in game.ctx.player_count():
			if game.controller.lives(slot) != int(world.lives[slot]) or game.controller.team_score(slot % 2) != int(world.team_scores[slot % 2]) or absf(game.ctx.fighter(slot).damage_percent - float(world.damage[slot])) > 0.001:
				_fail("duo HUD diverged from host")
				return
		var index := 0
		for hazard in game.arena._hazards:
			if hazard is ArenaHazards.Sweeper:
				if absf(angle_difference(hazard.rotation.y, float(world.hazards.angles[index]))) > 0.001:
					_fail("duo sweeper transform diverged")
					return
				index += 1
			elif hazard is ArenaHazards.Bumper:
				var s: Array = world.hazards.scales[index]
				if not hazard._mesh.scale.is_equal_approx(Vector3(s[0], s[1], s[2])):
					_fail("duo bumper transform diverged")
					return
				index += 1
		if index != (3 if game.config.arena_id == "sweeper_ring" else 5):
			_fail("missing duo arena hazards")
			return
	if game_id == "bumper_bowl" and not host:
		var world: Dictionary = game._network_replica.target.get("world", {})
		if world_snapshots < 5 or world.is_empty():
			_fail("missing bumper world")
			return
		var index := 0
		for hazard in game.arena._hazards:
			if hazard is ArenaHazards.Bumper:
				var s: Array = world.scales[index]
				if not hazard._mesh.scale.is_equal_approx(Vector3(float(s[0]), float(s[1]), float(s[2]))):
					_fail("bumper deformation diverged")
					return
				index += 1
		if index != 5:
			_fail("missing authored bumpers")
			return
	if game_id == "duel_pit" and not host:
		var world: Dictionary = game._network_replica.target.get("world", {})
		if world_snapshots < 5 or world.is_empty():
			_fail("missing duel world")
			return
		for slot in game.ctx.player_count():
			if game.controller.lives(slot) != int(world.lives[slot]) or absf(game.ctx.fighter(slot).damage_percent - float(world.damage[slot])) > 0.001:
				_fail("duel lives or damage diverged")
				return
	if game_id == "sweeper_storm":
		var angles: Array = []
		for hazard in game.arena._hazards:
			if hazard is ArenaHazards.Sweeper:
				angles.append(hazard.rotation.y)
				if host and hazard._age <= 0.0:
					_fail("sweeper never advanced")
					return
		if angles.size() != 3:
			_fail("missing sweeper arms")
			return
		if not host:
			var world: Dictionary = game._network_replica.target.get("world", {})
			if world_snapshots < 5 or world.is_empty():
				_fail("missing sweeper snapshots")
				return
			for i in angles.size():
				if absf(angle_difference(float(angles[i]), float(world.angles[i]))) > 0.001:
					_fail("sweeper angle diverged")
					return
	if game_id == "rising_tide":
		if game.arena.water_level() <= 0.0 or not game.ctx.alive.has(false):
			_fail("tide did not rise and eliminate a runner")
			return
		if host and game.arena._water._hit.is_empty():
			_fail("no authoritative submersion occurred")
			return
		if not host:
			var world: Dictionary = game._network_replica.target.get("world", {})
			if world_snapshots < 5 or world.is_empty() or absf(game.arena.water_level() - float(world.level)) > 0.001:
				_fail("tide level diverged from host")
				return
	if game_id == "hurdle_dash":
		for slot in game.ctx.player_count():
			if game.ctx.is_alive(slot) and game.controller.finish_times[slot] == game.controller.UNFINISHED:
				_fail("active hurdle runner did not reach the finish")
				return
		var best: int = result.scores.min()
		for winner in result.winners():
			if result.scores[winner] != best:
				_fail("hurdle results do not rank lowest time first")
				return
		if not host:
			var world: Dictionary = game._network_replica.target.get("world", {})
			if world_snapshots < 5 or world.is_empty() or absf(game.controller._elapsed - float(world.elapsed)) > 0.001:
				_fail("missing hurdle clock")
				return
			for slot in game.ctx.player_count():
				if game.controller.finish_times[slot] != int(world.times[slot]):
					_fail("hurdle finish times diverged")
					return
	if not host and game_id in ["crate_smash", "lab_crates"]:
		var world: Dictionary = game._network_replica.target.get("world", {})
		var view = game._network_replica._crates
		if world_snapshots < 5 or world.is_empty() or not is_instance_valid(view):
			_fail("missing crate world")
			return
		if not game.controller._crates.is_empty() or view.crates.size() != world.crates.size() or view.shots.size() != world.shots.size():
			_fail("crate world diverged or procedural crates retained")
			return
		for row in world.crates:
			if not view.crates.has(row.id) or view.crates[row.id].get_meta("kind") != int(row.kind) or view.crates[row.id].global_position.distance_to(Vector3(row.position[0], row.position[1], row.position[2])) > 0.001:
				_fail("crate position or type diverged")
				return
	if not host and game_id == "symbol_echo":
		var world: Dictionary = game._network_replica.target.get("world", {})
		if world_snapshots < 5 or world.is_empty() or world.has("sequence") or not game.controller._sequence.is_empty():
			_fail("missing echo state or private answers retained")
			return
		if game.controller._stage != int(world.stage) or game.controller.sequence_serial() != int(world.serial):
			_fail("echo phase diverged")
			return
		for player_slot in world.progress.size():
			if game.controller.progress_of(player_slot) != int(world.progress[player_slot]) or game.controller.mistakes_of(player_slot) != int(world.mistakes[player_slot]):
				_fail("echo progress diverged")
				return
	if not host and game_id == "quick_draw":
		var world: Dictionary = game._network_replica.target.get("world", {})
		if world_snapshots < 5 or world.is_empty() or world.has("timer") or world.has("signal_age"):
			_fail("missing draw world or hidden timing published")
			return
		var host_order: Array[int] = []
		for player_slot in world.order:
			host_order.append(int(player_slot))
		if game.controller._stage != int(world.stage) or game.controller._round_no != int(world.prompt) \
				or game.controller._order != host_order:
			_fail("draw prompt or response order diverged: local=%s/%s/%s host=%s/%s/%s" % [game.controller._stage, game.controller._round_no, game.controller._order, world.stage, world.prompt, world.order])
			return
		for player_slot in world.locked.size():
			if game.controller.is_locked(player_slot) != bool(world.locked[player_slot]):
				_fail("draw false-start state diverged")
				return
	if not host and game_id == "color_stand":
		var world: Dictionary = game._network_replica.target.get("world", {})
		if world_snapshots < 5 or world.is_empty():
			_fail("missing color world")
			return
		if game.controller._called != int(world.called) or game.controller._stage != int(world.stage) \
				or absf(game.controller._timer - float(world.timer)) > 0.001:
			_fail("color call diverged")
			return
		for i in game.arena.tiles.size():
			var tile: ArenaTile = game.arena.tiles[i]
			if tile.tag != game.controller.COLOR_NAMES[int(world.colors[i])] \
					or tile.state != int(world.tiles[i][0]) or absf(tile.position.y - float(world.tiles[i][2])) > 0.001 \
					or tile.collision_layer != 0:
				_fail("color floor diverged")
				return
	if not host and game_id == "blast_ball":
		var world: Dictionary = game._network_replica.target.get("world", {})
		var ball: GameBall = game.controller.ball
		if world_snapshots < 5 or world.is_empty():
			_fail("missing blast world")
			return
		if absf(ball.fuse - float(world.fuse)) > 0.001 or ball.launch_generation != int(world.generation) \
				or ball.detonated != bool(world.detonated) or ball.collision_mask != 0:
			_fail("blast ball presentation diverged")
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
	if not host and game_id in ["gem_grab", "star_rush", "crate_relay"]:
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
		if game_id == "crate_relay":
			for slot in game.ctx.player_count():
				if game.controller._carry_marks.has(slot) != (int(world.carrying[slot]) > 0):
					_fail("relay cargo visual diverged")
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
	if host and observed_remote_input_slots.size() < count - 1:
		_fail("missing remote inputs")
		return
	if game_id == "tank_arena" and (not observed_turret_shot or not observed_tank_armor or not observed_tank_inventory):
		_fail("ATV shot/armor/inventory evidence missing: %s %s %s" % [observed_turret_shot, observed_tank_armor, observed_tank_inventory])
		return
	finished_matches += 1
	if tournament_mode and not bool(Net.tournament.get("complete", false)):
		call_deferred("_continue_tournament")
		return
	if requested_game_id == "drift_floes" and tournament_mode and floe_arenas_seen.size() != 2:
		_fail("floe tournament did not visit both arenas")
		return
	if game_id in ["gem_grab", "star_rush", "crate_relay"] and not observed_collection_score:
		_fail("collection scoring observation missing: slot=%s scores=%s carrying_seen=%s" % [Net.local_slot(), result.scores, observed_carrying])
		return
	if game_id in ["star_rush", "crate_relay"] and not observed_carrying:
		_fail("carrying was never observed")
		return
	if game_id == "zone_hold" and not observed_zone_score:
		_fail("zone finished without capture scoring")
		return
	if game_id == "turret_duel" and (not observed_turret_shot or not observed_turret_damage or not observed_turret_score):
		_fail("turret shot/damage/score evidence missing: %s %s %s" % [observed_turret_shot, observed_turret_damage, observed_turret_score])
		return
	if requested_game_id == "tank_arena" and tournament_mode and tank_arenas_seen.size() != 3:
		_fail("ATV tournament did not visit all three authored arenas")
		return
	if requested_game_id == "fawda" and tournament_mode and fawda_arenas_seen.size() != 2:
		_fail("fawda tournament did not visit both authored arenas")
		return
	if requested_game_id == "base_siege" and tournament_mode and siege_arenas_seen.size() != 2:
		_fail("siege tournament did not visit both authored arenas")
		return
	if siege_tiebreak:
		var totals_unchanged := observed_siege_final and siege_final_cups.size() == 4
		for slot in 4:
			totals_unchanged = totals_unchanged and int(Net.tournament.points[slot]) == 3 \
				and int(Net.tournament.cups[slot]) == int(siege_final_cups[slot]) and int(Net.tournament.awards[slot]) == 0
		if not totals_unchanged or int(Net.tournament.tie_attempts) == 0:
			_fail("siege final did not run or changed tournament awards")
			return
	if forge_tiebreak or dread_tiebreak or sovereign_tiebreak:
		var totals_unchanged := observed_boss_final and boss_final_cups.size() == 4
		for slot in 4:
			totals_unchanged = totals_unchanged and int(Net.tournament.points[slot]) == 3 \
				and int(Net.tournament.cups[slot]) == int(boss_final_cups[slot]) and int(Net.tournament.awards[slot]) == 0
		if not totals_unchanged or int(Net.tournament.tie_attempts) == 0:
			_fail("boss final did not run or changed tournament awards")
			return
	if race_tiebreak:
		var totals_unchanged := observed_kart_final and kart_final_cups.size() == 4
		for slot in 4:
			totals_unchanged = totals_unchanged and int(Net.tournament.points[slot]) == 3 and int(Net.tournament.cups[slot]) == int(kart_final_cups[slot])
		if not totals_unchanged or int(Net.tournament.tie_attempts) == 0:
			_fail("race final did not run or changed ordinary tournament awards")
			return
	if game_id == "sweeper_storm" and not observed_sweeper_hit:
		_fail("no sweeper collision feedback observed")
		return
	if game_id == "bumper_bowl" and (not observed_bumper_hit or not observed_bumper_respawn):
		_fail("bumper collision/respawn evidence missing: %s %s" % [observed_bumper_hit, observed_bumper_respawn])
		return
	if game_id == "duel_pit" and requested_game_id != "duo_clash" and (not observed_duel_damage or not observed_duel_life_loss or not observed_duel_respawn):
		_fail("duel combat/life/respawn evidence missing: %s %s %s" % [observed_duel_damage, observed_duel_life_loss, observed_duel_respawn])
		return
	if requested_game_id == "duo_clash":
		if not observed_duo_score or not observed_duo_life_loss or not observed_duo_damage:
			_fail("duo team score/life/damage evidence missing")
			return
		if tournament_mode and duo_arenas_seen.size() != 2:
			_fail("duo tournament did not visit both authored arenas")
			return
		if duo_tiebreak:
			var final_points: Array = Net.tournament.get("points", [])
			var final_cups: Array = Net.tournament.get("cups", [])
			var totals_unchanged := final_points.size() == 4 and final_cups.size() == 4 and duo_final_cups.size() == 4
			if totals_unchanged:
				for slot in range(4):
					totals_unchanged = totals_unchanged and float(final_points[slot]) == 3.0 and float(final_cups[slot]) == float(duo_final_cups[slot])
			if not observed_duo_final or not totals_unchanged:
				_fail("duo final did not run or changed points/cups: observed=%s points=%s cups=%s baseline=%s" % [observed_duo_final, final_points, final_cups, duo_final_cups])
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
	if game_id == "blast_ball" and (not observed_blast_fuse or not observed_blast_explosion):
		_fail("blast fuse/explosion observation missing: fuse=%s explosion=%s sequence=%s" % [observed_blast_fuse, observed_blast_explosion, game.controller.explosion_sequence])
		return
	if game_id == "color_stand" and not observed_color_drop:
		_fail("color floor never dropped")
		return
	if game_id == "quick_draw" and (not observed_draw_signal or not observed_draw_response):
		_fail("draw never signalled or accepted this player's response")
		return
	if game_id == "symbol_echo" and (not observed_echo_cue or not observed_echo_score):
		_fail("echo never displayed a cue or accepted this player's observed answer")
		return
	if game_id in ["crate_smash", "lab_crates"] and (not observed_crate_break or not observed_crate_score):
		_fail("crate break or scoring was never observed")
		return
	if game_id == "lab_crates" and (not observed_lab_weapon or not observed_lab_shot):
		var lab_world: Dictionary = load("res://src/net/crate_replica.gd").capture(game.controller, true) if host else game._network_replica.target.get("world", {})
		_fail("lab weapon or volley was never observed: weapon=%s shot=%s events=%s" % [observed_lab_weapon, observed_lab_shot, JSON.stringify(lab_world.get("break_events", []))])
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
