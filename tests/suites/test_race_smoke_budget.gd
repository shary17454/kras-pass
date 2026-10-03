extends RefCounted

const Config = preload("res://tests/network_smoke_config.gd")


func run(t: TestHarness) -> void:
	t.suite("race smoke budget")
	t.equal(Config.kart_deadline(false), 900, "two full race windows plus setup")
	t.equal(Config.kart_deadline(true), 1680, "three races and bounded final attempts plus setup")
	t.greater(Config.kart_deadline(true), Config.kart_deadline(false), "tournament remains separately bounded")
