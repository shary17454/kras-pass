extends Screen
## Quick Play — pick a game, a competitor and the shape of the match, then go.
##
## Every control here maps to one field of `MatchConfig`; the screen has no
## gameplay knowledge of its own, which is why adding a mini-game never means
## editing it.

const SettingToggle = preload("res://src/ui/components/setting_toggle.gd")
const FORM_FIELD_HEIGHT := 96.0

var _game_index := 0
var _character_index := 0
var _games: Array[MiniGameDef] = []
var _characters: Array[CharacterData] = []
var _opponents := 3
var _difficulty := 1
var _rounds := 1
var _arena_index := 0
var _powerups := true

var _game_card_holder: Control
var _character_card_holder: Control
var _arena_option: OptionButton
var _rounds_option: OptionButton
var _game_option: OptionButton
var _laps := 3
var _laps_row: Control
var _laps_option: OptionButton
var _tank_variant := "normal"
var _tank_row: Control


func build() -> void:
	title(Loc.t("quick.title"))
	var screen_title := header.get_node("ScreenTitle") as Label
	screen_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_games = Progression.playable_games()
	_characters = Progression.playable_characters()
	if _games.is_empty() or _characters.is_empty():
		body.add_child(UIKit.centered(Loc.t("common.locked"), UIKit.SIZE_HEADING, UIKit.DANGER))
		return
	var last := Progression.last_character()
	for i in _characters.size():
		if _characters[i].id == last:
			_character_index = i
	_rounds = _games[_game_index].default_rounds
	var selected_id := String(args.get("game_id", ""))
	for i in _games.size():
		if _games[i].id == selected_id:
			_game_index = i
	var game_names: Array[String] = []
	for game in _games:
		game_names.append(game.display_name())
	_game_option = UIKit.option(game_names, _game_index)
	_game_option.item_selected.connect(func(i):
		_game_index = i
		_arena_index = 0
		_refresh_game())
	body.add_child(_setting_row("Game", Loc.t("quick.game"), _game_option))

	var columns := UIKit.adaptive_columns(32)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)

	var left := UIKit.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := UIKit.vbox(12)
	right.name = "FormSettings"
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	columns.add_child(right)

	var game_heading := UIKit.heading(Loc.t("quick.game"))
	game_heading.name = "GameHeading"
	game_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(game_heading)
	_game_card_holder = _picker(left, func(step): _cycle_game(step))
	var character_heading := UIKit.heading(Loc.t("quick.character"))
	character_heading.name = "CharacterHeading"
	character_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(character_heading)
	_character_card_holder = _picker(left, func(step): _cycle_character(step))

	var opp := UIKit.option(["0", "1", "2", "3"], _opponents)
	opp.item_selected.connect(func(i): _opponents = i)
	right.add_child(_setting_row("Opponents", Loc.t("quick.opponents"), opp, true))

	var diff := UIKit.option([
		Loc.t("difficulty.easy"), Loc.t("difficulty.medium"),
		Loc.t("difficulty.hard"), Loc.t("difficulty.expert"),
	], _difficulty)
	diff.item_selected.connect(func(i): _difficulty = i)
	right.add_child(_setting_row("Difficulty", Loc.t("quick.difficulty"), diff))

	_arena_option = UIKit.option([], 0)
	_arena_option.item_selected.connect(func(i): _arena_index = i)
	right.add_child(_setting_row("Arena", Loc.t("quick.arena"), _arena_option))

	_rounds_option = UIKit.option(["1", "2", "3", "5"], 0)
	_rounds_option.item_selected.connect(func(i): _rounds = [1, 2, 3, 5][i])
	right.add_child(_setting_row("Rounds", Loc.t("quick.rounds"), _rounds_option, true))
	_laps_option = UIKit.option(["3", "4", "5", "6", "7", "8", "9", "10"], 0)
	_laps_option.item_selected.connect(func(i): _laps = i + 3)
	_laps_row = _setting_row("Laps", Loc.t("race.laps"), _laps_option, true)
	right.add_child(_laps_row)
	var variants := ["normal", "ricochet", "one_shot", "infinite"]
	var names: Array = []
	for id in variants:
		names.append(Loc.t("tank.variant." + id))
	var variant := UIKit.option(names, 0)
	variant.item_selected.connect(func(i): _tank_variant = variants[i])
	_tank_row = _setting_row("TankVariant", Loc.t("party.variant"), variant)
	right.add_child(_tank_row)

	var pu := SettingToggle.new()
	pu.button_pressed = _powerups
	pu.toggled.connect(func(v): _powerups = v)
	right.add_child(_setting_row("Powerups", Loc.t("quick.powerups"), pu, false, true))

	right.add_child(UIKit.spacer(18))
	var start := UIKit.button(Loc.t("quick.start"), UIKit.SIZE_HEADING)
	start.name = "StartButton"
	_style_form_button(start)
	start.custom_minimum_size = Vector2(0, FORM_FIELD_HEIGHT * UIKit.scale())
	start.pressed.connect(_start)
	var start_margin := MarginContainer.new()
	start_margin.add_theme_constant_override("margin_left", int(8 * UIKit.scale()))
	start_margin.add_theme_constant_override("margin_right", int(8 * UIKit.scale()))
	start_margin.add_child(start)
	right.add_child(start_margin)
	# The base screen grabs this focus after layout; keep it above the fold.
	first_focus = _game_option

	_refresh_game()
	_refresh_character()


func _setting_row(id: String, caption: String, control: Control, numeric := false, compact := false) -> MarginContainer:
	var row := MarginContainer.new()
	row.name = id + "Row"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	var padding := int(8 * UIKit.scale())
	for edge in ["left", "top", "right", "bottom"]:
		row.add_theme_constant_override("margin_" + edge, padding)
	var content := BoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", int(16 * UIKit.scale()))
	row.add_child(content)
	var label := UIKit.label(caption)
	label.name = id + "Label"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.layout_direction = row.layout_direction
	label.text_direction = Control.TEXT_DIRECTION_RTL if Loc.is_rtl() else Control.TEXT_DIRECTION_LTR
	# Godot mirrors leading alignment when the control layout is RTL.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(label)
	control.name = id + ("Toggle" if compact else "Option")
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.layout_direction = row.layout_direction
	if control is OptionButton:
		var option := control as OptionButton
		option.fit_to_longest_item = false
		option.clip_text = true
		option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		option.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_form_button(option)
		option.text_direction = Control.TEXT_DIRECTION_LTR if numeric or not Loc.is_rtl() else Control.TEXT_DIRECTION_RTL
		for item in option.item_count:
			option.get_popup().set_item_text_direction(item, option.text_direction)
		option.get_popup().add_theme_font_size_override("font_size", int(UIKit.SIZE_BODY * UIKit.scale()))
		option.resized.connect(func(): _fit_option_text(option))
		option.item_selected.connect(func(_index): _fit_option_text(option))
	content.add_child(control)
	# Use the allocated width too: landscape can still have a narrow settings column.
	var fit := func():
		var stacked := not compact and (row.get_viewport_rect().size.x < row.get_viewport_rect().size.y or row.size.x < 560 * UIKit.scale())
		content.vertical = stacked
		label.custom_minimum_size.x = 0 if stacked or compact else 180 * UIKit.scale()
		if compact:
			control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		else:
			control.custom_minimum_size = Vector2(0 if stacked else 300 * UIKit.scale(), FORM_FIELD_HEIGHT * UIKit.scale())
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if stacked else Control.SIZE_SHRINK_END
	row.resized.connect(fit)
	row.tree_entered.connect(func():
		row.get_viewport().size_changed.connect(fit)
		fit.call())
	row.tree_exiting.connect(func(): row.get_viewport().size_changed.disconnect(fit))
	return row


func _fit_option_text(option: OptionButton) -> void:
	if option.item_count == 0 or option.size.x <= 0:
		return
	var caption := option.get_item_text(option.selected)
	option.tooltip_text = caption
	var style := option.get_theme_stylebox("normal")
	var arrow := option.get_theme_icon("arrow")
	var inset := style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
	var available := maxf(1.0, option.size.x - inset - arrow.get_width() - 12 * UIKit.scale())
	var font := option.get_theme_font("font")
	var maximum := int(UIKit.SIZE_BODY * UIKit.scale())
	var minimum := int(UIKit.SIZE_TINY * UIKit.scale())
	var fitted := maximum
	while fitted > minimum and font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > available:
		fitted -= 1
	option.add_theme_font_size_override("font_size", fitted)


func _style_form_button(button: Button) -> void:
	var styles := {
		"normal": UIKit.liquid_glass_stylebox(UIKit.PANEL, 8),
		"hover": UIKit.liquid_glass_stylebox(UIKit.PANEL_HI, 8, true),
		"pressed": UIKit.stylebox(UIKit.PANEL_HI, 8),
		"focus": UIKit.stylebox(UIKit.PANEL_HI, 8, 2, UIKit.ACCENT),
		"disabled": UIKit.liquid_glass_stylebox(UIKit.PANEL, 8),
	}
	for state in styles:
		var style: StyleBoxFlat = styles[state]
		style.content_margin_left = 20 * UIKit.scale()
		style.content_margin_right = 20 * UIKit.scale()
		style.content_margin_top = 10 * UIKit.scale()
		style.content_margin_bottom = 10 * UIKit.scale()
		button.add_theme_stylebox_override(state, style)
		if button is OptionButton and state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state + "_mirrored", style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, UIKit.text_color())


func _picker(parent: VBoxContainer, on_step: Callable) -> Control:
	var row := UIKit.hbox(12)
	var prev := UIKit.icon_button("‹", "")
	prev.pressed.connect(func(): on_step.call(-1))
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(320, 160)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var next := UIKit.icon_button("›", "")
	next.pressed.connect(func(): on_step.call(1))
	row.add_child(prev)
	row.add_child(holder)
	row.add_child(next)
	parent.add_child(row)
	return holder


func _cycle_game(step: int) -> void:
	_game_index = wrapi(_game_index + step, 0, _games.size())
	_rounds = _games[_game_index].default_rounds
	_arena_index = 0
	_refresh_game()
	AudioManager.play_ui("ui_move")


func _cycle_character(step: int) -> void:
	_character_index = wrapi(_character_index + step, 0, _characters.size())
	_refresh_character()
	AudioManager.play_ui("ui_move")


func _refresh_game() -> void:
	_game_option.select(_game_index)
	for c in _game_card_holder.get_children():
		c.queue_free()
	var def := _games[_game_index]
	var card := Widgets.minigame_card(def, true)
	_game_card_holder.add_child(card)
	_arena_option.clear()
	for aid in def.arena_ids:
		var a := Registry.arena(aid)
		_arena_option.add_item(a.display_name() if a != null else aid)
	if def.arena_ids.size() > 1:
		_arena_option.add_item(Loc.t("common.random"))
	_arena_option.selected = 0
	if bool(args.get("random_arena", false)):
		_arena_index = randi_range(0, def.arena_ids.size() - 1)
		_arena_option.select(_arena_index)
		args.erase("random_arena")
	_rounds_option.selected = [1, 2, 3, 5].find(def.default_rounds) if [1, 2, 3, 5].has(def.default_rounds) else 0
	_rounds = def.default_rounds
	_laps_row.visible = def.id in ["kart_sprint", "sabaq_sawarikh"]
	_tank_row.visible = def.id == "tank_arena"
	_fit_option_text(_game_option)
	_fit_option_text(_arena_option)


func _refresh_character() -> void:
	for c in _character_card_holder.get_children():
		c.queue_free()
	var character := _characters[_character_index]
	var card := UIKit.panel(UIKit.PANEL, 12)
	var details := UIKit.vbox(8)
	card.add_child(details)
	details.add_child(UIKit.centered(character.display_name(), UIKit.SIZE_HEADING, character.color, true))
	details.add_child(UIKit.centered(Loc.t(character.realm_key), UIKit.SIZE_BODY))
	_character_card_holder.add_child(card)


func _start() -> void:
	var cfg := _build_match_config()
	Progression.set_last_character(cfg.players[0].character_id)
	SceneRouter.start_match(cfg)


func _build_match_config() -> MatchConfig:
	var def := _games[_game_index]
	var me := _characters[_character_index]

	var cfg := MatchConfig.new()
	cfg.minigame_id = def.id
	cfg.context = MatchConfig.Context.QUICK
	cfg.rounds = _rounds
	cfg.rules["race_laps"] = _laps
	cfg.rules["tank_variant"] = _tank_variant
	cfg.allow_powerups = _powerups
	cfg.sudden_death = def.supports_sudden_death
	cfg.seed = randi() & 0x7FFFFFFF
	var rng := RandomNumberGenerator.new()
	rng.seed = cfg.seed
	if _arena_index >= def.arena_ids.size():
		cfg.arena_id = def.arena_ids[rng.randi_range(0, def.arena_ids.size() - 1)]
	else:
		cfg.arena_id = def.arena_ids[_arena_index]

	var p := PlayerConfig.new()
	p.slot = 0
	p.character_id = me.id
	p.is_human = true
	cfg.players.append(p)

	var pool: Array[String] = []
	for c in Registry.characters():
		if c.id != me.id:
			pool.append(c.id)
	var count := clampi(_opponents, maxi(0, def.min_players - 1), def.max_players - 1)
	for i in count:
		var o := PlayerConfig.new()
		o.slot = i + 1
		o.character_id = pool[rng.randi_range(0, pool.size() - 1)] if pool.size() > 0 else me.id
		o.is_human = false
		o.ai_difficulty = _difficulty
		cfg.players.append(o)
		pool.erase(o.character_id)

	return cfg
