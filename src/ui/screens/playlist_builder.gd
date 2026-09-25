extends Screen

var _plan: Dictionary
var _games: Array[MiniGameDef] = []
var _entries: VBoxContainer
var _name: LineEdit
var _code: TextEdit
var _message: Label


func build() -> void:
	title(Loc.t("playlist.title"))
	_plan = args.get("plan", {}).duplicate(true)
	if not PartyPlaylist.valid(_plan):
		_plan = PartyPlaylist.create_plan()
	_games = Progression.playable_games()
	_games = _games.filter(func(game): return not game.is_boss)
	var saved := PartyPlaylist.saved()
	var names: Array = [Loc.t("playlist.saved")]
	names.append_array(saved.keys())
	var picker := UIKit.option(names, 0)
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.item_selected.connect(func(i):
		if i > 0:
			if PartyPlaylist.valid(saved[names[i]]):
				SceneRouter.go_to("playlist_builder", {"plan": saved[names[i]]}, false, 0)
			else:
				_message.text = Loc.t("playlist.invalid"))
	body.add_child(picker)
	if saved.has(String(_plan.get("name", ""))):
		var remove := UIKit.button("×", UIKit.SIZE_SMALL)
		remove.tooltip_text = Loc.t("playlist.delete")
		remove.pressed.connect(func():
			var dialog := ConfirmationDialog.new()
			dialog.dialog_text = Loc.t("playlist.confirm_delete", {"name": _plan["name"]})
			dialog.ok_button_text = Loc.t("playlist.delete")
			dialog.cancel_button_text = Loc.t("common.cancel")
			add_child(dialog)
			dialog.confirmed.connect(func():
				PartyPlaylist.remove(_plan["name"])
				SceneRouter.go_to("playlist_builder", {}, false, 0))
			dialog.popup_centered())
		header.add_child(remove)
	_name = LineEdit.new()
	_name.max_length = 32
	_name.custom_minimum_size.y = 64
	_name.add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
	_name.text = _plan["name"]
	_name.placeholder_text = Loc.t("playlist.name")
	body.add_child(_name)
	var presets := PlaylistGenerator.preset_ids()
	var labels: Array = []
	for id in presets:
		labels.append(Loc.t("preset." + id))
	var preset := UIKit.option(labels, maxi(0, presets.find(_plan["preset"])))
	preset.item_selected.connect(func(i): _plan["preset"] = presets[i])
	body.add_child(UIKit.row(Loc.t("party.preset"), preset))
	var double_final := UIKit.checkbox(Loc.t("party.double_final"), bool(_plan["double_final"]))
	double_final.toggled.connect(func(value): _plan["double_final"] = value)
	body.add_child(double_final)
	_entries = UIKit.vbox(12)
	body.add_child(_entries)
	_rebuild_entries()
	var add := UIKit.button("+", UIKit.SIZE_BODY)
	add.tooltip_text = Loc.t("playlist.add")
	add.pressed.connect(func():
		if _plan["entries"].size() < 10 and not _games.is_empty():
			_plan["entries"].append({"game": _games[0].id, "arena": _games[0].arena_ids[0]})
			_rebuild_entries())
	body.add_child(add)
	var actions := UIKit.adaptive_columns(12)
	body.add_child(actions)
	for action in [["playlist.save", _save], ["playlist.copy", _copy], ["playlist.use", _use]]:
		var button := UIKit.button(Loc.t(action[0]), UIKit.SIZE_SMALL)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(action[1])
		actions.add_child(button)
		first_focus = button
	_code = TextEdit.new()
	_code.custom_minimum_size = Vector2(0, 110)
	_code.add_theme_font_size_override("font_size", UIKit.SIZE_TINY)
	_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code.placeholder_text = Loc.t("playlist.code")
	_code.text_direction = Control.TEXT_DIRECTION_LTR
	body.add_child(_code)
	var import_button := UIKit.button(Loc.t("playlist.import"), UIKit.SIZE_SMALL)
	import_button.pressed.connect(func():
		var plan := PartyPlaylist.decode(_code.text)
		if plan.is_empty():
			_message.text = Loc.t("playlist.invalid")
		else:
			SceneRouter.go_to("playlist_builder", {"plan": plan}, false, 0))
	body.add_child(import_button)
	_message = UIKit.centered("", UIKit.SIZE_SMALL, UIKit.ACCENT)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_message)


func _rebuild_entries() -> void:
	for child in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
	var names: Array = []
	for game in _games:
		names.append(game.display_name())
	for i in _plan["entries"].size():
		var entry: Dictionary = _plan["entries"][i]
		var row := UIKit.adaptive_columns(10)
		_entries.add_child(row)
		row.add_child(UIKit.label(str(i + 1), UIKit.SIZE_SMALL, UIKit.ACCENT))
		var selected := 0
		for j in _games.size():
			if _games[j].id == entry["game"]:
				selected = j
		var game := UIKit.option(names, selected)
		_fit_option(game)
		game.item_selected.connect(func(j):
			entry["game"] = _games[j].id
			entry["arena"] = _games[j].arena_ids[0]
			_rebuild_entries())
		row.add_child(game)
		var arenas := Registry.minigame(entry["game"]).arena_ids
		var arena_names: Array = []
		for id in arenas:
			arena_names.append(Registry.arena(id).display_name())
		var arena := UIKit.option(arena_names, maxi(0, arenas.find(entry["arena"])))
		_fit_option(arena)
		arena.item_selected.connect(func(j): entry["arena"] = arenas[j])
		row.add_child(arena)
		var tools := UIKit.hbox(6)
		row.add_child(tools)
		for operation in [["↑", "playlist.up", -1], ["↓", "playlist.down", 1], ["×", "playlist.remove", 0]]:
			var button := UIKit.button(operation[0], UIKit.SIZE_SMALL)
			button.tooltip_text = Loc.t(operation[1])
			button.custom_minimum_size.x = 60
			var direction := int(operation[2])
			button.disabled = (direction == -1 and i == 0) or (direction == 1 and i == _plan["entries"].size() - 1) or (direction == 0 and _plan["entries"].size() <= 3)
			button.pressed.connect(func():
				if direction == 0:
					_plan["entries"].remove_at(i)
				else:
					var other = _plan["entries"][i + direction]
					_plan["entries"][i + direction] = entry
					_plan["entries"][i] = other
				_rebuild_entries())
			tools.add_child(button)


func _fit_option(option: OptionButton) -> void:
	option.fit_to_longest_item = false
	option.clip_text = true
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size.x = 0


func _save() -> void:
	_plan["name"] = _name.text
	_message.text = Loc.t("playlist.saved_ok" if PartyPlaylist.save(_plan) else "playlist.save_failed")


func _copy() -> void:
	_plan["name"] = _name.text
	_code.text = PartyPlaylist.encode(_plan)
	if not _code.text.is_empty():
		DisplayServer.clipboard_set(_code.text)
		_message.text = Loc.t("playlist.copied")


func _use() -> void:
	_plan["name"] = _name.text
	if PartyPlaylist.valid(_plan):
		SceneRouter.go_to("tournament", {"playlist": _plan}, false)
