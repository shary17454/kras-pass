class_name PowerUpDef
extends Resource
## A pickup recipe from `data/powerups.json`.
##
## Effects are declarative: a power-up names a `kind` that `PowerUpSystem` knows
## how to apply, plus magnitude and duration. No power-up owns code, so a new
## one is a JSON entry — and re-balancing never means touching a mini-game.

@export var id := ""
@export var name_key := ""
@export var kind := "speed"
@export var duration := 6.0
@export var magnitude := 1.5
@export var color := Color.WHITE
@export var glyph := "★"
@export var weight := 1.0            # relative spawn chance
@export var categories: PackedStringArray = []  # empty = allowed everywhere
@export var instant := false         # applies once instead of over time
@export var targets_rivals := false  # affects everyone except the collector


static func from_dict(d: Dictionary) -> PowerUpDef:
	var p := PowerUpDef.new()
	p.id = String(d.get("id", ""))
	p.name_key = String(d.get("name_key", "powerup.%s.name" % p.id))
	p.kind = String(d.get("kind", p.id))
	p.duration = float(d.get("duration", 6.0))
	p.magnitude = float(d.get("magnitude", 1.5))
	p.color = CharacterData._color(d.get("color", "#ffffff"))
	p.glyph = String(d.get("glyph", "★"))
	p.weight = float(d.get("weight", 1.0))
	p.categories = PackedStringArray(d.get("categories", []))
	p.instant = bool(d.get("instant", false))
	p.targets_rivals = bool(d.get("targets_rivals", false))
	return p


func allowed_in(category_name: String) -> bool:
	return categories.is_empty() or categories.has(category_name)
