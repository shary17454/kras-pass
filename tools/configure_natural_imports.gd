extends SceneTree


func _initialize() -> void:
	configure("res://assets/natural")
	quit()


func configure(path: String) -> void:
	if FileAccess.file_exists(path + "/.gdignore"):
		return
	for folder in DirAccess.get_directories_at(path):
		configure(path + "/" + folder)
	for file in DirAccess.get_files_at(path):
		if not file.ends_with(".jpg.import"):
			continue
		var config := ConfigFile.new()
		var full_path := path + "/" + file
		if config.load(full_path) != OK:
			continue
		config.set_value("params", "compress/mode", 2)
		config.set_value("params", "compress/high_quality", true)
		config.set_value("params", "mipmaps/generate", true)
		config.set_value("params", "process/size_limit", 2048)
		config.save(full_path)
		print("Configured 3D texture: ", file)
