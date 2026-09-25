class_name PartyRoster
extends GridContainer
## Shared lobby for single matches and tournaments; no account is required.

var players: Array[PlayerConfig] = []
var _characters: Array[CharacterData] = []
var _devices: Array = []


func setup() -> void:
	_characters = Progression.playable_characters()
	players = last_players()
	_devices = [{"type": 2, "id": 0, "label": Loc.t("party.touch")},
		{"type": 0, "id": 0, "label": Loc.t("keyboard.profile.1")},
		{"type": 0, "id": 1, "label": Loc.t("keyboard.profile.2")}]
	for id in Input.get_connected_joypads():
		_devices.append({"type": 1, "id": id, "label": Input.get_joy_name(id)})
	add_theme_constant_override("h_separation", 14)
	add_theme_constant_override("v_separation", 14)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_rebuild()


func _fit() -> void:
	columns = clampi(int((get_viewport_rect().size.x - 112.0) / 280.0), 1, 4)


static func last_players() -> Array[PlayerConfig]:
	var out: Array[PlayerConfig] = []
	var raw = SaveSystem.shared_branch("party_roster", [])
	if raw is Array and raw.size() == 4:
		for row in raw:
			var p := PlayerConfig.from_dict(row) if row is Dictionary else null
			if p == null or not Progression.is_character_unlocked(p.character_id):
				out.clear()
				break
			p.slot = out.size()
			if p.device_type == 1 and not Input.get_connected_joypads().has(p.device_id):
				p.device_type = 2
				p.device_id = 0
			if not p.local_profile_id.is_empty() and not SaveSystem.profile_ids().has(p.local_profile_id):
				p.local_profile_id = ""
			out.append(p)
	if out.size() == 4:
		var has_human := false
		var devices := {}
		var profiles := {}
		for p in out:
			if not p.is_human:
				continue
			has_human = true
			var key := "%d:%d" % [p.device_type, p.device_id]
			if p.device_type != 2 and devices.has(key):
				p.device_type = 2
			devices[key] = true
			if profiles.has(p.local_profile_id):
				p.local_profile_id = ""
			elif not p.local_profile_id.is_empty():
				profiles[p.local_profile_id] = true
		if not has_human:
			out[0].is_human = true
			out[0].device_type = 2 if TouchSource.should_show() else 0
			out[0].device_id = 0
		return out
	var chars := Progression.playable_characters()
	if chars.is_empty():
		return out
	for i in 4:
		var p := PlayerConfig.new()
		p.slot = i
		p.character_id = chars[i % chars.size()].id
		p.is_human = i == 0
		p.device_type = 2 if TouchSource.should_show() else 0
		p.device_id = mini(i, 1)
		p.local_profile_id = SaveSystem.active_profile_id() if i == 0 else ""
		p.apply_profile_preferences()
		out.append(p)
	return out


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for p in players:
		var column := UIKit.vbox(8)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(column)
		column.add_child(UIKit.centered("P%d %s" % [p.slot + 1, p.symbol()], UIKit.SIZE_HEADING, p.color(), true))
		var mode := UIKit.option([Loc.t("party.human"), Loc.t("local.slot_ai")], 0 if p.is_human else 1)
		_compact(mode)
		mode.item_selected.connect(func(i):
			p.is_human = i == 0
			_rebuild())
		column.add_child(mode)
		column.add_child(Widgets.character_portrait(p.character_with_cosmetics()))
		column.add_child(UIKit.centered(Loc.t("archetype." + p.character().archetype), UIKit.SIZE_SMALL, UIKit.ACCENT))
		for stat in [["speed", p.character().speed], ["power", p.character().power], ["weight", p.character().weight]]:
			var dots := clampi(ceili(float(stat[1]) * 4.0), 1, 4)
			column.add_child(UIKit.centered(Loc.t("char.stat." + stat[0]) + "  " + "●".repeat(dots) + "○".repeat(4 - dots), UIKit.SIZE_TINY))
		var names: Array = []
		var selected := 0
		for i in _characters.size():
			names.append(_characters[i].display_name())
			if _characters[i].id == p.character_id:
				selected = i
		var character := UIKit.option(names, selected)
		_compact(character)
		character.item_selected.connect(func(i):
			p.character_id = _characters[i].id
			_rebuild())
		column.add_child(character)
		var random_character := UIKit.button("⚄", UIKit.SIZE_BODY)
		random_character.tooltip_text = Loc.t("common.random")
		random_character.pressed.connect(func():
			p.character_id = _characters[randi_range(0, _characters.size() - 1)].id
			_rebuild())
		column.add_child(random_character)
		if p.is_human:
			_add_human_options(column, p)


func _add_human_options(column: VBoxContainer, p: PlayerConfig) -> void:
	var ids: Array = [""]
	var labels: Array = [Loc.t("party.guest")]
	for id in SaveSystem.profile_ids():
		ids.append(id)
		var name := String(SaveSystem.profile_meta(id)["name"])
		labels.append(Loc.t(name) if Loc.has(name) else name)
	var profile := UIKit.option(labels, maxi(0, ids.find(p.local_profile_id)))
	_compact(profile)
	profile.item_selected.connect(func(i):
		p.local_profile_id = ids[i]
		p.apply_profile_preferences()
		_rebuild())
	column.add_child(profile)
	var devices: Array = []
	var selected := 0
	for i in _devices.size():
		devices.append(_devices[i]["label"])
		if p.device_type == _devices[i]["type"] and (p.device_type == 2 or p.device_id == _devices[i]["id"]):
			selected = i
	var device := UIKit.option(devices, selected)
	_compact(device)
	device.item_selected.connect(func(i):
		p.device_type = _devices[i]["type"]
		p.device_id = _devices[i]["id"])
	column.add_child(device)


func _compact(option: OptionButton) -> void:
	option.fit_to_longest_item = false
	option.clip_text = true
	option.custom_minimum_size.x = 0
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_size_override("font_size", UIKit.SIZE_SMALL)


func _process(_delta: float) -> void:
	var taken: Array = []
	for p in players:
		if p.is_human and p.device_type != 2:
			taken.append({"type": InputRouter.Source.PAD if p.device_type == 1 else InputRouter.Source.KEYBOARD, "id": p.device_id})
	var request := InputRouter.poll_join_request(taken)
	if request.is_empty():
		return
	for p in players:
		if not p.is_human:
			p.is_human = true
			p.device_type = 1 if request["type"] == InputRouter.Source.PAD else 0
			p.device_id = request["id"]
			_rebuild()
			return


func validation_error() -> String:
	var devices := {}
	var profiles := {}
	var humans := 0
	for p in players:
		if not p.is_human:
			continue
		humans += 1
		if p.device_type != 2:
			var key := "%d:%d" % [p.device_type, p.device_id]
			if devices.has(key):
				return "party.device_duplicate"
			devices[key] = true
		if not p.local_profile_id.is_empty():
			if profiles.has(p.local_profile_id):
				return "party.profile_duplicate"
			profiles[p.local_profile_id] = true
	return "party.need_human" if humans == 0 else ""


func save_roster(difficulty: int) -> Array[PlayerConfig]:
	var rows: Array = []
	for p in players:
		p.ai_difficulty = difficulty
		if p.is_human:
			var name := String(SaveSystem.profile_meta(p.local_profile_id).get("name", "")) if not p.local_profile_id.is_empty() else ""
			p.display_name_override = (Loc.t(name) if Loc.has(name) else name) if not name.is_empty() else Loc.t("party.guest_slot", {"n": p.slot + 1})
			if not p.local_profile_id.is_empty():
				var progress := Progression.prepare_profile(p.local_profile_id)
				p.palette_id = String(progress.get("selected_palette", "classic"))
			else:
				p.palette_id = "classic"
		rows.append(p.to_dict())
	SaveSystem.set_shared_branch("party_roster", rows)
	SaveSystem.flush()
	return players
