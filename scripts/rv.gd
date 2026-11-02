class_name RV
extends VehicleBody3D
## Дом на колёсах. Физика — у хоста; водитель шлёт ввод хосту.
## Вперёд — ось +Z.

const SEATS := [
	Vector3(0.55, 1.15, 2.2),    # 0 водитель
	Vector3(-0.55, 1.15, 2.2),   # 1 пассажир
	Vector3(0.6, 3.05, -0.8),    # 2 шезлонг на крыше
	Vector3(-0.6, 3.05, -0.8),   # 3 шезлонг на крыше
]
const EXITS := [Vector3(2.3, 0.2, 2.2), Vector3(-2.3, 0.2, 2.2), Vector3(2.3, 0.2, -0.8), Vector3(-2.3, 0.2, -0.8)]
const BASE_FORCE := 3300.0
const ENGINE_MULT := [1.0, 1.35, 1.75]
const TANK := [70.0, 110.0, 160.0]
const ARMOR_MULT := [1.0, 0.6, 0.35]
# Механическая КПП: индекс 0 — R, 1 — N, 2..6 — передачи 1..5
const GEARS := [-3.4, 0.0, 3.5, 2.2, 1.5, 1.1, 0.85]
const GEAR_NAMES := ["R", "N", "1", "2", "3", "4", "5"]
const FINAL_DRIVE := 8.0
const WHEEL_R := 0.5
const IDLE_RPM := 850.0
const MAX_RPM := 4600.0
const WINCH_RANGE := 28.0
const WINCH_FORCE := 26000.0
const HOOKS := [Vector3(0, 0.9, 3.45), Vector3(0, 0.9, -4.3)]

var sync_xform := Transform3D()
var sync_vel := Vector3.ZERO
var fuel := 55.0
var max_fuel := 70.0
var hp := 100.0
var up_engine := 0
var up_tank := 0
var up_armor := 0
var up_heater := 0
var seats: Array = [0, 0, 0, 0]
var throttle_vis := 0.0
var gear := 2
var rpm := 850.0
var winch_on := [false, false]
var winch_anchor := [Vector3.ZERO, Vector3.ZERO]
var winch_len := [0.0, 0.0]
var cables: Array = []
var mirrors: Array = []
var wheels: Array = []

var world: Node
var in_t := 0.0
var in_s := 0.0
var in_b := 0.0
var last_in_ms := 0
var prev_vel := Vector3.ZERO
var flip_t := 0.0
var engine_snd: AudioStreamPlayer3D
var exhaust: CPUParticles3D
var smoke: CPUParticles3D
var lights: Array = []
var heat_node: Node3D
var vis_wheels: Array = []
var _wheel_rot := 0.0


func setup(data: Dictionary) -> void:
	name = "RV"
	position = data.pos
	rotation.y = float(data.get("yaw", 0.0))
	sync_xform = Transform3D(Basis(Vector3.UP, rotation.y), data.pos)
	mass = 1800.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.55, 0)
	collision_layer = MU.L_RV
	collision_mask = MU.L_WORLD | MU.L_ITEMS
	set_meta("kind", "rv_door")
	_build()
	add_child(MU.make_sync(["sync_xform", "sync_vel", "fuel", "max_fuel", "hp", "up_engine", "up_tank",
		"up_armor", "up_heater", "seats", "throttle_vis", "gear", "rpm", "winch_on", "winch_anchor"], 0.033))


func _shape(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	add_child(cs)


func _build() -> void:
	_shape(Vector3(2.4, 2.3, 6.4), Vector3(0, 1.75, -0.1))
	_shape(Vector3(1.0, 2.0, 0.9), Vector3(0, 1.6, -3.75))       # будка-туалет сзади
	var cream := Color(0.9, 0.86, 0.75)
	var brown := Color(0.45, 0.28, 0.15)
	var glass := MU.mat(Color(0.15, 0.22, 0.28, 0.85), 0.05, 0.0, 0.3)
	var v := Node3D.new()
	v.name = "Vis"
	add_child(v)
	# кузов
	v.add_child(MU.box(Vector3(2.4, 2.0, 5.0), cream, Vector3(0, 1.9, -0.8)))
	v.add_child(MU.box(Vector3(2.42, 0.25, 5.02), brown, Vector3(0, 1.55, -0.8)))
	v.add_child(MU.box(Vector3(2.42, 0.08, 5.02), Color(0.85, 0.5, 0.1), Vector3(0, 1.75, -0.8)))
	v.add_child(MU.box(Vector3(2.4, 0.6, 6.4), Color(0.3, 0.3, 0.3), Vector3(0, 0.85, -0.1)))   # рама/юбка
	# кабина
	v.add_child(MU.box(Vector3(2.35, 1.4, 1.5), cream, Vector3(0, 1.4, 2.4)))
	v.add_child(MU.box(Vector3(2.3, 0.7, 0.05), glass, Vector3(0, 2.0, 3.12), Vector3(-20, 0, 0)))
	v.add_child(MU.box(Vector3(2.36, 0.55, 1.0), glass, Vector3(0, 1.85, 2.4)))
	v.add_child(MU.box(Vector3(2.35, 0.5, 0.4), Color(0.25, 0.25, 0.25), Vector3(0, 0.9, 3.2)))  # бампер
	for e in [-1, 1]:
		var hl := MU.box(Vector3(0.35, 0.2, 0.05), MU.mat(Color(1.0, 0.95, 0.8), 0.2, 2.0), Vector3(e * 0.8, 1.15, 3.17))
		v.add_child(hl)
		var sl := SpotLight3D.new()
		sl.position = Vector3(e * 0.8, 1.15, 3.2)
		sl.rotation_degrees = Vector3(-5, 180, 0)
		sl.spot_range = 45.0
		sl.spot_angle = 35.0
		sl.light_energy = 4.0
		sl.visible = false
		add_child(sl)
		lights.append(sl)
		# окна жилого блока
		v.add_child(MU.box(Vector3(0.02, 0.6, 1.0), glass, Vector3(e * 1.215, 2.2, 0.2)))
		v.add_child(MU.box(Vector3(0.02, 0.6, 1.0), glass, Vector3(e * 1.215, 2.2, -2.0)))
	# крыша: багажник и шезлонги
	v.add_child(MU.box(Vector3(2.0, 0.06, 3.0), Color(0.2, 0.2, 0.2), Vector3(0, 2.95, -1.0)))
	for e in [-1, 1]:
		v.add_child(MU.box(Vector3(0.6, 0.06, 0.6), Color(0.2, 0.5, 0.75), Vector3(e * 0.6, 3.1, -0.8)))
		v.add_child(MU.box(Vector3(0.6, 0.7, 0.06), Color(0.2, 0.5, 0.75), Vector3(e * 0.6, 3.4, -1.15), Vector3(-15, 0, 0)))
	v.add_child(MU.cyl(0.25, 0.25, 0.25, Color(0.15, 0.15, 0.15), Vector3(0, 3.1, -2.1), Vector3(90, 0, 0)))  # запаска
	# будка-туалет (сзади)
	v.add_child(MU.box(Vector3(1.0, 2.0, 0.9), Color(0.5, 0.35, 0.2), Vector3(0, 1.6, -3.75)))
	v.add_child(MU.box(Vector3(0.12, 0.25, 0.02), Color(0.95, 0.9, 0.5), Vector3(0, 2.2, -4.21)))
	add_child(MU.area_box(Vector3(1.0, 1.8, 0.4), Vector3(0, 1.6, -4.3), "rv_toilet", "St_toilet"))
	# плита (правый бок, -X)
	v.add_child(MU.box(Vector3(0.5, 0.1, 0.8), Color(0.15, 0.15, 0.15), Vector3(-1.45, 1.25, 0.6)))
	v.add_child(MU.box(Vector3(0.45, 0.04, 0.7), MU.mat(Color(0.7, 0.7, 0.72), 0.3, 0.0, 0.9), Vector3(-1.45, 1.32, 0.6)))
	add_child(MU.area_box(Vector3(0.7, 0.8, 1.0), Vector3(-1.5, 1.3, 0.6), "rv_stove", "St_stove"))
	# разделочный стол (правый бок, сзади)
	v.add_child(MU.box(Vector3(0.7, 0.06, 1.3), Color(0.55, 0.4, 0.25), Vector3(-1.6, 1.05, -2.2)))
	add_child(MU.area_box(Vector3(0.9, 0.8, 1.4), Vector3(-1.6, 1.15, -2.2), "rv_butcher", "St_butcher"))
	# гардероб + сушилка (левый бок, +X)
	v.add_child(MU.box(Vector3(0.05, 1.4, 0.8), Color(0.4, 0.25, 0.12), Vector3(1.22, 1.8, -1.0)))
	v.add_child(MU.cyl(0.01, 0.01, 1.2, Color(0.8, 0.8, 0.8), Vector3(1.5, 2.6, -1.0), Vector3(90, 0, 0)))
	add_child(MU.area_box(Vector3(0.6, 1.4, 0.9), Vector3(1.4, 1.8, -1.0), "rv_wardrobe", "St_wardrobe"))
	# бак (левый бок, сзади)
	v.add_child(MU.cyl(0.08, 0.08, 0.05, Color(0.1, 0.1, 0.1), Vector3(1.22, 1.1, -2.8), Vector3(0, 0, 90)))
	add_child(MU.area_box(Vector3(0.5, 0.6, 0.6), Vector3(1.4, 1.1, -2.8), "rv_fuel", "St_fuel"))
	# двигатель (капот спереди)
	add_child(MU.area_box(Vector3(1.6, 0.8, 0.5), Vector3(0, 1.2, 3.4), "rv_engine", "St_engine"))
	# дверь
	v.add_child(MU.box(Vector3(0.03, 1.2, 0.8), Color(0.75, 0.7, 0.6), Vector3(1.2, 1.4, 2.3)))
	add_child(MU.area_box(Vector3(0.5, 1.6, 1.0), Vector3(1.35, 1.4, 2.3), "rv_door", "St_door"))
	# колёса
	for wp in [Vector3(1.1, 0.55, 2.2), Vector3(-1.1, 0.55, 2.2), Vector3(1.1, 0.55, -2.3), Vector3(-1.1, 0.55, -2.3)]:
		var w := VehicleWheel3D.new()
		w.position = wp
		w.wheel_radius = 0.5
		w.wheel_rest_length = 0.3
		w.suspension_travel = 0.5
		w.suspension_stiffness = 24.0
		w.suspension_max_force = 40000.0
		w.damping_compression = 0.28
		w.damping_relaxation = 0.42
		w.wheel_friction_slip = 2.4
		w.wheel_roll_influence = 0.2
		w.use_as_traction = true
		w.use_as_steering = wp.z > 0.0
		w.add_child(MU.cyl(0.5, 0.5, 0.35, Color(0.08, 0.08, 0.08), Vector3.ZERO, Vector3(0, 0, 90), 16))
		w.add_child(MU.cyl(0.28, 0.28, 0.37, MU.mat(Color(0.6, 0.6, 0.62), 0.3, 0.0, 0.8), Vector3.ZERO, Vector3(0, 0, 90), 8))
		add_child(w)
		wheels.append(w)
	# крюки лебёдок и тросы
	for i in 2:
		var hp_ := HOOKS[i] as Vector3
		get_node("Vis").add_child(MU.box(Vector3(0.5, 0.35, 0.3), Color(0.15, 0.15, 0.15), hp_ - Vector3(0, 0, 0.15 * signf(hp_.z))))
		var cable := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.02
		cm.height = 1.0
		cm.radial_segments = 6
		cable.mesh = cm
		cable.material_override = MU.mat(Color(0.25, 0.25, 0.25), 0.4, 0.0, 0.7)
		cable.top_level = true
		cable.visible = false
		add_child(cable)
		cables.append(cable)
	_build_mirrors()
	# выхлоп и дым поломки
	exhaust = _particles(Color(0.35, 0.35, 0.35, 0.4), Vector3(0.9, 0.6, -3.3), 0.08)
	smoke = _particles(Color(0.1, 0.1, 0.1, 0.6), Vector3(0, 1.6, 3.3), 0.2)
	smoke.amount = 24
	# обогреватель (источник тепла)
	heat_node = Node3D.new()
	heat_node.name = "Heat"
	heat_node.position = Vector3(0, 1.5, 0)
	add_child(heat_node)
	engine_snd = AudioStreamPlayer3D.new()
	engine_snd.stream = Sfx.get_stream("engine")
	engine_snd.unit_size = 8.0
	engine_snd.max_distance = 140.0
	engine_snd.volume_db = -6.0
	engine_snd.bus = "SFX"
	add_child(engine_snd)


## Боковые зеркала: SubViewport + камера, картинка отражается по горизонтали.
func _build_mirrors() -> void:
	for e in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(e * 1.45, 2.0, 2.9)
		add_child(arm)
		arm.add_child(MU.box(Vector3(0.35, 0.05, 0.05), Color(0.1, 0.1, 0.1), Vector3(-e * 0.15, -0.1, 0)))
		arm.add_child(MU.box(Vector3(0.24, 0.36, 0.04), Color(0.1, 0.1, 0.1), Vector3(0, 0, 0.02)))
		var vp := SubViewport.new()
		vp.size = Vector2i(192, 288)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		arm.add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 55
		cam.far = 300
		cam.cull_mask = 1
		vp.add_child(cam)
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.21, 0.32)
		quad.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = vp.get_texture()
		m.uv1_scale = Vector3(-1, 1, 1)
		m.uv1_offset = Vector3(1, 0, 0)
		quad.material_override = m
		quad.position = Vector3(0, 0, 0.045)
		quad.layers = 2   # зеркало не отражает само себя
		arm.add_child(quad)
		mirrors.append({"vp": vp, "cam": cam, "arm": arm, "side": e})


func _update_mirrors() -> void:
	var lp: Node = world.local_player if world else null
	var active: bool = Settings.mirrors and lp != null and (lp.seated >= 0 or lp.global_position.distance_to(global_position) < 15.0)
	for mr in mirrors:
		var vp: SubViewport = mr.vp
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
		if active:
			var arm: Node3D = mr.arm
			var cam: Camera3D = mr.cam
			# смотрим назад и чуть в сторону, как настоящее зеркало
			var back := -global_basis.z + global_basis.x * float(mr.side) * 0.12
			cam.global_position = arm.global_position + global_basis.z * 0.1
			cam.look_at(cam.global_position + back, global_basis.y)


func _particles(c: Color, pos: Vector3, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 12
	p.lifetime = 1.5
	p.emitting = false
	p.gravity = Vector3(0, 1.2, 0)
	p.direction = Vector3(0, 0.3, -1)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.2
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = MU.mat(c, 1.0)
	p.mesh = m
	add_child(p)
	return p


func _ready() -> void:
	world = get_tree().current_scene
	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		global_transform = sync_xform
		# у клиента колёса — только визуал (физика колёс есть лишь у хоста)
		for c in get_children():
			if c is VehicleWheel3D:
				var vw := Node3D.new()
				vw.position = c.position
				for m in c.get_children():
					m.reparent(vw, false)
				add_child(vw)
				vis_wheels.append(vw)
				c.queue_free()
	engine_snd.play()


func get_seat_xform(i: int) -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.UP, PI), SEATS[i])


func get_exit_point(i: int) -> Vector3:
	return global_transform * EXITS[clampi(i, 0, 3)]


func gear_name() -> String:
	return GEAR_NAMES[gear]


func shift(d: int) -> void:
	var ng := clampi(gear + d, 0, GEARS.size() - 1)
	if ng != gear:
		gear = ng
		world.sfx_all("click", global_position, 0.0, 0.6)


func toggle_winch(i: int) -> String:
	if winch_on[i]:
		winch_on[i] = false
		winch_on = winch_on.duplicate()
		return "winch_off"
	var hook: Vector3 = global_transform * HOOKS[i]
	var dir := global_basis.z * (1.0 if i == 0 else -1.0)
	var space := get_world_3d().direct_space_state
	# ищем, за что зацепиться: веер лучей вперёд/назад
	for ang in [0.0, 0.25, -0.25, 0.5, -0.5, 0.8, -0.8]:
		for pitch in [0.0, -0.15, 0.15]:
			var d := dir.rotated(Vector3.UP, ang).rotated(global_basis.x, pitch)
			var q := PhysicsRayQueryParameters3D.create(hook, hook + d * WINCH_RANGE, MU.L_WORLD, [get_rid()])
			var r := space.intersect_ray(q)
			if not r.is_empty() and r.position.distance_to(hook) > 2.0:
				winch_on[i] = true
				winch_on = winch_on.duplicate()
				var a: Array = winch_anchor.duplicate()
				a[i] = r.position
				winch_anchor = a
				winch_len[i] = r.position.distance_to(hook)
				world.sfx_all("reload", hook, 2.0, 0.5)
				return "winch_on"
	return "winch_none"


func is_flipped() -> bool:
	return global_basis.y.dot(Vector3.UP) < 0.4


func heat_radius() -> float:
	return 6.0 if up_heater > 0 else 0.0


func set_input(t: float, s: float, b: float) -> void:
	in_t = clampf(t, -1.0, 1.0)
	in_s = clampf(s, -1.0, 1.0)
	in_b = clampf(b, 0.0, 1.0)
	last_in_ms = Time.get_ticks_msec()


func apply_upgrade(up: String) -> bool:
	match up:
		"engine":
			if up_engine >= 2:
				return false
			up_engine += 1
		"tank":
			if up_tank >= 2:
				return false
			up_tank += 1
			max_fuel = TANK[up_tank]
		"armor":
			if up_armor >= 2:
				return false
			up_armor += 1
		"heater":
			if up_heater >= 1:
				return false
			up_heater = 1
	return true


func upgrade_level(up: String) -> int:
	return {"engine": up_engine, "tank": up_tank, "armor": up_armor, "heater": up_heater}.get(up, 0)


func flip_upright() -> void:
	var fwd := global_basis.z
	fwd.y = 0
	if fwd.length() < 0.1:
		fwd = Vector3.FORWARD
	var p := global_position
	p.y = TerrainGen.height_at(p.x, p.z) + 1.2
	global_transform = Transform3D(Basis.looking_at(-fwd.normalized(), Vector3.UP), p)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_physics(delta)
		sync_xform = global_transform
		sync_vel = linear_velocity
	else:
		global_transform = global_transform.interpolate_with(sync_xform, clampf(delta * 14.0, 0.0, 1.0))
	_effects()


func _server_physics(delta: float) -> void:
	if seats[0] == 0 or Time.get_ticks_msec() - last_in_ms > 600:
		in_t = 0.0
		in_s = 0.0
		in_b = 1.0 if seats[0] == 0 else in_b
	var speed := linear_velocity.dot(global_basis.z)
	var running: bool = seats[0] != 0 and fuel > 0.0 and hp > 0.0
	var ratio: float = GEARS[gear]
	var gas := maxf(in_t, 0.0)
	# обороты от скорости колёс; на нейтрали — от педали газа
	var wheel_rpm := absf(speed) / WHEEL_R * 60.0 / TAU
	var target_rpm := IDLE_RPM + gas * 3800.0 if ratio == 0.0 else maxf(IDLE_RPM, wheel_rpm * absf(ratio) * FINAL_DRIVE)
	if not running:
		target_rpm = 0.0
	rpm = lerpf(rpm, minf(target_rpm, MAX_RPM + 200.0), clampf(delta * 6.0, 0.0, 1.0))
	var torque_k := clampf(0.55 + 0.45 * sin(clampf(rpm / MAX_RPM, 0.0, 1.0) * PI * 0.95), 0.0, 1.0)
	if rpm > MAX_RPM:
		torque_k = 0.0   # отсечка
	var power := BASE_FORCE * float(ENGINE_MULT[up_engine]) * torque_k
	if not running:
		power = 0.0
	elif hp < 30.0:
		power *= 0.5
	engine_force = gas * power * ratio / 1.6
	# S — тормоз (задний ход — через передачу R)
	brake = maxf(in_b * 60.0, maxf(-in_t, 0.0) * 45.0)
	# грязь и вода: сцепление зависит от поверхности под колесом
	for w in wheels:
		var wp: Vector3 = (w as Node3D).global_position
		var on_road := TerrainGen.road_query(Vector2(wp.x, wp.z)).x < 4.0
		var h := TerrainGen.height_at(wp.x, wp.z)
		var slip := 3.0 if on_road else 1.9
		if h < TerrainGen.WATER + 1.5:
			slip = 1.0   # грязь у воды
		if world.raining and not on_road:
			slip *= 0.7
		(w as VehicleWheel3D).wheel_friction_slip = slip
	# лебёдки
	for i in 2:
		if winch_on[i]:
			var hook: Vector3 = global_transform * HOOKS[i]
			var anchor: Vector3 = winch_anchor[i]
			var to := anchor - hook
			var dist := to.length()
			winch_len[i] = maxf(winch_len[i] - delta * 1.6, 1.5)
			if dist > winch_len[i]:
				var f := minf((dist - winch_len[i]) * 30000.0, WINCH_FORCE)
				apply_force(to.normalized() * f, hook - global_position)
			if dist > WINCH_RANGE + 6.0 or dist < 2.0:
				winch_on[i] = false
				winch_on = winch_on.duplicate()
	var max_steer := lerpf(0.5, 0.18, clampf(absf(speed) / 25.0, 0.0, 1.0))
	steering = move_toward(steering, in_s * max_steer, delta * 1.8)
	throttle_vis = gas if power > 0.0 else 0.0
	if running:
		fuel = maxf(fuel - delta * (0.02 + gas * 0.12 * rpm / MAX_RPM), 0.0)
	# удары
	var dv := (linear_velocity - prev_vel).length()
	if dv > 5.0:
		var dmg := (dv - 5.0) * 6.0 * float(ARMOR_MULT[up_armor])
		hp = maxf(hp - dmg, 0.0)
		world.sfx_all("crash", global_position, clampf(dv * 0.8 - 6.0, -6.0, 6.0), 1.0)
		if dv > 8.0:
			_eject_roof(linear_velocity)
	prev_vel = linear_velocity
	# перевернулись — все вылетают
	if is_flipped():
		flip_t += delta
		if flip_t > 2.5:
			for i in 4:
				if seats[i] != 0:
					var p: Node = world.get_player(seats[i])
					seats[i] = 0
					if p:
						p.rpc_id(p.peer_id, "get_hit", Vector3.UP * 5.0, 5.0, 0.0)
			seats = seats.duplicate()
	else:
		flip_t = 0.0
	if global_position.y < -30.0:
		flip_upright()


func _eject_roof(vel: Vector3) -> void:
	var changed := false
	for i in [2, 3]:
		if seats[i] != 0:
			var p: Node = world.get_player(seats[i])
			seats[i] = 0
			changed = true
			if p:
				p.rpc_id(p.peer_id, "get_hit", vel * 0.9 + Vector3.UP * 7.0, 8.0, 0.1)
				world.broadcast(T.t("msg_roof_eject", [p.nick]))
	if changed:
		seats = seats.duplicate()


func _effects() -> void:
	_update_mirrors()
	for i in 2:
		var c: MeshInstance3D = cables[i]
		c.visible = winch_on[i]
		if winch_on[i]:
			var a: Vector3 = global_transform * HOOKS[i]
			var b: Vector3 = winch_anchor[i]
			var mid := (a + b) * 0.5
			var len := a.distance_to(b)
			if len > 0.1:
				c.global_transform = Transform3D(Basis.looking_at(b - a, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT) * Basis(Vector3.RIGHT, PI / 2.0), mid)
				c.scale = Vector3(1, len, 1)
	var running: bool = seats[0] != 0 and fuel > 0.0 and hp > 0.0
	exhaust.emitting = running
	smoke.emitting = hp < 30.0
	var spd := sync_vel.length()
	if not vis_wheels.is_empty():
		_wheel_rot += sync_vel.dot(global_basis.z) / 0.5 * get_physics_process_delta_time()
		for w in vis_wheels:
			(w as Node3D).rotation.x = _wheel_rot
	if running:
		engine_snd.volume_db = lerpf(engine_snd.volume_db, -4.0, 0.1)
		engine_snd.pitch_scale = lerpf(engine_snd.pitch_scale, 0.55 + rpm / MAX_RPM * 1.3 + throttle_vis * 0.1, 0.15)
	else:
		engine_snd.volume_db = lerpf(engine_snd.volume_db, -60.0, 0.05)
	var night: bool = world != null and not world.is_day()
	for l in lights:
		(l as SpotLight3D).visible = night and running
