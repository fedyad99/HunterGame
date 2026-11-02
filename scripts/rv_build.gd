class_name RVBuild
extends RefCounted
## Сборка внешности и салона дома на колёсах: текстуры ambientCG и модели Poly Haven (CC0).
## Оригинальная компоновка: кузов, салон и кабина собраны из частей, а не скопированы откуда-то.

const F := RV.FLOOR_Y


static func _cream() -> StandardMaterial3D:
	return A3.tmat("plastic", Color(1.25, 1.2, 1.05), 1.6, 0.5)


static func _wood(tint := Color(1.25, 1.05, 0.85)) -> StandardMaterial3D:
	return A3.tmat("wood", tint, 0.8, 0.7)


static func _fabric(tint: Color) -> StandardMaterial3D:
	return A3.tmat("fabric", tint * 2.2, 0.35, 0.95)


static func _rubber() -> StandardMaterial3D:
	return A3.tmat("rubber", Color(0.5, 0.5, 0.5), 0.5, 0.9)


static func _steel() -> StandardMaterial3D:
	return A3.tmat("steel", Color(0.9, 0.92, 0.95), 1.0, 0.35, 0.6)


## Модель Poly Haven в точке с разворотом (градусы) и без тени-«мыла».
static func put_model(v: Node3D, name: String, pos: Vector3, yaw_deg := 0.0, h := -1.0, l := -1.0) -> Node3D:
	var m := A3.model(name, h, l)
	m.position = pos
	m.rotation_degrees.y = yaw_deg
	v.add_child(m)
	return m


# ======================================================================= КУЗОВ
static func body(rv: RV, v: Node3D) -> void:
	var cream := _cream()
	var dark := A3.tmat("rubber", Color(0.35, 0.35, 0.37), 0.6, 0.8)
	var stripe := A3.tmat("plastic", Color(0.55, 0.3, 0.14), 1.6, 0.5)
	var orange := A3.tmat("plastic", Color(0.95, 0.55, 0.12), 1.6, 0.5)
	var glass := MU.mat(Color(0.4, 0.55, 0.62, 0.28), 0.04, 0.0, 0.2)
	var cz := -0.1 - RV.EXT * 0.5
	var lz := 6.8 + RV.EXT
	var wh := 2.1 + RV.H_UP
	var wy := 2.1 + RV.H_UP * 0.5
	# рама и пол (пол — дерево)
	rv._part(v, Vector3(2.4, 0.55, 7.0 + RV.EXT), Vector3(0, 0.72, cz), dark)
	rv._part(v, Vector3(2.3, 0.08, lz), Vector3(0, F - 0.04, cz), _wood(Color(0.8, 0.66, 0.52)))
	# стены (левая +X целая, правая −X с дверным проёмом z 0.3..1.3)
	rv._wall(v, Vector3(0.1, wh, lz), Vector3(1.15, wy, cz), cream, glass)
	rv._wall(v, Vector3(0.1, wh, 3.8 + RV.EXT), Vector3(-1.15, wy, -1.6 - RV.EXT * 0.5), cream, glass)
	rv._wall(v, Vector3(0.1, wh, 1.9), Vector3(-1.15, wy, 2.35), cream, glass)
	rv._part(v, Vector3(0.1, 0.55, 1.0), Vector3(-1.15, RV.ROOF_Y - 0.3, 0.8), cream)
	rv._part(v, Vector3(2.4, wh, 0.1), Vector3(0, wy, RV.REAR_Z), cream)
	# рамки окон
	for e in [-1, 1]:
		for seg in [[lz, cz]] if e > 0 else [[3.8 + RV.EXT, -1.6 - RV.EXT * 0.5], [1.9, 2.35]]:
			var sl: float = seg[0]
			var sc: float = seg[1]
			for yy in [2.0, 2.65]:
				v.add_child(MU.box(Vector3(0.14, 0.05, sl * 0.62), dark, Vector3(e * 1.15, yy, sc)))
	# полосы
	v.add_child(MU.box(Vector3(2.44, 0.18, lz + 0.02), stripe, Vector3(0, 1.55, cz)))
	v.add_child(MU.box(Vector3(2.44, 0.06, lz + 0.02), orange, Vector3(0, 1.72, cz)))
	# юбка кузова и подножки-рамки
	v.add_child(MU.box(Vector3(2.46, 0.3, lz + 0.04), dark, Vector3(0, 1.0, cz)))
	# крыша
	rv._part(v, Vector3(2.4, 0.1, lz), Vector3(0, RV.ROOF_Y, cz), cream)
	for e in [-1, 1]:
		v.add_child(MU.box(Vector3(0.06, 0.08, lz), orange, Vector3(e * 1.2, RV.ROOF_Y - 0.05, cz)))
	# кабина: капот, панель, лобовое стекло
	rv._part(v, Vector3(2.3, 0.75, 1.0), Vector3(0, 1.0, 3.85), cream)
	rv._part(v, Vector3(2.3, 0.08, 1.0), Vector3(0, 1.42, 3.85), stripe)
	# приборная панель: мягкий пластик, верх повыше, чтобы приборы были над рулём
	rv._part(v, Vector3(2.2, 0.85, 0.5), Vector3(0, 1.475, 3.1), A3.tmat("rubber", Color(0.7, 0.66, 0.6), 0.5, 0.8))
	v.add_child(MU.box(Vector3(2.2, 0.04, 0.5), _wood(Color(0.7, 0.5, 0.35)), Vector3(0, 1.915, 3.1)))
	rv._shape(Vector3(2.3, 1.3 + RV.H_UP, 0.08), Vector3(0, 2.55 + RV.H_UP * 0.5, 3.35))
	v.add_child(MU.box(Vector3(2.3, 1.3 + RV.H_UP, 0.04), glass, Vector3(0, 2.55 + RV.H_UP * 0.5, 3.35)))
	for e in [-1, 1]:   # стойки лобового стекла
		v.add_child(MU.box(Vector3(0.1, 1.7, 0.12), dark, Vector3(e * 1.15, 2.6, 3.35)))
	v.add_child(MU.box(Vector3(2.4, 0.12, 0.14), cream, Vector3(0, RV.ROOF_Y - 0.02, 3.35)))
	# солнцезащитные козырьки
	for e in [1, -1]:
		v.add_child(MU.box(Vector3(0.5, 0.03, 0.28), A3.tmat("fabric", Color(0.6, 0.55, 0.45), 0.3, 0.9), Vector3(e * 0.55, 3.4, 3.15)))
	# решётка радиатора, бампер, фары
	v.add_child(MU.box(Vector3(1.2, 0.34, 0.05), MU.mat(Color(0.06, 0.06, 0.07), 0.5), Vector3(0, 1.0, 4.355)))
	for i in 5:
		v.add_child(MU.box(Vector3(1.2, 0.02, 0.06), _steel(), Vector3(0, 0.88 + i * 0.07, 4.365)))
	rv._part(v, Vector3(2.46, 0.26, 0.22), Vector3(0, 0.66, 4.41), _steel())
	v.add_child(MU.box(Vector3(2.5, 0.08, 0.24), dark, Vector3(0, 0.8, 4.41)))
	for e in [-1, 1]:
		v.add_child(MU.cyl(0.14, 0.14, 0.06, _steel(), Vector3(e * 0.82, 1.15, 4.36), Vector3(90, 0, 0), 16))
		v.add_child(MU.cyl(0.115, 0.115, 0.07, MU.mat(Color(1.0, 0.95, 0.8), 0.15, 2.0), Vector3(e * 0.82, 1.15, 4.37), Vector3(90, 0, 0), 16))
		v.add_child(MU.box(Vector3(0.16, 0.07, 0.05), MU.mat(Color(1.0, 0.6, 0.1), 0.3, 1.0), Vector3(e * 0.82, 0.93, 4.37)))
		var sl := SpotLight3D.new()
		sl.position = Vector3(e * 0.82, 1.15, 4.42)
		sl.rotation_degrees = Vector3(-5, 180, 0)
		sl.spot_range = 50.0
		sl.spot_angle = 35.0
		sl.light_energy = 4.0
		sl.shadow_enabled = true
		sl.visible = false
		rv.add_child(sl)
		rv.lights.append(sl)
	# задняя часть: фонари, бампер, номер
	for e in [-1, 1]:
		v.add_child(MU.box(Vector3(0.2, 0.34, 0.06), MU.mat(Color(0.9, 0.05, 0.05), 0.3, 1.2), Vector3(e * 1.0, 1.5, RV.REAR_Z - 0.06)))
		v.add_child(MU.box(Vector3(0.2, 0.08, 0.06), MU.mat(Color(0.9, 0.9, 0.9), 0.3, 0.8), Vector3(e * 1.0, 1.28, RV.REAR_Z - 0.06)))
	rv._part(v, Vector3(2.46, 0.24, 0.2), Vector3(0, 0.78, RV.REAR_Z - 0.12), _steel())
	v.add_child(MU.box(Vector3(0.5, 0.12, 0.02), MU.mat(Color(0.95, 0.95, 0.9), 0.5), Vector3(0.0, 1.2, RV.REAR_Z - 0.07)))
	# колёсные арки: тёмные диски на борту за колёсами и хромированные ободки
	for wp in RV.WHEEL_POS:
		var e := 1.0 if wp.x > 0.0 else -1.0
		v.add_child(MU.cyl(0.66, 0.66, 0.04, MU.mat(Color(0.03, 0.03, 0.03), 1.0), Vector3(e * 1.17, wp.y + 0.05, wp.z), Vector3(0, 0, 90), 20))
		v.add_child(MU.box(Vector3(0.08, 0.06, 1.4), dark, Vector3(e * 1.27, wp.y + 0.7, wp.z)))
	# ступеньки у двери
	for i in 3:
		var sp := Vector3(-1.45 - i * 0.3, F - 0.3 - i * 0.3, 0.8)
		rv._part(v, Vector3(0.3, 0.08, 0.9), sp, _steel())
	# задняя лестница на крышу
	for i in 11:
		v.add_child(MU.box(Vector3(0.45, 0.04, 0.04), _steel(), Vector3(-0.6, 0.6 + i * 0.35, RV.REAR_Z - 0.11)))
	for e in [-1, 1]:
		v.add_child(MU.box(Vector3(0.04, 3.7, 0.04), _steel(), Vector3(-0.6 + e * 0.22, 2.4, RV.REAR_Z - 0.11)))
	rv.add_child(MU.area_box(Vector3(0.7, 3.4, 0.5), Vector3(-0.6, 2.3, RV.REAR_Z - 0.3), "rv_ladder", "St_ladder"))
	# кондиционер, люк, антенна
	v.add_child(MU.box(Vector3(0.9, 0.22, 1.1), A3.tmat("plastic", Color(0.95, 0.95, 0.97), 1.0, 0.5), Vector3(0.0, RV.ROOF_Y + 0.2, 0.9)))
	v.add_child(MU.box(Vector3(0.7, 0.04, 0.7), MU.mat(Color(0.5, 0.7, 0.85, 0.5), 0.1, 0.0, 0.3), Vector3(0.0, RV.ROOF_Y + 0.07, -0.2)))
	v.add_child(MU.cyl(0.01, 0.01, 1.0, dark, Vector3(1.0, RV.ROOF_Y + 0.5, 2.8)))
	# зеркало заднего вида внутри
	v.add_child(MU.box(Vector3(0.28, 0.08, 0.03), dark, Vector3(0.0, 3.2, 3.2)))
	# лебёдки: барабан с тросом и клеммой у бамперов
	for i in 2:
		var hp: Vector3 = RV.HOOKS[i]
		var sign := 1.0 if i == 0 else -1.0
		v.add_child(MU.box(Vector3(0.6, 0.3, 0.26), A3.tmat("steel", Color(0.45, 0.1, 0.08), 0.6, 0.5, 0.4), hp))
		v.add_child(MU.cyl(0.1, 0.1, 0.5, _steel(), hp + Vector3(0, 0, sign * 0.02), Vector3(0, 0, 90), 12))
		v.add_child(MU.box(Vector3(0.1, 0.08, 0.14), MU.mat(Color(0.1, 0.1, 0.1), 0.6), hp + Vector3(0, -0.13, sign * 0.15)))


# ======================================================================= СИДЕНЬЯ
static func car_seat(v: Node3D, x: float, z: float) -> void:
	var fab := A3.tmat("leather", Color(1.6, 1.2, 1.0), 0.4, 0.6)
	var dk := A3.tmat("rubber", Color(0.55, 0.55, 0.55), 0.4, 0.8)
	var y := 1.5
	# подушка (с валиками), спинка, подголовник, подлокотник, тумба-основание
	v.add_child(MU.box(Vector3(0.52, 0.12, 0.52), fab, Vector3(x, y, z)))
	for e in [-1, 1]:
		v.add_child(MU.box(Vector3(0.07, 0.17, 0.5), fab, Vector3(x + e * 0.25, y + 0.03, z)))
		v.add_child(MU.box(Vector3(0.07, 0.5, 0.15), fab, Vector3(x + e * 0.26, y + 0.35, z - 0.28), Vector3(-10, 0, 0)))
	v.add_child(MU.box(Vector3(0.52, 0.72, 0.13), fab, Vector3(x, y + 0.42, z - 0.3), Vector3(-10, 0, 0)))
	v.add_child(MU.box(Vector3(0.3, 0.2, 0.1), fab, Vector3(x, y + 0.88, z - 0.34), Vector3(-10, 0, 0)))
	v.add_child(MU.box(Vector3(0.36, 0.28, 0.4), dk, Vector3(x, y - 0.22, z)))
	v.add_child(MU.cyl(0.16, 0.2, 0.06, dk, Vector3(x, 1.1, z), Vector3.ZERO, 10))


# ======================================================================= САЛОН
static func interior(rv: RV, v: Node3D) -> void:
	var cream := _cream()
	var wood := _wood()
	var dark := A3.tmat("rubber", Color(0.4, 0.4, 0.42), 0.6, 0.8)
	var steel := _steel()
	var rz := RV.REAR_Z
	# обшивка стен: деревянная панель до окон (кроме кабины и дверного проёма)
	for e in [-1, 1]:
		var zr: Array = [[1.75, rz + 0.1]] if e > 0 else [[0.28, rz + 0.1], [3.1, 1.32]]
		if e > 0:
			zr = [[1.75, rz + 0.1]]
		else:
			zr = [[0.28, rz + 0.1], [3.1, 1.32]]
		for r in zr:
			var z0: float = r[0]
			var z1: float = r[1]
			v.add_child(MU.box(Vector3(0.025, 0.9, absf(z0 - z1)), wood, Vector3(e * 1.085, F + 0.45, (z0 + z1) * 0.5)))
	# потолок
	v.add_child(MU.box(Vector3(2.2, 0.03, 9.9), cream, Vector3(0, RV.ROOF_Y - 0.07, -1.7)))
	# ---- кабина: кресла, консоль
	car_seat(v, 0.55, 2.25)
	car_seat(v, -0.55, 2.25)
	# ---- левая стена: шкаф-сушилка, кресла, диван, стеллаж
	rv._part(v, Vector3(0.55, 2.0 + RV.H_UP, 0.9), Vector3(0.85, 2.05 + RV.H_UP * 0.5, 0.75), A3.tmat("wood", Color(1.0, 0.8, 0.62), 0.8, 0.7))
	for dz in [-0.2, 0.2]:
		v.add_child(MU.box(Vector3(0.02, 2.1, 0.02), dark, Vector3(0.575, 2.05, 0.75 + dz)))
	v.add_child(MU.box(Vector3(0.04, 0.2, 0.04), steel, Vector3(0.57, 2.1, 0.62)))
	rv.add_child(MU.area_box(Vector3(0.7, 1.6, 1.0), Vector3(0.62, 2.0, 0.75), "rv_wardrobe", "St_wardrobe"))
	# кресла (Poly Haven modern_arm_chair_01), смотрят в салон (−X)
	for cz in [-0.5, -1.55]:
		put_model(v, "modern_arm_chair_01", Vector3(0.62, F, cz), -90.0, 0.95)
		rv._shape(Vector3(0.65, 0.6, 0.7), Vector3(0.62, F + 0.3, cz))
	# диван (Poly Haven sofa_02)
	put_model(v, "sofa_02", Vector3(0.68, F, -3.2), -90.0, -1.0, 1.8)
	rv._shape(Vector3(0.8, 0.5, 1.8), Vector3(0.68, F + 0.25, -3.2))
	# стол-журнальный между диваном и кухней: без коллизии, чтобы не мешать проходу
	var tb := put_model(v, "small_wooden_table_01", Vector3(0.0, F, -3.2), 90.0, 0.62)
	# ковёр
	v.add_child(MU.box(Vector3(1.4, 0.012, 2.4), _fabric(Color(0.85, 0.45, 0.35)), Vector3(0.0, F + 0.01, -2.0)))
	# стеллаж у левой стены (хранение): каркас, 3 полки, ящики
	rv.shelf_pos = Vector3(0.82, F, -4.95)
	_shelving(rv, v, rv.shelf_pos)
	# ---- правая стена: печь, кухня, холодильник, шкафчик
	var stove := put_model(v, "barrel_stove", Vector3(-0.66, F, -0.85), 0.0, 0.95)
	rv._shape(Vector3(0.6, 0.95, 0.6), Vector3(-0.66, F + 0.47, -0.85))
	v.add_child(MU.cyl(0.055, 0.055, RV.ROOF_Y - F - 0.95, A3.tmat("steel", Color(0.25, 0.25, 0.27), 0.5, 0.7, 0.6), Vector3(-0.66, F + 0.95 + (RV.ROOF_Y - F - 0.95) * 0.5, -0.85), Vector3.ZERO, 10))
	v.add_child(MU.cyl(0.1, 0.1, 0.05, steel, Vector3(-0.66, RV.ROOF_Y + 0.05, -0.85), Vector3.ZERO, 10))
	v.add_child(MU.cyl(0.28, 0.28, 0.03, A3.tmat("steel", Color(0.35, 0.35, 0.38), 0.5, 0.6, 0.6), Vector3(-0.66, F + 0.95, -0.85), Vector3.ZERO, 16))
	v.add_child(MU.box(Vector3(0.03, 0.12, 0.2), MU.mat(Color(1.0, 0.5, 0.15), 0.4, 1.2), Vector3(-0.38, F + 0.45, -0.85)))
	rv.add_child(MU.area_box(Vector3(0.8, 1.0, 0.8), Vector3(-0.66, F + 0.5, -0.85), "rv_stove", "St_stove"))
	rv.stove_light = OmniLight3D.new()
	rv.stove_light.position = Vector3(-0.66, F + 0.6, -0.85)
	rv.stove_light.light_color = Color(1.0, 0.55, 0.2)
	rv.stove_light.omni_range = 4.0
	rv.stove_light.light_energy = 1.2
	rv.stove_light.visible = false
	rv.add_child(rv.stove_light)
	rv.stove_fx = rv._particles(Color(1.0, 0.5, 0.1, 0.8), Vector3(-0.66, F + 1.0, -0.85), 0.012)
	rv.stove_fx.gravity = Vector3(0, 1.5, 0)
	rv.stove_fx.direction = Vector3(0, 1, 0)
	rv.stove_fx.amount = 10
	rv.stove_fx.lifetime = 0.6
	# кухонная тумба с раковиной и верхние шкафы
	rv._part(v, Vector3(0.6, 0.9, 1.5), Vector3(-0.82, F + 0.45, -2.95), A3.tmat("wood", Color(1.3, 1.1, 0.9), 0.7, 0.7))
	v.add_child(MU.box(Vector3(0.64, 0.04, 1.54), _wood(Color(1.5, 1.3, 1.1)), Vector3(-0.82, F + 0.92, -2.95)))
	v.add_child(MU.box(Vector3(0.4, 0.06, 0.5), A3.tmat("steel", Color(0.5, 0.52, 0.56), 0.5, 0.3, 0.8), Vector3(-0.82, F + 0.93, -3.2)))
	v.add_child(MU.cyl(0.015, 0.015, 0.25, steel, Vector3(-1.0, F + 1.05, -3.2), Vector3.ZERO, 8))
	v.add_child(MU.box(Vector3(0.3, 0.012, 0.012), steel, Vector3(-0.9, F + 1.17, -3.2)))
	for dz in [-0.5, 0.0, 0.5]:
		v.add_child(MU.box(Vector3(0.02, 0.1, 0.02), dark, Vector3(-0.51, F + 0.7, -2.95 + dz - 0.2)))
	rv._part(v, Vector3(0.32, 0.6, 1.5), Vector3(-0.95, RV.ROOF_Y - 0.5, -2.95), A3.tmat("wood", Color(1.3, 1.1, 0.9), 0.7, 0.7))
	# холодильник (хранение, замедляет порчу)
	var fz := -4.2
	rv.fridge_pos = Vector3(-0.8, F, fz)
	rv._part(v, Vector3(0.62, 1.7, 0.66), Vector3(-0.8, F + 0.85, fz), A3.tmat("plastic", Color(0.97, 0.97, 1.0), 1.0, 0.35))
	v.add_child(MU.box(Vector3(0.02, 1.0, 0.64), A3.tmat("plastic", Color(0.92, 0.92, 0.96), 1.0, 0.3), Vector3(-0.49, F + 0.5, fz)))
	v.add_child(MU.box(Vector3(0.02, 0.62, 0.64), A3.tmat("plastic", Color(0.92, 0.92, 0.96), 1.0, 0.3), Vector3(-0.49, F + 1.38, fz)))
	v.add_child(MU.box(Vector3(0.015, 0.012, 0.64), dark, Vector3(-0.485, F + 1.08, fz)))
	for hy in [0.68, 1.55]:
		v.add_child(MU.box(Vector3(0.04, 0.3, 0.03), steel, Vector3(-0.47, F + hy, fz + 0.26)))
	v.add_child(MU.cyl(0.015, 0.015, 0.012, MU.mat(Color(0.2, 1.0, 0.3), 0.3, 2.0), Vector3(-0.485, F + 1.62, fz - 0.2), Vector3(0, 0, 90), 6))
	rv.add_child(MU.area_box(Vector3(0.5, 1.8, 0.8), Vector3(-0.62, F + 0.9, fz), "rv_fridge", "St_fridge"))
	# шкафчик для склада у правой стены (Poly Haven painted_wooden_cabinet)
	rv.locker_pos = Vector3(-0.8, F, -5.25)
	put_model(v, "painted_wooden_cabinet", Vector3(-0.82, F, -5.25), 90.0, 1.0)
	rv._shape(Vector3(0.55, 1.0, 0.95), Vector3(-0.82, F + 0.5, -5.25))
	rv.add_child(MU.area_box(Vector3(0.6, 1.1, 1.0), Vector3(-0.7, F + 0.55, -5.25), "rv_locker", "St_locker"))
	# ---- хвост: широкая кровать
	var bz := rz + 0.75
	v.add_child(MU.box(Vector3(2.2, 0.4, 1.3), wood, Vector3(0, F + 0.2, bz)))
	rv._shape(Vector3(2.2, 0.45, 1.3), Vector3(0, F + 0.22, bz))
	v.add_child(MU.box(Vector3(2.1, 0.17, 1.25), _fabric(Color(0.72, 0.78, 0.9)), Vector3(0, F + 0.49, bz)))
	v.add_child(MU.box(Vector3(2.1, 0.03, 0.65), _fabric(Color(0.5, 0.2, 0.2)), Vector3(0, F + 0.59, bz + 0.3)))
	for px in [-0.55, 0.55]:
		v.add_child(MU.box(Vector3(0.7, 0.12, 0.38), _fabric(Color(0.95, 0.95, 0.98)), Vector3(px, F + 0.62, bz - 0.4)))
	# верхняя полка-антресоль над кроватью
	v.add_child(MU.box(Vector3(2.1, 0.08, 0.8), wood, Vector3(0, RV.ROOF_Y - 0.9, rz + 0.55)))
	# заполняющий свет салона (имитация отражённого света), без теней
	for lz in [1.0, -2.0, -5.0]:
		var fl := OmniLight3D.new()
		fl.position = Vector3(0, RV.ROOF_Y - 0.4, lz)
		fl.light_color = Color(1.0, 0.93, 0.8)
		fl.omni_range = 5.0
		fl.light_energy = 0.9
		rv.add_child(fl)
	# лампа под потолком
	v.add_child(MU.cyl(0.14, 0.14, 0.05, MU.mat(Color(1.0, 0.92, 0.7), 0.3, 1.5), Vector3(0, RV.ROOF_Y - 0.1, -0.5 - RV.EXT * 0.5), Vector3.ZERO, 14))
	# разделочный стол и топливная горловина — снаружи
	v.add_child(MU.box(Vector3(0.7, 0.06, 1.3), wood, Vector3(1.6, 1.05, -2.3)))
	rv.add_child(MU.area_box(Vector3(0.9, 0.8, 1.4), Vector3(1.6, 1.2, -2.3), "rv_butcher", "St_butcher"))
	v.add_child(MU.cyl(0.08, 0.08, 0.05, steel, Vector3(1.22, 1.2, -0.6), Vector3(0, 0, 90)))
	rv.add_child(MU.area_box(Vector3(0.5, 0.6, 0.6), Vector3(1.4, 1.2, -0.6), "rv_fuel", "St_fuel"))
	rv.add_child(MU.area_box(Vector3(1.8, 0.6, 1.0), Vector3(0, 1.6, 3.85), "rv_engine", "St_engine"))
	rv.add_child(MU.area_box(Vector3(0.5, 1.0, 3.0), Vector3(1.35, 2.0, -3.9), "rv_body", "St_body"))
	# табуреты у стола (место 4 и 5)
	for zi in [-2.3, -4.1]:
		var leg := _wood(Color(0.55, 0.38, 0.24))
		for lx in [-0.14, 0.14]:
			for lz in [-0.14, 0.14]:
				v.add_child(MU.cyl(0.022, 0.026, 0.42, leg, Vector3(-0.05 + lx, F + 0.21, zi + lz), Vector3(lx * 40.0, 0, -lz * 40.0) * 0.0, 8))
		v.add_child(MU.cyl(0.21, 0.21, 0.05, leg, Vector3(-0.05, F + 0.44, zi), Vector3.ZERO, 16))
		v.add_child(MU.cyl(0.2, 0.2, 0.06, A3.tmat("leather", Color(1.6, 0.9, 0.6), 0.5, 0.6), Vector3(-0.05, F + 0.49, zi), Vector3.ZERO, 16))
	# бардачок у пассажира: крышка с ручкой, внутри — карта
	v.add_child(MU.box(Vector3(0.42, 0.2, 0.03), A3.tmat("plastic", Color(0.25, 0.25, 0.27), 1.0, 0.6), Vector3(-0.55, 1.83, 3.02), Vector3(-25, 0, 0)))
	v.add_child(MU.box(Vector3(0.1, 0.025, 0.02), MU.mat(Color(0.6, 0.6, 0.62), 0.3, 0.0, 0.8), Vector3(-0.55, 1.9, 3.0), Vector3(-25, 0, 0)))
	rv.add_child(MU.area_box(Vector3(0.5, 0.3, 0.3), Vector3(-0.55, 1.85, 2.95), "rv_glovebox", "St_glovebox"))
	# место
	for i in RV.SEAT_COUNT:
		var a := MU.area_box(Vector3(0.6, 0.9, 0.6), RV.SEATS[i][0] + Vector3(0, 0.6, 0), "rv_seat", "St_seat%d" % i)
		a.set_meta("seat", i)
		rv.add_child(a)


## Открытый стеллаж: каркас, полки, ящики и канистра на них. Хранение — «rv_shelf».
static func _shelving(rv: RV, v: Node3D, p: Vector3) -> void:
	var wood := _wood(Color(0.7, 0.55, 0.4))
	var w := 1.35
	for e in [-1, 1]:
		v.add_child(MU.box(Vector3(0.45, 1.9, 0.05), wood, Vector3(p.x - 0.1, p.y + 0.95, p.z + e * (w * 0.5))))
	for i in 4:
		v.add_child(MU.box(Vector3(0.45, 0.04, w), wood, Vector3(p.x - 0.1, p.y + 0.12 + i * 0.58, p.z)))
	rv._shape(Vector3(0.45, 1.9, w), Vector3(p.x - 0.1, p.y + 0.95, p.z))
	# ящики и банки
	put_model(v, "wooden_crate_01", Vector3(p.x - 0.1, p.y + 0.14, p.z - 0.3), 90.0, -1.0, 0.45)
	put_model(v, "metal_toolbox", Vector3(p.x - 0.1, p.y + 0.72, p.z + 0.3), 90.0, -1.0, 0.36)
	put_model(v, "metal_jerrycan", Vector3(p.x - 0.1, p.y + 1.3, p.z - 0.35), 90.0, 0.4)
	rv.add_child(MU.area_box(Vector3(0.7, 1.9, 1.5), Vector3(p.x - 0.2, p.y + 0.95, p.z), "rv_shelf", "St_shelf"))


# ======================================================================= БАГАЖНИК НА КРЫШЕ
const RACK_SLOTS := [Vector3(-0.5, 0, -0.55), Vector3(0.5, 0, -0.55), Vector3(-0.5, 0, -2.15), Vector3(0.5, 0, -2.15),
	Vector3(-0.5, 0, -3.75), Vector3(0.5, 0, -3.75)]


static func rack(rv: RV, v: Node3D) -> void:
	var steel := _steel()
	var dark := A3.tmat("steel", Color(0.3, 0.3, 0.33), 0.6, 0.5, 0.5)
	var y0: float = RV.ROOF_Y + 0.05
	var z0 := 0.4
	var z1 := -4.7
	var zc := (z0 + z1) * 0.5
	var zl := z0 - z1
	# настил-решётка
	for i in 13:
		v.add_child(MU.box(Vector3(2.0, 0.03, 0.06), dark, Vector3(0, y0, z0 - 0.2 - i * (zl - 0.4) / 12.0)))
	# бортики и стойки (невысокие: груз может вылететь на кочках)
	for e in [-1, 1]:
		v.add_child(MU.box(Vector3(0.04, 0.04, zl), steel, Vector3(e * 1.0, y0 + 0.22, zc)))
		v.add_child(MU.box(Vector3(0.03, 0.03, zl), steel, Vector3(e * 1.0, y0 + 0.1, zc)))
		for i in 6:
			v.add_child(MU.box(Vector3(0.04, 0.22, 0.04), steel, Vector3(e * 1.0, y0 + 0.11, z0 - i * zl / 5.0)))
		rv._shape(Vector3(0.06, 0.22, zl), Vector3(e * 1.0, y0 + 0.12, zc))
	for zz in [z0, z1]:
		v.add_child(MU.box(Vector3(2.0, 0.04, 0.04), steel, Vector3(0, y0 + 0.22, zz)))
		rv._shape(Vector3(2.0, 0.22, 0.06), Vector3(0, y0 + 0.12, zz))
	# метки мест
	for s in RACK_SLOTS:
		v.add_child(MU.box(Vector3(0.7, 0.012, 1.3), MU.mat(Color(0.95, 0.75, 0.1, 0.55), 0.8), Vector3(s.x, y0 + 0.025, s.z)))
	rv.add_child(MU.area_box(Vector3(2.2, 0.5, zl), Vector3(0, y0 + 0.3, zc), "rv_rack", "St_rack"))


# ======================================================================= КОЛЁСА
## Визуал колеса: покрышка с протектором, диск, гайки. Возвращает словарь частей.
static func wheel_visual(w: Node3D) -> Dictionary:
	var tire := MU.cyl(0.5, 0.5, 0.36, _rubber(), Vector3.ZERO, Vector3(0, 0, 90), 24)
	w.add_child(tire)
	for i in 3:
		w.add_child(MU.cyl(0.505, 0.505, 0.07, MU.mat(Color(0.03, 0.03, 0.03), 1.0), Vector3(-0.1 + i * 0.1, 0, 0), Vector3(0, 0, 90), 24))
	var rim := Node3D.new()
	w.add_child(rim)
	var steel_m := MU.mat(Color(0.7, 0.72, 0.75), 0.3, 0.0, 0.8)
	rim.add_child(MU.cyl(0.3, 0.3, 0.38, steel_m, Vector3.ZERO, Vector3(0, 0, 90), 20))
	rim.add_child(MU.cyl(0.1, 0.1, 0.4, MU.mat(Color(0.2, 0.2, 0.22), 0.4, 0.0, 0.7), Vector3.ZERO, Vector3(0, 0, 90), 10))
	for i in 5:
		var a := TAU * float(i) / 5.0
		rim.add_child(MU.cyl(0.025, 0.025, 0.41, MU.mat(Color(0.35, 0.35, 0.38), 0.3, 0.0, 0.9), Vector3(0, sin(a) * 0.18, cos(a) * 0.18), Vector3(0, 0, 90), 6))
	return {"tire": tire, "rim": rim}
