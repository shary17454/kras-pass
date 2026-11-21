extends RefCounted
## Real looping players and elapsed tweens, including a stop mid-crossfade.


func run(t: TestHarness, host: Node) -> void:
	t.suite("audio_stop_crossfade")
	for crossfade in [false, true]:
		for fade in [0.0, 0.4]:
			await _stop_case(t, host, crossfade, fade)


func _stop_case(t: TestHarness, host: Node, crossfade: bool, fade: float) -> void:
	t.test("stop fade=%s crossfade=%s" % [fade, crossfade])
	var audio: Node = load("res://src/audio/audio_manager.gd").new()
	host.add_child(audio)
	# Headless normally disables audio; use real players with the Dummy driver.
	audio.enabled = true
	audio._tracks["regression_a"] = _loop()
	audio._tracks["regression_b"] = _loop()
	audio.play_music("regression_a", 0.0)
	await host.get_tree().create_timer(0.05).timeout
	var outgoing: AudioStreamPlayer = audio._music_active
	t.ok(outgoing.playing, "A really started playback")
	if crossfade:
		audio.play_music("regression_b", 1.0)
		await host.get_tree().create_timer(0.2).timeout
		t.ok(audio._music_a.playing and audio._music_b.playing,
			"both players really overlap before stop")
	var active: AudioStreamPlayer = audio._music_active
	var active_db := active.volume_db
	var outgoing_db := outgoing.volume_db
	var interrupted: Tween = audio._fade_tween
	audio.stop_music(fade)
	t.equal(audio.current_track(), "", "stop clears the current track immediately")
	t.ok(not interrupted.is_valid(), "stop cancels the old transition")
	if fade <= 0.0:
		t.ok(not audio._music_a.playing and not audio._music_b.playing,
			"zero fade stops both players synchronously")
	else:
		t.ok(active.playing and outgoing.playing, "positive fade does not stop abruptly")
		await host.get_tree().create_timer(0.15).timeout
		t.ok(active.playing and outgoing.playing, "playback continues during the fade")
		t.ok(active.volume_db < active_db, "active player fades down")
		t.ok(outgoing.volume_db < outgoing_db, "outgoing player also fades down")
	await host.get_tree().create_timer(fade + 0.15).timeout
	t.ok(not audio._music_a.playing, "player A is stopped after the deadline")
	t.ok(not audio._music_b.playing, "player B is stopped after the deadline")
	# Stopping must not prevent a subsequent request for the same track.
	audio.play_music("regression_a", 0.0)
	await host.get_tree().create_timer(0.05).timeout
	t.ok(audio._music_active.playing, "music can restart after stop")
	t.equal(audio.current_track(), "regression_a", "restart restores track identity")
	audio.shutdown()
	audio.queue_free()
	await host.get_tree().process_frame


func _loop() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	stream.data = PackedByteArray([0, 1, 0, 255])
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 4
	return stream
