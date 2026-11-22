extends RefCounted

const LIVE_FIELDS := [
	"health", "max_health", "charge", "damage_percent", "alive", "lives", "carrying",
	"velocity", "_impulse", "_stun", "_dash_cd", "_dash_time", "_attack_cd",
	"_attack_time", "_invuln", "_hitstop", "_last_hit_by", "_last_hit_timer",
	"_fx_time", "_spin_time", "_shocked", "_snow_timer", "_tick_prepared",
	"_prepared_hitstop", "_prepared_wish", "_prepared_attack", "mods", "mutator",
]
const MOVEMENT_FIELDS := [
	"top_speed", "acceleration", "friction", "jump_velocity", "turn_rate", "air_control",
]


func run(t: TestHarness, host: Node) -> void:
	t.suite("opt-in compound budget: actual Duel contact against neutral")
	var cfg := MatchConfig.build("duel_pit", ["nabta", "sakhra", "fanoos", "ramla"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
		t.equal(fighter._duel_compound_budget_enabled, true, "current Duel opts into its versioned profile")
	var actor: Fighter = scene.ctx.fighter(0)
	var neutral: Fighter = scene.ctx.fighter(1)
	neutral.data = CharacterData.new()
	neutral._apply_character()
	var rows: Array[Dictionary] = []
	var cases: Array[Dictionary] = [{"label": "neutral", "data": CharacterData.new()}]
	for authored in Registry.characters():
		cases.append({"label": authored.id + "/authored_perk", "data": authored})
		var plain := authored.duplicate() as CharacterData
		plain.perk = ""
		cases.append({"label": authored.id + "/without_perk", "data": plain})
		for scale in [0.9, 1.1]:
			var resistance := authored.duplicate() as CharacterData
			resistance.perk = "resistance"
			resistance.perk_scale = scale
			cases.append({"label": authored.id + "/resistance_" + str(scale), "data": resistance})
	t.equal(Registry.characters().size(), 8, "all eight authored characters are covered")
	for entry in cases:
		actor.set_duel_compound_budget_enabled(false)
		actor.data = entry.data
		actor._apply_character()
		var base_power := actor.knock_power
		var base_resist := actor.knock_resist
		var movement := _snapshot(actor, MOVEMENT_FIELDS)
		var stats: Dictionary = actor._tuning
		var d: CharacterData = actor.data
		t.near(base_power, float(stats.power_base) + float(stats.power_range) * d.power,
			0.00000001, entry.label + " disabled outgoing power is legacy-derived")
		t.near(base_resist, (float(stats.resist_base) + float(stats.resist_range) * d.weight)
			* d.perk_factor("resistance"), 0.00000001, entry.label + " cache is after existing perks")
		for closing in [4.5, 8.0, 12.0]:
			for dash in [false, true]:
				actor.set_duel_compound_budget_enabled(false)
				var raw := _exchange(actor, neutral, closing, dash)
				actor.set_duel_compound_budget_enabled(true)
				var profiled := _exchange(actor, neutral, closing, dash)
				var measured_ratio: float = profiled.outgoing / profiled.incoming
				var raw_ratio: float = raw.outgoing / raw.incoming
				var expected_ratio := clampf(raw_ratio, 0.85, 1.15)
				var label: String = "%s speed=%.1f dash=%s" % [entry.label, closing, dash]
				t.ok(profiled.outgoing > 0.0 and profiled.incoming > 0.0, label + " real reciprocal hits landed")
				t.ok(measured_ratio >= 0.85 - 0.00001 and measured_ratio <= 1.15 + 0.00001,
					label + " measured reciprocal impulse stays within budget")
				t.near(measured_ratio, expected_ratio, 0.00001, label + " bounds measured raw contact, not just formula")
				t.near(actor.knock_power / base_power, actor.knock_resist / base_resist,
					0.00000001, label + " power and resistance share one scale")
				actor.reapply_duel_compound_budget_profile()
				var repeated := _exchange(actor, neutral, closing, dash)
				t.near(repeated.outgoing, profiled.outgoing, 0.00001, label + " repeated profile preserves actual outgoing hit")
				t.near(repeated.incoming, profiled.incoming, 0.00001, label + " repeated profile preserves actual incoming hit")
				actor.set_duel_compound_budget_enabled(false)
				var restored := _exchange(actor, neutral, closing, dash)
				t.near(restored.outgoing, raw.outgoing, 0.00001, label + " disabling restores actual outgoing hit")
				t.near(restored.incoming, raw.incoming, 0.00001, label + " disabling restores actual incoming hit")
				rows.append({"character": d.id, "case": entry.label, "perk": d.perk,
					"perk_scale": d.perk_scale, "closing": closing, "dash": dash,
					"raw": raw, "profiled": profiled, "measured_ratio": measured_ratio,
					"expected_clamped_measured_ratio": expected_ratio, "restored": restored})
		_seed_live_state(actor)
		var state := _snapshot(actor, LIVE_FIELDS)
		actor.set_duel_compound_budget_enabled(true)
		var profile_power := actor.knock_power
		var profile_resist := actor.knock_resist
		for repeat_index in 3:
			actor.set_duel_compound_budget_enabled(true)
			actor.reapply_duel_compound_budget_profile()
			t.near(actor.knock_power, profile_power, 0.00000001, entry.label + " repeated enable has no power drift")
			t.near(actor.knock_resist, profile_resist, 0.00000001, entry.label + " repeated enable has no resistance drift")
			t.equal(_snapshot(actor, LIVE_FIELDS), state, entry.label + " enable/reapply preserves every live field")
			t.equal(_snapshot(actor, MOVEMENT_FIELDS), movement, entry.label + " profile never changes movement")
			actor._apply_character()
			t.near(actor.knock_power, profile_power, 0.00000001, entry.label + " stats reapply uses unscaled power")
			t.near(actor.knock_resist, profile_resist, 0.00000001, entry.label + " stats reapply uses post-perk resistance")
			t.equal(_snapshot(actor, LIVE_FIELDS), state, entry.label + " stats reapply does not heal or reset runtime")
			actor.set_duel_compound_budget_enabled(false)
			actor.set_duel_compound_budget_enabled(false)
			actor.reapply_duel_compound_budget_profile()
			t.near(actor.knock_power, base_power, 0.00000001, entry.label + " disabled power is exactly reversible")
			t.near(actor.knock_resist, base_resist, 0.00000001, entry.label + " disabled resistance is exactly reversible")
			t.equal(_snapshot(actor, LIVE_FIELDS), state, entry.label + " disable preserves every live field")
			actor.set_duel_compound_budget_enabled(true)
		if entry.label == "neutral":
			t.near(profile_power, base_power, 0.00000001, "neutral power unchanged")
			t.near(profile_resist, base_resist, 0.00000001, "neutral resistance unchanged")
		# Replace character data while opted in: a fresh fighter is the reference.
		var changed := CharacterData.new()
		changed.perk = "resistance"
		changed.perk_scale = 1.1
		actor.data = changed
		actor._apply_character()
		var fresh := Fighter.new()
		fresh.data = changed
		fresh._apply_character()
		fresh.set_duel_compound_budget_enabled(true)
		t.near(actor.knock_power, fresh.knock_power, 0.00000001, entry.label + " new data replaces cached power")
		t.near(actor.knock_resist, fresh.knock_resist, 0.00000001, entry.label + " new perk replaces cached resistance")
		t.equal(_snapshot(actor, LIVE_FIELDS), state, entry.label + " replacement data preserves runtime")
		fresh.free()
		await host.get_tree().process_frame
	t.equal(rows.size(), 198, "33 authored/perk/neutral cases times three speeds times two dash states")
	_check_uninitialized_profile(t)
	var file := FileAccess.open(SaveSystem.storage_root.path_join("duel-compound-budget-contacts.json"), FileAccess.WRITE)
	t.ok(file != null, "actual contact evidence writes to isolated test storage")
	if file != null:
		file.store_string(JSON.stringify({"contact_cases": rows.size(), "rows": rows}))
		file.close()
	scene.teardown()
	scene.queue_free()
	Fighter.clear_impact_state()
	await host.get_tree().process_frame


func _exchange(actor: Fighter, neutral: Fighter, closing: float, dash: bool) -> Dictionary:
	_reset_contact(actor, dash)
	_reset_contact(neutral, dash)
	actor._deal_ram(neutral, Vector3.RIGHT, closing, Vector3.ZERO, actor._tuning)
	var outgoing := neutral._impulse.x
	_reset_contact(actor, dash)
	_reset_contact(neutral, dash)
	neutral._deal_ram(actor, Vector3.LEFT, closing, Vector3.ZERO, neutral._tuning)
	return {"outgoing": outgoing, "incoming": -actor._impulse.x}


func _reset_contact(fighter: Fighter, dash: bool) -> void:
	fighter.alive = true
	fighter._dash_time = 0.1 if dash else 0.0
	fighter._invuln = 0.0
	fighter._impulse = Vector3.ZERO
	fighter.damage_percent = 0.0
	fighter.health = fighter.max_health
	fighter.mods["weight"] = 1.0
	fighter.mods["push"] = 1.0
	fighter.mods["shield"] = 0.0
	fighter.mods["resist_taken"] = 1.0
	fighter.mutator["knockback_taken"] = 1.0


func _snapshot(fighter: Fighter, fields: Array) -> Dictionary:
	var snapshot := {}
	for field in fields:
		var value = fighter.get(field)
		snapshot[field] = value.duplicate(true) if value is Dictionary else value
	return snapshot


func _seed_live_state(fighter: Fighter) -> void:
	fighter.health = 37.0
	fighter.charge = 0.23
	fighter.damage_percent = 41.0
	fighter.velocity = Vector3(1.0, 2.0, 3.0)
	fighter._impulse = Vector3(4.0, 5.0, 6.0)
	fighter._stun = 0.31
	fighter._dash_cd = 0.32
	fighter._dash_time = 0.33
	fighter._attack_cd = 0.34
	fighter._attack_time = 0.35
	fighter._invuln = 0.36
	fighter._hitstop = 0.37
	fighter._last_hit_timer = 0.38
	fighter._last_hit_by = 3
	fighter.mods["push"] = 1.2
	fighter.mods["weight"] = 0.9
	fighter.mods["resist_taken"] = 0.85
	fighter.mods["frozen"] = 0.42
	fighter.mutator["knockback_taken"] = 0.8


func _check_uninitialized_profile(t: TestHarness) -> void:
	var fresh := Fighter.new()
	fresh.health = 17.0
	fresh.charge = 0.2
	var before := _snapshot(fresh, LIVE_FIELDS)
	fresh.set_duel_compound_budget_enabled(true)
	fresh.set_duel_compound_budget_enabled(false)
	fresh.reapply_duel_compound_budget_profile()
	t.equal(_snapshot(fresh, LIVE_FIELDS), before, "profile before derived stats never resets runtime")
	fresh.free()
