extends Node
## Decoupled signal hub. Autoload name: `EventBus`.
##
## Mini-games emit here; HUD, audio, stats, achievements and the replay recorder
## listen. Nothing in `src/minigames/` may hold a direct reference to a UI or
## progression node — that rule is what keeps 20+ games from turning into a web
## of cross-dependencies.

# --- match lifecycle -------------------------------------------------------
signal match_phase_changed(phase: int)
signal match_started(config: Resource)
signal round_started(round_index: int)
signal countdown_tick(remaining: int)
signal match_time_changed(remaining: float)
signal sudden_death_started()
## Emitted once per second through the closing seconds of a round, counting
## down. Audio raises the tempo, the HUD reads the clock itself, and haptics
## turn the last beats into something felt.
signal time_warning(seconds_left: int)
signal round_finished(result: Resource)
signal match_finished(result: Resource)

# --- scoring ---------------------------------------------------------------
signal score_changed(player_slot: int, score: int)
signal player_eliminated(player_slot: int, place: int)
signal lead_changed(player_slot: int)

# --- gameplay feedback -----------------------------------------------------
signal player_hit(attacker_slot: int, victim_slot: int, strength: float)
signal player_respawned(player_slot: int)
signal powerup_collected(player_slot: int, powerup_id: String)
signal powerup_expired(player_slot: int, powerup_id: String)
signal pickup_collected(player_slot: int, kind: String, amount: int)
signal hazard_triggered(kind: String, position: Vector3)
signal camera_shake_requested(strength: float, duration: float)
signal hitstop_requested(duration: float)

# --- meta ------------------------------------------------------------------
signal achievement_unlocked(id: String)
signal character_unlocked(id: String)
signal minigame_unlocked(id: String)
signal world_unlocked(id: String)
signal reward_granted(kind: String, amount: int)
signal notification_requested(text: String, icon: String)

# --- input / devices -------------------------------------------------------
signal device_connected(device_id: int)
signal device_disconnected(device_id: int)
signal player_device_lost(player_slot: int)


## Convenience wrapper so gameplay code reads as an action rather than a signal
## emit, and so a future analytics hook has exactly one place to attach.
func shake(strength: float, duration: float = 0.25) -> void:
	if UserSettings != null and not bool(UserSettings.get_value("reduce_effects")):
		camera_shake_requested.emit(strength * float(UserSettings.get_value("camera_shake")), duration)


func hitstop(duration: float) -> void:
	hitstop_requested.emit(duration)


func notify(text: String, icon: String = "") -> void:
	notification_requested.emit(text, icon)
