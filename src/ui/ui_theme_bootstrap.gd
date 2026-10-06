extends Node
## Imported fonts are unavailable while a fresh editor checkout is importing.
## Populate the dependency-free project theme before any runtime UI is built.

func _enter_tree() -> void:
	var project_theme := ThemeDB.get_project_theme()
	var bundled_theme := load("res://assets/fonts/ui_theme.tres") as Theme
	if project_theme == null or bundled_theme == null or bundled_theme.default_font == null:
		push_error("Cannot initialize the bundled project font")
		get_tree().quit(1)
		return
	project_theme.default_font = bundled_theme.default_font
	project_theme.default_font_size = bundled_theme.default_font_size
