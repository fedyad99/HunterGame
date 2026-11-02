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
	[Vector3(0.72, 1.12, -1.5), PI / 2.0],    # 2 диван
	[Vector3(0.72, 1.12, -2.35), PI / 2.0],   # 3 диван
]
const STAND := [Vector3(0.1, 1.1, 1.6), Vector3(-0.2, 1.1, 1.6), Vector3(0.0, 1.1, -1.5), Vector3(0.0, 1.1, -2.35)]
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
const CABLE_LEN := 30.0
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


func setup(data: Dictionary) -> void:
	name = "RV"
	position = data.pos
	rotation.y = float(data.get("yaw", 0.0))
	sync_xform = Transform3D(Basis(Vector3.UP, rotation.y), data.pos)
	mass = 3200.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.35, -1.2)
	angular_damp = 0.6
	collision_layer = MU.L_RV
	collision_mask = MU.L_WORLD | MU.L_ITEMS
	_build()
	add_child(MU.make_sync(["sync_xform", "sync_vel", "fuel", "max_fuel", "hp", "up_engine", "up_tank",
		"up_armor", "up_heater", "seats", "throttle_vis", "steer_vis", "gear", "rpm", "lights_on",
		"winch_state", "winch_holder", "winch_anchor", "winch_on"], 0.033))


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
func _wall(v: Node3D, size: Vector3, pos: Vector3, c: Color, glass: Material) -> void:
	_shape(size, pos)
	var y0 := pos.y - size.y * 0.5
	var bottom := 0.95
	var win := 0.65
	var top := size.y - bottom - win
	v.add_child(MU.box(Vector3(size.x, bottom, size.z), c, Vector3(pos.x, y0 + bottom * 0.5, pos.z)))
	v.add_child(MU.box(Vector3(size.x * 0.6, win, size.z), glass, Vector3(pos.x, y0 + bottom + win * 0.5, pos.z)))
	v.add_child(MU.box(Vector3(size.x, top, size.z), c, Vector3(pos.x, y0 + bottom + win + top * 0.5, pos.z)))


func _build() -> void:
	var cream := Color(0.9, 0.86, 0.75)
	var brown := Color(0.45, 0.28, 0.15)
	var dark := Color(0.2, 0.2, 0.2)
	var glass := MU.mat(Color(0.35, 0.45, 0.5, 0.3), 0.05, 0.0, 0.3)
	var cz := -0.1 - EXT * 0.5          # центр удлинённой части по Z
	var lz := 6.8 + EXT                 # длина кузова
	var wh := 2.1 + H_UP                # высота стен
	var wy := 2.1 + H_UP * 0.5          # центр стен по Y
	var v := Node3D.new()
	v.name = "Vis"
	add_child(v)
	# рама и пол
	_part(v, Vector3(2.4, 0.55, 7.0 + EXT), Vector3(0, 0.72, cz), dark)
	_part(v, Vector3(2.3, 0.08, lz), Vector3(0, FLOOR_Y - 0.04, cz), Color(0.42, 0.3, 0.2))
	# стены: левая (+X) целая, правая (−X) с дверным проёмом z 0.3..1.3
	_wall(v, Vector3(0.1, wh, lz), Vector3(1.15, wy, cz), cream, glass)
	_wall(v, Vector3(0.1, wh, 3.8 + EXT), Vector3(-1.15, wy, -1.6 - EXT * 0.5), cream, glass)
	_wall(v, Vector3(0.1, wh, 1.9), Vector3(-1.15, wy, 2.35), cream, glass)
	_part(v, Vector3(0.1, 0.55, 1.0), Vector3(-1.15, ROOF_Y - 0.3, 0.8), cream)   # перемычка над дверью
	_part(v, Vector3(2.4, wh, 0.1), Vector3(0, wy, REAR_Z), cream)
	# полосы снаружи
	v.add_child(MU.box(Vector3(2.44, 0.18, lz + 0.02), brown, Vector3(0, 1.55, cz)))
	v.add_child(MU.box(Vector3(2.44, 0.06, lz + 0.02), Color(0.85, 0.5, 0.1), Vector3(0, 1.72, cz)))
	# крыша (на неё можно залезть по лестнице)
	_part(v, Vector3(2.4, 0.1, lz), Vector3(0, ROOF_Y, cz), cream)
	v.add_child(MU.box(Vector3(2.0, 0.06, 3.0 + EXT * 0.7), dark, Vector3(0, ROOF_Y + 0.1, -1.2 - EXT * 0.35)))
	for e in [-1, 1]:
		v.add_child(MU.box(Vector3(0.05, 0.15, 3.0 + EXT * 0.7), dark, Vector3(e * 1.0, ROOF_Y + 0.15, -1.2 - EXT * 0.35)))
	# кондиционер и люк на крыше
	v.add_child(MU.box(Vector3(0.9, 0.22, 1.3), Color(0.85, 0.85, 0.87), Vector3(0.0, ROOF_Y + 0.2, -3.0)))
	v.add_child(MU.box(Vector3(0.95, 0.04, 1.35), Color(0.6, 0.6, 0.62), Vector3(0.0, ROOF_Y + 0.33, -3.0)))
	v.add_child(MU.box(Vector3(0.7, 0.04, 0.7), MU.mat(Color(0.5, 0.7, 0.85, 0.5), 0.1, 0.0, 0.3), Vector3(0.0, ROOF_Y + 0.07, -0.6)))
	# кабина: капот, приборная панель, лобовое стекло
	_part(v, Vector3(2.3, 0.75, 1.0), Vector3(0, 1.0, 3.85), cream)
	_part(v, Vector3(2.3, 0.08, 1.0), Vector3(0, 1.42, 3.85), brown)
	_part(v, Vector3(2.2, 0.85, 0.5), Vector3(0, 1.475, 3.1), Color(0.36, 0.33, 0.29))
	_shape(Vector3(2.3, 1.3 + H_UP, 0.08), Vector3(0, 2.55 + H_UP * 0.5, 3.35))
	v.add_child(MU.box(Vector3(2.3, 1.3 + H_UP, 0.04), glass, Vector3(0, 2.55 + H_UP * 0.5, 3.35)))
	v.add_child(MU.box(Vector3(2.4, 0.1, 0.12), cream, Vector3(0, ROOF_Y - 0.02, 3.35)))
	v.add_child(MU.box(Vector3(2.4, 0.3, 0.3), dark, Vector3(0, 0.75, 4.4)))   # бампер
	# ступеньки у двери
	for i in 3:
		var sp := Vector3(-1.45 - i * 0.3, FLOOR_Y - 0.3 - i * 0.3, 0.8)
		_part(v, Vector3(0.3, 0.08, 0.9), sp, Color(0.35, 0.35, 0.36))
	# лестница на крышу (сзади)
	for i in 11:
		v.add_child(MU.box(Vector3(0.45, 0.04, 0.04), dark, Vector3(-0.6, 0.6 + i * 0.35, REAR_Z - 0.11)))
	for e in [-1, 1]:
		v.add_child(MU.box(Vector3(0.04, 3.7, 0.04), dark, Vector3(-0.6 + e * 0.22, 2.4, REAR_Z - 0.11)))
	add_child(MU.area_box(Vector3(0.7, 3.4, 0.5), Vector3(-0.6, 2.3, REAR_Z - 0.3), "rv_ladder", "St_ladder"))
	# фары
	for e in [-1, 1]:
		v.add_child(MU.box(Vector3(0.35, 0.2, 0.05), MU.mat(Color(1.0, 0.95, 0.8), 0.2, 2.0), Vector3(e * 0.8, 1.15, 4.37)))
		var sl := SpotLight3D.new()
		sl.position = Vector3(e * 0.8, 1.15, 4.4)
		sl.rotation_degrees = Vector3(-5, 180, 0)
		sl.spot_range = 50.0
		sl.spot_angle = 35.0
		sl.light_energy = 4.0
		sl.shadow_enabled = true
		sl.visible = false
		add_child(sl)
		lights.append(sl)
	# задние фонари
	for e in [-1, 1]:
		v.add_child(MU.box(Vector3(0.18, 0.3, 0.05), MU.mat(Color(0.9, 0.05, 0.05), 0.3, 1.2), Vector3(e * 1.0, 1.5, REAR_Z - 0.06)))
	# ---- салон
	# кресла водителя и пассажира
	for e in [1, -1]:
		v.add_child(MU.box(Vector3(0.55, 0.12, 0.55), Color(0.25, 0.18, 0.12), Vector3(e * 0.55, 1.5, 2.25)))
		v.add_child(MU.box(Vector3(0.55, 0.8, 0.12), Color(0.25, 0.18, 0.12), Vector3(e * 0.55, 1.9, 1.95), Vector3(-10, 0, 0)))
		v.add_child(MU.box(Vector3(0.3, 0.4, 0.4), dark, Vector3(e * 0.55, 1.25, 2.25)))
	# диван у левой стены
	v.add_child(MU.box(Vector3(0.55, 0.45, 1.8), Color(0.35, 0.45, 0.3), Vector3(0.82, 1.3, -1.95)))
	v.add_child(MU.box(Vector3(0.15, 0.6, 1.8), Color(0.35, 0.45, 0.3), Vector3(1.03, 1.8, -1.95)))
	# стол
	v.add_child(MU.box(Vector3(0.7, 0.05, 1.0), Color(0.5, 0.36, 0.22), Vector3(0.1, 1.8, -1.95)))
	v.add_child(MU.box(Vector3(0.08, 0.7, 0.08), dark, Vector3(0.1, 1.42, -1.95)))
	# плита у правой стены
	_part(v, Vector3(0.6, 0.9, 1.1), Vector3(-0.82, 1.5, -1.2), Color(0.55, 0.55, 0.57))
	v.add_child(MU.box(Vector3(0.5, 0.03, 0.9), MU.mat(Color(0.1, 0.1, 0.1), 0.3, 0.0, 0.8), Vector3(-0.82, 1.97, -1.2)))
	add_child(MU.area_box(Vector3(0.8, 0.6, 1.2), Vector3(-0.72, 2.0, -1.2), "rv_stove", "St_stove"))
	# кухонная тумба с раковиной вдоль правой стены дальше
	_part(v, Vector3(0.6, 0.9, 1.6), Vector3(-0.82, 1.5, -2.9), Color(0.5, 0.36, 0.22))
	v.add_child(MU.box(Vector3(0.62, 0.04, 1.62), Color(0.78, 0.78, 0.8), Vector3(-0.82, 1.97, -2.9)))
	v.add_child(MU.box(Vector3(0.4, 0.05, 0.5), Color(0.35, 0.37, 0.4), Vector3(-0.82, 1.99, -2.9)))
	# двухъярусная кровать у левой стены и широкая кровать в хвосте
	var bz := REAR_Z + 1.3
	v.add_child(MU.box(Vector3(2.2, 0.5, 1.7), Color(0.4, 0.3, 0.25), Vector3(0, 1.3, bz)))
	v.add_child(MU.box(Vector3(2.1, 0.14, 1.65), Color(0.85, 0.85, 0.9), Vector3(0, 1.62, bz)))
	v.add_child(MU.box(Vector3(0.7, 0.1, 0.45), Color(0.9, 0.9, 0.95), Vector3(0.6, 1.74, bz - 0.55)))
	v.add_child(MU.box(Vector3(0.7, 0.1, 0.45), Color(0.9, 0.9, 0.95), Vector3(-0.6, 1.74, bz - 0.55)))
	var cz2 := REAR_Z + 3.3
	for lvl in 2:
		v.add_child(MU.box(Vector3(0.75, 0.1, 1.9), Color(0.4, 0.3, 0.25), Vector3(0.78, 1.45 + lvl * 0.95, cz2)))
		v.add_child(MU.box(Vector3(0.72, 0.12, 1.85), Color(0.55, 0.65, 0.75), Vector3(0.78, 1.55 + lvl * 0.95, cz2)))
	for zz in [cz2 - 0.9, cz2 + 0.9]:
		v.add_child(MU.box(Vector3(0.06, 2.2, 0.06), dark, Vector3(1.12, 2.15, zz)))
	# шкаф-сушилка у левой стены
	_part(v, Vector3(0.55, 2.0 + H_UP, 0.9), Vector3(0.85, 2.05 + H_UP * 0.5, 0.75), brown)
	add_child(MU.area_box(Vector3(0.7, 1.6, 1.0), Vector3(0.62, 2.0, 0.75), "rv_wardrobe", "St_wardrobe"))
	# коврик и ящики
	v.add_child(MU.box(Vector3(1.2, 0.01, 1.8), Color(0.5, 0.2, 0.15), Vector3(0.0, FLOOR_Y + 0.01, -3.9)))
	_part(v, Vector3(0.5, 0.6, 0.5), Vector3(-0.85, 1.35, REAR_Z + 1.2), Color(0.5, 0.36, 0.22))
	# места
	for i in 4:
		var a := MU.area_box(Vector3(0.6, 0.9, 0.6), SEATS[i][0] + Vector3(0, 0.6, 0), "rv_seat", "St_seat%d" % i)
		a.set_meta("seat", i)
		add_child(a)
	# ---- приборная панель и рычаг КПП
	_build_dashboard(v)
	# ---- снаружи: разделочный стол, бак, двигатель, крюки
	v.add_child(MU.box(Vector3(0.7, 0.06, 1.3), Color(0.55, 0.4, 0.25), Vector3(1.6, 1.05, -2.3)))
	add_child(MU.area_box(Vector3(0.9, 0.8, 1.4), Vector3(1.6, 1.2, -2.3), "rv_butcher", "St_butcher"))
	v.add_child(MU.cyl(0.08, 0.08, 0.05, dark, Vector3(1.22, 1.2, -0.6), Vector3(0, 0, 90)))
	add_child(MU.area_box(Vector3(0.5, 0.6, 0.6), Vector3(1.4, 1.2, -0.6), "rv_fuel", "St_fuel"))
	add_child(MU.area_box(Vector3(1.8, 0.6, 1.0), Vector3(0, 1.6, 3.85), "rv_engine", "St_engine"))
	# уличный термометр рядом с дверью
	thermo = Thermometer.new()
	thermo.position = Vector3(-1.23, 2.1, 1.95)
	thermo.rotation.y = -PI * 0.5
	v.add_child(thermo)
	for i in 2:
		var hp_: Vector3 = HOOKS[i]
		v.add_child(MU.box(Vector3(0.45, 0.3, 0.25), Color(0.6, 0.15, 0.1), hp_))
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
	for wp in [Vector3(1.1, 0.55, 2.6), Vector3(-1.1, 0.55, 2.6), Vector3(1.1, 0.55, -2.4 - EXT * 0.75), Vector3(-1.1, 0.55, -2.4 - EXT * 0.75)]:
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
		w.add_child(MU.cyl(0.5, 0.5, 0.35, Color(0.08, 0.08, 0.08), Vector3.ZERO, Vector3(0, 0, 90), 16))
		w.add_child(MU.cyl(0.28, 0.28, 0.37, MU.mat(Color(0.6, 0.6, 0.62), 0.3, 0.0, 0.8), Vector3.ZERO, Vector3(0, 0, 90), 8))
		add_child(w)
		wheels.append(w)
	_build_mirrors()
	exhaust = _particles(Color(0.35, 0.35, 0.35, 0.4), Vector3(0.9, 0.5, REAR_Z - 0.05), 0.08)
	smoke = _particles(Color(0.1, 0.1, 0.1, 0.6), Vector3(0, 1.6, 4.2), 0.2)
	smoke.amount = 24
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


# ---- приборная панель: только круглые приборы, лампочки-иконки и кнопки-иконки
const FACE := Basis(Quaternion(Vector3(0, 1, 0), PI) * Quaternion(Vector3(1, 0, 0), -0.9599310885968813))


func _panel_pos(xl: float, yl: float, lift := 0.012) -> Vector3:
	return Vector3(0.55, 1.93, 2.98) + FACE.x * xl + FACE.y * yl + FACE.z * lift


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
	steering_wheel.position = Vector3(0.55, 2.12, 2.72)
	steering_wheel.rotation_degrees = Vector3(-60, 0, 0)
	v.add_child(steering_wheel)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.15
	torus.outer_radius = 0.19
	var tm := MeshInstance3D.new()
	tm.mesh = torus
	tm.material_override = MU.mat(Color(0.1, 0.1, 0.1))
	steering_wheel.add_child(tm)
	steering_wheel.add_child(MU.box(Vector3(0.32, 0.03, 0.04), Color(0.1, 0.1, 0.1)))
	v.add_child(MU.cyl(0.03, 0.03, 0.35, Color(0.1, 0.1, 0.1), Vector3(0.55, 1.98, 2.86), Vector3(-60, 0, 0)))
	# приборы: спидометр, тахометр, топливо, состояние двигателя
	_gauge(v, "speed", 0.0, 0.0, 0.11, 24, 4, -1.0)
	_gauge(v, "rpm", -0.235, 0.0, 0.085, 10, 2, 0.8)
	_gauge(v, "fuel", 0.19, 0.085, 0.05, 4, 4, -1.0, "fuel", Color(0.9, 0.85, 0.5))
	_gauge(v, "engine", 0.19, -0.05, 0.05, 4, 4, -1.0, "engine", Color(0.9, 0.85, 0.5))
	# контрольные лампочки-иконки
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
		var yl := -0.17
		var base := MU.box(Vector3(0.085, 0.085, 0.012), MU.mat(Color(0.12, 0.12, 0.14), 0.5), Vector3.ZERO)
		base.transform = Transform3D(FACE, _panel_pos(xl, yl, 0.005))
		v.add_child(base)
		var ic := _quad(v, DashIcons.icon(btns[i][1]), 0.062, _panel_pos(xl, yl, 0.0125), Color(0.85, 0.85, 0.8), 0.0)
		btn_vis[btns[i][0]] = ic
		var pos := _panel_pos(xl, yl, 0.0)
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
	winch_state = st
	winch_holder = hl
	winch_on = on
	world.sfx_all("reload", hook_pos(i), 0.0, 0.6)
	return res


func attach_cable(i: int, pid: int, point: Vector3) -> String:
	if winch_state[i] != 1 or winch_holder[i] != pid:
		return ""
	if point.distance_to(hook_pos(i)) > CABLE_LEN:
		return "msg_cable_short"
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
	if seats[0] == 0 or Time.get_ticks_msec() - last_in_ms > 600:
		in_t = 0.0
		in_s = 0.0
		in_b = 1.0 if seats[0] == 0 else in_b
	var speed := linear_velocity.dot(global_basis.z)
	var running: bool = seats[0] != 0 and fuel > 0.0 and hp > 0.0
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
	elif hp < 30.0:
		power *= 0.5
	engine_force = gas * power * ratio / 1.6
	brake = maxf(in_b * 70.0, maxf(-in_t, 0.0) * 50.0)
	# сцепление зависит от поверхности под колесом
	for w in wheels:
		var wp: Vector3 = (w as Node3D).global_position
		var on_road := TerrainGen.road_query(Vector2(wp.x, wp.z)).x < 4.0
		var h := TerrainGen.height_at(wp.x, wp.z)
		var slip := 3.0 if on_road else 2.0
		if h < TerrainGen.WATER + 1.5:
			slip = 1.1   # грязь у воды
		if world.raining and not on_road:
			slip *= 0.75
		(w as VehicleWheel3D).wheel_friction_slip = slip
	# стабилизатор: возвращает кузов к вертикали, но даёт раскачиваться
	var up_err := global_basis.y.cross(Vector3.UP)
	apply_torque(up_err * mass * 6.0 - angular_velocity * Vector3(1, 0, 1) * mass * 0.8)
	# лебёдки
	for i in 2:
		if winch_state[i] == 1:
			var p: Node = world.get_player(winch_holder[i])
			if p == null or p.dead or p.global_position.distance_to(hook_pos(i)) > CABLE_LEN + 2.0:
				hook_action(i, winch_holder[i])
				if p:
					world.tell(p.peer_id, T.t("msg_cable_short"))
		elif winch_state[i] == 2 and winch_on[i]:
			var hook := hook_pos(i)
			var anchor: Vector3 = winch_anchor[i]
			var to := anchor - hook
			var dist := to.length()
			winch_len[i] = maxf(winch_len[i] - delta * 1.5, 1.5)
			if dist > winch_len[i]:
				var f := minf((dist - winch_len[i]) * 40000.0, WINCH_FORCE)
				apply_force(to.normalized() * f, hook - global_position)
			if dist < 2.0:
				var on: Array = winch_on.duplicate()
				on[i] = false
				winch_on = on
	var max_steer := lerpf(0.5, 0.16, clampf(absf(speed) / 25.0, 0.0, 1.0))
	steering = move_toward(steering, in_s * max_steer, delta * 1.6)
	steer_vis = steering
	throttle_vis = gas if power > 0.0 else 0.0
	if running:
		fuel = maxf(fuel - delta * (0.02 + gas * 0.12 * rpm / MAX_RPM), 0.0)
	# удары
	var dv := (linear_velocity - prev_vel).length()
	if dv > 5.0:
		var dmg := (dv - 5.0) * 6.0 * float(ARMOR_MULT[up_armor])
		hp = maxf(hp - dmg, 0.0)
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


func _set_needle(key: String, k: float, sweep: float) -> void:
	var n: Node3D = needles[key]
	var target := lerpf(sweep, -sweep, k)
	var cur: float = n.get_meta("a", sweep)
	cur = lerpf(cur, target, 0.2)
	n.set_meta("a", cur)
	n.basis = FACE * Basis(Vector3(0, 0, 1), cur)


func _lamp(key: String, on: bool) -> void:
	var q: MeshInstance3D = lamps[key]
	var m := q.material_override as StandardMaterial3D
	var c: Color = q.get_meta("on_col") if on else Color(0.18, 0.18, 0.18)
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if on else BaseMaterial3D.SHADING_MODE_PER_PIXEL


func _effects(delta: float) -> void:
	_update_mirrors()
	var running: bool = seats[0] != 0 and fuel > 0.0 and hp > 0.0
	exhaust.emitting = running
	smoke.emitting = hp < 30.0
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
