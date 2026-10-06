extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("bundled bilingual UI fonts")
	var characters := {}
	for locale in ["ar", "en"]:
		var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/loc/%s.json" % locale))
		for value in table.values():
			for character in str(value):
				var codepoint := character.unicode_at(0)
				if codepoint >= 32 and codepoint not in [0x200D, 0xFE0E, 0xFE0F]:
					characters[codepoint] = true
	for character in "● ▲ ■ ★ ♥ ◇ ✦ → ← ☄ ❄ 🏆 🎲 🔥 ⚡ 👑 🏁 🎮 ⏸ ⏵ ✕":
		characters[character.unicode_at(0)] = true
	var server := TextServerManager.get_primary_interface()
	for font in [UIKit.font(), UIKit.font_bold()]:
		t.ok(not font is SystemFont, "UI has no implicit system font dependency")
		var bundled_rids: Array = font.get_rids()
		for codepoint in characters:
			t.ok(font.has_char(codepoint), "bundled chain covers UI U+%04X" % codepoint)
		for sample in ["كراس باس بطولة الجولة الأخيرة", "KRAS PASS 0123456789", "● ▲ ■ ★ ☄ ❄", "🏆 🎲 🔥 ⚡ 👑"]:
			var line := TextLine.new()
			t.ok(line.add_string(sample, font, 32), "bilingual and symbol sample shapes")
			t.ok(line.get_line_width() > 0.0, "sample has visible width")
			for glyph in server.shaped_text_get_glyphs(line.get_rid()):
				t.ok(glyph.font_rid.is_valid() and server.has(glyph.font_rid), "sample owns valid font glyphs")
				t.ok(glyph.index != 0, "sample has no missing-glyph boxes")
				t.ok(glyph.font_rid in bundled_rids, "known UI sample never requests system fallback glyphs")
	if UIKit.font() is FontVariation:
		for font in [UIKit.font(), UIKit.font_bold()]:
			var files: Array[Font] = [font.base_font]
			for fallback in font.fallbacks:
				files.append(fallback.base_font if fallback is FontVariation else fallback)
			for index in files.size():
				var file := files[index]
				t.ok(file is FontFile, "every explicit fallback is a bundled face")
				t.ok(not file.allow_system_fallback, "known UI never enables automatic system fallback")
	var regular := UIKit.font()
	t.equal(UIKit.font_for_text("كراس باس 🏆"), regular, "known mixed text reuses ordinary bundled font")
	var extended := UIKit.font_for_text("玩家")
	t.ok(extended != regular, "other player-name scripts receive a separate fallback chain")
	t.ok(extended is SystemFont and extended.allow_system_fallback, "other scripts preserve the previous system-font path")
	t.equal(UIKit.font_for_text("玩家"), extended, "extended user font is reused rather than rebuilt per label")
	var previous := SystemFont.new()
	previous.font_names = PackedStringArray(["SF Pro Display", "Helvetica Neue", "Segoe UI", "Noto Sans", "Arial"])
	previous.allow_system_fallback = true
	var widths: Array[float] = []
	var missing_counts: Array[int] = []
	for face in [extended, previous]:
		var user_line := TextLine.new()
		t.ok(user_line.add_string("玩家", face, 32), "other-script player name shapes")
		widths.append(user_line.get_line_width())
		var missing := 0
		for glyph in server.shaped_text_get_glyphs(user_line.get_rid()):
			if glyph.index == 0 or not glyph.font_rid.is_valid():
				missing += 1
		missing_counts.append(missing)
	t.equal(missing_counts[0], missing_counts[1], "other-script glyph coverage is unchanged from prior OS path")
	t.near(widths[0], widths[1], 0.01, "other-script shaping preserves prior OS path")
	for rid in regular.get_rids():
		t.ok(not server.font_is_allow_system_fallback(rid), "user fallback cannot mutate shared ordinary faces")
	var field := LineEdit.new()
	UIKit.fit_input_font(field, "كراس باس")
	t.equal(field.get_theme_font("font"), regular, "ordinary input uses bundled face")
	field.text = "玩家"
	field.text_changed.emit(field.text)
	t.equal(field.get_theme_font("font"), extended, "typing another script switches only that input")
	field.text = "KRAS"
	field.text_changed.emit(field.text)
	t.equal(field.get_theme_font("font"), regular, "returning to known text returns to bounded font")
	field.free()
