extends Screen
## Room UI consumes server state; no simulated peers or local pseudo-room codes.
var _status: Label
var _rooms: Array = []
var _name := "Player"
var _refresh_pending := false


func build() -> void:
	title(Loc.t("online.title"))
	Net.room_updated.connect(_schedule_refresh)
	Net.rooms_received.connect(func(rooms):
		_rooms = rooms
		_schedule_refresh())
	Net.online_error.connect(func(_code):
		if is_instance_valid(_status):
			_status.text = Loc.t("online.failed"))
	Net.connection_lost.connect(func(_reason): _schedule_refresh())
	Net.match_start_requested.connect(func(cfg):
		if Net.mode != Net.Mode.LOCAL and cfg != null and cfg.context == MatchConfig.Context.ONLINE:
			SceneRouter.start_match(cfg))
	_refresh()


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
		_browser()
	else:
		_lobby()


func _browser() -> void:
	var name_field := LineEdit.new()
	name_field.text = _name
	name_field.max_length = 24
	name_field.placeholder_text = Loc.t("online.player_name")
	name_field.custom_minimum_size.y = 56
	name_field.text_changed.connect(func(value): _name = value)
	body.add_child(name_field)
	add_menu_button(Loc.t("online.create_public"), func(): Net.host_online(4, true, _name))
	add_menu_button(Loc.t("online.create_private"), func(): Net.host_online(4, false, _name))
	var row := UIKit.hbox(12)
	var code := LineEdit.new()
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
	var variant := UIKit.label(Loc.t("online.push_variant"), UIKit.SIZE_SMALL, UIKit.ACCENT_2)
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
	var mode := UIKit.option([Loc.t("online.single"), Loc.t("tournament.points"), Loc.t("tournament.cups")],
		0 if tournament.is_empty() else (1 if tournament.mode == "points" else 2))
	mode.item_selected.connect(func(index):
		cfg["tournament"] = null if index == 0 else {"mode": "points" if index == 1 else "cups", "target": 3,
			"rotation": "random_no_repeat", "points": [5, 3, 2, 1], "entries": [
				{"game": "ring_rumble", "arena": "vortex_ring"}, {"game": "ring_rumble", "arena": "storm_ring"}]}
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
		if tournament.is_empty(): cfg["rounds"] = int(value)
		else: cfg["tournament"]["target"] = int(value)
		Net.set_lobby_config(cfg))
	row.add_child(rounds)
	var bots := UIKit.checkbox(Loc.t("online.bots"), bool(cfg.get("bots", true)))
	bots.toggled.connect(func(value):
		cfg["bots"] = value
		Net.set_lobby_config(cfg))
	row.add_child(bots)
	body.add_child(row)
	var difficulty := UIKit.option([], 0)
	for key in PlayerConfig.DIFFICULTY_KEYS:
		difficulty.add_item(Loc.t(key))
	difficulty.select(int(cfg.get("difficulty", 1)))
	difficulty.item_selected.connect(func(index):
		cfg["difficulty"] = index
		Net.set_lobby_config(cfg))
	body.add_child(difficulty)
	var arenas := UIKit.option([], 0)
	for id in ["vortex_ring", "storm_ring"]:
		arenas.add_item(Registry.arena(id).display_name())
	arenas.select(0 if cfg.get("arena") == "vortex_ring" else 1)
	arenas.item_selected.connect(func(index):
		cfg["arena"] = ["vortex_ring", "storm_ring"][index]
		if not tournament.is_empty() and tournament.rotation == "manual":
			cfg["tournament"]["entries"] = [{"game": "ring_rumble", "arena": cfg.arena}]
		Net.set_lobby_config(cfg))
	body.add_child(arenas)
	if not tournament.is_empty():
		var rotate := UIKit.checkbox(Loc.t("online.rotate_arenas"), tournament.rotation == "random_no_repeat")
		rotate.toggled.connect(func(value):
			cfg["tournament"]["rotation"] = "random_no_repeat" if value else "manual"
			cfg["tournament"]["entries"] = [
				{"game": "ring_rumble", "arena": "vortex_ring"}, {"game": "ring_rumble", "arena": "storm_ring"}]
			if not value:
				cfg["tournament"]["entries"] = [{"game": "ring_rumble", "arena": cfg.arena}]
			Net.set_lobby_config(cfg))
		body.add_child(rotate)


func go_back() -> void:
	Net.leave()
	super.go_back()
