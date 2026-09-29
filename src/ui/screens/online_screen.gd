extends Screen
## Online entry point. Network transport is intentionally unavailable until a
## real matchmaking/relay service is configured; this screen never simulates a
## remote room with local bots.


func build() -> void:
	title(Loc.t("online.title"))
	var notice := UIKit.label(Loc.t("online.unavailable"), UIKit.SIZE_BODY, UIKit.ACCENT)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(notice)

	var local := UIKit.button(Loc.t("online.play_local"), UIKit.SIZE_HEADING)
	local.pressed.connect(func(): SceneRouter.go_to("local_play"))
	body.add_child(local)
	first_focus = local

	for key in ["online.create", "online.join", "online.quick_match", "online.friends"]:
		var action := UIKit.button(Loc.t(key))
		action.disabled = true
		action.tooltip_text = Loc.t("common.soon")
		body.add_child(action)
