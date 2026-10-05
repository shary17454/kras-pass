extends RefCounted

func run(t: TestHarness) -> void:
	t.suite("colossus network input simulation clock")
	var driver: Script = load("res://tests/network_peer.gd")
	var clock := 0.0
	var attacks := 0
	var releases := 0
	for tick in 144:
		clock = driver.next_colossus_attack_clock(clock, 1.0 / 60.0, MatchPhase.P.PLAYING)
		var bits: int = driver.colossus_attack_buttons({"attack": true}, clock)
		if bits == InputFrame.Btn.ATTACK:
			attacks += 1
		else:
			releases += 1
	t.ok(attacks >= 30 and attacks <= 42, "authored exposure has repeated attack pulses in simulation time")
	t.ok(releases > attacks, "pulse releases permit subsequent attack edges")
	t.equal(driver.colossus_attack_buttons({}, 0.05), 0, "no attack without exposed-fist plan")
	t.equal(driver.colossus_attack_buttons({"attack": false}, 0.05), 0, "unsafe approach cannot authorize attack")
	t.equal(driver.colossus_attack_buttons({"attack": true}, 0.2), 0, "attack pulse ends after one tenth second")
	t.equal(driver.next_colossus_attack_clock(0.3, 0.1, MatchPhase.P.COUNTDOWN), 0.0, "non-playing phase resets clock")
	t.equal(driver.next_colossus_attack_clock(0.2, 0.0, MatchPhase.P.PLAYING), 0.2, "wall-time passage cannot advance stationary simulation")
	t.near(driver.next_colossus_attack_clock(0.35, 0.1, MatchPhase.P.SUDDEN_DEATH), 0.05, 0.00001, "sudden death retains pulse period")
	var opening: float = driver.colossus_opening_clock(0.3, false, true)
	t.equal(opening, 0.0, "entering safe reach starts an immediate pulse")
	t.equal(driver.colossus_attack_buttons({"attack": true}, opening), InputFrame.Btn.ATTACK, "late arrival does not wait for global pulse")
	t.equal(driver.colossus_opening_clock(0.3, true, true), 0.3, "remaining in reach preserves release interval")
	t.equal(driver.colossus_opening_clock(0.3, true, false), 0.3, "leaving safe reach does not authorize a pulse")
	t.equal(driver.colossus_attack_buttons({"attack": false}, opening), 0, "opening clock cannot bypass safe-plan authorization")
