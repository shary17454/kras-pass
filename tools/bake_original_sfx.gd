extends Node

const SOUNDS := ["cannon_fire", "ui_move", "ui_select", "ui_back", "ui_error",
	"countdown", "go", "hit", "swing", "dash", "fall", "splash", "burn",
	"eliminate", "pickup", "powerup", "score", "crate_break", "explode",
	"shield_break", "shock", "ice_crack", "skid", "rumble", "gust",
	"machine_hum", "machine_alert", "beam", "bounce", "tick", "whistle",
	"win", "lose", "unlock", "trophy", "engine", "correct", "wrong"]
const AMBIENCES := ["atv_engine", "wind"]


func _ready() -> void:
	if "--benchmark-only" in OS.get_cmdline_user_args():
		var started := Time.get_ticks_usec()
		var worst := 0.0
		var worst_id := ""
		AudioManager._bank.clear()
		AudioManager._ambience_bank.clear()
		for id in SOUNDS + AMBIENCES:
			var item_started := Time.get_ticks_usec()
			var stream = AudioManager._sound(id) if id in SOUNDS else AudioManager._ambience_stream(id)
			if stream == null:
				get_tree().quit(1)
				return
			var elapsed := (Time.get_ticks_usec() - item_started) / 1000.0
			if elapsed > worst:
				worst = elapsed
				worst_id = id
		print("ORIGINAL SFX FIRST-LOAD: " + JSON.stringify({"sounds": SOUNDS.size(),
			"ambiences": AMBIENCES.size(), "total_ms": (Time.get_ticks_usec() - started) / 1000.0,
			"worst_ms": worst, "worst_id": worst_id}))
		get_tree().quit()
		return
	for category in ["sfx", "ambience"]:
		var directory: String = "res://assets/audio/" + category
		if DirAccess.make_dir_recursive_absolute(directory) != OK:
			push_error("Cannot create original sound directory")
			get_tree().quit(1)
			return
		for id in SOUNDS if category == "sfx" else AMBIENCES:
			var samples = AudioManager._render_sfx(id) if category == "sfx" else AudioManager._render_ambience(id)
			if samples == null or ResourceSaver.save(Synth.to_stream(samples, category == "ambience"), directory + "/" + id + ".res") != OK:
				push_error("Cannot bake original sound: " + id)
				get_tree().quit(1)
				return
			print("BAKED ORIGINAL SOUND: " + category + "/" + id)
	get_tree().quit()
