class_name MatchResult
extends Resource
## Outcome of a round or a whole match.
##
## Placement is computed here, once, from raw scores — not by each mini-game.
## That is why ties behave identically in all 21 games, and why the tournament
## and adventure layers can trust the numbers they are handed.

@export var minigame_id := ""
@export var arena_id := ""
@export var round_index := 0
@export var scores: Array[int] = []          # index = slot
@export var places: Array[int] = []          # 1-based, ties share a place
@export var elimination_order: Array[int] = []  # slots, first out first
@export var duration := 0.0
@export var finished_naturally := true       # false if quit/aborted
@export var sudden_death_used := false
## Per-slot free-form numbers a game wants on the results screen,
## e.g. [{"knockouts": 3, "falls": 1}, ...]
@export var details: Array = []
@export var rounds: Array[MatchResult] = []  # populated on the aggregate result


func winner_slot() -> int:
	for i in places.size():
		if places[i] == 1:
			return i
	return -1


## All slots sharing first place. A genuine draw returns more than one.
func winners() -> Array[int]:
	var out: Array[int] = []
	for i in places.size():
		if places[i] == 1:
			out.append(i)
	return out


func is_draw() -> bool:
	return winners().size() > 1


func place_of(slot: int) -> int:
	return places[slot] if slot >= 0 and slot < places.size() else 0


func score_of(slot: int) -> int:
	return scores[slot] if slot >= 0 and slot < scores.size() else 0


func detail(slot: int, key: String, fallback := 0):
	if slot < 0 or slot >= details.size():
		return fallback
	return details[slot].get(key, fallback)


## Slots ordered best-first.
func ranking() -> Array[int]:
	var order: Array[int] = []
	for i in places.size():
		order.append(i)
	order.sort_custom(func(a, b): return places[a] < places[b])
	return order


## Standard competition ranking: [5,5,3] -> [1,1,3].
## `higher_is_better` is false for race-time scoring, where a low value wins.
static func compute_places(values: Array[int], higher_is_better: bool = true) -> Array[int]:
	var n := values.size()
	var places: Array[int] = []
	places.resize(n)
	for i in n:
		var better := 0
		for j in n:
			if i == j:
				continue
			if higher_is_better and values[j] > values[i]:
				better += 1
			elif not higher_is_better and values[j] < values[i]:
				better += 1
		places[i] = better + 1
	return places


static func make(minigame_id: String, arena_id: String, scores: Array[int], higher_is_better: bool = true) -> MatchResult:
	var r := MatchResult.new()
	r.minigame_id = minigame_id
	r.arena_id = arena_id
	r.scores = scores.duplicate()
	r.places = compute_places(scores, higher_is_better)
	for i in scores.size():
		r.details.append({})
	return r


## Fold several round results into one match result. Round scores are summed,
## and places are recomputed from the totals so a player who wins two of three
## rounds cannot lose the match on a technicality.
static func aggregate(minigame_id: String, round_results: Array[MatchResult], higher_is_better: bool = true) -> MatchResult:
	var agg := MatchResult.new()
	agg.minigame_id = minigame_id
	if round_results.is_empty():
		return agg
	var slots: int = round_results[0].scores.size()
	var totals: Array[int] = []
	totals.resize(slots)
	totals.fill(0)
	for r in round_results:
		for i in mini(slots, r.scores.size()):
			totals[i] += r.scores[i]
		agg.duration += r.duration
		agg.sudden_death_used = agg.sudden_death_used or r.sudden_death_used
	agg.arena_id = round_results[round_results.size() - 1].arena_id
	agg.scores = totals
	agg.places = compute_places(totals, higher_is_better)
	agg.rounds = round_results.duplicate()
	for i in slots:
		var merged := {}
		for r in round_results:
			if i < r.details.size():
				for k in r.details[i]:
					merged[k] = merged.get(k, 0) + r.details[i][k]
		agg.details.append(merged)
	return agg
