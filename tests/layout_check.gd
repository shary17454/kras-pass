extends Node
## Guards against screens that build correctly but land off-screen.
##
## This needs a real window and cannot move into `test_runner.tscn`: the entry
## animation early-returns under the headless display server, so the whole
## class of "the layout is fine but something parked it outside the viewport"
## bug is invisible to the headless suite by construction. That is how a boot
## screen that rendered nothing but the background colour shipped — the game
## played its music, every assertion passed, and the player saw black.
##
## Arabic is the default locale on an Arabic system and RTL is where this fails
## first: a stale pre-layout position reads as (0, 0) under LTR, which merely
## nudges the screen, but as the far right edge under RTL, which throws all of
## it out of view. Both directions are checked so neither regresses alone.
##
##   godot --path . tests/layout_check.tscn
##
## Exits non-zero when anything with a drawable rect sits fully outside the
## viewport horizontally. Vertical overflow is legitimate — the long screens put
## their content in a ScrollContainer — so only the horizontal axis is fatal.

# These need a live match, a finished result or a stored replay to open.
const NEEDS_ARGS := ["match", "results", "replay_player", "standings"]
const SETTLE_FRAMES := 40

var _failures: Array[String] = []
var _checked := 0


func _ready() -> void:
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for id in SceneRouter.SCREENS.keys():
			var screen_id := String(id)
			if screen_id in NEEDS_ARGS:
				continue
			SceneRouter.go_to(screen_id, {}, false, 0.0)
			for i in SETTLE_FRAMES:
				await get_tree().process_frame
			if SceneRouter.current_node == null:
				_failures.append("%s/%s never opened" % [locale, screen_id])
				continue
			_checked += 1
			_scan(SceneRouter.current_node, "%s/%s" % [locale, screen_id])

	print("layout check: %d screens" % _checked)
	if _failures.is_empty():
		print("OK — every screen renders inside the viewport")
		get_tree().quit(0)
		return
	for f in _failures:
		print("  off-screen: %s" % f)
	print("FAILED — %d control(s) outside the viewport" % _failures.size())
	get_tree().quit(1)


func _scan(node: Node, label: String) -> void:
	var view := get_viewport().get_visible_rect()
	if node is Control:
		var c := node as Control
		var r := c.get_global_rect()
		# Zero-sized spacers and hidden branches draw nothing, so they cannot
		# be the reason a player sees an empty screen.
		if c.is_visible_in_tree() and r.size.x > 1.0 and r.size.y > 1.0:
			if r.position.x >= view.end.x or r.end.x <= view.position.x:
				_failures.append("%s :: %s [%s] at %s" % [label, c.name, c.get_class(), str(r)])
	for child in node.get_children():
		_scan(child, label)
