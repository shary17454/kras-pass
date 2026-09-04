extends Screen
## Adventure map: five realms, five stages each, with live lock state.
##
## A stage is only enterable when its realm is unlocked and the previous stage
## in that realm is cleared, so there is no path into content that has not been
## earned — and no locked button without a reason printed under it.

var _world_index := 0
var _character_index := 0
var _characters: Array[CharacterData] = []
var _stage_holder: VBoxContainer
var _world_tabs: HBoxContainer


func build() -> void:
	title(Loc.t("adventure.title"))
	header.add_child(_completion_strip())
	_characters = Progression.playable_characters()
	var last := Progression.last_character()
	for i in _characters.size():
		if _characters[i].id == last:
			_character_index = i
	# Open on the first realm with unfinished business.
	var worlds := Registry.worlds()
	for i in worlds.size():
		var wid := String(worlds[i].get("id", ""))
		if Progression.is_world_unlocked(wid):
			var prog := Progression.world_progress(wid)
			_world_index = i
			if int(prog["cleared"]) < int(prog["total"]):
				break

	_world_tabs = UIKit.hbox(10)
	body.add_child(_world_tabs)
	_build_tabs()

	var columns := UIKit.hbox(28)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	_stage_holder = UIKit.vbox(10)
	_stage_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_stage_holder)

	var side := UIKit.vbox(12)
	side.custom_minimum_size = Vector2(320, 0)
	columns.add_child(side)
	side.add_child(UIKit.heading(Loc.t("quick.character")))
	var holder := Control.new()
	holder.name = "CharHolder"
	holder.custom_minimum_size = Vector2(260, 300)
	side.add_child(holder)
	var row := UIKit.hbox(10)
	var prev := UIKit.icon_button("‹", "")
	prev.pressed.connect(func(): _cycle(-1))
	var next := UIKit.icon_button("›", "")
	next.pressed.connect(func(): _cycle(1))
	row.add_child(prev)
	row.add_child(next)
	side.add_child(row)

	_refresh_character()
	_build_stages()


func _completion_strip() -> Control:
	var h := UIKit.hbox(16)
	h.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(UIKit.label("🏆 %d" % Progression.trophies(), UIKit.SIZE_BODY, UIKit.ACCENT, true))
	h.add_child(UIKit.label("%s %.0f%%" % [Loc.t("adventure.completion"), Progression.completion_percent()],
		UIKit.SIZE_BODY, UIKit.ACCENT_2, true))
	return h


func _build_tabs() -> void:
	for c in _world_tabs.get_children():
		c.queue_free()
	var worlds := Registry.worlds()
	for i in worlds.size():
		var w: Dictionary = worlds[i]
		var wid := String(w.get("id", ""))
		var unlocked := Progression.is_world_unlocked(wid)
		var prog := Progression.world_progress(wid)
		var label := "%s  %d/%d" % [Loc.t(String(w.get("name_key", ""))), prog["cleared"], prog["total"]]
		var b := UIKit.button(label if unlocked else "🔒 " + Loc.t(String(w.get("name_key", ""))), UIKit.SIZE_SMALL)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not unlocked
		if unlocked:
			b.pressed.connect(func():
				_world_index = i
				_build_stages()
				_build_tabs())
		else:
			b.tooltip_text = Loc.t("adventure.requires", {"n": w.get("required_trophies", 0)})
		if i == _world_index:
			b.add_theme_stylebox_override("normal", UIKit.stylebox(UIKit.PANEL_HI, 14, 2, UIKit.ACCENT))
		_world_tabs.add_child(b)
		if first_focus == null and unlocked:
			first_focus = b


func _build_stages() -> void:
	for c in _stage_holder.get_children():
		c.queue_free()
	var worlds := Registry.worlds()
	if worlds.is_empty():
		return
	var w: Dictionary = worlds[clampi(_world_index, 0, worlds.size() - 1)]
	var wid := String(w.get("id", ""))
	_stage_holder.add_child(UIKit.heading(Loc.t(String(w.get("name_key", "")))))
	var desc := UIKit.label(Loc.t(String(w.get("desc_key", ""))), UIKit.SIZE_SMALL, UIKit.dim_color())
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stage_holder.add_child(desc)

	var stages: Array = w.get("stages", [])
	var previous_cleared := true
	for i in stages.size():
		var s: Dictionary = stages[i]
		var sid := String(s.get("id", ""))
		var rec := Progression.stage_record(wid, sid)
		var cleared := bool(rec.get("cleared", false))
		var enterable := Progression.is_world_unlocked(wid) and (previous_cleared or cleared or Progression.all_unlocked())
		_stage_holder.add_child(_stage_row(w, s, i, rec, enterable))
		previous_cleared = cleared


func _stage_row(world: Dictionary, stage: Dictionary, index: int, rec: Dictionary, enterable: bool) -> Control:
	var m := Registry.minigame(String(stage.get("game", "")))
	var boss := bool(stage.get("boss", false))
	var card := UIKit.panel(UIKit.PANEL_HI if boss else UIKit.PANEL, 14)
	var h := UIKit.hbox(16)
	card.add_child(h)

	var glyph := UIKit.label("👑" if boss else (m.icon_glyph if m != null else "◆"), UIKit.SIZE_HEADING, UIKit.ACCENT, true)
	glyph.custom_minimum_size = Vector2(60, 0)
	h.add_child(glyph)

	var info := UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := Loc.t(String(stage["name_key"])) if stage.has("name_key") else (m.display_name() if m != null else "?")
	info.add_child(UIKit.label("%d. %s" % [index + 1, name], UIKit.SIZE_BODY, UIKit.text_color(), true))
	var arena := Registry.arena(String(stage.get("arena", "")))
	info.add_child(UIKit.label("%s · %s" % [
		arena.display_name() if arena != null else "",
		Loc.t(PlayerConfig.DIFFICULTY_KEYS[clampi(int(stage.get("difficulty", 1)), 0, 3)]),
	], UIKit.SIZE_TINY, UIKit.dim_color()))
	h.add_child(info)

	var stars := int(rec.get("stars", 0))
	h.add_child(UIKit.label("★".repeat(stars) + "☆".repeat(3 - stars), UIKit.SIZE_BODY, UIKit.ACCENT))

	var play := UIKit.button(Loc.t("adventure.play") if enterable else Loc.t("common.locked"), UIKit.SIZE_SMALL)
	play.custom_minimum_size = Vector2(160, 0)
	play.disabled = not enterable
	if enterable:
		play.pressed.connect(func(): _enter(world, stage))
		if first_focus == null:
			first_focus = play
	h.add_child(play)
	return card


func _enter(world: Dictionary, stage: Dictionary) -> void:
	if _characters.is_empty():
		return
	var me := _characters[_character_index]
	Progression.set_last_character(me.id)
	var session := AdventureSession.new()
	session.setup(world, stage, me.id)
	var cfg := session.build_config()
	if cfg == null:
		AudioManager.play_ui("ui_error")
		return
	SceneRouter.start_match(cfg, Callable(session, "on_match_finished"))


func _cycle(step: int) -> void:
	if _characters.is_empty():
		return
	_character_index = wrapi(_character_index + step, 0, _characters.size())
	_refresh_character()
	AudioManager.play_ui("ui_move")


func _refresh_character() -> void:
	var holder := find_child("CharHolder", true, false)
	if holder == null or _characters.is_empty():
		return
	for c in holder.get_children():
		c.queue_free()
	var card := Widgets.character_card(_characters[_character_index], true, true)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(card)
