class_name Synth
extends RefCounted
## Runtime audio synthesis. The game ships with zero audio files.
##
## Every sound effect and every music loop is rendered into an AudioStreamWAV on
## first use from a small parameter dictionary. That keeps the repository free of
## any borrowed or licensed audio, keeps the build tiny, and means re-tuning a
## sound is editing two numbers rather than re-exporting a wav.

const RATE := 22050

enum Wave { SINE, SQUARE, SAW, TRIANGLE, NOISE }


## Render one voice. `spec` keys:
##   freq, freq_to   Hz sweep (freq_to defaults to freq)
##   dur             seconds
##   wave            Wave enum
##   attack/decay/sustain/release  ADSR in seconds / 0..1 level
##   vibrato, vibrato_hz           pitch wobble
##   drive           soft clipping amount, adds arcade grit
##   gain            0..1
static func voice(spec: Dictionary) -> PackedFloat32Array:
	var dur := float(spec.get("dur", 0.2))
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var f0 := float(spec.get("freq", 440.0))
	var f1 := float(spec.get("freq_to", f0))
	var wave := int(spec.get("wave", Wave.SINE))
	var attack := float(spec.get("attack", 0.005))
	var decay := float(spec.get("decay", 0.05))
	var sustain := float(spec.get("sustain", 0.6))
	var release := float(spec.get("release", 0.08))
	var vib := float(spec.get("vibrato", 0.0))
	var vib_hz := float(spec.get("vibrato_hz", 6.0))
	var drive := float(spec.get("drive", 0.0))
	var gain := float(spec.get("gain", 0.7))
	var curve := float(spec.get("curve", 1.0))
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 12345))
	for i in n:
		var t := float(i) / RATE
		var p := pow(clampf(t / maxf(dur, 0.0001), 0.0, 1.0), curve)
		var f: float = lerp(f0, f1, p)
		if vib > 0.0:
			f *= 1.0 + sin(TAU * vib_hz * t) * vib
		phase += TAU * f / RATE
		var s := 0.0
		match wave:
			Wave.SQUARE:
				s = 1.0 if sin(phase) >= 0.0 else -1.0
			Wave.SAW:
				s = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			Wave.TRIANGLE:
				s = asin(sin(phase)) * (2.0 / PI)
			Wave.NOISE:
				s = rng.randf_range(-1.0, 1.0)
			_:
				s = sin(phase)
		s *= _adsr(t, dur, attack, decay, sustain, release)
		if drive > 0.0:
			s = tanh(s * (1.0 + drive * 6.0)) / tanh(1.0 + drive * 6.0)
		out[i] = s * gain
	return out


static func _adsr(t: float, dur: float, a: float, d: float, s: float, r: float) -> float:
	if t < a:
		return t / maxf(a, 0.0001)
	if t < a + d:
		return lerp(1.0, s, (t - a) / maxf(d, 0.0001))
	var rel_start := maxf(a + d, dur - r)
	if t < rel_start:
		return s
	return lerp(s, 0.0, clampf((t - rel_start) / maxf(r, 0.0001), 0.0, 1.0))


static func mix(layers: Array, normalize := true) -> PackedFloat32Array:
	var length := 0
	for l in layers:
		length = maxi(length, (l as PackedFloat32Array).size())
	var out := PackedFloat32Array()
	out.resize(length)
	for l in layers:
		var buf: PackedFloat32Array = l
		for i in buf.size():
			out[i] += buf[i]
	if normalize:
		var peak := 0.0
		for v in out:
			peak = maxf(peak, absf(v))
		if peak > 0.0001:
			var k := 0.92 / peak
			for i in out.size():
				out[i] *= k
	return out


## Place `buf` into `dest` starting at `at_sec`, growing nothing (clips at end).
static func place(dest: PackedFloat32Array, buf: PackedFloat32Array, at_sec: float, gain := 1.0) -> void:
	var start := int(at_sec * RATE)
	for i in buf.size():
		var j := start + i
		if j < 0 or j >= dest.size():
			continue
		dest[j] += buf[i] * gain


static func to_stream(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var v := int(clampf(buf[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
	return s


static func silence(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


## Equal-tempered note helper. `n` is semitones from A4 (440 Hz).
static func note(n: float) -> float:
	return 440.0 * pow(2.0, n / 12.0)
