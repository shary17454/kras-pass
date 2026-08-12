extends Screen
## Profile: completion, currency, favourites and the realm-by-realm breakdown.


func build() -> void:
	title(Loc.t("profile.title"))
	var completion := Progression.completion_percent()
	body.add_child(Widgets.progress_row(Loc.t("profile.completion"), "%.1f%%" % completion, completion / 100.0, UIKit.ACCENT))

	var strip := UIKit.hbox(18)
	body.add_child(strip)
	strip.add_child(_tile("🏆", Loc.t("profile.trophies"), str(Progression.trophies())))
	strip.add_child(_tile("💎", Loc.t("profile.gems"), str(Progression.gems())))
	strip.add_child(_tile("🥇", Loc.t("stats.wins"), str(Stats.total_wins())))
	strip.add_child(_tile("🎪", Loc.t("stats.tournaments"), str(Progression.tournaments_won())))
	strip.add_child(_tile("🏅", Loc.t("menu.achievements"), "%d/%d" % [Achievements.earned_count(), Achievements.total_count()]))

	body.add_child(UIKit.heading(Loc.t("adventure.title")))
	for w in Registry.worlds():
		var wid := String(w.get("id", ""))
		var prog := Progression.world_progress(wid)
		var total := maxi(1, int(prog["total"]))
		var locked := not Progression.is_world_unlocked(wid)
		body.add_child(Widgets.progress_row(
			("🔒 " if locked else "") + Loc.t(String(w.get("name_key", ""))),
			"%d/%d  ★%d" % [prog["cleared"], prog["total"], prog["stars"]],
			float(prog["cleared"]) / float(total),
			CharacterData._color(w.get("color", "#ffffff"))))

	var row := UIKit.hbox(14)
	body.add_child(row)
	for entry in [["menu.stats", "stats"], ["menu.achievements", "achievements"], ["menu.rewards", "rewards"]]:
		var b := UIKit.button(Loc.t(String(entry[0])), UIKit.SIZE_SMALL)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): SceneRouter.go_to(String(entry[1])))
		row.add_child(b)
		if first_focus == null:
			first_focus = b


func _tile(glyph: String, label: String, value: String) -> Control:
	var card := UIKit.panel(UIKit.PANEL, 14)
	card.custom_minimum_size = Vector2(200, 120)
	var v := UIKit.vbox(2)
	card.add_child(v)
	v.add_child(UIKit.centered(glyph, UIKit.SIZE_HEADING))
	v.add_child(UIKit.centered(value, UIKit.SIZE_HEADING, UIKit.ACCENT, true))
	v.add_child(UIKit.centered(label, UIKit.SIZE_TINY, UIKit.dim_color()))
	return card
