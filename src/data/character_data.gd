class_name CharacterData
extends Resource
## One playable competitor, built from `data/characters.json`.
##
## Stats are normalized 0..1 and are turned into physical values by
## `Fighter._apply_character()`. Keeping them normalized means a designer tunes
## a character's *feel* here and the global speed/weight scale in tuning.json,
## instead of re-balancing every character when the base speed moves.

@export var id := ""
@export var name_key := ""
@export var realm_key := ""
@export var tagline_key := ""
@export var color := Color.WHITE
@export var accent := Color.WHITE

## 0 = sluggish, 1 = maximum. Sum is kept near a constant in the data file so
## no character is strictly better than another.
@export var speed := 0.5
@export var accel := 0.5
@export var weight := 0.5   # resistance to knockback
@export var jump := 0.5
@export var power := 0.5    # knockback dealt
@export var control := 0.5  # air steering and turn rate

## Procedural body recipe — the art layer reads these instead of a mesh file, so
## swapping in authored models later means implementing one builder branch.
@export var body_shape := "capsule"  # capsule | boulder | orb | shard | drum
@export var head_shape := "sphere"
@export var height_scale := 1.0
@export var girth_scale := 1.0
@export var accessory := ""  # leaf | crack | spark | flame | wave | puff | grain | cog

@export var voice_pitch := 1.0
@export var celebration := "spin"  # spin | leap | flex | bow | shimmer
@export var unlock := {}  # e.g. {"type": "trophies", "amount": 6}
@export var starter := false


static func from_dict(d: Dictionary) -> CharacterData:
	var c := CharacterData.new()
	c.id = String(d.get("id", ""))
	c.name_key = String(d.get("name_key", "char.%s.name" % c.id))
	c.realm_key = String(d.get("realm_key", "char.%s.realm" % c.id))
	c.tagline_key = String(d.get("tagline_key", "char.%s.tagline" % c.id))
	c.color = _color(d.get("color", "#ffffff"))
	c.accent = _color(d.get("accent", "#ffffff"))
	var s: Dictionary = d.get("stats", {})
	c.speed = float(s.get("speed", 0.5))
	c.accel = float(s.get("accel", 0.5))
	c.weight = float(s.get("weight", 0.5))
	c.jump = float(s.get("jump", 0.5))
	c.power = float(s.get("power", 0.5))
	c.control = float(s.get("control", 0.5))
	var b: Dictionary = d.get("body", {})
	c.body_shape = String(b.get("shape", "capsule"))
	c.head_shape = String(b.get("head", "sphere"))
	c.height_scale = float(b.get("height", 1.0))
	c.girth_scale = float(b.get("girth", 1.0))
	c.accessory = String(b.get("accessory", ""))
	c.voice_pitch = float(d.get("voice_pitch", 1.0))
	c.celebration = String(d.get("celebration", "spin"))
	c.unlock = d.get("unlock", {})
	c.starter = bool(d.get("starter", false))
	return c


## Total stat budget. The balance test asserts every character lands inside a
## narrow band so none is objectively dominant.
func stat_total() -> float:
	return speed + accel + weight + jump + power + control


func display_name() -> String:
	return Loc.t(name_key)


static func _color(v) -> Color:
	if v is String:
		return Color.html(v)
	if v is Array and v.size() >= 3:
		return Color(v[0], v[1], v[2], 1.0 if v.size() < 4 else v[3])
	return Color.WHITE
