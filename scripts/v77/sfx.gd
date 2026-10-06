class_name V77Sfx
extends Node
## Sound for Neon Core: v77's two music tracks (menu theme, combat theme, crossfaded) and its synthesized effects,
## rendered once to PCM from recipes built on the same primitives as v77's WebAudio graphs (filtered noise bursts
## and swept oscillators with exponential envelopes).

const RATE := 22050
var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _loops := {}
var _music: Array[AudioStreamPlayer] = []
var _music_cur := ""
var master := 1.0
var music_vol := .55


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in 16:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 8.0
		p3.max_distance = 90.0
		add_child(p3)
		_players3d.append(p3)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)


func music(track: String) -> void:
	if track == _music_cur:
		return
	_music_cur = track
	var path: String = {"menu": "res://assets/v77/file_26.mp3", "game": "res://assets/v77/file_27.mp3"}.get(track, "")
	var nxt: AudioStreamPlayer = _music[1] if _music[0].playing and _music[0].volume_db > -40 else _music[0]
	var old: AudioStreamPlayer = _music[0] if nxt == _music[1] else _music[1]
	if path != "":
		var s: AudioStreamMP3 = load(path)
		s.loop = true
		nxt.stream = s
		nxt.volume_db = -60
		nxt.play()
		create_tween().tween_property(nxt, "volume_db", linear_to_db(music_vol), 1.2)
	create_tween().tween_property(old, "volume_db", -80.0, 1.2)


func play(sound: String, vol := 1.0, pitch := 1.0) -> void:
	var s := _stream(sound)
	if s == null:
		return
	var p: AudioStreamPlayer = _free(_players)
	p.stream = s
	p.volume_db = linear_to_db(maxf(.0001, vol * master))
	p.pitch_scale = pitch * randf_range(.97, 1.03)
	p.play()


func play_at(sound: String, pos: Vector3, vol := 1.0) -> void:
	var s := _stream(sound)
	if s == null:
		return
	var p: AudioStreamPlayer3D = _free(_players3d)
	p.stream = s
	p.global_position = pos
	p.volume_db = linear_to_db(maxf(.0001, vol * master)) + 4.0
	p.play()


func fire(w: Dictionary) -> void:
	play("fire_" + str(w.id), .8)


func beep(freq: float, dur: float, wave := "sine", vol := .1) -> void:
	var key := "beep_%d_%d_%s" % [int(freq), int(dur * 1000), wave]
	if not _cache.has(key):
		var b := _buf(dur + .05)
		_osc(b, 0, dur, wave, freq, freq, vol * 3, .005)
		_cache[key] = _wav(b)
	var p: AudioStreamPlayer = _free(_players)
	p.stream = _cache[key]
	p.volume_db = linear_to_db(master)
	p.pitch_scale = 1.0
	p.play()


func loop(sound: String, on: bool) -> void:
	if on:
		if _loops.has(sound):
			return
		var p := AudioStreamPlayer.new()
		p.stream = _stream(sound, true)
		p.volume_db = linear_to_db(.6 * master)
		add_child(p)
		p.play()
		_loops[sound] = p
	elif _loops.has(sound):
		_loops[sound].queue_free()
		_loops.erase(sound)


func _free(list: Array):
	for p in list:
		if not p.playing:
			return p
	return list[0]


# ---------------------------------------------------------------- recipes
func _stream(sound: String, looped := false) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var b: PackedFloat32Array
	if sound.begins_with("fire_"):
		b = _fire(sound.substr(5))
	else:
		match sound:
			"step":
				b = _buf(.14)
				_noise(b, 0, .06, "lp", 900, 200, .8, .35, .002)
				_noise(b, 0, .02, "bp", 2400, 1800, 2, .1, .001)
			"land":
				b = _buf(.3)
				_noise(b, 0, .15, "lp", 700, 120, .8, .6, .002)
				_osc(b, 0, .12, "sine", 80, 40, .5, .002)
			"jump":
				b = _buf(.2)
				_noise(b, 0, .1, "bp", 1200, 500, 1.2, .2, .003)
			"slide":
				b = _buf(.9)
				_noise(b, 0, .6, "bp", 2600, 650, 1.1, .38, .02)
				_noise(b, 0, .75, "lp", 520, 140, .7, .32, .03)
				_osc(b, 0, .65, "sawtooth", 150, 82, .03, .05)
			"slide_burst":
				b = _buf(1.3)
				_noise(b, 0, .012, "hp", 4500, 4500, .7, .55, .0006)
				_noise(b, .005, .35, "lp", 260, 2600, .8, .6, .012)
				_noise(b, .03, 1.1, "bp", 420, 1500, .7, .5, .05)
				_osc(b, .02, .9, "sawtooth", 180, 760, .04, .06)
			"jet":
				b = _buf(1.0)
				_noise(b, 0, 1.0, "lp", 1200, 1200, .8, .5, .001, true)
				_noise(b, 0, 1.0, "bp", 380, 380, .9, .35, .001, true)
				_osc(b, 0, 1.0, "sawtooth", 174, 174, .05, .001, true)
				looped = true
			"pad":
				b = _buf(.8)
				_osc(b, 0, .6, "sawtooth", 90, 520, .18, .01)
				_noise(b, 0, .5, "lp", 3000, 600, .8, .5, .003)
				_osc(b, 0, .25, "sine", 70, 40, .7, .002)
			"turn":
				b = _buf(.4)
				_noise(b, 0, .36, "bp", 500, 2200, 1.1, .16, .12)
			"reload":
				b = _buf(.5)
				_noise(b, 0, .03, "bp", 2400, 1800, 6, .4, .001)
				_noise(b, .25, .025, "bp", 3300, 2600, 8, .5, .001)
				_osc(b, .25, .04, "square", 900, 600, .05, .001)
			"ready":
				b = _buf(.3)
				_osc(b, 0, .12, "sine", 880, 880, .12, .005)
				_osc(b, .1, .15, "sine", 1320, 1320, .12, .005)
			"skill":
				b = _buf(.6)
				_osc(b, 0, .4, "sine", 300, 1200, .2, .02)
				_noise(b, 0, .3, "bp", 2000, 5000, 1.5, .12, .01)
			"shield_hit":
				b = _buf(.4)
				_osc(b, 0, .3, "sine", 1600, 900, .2, .002)
			"hurt":
				b = _buf(.3)
				_noise(b, 0, .2, "lp", 1200, 200, .8, .5, .002)
				_osc(b, 0, .2, "sine", 120, 60, .5, .002)
			"boom":
				b = _buf(1.2)
				_noise(b, 0, .9, "lp", 2400, 90, .8, 1.0, .004)
				_osc(b, 0, .6, "sine", 110, 32, .9, .003)
				_osc(b, 0, .35, "sawtooth", 110, 40, .2, .002)
			"glass":
				b = _buf(.9)
				_noise(b, 0, .05, "hp", 5000, 5000, .7, .5, .001)
				for i in 9:
					var fq := 3000.0 + randf() * 6000.0
					_osc(b, .01 + i * .06 * randf(), .25 + randf() * .4, "sine", fq, fq * .97, .05, .001)
				_noise(b, .02, .5, "bp", 6500, 3500, 3, .25, .002)
			"sp_hit":
				b = _buf(.2)
				_noise(b, 0, .05, "bp", 3200, 2000, 3, .35, .001)
				_osc(b, 0, .08, "square", 300, 180, .08, .001)
			"sp_die":
				b = _buf(.4)
				_osc(b, 0, .2, "sawtooth", 90, 90, .5, .004)
				_noise(b, 0, .3, "lp", 1800, 300, .8, .3, .002)
			"slash_windup":
				b = _buf(.35)
				_osc(b, 0, .28, "sawtooth", 140, 420, .12, .08)
			"slash_hit":
				b = _buf(.35)
				_noise(b, 0, .16, "bp", 900, 4200, 1.4, .35, .002)
				_noise(b, .01, .22, "bp", 5200, 2600, 6, .22, .001)
				_osc(b, 0, .18, "sine", 95, 45, .6, .002)
			"slash_miss":
				b = _buf(.25)
				_noise(b, 0, .16, "bp", 900, 4200, 1.4, .35, .002)
			"grapple":
				b = _buf(.4)
				_noise(b, 0, .05, "hp", 3000, 3000, .7, .4, .001)
				_osc(b, 0, .3, "sawtooth", 600, 200, .08, .002)
			"grapple_hit":
				b = _buf(.3)
				_noise(b, 0, .03, "bp", 4000, 3000, 6, .6, .0005)
				_osc(b, 0, .15, "sine", 1800, 1600, .08, .001)
			"drone":
				b = _buf(.2)
				_osc(b, 0, .12, "sawtooth", 1900, 240, .09, .004)
				_osc(b, 0, .1, "sine", 140, 50, .18, .002)
			"door_open":
				b = _buf(.75)
				_noise(b, 0, .18, "bp", 3200, 1400, 1.6, .2, .004)
				_noise(b, .02, .42, "bp", 900, 1900, 1.2, .14, .03)
				_osc(b, .43, .12, "sine", 740, 730, .04, .001)
			"door_close":
				b = _buf(.95)
				_noise(b, 0, .5, "bp", 1700, 800, 1.2, .12, .04)
				_noise(b, .56, .07, "lp", 420, 130, .8, .32, .002)
				_osc(b, .57, .16, "sine", 520, 510, .05, .001)
			_:
				return null
	var w := _wav(b, looped)
	_cache[sound] = w
	return w


## Weapon shots, voiced by each gun's v77 'snd' pitch and class.
func _fire(id: String) -> PackedFloat32Array:
	var w := V77Data.pick(V77Data.WEAPONS, id)
	var f: float = w.snd
	var b := _buf(.6)
	match id:
		"scatter":
			_noise(b, 0, .35, "lp", 3000, 200, .8, .9, .002)
			_osc(b, 0, .2, "sine", 120, 45, .7, .002)
		"arc", "void":
			_osc(b, 0, .4, "sine", f * 2, f * .5, .5, .003)
			_noise(b, 0, .3, "lp", 1500, 200, .8, .5, .003)
		"rail":
			_osc(b, 0, .45, "sawtooth", f * 2, f * .4, .25, .002)
			_noise(b, 0, .3, "hp", 6000, 2000, .7, .3, .001)
			_osc(b, 0, .2, "sine", 90, 40, .5, .002)
		"cryo":
			_noise(b, 0, .12, "bp", 5000, 3000, 2, .25, .002)
		"chain":
			_noise(b, 0, .2, "hp", 4000, 8000, .8, .35, .001)
			_osc(b, 0, .2, "square", f, f * .3, .08, .001)
		_:
			_noise(b, 0, .1, "bp", f * 4, f * 1.5, 1.5, .5, .001)
			_osc(b, 0, .12, "square", f, f * .45, .12, .001)
			_osc(b, 0, .1, "sine", 110, 50, .45, .001)
	return b


# ---------------------------------------------------------------- synthesis primitives
func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


func _env(t: float, a: float, peak: float, dur: float, sustain: bool) -> float:
	if sustain:
		return peak
	if t < a:
		return .0001 * pow(peak / .0001, t / maxf(a, 1e-5))
	var u := (t - a) / dur
	return 0.0 if u >= 1.0 else peak * pow(.0001 / peak, u)


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
			"square": s = 1.0 if ph < .5 else -1.0
			"sawtooth": s = ph * 2.0 - 1.0
			"triangle": s = 1.0 - 4.0 * absf(ph - .5)
			_: s = sin(ph * TAU)
		b[start + i] += s * _env(t, a, peak, dur, sustain)


func _noise(b: PackedFloat32Array, t0: float, dur: float, kind: String, f0: float, f1: float, q: float, peak: float, a: float, sustain := false) -> void:
	var start := int(t0 * RATE)
	var n := mini(int((a + dur) * RATE), b.size() - start)
	var low := 0.0
	var band := 0.0
	var damp := 1.0 / maxf(q, .3)
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
	w.data = data
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = b.size()
	return w
