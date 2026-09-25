extends Screen

var _roster: PartyRoster
var _preset := "normal"
var _rounds := 5
var _difficulty := 1
var _double_final := false
var _favorites_only := false
var _error: Label
var _playlist: Dictionary = {}


func build() -> void:
	title(Loc.t("tournament.title"))
	_playlist = args.get("playlist", {})
	if not _playlist.is_empty() and not PartyPlaylist.valid(_playlist):
		_playlist = {}
	var builder := UIKit.button(Loc.t("playlist.title"), UIKit.SIZE_SMALL)
	builder.pressed.connect(func():
		if _roster.validation_error().is_empty():
			_roster.save_roster(_difficulty)
			SceneRouter.go_to("playlist_builder", {"plan": _playlist}))
	body.add_child(builder)
	if not _playlist.is_empty():
		_preset = _playlist["preset"]
		_rounds = _playlist["entries"].size()
		_double_final = _playlist["double_final"]
		body.add_child(UIKit.centered(String(_playlist.get("name", "")), UIKit.SIZE_BODY, UIKit.ACCENT))
	var row := UIKit.adaptive_columns(16)
	body.add_child(row)
	var ids := PlaylistGenerator.preset_ids()
	var labels: Array = []
	for id in ids:
		labels.append(Loc.t("preset." + id))
	var preset := UIKit.option(labels, maxi(0, ids.find(_preset)))
	_add_option(row, "party.preset", preset)
	var counts := [3, 4, 5, 6, 7, 8, 9, 10]
	var rounds := UIKit.option(["3", "4", "5", "6", "7", "8", "9", "10"], maxi(0, counts.find(_rounds)))
	rounds.disabled = not _playlist.is_empty()
	rounds.item_selected.connect(func(i): _rounds = counts[i])
	_add_option(row, "tournament.rounds", rounds)
	var difficulty_labels: Array = []
	for key in PlayerConfig.DIFFICULTY_KEYS:
		difficulty_labels.append(Loc.t(key))
	var difficulty := UIKit.option(difficulty_labels, 1)
	if not _playlist.is_empty():
		difficulty.select(int(PlaylistGenerator.preset_meta(_preset).get("difficulty", 1)))
		difficulty.disabled = true
	difficulty.item_selected.connect(func(i): _difficulty = i)
	_add_option(row, "quick.difficulty", difficulty)
	preset.item_selected.connect(func(i):
		_preset = ids[i]
		var meta := PlaylistGenerator.preset_meta(_preset)
		_rounds = int(meta.get("games_count", 5))
		rounds.select(maxi(0, counts.find(_rounds)))
		_difficulty = int(meta.get("difficulty", 1))
		difficulty.select(_difficulty)
		difficulty.disabled = _preset in ["family", "skill"])
	var final_toggle := UIKit.checkbox(Loc.t("party.double_final"), _double_final)
	final_toggle.toggled.connect(func(on): _double_final = on)
	body.add_child(final_toggle)
	var favorites := UIKit.checkbox(Loc.t("party.favorites_cup"), false)
	favorites.toggled.connect(func(on): _favorites_only = on)
	body.add_child(favorites)
	favorites.disabled = not _playlist.is_empty()
	preset.disabled = not _playlist.is_empty()
	_roster = PartyRoster.new()
	body.add_child(_roster)
	_roster.setup()
	_error = UIKit.centered("", UIKit.SIZE_SMALL, UIKit.DANGER)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_error)
	var start := UIKit.button(Loc.t("tournament.start"), UIKit.SIZE_HEADING)
	start.custom_minimum_size.y = 80
	start.pressed.connect(_start)
	body.add_child(start)
	first_focus = start


func _add_option(parent: Control, key: String, option: OptionButton) -> void:
	var column := UIKit.vbox(6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(UIKit.label(Loc.t(key), UIKit.SIZE_SMALL))
	option.fit_to_longest_item = false
	option.clip_text = true
	option.custom_minimum_size.x = 0
	column.add_child(option)
	parent.add_child(column)


func _start() -> void:
	var error := _roster.validation_error()
	if not error.is_empty():
		_error.text = Loc.t(error)
		return
	var pool: Array = []
	if _favorites_only:
		pool = PartyLibrary.favorites()
		if pool.is_empty():
			_error.text = Loc.t("party.no_favorites")
			return
	var roster := _roster.save_roster(_difficulty)
	if not _playlist.is_empty():
		var custom := PartyPlaylist.make_session(_playlist, roster)
		if custom == null:
			_error.text = Loc.t("playlist.invalid")
			return
		custom.double_final = _double_final
		_confirm_launch(custom)
		return
	var session := TournamentSession.from_preset(_preset, roster, randi() & 0x7FFFFFFF, pool)
	var definitions := PlaylistGenerator._resolve_pool(pool, PlaylistGenerator.preset_meta(_preset).get("categories", []))
	var entries := PlaylistGenerator.generate(definitions, _rounds, session.seed_value)
	if entries.is_empty():
		_error.text = Loc.t("party.no_favorites")
		return
	session.game_ids.clear()
	session.arena_ids.clear()
	for entry in entries:
		session.game_ids.append(entry["game_id"])
		session.arena_ids.append(entry["arena_id"])
	if _preset not in ["family", "skill"]:
		for p in session.players:
			p.ai_difficulty = _difficulty
	session.double_final = _double_final
	_confirm_launch(session)


func _confirm_launch(session: TournamentSession) -> void:
	if TournamentSession.saved_session() != null:
		var dialog := ConfirmationDialog.new()
		dialog.dialog_text = Loc.t("party.replace_saved")
		dialog.ok_button_text = Loc.t("tournament.start")
		dialog.cancel_button_text = Loc.t("common.cancel")
		add_child(dialog)
		dialog.confirmed.connect(func(): _launch(session))
		dialog.popup_centered()
	else:
		_launch(session)


func _launch(session: TournamentSession) -> void:
	session.checkpoint()
	SceneRouter.go_to("standings", {"session": session}, false)
