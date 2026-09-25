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
@export var local_profile_id := ""
@export var palette_id := ""
## Which local device drives this slot, when human. Set by the join screen.
@export var device_type := 0
@export var device_id := 0
## Set for remote participants once the online layer is live.
@export var peer_id := 0

const SYMBOLS := ["●", "▲", "■", "★"]


func symbol() -> String:
	return SYMBOLS[clampi(slot, 0, 3)]


func to_dict() -> Dictionary:
	return {"slot": slot, "character": character_id, "human": is_human,
		"difficulty": ai_difficulty, "team": team, "name": display_name_override,
		"profile": local_profile_id, "palette": palette_id, "device_type": device_type, "device_id": device_id}


static func from_dict(data: Dictionary) -> PlayerConfig:
	if Registry.character(String(data.get("character", ""))) == null:
		return null
	var player := PlayerConfig.new()
	player.slot = clampi(int(data.get("slot", 0)), 0, 3)
	player.character_id = String(data["character"])
	player.is_human = bool(data.get("human", false))
	player.ai_difficulty = clampi(int(data.get("difficulty", 1)), 0, 3)
	player.team = clampi(int(data.get("team", -1)), -1, 3)
	player.display_name_override = String(data.get("name", "")).left(32)
	player.local_profile_id = String(data.get("profile", ""))
	player.palette_id = String(data.get("palette", ""))
	player.device_type = clampi(int(data.get("device_type", 0)), 0, 2)
	player.device_id = int(data.get("device_id", 0))
	return player


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
	if is_human or not palette_id.is_empty():
		var palette := Registry.palette(cosmetic_palette())
		if palette.has("color"):
			return Color.html(String(palette["color"]))
	return c.color if c != null else Color.WHITE


## The character this player plays, recoloured by their chosen palette when
## they are human and own a non-default one. AI opponents always show a
## character's true colours — a cosmetic is a human player's preference, not
## part of the game's content.
func character_with_cosmetics() -> CharacterData:
	var c := character()
	if c == null or not is_human and palette_id.is_empty():
		return c
	var palette := Registry.palette(cosmetic_palette())
	if not palette.has("color"):
		return c
	var variant := c.duplicate() as CharacterData
	variant.color = Color.html(String(palette.get("color", "")))
	variant.accent = Color.html(String(palette.get("accent", palette.get("color", ""))))
	return variant


func cosmetic_palette() -> String:
	var chosen := palette_id
	if chosen.is_empty():
		if not local_profile_id.is_empty() and SaveSystem.profile_ids().has(local_profile_id):
			var progress := SaveSystem.profile_branch(local_profile_id, "progress")
			chosen = String(progress.get("selected_palette", "classic"))
			if not Progression.all_unlocked() and not progress.get("palettes", []).has(chosen):
				chosen = "classic"
		else:
			chosen = Progression.selected_palette() if display_name_override.is_empty() else "classic"
	return chosen


func apply_profile_preferences() -> void:
	if not is_human or local_profile_id.is_empty() or not SaveSystem.profile_ids().has(local_profile_id):
		palette_id = "classic"
		return
	var progress := Progression.prepare_profile(local_profile_id)
	var favorite := String(progress.get("last_character", ""))
	if Registry.character(favorite) != null and Progression.is_character_unlocked(favorite):
		character_id = favorite
	var selected := String(progress.get("selected_palette", "classic"))
	palette_id = selected if Progression.all_unlocked() or progress.get("palettes", []).has(selected) else "classic"
