extends Screen
## The hub. Two columns: modes on one side, the player's standing on the other.
##
## Every mode entry either works or is visibly, explainedly unavailable — there
## are no buttons here that do nothing.


func setup(a: Dictionary) -> void:
	super.setup(a)
	AudioManager.play_music("menu")
	SceneRouter.clear_stack()


func build() -> void:
	title(Loc.t("app.title"), false)
	header.add_child(_currency_strip())

	var columns := UIKit.hbox(36)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)

	var modes := UIKit.vbox(10)
	modes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var side := UIKit.vbox(14)
	side.custom_minimum_size = Vector2(520, 0)

	if Loc.is_rtl():
		columns.add_child(side)
		columns.add_child(modes)
	else:
		columns.add_child(modes)
		columns.add_child(side)

	_add_mode(modes, "menu.adventure", "adventure")
	_add_mode(modes, "menu.quick_play", "quick_play")
	_add_mode(modes, "menu.tournament", "tournament")
	_add_mode(modes, "menu.local", "local_play")
	_add_mode(modes, "menu.online", "online")
	_add_mode(modes, "menu.training", "training")
	_add_mode(modes, "menu.daily", "daily")

	var secondary := UIKit.hbox(10)
	modes.add_child(secondary)
	for entry in [["menu.characters", "characters"], ["menu.achievements", "achievements"],
			["replay.title", "replays"], ["menu.stats", "stats"], ["menu.settings", "settings"]]:
		var b := UIKit.button(Loc.t(String(entry[0])), UIKit.SIZE_SMALL)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): SceneRouter.go_to(String(entry[1])))
		secondary.add_child(b)

	side.add_child(_profile_card())
	side.add_child(_next_up_card())


func _add_mode(parent: VBoxContainer, key: String, screen: String) -> void:
	var b := UIKit.button(Loc.t(key), UIKit.SIZE_HEADING)
	b.custom_minimum_size = Vector2(0, 72)
	b.pressed.connect(func(): SceneRouter.go_to(screen))
	parent.add_child(b)
	if first_focus == null:
		first_focus = b


func _currency_strip() -> Control:
	var h := UIKit.hbox(18)
	h.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(UIKit.label("🏆 %d" % Progression.trophies(), UIKit.SIZE_BODY, UIKit.ACCENT, true))
	h.add_child(UIKit.label("💎 %d" % Progression.gems(), UIKit.SIZE_BODY, UIKit.ACCENT_2, true))
	return h


func _profile_card() -> Control:
	var card := UIKit.panel(UIKit.PANEL, 20)
	var v := UIKit.vbox(10)
	card.add_child(v)
	v.add_child(UIKit.label(Loc.t("profile.title"), UIKit.SIZE_HEADING, UIKit.text_color(), true))
	var completion := Progression.completion_percent()
	v.add_child(Widgets.progress_row(Loc.t("adventure.completion"), "%.0f%%" % completion, completion / 100.0, UIKit.ACCENT))
	v.add_child(Widgets.progress_row(
		Loc.t("menu.achievements"),
		Loc.t("achievements.progress", {"n": Achievements.earned_count(), "total": Achievements.total_count()}),
		float(Achievements.earned_count()) / maxf(1.0, float(Achievements.total_count())),
		UIKit.ACCENT_2))
	v.add_child(Widgets.progress_row(
		Loc.t("menu.characters"),
		"%d / %d" % [Progression.unlocked_characters().size(), Registry.characters().size()],
		float(Progression.unlocked_characters().size()) / maxf(1.0, float(Registry.characters().size())),
		UIKit.OK))
	var stats_button := UIKit.button(Loc.t("menu.stats"), UIKit.SIZE_SMALL)
	stats_button.pressed.connect(func(): SceneRouter.go_to("stats"))
	v.add_child(stats_button)
	return card


## Points at the next thing worth doing, so a returning player is never staring
## at a menu wondering where they left off.
func _next_up_card() -> Control:
	var card := UIKit.panel(UIKit.PANEL_HI, 20)
	var v := UIKit.vbox(8)
	card.add_child(v)
	v.add_child(UIKit.label(Loc.t("menu.adventure"), UIKit.SIZE_BODY, UIKit.ACCENT, true))
	var target := _next_stage()
	if target.is_empty():
		v.add_child(UIKit.label(Loc.t("achievement.adventure_done.name"), UIKit.SIZE_SMALL, UIKit.OK))
	else:
		v.add_child(UIKit.label("%s — %s" % [
			Loc.t(String(target["world_name"])),
			String(target["stage_name"]),
		], UIKit.SIZE_SMALL, UIKit.dim_color()))
		var go := UIKit.button(Loc.t("adventure.play"), UIKit.SIZE_SMALL)
		go.pressed.connect(func(): SceneRouter.go_to("adventure"))
		v.add_child(go)
	return card


func _next_stage() -> Dictionary:
	for w in Registry.worlds():
		var wid := String(w.get("id", ""))
		if not Progression.is_world_unlocked(wid):
			continue
		for s in w.get("stages", []):
			var sid := String(s.get("id", ""))
			if Progression.is_stage_cleared(wid, sid):
				continue
			var m := Registry.minigame(String(s.get("game", "")))
			return {
				"world_name": String(w.get("name_key", "")),
				"stage_name": m.display_name() if m != null else sid,
			}
	return {}


func go_back() -> void:
	# The main menu is the root: back means quit, with no dead end above it.
	SaveSystem.flush()
	get_tree().quit()
