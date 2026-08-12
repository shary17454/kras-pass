class_name PlayerConfig
extends Resource
## One participant in a match — human or AI, the two are interchangeable.

enum Difficulty { EASY, MEDIUM, HARD, EXPERT }

const DIFFICULTY_KEYS := ["difficulty.easy", "difficulty.medium", "difficulty.hard", "difficulty.expert"]

@export var slot := 0
@export var character_id := ""
@export var is_human := false
@export var ai_difficulty: int = Difficulty.MEDIUM
@export var team := -1  # -1 = free for all
@export var display_name_override := ""
## Which local device drives this slot, when human. Set by the join screen.
@export var device_type := 0
@export var device_id := 0
## Set for remote participants once the online layer is live.
@export var peer_id := 0


func character() -> CharacterData:
	return Registry.character(character_id)


func display_name() -> String:
	if display_name_override != "":
		return display_name_override
	var c := character()
	var base := c.display_name() if c != null else "P%d" % (slot + 1)
	if is_human:
		return base
	return "%s (%s)" % [base, Loc.t(DIFFICULTY_KEYS[clampi(ai_difficulty, 0, 3)])]


func color() -> Color:
	var c := character()
	return c.color if c != null else Color.WHITE
