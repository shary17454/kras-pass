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


## The character this player plays, recoloured by their chosen palette when
## they are human and own a non-default one. AI opponents always show a
## character's true colours — a cosmetic is a human player's preference, not
## part of the game's content.
func character_with_cosmetics() -> CharacterData:
	var c := character()
	if c == null or not is_human:
		return c
	var palette := Registry.palette(Progression.selected_palette())
	if not palette.has("color"):
		return c
	var variant := c.duplicate() as CharacterData
	variant.color = Color.html(String(palette.get("color", "")))
	variant.accent = Color.html(String(palette.get("accent", palette.get("color", ""))))
	return variant
