class_name MatchContext
extends RefCounted
## Shared state handed to the mini-game controller, the AI brains and the HUD.
##
## Everything a game needs to read is here, and everything it needs to change it
## changes through a method — so scoring, elimination and time are consistent
## across all 21 games and the replay recorder has a single choke point.

var config: MatchConfig
var definition: MiniGameDef
var arena: Node3D
var arena_def: ArenaDef
var fighters: Array[Fighter] = []   ## index == slot
var rng: RandomNumberGenerator
var scores: Array[int] = []
var elimination_order: Array[int] = []
var alive: Array[bool] = []
var time_left := 0.0
var round_index := 0
var phase: int = MatchPhase.P.LOADING
var sudden_death := false
var details: Array = []           # per-slot dictionaries of extra stats
var powerups: Node                # PowerUpSystem, may be null
var machine: Node3D               # HoverMachine, null in games that refuse it
var world_root: Node3D            # where a game parents its own objects

## Set by the controller when the round should end before the clock does.
var early_finish := false


func player_count() -> int:
	return config.player_count() if config != null else 0


func fighter(slot: int) -> Fighter:
	return fighters[slot] if slot >= 0 and slot < fighters.size() else null


func is_alive(slot: int) -> bool:
	return slot >= 0 and slot < alive.size() and alive[slot]


func alive_count() -> int:
	var n := 0
	for a in alive:
		if a:
			n += 1
	return n


func alive_slots() -> Array[int]:
	var out: Array[int] = []
	for i in alive.size():
		if alive[i]:
			out.append(i)
	return out


func add_score(slot: int, amount: int) -> void:
	if slot < 0 or slot >= scores.size():
		return
	var before := scores[slot]
	scores[slot] = maxi(0, scores[slot] + amount)
	if scores[slot] != before:
		EventBus.score_changed.emit(slot, scores[slot])


func set_score(slot: int, value: int) -> void:
	if slot < 0 or slot >= scores.size():
		return
	scores[slot] = value
	EventBus.score_changed.emit(slot, value)


func bump_detail(slot: int, key: String, amount: int = 1) -> void:
	if slot < 0 or slot >= details.size():
		return
	details[slot][key] = int(details[slot].get(key, 0)) + amount


func set_detail(slot: int, key: String, value) -> void:
	if slot >= 0 and slot < details.size():
		details[slot][key] = value


## Marks a slot out of the round. Elimination order drives SURVIVAL scoring:
## the last one standing gets the top score, the first one out the lowest.
func eliminate(slot: int) -> void:
	if not is_alive(slot):
		return
	alive[slot] = false
	elimination_order.append(slot)
	var place := alive_count() + 1
	EventBus.player_eliminated.emit(slot, place)
	var f := fighter(slot)
	if f != null and is_instance_valid(f):
		f.on_eliminated()


func revive(slot: int) -> void:
	if slot < 0 or slot >= alive.size() or alive[slot]:
		return
	alive[slot] = true
	elimination_order.erase(slot)
	EventBus.player_respawned.emit(slot)


## Survival scoring: last alive scores player_count, first out scores 1.
func survival_scores() -> Array[int]:
	var n := player_count()
	var out: Array[int] = []
	out.resize(n)
	out.fill(0)
	var still: Array[int] = alive_slots()
	for slot in still:
		out[slot] = n
	var rank := n - still.size()
	for i in range(elimination_order.size() - 1, -1, -1):
		out[elimination_order[i]] = rank
		rank -= 1
	for i in n:
		out[i] = maxi(out[i], 1)
	return out


func leader_slot() -> int:
	var best := -1
	var best_score := -2147483648
	for i in scores.size():
		if scores[i] > best_score:
			best_score = scores[i]
			best = i
	return best


func nearest_rival(slot: int) -> int:
	var me := fighter(slot)
	if me == null:
		return -1
	var best := -1
	var best_d := INF
	for i in fighters.size():
		if i == slot or not is_alive(i):
			continue
		var o := fighter(i)
		if o == null or not is_instance_valid(o):
			continue
		var d: float = me.global_position.distance_squared_to(o.global_position)
		if d < best_d:
			best_d = d
			best = i
	return best


func arena_center() -> Vector3:
	return arena.global_position if arena != null else Vector3.ZERO


func arena_radius() -> float:
	return arena_def.radius if arena_def != null else 12.0
