extends Node
## Unlocks the whole collection for whoever knows the phrase. Autoload: `Access`.
##
## The project already had one switch that opens everything — `DevTools.unlock_all`
## — wired into every unlock check, but it is gated on `OS.is_debug_build()` and
## so can never fire in a shipped build. This is the release-safe sibling: the
## same five checks, opened by a phrase rather than by a debug flag.
##
## **The phrase is not in this file, and not anywhere else in the repository.**
## What is stored is a salted SHA-256 of it. That matters more than it looks:
## every string a Godot project ships ends up inside the .pck, and `strings` on
## an extracted IPA lists them all — so a plain-text unlock phrase, an owner
## e-mail, or a name in the source is published the moment the app is. A digest
## published is still just a digest.
##
## Changing the phrase is one command, and needs no code edit beyond pasting the
## result over `FINGERPRINT`:
##
##     python3 -c "import hashlib;print(hashlib.sha256(('kras-pass/unlock/v1'+input().strip().lower()).encode()).hexdigest())"
##
## Limits, stated plainly: this keeps the phrase out of the binary, not the
## unlock out of a determined hand. Anyone who guesses the phrase can enter it,
## and anyone with the device can edit the settings file. It is a private door,
## not a lock.

const SALT := "kras-pass/unlock/v1"
const FINGERPRINT := "61760af6f0eb50e450dc2d286cb26cedc11ae9e7366efab1d4beacc580693282"
const SETTING := "access_token"


## True once the phrase has been entered on this device.
func is_active() -> bool:
	return String(UserSettings.get_value(SETTING)) == FINGERPRINT


## Hash what was typed and compare. Case and surrounding spaces are ignored,
## because a phrase typed on a phone keyboard picks up both.
func matches(text: String) -> bool:
	return _digest(text) == FINGERPRINT


## Try a phrase. Returns true and remembers it when it is the right one.
func redeem(text: String) -> bool:
	if not matches(text):
		return false
	UserSettings.set_value(SETTING, FINGERPRINT)
	return true


func revoke() -> void:
	UserSettings.set_value(SETTING, "")


static func _digest(text: String) -> String:
	var normalised := text.strip_edges().to_lower()
	if normalised.is_empty():
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update((SALT + normalised).to_utf8_buffer())
	return ctx.finish().hex_encode()
