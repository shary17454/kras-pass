extends Screen
## Release notes shown from the main menu.


func build() -> void:
	title(Loc.t("updates.title"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	var v := UIKit.vbox(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	var version := String(ProjectSettings.get_setting("application/config/version", ""))
	var card := UIKit.panel(UIKit.PANEL_HI, 20)
	v.add_child(card)
	var content := UIKit.vbox(12)
	card.add_child(content)

	var headline := UIKit.label(Loc.t("updates.version", {"version": version}), UIKit.SIZE_HEADING, UIKit.ACCENT, true)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(headline)
	_add_note(content, "updates.item.liquid_glass")
	_add_note(content, "updates.item.performance")
	_add_note(content, "updates.item.ai")
	_add_note(content, "updates.item.ice")
	_add_note(content, "updates.item.rocket")


func _add_note(parent: VBoxContainer, key: String) -> void:
	var l := UIKit.label("- " + Loc.t(key), UIKit.SIZE_BODY, UIKit.text_color())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
