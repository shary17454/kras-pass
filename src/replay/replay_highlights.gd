class_name ReplayHighlights
extends RefCounted
## Finds the two or three seconds of a match that were actually worth watching.
##
## Works from the timeline the match records anyway (hits, eliminations, score
## changes) plus the final result, so detection costs nothing during play. The
## output is a list of marked ticks the replay player can jump between — the
## point is that nobody wants to re-watch ninety seconds to see the one moment
## they are arguing about.

const LAST_SECOND_WINDOW := 3.0
const MULTI_KO_WINDOW := 2.0
const BIG_HIT_STRENGTH := 26.0
const EARLY_OUT_SECONDS := 10.0
const NARROW_MARGIN := 1


## `timeline` entries are {tick, type, slot, other, value}.
static func detect(timeline: Array, result: MatchResult, tick_count: int, tick_rate: int) -> Array:
	var out: Array = []
	if result == null or tick_rate <= 0:
		return out
	var last_tick := maxi(tick_count - 1, 0)
	var final_window_start := last_tick - int(LAST_SECOND_WINDOW * tick_rate)

	_narrow_finish(out, result, last_tick)
	_late_swing(out, timeline, final_window_start)
	_comeback(out, timeline, result)
	_early_exit(out, timeline, tick_rate)
	_multi_knockout(out, timeline, tick_rate)
	_biggest_hit(out, timeline)

	out.sort_custom(func(a, b): return int(a["tick"]) < int(b["tick"]))
	return out


static func _add(out: Array, tick: int, kind: String, slot: int, detail := "") -> void:
	# One highlight per kind: three "big hit" markers in a row is noise.
	for h in out:
		if String(h["kind"]) == kind:
			return
	out.append({"tick": maxi(0, tick), "kind": kind, "slot": slot, "detail": detail})


## Decided by a single point, or a hair on the clock.
static func _narrow_finish(out: Array, result: MatchResult, last_tick: int) -> void:
	var ranking := result.ranking()
	if ranking.size() < 2:
		return
	var first := result.score_of(ranking[0])
	var second := result.score_of(ranking[1])
	var margin: int = absi(first - second)
	if margin <= NARROW_MARGIN and margin >= 0:
		_add(out, maxi(0, last_tick - 120), "narrow_win", ranking[0], str(margin))


## The lead changed in the closing seconds.
static func _late_swing(out: Array, timeline: Array, from_tick: int) -> void:
	var leader_at_window := -1
	for e in timeline:
		if String(e["type"]) != "lead":
			continue
		if int(e["tick"]) <= from_tick:
			leader_at_window = int(e["slot"])
		elif int(e["tick"]) > from_tick:
			if leader_at_window >= 0 and int(e["slot"]) != leader_at_window:
				_add(out, int(e["tick"]), "late_swing", int(e["slot"]))
				return


## Finished first after being last at some point.
static func _comeback(out: Array, timeline: Array, result: MatchResult) -> void:
	var winner := result.winner_slot()
	if winner < 0:
		return
	for e in timeline:
		if String(e["type"]) == "last_place" and int(e["slot"]) == winner:
			_add(out, int(e["tick"]), "comeback", winner)
			return


## Someone was gone before the round really started.
static func _early_exit(out: Array, timeline: Array, tick_rate: int) -> void:
	var limit := int(EARLY_OUT_SECONDS * tick_rate)
	for e in timeline:
		if String(e["type"]) == "eliminated" and int(e["tick"]) <= limit:
			_add(out, int(e["tick"]), "early_exit", int(e["slot"]))
			return


## Two or more competitors removed within a couple of seconds.
static func _multi_knockout(out: Array, timeline: Array, tick_rate: int) -> void:
	var outs: Array = []
	for e in timeline:
		if String(e["type"]) == "eliminated":
			outs.append(int(e["tick"]))
	outs.sort()
	var window := int(MULTI_KO_WINDOW * tick_rate)
	for i in range(1, outs.size()):
		if outs[i] - outs[i - 1] <= window:
			_add(out, outs[i - 1], "multi_knockout", -1, str(outs.size()))
			return


static func _biggest_hit(out: Array, timeline: Array) -> void:
	var best_tick := -1
	var best := BIG_HIT_STRENGTH
	var by := -1
	for e in timeline:
		if String(e["type"]) != "hit":
			continue
		if float(e["value"]) > best:
			best = float(e["value"])
			best_tick = int(e["tick"])
			by = int(e["slot"])
	if best_tick >= 0:
		_add(out, best_tick, "big_hit", by, "%.0f" % best)


static func label_key(kind: String) -> String:
	return "highlight.%s" % kind
