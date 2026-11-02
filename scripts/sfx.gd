extends Node
## Звуки. Все файлы — в res://sounds (сгенерированы tools/gen_sounds.py,
## можно заменить на свои с теми же именами).

const LOOPS := ["engine", "rain", "ambience", "night", "fire", "winch"]
var streams := {}


func _ready() -> void:
	var dir := DirAccess.open("res://sounds")
	var names: Array = []
	if dir:
		for f in dir.get_files():
			var fn := f.trim_suffix(".import")
			if fn.ends_with(".wav") and not fn in names:
				names.append(fn)
	for fn in names:
		var s := load("res://sounds/" + fn) as AudioStreamWAV
		if s == null:
			continue
		var key: String = fn.get_basename()
		if key in LOOPS:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate) - 1
		streams[key] = s


func get_stream(n: String) -> AudioStream:
	return streams.get(n)


func play_at(n: String, pos: Vector3, vol := 0.0, pitch := 1.0) -> void:
	var s: AudioStream = streams.get(n)
	var scene := get_tree().current_scene
	if s == null or scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.unit_size = 6.0
	p.max_distance = 250.0
	p.attenuation_filter_cutoff_hz = 6000.0
	p.bus = "SFX"
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func play_ui(n: String, vol := 0.0) -> void:
	var s: AudioStream = streams.get(n)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = vol
	p.bus = "SFX"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
