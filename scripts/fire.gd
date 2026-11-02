class_name Fire
extends Node3D
## Костёр, сложенный игроком. Хост считает топливо; все видят пламя по синхронизации.
## Разжечь — спичками (удержание E), подкинуть дров — с поленом в руках.

const MAX_FUEL := 600.0

var lit := false
var fuel := 180.0            # секунд горения
var world: Node
var flame: CPUParticles3D
var smoke: CPUParticles3D
var light: OmniLight3D
var snd: AudioStreamPlayer3D
var logs: Node3D


func setup(data: Dictionary) -> void:
	name = data.name
	position = data.pos
	set_meta("kind", "fire")
	_build()
	add_child(MU.make_sync(["lit", "fuel"], 0.25))


func _build() -> void:
	# камни по кругу и поленья «шалашом»
	var rng := RandomNumberGenerator.new()
	rng.seed = name.hash()
	for i in 8:
		var a := i * TAU / 8.0 + rng.randf() * 0.2
		add_child(MU.sphere(0.13 + rng.randf() * 0.05, Color(0.38, 0.36, 0.33), Vector3(cos(a) * 0.55, 0.06, sin(a) * 0.55), Vector3(1.2, 0.7, 1.0)))
	logs = Node3D.new()
	add_child(logs)
	for i in 5:
		var a := i * TAU / 5.0
		var lg := MU.cyl(0.05, 0.06, 0.75, Color(0.36, 0.24, 0.13), Vector3(cos(a) * 0.17, 0.27, sin(a) * 0.17), Vector3.ZERO, 7)
		lg.rotation = Vector3(0, -a, 0)
		lg.rotate_object_local(Vector3(0, 0, 1), 0.55)
		logs.add_child(lg)
	add_child(MU.cyl(0.32, 0.36, 0.02, Color(0.08, 0.07, 0.06), Vector3(0, 0.01, 0)))
	flame = CPUParticles3D.new()
	flame.amount = 34
	flame.lifetime = 0.7
	flame.position.y = 0.2
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.2
	flame.gravity = Vector3(0, 2.8, 0)
	flame.initial_velocity_min = 0.2
	flame.initial_velocity_max = 0.6
	flame.scale_amount_min = 0.6
	flame.scale_amount_max = 1.5
	var fm := SphereMesh.new()
	fm.radius = 0.11
	fm.height = 0.22
	fm.radial_segments = 6
	fm.rings = 3
	fm.material = MU.mat(Color(1.0, 0.5, 0.1), 1.0, 4.0)
	flame.mesh = fm
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.85, 0.35, 1))
	grad.set_color(1, Color(0.8, 0.15, 0.0, 0))
	flame.color_ramp = grad
	flame.emitting = false
	add_child(flame)
	smoke = CPUParticles3D.new()
	smoke.amount = 14
	smoke.lifetime = 3.0
	smoke.position.y = 0.6
	smoke.gravity = Vector3(0.3, 1.2, 0)
	smoke.initial_velocity_min = 0.1
	smoke.initial_velocity_max = 0.3
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 3.0
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = MU.mat(Color(0.55, 0.55, 0.55, 0.25), 1.0)
	smoke.mesh = sm
	smoke.emitting = false
	add_child(smoke)
	light = OmniLight3D.new()
	light.name = "Light"
	light.position.y = 0.8
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 11.0
	light.light_energy = 0.0
	light.shadow_enabled = true
	add_child(light)
	var a2 := MU.area_box(Vector3(1.4, 0.9, 1.4), Vector3(0, 0.45, 0), "fire", "Station")
	add_child(a2)
	snd = AudioStreamPlayer3D.new()
	snd.stream = Sfx.get_stream("fire")
	snd.unit_size = 3.0
	snd.max_distance = 25.0
	snd.volume_db = -6.0
	snd.bus = "SFX"
	add_child(snd)


func _ready() -> void:
	world = get_tree().current_scene


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and lit:
		# дождь гасит быстрее
		fuel -= delta * (2.5 if world.raining else 1.0)
		if fuel <= 0.0:
			fuel = 0.0
			lit = false
	var f := clampf(fuel / 120.0, 0.25, 1.0)
	flame.emitting = lit
	smoke.emitting = lit
	flame.scale = Vector3.ONE * (0.6 + 0.6 * f)
	var t := Time.get_ticks_msec() * 0.001
	light.light_energy = (2.2 + sin(t * 11.0) * 0.25 + sin(t * 7.3) * 0.2) * f if lit else 0.0
	logs.visible = fuel > 0.0
	if lit and not snd.playing and snd.stream:
		snd.play()
	elif not lit and snd.playing:
		snd.stop()


## Насколько греет (для world.heat_at).
func is_hot() -> bool:
	return lit


func add_wood() -> void:
	fuel = minf(fuel + 240.0, MAX_FUEL)
