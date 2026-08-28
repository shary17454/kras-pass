extends Node
## Turns match events into felt ones. Autoload name: `Haptics`.
##
## Spec item 23 lists the moments that need feedback and item 22 asks for it in
## grades rather than as one buzz. Doing that from the individual systems would
## scatter `if this is the local player` checks through gameplay code, so the
## rules live here: subscribe to the EventBus once, decide who should feel what,
## and let InputRouter deal with whether that player is holding a pad or a
## phone. Nothing in the mini-games, actors or UI knows this file exists.

const H := InputRouter.Haptic


func _ready() -> void:
	EventBus.countdown_tick.connect(_on_countdown)
	EventBus.player_eliminated.connect(_on_eliminated)
	EventBus.powerup_collected.connect(_on_powerup)
	EventBus.pickup_collected.connect(_on_pickup)
	EventBus.player_respawned.connect(_on_respawned)
	EventBus.sudden_death_started.connect(_on_sudden_death)
	EventBus.match_finished.connect(_on_match_finished)
	EventBus.achievement_unlocked.connect(_on_achievement)


## The last beat before "go" is the one worth feeling, not all four.
func _on_countdown(remaining: int) -> void:
	_all(H.LIGHT if remaining > 1 else H.MEDIUM)


## Going out is the heaviest thing that happens to you, and it is worth
## something quieter to everyone else — that is how you notice the field
## thinning without looking away from your own fight.
func _on_eliminated(slot: int, _place: int) -> void:
	_one(slot, H.HEAVY)
	_all_except(slot, H.LIGHT)


func _on_powerup(slot: int, _id: String) -> void:
	_one(slot, H.MEDIUM)


func _on_pickup(slot: int, _kind: String, _amount: int) -> void:
	_one(slot, H.LIGHT)


func _on_respawned(slot: int) -> void:
	_one(slot, H.MEDIUM)


func _on_sudden_death() -> void:
	_all(H.HEAVY)


## Winners get the celebration pattern, everyone else gets a single thud, so
## the result is legible before the screen has finished animating.
func _on_match_finished(result) -> void:
	if result == null:
		return
	for slot in InputRouter.MAX_SLOTS:
		if not InputRouter.can_feel(slot):
			continue
		if result.has_method("place_of") and int(result.place_of(slot)) == 1:
			InputRouter.haptic(slot, H.SUCCESS)
		else:
			InputRouter.haptic(slot, H.MEDIUM)


func _on_achievement(_id: String) -> void:
	_all(H.SUCCESS)


func _one(slot: int, kind: int) -> void:
	if InputRouter.can_feel(slot):
		InputRouter.haptic(slot, kind)


func _all(kind: int) -> void:
	for slot in InputRouter.MAX_SLOTS:
		if InputRouter.can_feel(slot):
			InputRouter.haptic(slot, kind)


func _all_except(skip: int, kind: int) -> void:
	for slot in InputRouter.MAX_SLOTS:
		if slot != skip and InputRouter.can_feel(slot):
			InputRouter.haptic(slot, kind)
