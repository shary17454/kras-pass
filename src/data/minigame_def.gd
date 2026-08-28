class_name MiniGameDef
extends Resource
## Static description of one mini-game, from `data/minigames.json`.
##
## The definition is what the menus, adventure map and tournament picker read.
## It never contains behaviour — `controller_script` points at the runtime.
## Adding a game means one JSON entry plus one script; nothing else in the
## project needs editing. See docs/adding-a-minigame.md.

enum Category {
	PUSH_OUT,      # knock rivals out of the ring
	BALL_ZONE,     # defend your zone, deflect balls
	VEHICLE,       # drive and wreck
	COLLECT,       # gather scattered value
	CONTROL,       # claim territory
	CRATES,        # smash / carry objects
	RACE,          # first past the post
	REACTION,      # memory and reflex
	SURVIVAL,      # last one standing
	COMBAT,        # light arcade fighting
}

enum Scoring {
	POINTS,        # highest score wins
	SURVIVAL,      # reverse elimination order
	RACE_TIME,     # lowest time wins
	LIVES,         # last with lives remaining
}

const CATEGORY_NAMES := {
	Category.PUSH_OUT: "push_out", Category.BALL_ZONE: "ball_zone",
	Category.VEHICLE: "vehicle", Category.COLLECT: "collect",
	Category.CONTROL: "control", Category.CRATES: "crates",
	Category.RACE: "race", Category.REACTION: "reaction",
	Category.SURVIVAL: "survival", Category.COMBAT: "combat",
}

@export var id := ""
@export var name_key := ""
@export var desc_key := ""
@export var rules_key := ""
@export var category: Category = Category.PUSH_OUT
@export var scoring: Scoring = Scoring.POINTS
@export var controller_script := ""
@export var arena_ids: PackedStringArray = []
@export var min_players := 2
@export var max_players := 4
@export var duration := 90.0
@export var default_rounds := 1
@export var supports_sudden_death := true
@export var supports_teams := false
## Control glyphs shown on the pre-round card, e.g. ["move", "dash", "attack"].
@export var control_hints: PackedStringArray = []
## Which on-screen layout this game wants. See ControlProfile.
@export var control_profile: ControlProfile.Kind = ControlProfile.Kind.MOVEMENT_ACTION
@export var tags: PackedStringArray = []
@export var unlock := {}
@export var difficulty_curve := 1.0  # multiplies AI aggression in adventure
@export var icon_glyph := "◆"
## Championship fights. They are real mini-games and go through the same match
## layer, but they are not part of the rotation: Quick Play, Party, the stats
## table and the completion percentage all count the collection, not the four
## bosses guarding it.
@export var is_boss := false


static func from_dict(d: Dictionary) -> MiniGameDef:
	var m := MiniGameDef.new()
	m.id = String(d.get("id", ""))
	m.name_key = String(d.get("name_key", "game.%s.name" % m.id))
	m.desc_key = String(d.get("desc_key", "game.%s.desc" % m.id))
	m.rules_key = String(d.get("rules_key", "game.%s.rules" % m.id))
	m.category = _category_from(String(d.get("category", "push_out")))
	m.scoring = _scoring_from(String(d.get("scoring", "points")))
	m.controller_script = String(d.get("script", "res://src/minigames/%s.gd" % m.id))
	m.arena_ids = PackedStringArray(d.get("arenas", []))
	m.min_players = int(d.get("min_players", 2))
	m.max_players = int(d.get("max_players", 4))
	m.duration = float(d.get("duration", 90.0))
	m.default_rounds = int(d.get("rounds", 1))
	m.supports_sudden_death = bool(d.get("sudden_death", true))
	m.supports_teams = bool(d.get("teams", false))
	m.control_hints = PackedStringArray(d.get("controls", ["move"]))
	m.control_profile = ControlProfile.from_string(String(d.get("control_profile", "movement_action")))
	m.tags = PackedStringArray(d.get("tags", []))
	m.unlock = d.get("unlock", {})
	m.difficulty_curve = float(d.get("difficulty_curve", 1.0))
	m.icon_glyph = String(d.get("glyph", "◆"))
	m.is_boss = bool(d.get("boss", false))
	return m


func category_name() -> String:
	return CATEGORY_NAMES.get(category, "unknown")


func display_name() -> String:
	return Loc.t(name_key)


## Higher score wins for POINTS/SURVIVAL/LIVES; lower wins for RACE_TIME.
func higher_is_better() -> bool:
	return scoring != Scoring.RACE_TIME


static func _category_from(s: String) -> Category:
	for k in CATEGORY_NAMES:
		if CATEGORY_NAMES[k] == s:
			return k
	return Category.PUSH_OUT


static func _scoring_from(s: String) -> Scoring:
	match s:
		"survival": return Scoring.SURVIVAL
		"race_time": return Scoring.RACE_TIME
		"lives": return Scoring.LIVES
		_: return Scoring.POINTS
