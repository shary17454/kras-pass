extends RefCounted
## Four-seat rotations of the 14 affine planes over eight character labels.
## Per 56-match cycle: 28 appearances per character, seven per seat,
## and 12 co-appearances for every pair. This is a diagnostic, not a game rule.

const CYCLE_LENGTH := 56


static func roster_for(characters: Array[String], run: int, seed: int) -> Array[String]:
	if characters.size() != 8 or run < 0 or seed < 0:
		return []
	var unique := {}
	for character in characters:
		if character.strip_edges().is_empty() or unique.has(character):
			return []
		unique[character] = true
	var roster: Array[String] = characters.duplicate()
	var random := RandomNumberGenerator.new()
	random.seed = seed + int(run / CYCLE_LENGTH) * 613
	for i in range(7, 0, -1):
		var other := random.randi_range(0, i)
		var previous := roster[i]
		roster[i] = roster[other]
		roster[other] = previous
	var block := int((run % CYCLE_LENGTH) / 4)
	var mask := int(block / 2) + 1
	var side := block % 2
	var quartet: Array[String] = []
	for point in 8:
		var bits := point & mask
		var parity := 0
		while bits > 0:
			parity ^= bits & 1
			bits >>= 1
		if parity == side:
			quartet.append(roster[point])
	var selected: Array[String] = []
	for slot in 4:
		selected.append(quartet[(slot + run) % 4])
	return selected
