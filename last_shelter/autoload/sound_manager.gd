extends Node
## Звуки игры (автозагрузка SoundManager). Всё синтезируется кодом при запуске — внешних файлов нет.
## Каждая кнопка сама щёлкает при нажатии; остальные звуки игра вызывает через play().
## Настройка «звук вкл/выкл» хранится в user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"
const RATE := 22050
const VOICES := 6

## Как звучит каждый звук: список нот {f — частота, t — начало, d — длительность, w — форма, v — громкость}.
## Формы: sine, square, tri, noise; slide — к какой частоте съехать к концу ноты.
const SOUNDS := {
	"click": [{"f": 900.0, "d": 0.035, "w": "square", "v": 0.18, "slide": 600.0}],
	"confirm": [{"f": 660.0, "d": 0.07, "w": "tri", "v": 0.35}, {"f": 990.0, "t": 0.07, "d": 0.11, "w": "tri", "v": 0.35}],
	"error": [{"f": 220.0, "d": 0.09, "w": "square", "v": 0.22}, {"f": 165.0, "t": 0.1, "d": 0.14, "w": "square", "v": 0.22}],
	"build": [{"f": 120.0, "d": 0.16, "w": "sine", "v": 0.6, "slide": 50.0}, {"f": 0.0, "d": 0.12, "w": "noise", "v": 0.25},
		{"f": 0.0, "t": 0.18, "d": 0.08, "w": "noise", "v": 0.18}],
	"day": [{"f": 523.0, "d": 0.18, "w": "tri", "v": 0.3}, {"f": 659.0, "t": 0.12, "d": 0.2, "w": "tri", "v": 0.28},
		{"f": 784.0, "t": 0.24, "d": 0.4, "w": "tri", "v": 0.3}],
	"event": [{"f": 740.0, "d": 0.12, "w": "square", "v": 0.2}, {"f": 554.0, "t": 0.14, "d": 0.12, "w": "square", "v": 0.2},
		{"f": 740.0, "t": 0.28, "d": 0.18, "w": "square", "v": 0.2}],
	"story": [{"f": 196.0, "d": 0.9, "w": "sine", "v": 0.35, "slide": 185.0}, {"f": 293.7, "t": 0.15, "d": 0.8, "w": "sine", "v": 0.22},
		{"f": 1174.0, "t": 0.3, "d": 0.6, "w": "sine", "v": 0.06}],
	"radio": [{"f": 0.0, "d": 0.25, "w": "noise", "v": 0.12}, {"f": 1200.0, "t": 0.1, "d": 0.06, "w": "sine", "v": 0.3},
		{"f": 1200.0, "t": 0.2, "d": 0.06, "w": "sine", "v": 0.3}, {"f": 1200.0, "t": 0.3, "d": 0.18, "w": "sine", "v": 0.3}],
	"merchant": [{"f": 1318.0, "d": 0.5, "w": "sine", "v": 0.25}, {"f": 1760.0, "t": 0.12, "d": 0.5, "w": "sine", "v": 0.18},
		{"f": 1318.0, "t": 0.3, "d": 0.6, "w": "sine", "v": 0.2}],
	"coins": [{"f": 1500.0, "d": 0.05, "w": "square", "v": 0.14}, {"f": 2000.0, "t": 0.06, "d": 0.09, "w": "square", "v": 0.14}],
	"return": [{"f": 392.0, "d": 0.12, "w": "tri", "v": 0.3}, {"f": 587.0, "t": 0.12, "d": 0.22, "w": "tri", "v": 0.3}],
	"bad": [{"f": 330.0, "d": 0.25, "w": "tri", "v": 0.3, "slide": 260.0}, {"f": 247.0, "t": 0.22, "d": 0.4, "w": "tri", "v": 0.3, "slide": 200.0}],
}

var enabled: bool = true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _ambient: AudioStreamPlayer
var _noise_seed: int = 12345


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	for id: String in SOUNDS:
		_streams[id] = _render(SOUNDS[id])
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _render_ambient()
	_ambient.volume_db = -14.0
	add_child(_ambient)
	get_tree().node_added.connect(_on_node_added)
	_update_ambient()


func has_sound(id: String) -> bool:
	return _streams.has(id)


func play(id: String, volume_db: float = 0.0) -> void:
	if not enabled or not _streams.has(id):
		return
	var p := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	p.stream = _streams[id]
	p.volume_db = volume_db
	p.play()


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		for p in _players:
			p.stop()
	_update_ambient()
	_save_settings()


func toggle() -> void:
	set_enabled(not enabled)


## Фоновый гул вентиляции — только в игре, не в меню.
func set_ambient(on: bool) -> void:
	_ambient.set_meta("wanted", on)
	_update_ambient()


func _update_ambient() -> void:
	var wanted := bool(_ambient.get_meta("wanted", false)) and enabled
	if wanted and not _ambient.playing:
		_ambient.play()
	elif not wanted and _ambient.playing:
		_ambient.stop()


func _on_node_added(node: Node) -> void:
	# Каждая кнопка щёлкает сама: никаких «немых» кнопок.
	if node is BaseButton and not node.has_meta("silent"):
		(node as BaseButton).pressed.connect(play.bind("click", -4.0))


# --- Синтез ---------------------------------------------------------------------

func _render(notes: Array) -> AudioStreamWAV:
	var length := 0.0
	for n: Dictionary in notes:
		length = maxf(length, float(n.get("t", 0.0)) + float(n["d"]))
	var count := int(length * RATE) + 64
	var buf := PackedFloat32Array()
	buf.resize(count)
	for n: Dictionary in notes:
		var start := int(float(n.get("t", 0.0)) * RATE)
		var dur := int(float(n["d"]) * RATE)
		var f0 := float(n["f"])
		var f1 := float(n.get("slide", f0))
		var wave := String(n.get("w", "sine"))
		var vol := float(n.get("v", 0.3))
		var phase := 0.0
		for i in dur:
			var k := float(i) / float(dur)
			var f := lerpf(f0, f1, k)
			phase += f / RATE
			var x := 0.0
			match wave:
				"sine": x = sin(TAU * phase)
				"square": x = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				"tri": x = 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0
				"noise": x = _noise()
			# Короткая атака и плавное затухание — без щелчков.
			var env := minf(1.0, float(i) / (RATE * 0.004)) * pow(1.0 - k, 1.6)
			if start + i < count:
				buf[start + i] += x * vol * env
	return _to_wav(buf, false)


## Мягкий низкий гул с шорохом — бесшовная петля.
func _render_ambient() -> AudioStreamWAV:
	var seconds := 4.0
	var count := int(seconds * RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var smooth := 0.0
	for i in count:
		var t := float(i) / RATE
		# Частоты кратны 1/4 Гц, чтобы петля сходилась без стыка.
		var hum := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 110.0 * t) * 0.18 + sin(TAU * 82.5 * t) * 0.12
		var wobble := 0.75 + 0.25 * sin(TAU * 0.25 * t)
		smooth += (_noise() - smooth) * 0.03
		buf[i] = (hum * wobble + smooth * 0.9) * 0.22
	return _to_wav(buf, true)


func _noise() -> float:
	_noise_seed = (_noise_seed * 1103515245 + 12345) & 0x7fffffff
	return float(_noise_seed) / float(0x3fffffff) - 1.0


func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	return wav


# --- Настройки --------------------------------------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		enabled = bool(cfg.get_value("sound", "enabled", true))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("sound", "enabled", enabled)
	cfg.save(SETTINGS_PATH)
