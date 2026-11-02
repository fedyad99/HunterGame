class_name RV
extends VehicleBody3D
## Дом на колёсах. Физика — у хоста; водитель шлёт ввод хосту.
## Внутрь можно зайти по ступенькам (правая дверь), сесть в кресла,
## управлять с приборной панели. Вперёд — ось +Z, пол салона на y = 1.05.

const FLOOR_Y := 1.05
# место: позиция (ноги персонажа), разворот (рад) — модель смотрит в -Z
const SEATS := [
	[Vector3(0.55, 1.12, 2.25), PI],          # 0 водитель
	[Vector3(-0.55, 1.12, 2.25), PI],         # 1 пассажир
	[Vector3(0.66, 1.12, -2.75), PI / 2.0],   # 2 диван
	[Vector3(0.66, 1.12, -3.65), PI / 2.0],   # 3 диван
]
const STAND := [Vector3(0.1, 1.1, 1.6), Vector3(-0.2, 1.1, 1.6), Vector3(-0.1, 1.1, -2.75), Vector3(-0.1, 1.1, -3.65)]
const WHEEL_POS := [Vector3(1.1, 0.55, 2.6), Vector3(-1.1, 0.55, 2.6), Vector3(1.1, 0.55, -4.95), Vector3(-1.1, 0.55, -4.95)]
const BASE_MASS := 3200.0
const BASE_COM := Vector3(0, 0.35, -1.2)
const STORE_CAP := {"fridge": 10, "shelf": 14, "locker": 10}
const FRIDGE_COLD := 0.12          # во сколько раз медленнее портится еда в холодильнике
const PUNCTURE_RATE := 1.1e-5      # шанс прокола на тик на (м/с) вне дороги
const CAN_LITERS := 40.0
const BASE_FORCE := 5200.0
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
const CABLE_LEN := 50.0
const WINCH_FORCE := 28000.0
const EXT := 3.4                 # на сколько метров салон длиннее прежнего
const H_UP := 0.4                # и выше
const ROOF_Y := 3.2 + H_UP
const REAR_Z := -3.45 - EXT
const HOOKS := [Vector3(0, 0.75, 4.35), Vector3(0.45, 0.75, REAR_Z - 0.15)]
# габарит салона для «езды внутри» (локальные координаты)
const RIDE_MIN := Vector3(-1.35, 0.6, REAR_Z - 0.25)
const RIDE_MAX := Vector3(1.35, 5.0, 3.5)

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
var steer_vis := 0.0
var gear := 2
var rpm := 0.0
var lights_on := false
# лебёдки: 0 — на крюке, 1 — трос в руках игрока, 2 — зацеплен
var winch_state: Array = [0, 0]
var winch_holder: Array = [0, 0]
var winch_anchor: Array = [Vector3.ZERO, Vector3.ZERO]
var winch_on: Array = [false, false]

var world: Node
var in_t := 0.0
var in_s := 0.0
var in_b := 0.0
var last_in_ms := 0
var prev_vel := Vector3.ZERO
var flip_t := 0.0
var winch_len := [0.0, 0.0]
var engine_snd: AudioStreamPlayer3D
var winch_snd: AudioStreamPlayer3D
var exhaust: CPUParticles3D
var smoke: CPUParticles3D
var lights: Array = []
var cabin_light: OmniLight3D
var cables: Array = []
var mirrors: Array = []
var wheels: Array = []
var vis_wheels: Array = []
var _wheel_rot := 0.0
var steering_wheel: Node3D
var needles := {}          # speed / rpm / fuel / engine -> Node3D
var lamps := {}            # имя -> MeshInstance3D (лампочки на панели)
var btn_vis := {}          # кнопки на панели
var lever: Node3D          # рычаг КПП
var lever_pos := Vector2.ZERO   # текущее положение рычага (-1..1)
var lever_hold := false         # игрок держит рычаг мышью (положение задаёт он)
var thermo: Thermometer
# --- повреждения: двигатель — hp (прибор), кузов, бак, колёса
var hp_body := 100.0
var hp_tank := 100.0
var wheel_hp: Array = [100.0, 100.0, 100.0, 100.0]
var wheel_state: Array = [0, 0, 0, 0]      # 0 исправно, 1 спущено, 2 снято
var jack_i := -1                           # какой угол поднят домкратом
var jack_t := 0.0                          # 0..1 высота подъёма
var stove_t := 0.0                         # сколько ещё секунд горит печь
var store := {"fridge": [], "shelf": [], "locker": []}
var winch_item: Array = ["", ""]           # имя предмета на конце троса (туша), "" — трос на земле/дереве
var cargo_mass := 0.0
var shelf_pos := Vector3.ZERO
var fridge_pos := Vector3.ZERO
var locker_pos := Vector3.ZERO
var stove_light: OmniLight3D
var stove_fx: CPUParticles3D
var leak: CPUParticles3D
var jack_node: Node3D
var wheel_parts: Array = []
var job := {}                              # текущая «работа» (удерживаемое E): только хост
var _cargo_t := 0.0
var _dent_nodes: Array = []


func setup(data: Dictionary) -> void:
	name = "RV"
	position = data.pos
	rotation.y = float(data.get("yaw", 0.0))
	sync_xform = Transform3D(Basis(Vector3.UP, rotation.y), data.pos)
	mass = BASE_MASS
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = BASE_COM
	angular_damp = 0.6
	collision_layer = MU.L_RV
	collision_mask = MU.L_WORLD | MU.L_ITEMS
	_build()
	add_child(MU.make_sync(["sync_xform", "sync_vel", "fuel", "max_fuel", "hp", "up_engine", "up_tank",
		"up_armor", "up_heater", "seats", "throttle_vis", "steer_vis", "gear", "rpm", "lights_on",
		"winch_state", "winch_holder", "winch_anchor", "winch_on", "hp_body", "hp_tank", "jack_i", "jack_t", "stove_t",
		"cargo_mass"], 0.033))
	add_child(MU.make_sync(["wheel_hp", "wheel_state", "store", "winch_item"], 0.1, true, "Sync2"))


# ======================================================================= ПОСТРОЕНИЕ
func _shape(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	cs.rotation_degrees = rot
	add_child(cs)


## Твёрдая деталь: коллизия + визуал одного размера.
func _part(v: Node3D, size: Vector3, pos: Vector3, c: Variant, rot := Vector3.ZERO) -> void:
	_shape(size, pos, rot)
	v.add_child(MU.box(size, c, pos, rot))


## Стена с окном: низ и верх сплошные, посередине стекло.
func _wall(v: Node3D, size: Vector3, pos: Vector3, c: Variant, glass: Material) -> void:
	_shape(size, pos)
	var y0 := pos.y - size.y * 0.5
	var bottom := 0.95
	var win := 0.65
	var top := size.y - bottom - win
	v.add_child(MU.box(Vector3(size.x, bottom, size.z), c, Vector3(pos.x, y0 + bottom * 0.5, pos.z)))
	v.add_child(MU.box(Vector3(size.x * 0.6, win, size.z), glass, Vector3(pos.x, y0 + bottom + win * 0.5, pos.z)))
	v.add_child(MU.box(Vector3(size.x, top, size.z), c, Vector3(pos.x, y0 + bottom + win + top * 0.5, pos.z)))


func _build() -> void:
	var v := Node3D.new()
	v.name = "Vis"
	add_child(v)
	RVBuild.body(self, v)
	RVBuild.interior(self, v)
	RVBuild.rack(self, v)
	_build_dashboard(v)
	# уличный термометр рядом с дверью
	thermo = Thermometer.new()
	thermo.position = Vector3(-1.23, 2.1, 1.95)
	thermo.rotation.y = -PI * 0.5
	v.add_child(thermo)
	for i in 2:
		var hp_: Vector3 = HOOKS[i]
		var ha := MU.area_box(Vector3(0.8, 0.8, 0.8), hp_, "rv_hook", "St_hook%d" % i)
		ha.set_meta("hook", i)
		add_child(ha)
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
	# колёса: передняя ось и задняя (длинная колёсная база)
	for wi in 4:
		var wp: Vector3 = WHEEL_POS[wi]
		var w := VehicleWheel3D.new()
		w.position = wp
		w.wheel_radius = 0.5
		w.wheel_rest_length = 0.3
		w.suspension_travel = 0.45
		w.suspension_stiffness = 26.0
		w.suspension_max_force = 60000.0
		w.damping_compression = 0.35
		w.damping_relaxation = 0.5
		w.wheel_friction_slip = 2.4
		w.wheel_roll_influence = 0.12
		w.use_as_traction = true
		w.use_as_steering = wp.z > 0.0
		wheel_parts.append(RVBuild.wheel_visual(w))
		add_child(w)
		wheels.append(w)
		var wa := MU.area_box(Vector3(0.9, 1.1, 1.1), Vector3(wp.x * 1.28, wp.y, wp.z), "rv_wheel", "St_wheel%d" % wi)
		wa.set_meta("wheel", wi)
		add_child(wa)
	_build_mirrors()
	exhaust = _particles(Color(0.35, 0.35, 0.35, 0.4), Vector3(0.9, 0.5, REAR_Z - 0.05), 0.08)
	smoke = _particles(Color(0.1, 0.1, 0.1, 0.6), Vector3(0, 1.6, 4.2), 0.2)
	smoke.amount = 24
	leak = _particles(Color(0.9, 0.75, 0.2, 0.7), Vector3(1.2, 0.5, -0.6), 0.03)
	leak.gravity = Vector3(0, -6.0, 0)
	leak.direction = Vector3(1, -0.2, 0)
	leak.amount = 8
	cabin_light = OmniLight3D.new()
	cabin_light.position = Vector3(0, ROOF_Y - 0.3, -0.5 - EXT * 0.5)
	cabin_light.light_color = Color(1.0, 0.85, 0.6)
	cabin_light.omni_range = 8.0
	cabin_light.light_energy = 0.9
	add_child(cabin_light)
	engine_snd = AudioStreamPlayer3D.new()
	engine_snd.stream = Sfx.get_stream("engine")
	engine_snd.unit_size = 8.0
	engine_snd.max_distance = 140.0
	engine_snd.volume_db = -60.0
	engine_snd.bus = "SFX"
	add_child(engine_snd)
	winch_snd = AudioStreamPlayer3D.new()
	winch_snd.stream = Sfx.get_stream("engine")
	winch_snd.pitch_scale = 2.4
	winch_snd.volume_db = -60.0
	winch_snd.bus = "SFX"
	add_child(winch_snd)
	jack_node = Node3D.new()
	jack_node.visible = false
	add_child(jack_node)
	jack_node.add_child(MU.cyl(0.07, 0.09, 0.3, MU.mat(Color(0.8, 0.1, 0.05), 0.5, 0.0, 0.4), Vector3(0, 0.15, 0), Vector3.ZERO, 10))
	jack_node.add_child(MU.cyl(0.04, 0.04, 0.2, MU.mat(Color(0.7, 0.7, 0.72), 0.3, 0.0, 0.9), Vector3(0, 0.38, 0), Vector3.ZERO, 8))
	jack_node.add_child(MU.cyl(0.1, 0.1, 0.03, MU.mat(Color(0.1, 0.1, 0.1), 0.6), Vector3(0, 0.49, 0), Vector3.ZERO, 10))


# ---- приборная панель: только круглые приборы, лампочки-иконки и кнопки-иконки
const FACE := Basis(Quaternion(Vector3(0, 1, 0), PI) * Quaternion(Vector3(1, 0, 0), -0.9599310885968813))


## Приборы стоят выше обода руля (приборный козырёк), кнопки — на центральной консоли левее руля.
const PANEL_ORG := Vector3(0.55, 2.13, 3.04)
const BTN_ORG := Vector3(0.02, 1.96, 3.0)


func _panel_pos(xl: float, yl: float, lift := 0.012, org := PANEL_ORG) -> Vector3:
	return org + FACE.x * xl + FACE.y * yl + FACE.z * lift


func _quad(v: Node3D, tex: Texture2D, size: float, pos: Vector3, col: Color, emit := 0.0, transparent := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emit > 0.0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.transform = Transform3D(FACE, pos)
	v.add_child(mi)
	return mi


func _gauge(v: Node3D, key: String, xl: float, yl: float, r: float, ticks: int, long_every: int, red_from: float, icon_kind := "", icon_col := Color(0.9, 0.9, 0.8)) -> void:
	_quad(v, DashIcons.dial(ticks, long_every, red_from), r * 2.0, _panel_pos(xl, yl, 0.008), Color.WHITE, 0.0, false)
	if icon_kind != "":
		_quad(v, DashIcons.icon(icon_kind), r * 0.7, _panel_pos(xl, yl - r * 0.48, 0.011), icon_col, 1.0)
	var needle := Node3D.new()
	needle.transform = Transform3D(FACE, _panel_pos(xl, yl, 0.014))
	v.add_child(needle)
	needle.add_child(MU.box(Vector3(r * 0.07, r * 0.85, 0.004), MU.mat(Color(1, 0.3, 0.1), 0.5, 2.0), Vector3(0, r * 0.35, 0)))
	needle.add_child(MU.cyl(r * 0.12, r * 0.12, 0.008, Color(0.15, 0.15, 0.15), Vector3.ZERO, Vector3(90, 0, 0), 10))
	needles[key] = needle


func _build_dashboard(v: Node3D) -> void:
	# руль
	steering_wheel = Node3D.new()
	steering_wheel.position = Vector3(0.55, 1.9, 2.64)
	steering_wheel.rotation_degrees = Vector3(-62, 0, 0)
	v.add_child(steering_wheel)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.145
	torus.outer_radius = 0.18
	var tm := MeshInstance3D.new()
	tm.mesh = torus
	tm.material_override = A3.tmat("rubber", Color(0.45, 0.45, 0.45), 0.3, 0.7)
	steering_wheel.add_child(tm)
	steering_wheel.add_child(MU.box(Vector3(0.32, 0.03, 0.04), Color(0.1, 0.1, 0.1)))
	v.add_child(MU.cyl(0.03, 0.03, 0.35, Color(0.1, 0.1, 0.1), Vector3(0.55, 1.78, 2.76), Vector3(-62, 0, 0)))
	# козырёк приборов: тёмный короб за шкалами, ниже линии взгляда
	v.add_child(MU.box(Vector3(0.78, 0.28, 0.3), A3.tmat("rubber", Color(0.5, 0.5, 0.5), 0.4, 0.8), Vector3(0.55, 1.97, 3.2)))
	# приборы: спидометр, тахометр, топливо, состояние двигателя
	_gauge(v, "speed", 0.0, 0.0, 0.11, 24, 4, -1.0)
	_gauge(v, "rpm", -0.235, 0.0, 0.085, 10, 2, 0.8)
	_gauge(v, "fuel", 0.19, 0.085, 0.05, 4, 4, -1.0, "fuel", Color(0.9, 0.85, 0.5))
	_gauge(v, "engine", 0.19, -0.05, 0.05, 4, 4, -1.0, "engine", Color(0.9, 0.85, 0.5))
	# контрольные лампочки-иконки
	# панель кнопок (центральная консоль)
	v.add_child(MU.box(Vector3(0.5, 0.2, 0.08), A3.tmat("rubber", Color(0.45, 0.45, 0.45), 0.4, 0.8), Vector3(0.02, 1.9, 3.06), Vector3(-35, 0, 0)))
	var lamp_defs := [["fuel", "fuel", Color(1.0, 0.6, 0.1)], ["engine", "engine", Color(1.0, 0.25, 0.1)],
		["winch", "winch_front", Color(0.3, 0.9, 1.0)], ["lights", "lights", Color(0.4, 1.0, 0.4)], ["brake", "brake", Color(1.0, 0.2, 0.15)]]
	for i in lamp_defs.size():
		var d: Array = lamp_defs[i]
		var q := _quad(v, DashIcons.icon(d[1]), 0.042, _panel_pos(-0.12 + i * 0.06, 0.175), Color(0.2, 0.2, 0.2), 0.0)
		q.set_meta("on_col", d[2])
		lamps[d[0]] = q
	# кнопки-иконки: лебёдка спереди/сзади, фары, гудок
	var btns := [["winch_front", "winch_front"], ["winch_rear", "winch_rear"], ["lights", "lights"], ["horn", "horn"]]
	for i in btns.size():
		var xl := 0.15 - i * 0.1
		var yl := 0.0
		var base := MU.box(Vector3(0.085, 0.085, 0.012), MU.mat(Color(0.12, 0.12, 0.14), 0.5), Vector3.ZERO)
		base.transform = Transform3D(FACE, _panel_pos(xl, yl, 0.005, BTN_ORG))
		v.add_child(base)
		var ic := _quad(v, DashIcons.icon(btns[i][1]), 0.062, _panel_pos(xl, yl, 0.0125, BTN_ORG), Color(0.85, 0.85, 0.8), 0.0)
		btn_vis[btns[i][0]] = ic
		var pos := _panel_pos(xl, yl, 0.0, BTN_ORG)
		var a := MU.area_box(Vector3(0.13, 0.13, 0.14), pos, "rv_button", "Btn_" + btns[i][0])
		a.set_meta("action", btns[i][0])
		add_child(a)
	# рычаг КПП между креслами: пластина с Н-образной кулисой и стальной рычаг с шаром
	v.add_child(MU.box(Vector3(0.34, 0.3, 0.7), Color(0.14, 0.14, 0.15), Vector3(0.0, 1.25, 2.52)))
	var plate := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(0.26, 0.26)
	plate.mesh = pq
	var pm := StandardMaterial3D.new()
	pm.albedo_texture = DashIcons.shift_plate()
	pm.roughness = 0.6
	plate.material_override = pm
	plate.transform = Transform3D(Basis(Vector3(1, 0, 0), -PI * 0.5), Vector3(0.0, 1.402, 2.52))
	v.add_child(plate)
	lever = Node3D.new()
	lever.position = Vector3(0.0, 1.41, 2.52)
	v.add_child(lever)
	lever.add_child(MU.cyl(0.014, 0.014, 0.4, MU.mat(Color(0.7, 0.7, 0.72), 0.3, 0.0, 0.9), Vector3(0, 0.2, 0), Vector3.ZERO, 8))
	lever.add_child(MU.sphere(0.035, MU.mat(Color(0.08, 0.08, 0.08), 0.4), Vector3(0, 0.42, 0)))
	lever.add_child(MU.cyl(0.03, 0.05, 0.06, Color(0.05, 0.05, 0.05), Vector3(0, 0.03, 0), Vector3.ZERO, 8))
	var la := MU.area_box(Vector3(0.22, 0.3, 0.22), Vector3(0.0, 1.78, 2.52), "rv_lever", "St_lever")
	add_child(la)


## Положение рычага (x: -1 лево … +1 право от водителя, y: +1 вперёд, -1 назад) для передачи.
## Передачи: индексы 0=R, 1=N, 2..6 = 1..5.
static func gear_to_lever(g: int) -> Vector2:
	match g:
		0: return Vector2(1, -1)
		2: return Vector2(-1, 1)
		3: return Vector2(-1, -1)
		4: return Vector2(0, 1)
		5: return Vector2(0, -1)
		6: return Vector2(1, 1)
	return Vector2.ZERO


static func lever_to_gear(l: Vector2) -> int:
	if absf(l.y) < 0.8:
		return 1
	var col := 1 if l.x > 0.5 else (-1 if l.x < -0.5 else 0)
	if absf(l.x - float(col)) > 0.35:
		return 1
	var up := l.y > 0.0
	match col:
		-1: return 2 if up else 3
		0: return 4 if up else 5
		1: return 6 if up else 0
	return 1


## Ограничить положение рычага рисунком буквы «Н»: между рядами — только в нейтрали.
static func constrain_lever(l: Vector2) -> Vector2:
	var r := Vector2(clampf(l.x, -1.0, 1.0), clampf(l.y, -1.0, 1.0))
	if absf(r.y) > 0.22:
		var col := roundf(r.x)
		r.x = clampf(r.x, col - 0.12, col + 0.12)
	return r


## Мировая позиция шара рычага (для наведения взгляда).
func lever_world() -> Vector3:
	return global_transform * Vector3(0.0, 1.8, 2.52)


## Боковые зеркала: SubViewport + камера, картинка отражается по горизонтали.
func _build_mirrors() -> void:
	for e in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(e * 1.38, 2.35, 3.25)
		add_child(arm)
		arm.add_child(MU.box(Vector3(0.3, 0.04, 0.04), Color(0.1, 0.1, 0.1), Vector3(-e * 0.12, -0.12, 0)))
		arm.add_child(MU.box(Vector3(0.22, 0.32, 0.04), Color(0.1, 0.1, 0.1), Vector3(0, 0, -0.02)))
		var vp := SubViewport.new()
		vp.size = Vector2i(160, 240)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		arm.add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 50
		cam.far = 300
		cam.cull_mask = 1
		vp.add_child(cam)
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.19, 0.29)
		quad.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = vp.get_texture()
		m.uv1_scale = Vector3(-1, 1, 1)
		m.uv1_offset = Vector3(1, 0, 0)
		quad.material_override = m
		# зеркало смотрит назад (к водителю)
		quad.rotation_degrees = Vector3(0, 180, 0)
		quad.position = Vector3(0, 0, -0.045)
		quad.layers = 4   # не попадает в собственную камеру зеркала
		arm.add_child(quad)
		mirrors.append({"vp": vp, "cam": cam, "arm": arm, "side": e})


func _update_mirrors() -> void:
	var lp: Node = world.local_player if world else null
	var active: bool = Settings.mirrors and lp != null and lp.global_position.distance_to(global_position) < 20.0
	for mr in mirrors:
		var vp: SubViewport = mr.vp
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
		if active:
			var arm: Node3D = mr.arm
			var cam: Camera3D = mr.cam
			var back := -global_basis.z + global_basis.x * float(mr.side) * 0.12
			cam.global_position = arm.global_position + global_basis.x * float(mr.side) * 0.05
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
	winch_snd.play()


# ======================================================================= ЗАПРОСЫ
func get_seat_xform(i: int) -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.UP, SEATS[i][1]), SEATS[i][0])


func get_stand_point(i: int) -> Vector3:
	return global_transform * STAND[clampi(i, 0, 3)]


func get_exit_point(i: int) -> Vector3:
	return get_stand_point(i)


func hook_pos(i: int) -> Vector3:
	return global_transform * HOOKS[i]


## Находится ли точка (в мировых координатах) в объёме дома.
func contains(p: Vector3, xf := Transform3D()) -> bool:
	var base := xf if xf != Transform3D() else global_transform
	var l := base.affine_inverse() * p
	return l.x > RIDE_MIN.x and l.x < RIDE_MAX.x and l.y > RIDE_MIN.y and l.y < RIDE_MAX.y and l.z > RIDE_MIN.z and l.z < RIDE_MAX.z


func gear_name() -> String:
	return GEAR_NAMES[gear]


## Передачу включает водитель, двигая рычаг мышью (см. Player). Хост принимает индекс 0..6.
func set_gear(g: int) -> void:
	var ng := clampi(g, 0, GEARS.size() - 1)
	if ng != gear:
		gear = ng
		world.sfx_all("click", global_position, 0.0, 0.6)


func is_flipped() -> bool:
	return global_basis.y.dot(Vector3.UP) < 0.4


func heat_radius() -> float:
	return 6.0 if (up_heater > 0 or stove_t > 0.0) else 0.0


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


## Кнопка на приборной панели (исполняет хост).
func press_button(action: String) -> String:
	match action:
		"lights":
			lights_on = not lights_on
			world.sfx_all("click", global_position, 0.0, 1.0)
		"horn":
			world.sfx_all("horn", global_position, 4.0, 1.0)
		"winch_front", "winch_rear":
			var i := 0 if action == "winch_front" else 1
			if winch_state[i] != 2:
				return "msg_winch_not_attached"
			var on: Array = winch_on.duplicate()
			on[i] = not on[i]
			winch_on = on
			if on[i]:
				winch_len[i] = hook_pos(i).distance_to(winch_anchor[i])
			world.sfx_all("click", global_position, 0.0, 0.8)
			return "msg_winch_motor_on" if on[i] else "msg_winch_motor_off"
	return ""


## Действие с крюком лебёдки (исполняет хост).
func hook_action(i: int, pid: int) -> String:
	var st: Array = winch_state.duplicate()
	var hl: Array = winch_holder.duplicate()
	var on: Array = winch_on.duplicate()
	var res := ""
	match int(st[i]):
		0:
			st[i] = 1
			hl[i] = pid
			res = "msg_cable_taken"
		1:
			if hl[i] == pid:
				st[i] = 0
				hl[i] = 0
				res = "msg_cable_back"
		2:
			st[i] = 0
			on[i] = false
			res = "msg_cable_back"
	var wi: Array = winch_item.duplicate()
	if int(st[i]) != 2:
		wi[i] = ""
	winch_item = wi
	winch_state = st
	winch_holder = hl
	winch_on = on
	world.sfx_all("reload", hook_pos(i), 0.0, 0.6)
	return res


func attach_cable(i: int, pid: int, point: Vector3, item_name := "") -> String:
	if winch_state[i] != 1 or winch_holder[i] != pid:
		return ""
	if point.distance_to(hook_pos(i)) > CABLE_LEN:
		return "msg_cable_short"
	var wi: Array = winch_item.duplicate()
	wi[i] = ""
	if item_name != "":
		var it := world.entities.get_node_or_null(item_name) as Item
		if it == null or it.holder != 0:
			return ""
		wi[i] = item_name
	winch_item = wi
	winch_len[i] = point.distance_to(hook_pos(i))
	var st: Array = winch_state.duplicate()
	var hl: Array = winch_holder.duplicate()
	var an: Array = winch_anchor.duplicate()
	st[i] = 2
	hl[i] = 0
	an[i] = point
	winch_state = st
	winch_holder = hl
	winch_anchor = an
	world.sfx_all("reload", point, 2.0, 0.5)
	return "msg_cable_attached"


func cable_holder_of(pid: int) -> int:
	for i in 2:
		if winch_state[i] == 1 and winch_holder[i] == pid:
			return i
	return -1


# ======================================================================= ФИЗИКА
func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_physics(delta)
		sync_xform = global_transform
		sync_vel = linear_velocity
	else:
		global_transform = global_transform.interpolate_with(sync_xform, clampf(delta * 14.0, 0.0, 1.0))
	_effects(delta)


func _server_physics(delta: float) -> void:
	_tick_job(delta)
	_tick_jack(delta)
	_tick_cargo(delta)
	if stove_t > 0.0:
		stove_t = maxf(stove_t - delta, 0.0)
	_tick_store(delta)
	if seats[0] == 0 or Time.get_ticks_msec() - last_in_ms > 600:
		in_t = 0.0
		in_s = 0.0
		in_b = 1.0 if seats[0] == 0 else in_b
	var speed := linear_velocity.dot(global_basis.z)
	var running: bool = seats[0] != 0 and fuel > 0.0 and hp > 0.0 and jack_i < 0
	var ratio: float = GEARS[gear]
	var gas := maxf(in_t, 0.0)
	# обороты: от скорости кузова (не от проскальзывающих колёс), плавно
	var wheel_rpm := absf(speed) / WHEEL_R * 60.0 / TAU
	var target_rpm := IDLE_RPM + gas * 3600.0
	if ratio != 0.0:
		target_rpm = maxf(IDLE_RPM + gas * 300.0, wheel_rpm * absf(ratio) * FINAL_DRIVE)
	if not running:
		target_rpm = 0.0
	rpm = lerpf(rpm, minf(target_rpm, MAX_RPM + 150.0), clampf(delta * 3.0, 0.0, 1.0))
	# мягкая отсечка
	var torque_k := 0.6 + 0.4 * sin(clampf(rpm / MAX_RPM, 0.0, 1.0) * PI * 0.9)
	torque_k *= 1.0 - smoothstep(MAX_RPM - 400.0, MAX_RPM + 100.0, rpm)
	var power := BASE_FORCE * float(ENGINE_MULT[up_engine]) * torque_k
	if not running:
		power = 0.0
	else:
		power *= clampf(0.3 + hp / 100.0 * 0.9, 0.3, 1.0)   # побитый двигатель тянет хуже
	engine_force = gas * power * ratio / 1.6
	brake = maxf(in_b * 70.0, maxf(-in_t, 0.0) * 50.0)
	if jack_i >= 0:
		brake = 120.0
		engine_force = 0.0
	# колёса: сцепление от поверхности, спущенные и снятые, прокол вне дороги
	var flat_pull := 0.0
	var drag := 0.0
	for wi in 4:
		var w := wheels[wi] as VehicleWheel3D
		var wp: Vector3 = w.global_position
		var on_road := TerrainGen.road_query(Vector2(wp.x, wp.z)).x < 4.0
		var h := TerrainGen.height_at(wp.x, wp.z)
		var slip := 3.0 if on_road else 2.0
		if h < TerrainGen.WATER + 1.5:
			slip = 1.1   # грязь у воды
		if world.raining and not on_road:
			slip *= 0.75
		var st := int(wheel_state[wi])
		if st == 0 and absf(speed) > 3.0 and not on_road and randf() < PUNCTURE_RATE * absf(speed):
			_puncture(wi)
		if st == 1:
			slip *= 0.6
			w.wheel_radius = 0.4
			flat_pull += (1.0 if WHEEL_POS[wi].x > 0.0 else -1.0)
			drag += 1.0
		elif st == 2:
			slip *= 0.3
			w.wheel_radius = 0.2
			drag += 2.0
		else:
			w.wheel_radius = 0.5
		w.wheel_friction_slip = slip
	if flat_pull != 0.0 and jack_i < 0:
		apply_torque(Vector3.UP * flat_pull * speed * mass * 0.03)
		apply_central_force(-linear_velocity * mass * 0.05 * drag)
	# стабилизатор: возвращает кузов к вертикали; тяжёлая крыша делает его слабее
	var roof_k := clampf(_roof_mass / 700.0, 0.0, 0.55)
	var up_err := global_basis.y.cross(Vector3.UP)
	if jack_i < 0:
		apply_torque(up_err * mass * 6.0 * (1.0 - roof_k) - angular_velocity * Vector3(1, 0, 1) * mass * 0.8)
	_tick_winches(delta)
	var max_steer := lerpf(0.5, 0.16, clampf(absf(speed) / 25.0, 0.0, 1.0))
	steering = move_toward(steering, in_s * max_steer, delta * 1.6)
	steer_vis = steering
	throttle_vis = gas if power > 0.0 else 0.0
	if running:
		fuel = maxf(fuel - delta * (0.02 + gas * 0.12 * rpm / MAX_RPM), 0.0)
	# течь из бака
	if hp_tank < 45.0 and fuel > 0.0:
		fuel = maxf(fuel - delta * (1.0 - hp_tank / 45.0) * 0.15, 0.0)
	# удары: по месту удара страдают разные части
	var dvv := linear_velocity - prev_vel
	var dv := dvv.length()
	if dv > 5.0 and jack_i < 0:
		var dmg := (dv - 5.0) * 6.0 * float(ARMOR_MULT[up_armor])
		var ld := global_basis.inverse() * dvv
		hp_body = maxf(hp_body - dmg * 0.7, 0.0)
		if ld.z < -0.5 * dv:                 # лобовой удар — страдает двигатель
			hp = maxf(hp - dmg * 0.8, 0.0)
		elif ld.z > 0.5 * dv:                # удар сзади — бак
			hp_tank = maxf(hp_tank - dmg * 0.9, 0.0)
		else:                                # боковой — колесо с этой стороны
			var side := 0 if ld.x < 0.0 else 1
			var wi := side + (0 if randf() < 0.5 else 2)
			_wheel_damage(wi, dmg * 1.2)
		if randf() < 0.3:
			_wheel_damage(randi() % 4, dmg * 0.5)
		world.sfx_all("crash", global_position, clampf(dv * 0.8 - 6.0, -6.0, 6.0), 1.0)
	prev_vel = linear_velocity
	if is_flipped():
		flip_t += delta
		if flip_t > 2.5:
			for i in 4:
				if seats[i] != 0:
					var p: Node = world.get_player(seats[i])
					if p:
						p.rpc_id(p.peer_id, "get_hit", Vector3.UP * 4.0, 5.0, 0.0)
			seats = [0, 0, 0, 0]
	else:
		flip_t = 0.0
	if global_position.y < -30.0:
		flip_upright()


func _wheel_damage(wi: int, dmg: float) -> void:
	var a: Array = wheel_hp.duplicate()
	a[wi] = maxf(float(a[wi]) - dmg, 0.0)
	wheel_hp = a
	if a[wi] <= 0.0 and int(wheel_state[wi]) == 0:
		_puncture(wi)


func _puncture(wi: int) -> void:
	var a: Array = wheel_state.duplicate()
	a[wi] = 1
	wheel_state = a
	world.sfx_all("whoosh", (wheels[wi] as Node3D).global_position, 4.0, 1.0)
	world.broadcast(T.t("msg_puncture"))


var _roof_mass := 0.0


## Масса груза (внутри, на крыше, люди) меняет массу, центр тяжести и мягкость подвески.
func _tick_cargo(delta: float) -> void:
	_cargo_t -= delta
	if _cargo_t > 0.0:
		return
	_cargo_t = 0.25
	var inv := global_transform.affine_inverse()
	var total := 0.0
	var moment := Vector3.ZERO
	var roof := 0.0
	for n in get_tree().get_nodes_in_group("items"):
		var it := n as Item
		if it == null or it.holder != 0 or it.is_queued_for_deletion():
			continue
		var l: Vector3 = inv * it.global_position
		if l.x > RIDE_MIN.x and l.x < RIDE_MAX.x and l.y > RIDE_MIN.y and l.y < RIDE_MAX.y and l.z > RIDE_MIN.z and l.z < RIDE_MAX.z:
			total += it.mass
			moment += l * it.mass
			if l.y > ROOF_Y:
				roof += it.mass
	for pid in world.players:
		var pl: Node = world.players[pid]
		if pl != null and contains(pl.global_position):
			var l2: Vector3 = inv * pl.global_position
			total += 80.0
			moment += l2 * 80.0
			if l2.y > ROOF_Y:
				roof += 80.0
	var fuel_m := fuel * 0.75
	moment += Vector3(1.4, 0.8, -0.6) * fuel_m
	total += fuel_m
	cargo_mass = total
	_roof_mass = roof
	mass = BASE_MASS + total
	var com := (BASE_COM * BASE_MASS + moment) / mass
	center_of_mass = Vector3(clampf(com.x, -0.6, 0.6), clampf(com.y, 0.2, 1.6), clampf(com.z, -2.5, 0.5))
	var soft := lerpf(1.0, 0.72, clampf(total / 1500.0, 0.0, 1.0))
	for w in wheels:
		(w as VehicleWheel3D).suspension_stiffness = 26.0 * soft


func _tick_store(delta: float) -> void:
	var changed := false
	for k in ["fridge", "shelf", "locker"]:
		var arr: Array = store[k]
		var rate := FRIDGE_COLD if k == "fridge" else 1.0
		for e in arr:
			if ItemsDB.PERISHABLE.has(e.kind):
				e["age"] = float(e.get("age", 0.0)) + delta * rate
				changed = true
	if changed and Engine.get_physics_frames() % 60 == 0:
		store = store.duplicate(true)   # чтобы синхронизатор «по изменению» увидел новое


## Домкрат: у поднятого угла удлиняется подвеска (кузов приподнимается), дом стоит на месте.
func _tick_jack(delta: float) -> void:
	for wi in wheels.size():
		var w := wheels[wi] as VehicleWheel3D
		var lift := 0.35 * jack_t if wi == jack_i else 0.0
		w.wheel_rest_length = 0.3 + lift
		w.suspension_travel = 0.45 + lift
	if jack_i >= 0:
		linear_velocity.x = 0.0
		linear_velocity.z = 0.0
		angular_velocity.y = 0.0
		brake = 120.0
		engine_force = 0.0


func _tick_winches(delta: float) -> void:
	for i in 2:
		if winch_state[i] == 1:
			var p: Node = world.get_player(winch_holder[i])
			if p == null or p.dead or p.global_position.distance_to(hook_pos(i)) > CABLE_LEN + 2.0:
				hook_action(i, winch_holder[i])
				if p:
					world.tell(p.peer_id, T.t("msg_cable_short"))
		elif winch_state[i] == 2:
			var hook := hook_pos(i)
			var item_name: String = winch_item[i]
			if item_name != "":
				var it := world.entities.get_node_or_null(item_name) as Item
				if it == null or it.is_queued_for_deletion() or it.holder != 0:
					hook_action(i, 0)
					continue
				winch_anchor[i] = it.global_position
				if winch_on[i]:
					winch_len[i] = maxf(winch_len[i] - delta * 1.2, 2.2)
				var to := hook - it.global_position
				var dist := to.length()
				if dist > winch_len[i] and dist > 0.1:
					var dir := to / dist
					var rel := (it.linear_velocity - linear_velocity).dot(dir)
					var f := clampf((dist - winch_len[i]) * 18000.0 - rel * 600.0, 0.0, WINCH_FORCE)
					it.apply_central_force(dir * f)
					apply_force(-dir * f, hook - global_position)
				if winch_on[i] and dist < 2.4:
					var on2: Array = winch_on.duplicate()
					on2[i] = false
					winch_on = on2
			elif winch_on[i]:
				var anchor: Vector3 = winch_anchor[i]
				var hook2 := hook
				var to2 := anchor - hook2
				var dist2 := to2.length()
				winch_len[i] = maxf(winch_len[i] - delta * 1.5, 1.5)
				if dist2 > winch_len[i]:
					var f2 := minf((dist2 - winch_len[i]) * 40000.0, WINCH_FORCE)
					apply_force(to2.normalized() * f2, hook2 - global_position)
				if dist2 < 2.0:
					var on: Array = winch_on.duplicate()
					on[i] = false
					winch_on = on


# ======================================================================= РАБОТЫ (удержание E)
## Старт/стоп длительной работы. kind: refuel, pump, repair, unbolt, mount, jack_up, jack_down.
func start_job(pid: int, kind: String, idx: int, extra := {}) -> void:
	var pl: Node = world.get_player(pid)
	if pl == null or pl.dead:
		return
	if kind in ["jack_up", "unbolt", "mount"] and (linear_velocity.length() > 1.5 or seats[0] != 0 and kind != "jack_down"):
		world.tell(pid, T.t("msg_rv_moving"))
		return
	job = {"pid": pid, "kind": kind, "idx": idx, "t": 0.0, "extra": extra, "snd": 0.0}


func stop_job(pid: int) -> void:
	if not job.is_empty() and int(job.pid) == pid:
		job = {}


func _tick_job(delta: float) -> void:
	if job.is_empty():
		return
	var pl: Node = world.get_player(int(job.pid))
	var far: bool = pl != null and (pl.global_position.distance_to(job.extra.get("pos", global_position)) > 8.0 if job.kind == "pump" else pl.global_position.distance_to(global_position) > 10.0)
	if pl == null or pl.dead or far:
		job = {}
		return
	var pid := int(job.pid)
	var kind: String = job.kind
	var idx := int(job.idx)
	job.t = float(job.t) + delta
	job.snd = float(job.snd) - delta
	var tick_snd: bool = float(job.snd) <= 0.0
	if tick_snd:
		job.snd = 0.45
	match kind:
		"refuel":
			var can := world.get_held_item(pid) as Item
			if can == null or can.kind != "jerrycan":
				job = {}
				return
			var liters := minf(3.5 * delta, minf(can.q * CAN_LITERS, max_fuel - fuel))
			if liters <= 0.0:
				world.tell(pid, T.t("msg_tank_full") if fuel >= max_fuel - 0.1 else T.t("msg_can_empty"))
				job = {}
				return
			fuel += liters
			can.q = maxf(can.q - liters / CAN_LITERS, 0.0)
			if tick_snd:
				world.sfx_all("fuel", global_position, -4.0, 1.0)
		"pump":
			if not world.pump_tick(pid, delta, job.extra):
				job = {}
				return
			if tick_snd:
				world.sfx_all("fuel", global_position, -4.0, 1.0)
		"repair":
			var rate := 14.0 * delta
			var part := str(job.extra.get("part", "engine"))
			var done := false
			match part:
				"engine":
					hp = minf(hp + rate, 100.0)
					done = hp >= 100.0
				"body":
					hp_body = minf(hp_body + rate, 100.0)
					done = hp_body >= 100.0
				"tank":
					hp_tank = minf(hp_tank + rate, 100.0)
					done = hp_tank >= 100.0
				"wheel":
					if int(wheel_state[idx]) == 0:
						var a: Array = wheel_hp.duplicate()
						a[idx] = minf(float(a[idx]) + rate, 100.0)
						wheel_hp = a
						done = a[idx] >= 100.0
					else:
						done = true
			if tick_snd:
				world.sfx_all("repair", global_position, -6.0, 1.0)
			if done:
				world.tell(pid, T.t("msg_part_ok"))
				job = {}
		"jack_up":
			if jack_i != idx:
				jack_i = idx
			jack_t = minf(jack_t + delta / 2.5, 1.0)
			if tick_snd:
				world.sfx_all("click", global_position, -4.0, 0.6)
			if jack_t >= 1.0:
				world.tell(pid, T.t("msg_jacked"))
				job = {}
		"jack_down":
			jack_t = maxf(jack_t - delta / 2.0, 0.0)
			if tick_snd:
				world.sfx_all("click", global_position, -4.0, 0.5)
			if jack_t <= 0.0:
				jack_i = -1
				world.tell(pid, T.t("msg_jack_down"))
				job = {}
		"unbolt":
			if jack_i != idx or jack_t < 0.99 or int(wheel_state[idx]) == 2:
				job = {}
				return
			if tick_snd:
				world.sfx_all("click", global_position, -2.0, 1.4)
			if float(job.t) >= 3.0:
				var was := int(wheel_state[idx])
				var q := float(wheel_hp[idx]) / 100.0
				var a: Array = wheel_state.duplicate()
				a[idx] = 2
				wheel_state = a
				var wp: Vector3 = (wheels[idx] as Node3D).global_position + global_basis.x * (1.0 if WHEEL_POS[idx].x > 0.0 else -1.0) * 0.8
				world.spawn_item("wheel_flat" if was == 1 else "spare_wheel", wp + Vector3.UP * 0.4, global_basis.x * (1.0 if WHEEL_POS[idx].x > 0.0 else -1.0) * 1.2, q)
				world.sfx_all("thud", wp, 0.0, 1.0)
				world.tell(pid, T.t("msg_wheel_off"))
				job = {}
		"mount":
			var wheel_it := world.get_held_item(pid) as Item
			if wheel_it == null or wheel_it.kind != "spare_wheel" or jack_i != idx or jack_t < 0.99 or int(wheel_state[idx]) != 2:
				job = {}
				return
			if tick_snd:
				world.sfx_all("click", global_position, -2.0, 1.4)
			if float(job.t) >= 3.5:
				var a2: Array = wheel_state.duplicate()
				a2[idx] = 0
				wheel_state = a2
				var h2: Array = wheel_hp.duplicate()
				h2[idx] = maxf(wheel_it.q * 100.0, 40.0)
				wheel_hp = h2
				wheel_it.queue_free()
				world.sfx_all("repair", global_position, 0.0, 1.2)
				world.tell(pid, T.t("msg_wheel_on"))
				job = {}


# ---- склад (хост)
func store_put(key: String, entry: Dictionary) -> bool:
	if not store.has(key):
		return false
	var arr: Array = store[key]
	if arr.size() >= int(STORE_CAP[key]):
		return false
	arr.append(entry)
	store = store.duplicate(true)
	return true


func store_take(key: String, i: int) -> Dictionary:
	if not store.has(key):
		return {}
	var arr: Array = store[key]
	if i < 0 or i >= arr.size():
		return {}
	var e: Dictionary = arr[i]
	arr.remove_at(i)
	store = store.duplicate(true)
	return e


## Свободное место на багажнике: возвращает позицию (мировую) или Vector3.INF.
func rack_free_slot() -> Vector3:
	var inv := global_transform.affine_inverse()
	var taken: Array = []
	for n in get_tree().get_nodes_in_group("items"):
		var it := n as Item
		if it != null and not it.is_queued_for_deletion():
			var l: Vector3 = inv * it.global_position
			if l.y > ROOF_Y and l.y < ROOF_Y + 1.8:
				taken.append(Vector2(l.x, l.z))
	for sl in RVBuild.RACK_SLOTS:
		var ok := true
		for t in taken:
			if Vector2(sl.x, sl.z).distance_to(t) < 0.75:
				ok = false
				break
		if ok:
			return global_transform * Vector3(sl.x, ROOF_Y + 0.7, sl.z)
	return Vector3.INF


func _set_needle(key: String, k: float, sweep: float) -> void:
	var n: Node3D = needles[key]
	var target := lerpf(sweep, -sweep, k)
	var cur: float = n.get_meta("a", sweep)
	cur = lerpf(cur, target, 0.2)
	n.set_meta("a", cur)
	n.basis = FACE * Basis(Vector3(0, 0, 1), cur)


func _make_dents() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var v := get_node("Vis")
	for i in 12:
		var e := 1.0 if i % 2 == 0 else -1.0
		var m := MU.box(Vector3(0.02, rng.randf_range(0.2, 0.5), rng.randf_range(0.3, 0.9)), MU.mat(Color(0.12, 0.1, 0.09, 0.85), 1.0), Vector3(e * 1.19, rng.randf_range(1.6, 2.8), rng.randf_range(-6.0, 2.0)), Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-12, 12)))
		m.visible = false
		v.add_child(m)
		_dent_nodes.append(m)


func _lamp(key: String, on: bool) -> void:
	var q: MeshInstance3D = lamps[key]
	var m := q.material_override as StandardMaterial3D
	var c: Color = q.get_meta("on_col") if on else Color(0.18, 0.18, 0.18)
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if on else BaseMaterial3D.SHADING_MODE_PER_PIXEL


func _effects(delta: float) -> void:
	_update_mirrors()
	var running: bool = seats[0] != 0 and fuel > 0.0 and hp > 0.0 and jack_i < 0
	exhaust.emitting = running
	smoke.emitting = hp < 30.0 or hp_body < 12.0
	leak.emitting = hp_tank < 45.0 and fuel > 0.0
	# печь: свет и искры
	stove_light.visible = stove_t > 0.0
	stove_light.light_energy = 1.0 + 0.4 * sin(Time.get_ticks_msec() * 0.02) if stove_t > 0.0 else 0.0
	stove_fx.emitting = stove_t > 0.0
	# колёса: спущенные приплюснуты, снятые невидимы; домкрат под поднятым углом
	for wi in wheel_parts.size():
		var st := int(wheel_state[wi])
		var tire: Node3D = wheel_parts[wi].tire
		var rim: Node3D = wheel_parts[wi].rim
		tire.visible = st != 2
		rim.visible = st != 2
		tire.scale = Vector3(1.0, 0.8, 0.8) if st == 1 else Vector3.ONE
		tire.position.y = -0.05 if st == 1 else 0.0
	jack_node.visible = jack_i >= 0
	if jack_i >= 0:
		var wp: Vector3 = WHEEL_POS[jack_i]
		jack_node.position = Vector3(wp.x * 0.78, 0.05, wp.z)
		jack_node.scale = Vector3(1, 0.85 + jack_t * 0.5, 1)
	# вмятины и царапины на кузове по мере повреждения
	if _dent_nodes.is_empty():
		_make_dents()
	var nd := int(clampf((100.0 - hp_body) / 8.0, 0.0, float(_dent_nodes.size())))
	for i in _dent_nodes.size():
		(_dent_nodes[i] as Node3D).visible = i < nd
	var spd := sync_vel.length()
	if running:
		engine_snd.volume_db = lerpf(engine_snd.volume_db, -4.0, 0.1)
		engine_snd.pitch_scale = lerpf(engine_snd.pitch_scale, 0.5 + rpm / MAX_RPM * 1.3 + throttle_vis * 0.1, 0.1)
	else:
		engine_snd.volume_db = lerpf(engine_snd.volume_db, -60.0, 0.05)
	winch_snd.volume_db = lerpf(winch_snd.volume_db, -8.0 if (winch_on[0] or winch_on[1]) else -60.0, 0.1)
	for l in lights:
		(l as SpotLight3D).visible = lights_on
	cabin_light.visible = world != null and not world.is_day()
	if not vis_wheels.is_empty():
		_wheel_rot += sync_vel.dot(global_basis.z) / WHEEL_R * delta
		for w in vis_wheels:
			(w as Node3D).rotation.x = _wheel_rot
	# руль и приборы
	steering_wheel.rotation.z = steer_vis * 3.0
	var sweep := 2.36
	_set_needle("speed", clampf(spd * 3.6 / 120.0, 0.0, 1.0), sweep)
	_set_needle("rpm", clampf(rpm / 5000.0, 0.0, 1.0), sweep)
	_set_needle("fuel", clampf(fuel / maxf(max_fuel, 1.0), 0.0, 1.0), sweep)
	_set_needle("engine", clampf(hp / 100.0, 0.0, 1.0), sweep)
	var winching: bool = winch_on[0] or winch_on[1]
	_lamp("fuel", fuel < max_fuel * 0.15 and fmod(Time.get_ticks_msec() * 0.004, 2.0) < 1.4)
	_lamp("engine", hp < 30.0)
	_lamp("winch", winching)
	_lamp("lights", lights_on)
	_lamp("brake", seats[0] != 0 and in_b > 0.5)
	for k in ["winch_front", "winch_rear"]:
		var i := 0 if k == "winch_front" else 1
		(btn_vis[k] as MeshInstance3D).material_override.albedo_color = Color(0.4, 1.0, 1.0) if winch_on[i] else (Color(1.0, 0.9, 0.5) if winch_state[i] == 2 else Color(0.85, 0.85, 0.8))
	(btn_vis["lights"] as MeshInstance3D).material_override.albedo_color = Color(0.5, 1.0, 0.5) if lights_on else Color(0.85, 0.85, 0.8)
	# рычаг КПП: пока его не держат, стоит там, где включена передача
	if not lever_hold:
		lever_pos = lever_pos.lerp(gear_to_lever(gear), clampf(delta * 12.0, 0.0, 1.0))
	lever.basis = Basis(Vector3(0, 0, 1), lever_pos.x * 0.22) * Basis(Vector3(1, 0, 0), lever_pos.y * 0.22)
	# тросы
	for i in 2:
		var c: MeshInstance3D = cables[i]
		var b := Vector3.ZERO
		var show := false
		if winch_state[i] == 2:
			b = winch_anchor[i]
			var wn: String = winch_item[i] if winch_item.size() > i else ""
			if wn != "" and world:
				var wit := world.entities.get_node_or_null(wn) as Node3D
				if wit:
					b = wit.global_position
			show = true
		elif winch_state[i] == 1 and world:
			var p: Node = world.get_player(winch_holder[i])
			if p:
				b = p.global_position + Vector3.UP * 1.1 - p.global_basis.z * 0.3
				show = true
		c.visible = show
		if show:
			var a := hook_pos(i)
			var len := a.distance_to(b)
			if len > 0.1:
				var d := (b - a) / len
				var up := Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT
				c.global_transform = Transform3D(Basis.looking_at(d, up) * Basis(Vector3.RIGHT, PI / 2.0), (a + b) * 0.5)
				c.scale = Vector3(1, len, 1)
