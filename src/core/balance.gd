extends Node
## Data-driven tuning tables. Autoload name: `Balance`.
##
## Every gameplay number that a designer would want to touch lives in a JSON
## file under `res://data/`, never as a literal inside a mini-game. Lookups go
## through `num()` / `get_table()` which fall back to a documented default so a
## missing key degrades to a playable value instead of a crash.
##
## Files are merged into one dictionary keyed by file stem, e.g.
##   data/tuning.json          -> Balance.table("tuning")
##   data/characters.json      -> Balance.table("characters")

const DATA_DIR := "res://data"
const FILES := [
	"tuning",
	"characters",
	"minigames",
	"arenas",
	"powerups",
	"achievements",
	"adventure",
	"ai",
	"mutators",
]

var _tables := {}
var _missing_keys := {}


func _ready() -> void:
	reload()


func reload() -> void:
	_tables.clear()
	for stem in FILES:
		var path := "%s/%s.json" % [DATA_DIR, stem]
		var parsed = _read_json(path)
		if parsed == null:
			Log.e("balance table missing or invalid: %s" % path, "Balance")
			_tables[stem] = {}
		else:
			_tables[stem] = parsed
	Log.i("loaded %d balance tables" % _tables.size(), "Balance")


func table(stem: String) -> Dictionary:
	return _tables.get(stem, {})


## Dotted lookup across a table, e.g. num("tuning", "fighter.walk_speed", 8.0).
func num(stem: String, path: String, fallback: float) -> float:
	var v = _dig(stem, path)
	if v == null:
		_note_missing(stem, path)
		return fallback
	if v is float or v is int:
		return float(v)
	_note_missing(stem, path)
	return fallback


func inum(stem: String, path: String, fallback: int) -> int:
	return int(round(num(stem, path, float(fallback))))


func flag(stem: String, path: String, fallback: bool) -> bool:
	var v = _dig(stem, path)
	if v is bool:
		return v
	_note_missing(stem, path)
	return fallback


func text(stem: String, path: String, fallback: String) -> String:
	var v = _dig(stem, path)
	if v is String:
		return v
	_note_missing(stem, path)
	return fallback


func dict(stem: String, path: String) -> Dictionary:
	var v = _dig(stem, path)
	return v if v is Dictionary else {}


func list(stem: String, path: String) -> Array:
	var v = _dig(stem, path)
	return v if v is Array else []


## Keys that were asked for but not present. The test suite asserts this is
## empty after a full simulated match, which catches typos in tuning paths.
func missing_keys() -> Array:
	return _missing_keys.keys()


func _dig(stem: String, path: String):
	var node = _tables.get(stem)
	if node == null:
		return null
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			return null
	return node


func _note_missing(stem: String, path: String) -> void:
	_missing_keys["%s:%s" % [stem, path]] = true


func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var raw := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		Log.e("json parse error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()], "Balance")
		return null
	return json.data if json.data is Dictionary else null
