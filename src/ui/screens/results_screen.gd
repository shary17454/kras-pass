extends Screen
## Post-match summary: placement, scores, per-game stats, rewards.
##
## Handles three entry points — quick play, adventure and training — because the
## information a player wants afterwards is the same in all three; only the
## follow-up buttons differ.

var result: MatchResult
var config: MatchConfig
var adventure := {}


func setup(a: Dictionary) -> void:
	result = a.get("result")
	config = a.get("config")
	adventure = a.get("adventure", {})
	super.setup(a)
	AudioManager.play_music("victory" if _player_won() else "menu")


func build() -> void:
	if result == null or config == null:
		title(Loc.t("results.title"))
		body.add_child(UIKit.centered(Loc.t("common.loading"), UIKit.SIZE_BODY, UIKit.dim_color()))
		_add_actions()
		return

	title(Loc.t("results.title"))
	var winners := result.winners()
	var headline := Loc.t("results.draw") if result.is_draw() else Loc.t("results.winner", {
		"name": config.player_at(winners[0]).display_name() if winners.size() > 0 else "—",
	})
	var banner := UIKit.centered(headline, UIKit.SIZE_TITLE, UIKit.ACCENT, true)
	body.add_child(banner)
	UIKit.animate_in(banner, 0.05)

	var columns := UIKit.hbox(32)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)

	var table := UIKit.vbox(10)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(table)
	_build_table(table)

	var side := UIKit.vbox(12)
	side.custom_minimum_size = Vector2(480, 0)
	columns.add_child(side)
	_build_rewards(side)

	_add_actions()


func _build_table(parent: VBoxContainer) -> void:
	var def := config.definition()
	var scroll_and_grid := Widgets.scroll_grid(1)
	var scroll: ScrollContainer = scroll_and_grid[0]
	var grid: GridContainer = scroll_and_grid[1]
	parent.add_child(scroll)
	var order := result.ranking()
	for rank_index in order.size():
		var slot: int = order[rank_index]
		var p := config.player_at(slot)
		if p == null:
			continue
		var value := _score_text(def, slot)
		var row := Widgets.standings_row(result.place_of(slot), p.display_name(), p.color(), value, p.is_human)
		grid.add_child(row)
		UIKit.animate_in(row, 0.06 * rank_index)
		var details := _detail_line(slot)
		if details != "":
			grid.add_child(UIKit.label(details, UIKit.SIZE_TINY, UIKit.dim_color()))


func _score_text(def: MiniGameDef, slot: int) -> String:
	var raw := result.score_of(slot)
	if def != null and def.scoring == MiniGameDef.Scoring.RACE_TIME:
		return "—" if raw >= 99000 else "%.2fs" % (raw / 100.0)
	return str(raw)


func _detail_line(slot: int) -> String:
	var parts: Array[String] = []
	for key in ["knockouts", "falls", "collected", "deposits", "saves", "crates", "correct", "mistakes", "damage"]:
		var v := int(result.detail(slot, key, 0))
		if v > 0:
			parts.append("%s %d" % [Loc.t("results.stat." + key), v])
	return "   ·   ".join(parts)


func _build_rewards(parent: VBoxContainer) -> void:
	var card := UIKit.panel(UIKit.PANEL, 20)
	var v := UIKit.vbox(10)
	card.add_child(v)
	v.add_child(UIKit.label(Loc.t("results.rewards"), UIKit.SIZE_HEADING, UIKit.text_color(), true))

	if not adventure.is_empty():
		var stars := int(adventure.get("stars", 0))
		v.add_child(UIKit.label("★".repeat(stars) + "☆".repeat(3 - stars), UIKit.SIZE_HEADING, UIKit.ACCENT, true))
		if bool(adventure.get("newly_cleared", false)):
			v.add_child(UIKit.label("🏆 +1 " + Loc.t("rewards.trophies"), UIKit.SIZE_BODY, UIKit.ACCENT))
		v.add_child(UIKit.label("💎 +%d %s" % [adventure.get("gems", 0), Loc.t("rewards.gems")], UIKit.SIZE_BODY, UIKit.ACCENT_2))
	else:
		v.add_child(UIKit.label("💎 %d" % Progression.gems(), UIKit.SIZE_BODY, UIKit.ACCENT_2))
		v.add_child(UIKit.label("🏆 %d" % Progression.trophies(), UIKit.SIZE_BODY, UIKit.ACCENT))

	var human := config.human_slots()
	if human.size() > 0:
		var me: int = human[0]
		var entry := Stats.game_entry(config.minigame_id)
		if result.score_of(me) >= int(entry.get("best", 0)) and result.score_of(me) > 0:
			v.add_child(UIKit.label(Loc.t("results.new_record"), UIKit.SIZE_BODY, UIKit.OK, true))

	var rounds := result.rounds
	if rounds.size() > 1:
		v.add_child(UIKit.label(Loc.t("hud.round_of", {"n": rounds.size(), "total": rounds.size()}), UIKit.SIZE_SMALL, UIKit.dim_color()))
		for i in rounds.size():
			var r: MatchResult = rounds[i]
			var winner := r.winners()
			var name := config.player_at(winner[0]).display_name() if winner.size() > 0 else "—"
			v.add_child(UIKit.label("%s %d — %s" % [Loc.t("hud.round", {"n": i + 1}), i + 1, name], UIKit.SIZE_TINY, UIKit.dim_color()))
	parent.add_child(card)


func _add_actions() -> void:
	var row := UIKit.hbox(14)
	body.add_child(row)
	if not adventure.is_empty():
		var back_to_map := UIKit.button(Loc.t("adventure.title"), UIKit.SIZE_BODY)
		back_to_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		back_to_map.pressed.connect(func(): SceneRouter.go_to("adventure", {}, false))
		row.add_child(back_to_map)
		first_focus = back_to_map
	if config != null:
		var again := UIKit.button(Loc.t("results.rematch"), UIKit.SIZE_BODY)
		again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		again.pressed.connect(_rematch)
		row.add_child(again)
		if first_focus == null:
			first_focus = again
	var menu := UIKit.button(Loc.t("results.quit"), UIKit.SIZE_BODY)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(func(): SceneRouter.go_to("main_menu", {}, false))
	row.add_child(menu)
	if first_focus == null:
		first_focus = menu


func _rematch() -> void:
	var fresh := MatchConfig.new()
	fresh.minigame_id = config.minigame_id
	fresh.arena_id = config.arena_id
	fresh.context = config.context
	fresh.rounds = config.rounds
	fresh.allow_powerups = config.allow_powerups
	fresh.sudden_death = config.sudden_death
	fresh.subtitle_key = config.subtitle_key
	fresh.seed = randi() & 0x7FFFFFFF
	fresh.players = config.players.duplicate()
	SceneRouter.start_match(fresh)


func _player_won() -> bool:
	if result == null or config == null:
		return false
	var human := config.human_slots()
	return human.size() > 0 and result.place_of(human[0]) == 1


func go_back() -> void:
	SceneRouter.go_to("main_menu", {}, false)
