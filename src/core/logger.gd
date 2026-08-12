extends Node
## Central logger. Autoload name: `Log`.
##
## Keeps a ring buffer of recent lines so the debug overlay and the crash
## reporter can show context without re-reading stdout. Levels below
## `min_level` are dropped before any string formatting happens, so debug
## logging costs nothing in a release build.

enum Level { DEBUG, INFO, WARN, ERROR }

const RING_CAPACITY := 400

var min_level: Level = Level.DEBUG
var _ring: PackedStringArray = []
var _counts := {Level.DEBUG: 0, Level.INFO: 0, Level.WARN: 0, Level.ERROR: 0}

signal line_logged(level: Level, text: String)


func _ready() -> void:
	if not OS.is_debug_build():
		min_level = Level.INFO


func d(msg: String, tag: String = "") -> void:
	_write(Level.DEBUG, msg, tag)


func i(msg: String, tag: String = "") -> void:
	_write(Level.INFO, msg, tag)


func w(msg: String, tag: String = "") -> void:
	_write(Level.WARN, msg, tag)


func e(msg: String, tag: String = "") -> void:
	_write(Level.ERROR, msg, tag)


## Number of messages emitted at `level` since launch. Tests assert on
## `error_count() == 0` to enforce the "no console errors" release gate.
func count(level: Level) -> int:
	return _counts[level]


func error_count() -> int:
	return _counts[Level.ERROR]


func recent(limit: int = 40) -> PackedStringArray:
	var start := maxi(0, _ring.size() - limit)
	return _ring.slice(start)


func clear() -> void:
	_ring.clear()
	for k in _counts:
		_counts[k] = 0


func _write(level: Level, msg: String, tag: String) -> void:
	_counts[level] = _counts[level] + 1
	if level < min_level:
		return
	var prefix: String = ["DBG", "INF", "WRN", "ERR"][level]
	var text := "[%s]%s %s" % [prefix, ("[" + tag + "]") if tag != "" else "", msg]
	_ring.append(text)
	if _ring.size() > RING_CAPACITY:
		_ring = _ring.slice(_ring.size() - RING_CAPACITY)
	match level:
		Level.ERROR:
			push_error(text)
		Level.WARN:
			push_warning(text)
		_:
			print(text)
	line_logged.emit(level, text)
