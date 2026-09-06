extends RefCounted

func run(t: TestHarness) -> void:
	t.suite("Apple account access isolation")
	var account = load("res://src/net/apple_account.gd").new()
	t.ok(not account.has_all_games(), "guest is never entitled")
	account._apply_access({"subject": "verified", "expires": Time.get_unix_time_from_system() + 300, "all_games": true})
	t.ok(account.has_all_games(), "verified current access is accepted")
	account._expires = 1
	t.ok(not account.has_all_games(), "expired access is denied")
	account._apply_access({"subject": "ordinary", "expires": Time.get_unix_time_from_system() + 300, "all_games": false})
	t.ok(not account.has_all_games(), "ordinary account does not unlock games")
	account._apply_access({"all_games": true})
	t.ok(not account.has_all_games(), "incomplete response cannot grant access")
	account._apply_access({"subject": "verified", "expires": Time.get_unix_time_from_system() + 300, "all_games": true})
	var generation: int = account._generation
	account._profile_changed()
	t.ok(not account.has_all_games() and not account.signed_in, "switching profile immediately clears access")
	t.ok(account._generation > generation, "late requests are invalidated by profile switch")
	account.free()
