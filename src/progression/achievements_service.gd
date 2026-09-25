extends Node
## Achievement evaluation. Autoload name: `Achievements`.
##
## Definitions live in `data/achievements.json`; each names a `condition` type
## that `_evaluate()` knows how to test against Stats/Progression. Evaluation is
## pull-based (re-checked after each match and each reward) rather than a web of
## event listeners — with ~40 achievements that is cheaper to reason about and
## impossible to miss an unlock through a dropped signal.

signal unlocked(id: String)

const BRANCH := "achievements"

var _earned := {}
var _pending_toasts: Array[String] = []


func _ready() -> void:
	_load()
	SaveSystem.profile_loaded.connect(func(_d): _load())
	Stats.updated.connect(evaluate_all)
	Progression.trophies_changed.connect(func(_n): evaluate_all())
	Progression.completion_changed.connect(func(_p): evaluate_all())


func _load() -> void:
	_earned = SaveSystem.player_branch(BRANCH)


func _commit() -> void:
	SaveSystem.set_player_branch(BRANCH, _earned)


func definitions() -> Array:
	return Registry.achievement_defs()


func is_unlocked(id: String) -> bool:
	return _earned.has(id)


func earned_count() -> int:
	return _earned.size()


func total_count() -> int:
	return definitions().size()


func unlock(id: String) -> bool:
	if is_unlocked(id):
		return false
	_earned[id] = Time.get_unix_time_from_system()
	_commit()
	SaveSystem.flush()
	unlocked.emit(id)
	EventBus.achievement_unlocked.emit(id)
	EventBus.notify(Loc.t("achievement.unlocked", {"name": Loc.t(name_key_of(id))}), "🏅")
	AudioManager.play_ui("unlock")
	return true


func definition(id: String) -> Dictionary:
	for d in definitions():
		if String(d.get("id", "")) == id:
			return d
	return {}


## Loc keys follow a fixed convention so a new achievement needs no key columns
## in the JSON — only the two strings in each locale file.
func name_key_of(id: String) -> String:
	return String(definition(id).get("name_key", "achievement.%s.name" % id))


func desc_key_of(id: String) -> String:
	return String(definition(id).get("desc_key", "achievement.%s.desc" % id))


## Current progress toward an achievement, 0..1, for the list UI.
func progress(id: String) -> float:
	if is_unlocked(id):
		return 1.0
	var d := definition(id)
	var cond: Dictionary = d.get("condition", {})
	var target := float(cond.get("amount", 1))
	if target <= 0.0:
		return 0.0
	return clampf(_measure(cond) / target, 0.0, 1.0)


func evaluate_all() -> void:
	evaluate_profile(SaveSystem.active_profile_id())


func evaluate_profile(profile_id: String) -> bool:
	if not SaveSystem.profile_ids().has(profile_id):
		return false
	var earned := SaveSystem.profile_branch(profile_id, BRANCH)
	var changed := false
	for d in definitions():
		var id := String(d.get("id", ""))
		if earned.has(id):
			continue
		if ProfileMetrics.rule_met(d.get("condition", {}), profile_id):
			if profile_id == SaveSystem.active_profile_id():
				_earned = earned
				unlock(id)
			else:
				earned[id] = Time.get_unix_time_from_system()
			changed = true
	if changed:
		SaveSystem.set_profile_branch(profile_id, BRANCH, earned)
	return changed


func rows() -> Array:
	var out: Array = []
	for d in definitions():
		var id := String(d.get("id", ""))
		out.append({
			"id": id,
			"name": Loc.t(name_key_of(id)),
			"desc": Loc.t(desc_key_of(id)),
			"icon": String(d.get("icon", "🏅")),
			"unlocked": is_unlocked(id),
			"progress": progress(id),
			"secret": bool(d.get("secret", false)),
		})
	return out


func reset() -> void:
	_earned.clear()
	_commit()


## Numeric measurement behind a condition, shared by `progress` and `_evaluate`.
func _measure(cond: Dictionary) -> float:
	return ProfileMetrics.measure(cond, SaveSystem.active_profile_id())


func _evaluate(cond: Dictionary) -> bool:
	if cond.is_empty():
		return false
	var t := String(cond.get("type", ""))
	if t == "all_minigames_won" or t == "adventure_complete":
		return _measure(cond) >= 1.0
	return _measure(cond) >= float(cond.get("amount", 1))
