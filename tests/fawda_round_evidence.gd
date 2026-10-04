extends RefCounted
## Read-only, bounded summaries of the actual host/replica bomb stream.

var rounds := {}


func observe(round_index: int, phase: int, elapsed: float, alive: Array, world: Dictionary) -> bool:
	if not rounds.has(round_index):
		rounds[round_index] = {"samples": 0, "phase": -1, "elapsed": 0.0,
			"alive": [], "bombs": 0, "minimum_fuse": -1.0, "events": {}}
	var row: Dictionary = rounds[round_index]
	var changed := int(row.phase) != phase
	row.samples += 1
	row.phase = phase
	row.elapsed = maxf(float(row.elapsed), elapsed)
	row.alive = alive.duplicate()
	row.bombs = world.get("bombs", []).size()
	for bomb in world.get("bombs", []):
		var fuse := float(bomb.fuse)
		if float(row.minimum_fuse) < 0.0 or fuse < float(row.minimum_fuse):
			row.minimum_fuse = fuse
	for kind in world.get("events", {}):
		row.events[kind] = maxi(int(row.events.get(kind, 0)), int(world.events[kind].sequence))
	return changed


func summary(round_index: int) -> Dictionary:
	return rounds.get(round_index, {}).duplicate(true)
