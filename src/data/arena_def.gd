class_name ArenaDef
extends Resource
## An arena recipe from `data/arenas.json`.
##
## Arenas are generated at load time by `ArenaBuilder` from these parameters
## rather than shipped as scene files. That keeps the repository asset-free
## (nothing borrowed, nothing to license), makes every arena trivially
## re-skinnable, and lets a designer add a new venue by editing JSON.

@export var id := ""
@export var name_key := ""
@export var shape := "disc"  # disc | square | ring | cross | tiles | track | pit | islands | oval | circuit
@export var radius := 12.0
@export var thickness := 1.0
@export var wall_height := 0.0   # 0 = open edge (fall off), >0 = enclosed
@export var theme := "sunset"
@export var floor_color := Color(0.22, 0.24, 0.34)
@export var accent_color := Color(0.95, 0.63, 0.25)
@export var sky_top := Color(0.10, 0.13, 0.28)
@export var sky_bottom := Color(0.42, 0.24, 0.42)
@export var hazards: Array = []      # [{"type":"sweeper","count":3,"speed":1.2}, ...]
@export var props: Array = []        # decorative, non-colliding
@export var spawn_points: Array = [] # explicit spawns; empty = auto ring
@export var gravity_scale := 1.0
@export var fall_y := -14.0          # below this a fighter is out
## Shape-specific numbers. `circuit` reads `lobes`, `wobble` and `width` from
## here, which is what makes five race tracks five different drives instead of
## one ring in five palettes. Kept as a free-form bag so a new shape never
## needs a schema change.
@export var params: Dictionary = {}


static func from_dict(d: Dictionary) -> ArenaDef:
	var a := ArenaDef.new()
	a.id = String(d.get("id", ""))
	a.name_key = String(d.get("name_key", "arena.%s.name" % a.id))
	a.shape = String(d.get("shape", "disc"))
	a.radius = float(d.get("radius", 12.0))
	a.thickness = float(d.get("thickness", 1.0))
	a.wall_height = float(d.get("wall_height", 0.0))
	a.theme = String(d.get("theme", "sunset"))
	var pal: Dictionary = d.get("palette", {})
	a.floor_color = CharacterData._color(pal.get("floor", "#383c56"))
	a.accent_color = CharacterData._color(pal.get("accent", "#f2a03f"))
	a.sky_top = CharacterData._color(pal.get("sky_top", "#1a2149"))
	a.sky_bottom = CharacterData._color(pal.get("sky_bottom", "#6b3d6b"))
	a.hazards = d.get("hazards", [])
	a.props = d.get("props", [])
	a.spawn_points = d.get("spawns", [])
	a.gravity_scale = float(d.get("gravity_scale", 1.0))
	a.fall_y = float(d.get("fall_y", -14.0))
	a.params = d.get("params", {})
	return a


func param(key: String, fallback: float) -> float:
	return float(params.get(key, fallback))


## Evenly spaced spawn ring when the data file does not pin exact positions.
func spawns_for(count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if spawn_points.size() >= count:
		for i in count:
			var p = spawn_points[i]
			out.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
		return out
	var r := radius * 0.62
	for i in count:
		var ang := TAU * float(i) / float(maxi(count, 1)) - PI * 0.5
		out.append(Vector3(cos(ang) * r, 1.4, sin(ang) * r))
	return out


func display_name() -> String:
	return Loc.t(name_key)
