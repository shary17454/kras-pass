extends Node

const TRACKS := ["menu", "arena", "arena_b", "tension", "victory", "adventure"]
const DIRECTORY := "res://assets/audio/music"


func _ready() -> void:
	var error := DirAccess.make_dir_recursive_absolute(DIRECTORY)
	if error != OK:
		push_error("Cannot create original music directory: " + str(error))
		get_tree().quit(1)
		return
	for id in TRACKS:
		var samples = AudioManager._render_track(id)
		if samples == null:
			push_error("Unknown original music track: " + id)
			get_tree().quit(1)
			return
		var stream := Synth.to_stream(samples, true)
		error = ResourceSaver.save(stream, DIRECTORY + "/" + id + ".res")
		if error != OK:
			push_error("Cannot bake music track: " + id)
			get_tree().quit(1)
			return
		print("BAKED ORIGINAL MUSIC: " + id)
	get_tree().quit()
