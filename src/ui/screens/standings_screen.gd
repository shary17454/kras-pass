extends Screen
## Tournament standings between games, and the champion screen at the end.

var session: TournamentSession
var last: MatchResult


func setup(a: Dictionary) -> void:
	session = a.get("session")
	last = a.get("last")
	super.setup(a)
	SceneRouter.prefetch_from_screen(self, session.next_config() if session != null else null)
	AudioManager.play_music("victory" if session != null and session.is_complete() else "menu")


func build() -> void:
	if session == null:
		title(Loc.t("tournament.title"))
		body.add_child(_wrapped_centered(Loc.t("common.loading"), UIKit.SIZE_BODY, UIKit.dim_color()))
		var home := UIKit.button(Loc.t("results.quit"))
		home.pressed.connect(func(): SceneRouter.go_to("main_menu", {}, false))
		body.add_child(home)
		first_focus = home
		return

	title(Loc.t("tournament.standings"))
	var results_parent: Control = body
	if session.is_complete():
		var columns := UIKit.adaptive_columns(24)
		columns.name = "ChampionColumns"
		columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(columns)
		var summary := UIKit.vbox(12)
		summary.name = "ChampionSummary"
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(summary)
		results_parent = columns
		var champ := session.champion()
		var headline := UIKit.centered(
			Loc.t("tournament.champion", {"name": session.players[champ].display_name()}) if champ >= 0 else Loc.t("party.shared_cup"),
			UIKit.SIZE_HEADING, UIKit.ACCENT, true)
		headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_child(headline)
		var podium := TournamentPodium.new()
		summary.add_child(podium)
		podium.setup(session)
		podium.custom_minimum_size.y = 180 * UIKit.scale()
		for award in session.fun_awards():
			var names: Array[String] = []
			for slot in award["slots"]:
				names.append(session.players[slot].display_name())
			var label := UIKit.centered(Loc.t(award["key"]) + ": " + " · ".join(names), UIKit.SIZE_SMALL, UIKit.ACCENT_2)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			summary.add_child(label)
	elif not session.tiebreak_slots.is_empty():
		body.add_child(_wrapped_centered(Loc.t("party.tiebreak"), UIKit.SIZE_HEADING, UIKit.ACCENT))
	else:
		body.add_child(_wrapped_centered(
			Loc.t("tournament.game_of", {"n": session.index + 1, "total": session.total_games()}),
			UIKit.SIZE_HEADING, UIKit.dim_color()))

	# Screen already provides scrolling; nested scrolling can collapse to a sliver.
	var grid := UIKit.vbox(12)
	grid.name = "StandingsRows"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_parent.add_child(grid)
	for row in session.rows():
		var card := Widgets.standings_row(
			int(row["rank"]), String(row["name"]), row["color"],
			"%d %s" % [int(row["points"]), Loc.t(session.score_label_key())],
			bool(row["human"]))
		_fit_standings_row(card)
		grid.add_child(card)
		UIKit.animate_in(card, 0.05 * int(row["rank"]))

	if last != null:
		var awarded := session.last_awards
		var line: Array[String] = []
		for slot in awarded.size():
			if awarded[slot] > 0:
				line.append("%s +%d" % [session.players[slot].display_name(), awarded[slot]])
		body.add_child(_wrapped_centered("   ·   ".join(line), UIKit.SIZE_SMALL, UIKit.ACCENT_2))

	if not session.is_complete():
		body.add_child(_schedule_strip())
	if not session.is_complete():
		var next_game := session.current_game()
		body.add_child(_wrapped_centered(next_game.display_name(), UIKit.SIZE_HEADING, UIKit.ACCENT_2))
		if session.double_final and session.index == session.total_games() - 1:
			body.add_child(_wrapped_centered(Loc.t("party.double_final"), UIKit.SIZE_BODY, UIKit.ACCENT))
	_add_actions()


func _wrapped_centered(text: String, size: int, color: Color) -> Label:
	var label := UIKit.centered(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _schedule_strip() -> Control:
	var h := GridContainer.new()
	h.name = "StandingsSchedule"
	var fit := func():
		h.columns = clampi(int(h.size.x / (320.0 * UIKit.scale())), 1, 3)
	h.resized.connect(fit)
	for i in session.game_ids.size():
		var m := Registry.minigame(session.game_ids[i])
		var played := i < session.index
		var l := UIKit.label("%s %s" % [m.icon_glyph if m != null else "◆", m.display_name() if m != null else "?"],
			UIKit.SIZE_TINY, UIKit.OK if played else UIKit.dim_color())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
	return h


func _fit_standings_row(card: Control) -> void:
	# Retain the shared row's styling and identity, but let the score move below
	# the player on compact layouts instead of forcing the whole screen wider.
	var player_line := card.get_child(0) as HBoxContainer
	var score := player_line.get_child(player_line.get_child_count() - 1) as Label
	player_line.remove_child(score)
	card.remove_child(player_line)
	var layout := UIKit.adaptive_columns(12)
	card.add_child(layout)
	player_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(player_line)
	score.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(score)


func _add_actions() -> void:
	var row := UIKit.adaptive_columns(14)
	row.name = "StandingsActions"
	body.get_parent().get_parent().add_child(row)
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
