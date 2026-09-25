extends Screen
## Tournament standings between games, and the champion screen at the end.

var session: TournamentSession
var last: MatchResult


func setup(a: Dictionary) -> void:
	session = a.get("session")
	last = a.get("last")
	super.setup(a)
	AudioManager.play_music("victory" if session != null and session.is_complete() else "menu")


func build() -> void:
	if session == null:
		title(Loc.t("tournament.title"))
		body.add_child(UIKit.centered(Loc.t("common.loading"), UIKit.SIZE_BODY, UIKit.dim_color()))
		var home := UIKit.button(Loc.t("results.quit"))
		home.pressed.connect(func(): SceneRouter.go_to("main_menu", {}, false))
		body.add_child(home)
		first_focus = home
		return

	title(Loc.t("tournament.standings"))
	if session.is_complete():
		var champ := session.champion()
		var headline := UIKit.centered(
			Loc.t("tournament.champion", {"name": session.players[champ].display_name()}) if champ >= 0 else Loc.t("party.shared_cup"),
			UIKit.SIZE_HEADING, UIKit.ACCENT, true)
		headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(headline)
		var podium := TournamentPodium.new()
		body.add_child(podium)
		podium.setup(session)
		for award in session.fun_awards():
			var names: Array[String] = []
			for slot in award["slots"]:
				names.append(session.players[slot].display_name())
			var label := UIKit.centered(Loc.t(award["key"]) + ": " + " · ".join(names), UIKit.SIZE_SMALL, UIKit.ACCENT_2)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_child(label)
	elif not session.tiebreak_slots.is_empty():
		body.add_child(UIKit.centered(Loc.t("party.tiebreak"), UIKit.SIZE_HEADING, UIKit.ACCENT))
	else:
		body.add_child(UIKit.centered(
			Loc.t("tournament.game_of", {"n": session.index + 1, "total": session.total_games()}),
			UIKit.SIZE_HEADING, UIKit.dim_color()))

	var scroll_and_grid := Widgets.scroll_grid(1)
	body.add_child(scroll_and_grid[0])
	var grid: GridContainer = scroll_and_grid[1]
	for row in session.rows():
		var card := Widgets.standings_row(
			int(row["rank"]), String(row["name"]), row["color"],
			"%d %s" % [int(row["points"]), Loc.t("tournament.points")],
			bool(row["human"]))
		grid.add_child(card)
		UIKit.animate_in(card, 0.05 * int(row["rank"]))

	if last != null:
		var awarded := session.last_awards
		var line: Array[String] = []
		for slot in awarded.size():
			if awarded[slot] > 0:
				line.append("%s +%d" % [session.players[slot].display_name(), awarded[slot]])
		body.add_child(UIKit.centered("   ·   ".join(line), UIKit.SIZE_SMALL, UIKit.ACCENT_2))

	if not session.is_complete():
		body.add_child(_schedule_strip())
	if not session.is_complete():
		var next_game := session.current_game()
		body.add_child(UIKit.centered(next_game.display_name(), UIKit.SIZE_HEADING, UIKit.ACCENT_2))
		if session.double_final and session.index == session.total_games() - 1:
			body.add_child(UIKit.centered(Loc.t("party.double_final"), UIKit.SIZE_BODY, UIKit.ACCENT))
	_add_actions()


func _schedule_strip() -> Control:
	var h := GridContainer.new()
	h.columns = 1 if get_viewport_rect().size.x < get_viewport_rect().size.y else 3
	var fit := func(): h.columns = 1 if get_viewport_rect().size.x < get_viewport_rect().size.y else 3
	get_viewport().size_changed.connect(fit)
	h.tree_exiting.connect(func(): get_viewport().size_changed.disconnect(fit))
	for i in session.game_ids.size():
		var m := Registry.minigame(session.game_ids[i])
		var played := i < session.index
		var l := UIKit.label("%s %s" % [m.icon_glyph if m != null else "◆", m.display_name() if m != null else "?"],
			UIKit.SIZE_TINY, UIKit.OK if played else UIKit.dim_color())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
	return h


func _add_actions() -> void:
	var row := UIKit.adaptive_columns(14)
	body.add_child(row)
	if session.is_complete():
		var again := UIKit.button(Loc.t("results.rematch"), UIKit.SIZE_BODY)
		again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		again.pressed.connect(func():
			var fresh := session.rematch()
			fresh.checkpoint()
			SceneRouter.start_match(fresh.next_config(), Callable(fresh, "on_match_finished")))
		row.add_child(again)
		first_focus = again
	else:
		var next := UIKit.button(Loc.t("tournament.next_game"), UIKit.SIZE_HEADING)
		next.custom_minimum_size = Vector2(0, 72)
		next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next.pressed.connect(_play_next)
		row.add_child(next)
		first_focus = next
	var quit := UIKit.button(Loc.t("results.quit"), UIKit.SIZE_BODY)
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit.pressed.connect(func(): SceneRouter.go_to("main_menu", {}, false))
	row.add_child(quit)


func _play_next() -> void:
	var cfg := session.next_config()
	if cfg == null:
		SceneRouter.go_to("main_menu", {}, false)
		return
	session.checkpoint()
	# The Callable holds the session, which is what keeps it alive across the
	# match; nothing global is involved.
	SceneRouter.start_match(cfg, Callable(session, "on_match_finished"))


func go_back() -> void:
	SceneRouter.go_to("main_menu", {}, false)
