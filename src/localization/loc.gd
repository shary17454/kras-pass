extends Node
## Localization service. Autoload name: `Loc`.
##
## No user-facing string is written inside gameplay code — everything goes
## through `Loc.t("some.key")`. Tables live in `res://data/loc/<locale>.json`.
## Arabic is the primary locale and is right-to-left; `is_rtl()` drives layout
## mirroring in the UI layer.

signal locale_changed(locale: String)

const LOC_DIR := "res://data/loc"
const SUPPORTED := ["ar", "en"]
const FALLBACK := "en"

var locale := "ar"
var _tables := {}
var _missing := {}


func _ready() -> void:
	for code in SUPPORTED:
		_tables[code] = _read(code)
	var sys := OS.get_locale_language()
	locale = sys if SUPPORTED.has(sys) else "ar"
	_apply_text_direction()


func set_locale(code: String) -> void:
	if not SUPPORTED.has(code) or code == locale:
		return
	locale = code
	_apply_text_direction()
	locale_changed.emit(locale)


func is_rtl() -> bool:
	return locale == "ar"


## Look up `key`. `args` values substitute `{name}` placeholders.
## An unknown key returns the key itself in a visible bracket form so missing
## strings are obvious in-game rather than silently blank.
func t(key: String, args: Dictionary = {}) -> String:
	var s := _lookup(locale, key)
	if s == "":
		s = _lookup(FALLBACK, key)
	if s == "":
		_missing[key] = true
		return "⟦%s⟧" % key
	for k in args:
		s = s.replace("{%s}" % k, str(args[k]))
	return s


func has(key: String) -> bool:
	return _lookup(locale, key) != "" or _lookup(FALLBACK, key) != ""


## Localized digits. Arabic UI uses Western digits by design (they are the norm
## in Saudi interfaces and are far more legible at small sizes in a HUD), so
## this is a hook kept for future locales rather than a transform today.
func number(value) -> String:
	return str(value)


func time_mmss(seconds: float) -> String:
	var s := int(max(0.0, ceil(seconds)))
	return "%d:%02d" % [s / 60, s % 60]


func ordinal(place: int) -> String:
	return t("ordinal.%d" % place) if has("ordinal.%d" % place) else str(place)


func missing_keys() -> Array:
	return _missing.keys()


## Keys present in one locale but absent from another. The test suite fails on
## a non-empty result, which keeps the two translations in lockstep.
func parity_gaps() -> Array:
	var gaps: Array = []
	var ar: Dictionary = _tables.get("ar", {})
	var en: Dictionary = _tables.get("en", {})
	for k in ar.keys():
		if not en.has(k):
			gaps.append("missing en: %s" % k)
	for k in en.keys():
		if not ar.has(k):
			gaps.append("missing ar: %s" % k)
	return gaps


func _lookup(code: String, key: String) -> String:
	var tbl: Dictionary = _tables.get(code, {})
	var v = tbl.get(key)
	return v if v is String else ""


func _apply_text_direction() -> void:
	# Godot's advanced text server handles Arabic shaping and bidi; we only need
	# to tell it which direction the UI as a whole should flow.
	if is_rtl():
		TranslationServer.set_locale("ar")
	else:
		TranslationServer.set_locale("en")


func _read(code: String) -> Dictionary:
	var path := "%s/%s.json" % [LOC_DIR, code]
	if not FileAccess.file_exists(path):
		Log.e("locale file missing: %s" % path, "Loc")
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var raw := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		Log.e("locale parse error %s: %s" % [path, json.get_error_message()], "Loc")
		return {}
	return json.data if json.data is Dictionary else {}
