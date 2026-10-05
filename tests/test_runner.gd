extends Node
## Headless test entry point.
##
##   godot --headless --fixed-fps 60 --path . tests/test_runner.tscn
##
## Backs up the real profile before running, restores it afterwards, and exits
## with a non-zero status on failure so CI can gate on it.

const SUITES := [
	"res://tests/suites/test_offscreen_cues.gd",
	"res://tests/suites/test_keeper_contact_plane.gd",
	"res://tests/suites/test_collectible_arbitration.gd",
	"res://tests/suites/test_world_camera.gd",
	"res://tests/suites/test_balance_sim.gd",
	"res://tests/suites/test_network.gd",
	"res://tests/suites/test_apple_account.gd",
	"res://tests/suites/test_scoring.gd",
	"res://tests/suites/test_content.gd",
	"res://tests/suites/test_save.gd",
	"res://tests/suites/test_systems.gd",
	"res://tests/suites/test_input_sources.gd",
	"res://tests/suites/test_replay.gd",
	"res://tests/suites/test_playlist.gd",
	"res://tests/suites/test_party.gd",
	"res://tests/suites/test_tournament_checkpoint.gd",
	"res://tests/suites/test_router_recovery.gd",
	"res://tests/suites/test_perf_sampling.gd",
	"res://tests/suites/test_road_query.gd",
	"res://tests/suites/test_road_query_boundaries.gd",
	"res://tests/suites/test_live_shadow_quality.gd",
	"res://tests/suites/test_match_preparation.gd",
	"res://tests/suites/test_tournament_prefetch.gd",
	"res://tests/suites/test_match_preparation_session.gd",
	"res://tests/suites/test_online_start_handoff.gd",
	"res://tests/suites/test_main_menu_exit.gd",
	"res://tests/suites/test_party_progress.gd",
	"res://tests/suites/test_mutators.gd",
	"res://tests/suites/test_matches.gd",
	"res://tests/suites/test_boss_round_reset.gd",
	"res://tests/suites/test_sovereign_collapse.gd",
	"res://tests/suites/test_sovereign_targets.gd",
	"res://tests/suites/test_forge_network.gd",
	"res://tests/suites/test_dreadnought_network.gd",
	"res://tests/suites/test_sovereign_network.gd",
	"res://tests/suites/test_colossus_network.gd",
	"res://tests/suites/test_colossus_targets.gd",
	"res://tests/suites/test_shrink_ejection.gd",
	"res://tests/suites/test_ram_contact_lifetime.gd",
	"res://tests/suites/test_colossus_respawn_spacing.gd",
	"res://tests/suites/test_forge_feeding.gd",
	"res://tests/suites/test_quick_draw.gd",
	"res://tests/suites/test_symbol_echo.gd",
	"res://tests/suites/test_crate_rounds.gd",
	"res://tests/suites/test_relay_rounds.gd",
	"res://tests/suites/test_relay_floor.gd",
	"res://tests/suites/test_crater_floor.gd",
	"res://tests/suites/test_colossus_approach.gd",
	"res://tests/suites/test_hurdle_rounds.gd",
	"res://tests/suites/test_runner_recovery.gd",
	"res://tests/suites/test_hurdle_network.gd",
	"res://tests/suites/test_survival_rounds.gd",
	"res://tests/suites/test_tide_network.gd",
	"res://tests/suites/test_tide_scoring.gd",
	"res://tests/suites/test_sweeper_network.gd",
	"res://tests/suites/test_sweeper_impact.gd",
	"res://tests/suites/test_dodger_perception.gd",
	"res://tests/suites/test_arena_respawn_scoring.gd",
	"res://tests/suites/test_duel_network.gd",
	"res://tests/suites/test_duo_network.gd",
	"res://tests/suites/test_floe_reset.gd",
	"res://tests/suites/test_floe_network.gd",
	"res://tests/suites/test_turret_rounds.gd",
	"res://tests/suites/test_turret_network.gd",
	"res://tests/suites/test_tank_network.gd",
	"res://tests/suites/test_tank_terrain.gd",
	"res://tests/suites/test_scrap_network.gd",
	"res://tests/suites/test_siege_network.gd",
	"res://tests/suites/test_siege_final_evidence.gd",
	"res://tests/suites/test_ai_visibility.gd",
	"res://tests/suites/test_ai_occlusion.gd",
	"res://tests/suites/test_collector_observed_motion.gd",
	"res://tests/suites/test_race_smoke_budget.gd",
	"res://tests/suites/test_lab_smoke_budget.gd",
	"res://tests/suites/test_fawda_network.gd",
	"res://tests/suites/test_fawda_round_evidence.gd",
	"res://tests/suites/test_fawda_final_evidence.gd",
	"res://tests/suites/test_race_rounds.gd",
	"res://tests/suites/test_kart_network.gd",
	"res://tests/suites/test_armed_race_network.gd",
	"res://tests/suites/test_bumper_network.gd",
	"res://tests/suites/test_crate_network.gd",
	"res://tests/suites/test_echo_perception.gd",
	"res://tests/suites/test_echo_network.gd",
	"res://tests/suites/test_draw_network.gd",
	"res://tests/suites/test_goal_guard.gd",
	"res://tests/suites/test_magnet_network.gd",
	"res://tests/suites/test_storm_network.gd",
	"res://tests/suites/test_sky_court.gd",
	"res://tests/suites/test_sky_network.gd",
	"res://tests/suites/test_arena_tiles.gd",
	"res://tests/suites/test_crumble_network.gd",
	"res://tests/suites/test_color_network.gd",
	"res://tests/suites/test_blast_ball.gd",
	"res://tests/suites/test_collection_network.gd",
	"res://tests/suites/test_zone_hold.gd",
	"res://tests/suites/test_relic_hold.gd",
	"res://tests/suites/test_tag_network.gd",
	"res://tests/suites/test_paint_reset.gd",
	"res://tests/suites/test_paint_network.gd",
	"res://tests/suites/test_saboteur_network.gd",
	"res://tests/suites/test_race_conditions.gd",
	"res://tests/suites/test_lifecycle.gd",
]

var _t: TestHarness
var _profile_backup := {}
var _settings_backup := {}


func _ready() -> void:
	await get_tree().process_frame
	_t = TestHarness.new()
	print("\nKRAS PASS test suite — Godot %s, %s" % [
		Engine.get_version_info().string, OS.get_name()])
	_backup()
	var started := Time.get_ticks_msec()
	var filter := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			filter = argument.trim_prefix("--suite=")
	var selected := 0
	for path in SUITES:
		if not filter.is_empty() and not path.ends_with("test_%s.gd" % filter):
			continue
		selected += 1
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			_t.suite(path)
			_t.ok(false, "suite failed to load")
			continue
		var suite = script.new()
		var previous_count := _t.passed + _t.failed
		# Suites that need the tree take a host node; pure ones do not.
		if suite.run.get_argument_count() >= 2:
			await suite.run(_t, self)
		else:
			suite.run(_t)
		_t.require_suite_assertions(previous_count)
	_t.ok(selected > 0, "at least one test suite was selected")
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("\nfinished in %.1fs" % elapsed)
	_restore()
	# Let audio playback references drain before the engine tears down its mixer.
	AudioManager.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	# Fixed-FPS headless frames may finish before one real audio mixer buffer.
	OS.delay_msec(100)
	var code := _t.report()
	get_tree().quit(code)


## Tests write to the same `user://` directory as the game. Snapshot the two
## real slots first so running the suite never costs a developer their progress.
func _backup() -> void:
	_profile_backup = SaveSystem.profile().duplicate(true)
	_settings_backup = SaveSystem.settings().duplicate(true)


func _restore() -> void:
	SaveSystem.erase("test_profile")
	SaveSystem.set_profile(_profile_backup)
	SaveSystem.set_settings(_settings_backup)
	SaveSystem.flush()
