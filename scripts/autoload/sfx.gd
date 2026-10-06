extends Node
## Sound: a port of the original WebAudio synth. Each effect is rendered once to PCM from the same recipe
## (filtered noise bursts + swept oscillators with exponential envelopes) and cached as an AudioStreamWAV.
## Music: the two looping tracks extracted from the original build, crossfaded on the Music bus.

const RATE := 32000
const MUSIC := {
	"menu": preload("res://assets/audio/music_menu.mp3"),
	"game": preload("res://assets/audio/music_game.mp3"),
}
const BALLISTIC := ["pulse", "smg", "burst", "scatter"]

var _cache := {}
## Recorded / generated sounds (assets/generated/sfx/<file>_N.mp3, ElevenLabs via the atlas-assets plugin) replace the
## synthesized recipe of the same game sound; a random variation plays each time.
const FILES := {"fire_sniper": "sniper_shot", "casing": "shell_drop", "headshot": "headshot", "hit_body": "body_hit", "whiz": "whiz",
	"footstep": "step_wet", "breath_in": "breath_in", "breath_out": "breath_out", "hurt": "hurt", "death": "death",
	"coat": "coat_swish", "scope_in": "scope_in", "clip_load": "clip_load", "bolt_cycle": "bolt_cycle", "rain": "rain_roof"}
var _variants := {}
var _players: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _music: Array[AudioStreamPlayer] = []
var _music_cur := -1
var _loops := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	for i in 24:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 6.0
		p.max_distance = 90.0
		add_child(p)
		_players3d.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)


# ------------------------------------------------------------------ public API
func _resolve(sound: String) -> AudioStream:
	if FILES.has(sound):
		if not _variants.has(sound):
			var list: Array[AudioStream] = []
			var base: String = "res://assets/generated/sfx/" + FILES[sound]
			if ResourceLoader.exists(base + ".mp3"):
				list.append(load(base + ".mp3"))
			for i in range(1, 7):
				if ResourceLoader.exists("%s_%d.mp3" % [base, i]):
					list.append(load("%s_%d.mp3" % [base, i]))
			_variants[sound] = list
		var l: Array = _variants[sound]
		if not l.is_empty():
			return l[randi() % l.size()]
	return _stream(sound)


func play(sound: String, volume := 1.0, pitch := 1.0) -> void:
	var s := _resolve(sound)
	if s == null:
		return
	var p := _free_player()
	p.stream = s
	p.volume_db = linear_to_db(volume)
	p.pitch_scale = pitch
	p.play()


func play_at(sound: String, pos: Vector3, volume := 1.0, pitch := 1.0) -> void:
	var s := _resolve(sound)
	if s == null:
		return
	var p: AudioStreamPlayer3D = _players3d.pop_front()
	_players3d.append(p)
	p.stream = s
	p.global_position = pos
	p.volume_db = linear_to_db(volume)
	p.pitch_scale = pitch
	p.play()


## The original's generic blip: beep(frequency, duration, waveform, volume).
func beep(freq: float, dur: float, wave := "sine", vol := 0.1) -> void:
	var key := "beep_%d_%d_%s" % [int(freq), int(dur * 1000), wave]
	if not _cache.has(key):
		var b := _buf(dur + 0.05)
		_osc(b, 0.0, dur, wave, freq, freq, 1.0, 0.005)
		_cache[key] = _wav(b)
	play(key, vol * 2.5)


func fire(w: WeaponData) -> void:
	play("fire_" + w.id, 1.0, randf_range(0.96, 1.04))


func music(track: String) -> void:
	var stream: AudioStream = MUSIC.get(track)
	var idx := 0 if track == "menu" else 1
	if _music_cur == idx and _music[idx].playing:
		return
	_music_cur = idx
	for i in 2:
		var m := _music[i]
		var tw := create_tween()
		if i == idx:
			if m.stream != stream:
				m.stream = stream
			if stream is AudioStreamMP3:
				stream.loop = true
			if not m.playing:
				m.play()
			tw.tween_property(m, "volume_db", 0.0, 1.2)
		else:
			tw.tween_property(m, "volume_db", -80.0, 1.2)
			tw.tween_callback(m.stop)


## Looping sounds (ambience, jetpack) are started/stopped by name.
func loop(sound: String, on: bool, volume := 1.0) -> void:
	if on and not _loops.has(sound):
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		var st := _resolve(sound)
		if st is AudioStreamMP3:
			st = st.duplicate()
			st.loop = true
		p.stream = st
		p.volume_db = linear_to_db(volume)
		add_child(p)
		p.play()
		_loops[sound] = p
	elif not on and _loops.has(sound):
		var p: AudioStreamPlayer = _loops[sound]
		_loops.erase(sound)
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, 0.35)
		tw.tween_callback(p.queue_free)


func loop_pitch(sound: String, pitch: float) -> void:
	if _loops.has(sound):
		_loops[sound].pitch_scale = pitch


# ------------------------------------------------------------------ recipes
func _stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var b: PackedFloat32Array
	if sound.begins_with("fire_"):
		b = _fire(sound.substr(5))
	else:
		match sound:
			"impact":
				b = _buf(0.4)
				_noise(b, 0, .03, "bp", 3200, 2000, 3, .35, .001)
				_noise(b, 0, .06, "lp", 1500, 300, .7, .25, .002)
				for i in 3:
					_noise(b, .05 + i * .035, .02, "bp", 2500 + randf() * 2500, 1800, 4, .07, .001)
			"explosion":
				b = _buf(1.2)
				_noise(b, 0, .9, "lp", 2400, 90, .8, 1.0, .004)
				_osc(b, 0, .6, "sine", 110, 32, .9, .003)
				_osc(b, 0, .35, "sawtooth", 110, 40, .2, .002)
			"enemy_die":
				b = _buf(.3)
				_osc(b, 0, .2, "sawtooth", 90, 90, .5, .004)
				_noise(b, 0, .15, "lp", 1800, 300, .8, .3, .002)
			"slash_windup":
				b = _buf(.35)
				_osc(b, 0, .28, "sawtooth", 140, 420, .12, .08)
				_noise(b, 0, .16, "bp", 900, 4200, 1.4, .35, .002)
			"slash_hit":
				b = _buf(.35)
				_noise(b, 0, .16, "bp", 900, 4200, 1.4, .35, .002)
				_noise(b, .01, .22, "bp", 5200, 2600, 6, .22, .001)
				_noise(b, .02, .18, "bp", 3300, 1800, 9, .16, .001)
				_osc(b, 0, .18, "sine", 95, 45, .6, .002)
			"slash_miss":
				b = _buf(.25)
				_noise(b, 0, .16, "bp", 900, 4200, 1.4, .35, .002)
			"footstep":
				b = _buf(.12)
				_noise(b, 0, .06, "lp", 900, 200, .8, .35, .002)
				_noise(b, 0, .02, "bp", 2400, 1800, 2, .1, .001)
			"land":
				b = _buf(.25)
				_noise(b, 0, .15, "lp", 700, 120, .8, .6, .002)
				_osc(b, 0, .12, "sine", 80, 40, .5, .002)
			"bolt_up":
				b = _buf(.12)
				_noise(b, 0, .02, "bp", 3800, 2600, 7, .45, .0006)
				_osc(b, .004, .04, "square", 1400, 900, .04, .0008)
			"bolt_back":
				b = _buf(.2)
				_noise(b, 0, .08, "bp", 2200, 1200, 3, .4, .002)
				_noise(b, .07, .02, "bp", 4200, 3000, 9, .55, .0005)
			"bolt_fwd":
				b = _buf(.2)
				_noise(b, 0, .06, "bp", 1500, 2600, 3, .35, .002)
				_noise(b, .055, .025, "bp", 3200, 2000, 8, .7, .0005)
				_osc(b, .055, .06, "sine", 240, 120, .25, .001)
			"bolt_down":
				b = _buf(.15)
				_noise(b, 0, .018, "bp", 5200, 4000, 10, .6, .0004)
				_osc(b, 0, .05, "sine", 1900, 1700, .05, .0005)
			"clip_in":
				b = _buf(.2)
				_noise(b, 0, .03, "bp", 2800, 2200, 6, .55, .0006)
				_noise(b, .03, .05, "bp", 1600, 1000, 3, .3, .001)
			"round_in":
				b = _buf(.12)
				_noise(b, 0, .02, "bp", 3600, 2800, 8, .45, .0005)
				_osc(b, 0, .05, "sine", 2600, 2400, .04, .0005)
			"breath_in":
				b = _buf(.9)
				_noise(b, 0, .8, "bp", 900, 1400, 1.2, .12, .35)
			"breath_out":
				b = _buf(1.0)
				_noise(b, 0, .9, "bp", 1100, 600, 1.0, .14, .03)
			"heartbeat":
				b = _buf(.5)
				_osc(b, 0, .12, "sine", 62, 45, .55, .006)
				_osc(b, .18, .12, "sine", 55, 40, .4, .006)
			"hitmarker":
				b = _buf(.12)
				_noise(b, 0, .03, "bp", 3000, 2500, 5, .35, .0005)
				_osc(b, 0, .06, "square", 1800, 1600, .05, .001)
			"headshot":
				b = _buf(.6)
				_osc(b, 0, .5, "sine", 2200, 2200, .16, .001)
				_osc(b, 0, .4, "sine", 3300, 3300, .07, .001)
				_noise(b, 0, .05, "bp", 4500, 3000, 6, .35, .0005)
				_osc(b, 0, .12, "sine", 90, 50, .5, .002)
			"glass":
				b = _buf(.9)
				_noise(b, 0, .05, "hp", 5000, 5000, .7, .5, .001)
				for i in 9:
					var f := 3000.0 + randf() * 6000.0
					_osc(b, .01 + i * .06 * randf(), .25 + randf() * .4, "sine", f, f * .97, .05, .001)
				_noise(b, .02, .5, "bp", 6500, 3500, 3, .25, .002)
			"lift":
				b = _buf(.6)
				_osc(b, 0, .5, "sine", 220, 660, .12, .05)
				_noise(b, 0, .4, "bp", 1800, 3600, 2, .08, .05)
			"launch":
				b = _buf(.8)
				_osc(b, 0, .6, "sawtooth", 90, 520, .18, .01)
				_noise(b, 0, .5, "lp", 3000, 600, .8, .5, .003)
				_osc(b, 0, .25, "sine", 70, 40, .7, .002)
			"casing":
				b = _buf(.12)
				for f in [4200.0, 6100.0, 8300.0]:
					_osc(b, 0, .09, "sine", f, f, .05, .001)
			"reload_out":
				b = _buf(.15)
				_noise(b, 0, .03, "bp", 2400, 1800, 6, .4, .001)
				_noise(b, .04, .06, "bp", 1200, 700, 3, .2, .002)
			"reload_in":
				b = _buf(.15)
				_noise(b, 0, .025, "bp", 3300, 2600, 8, .5, .001)
				_osc(b, 0, .04, "square", 900, 600, .05, .001)
			"jet":
				b = _buf(1.0)
				_noise(b, 0, 1.0, "lp", 1200, 1200, .8, .6, .001, true)
				_noise(b, 0, 1.0, "bp", 380, 380, .9, .4, .001, true)
				_osc(b, 0, 1.0, "sawtooth", 174, 174, .06, .001, true)
			"ambience":
				b = _buf(4.0)
				_noise(b, 0, 4.0, "lp", 90, 90, .7, .8, .001, true)
				_noise(b, 0, 4.0, "bp", 700, 700, .6, .06, .001, true)
				_noise(b, 0, 4.0, "bp", 2200, 2200, .4, .015, .001, true)
				for fv in [[60.0, .03], [120.0, .018], [180.0, .008]]:
					_osc(b, 0, 4.0, "sine", fv[0], fv[0], fv[1], .001, true)
			_:
				push_warning("Sfx: unknown sound '%s'" % sound)
				return null
	var w := _wav(b, sound in ["jet", "ambience"])
	_cache[sound] = w
	return w


func _fire(id: String) -> PackedFloat32Array:
	var w: WeaponData = Game.weapon(id)
	var f := 500.0
	var snd := {"pulse": 520, "scatter": 180, "rail": 900, "smg": 760, "arc": 140, "ion": 300, "cryo": 1200, "void": 90, "burst": 640, "chain": 1500}
	f = snd.get(w.id, 500)
	if w.id == "sniper":
		# big-bore: a supersonic crack, a deep chest boom, a mechanical clack and a long rooftop echo tail
		var bs := _buf(2.2)
		_noise(bs, 0, .014, "hp", 5000, 5000, .7, .9, .0006)
		_noise(bs, 0, .22, "lp", 3000, 260, .8, .95, .002)
		_osc(bs, 0, .3, "sine", 75, 32, 1.0, .002)
		_osc(bs, 0, .08, "sawtooth", 160, 60, .25, .002)
		_noise(bs, .012, .03, "bp", 2600, 1900, 6, .25, .0008)
		for k in 4:
			var at := .18 + k * .21 + randf() * .05
			_noise(bs, at, .5, "lp", 1100 - k * 180, 160, .8, .32 * pow(0.62, k), .02)
		return bs
	var b := _buf(0.45)
	var v := 0.55
	if w.id in BALLISTIC:
		var pk := 1.6 if w.id == "scatter" else (0.7 if w.id == "smg" else 1.0)
		_noise(b, 0, .012, "hp", 4000, 4000, .7, .55 * v * pk, .0008)            # supersonic crack
		_noise(b, 0, .09 * pk, "lp", 2600, 380, .8, .7 * v * pk, .002)          # muzzle blast body
		_osc(b, 0, .11, "sine", 120 * pk, 42, .8 * v * pk, .002)                # chest thump
		_noise(b, .018, .03, "bp", 2400, 1800, 6, .18 * v, .001)                # bolt carrier
		_noise(b, .045, .025, "bp", 3300, 2600, 8, .12 * v, .001)
		_osc(b, 0, .07, "sawtooth", f * 2.2, f * .7, .07 * v, .002)             # coil snap
		_noise(b, .11, .07, "lp", 1200, 400, .8, .5 * v * pk * .22, .002)       # slapback
	else:
		_osc(b, 0, .06, "sine", f * .8, f * 2.6, .22 * v, .004)                 # charge chirp
		_osc(b, .03, .22, "sawtooth", f * 1.6, f * .35, .16 * v, .003)          # discharge sweep
		_noise(b, .02, .16, "bp", 5200, 900, 2.5, .5 * v, .002)                 # plasma crackle
		_osc(b, .02, .18, "sine", 90, 35, .7 * v, .003)                         # sub punch
		_osc(b, 0, .35, "sine", f * 3.1, f * 3.1, .06 * v, .01)                 # shimmer
	return b


# ------------------------------------------------------------------ synthesis primitives
func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


## Exponential attack to `peak`, then exponential decay over `dur` (WebAudio exponentialRamp style).
func _env(t: float, a: float, peak: float, dur: float, sustain := false) -> float:
	if sustain:
		return peak
	if t < a:
		return 0.0001 * pow(peak / 0.0001, t / maxf(a, 1e-5))
	var u := (t - a) / dur
	return 0.0 if u >= 1.0 else peak * pow(0.0001 / peak, u)


func _osc(b: PackedFloat32Array, t0: float, dur: float, wave: String, f0: float, f1: float, peak: float, a: float, sustain := false) -> void:
	var start := int(t0 * RATE)
	var n := mini(int((a + dur) * RATE), b.size() - start)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := f0 * pow(f1 / f0, minf(1.0, t / dur))
		ph = fmod(ph + f / RATE, 1.0)
		var s: float
		match wave:
			"square": s = 1.0 if ph < 0.5 else -1.0
			"sawtooth": s = ph * 2.0 - 1.0
			"triangle": s = 1.0 - 4.0 * absf(ph - 0.5)
			_: s = sin(ph * TAU)
		b[start + i] += s * _env(t, a, peak, dur, sustain)


## Noise through a state-variable filter whose cutoff sweeps exponentially from f0 to f1.
func _noise(b: PackedFloat32Array, t0: float, dur: float, kind: String, f0: float, f1: float, q: float, peak: float, a: float, sustain := false) -> void:
	var start := int(t0 * RATE)
	var n := mini(int((a + dur) * RATE), b.size() - start)
	var low := 0.0
	var band := 0.0
	var damp := 1.0 / maxf(q, 0.3)
	for i in n:
		var t := float(i) / RATE
		var fc := minf(f0 * pow(f1 / f0, minf(1.0, t / dur)), RATE / 6.5)
		var fk := 2.0 * sin(PI * fc / RATE)
		var x := randf() * 2.0 - 1.0
		low += fk * band
		var high := x - low - damp * band
		band += fk * high
		var s: float = low if kind == "lp" else (high if kind == "hp" else band)
		b[start + i] += s * _env(t, a, peak, dur, sustain)


func _wav(b: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = b.size()
	return w


func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var p: AudioStreamPlayer = _players.pop_front()
	_players.append(p)
	return p
