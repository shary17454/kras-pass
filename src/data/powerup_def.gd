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
## True for a boost, false for a penalty. The hover machine reads this to skew
## who gets what without needing a list of ids.
@export var boon := true
## Only the hover machine hands this one out. The harsh power-downs are
## machine-only on purpose: as ground pickups they would flood the ambient pool
## and re-balance twenty-eight games that were measured without them.
@export var machine_only := false


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
	p.boon = bool(d.get("boon", not p.targets_rivals))
	p.machine_only = bool(d.get("machine_only", false))
	return p


func allowed_in(category_name: String) -> bool:
	return categories.is_empty() or categories.has(category_name)
