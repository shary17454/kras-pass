extends Screen
## Credits, reached from the main menu.


func build() -> void:
	title(Loc.t("credits.title"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	var v := UIKit.vbox(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	var card := UIKit.panel(UIKit.PANEL_HI, 20)
	v.add_child(card)
	var content := UIKit.vbox(12)
	card.add_child(content)

	var version := String(ProjectSettings.get_setting("application/config/version", ""))
	content.add_child(UIKit.label(
		"%s — v%s" % [Loc.t("app.title"), version], UIKit.SIZE_HEADING, UIKit.ACCENT, true))
	_line(content, Loc.t("credits.made_with"))
	_line(content, Loc.t("credits.original"))
	_line(content, Loc.t("credits.support"))


func _line(parent: VBoxContainer, text: String) -> void:
	var l := UIKit.label(text, UIKit.SIZE_BODY, UIKit.text_color())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
