extends Screen
## Rewards: the completion tiers and what each one pays out.
##
## Claiming is automatic on reaching a tier; this screen exists so the player can
## see what is coming, which is what makes the 75% grind feel deliberate.

const BRANCH := "rewards_claimed"


func setup(a: Dictionary) -> void:
	_claim_due()
	super.setup(a)


func build() -> void:
	title(Loc.t("rewards.title"))
	var completion := Progression.completion_percent()
	body.add_child(Widgets.progress_row(Loc.t("adventure.completion"), "%.1f%%" % completion, completion / 100.0, UIKit.ACCENT))

	var claimed: Dictionary = SaveSystem.profile().get(BRANCH, {})
	var next_tier := -1
	for tier in Balance.list("adventure", "completion_rewards"):
		var pct := float(tier.get("percent", 0))
		var done := claimed.has(str(pct))
		if not done and next_tier < 0:
			next_tier = int(pct)
		body.add_child(_tier_row(tier, done, completion))

	if next_tier > 0:
		body.add_child(UIKit.label(Loc.t("rewards.next_at", {"n": next_tier}), UIKit.SIZE_BODY, UIKit.ACCENT_2, true))

	body.add_child(UIKit.spacer(20))
	body.add_child(UIKit.heading(Loc.t("menu.characters")))
	var grid_pair := Widgets.scroll_grid(4)
	body.add_child(grid_pair[0])
	var grid: GridContainer = grid_pair[1]
	for c in Registry.characters():
		grid.add_child(Widgets.character_card(c, Progression.is_character_unlocked(c.id)))


func _tier_row(tier: Dictionary, claimed: bool, completion: float) -> Control:
	var pct := float(tier.get("percent", 0))
	var reached := completion >= pct
	var card := UIKit.panel(UIKit.PANEL_HI if reached else UIKit.PANEL, 14)
	var h := UIKit.hbox(16)
	card.add_child(h)
	h.add_child(UIKit.label("%d%%" % int(pct), UIKit.SIZE_HEADING, UIKit.ACCENT if reached else UIKit.dim_color(), true))
	var describe := ""
	match String(tier.get("type", "")):
		"gems":
			describe = "💎 %d %s" % [tier.get("amount", 0), Loc.t("rewards.gems")]
		"character":
			var c := Registry.character(String(tier.get("id", "")))
			describe = "◆ %s" % (c.display_name() if c != null else String(tier.get("id", "")))
		"arena_gold":
			var a := Registry.arena(String(tier.get("id", "")))
			describe = "★ %s" % (a.display_name() if a != null else String(tier.get("id", "")))
		_:
			describe = String(tier.get("type", ""))
	var l := UIKit.label(describe, UIKit.SIZE_BODY)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UIKit.label(Loc.t("rewards.claimed") if claimed else Loc.t("common.locked"),
		UIKit.SIZE_SMALL, UIKit.OK if claimed else UIKit.dim_color()))
	return card


## Grants any tier the player has reached but not yet been paid for. Idempotent,
## so it is safe to call every time the screen opens.
func _claim_due() -> void:
	var profile := SaveSystem.profile()
	var claimed: Dictionary = profile.get(BRANCH, {})
	var completion := Progression.completion_percent()
	var changed := false
	for tier in Balance.list("adventure", "completion_rewards"):
		var pct := float(tier.get("percent", 0))
		if completion < pct or claimed.has(str(pct)):
			continue
		claimed[str(pct)] = true
		changed = true
		match String(tier.get("type", "")):
			"gems":
				Progression.grant_gems(int(tier.get("amount", 0)))
			"character":
				Progression.unlock_character(String(tier.get("id", "")))
			_:
				EventBus.notify(Loc.t("rewards.title"), "★")
	if changed:
		profile[BRANCH] = claimed
		SaveSystem.set_profile(profile)
		SaveSystem.flush()
		AudioManager.play_ui("unlock")
