extends Screen
## Room UI consumes server state; no simulated peers or local pseudo-room codes.
var _status: Label
var _rooms: Array = []
var _name := "Player"
var _refresh_pending := false
var _pending_match: MatchConfig
var _pending_epoch := 0
var _pending_room := ""


func build() -> void:
	title(Loc.t("online.title"))
	Net.room_updated.connect(_schedule_refresh)
	Net.rooms_received.connect(func(rooms):
		_rooms = rooms
		_schedule_refresh())
	Net.online_error.connect(func(code):
		if is_instance_valid(_status):
			_status.text = Loc.t("online.version_mismatch" if code == "version_mismatch" else "online.failed"))
	Net.connection_lost.connect(func(_reason): _schedule_refresh())
	Net.match_start_requested.connect(_request_match)
	SceneRouter.transition_finished.connect(_flush_pending_match, CONNECT_DEFERRED)
	_refresh()


func _request_match(config: MatchConfig) -> void:
	if config == null or config.context != MatchConfig.Context.ONLINE or Net.mode == Net.Mode.LOCAL:
		return
	# Coalesce server starts while the previous transition is still loading.
	_pending_match = config
	_pending_epoch = Net.epoch
	_pending_room = Net.room_code
	_flush_pending_match()


func _flush_pending_match() -> void:
	if _pending_match == null or SceneRouter._busy:
		return
	var config := _pending_match
	_pending_match = null
	if SceneRouter.current_node != self or SceneRouter.current_id != "online" \
			or not SceneRouter._match_session_is_current(config, _pending_epoch, _pending_room):
		return
	_launch_match(config)


func _launch_match(config: MatchConfig) -> void:
	SceneRouter.start_match(config)


func _schedule_refresh() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		call_deferred("_refresh")


func _refresh() -> void:
	_refresh_pending = false
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	first_focus = null
	_status = UIKit.label("", UIKit.SIZE_SMALL, UIKit.ACCENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)
	if not Net.online_available:
		_status.text = Loc.t("online.unavailable")
		add_menu_button(Loc.t("online.play_local"), func(): SceneRouter.go_to("local_play"))
		return
	if Net.room_code.is_empty():
		if not Net.failure_key.is_empty():
			_rooms.clear()
		_browser()
		if not Net.failure_key.is_empty():
			_status.text = Loc.t(Net.failure_key)
	else:
		_lobby()


func _browser() -> void:
	var name_field := LineEdit.new()
	UIKit.fit_input_font(name_field, _name)
	name_field.max_length = 24
	name_field.placeholder_text = Loc.t("online.player_name")
	name_field.custom_minimum_size.y = 56
	name_field.text_changed.connect(func(value): _name = value)
	body.add_child(name_field)
	add_menu_button(Loc.t("online.create_public"), func(): Net.host_online(4, true, _name))
	add_menu_button(Loc.t("online.create_private"), func(): Net.host_online(4, false, _name))
	var row := UIKit.hbox(12)
	var code := LineEdit.new()
	UIKit.fit_input_font(code)
	code.max_length = 6
	code.placeholder_text = Loc.t("online.room_code")
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.text_direction = Control.TEXT_DIRECTION_LTR
	row.add_child(code)
	var join := UIKit.button(Loc.t("online.join"))
	join.pressed.connect(func():
		if not Net.join_online(code.text.strip_edges(), _name):
			_status.text = Loc.t("online.failed"))
	row.add_child(join)
	body.add_child(row)
	add_menu_button(Loc.t("online.refresh"), Net.list_rooms)
	for room in _rooms:
		var captured: Dictionary = room
		add_menu_button("%s  %d/%d" % [room.host, room.count, room.capacity],
			func(): Net.join_online(String(captured.code), _name))


func _lobby() -> void:
	_status.text = "%s: %s   %d ms" % [Loc.t("online.room_code"), Net.room_code, Net.ping_ms]
	var selected_game := String(Net.lobby_config.get("game", "ring_rumble"))
	var variant := UIKit.label(Loc.t("online.playlist") if Net.lobby_config.get("tournament") is Dictionary \
		else Loc.t("online.push_variant") if selected_game == "ring_rumble" \
		else Registry.minigame(selected_game).display_name(), UIKit.SIZE_SMALL, UIKit.ACCENT_2)
	variant.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(variant)
	if not Net.tournament.is_empty():
		var summary := UIKit.label(Loc.t("online.tournament_progress", {"n": int(Net.tournament.round), "target": int(Net.tournament.target)}), UIKit.SIZE_SMALL)
		body.add_child(summary)
		if not Net.tournament.get("contenders", []).is_empty() and not bool(Net.tournament.complete):
			body.add_child(UIKit.label(Loc.t("party.tiebreak"), UIKit.SIZE_SMALL, UIKit.ACCENT))
	var device := UIKit.option([], 0)
	var devices: Array = []
	device.add_item(Loc.t("online.touch"))
	devices.append({"type": 2, "id": 0})
	for source in InputRouter.available_devices():
		device.add_item(Loc.t(String(source.label)) if int(source.type) == InputRouter.Source.KEYBOARD else String(source.label))
		devices.append({"type": 1 if int(source.type) == InputRouter.Source.PAD else 0, "id": int(source.id)})
	for i in devices.size():
		if devices[i].type == Net.local_device_type and devices[i].id == Net.local_device_id:
			device.select(i)
	device.item_selected.connect(func(index):
		Net.local_device_type = devices[index].type
		Net.local_device_id = devices[index].id)
	body.add_child(device)
	var characters := Registry.characters()
	for peer in Net.peers.values():
		var row := UIKit.hbox(8)
		var name_label := UIKit.label("%s %s %s" % [
			Loc.t("online.host") if int(peer.id) == 1 else "",
			String(peer.name), Loc.t("online.ready_yes") if peer.ready else Loc.t("online.ready_no")], UIKit.SIZE_SMALL)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(name_label)
		if not bool(peer.connected):
			row.add_child(UIKit.label(Loc.t("online.reconnecting"), UIKit.SIZE_TINY, UIKit.DANGER))
		if int(peer.id) == Net.local_peer_id:
			var choice := UIKit.option([], 0)
			for character in characters:
				choice.add_item(character.display_name())
			choice.select(int(peer.character))
			choice.disabled = Net.room_state != "lobby"
			choice.item_selected.connect(Net.select_character)
			row.add_child(choice)
		else:
			row.add_child(UIKit.label(characters[int(peer.character)].display_name(), UIKit.SIZE_SMALL))
		if Net.is_host and int(peer.id) != Net.local_peer_id:
			var id := int(peer.id)
			var kick := UIKit.button(Loc.t("online.kick"), UIKit.SIZE_SMALL)
			kick.disabled = Net.room_state != "lobby"
			kick.pressed.connect(func(): Net.remove_peer(id))
			row.add_child(kick)
		body.add_child(row)
	if Net.is_host and Net.room_state == "lobby":
		_host_settings()
	elif Net.lobby_config.get("tournament") is Dictionary:
		for entry in Net.lobby_config.tournament.get("entries", []):
			var item := UIKit.label("%s / %s" % [Registry.minigame(entry.game).display_name(),
				Registry.arena(entry.arena).display_name()], UIKit.SIZE_SMALL)
			item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_child(item)
	if Net.room_state == "results":
		if not Net.tournament.is_empty() and not bool(Net.tournament.complete):
			var ready := bool(Net.peers.get(Net.local_peer_id, {}).get("ready", false))
			add_menu_button(Loc.t("online.unready") if ready else Loc.t("online.ready"),
				func(): Net.set_ready(Net.local_peer_id, not ready))
			if Net.is_host:
				add_menu_button(Loc.t("online.next_round"), Net.next_tournament_round, Net.all_ready())
		else:
			add_menu_button(Loc.t("online.return_lobby"), Net.end_match, Net.is_host)
	elif Net.room_state == "lobby":
		var ready := bool(Net.peers.get(Net.local_peer_id, {}).get("ready", false))
		add_menu_button(Loc.t("online.unready") if ready else Loc.t("online.ready"),
			func(): Net.set_ready(Net.local_peer_id, not ready))
		if Net.is_host:
			add_menu_button(Loc.t("online.start"), func(): Net.request_start(null), Net.all_ready())
	add_menu_button(Loc.t("online.leave"), func():
		Net.leave()
		_refresh())


func _host_settings() -> void:
	var cfg := Net.lobby_config.duplicate(true)
	var tournament: Dictionary = cfg.get("tournament") if cfg.get("tournament") is Dictionary else {}
	var selected_game := String(cfg.get("game", "ring_rumble"))
	var games := UIKit.option([], 0)
	games.name = "OnlineGameSelect"
	for id in Net.ONLINE_GAMES:
		games.add_item(Registry.minigame(id).display_name())
	games.select(Net.ONLINE_GAMES.find(selected_game))
	games.item_selected.connect(func(index):
		cfg["game"] = Net.ONLINE_GAMES[index]
		cfg["arena"] = Net.ONLINE_ARENAS[cfg.game][0]
		if not tournament.is_empty():
			cfg["tournament"]["entries"] = _arena_entries(cfg.game) if tournament.rotation != "manual" \
				else [{"game": cfg.game, "arena": cfg.arena}]
		Net.set_lobby_config(cfg))
	if tournament.is_empty():
		body.add_child(games)
	else:
		games.queue_free()
	var mode := UIKit.option([Loc.t("online.single"), Loc.t("tournament.points"), Loc.t("tournament.cups")],
		0 if tournament.is_empty() else (1 if tournament.mode == "points" else 2))
	mode.name = "OnlineTournamentMode"
	mode.item_selected.connect(func(index):
		if index == 0:
			cfg["tournament"] = null
		elif cfg.get("tournament") is Dictionary:
			cfg.tournament.mode = "points" if index == 1 else "cups"
		else:
			cfg["tournament"] = {"mode": "points" if index == 1 else "cups", "target": 3,
				"rotation": "random_no_repeat", "points": [5, 3, 2, 1], "entries": _arena_entries(selected_game)}
		Net.set_lobby_config(cfg))
	body.add_child(mode)
	var row := UIKit.hbox(12)
	row.add_child(UIKit.label(Loc.t("tournament.cups") if tournament.get("mode") == "cups" else Loc.t("online.rounds"), UIKit.SIZE_SMALL))
	var rounds := SpinBox.new()
	rounds.custom_minimum_size = Vector2(160, 64)
	rounds.get_line_edit().add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
	rounds.min_value = 1 if tournament.is_empty() else 3
	rounds.max_value = 10
	rounds.value = int(cfg.get("rounds", 3)) if tournament.is_empty() else int(tournament.target)
	rounds.value_changed.connect(func(value):
		if not cfg.get("tournament") is Dictionary: cfg["rounds"] = int(value)
		else: cfg["tournament"]["target"] = int(value)
		Net.set_lobby_config(cfg))
	row.add_child(rounds)
	var bots := UIKit.checkbox(Loc.t("online.bots"), bool(cfg.get("bots", true)))
	bots.toggled.connect(func(value):
		cfg["bots"] = value
		Net.set_lobby_config(cfg))
	body.add_child(row)
	body.add_child(bots)
	if selected_game in ["kart_sprint", "sabaq_sawarikh"] or tournament.get("entries", []).any( \
			func(entry): return entry.game in ["kart_sprint", "sabaq_sawarikh"]):
		var laps := UIKit.option(["3", "4", "5", "6", "7", "8", "9", "10"], int(cfg.get("race_laps", 3)) - 3)
		laps.name = "OnlineLapSelect"
		laps.item_selected.connect(func(index):
			cfg["race_laps"] = index + 3
			Net.set_lobby_config(cfg))
		body.add_child(UIKit.row(Loc.t("race.laps"), laps))
	var difficulty := UIKit.option([], 0)
	for key in PlayerConfig.DIFFICULTY_KEYS:
		difficulty.add_item(Loc.t(key))
	difficulty.select(int(cfg.get("difficulty", 1)))
	difficulty.item_selected.connect(func(index):
		cfg["difficulty"] = index
		Net.set_lobby_config(cfg))
	body.add_child(difficulty)
	var arenas := UIKit.option([], 0)
	arenas.name = "OnlineArenaSelect"
	var arena_ids: Array = Net.ONLINE_ARENAS[selected_game]
	for id in arena_ids:
		arenas.add_item(Registry.arena(id).display_name())
	arenas.select(arena_ids.find(cfg.get("arena")))
	arenas.item_selected.connect(func(index):
		cfg["arena"] = arena_ids[index]
		if not tournament.is_empty() and tournament.rotation == "manual":
			cfg["tournament"]["entries"] = [{"game": selected_game, "arena": cfg.arena}]
		Net.set_lobby_config(cfg))
	if tournament.is_empty():
		body.add_child(arenas)
	else:
		arenas.queue_free()
	if not tournament.is_empty():
		var rotations := ["manual", "random", "random_no_repeat"]
		var rotate := UIKit.option([Loc.t("online.rotation.manual"), Loc.t("common.random"),
			Loc.t("online.rotate_arenas")], rotations.find(tournament.rotation))
		rotate.name = "OnlineRotationSelect"
		rotate.item_selected.connect(func(index):
			if not cfg.get("tournament") is Dictionary:
				return
			cfg["tournament"]["rotation"] = rotations[index]
			Net.set_lobby_config(cfg))
		body.add_child(UIKit.row(Loc.t("online.rotation.label"), rotate))
		_playlist_editor(cfg)


func _playlist_editor(cfg: Dictionary) -> void:
	var entries: Array = cfg.tournament.entries
	body.add_child(UIKit.label(Loc.t("online.playlist"), UIKit.SIZE_SMALL))
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var portrait := get_viewport_rect().size.y > get_viewport_rect().size.x
		var row: BoxContainer = UIKit.vbox(8) if portrait else UIKit.hbox(8)
		var game := UIKit.option([], 0)
		game.name = "OnlinePlaylistGame%d" % index
		game.fit_to_longest_item = false
		game.custom_minimum_size.x = 160
		game.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		game.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for id in Net.ONLINE_GAMES:
			game.add_item(Registry.minigame(id).display_name())
		game.select(Net.ONLINE_GAMES.find(entry.game))
		game.item_selected.connect(func(choice):
			if not cfg.get("tournament") is Dictionary or index >= cfg.tournament.entries.size():
				return
			var id: String = Net.ONLINE_GAMES[choice]
			for arena in Net.ONLINE_ARENAS[id]:
				var changed: Array = cfg.tournament.entries.duplicate(true)
				changed[index] = {"game": id, "arena": arena}
				if _replace_playlist(cfg, changed):
					return
			_schedule_refresh())
		row.add_child(game)
		var arena := UIKit.option([], 0)
		arena.name = "OnlinePlaylistArena%d" % index
		arena.fit_to_longest_item = false
		arena.custom_minimum_size.x = 160
		arena.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var maps: Array = Net.ONLINE_ARENAS[entry.game]
		for id in maps:
			arena.add_item(Registry.arena(id).display_name())
		arena.select(maps.find(entry.arena))
		arena.item_selected.connect(func(choice):
			if not cfg.get("tournament") is Dictionary or index >= cfg.tournament.entries.size():
				return
			var changed: Array = cfg.tournament.entries.duplicate(true)
			changed[index].arena = maps[choice]
			if not _replace_playlist(cfg, changed):
				_schedule_refresh())
		row.add_child(arena)
		var up := UIKit.button("↑", UIKit.SIZE_SMALL)
		up.name = "OnlinePlaylistUp%d" % index
		up.tooltip_text = Loc.t("online.playlist.up")
		up.disabled = index == 0
		up.pressed.connect(func():
			if not cfg.get("tournament") is Dictionary or index <= 0 or index >= cfg.tournament.entries.size():
				return
			var changed: Array = cfg.tournament.entries.duplicate(true)
			var previous = changed[index - 1]
			changed[index - 1] = changed[index]
			changed[index] = previous
			_replace_playlist(cfg, changed))
		var actions := UIKit.hbox(8)
		actions.add_child(UIKit.label(str(index + 1), UIKit.SIZE_SMALL))
		actions.add_child(up)
		var remove := UIKit.button("-", UIKit.SIZE_SMALL)
		remove.name = "OnlinePlaylistRemove%d" % index
		remove.tooltip_text = Loc.t("online.playlist.remove")
		remove.disabled = entries.size() == 1
		remove.pressed.connect(func():
			if not cfg.get("tournament") is Dictionary or index >= cfg.tournament.entries.size():
				return
			var changed: Array = cfg.tournament.entries.duplicate(true)
			changed.remove_at(index)
			_replace_playlist(cfg, changed))
		actions.add_child(remove)
		row.add_child(actions)
		body.add_child(row)
	var add := UIKit.button(Loc.t("online.playlist.add"), UIKit.SIZE_SMALL)
	add.name = "OnlinePlaylistAdd"
	add.disabled = entries.size() >= 39
	add.pressed.connect(func():
		if not cfg.get("tournament") is Dictionary:
			return
		for id in Net.ONLINE_GAMES:
			for arena in Net.ONLINE_ARENAS[id]:
				var changed: Array = cfg.tournament.entries.duplicate(true)
				changed.append({"game": id, "arena": arena})
				if _replace_playlist(cfg, changed):
					return)
	body.add_child(add)


func _replace_playlist(cfg: Dictionary, entries: Array) -> bool:
	if not cfg.get("tournament") is Dictionary or entries.is_empty() or entries.size() > 39:
		return false
	var seen := {}
	for entry in entries:
		if not entry is Dictionary or not entry.get("game") in Net.ONLINE_GAMES \
				or not entry.get("arena") in Net.ONLINE_ARENAS[entry.game]:
			return false
		var key := "%s:%s" % [entry.game, entry.arena]
		if seen.has(key):
			return false
		seen[key] = true
	var changed := cfg.duplicate(true)
	changed.tournament.entries = entries.duplicate(true)
	changed.game = entries[0].game
	changed.arena = entries[0].arena
	# Keep sequential local edits on the same draft until server refresh arrives.
	cfg.tournament = changed.tournament
	cfg.game = changed.game
	cfg.arena = changed.arena
	Net.set_lobby_config(changed)
	return true


func _arena_entries(game_id: String) -> Array:
	var entries: Array = []
	for arena_id in Net.ONLINE_ARENAS[game_id]:
		entries.append({"game": game_id, "arena": arena_id})
	return entries


func go_back() -> void:
	Net.leave()
	super.go_back()
