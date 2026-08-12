extends Screen
## Lifetime statistics: the summary block, then a per-mini-game breakdown.


func build() -> void:
	title(Loc.t("stats.title"))
	var columns := UIKit.hbox(28)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)

	var left := UIKit.vbox(8)
	left.custom_minimum_size = Vector2(620, 0)
	columns.add_child(left)
	for row in Stats.summary_rows():
		var card := UIKit.panel(UIKit.PANEL, 12)
		var h := UIKit.hbox(16)
		card.add_child(h)
		var l := UIKit.label(Loc.t(String(row["key"])), UIKit.SIZE_BODY)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(UIKit.label(String(row["value"]), UIKit.SIZE_BODY, UIKit.ACCENT, true))
		left.add_child(card)

	var right := UIKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(UIKit.heading(Loc.t("stats.per_game")))
	var scroll_and_grid := Widgets.scroll_grid(1)
	right.add_child(scroll_and_grid[0])
	var grid: GridContainer = scroll_and_grid[1]
	for m in Registry.minigames():
		var entry := Stats.game_entry(m.id)
		var plays := int(entry.get("plays", 0))
		var wins := int(entry.get("wins", 0))
		var card := UIKit.panel(UIKit.PANEL, 12)
		var h := UIKit.hbox(14)
		card.add_child(h)
		h.add_child(UIKit.label(m.icon_glyph, UIKit.SIZE_BODY, UIKit.ACCENT))
		var name := UIKit.label(m.display_name(), UIKit.SIZE_SMALL)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name)
		h.add_child(UIKit.label("%s %d" % [Loc.t("stats.plays"), plays], UIKit.SIZE_TINY, UIKit.dim_color()))
		h.add_child(UIKit.label("%s %d" % [Loc.t("stats.wins"), wins], UIKit.SIZE_TINY, UIKit.OK if wins > 0 else UIKit.dim_color()))
		h.add_child(UIKit.label("%s %d" % [Loc.t("stats.best"), int(entry.get("best", 0))], UIKit.SIZE_TINY, UIKit.ACCENT_2))
		grid.add_child(card)
