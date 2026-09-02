extends Node
## Bot-versus-bot balance simulation.
##
##   godot --headless --fixed-fps 60 --path . tools/balance_sim.tscn -- --runs=8
##
## Plays every mini-game many times with bots and writes a report to
## `build/balance/`. This is the instrument for the questions you cannot answer
## by playing a few rounds yourself:
##
##   - does this game end in a draw half the time?
##   - does spawn slot 1 win more than slot 4?
##   - does one character win everywhere regardless of the game?
##   - is Expert actually better than Easy, per game rather than on average?
##   - is any game so short or so long that it does not belong in a party?
##
## Characters are rotated through slots between runs, so a character advantage
## and a slot advantage cannot be mistaken for each other.

const OUT_DIR := "build/balance"
const ROUND_SECONDS := 14.0
const MAX_TICKS := 60 * 120
## A deliberately combined, over-stuffed set — heavier than any real preset —
## to stress MutatorSystem's compatibility/exclusion filtering: whatever does
## not apply to a given game's category should be silently skipped rather than
## crash it. Mirrors the "chaos" preset's own mutators for the chaos pass.
const MUTATOR_STRESS_SET := ["low_gravity", "hyper_speed", "tiny", "double_hazards", "ice_floor", "short_fuse"]
const CHAOS_MUTATOR_SET := ["powerup_rush", "double_hazards"]

const NULL_TRIALS := 4000

var runs := 6
var only := ""
var _report := []
var _mutator_report := []
var _null_cache := {}
var _started := 0
## Progress goes to a file as well as stdout: Godot buffers stdout when it is
## piped, which makes a long simulation look hung when it is merely quiet.
var _log: FileAccess


func _ready() -> void:
	_parse_args()
	_log = FileAccess.open("user://balance_progress.txt", FileAccess.WRITE)
	_say("start runs=%d only=%s" % [runs, only])
	_started = Time.get_ticks_msec()
	# Shorter pre-round cards: this is a simulation, not a demo.
	UserSettings.set_value("show_control_hints", false)
	UserSettings.set_value("replay_capture", false)
	await get_tree().process_frame
	print("balance simulation: %d runs per game, %d games" % [runs, _games().size()])
	for def in _games():
		_say("begin %s" % def.id)
		var row := await _simulate(def)
		_report.append(row)
		_say("done %s" % def.id)
		print("  %-16s ties %3.0f%%  slot-bias %3.0f%%  char-bias %3.0f%%  %5.1fs  expert %+3.0f%%%s" % [
			def.id, row["tie_rate"] * 100.0, row["slot_bias"] * 100.0, row["character_bias"] * 100.0,
			row["avg_duration"], row["expert_edge"] * 100.0,
			"   ⚠ " + ", ".join(row["flags"]) if not row["flags"].is_empty() else ""])

	print("\nmutator & chaos smoke pass:")
	for def in _games():
		var mrow := await _mutator_smoke(def)
		_mutator_report.append(mrow)
		print("  %-16s mutated %s  chaos %s%s" % [
			def.id, "ok" if mrow["mutated_ok"] else "FAIL", "ok" if mrow["chaos_ok"] else "FAIL",
			"   ⚠ " + ", ".join(mrow["flags"]) if not mrow["flags"].is_empty() else ""])
	_write_reports()
	print("\nfinished in %.1fs — %s/report.html" % [(Time.get_ticks_msec() - _started) / 1000.0, OUT_DIR])
	get_tree().quit(0 if _worst_severity() < 2 else 1)


func _say(line: String) -> void:
	if _log != null:
		_log.store_line("[%6.1fs] %s" % [(Time.get_ticks_msec() - _started) / 1000.0, line])
		_log.flush()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = maxi(2, int(arg.split("=")[1]))
		elif arg.begins_with("--only="):
			only = arg.split("=")[1]


func _games() -> Array[MiniGameDef]:
	if only == "":
		return Registry.minigames()
	var out: Array[MiniGameDef] = []
	var def := Registry.minigame(only)
	if def != null:
		out.append(def)
	return out


func _simulate(def: MiniGameDef) -> Dictionary:
	var roster := Registry.characters()
	var wins_by_slot := [0, 0, 0, 0]
	var wins_by_character := {}
	# Every character that actually took the field, win or lose. Without this a
	# character that never wins is simply absent from `wins_by_character`, and
	# the bias maths then divides by the winners only — a game where one
	# character sweeps every run collapses to a single bucket and reports 0%
	# bias, which is exactly backwards.
	var appearances := {}
	var durations: Array[float] = []
	var ties := 0
	var zero_score_runs := 0
	var completed := 0
	var scores_seen: Array[int] = []

	for run in runs:
		_say("  %s run %d/%d" % [def.id, run + 1, runs])
		# Rotate the roster through the slots so slot bias and character bias
		# are separable rather than confounded.
		var chars: Array = []
		for slot in 4:
			var cid_played := roster[(slot + run) % roster.size()].id
			chars.append(cid_played)
			appearances[cid_played] = int(appearances.get(cid_played, 0)) + 1
		var cfg := MatchConfig.build(def.id, chars, 0, PlayerConfig.Difficulty.MEDIUM, 9001 + run * 613)
		cfg.duration_override = _window_for(def)
		cfg.rounds = 1
		var result := await _play(cfg)
		if result == null:
			continue
		completed += 1
		durations.append(result.duration)
		if result.is_draw():
			ties += 1
		var top := 0
		for i in result.scores.size():
			top = maxi(top, result.scores[i])
			scores_seen.append(result.scores[i])
		if top <= 0:
			zero_score_runs += 1
		for slot in result.winners():
			wins_by_slot[slot] = wins_by_slot[slot] + 1
			var cid := String(chars[slot])
			wins_by_character[cid] = int(wins_by_character.get(cid, 0)) + 1

	_say("  %s difficulty pass" % def.id)
	var expert_edge := await _difficulty_edge(def)

	var avg_duration := 0.0
	for d in durations:
		avg_duration += d
	avg_duration = avg_duration / maxf(1.0, float(durations.size()))

	var row := {
		"id": def.id,
		"name": def.display_name(),
		"category": def.category_name(),
		"runs": completed,
		"tie_rate": float(ties) / maxf(1.0, float(completed)),
		"avg_duration": avg_duration,
		"wins_by_slot": wins_by_slot,
		"slot_bias": _bias(wins_by_slot),
		"wins_by_character": wins_by_character,
		"character_buckets": appearances.size(),
		"character_bias": _bias(_counts_over(appearances.keys(), wins_by_character)),
		"zero_score_runs": zero_score_runs,
		"expert_edge": expert_edge,
		"avg_score": _mean(scores_seen),
	}
	row["flags"] = _flags(def, row)
	row["severity"] = _severity(row["flags"])
	return row


## How long to let one simulated round run. The 14-second clip keeps a 21-game
## sweep to a couple of minutes, but it is nonsense for a boss: those fights run
## 150 seconds against four-figure health pools, so a clipped round ends with
## nobody having landed enough hits to score and every boss reads as a 100% tie
## on zero. Give them a window the fight can actually resolve in.
func _window_for(def: MiniGameDef) -> float:
	if def.is_boss:
		return 75.0
	# A fraction of the intended round, not a flat count of seconds. The flat
	# 14 s clip quietly penalised anything that scores by accumulation: Zone
	# Hold runs 90 s and moves its circle every 7-11 s, so a 14 s sample caught
	# barely one placement and read a dead-flat 0.50 no matter how the bots
	# played — widening it to 45 s moved the same build to 0.52. Measuring a
	# 90-second game in 14 seconds is the same mistake as timing a boss fight
	# in 14 seconds, and it was hiding real signal rather than adding noise.
	# A race is only scored when somebody crosses the line. The 45 s ceiling is
	# shorter than a lap-race takes to run, so every race was being measured in
	# the state "nobody finished, rank by progress" — which is a different game
	# from the one being tuned, exactly as the flat 14 s clip was for the
	# bosses. Rocket Rally averaged 42.9 s against a 45 s window, i.e. it was
	# reading its own ceiling. Race games get their real clock.
	if def.scoring == MiniGameDef.Scoring.RACE_TIME:
		return maxf(def.duration, 45.0)
	return clampf(def.duration * 0.35, ROUND_SECONDS, 45.0)


## Expert-versus-Easy, mirrored across slots, expressed as the share of points
## the expert pair took. 0.5 is no separation at all.
func _difficulty_edge(def: MiniGameDef) -> float:
	var expert_total := 0.0
	var easy_total := 0.0
	var roster := Registry.characters()
	for i in maxi(2, runs / 2):
		var expert_first := i % 2 == 0
		var same: Array = []
		for slot in 4:
			same.append(roster[i % roster.size()].id)
		var cfg := MatchConfig.build(def.id, same, 0, PlayerConfig.Difficulty.EASY, 4242 + i * 97)
		cfg.duration_override = _window_for(def)
		cfg.rounds = 1
		cfg.allow_powerups = false
		for slot in 4:
			var is_expert := (slot < 2) == expert_first
			cfg.players[slot].ai_difficulty = PlayerConfig.Difficulty.EXPERT if is_expert \
				else PlayerConfig.Difficulty.EASY
		var result := await _play(cfg)
		if result == null:
			continue
		# Compare finishing places, not raw scores. Raw scores lied wherever a
		# game encodes its result indirectly — an unfinished race reports a
		# huge sentinel for everyone, so inverting it flattened every kart to
		# epsilon and the edge read exactly 0.50 no matter how the bots drove.
		# Places are what the ranking already computes for every scoring type,
		# so first-to-fourth pays 4-3-2-1 and the metric means the same thing
		# in a brawl, a race and a tile game.
		for slot in 4:
			var value := float(5 - clampi(result.place_of(slot), 1, 4))
			if (slot < 2) == expert_first:
				expert_total += value
			else:
				easy_total += value
	var total := expert_total + easy_total
	if total <= 0.0:
		return 0.5
	return expert_total / total


## MutatorSystem and chaos mode never went through the bot tournament before
## they had a menu path to reach them — this is the same "does it actually
## finish, cleanly" check the base game gets, run once with an intentionally
## over-stuffed mutator set and once with chaos on. Not a balance measurement:
## mutators are supposed to skew things. The bar is "completes, no new errors".
func _mutator_smoke(def: MiniGameDef) -> Dictionary:
	var roster := Registry.characters()
	var chars: Array = []
	for slot in 4:
		chars.append(roster[slot % roster.size()].id)

	var errors_before := Log.error_count()
	var mutated_cfg := MatchConfig.build(def.id, chars, 0, PlayerConfig.Difficulty.MEDIUM, 5501)
	mutated_cfg.duration_override = ROUND_SECONDS
	mutated_cfg.rounds = 1
	mutated_cfg.mutators = PackedStringArray(MUTATOR_STRESS_SET)
	var mutated_result := await _play(mutated_cfg)
	var mutated_ok := mutated_result != null
	var errors_after_mutated := Log.error_count()

	var chaos_cfg := MatchConfig.build(def.id, chars, 0, PlayerConfig.Difficulty.MEDIUM, 5502)
	chaos_cfg.duration_override = ROUND_SECONDS
	chaos_cfg.rounds = 1
	chaos_cfg.chaos = true
	chaos_cfg.mutators = PackedStringArray(CHAOS_MUTATOR_SET)
	var chaos_result := await _play(chaos_cfg)
	var chaos_ok := chaos_result != null
	var errors_after_chaos := Log.error_count()

	var flags: Array = []
	if not mutated_ok:
		flags.append("did not finish under a stress mutator set")
	if not chaos_ok:
		flags.append("did not finish under chaos mode")
	if errors_after_mutated > errors_before:
		flags.append("%d error(s) logged under a stress mutator set" % (errors_after_mutated - errors_before))
	if errors_after_chaos > errors_after_mutated:
		flags.append("%d error(s) logged under chaos mode" % (errors_after_chaos - errors_after_mutated))

	return {
		"id": def.id,
		"name": def.display_name(),
		"mutated_ok": mutated_ok,
		"chaos_ok": chaos_ok,
		"flags": flags,
		"severity": 0 if flags.is_empty() else 2,
	}


func _play(cfg: MatchConfig) -> MatchResult:
	var script: Script = load("res://src/match/match_scene.gd")
	var scene: Node = script.new()
	add_child(scene)
	var captured: Array = []
	scene.setup({"config": cfg, "on_finished": func(r): captured.append(r)})
	var tree := get_tree()
	var guard := 0
	while captured.is_empty() and guard < MAX_TICKS:
		await tree.physics_frame
		guard += 1
	scene.teardown()
	scene.queue_free()
	await tree.process_frame
	return captured[0] if captured.size() > 0 else null


## How far the most-favoured entry is above an even share. 0 is perfectly even.
## Win counts for every bucket that played, including the ones that never won.
func _counts_over(bucket_ids: Array, wins: Dictionary) -> Array:
	var counts: Array = []
	for id in bucket_ids:
		counts.append(int(wins.get(id, 0)))
	return counts


## The 95th percentile of `_bias` under a perfectly fair game, for the sample
## size that actually ran.
##
## `_bias` is a coarse statistic on a small sample: across six runs of a
## four-slot game it can only ever be one of 0.083, 0.25, 0.417, … so a fixed
## 0.20 cut is really the question "did any one slot win three of six?" — which
## chance alone answers yes to about 65% of the time. Comparing against the
## null distribution instead makes the flag mean "more lopsided than chance
## explains" at whatever `--runs` the operator picked, so raising the run count
## tightens the test rather than leaving it equally noisy.
func _null_bias_p95(bins: int, draws: int) -> float:
	if bins < 2 or draws < 1:
		return 1.0
	var key := "%d_%d" % [bins, draws]
	if _null_cache.has(key):
		return float(_null_cache[key])
	var rng := RandomNumberGenerator.new()
	rng.seed = 8675309  # fixed so two runs of the report never disagree
	var samples: Array[float] = []
	for trial in NULL_TRIALS:
		var counts: Array = []
		counts.resize(bins)
		counts.fill(0)
		for d in draws:
			var b := rng.randi_range(0, bins - 1)
			counts[b] = int(counts[b]) + 1
		samples.append(_bias(counts))
	samples.sort()
	var p95: float = samples[int(float(samples.size()) * 0.95)]
	_null_cache[key] = p95
	return p95


func _bias(counts) -> float:
	var values: Array = []
	var total := 0.0
	for c in counts:
		values.append(float(c))
		total += float(c)
	if total <= 0.0 or values.size() < 2:
		return 0.0
	var best := 0.0
	for v in values:
		best = maxf(best, v)
	var even := total / float(values.size())
	return clampf((best - even) / total, 0.0, 1.0)


func _mean(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for v in values:
		sum += float(v)
	return sum / float(values.size())


## Severity 2 is "do not ship this game"; 1 is "look at it".
func _flags(def: MiniGameDef, row: Dictionary) -> Array:
	var flags: Array = []
	if int(row["runs"]) < runs:
		flags.append("did not finish %d/%d runs" % [runs - int(row["runs"]), runs])
	if float(row["tie_rate"]) > 0.4:
		flags.append("ties %.0f%% of the time" % (float(row["tie_rate"]) * 100.0))
	# Thresholds come from the fair-game null for this sample size, never from a
	# fixed number — see `_null_bias_p95`.
	var slot_wins: Array = row["wins_by_slot"]
	var slot_draws := 0
	for w in slot_wins:
		slot_draws += int(w)
	if float(row["slot_bias"]) > _null_bias_p95(slot_wins.size(), slot_draws):
		flags.append("spawn slot advantage")
	var char_buckets := int(row["character_buckets"])
	var char_draws := 0
	for w in (row["wins_by_character"] as Dictionary).values():
		char_draws += int(w)
	if float(row["character_bias"]) > _null_bias_p95(char_buckets, char_draws):
		flags.append("character advantage")
	if int(row["zero_score_runs"]) > 0 and def.scoring == MiniGameDef.Scoring.POINTS:
		flags.append("%d run(s) scored nothing" % int(row["zero_score_runs"]))
	if float(row["avg_duration"]) < 3.0:
		flags.append("ends almost immediately")
	if float(row["expert_edge"]) < 0.52:
		flags.append("expert bots no better than easy")
	return flags


func _severity(flags: Array) -> int:
	if flags.is_empty():
		return 0
	for f in flags:
		var s := String(f)
		if s.begins_with("did not finish") or s.begins_with("ends almost") or s.contains("scored nothing"):
			return 2
	return 1


func _worst_severity() -> int:
	var worst := 0
	for row in _report:
		worst = maxi(worst, int(row["severity"]))
	for row in _mutator_report:
		worst = maxi(worst, int(row["severity"]))
	return worst


# --- output ----------------------------------------------------------------

func _write_reports() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var json := FileAccess.open("%s/report.json" % OUT_DIR, FileAccess.WRITE)
	if json != null:
		json.store_string(JSON.stringify({
			"generated": Time.get_datetime_string_from_system(),
			"runs_per_game": runs,
			"round_seconds": ROUND_SECONDS,
			"games": _report,
			"mutator_smoke": _mutator_report,
		}, "  "))
		json.close()
	var html := FileAccess.open("%s/report.html" % OUT_DIR, FileAccess.WRITE)
	if html != null:
		html.store_string(_html())
		html.close()


func _html() -> String:
	var rows := ""
	for r in _report:
		var colour: String = ["#1d3", "#fd4", "#f55"][int(r["severity"])]
		rows += """<tr>
<td class="id">%s<div class="cat">%s</div></td>
<td>%d</td><td>%.1fs</td><td>%.0f%%</td><td>%.0f%%</td><td>%.0f%%</td><td>%.0f%%</td><td>%.1f</td>
<td><span class="dot" style="background:%s"></span>%s</td></tr>\n""" % [
			r["name"], r["category"], int(r["runs"]), float(r["avg_duration"]),
			float(r["tie_rate"]) * 100.0, float(r["slot_bias"]) * 100.0,
			float(r["character_bias"]) * 100.0, float(r["expert_edge"]) * 100.0,
			float(r["avg_score"]), colour,
			", ".join(r["flags"]) if not r["flags"].is_empty() else "ok"]
	var mutator_rows := ""
	for r in _mutator_report:
		var colour: String = "#f55" if int(r["severity"]) > 0 else "#1d3"
		mutator_rows += """<tr><td class="id">%s</td><td>%s</td><td>%s</td>
<td><span class="dot" style="background:%s"></span>%s</td></tr>\n""" % [
			r["name"], "ok" if r["mutated_ok"] else "FAIL", "ok" if r["chaos_ok"] else "FAIL",
			colour, ", ".join(r["flags"]) if not r["flags"].is_empty() else "ok"]

	return """<!doctype html><meta charset="utf-8"><title>Kras Pass — balance report</title>
<style>
body{background:#0d1020;color:#f2f4ff;font:14px/1.5 -apple-system,system-ui,sans-serif;margin:40px}
h1{color:#ffb347;margin-bottom:4px} .sub{color:#9aa2c8;margin-bottom:24px}
table{border-collapse:collapse;width:100%%} th{text-align:left;color:#9aa2c8;font-weight:600;
border-bottom:1px solid #252c52;padding:8px 10px} td{padding:8px 10px;border-bottom:1px solid #171b32}
.id{font-weight:600} .cat{color:#9aa2c8;font-weight:400;font-size:12px}
.dot{display:inline-block;width:9px;height:9px;border-radius:50%%;margin-right:8px}
.note{color:#9aa2c8;margin-top:24px;max-width:60em}
</style>
<h1>Kras Pass — balance report</h1>
<div class="sub">%s · %d runs per game · %.0fs rounds</div>
<table><tr><th>Mini-game</th><th>Runs</th><th>Length</th><th>Ties</th><th>Slot bias</th>
<th>Character bias</th><th>Expert share</th><th>Avg score</th><th>Verdict</th></tr>
%s</table>
<p class="note"><b>Slot bias</b> and <b>character bias</b> are how far the most-favoured
spawn slot or competitor sits above an even share; characters are rotated through slots
between runs so the two cannot be confused. <b>Expert share</b> is the fraction of points
an Expert pair takes from an Easy pair with identical characters, mirrored across slots —
50%% means the difficulty tiers do nothing in this game.</p>
<h1 style="margin-top:32px">Mutator &amp; chaos smoke pass</h1>
<div class="sub">one run under a deliberately over-stuffed mutator set, one run with chaos mode on</div>
<table><tr><th>Mini-game</th><th>Mutated run</th><th>Chaos run</th><th>Verdict</th></tr>
%s</table>
""" % [Time.get_datetime_string_from_system(), runs, ROUND_SECONDS, rows, mutator_rows]
