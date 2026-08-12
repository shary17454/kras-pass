extends Screen
## Achievements list with live progress bars.
##
## Secret achievements show their name only once earned; everything else shows
## how far along you are, because "50 wins" is a goal and "37/50 wins" is a plan.


func build() -> void:
	title(Loc.t("menu.achievements"))
	header.add_child(UIKit.label(
		Loc.t("achievements.progress", {"n": Achievements.earned_count(), "total": Achievements.total_count()}),
		UIKit.SIZE_BODY, UIKit.ACCENT, true))

	var scroll_and_grid := Widgets.scroll_grid(2)
	body.add_child(scroll_and_grid[0])
	var grid: GridContainer = scroll_and_grid[1]
	var rows := Achievements.rows()
	# Earned first, then closest to completion — the list stays motivating.
	rows.sort_custom(func(a, b):
		if bool(a["unlocked"]) != bool(b["unlocked"]):
			return bool(a["unlocked"])
		return float(a["progress"]) > float(b["progress"]))
	for r in rows:
		grid.add_child(_row(r))


func _row(r: Dictionary) -> Control:
	var unlocked: bool = bool(r["unlocked"])
	var secret: bool = bool(r["secret"]) and not unlocked
	var card := UIKit.panel(UIKit.PANEL_HI if unlocked else UIKit.PANEL, 14)
	card.custom_minimum_size = Vector2(600, 96)
	var h := UIKit.hbox(16)
	card.add_child(h)
	var icon := UIKit.label(String(r["icon"]) if not secret else "❔", UIKit.SIZE_HEADING, UIKit.ACCENT if unlocked else UIKit.dim_color(), true)
	icon.custom_minimum_size = Vector2(56, 0)
	h.add_child(icon)
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UIKit.label(
		String(r["name"]) if not secret else Loc.t("achievements.secret"),
		UIKit.SIZE_BODY, UIKit.text_color() if unlocked else UIKit.dim_color(), true))
	var desc := UIKit.label(String(r["desc"]) if not secret else "", UIKit.SIZE_TINY, UIKit.dim_color())
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	if not unlocked and not secret:
		v.add_child(UIKit.stat_bar(float(r["progress"]), UIKit.ACCENT_2, 420.0))
	elif unlocked:
		v.add_child(UIKit.label(Loc.t("common.unlocked"), UIKit.SIZE_TINY, UIKit.OK))
	return card
