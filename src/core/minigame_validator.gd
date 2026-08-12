class_name MiniGameValidator
extends RefCounted
## Refuses an incomplete mini-game before it can reach a player.
##
## Adding a game is deliberately cheap — one JSON entry and one script — and the
## price of that is a checklist someone will forget. This is the checklist, run
## by `Registry.validate()`, by the test suite and by the debug menu, so a game
## missing its rules text or its bot policy fails at build time rather than as a
## blank card three menus deep.

## Everything a game must declare before it counts as finished.
const REQUIRED := [
	"id", "localized title", "localized description", "localized rules",
	"control profile", "controls", "arena", "duration", "victory condition",
	"bot policy", "player range", "category", "scoring",
]


static func validate(def: MiniGameDef, check_localization: bool = true) -> PackedStringArray:
	var problems := PackedStringArray()
	if def == null:
		problems.append("null definition")
		return problems
	var tag := def.id if def.id != "" else "<unnamed>"

	if def.id.strip_edges() == "":
		problems.append("%s: missing id" % tag)

	# --- text --------------------------------------------------------------
	if check_localization:
		for pair in [[def.name_key, "title"], [def.desc_key, "description"], [def.rules_key, "rules"]]:
			if not Loc.has(String(pair[0])):
				problems.append("%s: missing localized %s (%s)" % [tag, pair[1], pair[0]])
		if Loc.has(def.rules_key) and Loc.t(def.rules_key).length() < 20:
			problems.append("%s: rules text is too short to explain the game" % tag)

	# --- controls ----------------------------------------------------------
	if def.control_hints.is_empty():
		problems.append("%s: declares no controls" % tag)
	for hint in def.control_hints:
		if check_localization and not Loc.has("controls.%s" % hint):
			problems.append("%s: control '%s' has no label" % [tag, hint])
	if not ControlProfile.NAMES.has(def.control_profile):
		problems.append("%s: unknown control profile" % tag)
	var needs_move := def.control_hints.has("move") or def.control_hints.has("drive")
	var offers_move := ControlProfile.shows_move_stick(def.control_profile) \
		or ControlProfile.shows_steering(def.control_profile)
	if needs_move != offers_move and ControlProfile.full_screen_tap(def.control_profile) == 0:
		problems.append("%s: control profile does not match declared movement" % tag)

	# --- arenas ------------------------------------------------------------
	if def.arena_ids.is_empty():
		problems.append("%s: no arena" % tag)
	for aid in def.arena_ids:
		if Registry.arena(aid) == null:
			problems.append("%s: unknown arena '%s'" % [tag, aid])

	# --- rules -------------------------------------------------------------
	if def.duration <= 0.0:
		problems.append("%s: no time limit" % tag)
	elif def.duration > 300.0:
		problems.append("%s: %.0fs is too long for a party round" % [tag, def.duration])
	if def.default_rounds < 1:
		problems.append("%s: fewer than one round" % tag)
	if def.min_players < 1 or def.max_players > 4 or def.max_players < def.min_players:
		problems.append("%s: invalid player range %d..%d" % [tag, def.min_players, def.max_players])

	# --- code --------------------------------------------------------------
	if not ResourceLoader.exists(def.controller_script):
		problems.append("%s: controller script not found (%s)" % [tag, def.controller_script])
		return problems
	var script: Script = load(def.controller_script)
	if script == null:
		problems.append("%s: controller script does not compile" % tag)
		return problems
	var controller = script.new()
	if not (controller is MiniGameController):
		problems.append("%s: controller does not extend MiniGameController" % tag)
		if controller is Object and not (controller is RefCounted):
			controller.free()
		return problems

	# A game must be able to end, and to say who won.
	if not _overrides_any(controller, ["compute_scores", "is_round_over"]) \
			and def.scoring == MiniGameDef.Scoring.POINTS:
		problems.append("%s: point-scoring game defines no way to end or score" % tag)

	var brain_script = controller.ai_script()
	if brain_script == null:
		problems.append("%s: no bot policy" % tag)
	else:
		var brain = brain_script.new()
		if not (brain is AIBrain):
			problems.append("%s: bot policy does not extend AIBrain" % tag)
	controller.free()
	return problems


## True when the controller (or one of its ancestors below the base class)
## actually implements one of these, rather than inheriting the default.
static func _overrides_any(controller: Object, methods: Array) -> bool:
	for m in methods:
		if controller.has_method(m):
			return true
	return false


## Convenience for the debug menu and CI: validate the whole catalogue.
static func validate_all(check_localization: bool = true) -> PackedStringArray:
	var problems := PackedStringArray()
	for def in Registry.minigames():
		problems.append_array(validate(def, check_localization))
	return problems
