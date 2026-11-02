class_name ItemsDB
extends RefCounted
## Данные игры: предметы, оружие, патроны, животные, магазин.
## Все числа баланса — здесь.

# ---------------------------------------------------------------- Предметы
# mass — кг, price — цена продажи, carry — жёсткость «пружины» при переносе
# (меньше = болтается сильнее), use — что делает F.
const ITEMS := {
	"carcass_rabbit": {"mass": 3.0, "price": 35, "size": Vector3(0.35, 0.25, 0.55), "carry": 9.0, "hold": 1.4},
	"carcass_deer": {"mass": 65.0, "price": 140, "size": Vector3(0.55, 0.55, 1.5), "carry": 3.5, "hold": 1.9, "big": true},
	"carcass_boar": {"mass": 90.0, "price": 170, "size": Vector3(0.6, 0.6, 1.3), "carry": 3.0, "hold": 1.9, "big": true},
	"carcass_bear": {"mass": 220.0, "price": 520, "size": Vector3(1.0, 0.9, 2.0), "carry": 1.6, "hold": 2.3, "big": true},
	"meat_raw": {"mass": 2.0, "price": 22, "size": Vector3(0.34, 0.12, 0.26), "carry": 10.0, "use": "eat"},
	"meat_cooked": {"mass": 1.8, "price": 34, "size": Vector3(0.32, 0.12, 0.24), "carry": 10.0, "use": "eat"},
	"meat_burnt": {"mass": 1.5, "price": 2, "size": Vector3(0.3, 0.12, 0.22), "carry": 10.0, "use": "eat"},
	"hide": {"mass": 6.0, "price": 45, "size": Vector3(0.9, 0.06, 0.7), "carry": 7.0},
	"hide_bear": {"mass": 15.0, "price": 160, "size": Vector3(1.4, 0.08, 1.1), "carry": 6.0},
	"rabbit_foot": {"mass": 0.2, "price": 15, "size": Vector3(0.08, 0.08, 0.16), "carry": 10.0},
	"water_bottle": {"mass": 1.0, "price": 2, "size": Vector3(0.16, 0.32, 0.16), "carry": 10.0, "use": "drink"},
	"canned_food": {"mass": 0.6, "price": 3, "size": Vector3(0.16, 0.18, 0.16), "carry": 10.0, "use": "eat"},
	"jerrycan": {"mass": 18.0, "price": 8, "size": Vector3(0.22, 0.48, 0.38), "carry": 6.0, "use": "fuel", "big": true},
	"repair_kit": {"mass": 8.0, "price": 15, "size": Vector3(0.5, 0.28, 0.25), "carry": 7.0, "use": "repair"},
	"spare_wheel": {"mass": 28.0, "price": 30, "size": Vector3(1.0, 0.36, 1.0), "carry": 3.0, "hold": 1.8, "big": true},
	"wheel_flat": {"mass": 24.0, "price": 2, "size": Vector3(1.0, 0.36, 1.0), "carry": 3.0, "hold": 1.8, "big": true},
	"jack": {"mass": 7.0, "price": 20, "size": Vector3(0.4, 0.26, 0.26), "carry": 7.0, "use": "tool"},
	"bandage": {"mass": 0.2, "price": 3, "size": Vector3(0.12, 0.08, 0.12), "carry": 10.0, "use": "bandage"},
	"cigarettes": {"mass": 0.1, "price": 2, "size": Vector3(0.09, 0.03, 0.06), "carry": 10.0, "use": "smoke"},
	"beer": {"mass": 0.6, "price": 2, "size": Vector3(0.08, 0.24, 0.08), "carry": 10.0, "use": "booze"},
	"vodka": {"mass": 0.8, "price": 4, "size": Vector3(0.09, 0.3, 0.09), "carry": 10.0, "use": "booze"},
	"poo": {"mass": 0.4, "price": 0, "size": Vector3(0.2, 0.1, 0.2), "carry": 10.0},
	"firewood": {"mass": 6.0, "price": 4, "size": Vector3(0.7, 0.25, 0.25), "carry": 7.0},
	# оружие тоже лежит в рюкзаке и занимает ячейку
	"weapon_toz": {"mass": 2.8, "price": 60, "size": Vector3(0.08, 0.16, 1.0), "carry": 9.0, "use": "equip", "weapon": "toz"},
	"weapon_double": {"mass": 3.4, "price": 90, "size": Vector3(0.1, 0.16, 1.05), "carry": 9.0, "use": "equip", "weapon": "double"},
	"weapon_carbine": {"mass": 3.6, "price": 150, "size": Vector3(0.1, 0.2, 1.1), "carry": 9.0, "use": "equip", "weapon": "carbine"},
	"weapon_magnum": {"mass": 4.8, "price": 380, "size": Vector3(0.1, 0.2, 1.3), "carry": 9.0, "use": "equip", "weapon": "magnum"},
}

# Скоропортящееся: сколько секунд до порчи (в холодильнике время идёт медленнее)
const PERISHABLE := {"meat_raw": 420.0, "meat_cooked": 900.0}


## 0 — свежее, 1 — несвежее, 2 — тухлое.
static func freshness(kind: String, age: float) -> int:
	if not PERISHABLE.has(kind):
		return 0
	var lim: float = PERISHABLE[kind]
	if age >= lim:
		return 2
	return 1 if age >= lim * 0.6 else 0


# Еда: hunger, thirst, bladder, warmth, шанс отравления
const FOOD := {
	"canned_food": {"hunger": 35.0, "thirst": -3.0},
	"meat_cooked": {"hunger": 45.0, "warmth": 10.0},
	"meat_burnt": {"hunger": 12.0, "thirst": -8.0},
	"meat_raw": {"hunger": 15.0, "poison": 0.45},
	"water_bottle": {"thirst": 50.0, "bladder": 14.0},
	"beer": {"thirst": 25.0, "bladder": 25.0, "drunk": 18.0},
	"vodka": {"thirst": -10.0, "warmth": 20.0, "drunk": 38.0},
}

# ---------------------------------------------------------------- Боеприпасы
# pen — пробитие, dmg — урон одной пули/дробины, speed — м/с, pellets — дробь.
const AMMO := {
	"22lr": {"pen": 1.0, "dmg": 28.0, "speed": 330.0, "pellets": 1, "spread": 0.3, "drag": 0.0025},
	"12shot": {"pen": 1.0, "dmg": 11.0, "speed": 400.0, "pellets": 9, "spread": 2.6, "drag": 0.012},
	"12slug": {"pen": 3.0, "dmg": 95.0, "speed": 450.0, "pellets": 1, "spread": 0.6, "drag": 0.004},
	"308": {"pen": 4.5, "dmg": 120.0, "speed": 820.0, "pellets": 1, "spread": 0.12, "drag": 0.0012},
	"338": {"pen": 7.0, "dmg": 260.0, "speed": 900.0, "pellets": 1, "spread": 0.08, "drag": 0.0009},
}

# ---------------------------------------------------------------- Оружие
const WEAPONS := {
	"toz": {"ammo": ["22lr"], "mag": 5, "rof": 0.45, "reload": 2.2, "recoil": 0.6, "zoom": 50.0, "kick": 0.3, "snd": "shot_small"},
	"double": {"ammo": ["12shot", "12slug"], "mag": 2, "rof": 0.25, "reload": 2.6, "recoil": 3.5, "zoom": 60.0, "kick": 2.5, "snd": "shot_shotgun"},
	"carbine": {"ammo": ["308"], "mag": 5, "rof": 1.1, "reload": 2.8, "recoil": 2.5, "zoom": 25.0, "kick": 1.2, "snd": "shot_rifle"},
	"magnum": {"ammo": ["338"], "mag": 5, "rof": 1.6, "reload": 3.4, "recoil": 5.0, "zoom": 14.0, "kick": 4.5, "snd": "shot_big"},
}
const WEAPON_ORDER := ["toz", "double", "carbine", "magnum"]

# ---------------------------------------------------------------- Животные
# armor — сколько «пробития» нужно, чтобы пуля прошла. Меньше — почти без урона.
const ANIMALS := {
	"rabbit": {"hp": 14.0, "armor": 0.0, "walk": 1.4, "run": 9.0, "scare": 14.0, "size": Vector3(0.3, 0.32, 0.5), "count": 18},
	"deer": {"hp": 85.0, "armor": 1.5, "walk": 1.8, "run": 11.0, "scare": 30.0, "size": Vector3(0.55, 1.3, 1.6), "count": 20},
	"boar": {"hp": 140.0, "armor": 2.5, "walk": 1.5, "run": 8.0, "scare": 0.0, "aggro": 13.0, "dmg": 22.0, "size": Vector3(0.65, 0.85, 1.4), "count": 10},
	"bear": {"hp": 380.0, "armor": 4.0, "walk": 1.4, "run": 9.5, "scare": 0.0, "aggro": 22.0, "dmg": 45.0, "size": Vector3(1.1, 1.4, 2.1), "count": 4},
}

# Что получается при разделке: [вид, количество]
const BUTCHER := {
	"carcass_rabbit": [["meat_raw", 1], ["rabbit_foot", 1]],
	"carcass_deer": [["meat_raw", 3], ["hide", 1]],
	"carcass_boar": [["meat_raw", 4], ["hide", 1]],
	"carcass_bear": [["meat_raw", 7], ["hide_bear", 1]],
}

# ---------------------------------------------------------------- Магазин
const SHOP := [
	{"key": "water_bottle", "type": "item", "price": 5},
	{"key": "canned_food", "type": "item", "price": 8},
	{"key": "firewood", "type": "item", "price": 6},
	{"key": "bandage", "type": "item", "price": 10},
	{"key": "cigarettes", "type": "item", "price": 7, "q": 10.0},
	{"key": "beer", "type": "item", "price": 4},
	{"key": "vodka", "type": "item", "price": 12},
	{"key": "jerrycan", "type": "item", "price": 25},
	{"key": "repair_kit", "type": "item", "price": 45},
	{"key": "jack", "type": "item", "price": 60},
	{"key": "spare_wheel", "type": "item", "price": 90},
	{"key": "ammo_22lr", "type": "ammo", "ammo": "22lr", "amount": 20, "price": 10},
	{"key": "ammo_12shot", "type": "ammo", "ammo": "12shot", "amount": 10, "price": 12},
	{"key": "ammo_12slug", "type": "ammo", "ammo": "12slug", "amount": 10, "price": 18},
	{"key": "ammo_308", "type": "ammo", "ammo": "308", "amount": 10, "price": 30},
	{"key": "ammo_338", "type": "ammo", "ammo": "338", "amount": 5, "price": 45},
	{"key": "weapon_carbine", "type": "weapon", "weapon": "carbine", "price": 300},
	{"key": "weapon_magnum", "type": "weapon", "weapon": "magnum", "price": 750},
	{"key": "up_engine", "type": "upgrade", "up": "engine", "prices": [250, 500]},
	{"key": "up_tank", "type": "upgrade", "up": "tank", "prices": [150, 300]},
	{"key": "up_armor", "type": "upgrade", "up": "armor", "prices": [200, 400]},
	{"key": "up_heater", "type": "upgrade", "up": "heater", "prices": [180]},
]

const FUEL_PRICE := 1.5


static func item_name(kind: String) -> String:
	return T.t("item_" + kind)


## Визуальная модель предмета (примитивы-заглушки, легко заменить на модели).
static func build_visual(kind: String) -> Node3D:
	var v := Node3D.new()
	v.name = "Vis"
	var s: Vector3 = ITEMS[kind].size
	match kind:
		"carcass_rabbit":
			v.add_child(MU.capsule(0.13, 0.5, Color(0.55, 0.5, 0.45), Vector3.ZERO, Vector3(90, 0, 0)))
			v.add_child(MU.sphere(0.1, Color(0.5, 0.45, 0.4), Vector3(0, 0.03, -0.27)))
			v.add_child(MU.box(Vector3(0.04, 0.2, 0.06), Color(0.55, 0.48, 0.42), Vector3(0.04, 0.0, -0.4), Vector3(-70, 0, 10)))
			v.add_child(MU.box(Vector3(0.04, 0.2, 0.06), Color(0.55, 0.48, 0.42), Vector3(-0.04, 0.0, -0.4), Vector3(-70, 0, -10)))
			for p in [Vector3(0.08, 0.14, -0.12), Vector3(-0.08, 0.14, -0.12), Vector3(0.08, 0.14, 0.15), Vector3(-0.08, 0.14, 0.15)]:
				v.add_child(MU.box(Vector3(0.04, 0.16, 0.04), Color(0.5, 0.45, 0.4), p))
		"carcass_deer", "carcass_boar", "carcass_bear":
			var col := Color(0.45, 0.3, 0.18)
			var leg := 0.5
			if kind == "carcass_boar":
				col = Color(0.22, 0.17, 0.13)
				leg = 0.35
			elif kind == "carcass_bear":
				col = Color(0.2, 0.13, 0.08)
				leg = 0.45
			# туша лежит на спине — ноги вверх
			v.add_child(MU.capsule(s.x * 0.5, s.z, col, Vector3.ZERO, Vector3(90, 0, 0)))
			v.add_child(MU.sphere(s.x * 0.42, col.darkened(0.1), Vector3(0, 0.0, -s.z * 0.55), Vector3(0.9, 0.8, 1.3)))
			for lp in [Vector3(0.18, 0, -0.45), Vector3(-0.18, 0, -0.45), Vector3(0.18, 0, 0.45), Vector3(-0.18, 0, 0.45)]:
				var p: Vector3 = lp * Vector3(s.x / 0.55, 1, s.z / 1.5)
				v.add_child(MU.box(Vector3(0.08, leg, 0.08), col.darkened(0.2), p + Vector3(0, s.y * 0.35 + leg * 0.4, 0), Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))))
			if kind == "carcass_deer":
				v.add_child(MU.cyl(0.02, 0.03, 0.4, Color(0.85, 0.8, 0.65), Vector3(0.12, 0.1, -s.z * 0.7), Vector3(-60, 0, 30)))
				v.add_child(MU.cyl(0.02, 0.03, 0.4, Color(0.85, 0.8, 0.65), Vector3(-0.12, 0.1, -s.z * 0.7), Vector3(-60, 0, -30)))
			if kind == "carcass_boar":
				v.add_child(MU.cyl(0.0, 0.025, 0.14, Color(0.95, 0.92, 0.8), Vector3(0.07, -0.05, -s.z * 0.78), Vector3(-80, 0, 0)))
				v.add_child(MU.cyl(0.0, 0.025, 0.14, Color(0.95, 0.92, 0.8), Vector3(-0.07, -0.05, -s.z * 0.78), Vector3(-80, 0, 0)))
		"meat_raw":
			v.add_child(MU.box(s, Color(0.7, 0.15, 0.15)))
			v.add_child(MU.box(Vector3(s.x, s.y * 0.3, s.z * 0.25), Color(0.95, 0.9, 0.85), Vector3(0, s.y * 0.38, s.z * 0.35)))
		"meat_cooked":
			v.add_child(MU.box(s, Color(0.45, 0.25, 0.1)))
			v.add_child(MU.box(Vector3(s.x * 0.9, 0.01, 0.02), Color(0.2, 0.1, 0.05), Vector3(0, s.y * 0.5, 0)))
		"meat_burnt":
			v.add_child(MU.box(s, Color(0.06, 0.05, 0.04)))
		"hide":
			v.add_child(MU.box(s, Color(0.5, 0.35, 0.2)))
		"hide_bear":
			v.add_child(MU.box(s, Color(0.22, 0.14, 0.09)))
		"rabbit_foot":
			v.add_child(MU.capsule(0.04, 0.16, Color(0.9, 0.88, 0.85), Vector3.ZERO, Vector3(90, 0, 0)))
		"water_bottle":
			v.add_child(MU.cyl(0.07, 0.07, 0.26, Color(0.5, 0.75, 0.95, 0.75), Vector3(0, -0.02, 0)))
			v.add_child(MU.cyl(0.03, 0.03, 0.06, Color(0.1, 0.3, 0.8), Vector3(0, 0.14, 0)))
		"canned_food":
			v.add_child(MU.cyl(0.075, 0.075, 0.17, MU.mat(Color(0.75, 0.75, 0.78), 0.3, 0.0, 0.8)))
			v.add_child(MU.cyl(0.077, 0.077, 0.09, Color(0.8, 0.2, 0.1)))
		"jerrycan":
			var jm := A3.model("metal_jerrycan", s.y)
			jm.position.y = -s.y * 0.5
			jm.rotation_degrees.y = 90
			v.add_child(jm)
		"repair_kit":
			var km := A3.model("metal_toolbox", s.y * 1.0, -1.0)
			km.position.y = -s.y * 0.5
			km.scale = Vector3.ONE * 1.1
			v.add_child(km)
		"spare_wheel", "wheel_flat":
			var tire := MU.cyl(0.5, 0.5, 0.36, A3.tmat("rubber", Color(0.5, 0.5, 0.5), 0.5, 0.9), Vector3.ZERO, Vector3.ZERO, 24)
			if kind == "wheel_flat":
				tire.scale = Vector3(1, 0.7, 1)
			v.add_child(tire)
			var rm := A3.model("rusted_wheel_rim_01", -1.0, 0.62)
			rm.rotation_degrees.x = 90
			rm.position.y = 0.19
			v.add_child(rm)
		"jack":
			v.add_child(MU.cyl(0.07, 0.09, 0.2, MU.mat(Color(0.8, 0.1, 0.05), 0.5, 0.0, 0.4), Vector3(0, -0.03, 0), Vector3.ZERO, 10))
			v.add_child(MU.cyl(0.03, 0.03, 0.3, MU.mat(Color(0.7, 0.7, 0.72), 0.3, 0.0, 0.9), Vector3(0, 0.05, 0), Vector3(0, 0, 90), 8))
		"bandage":
			v.add_child(MU.cyl(0.06, 0.06, 0.08, Color(0.95, 0.95, 0.92)))
		"cigarettes":
			v.add_child(MU.box(s, Color(0.85, 0.85, 0.8)))
			v.add_child(MU.box(Vector3(s.x * 1.01, s.y * 1.01, s.z * 0.4), Color(0.7, 0.1, 0.1), Vector3(0, 0, s.z * 0.3)))
		"beer":
			v.add_child(MU.cyl(0.035, 0.04, 0.2, Color(0.35, 0.2, 0.05, 0.85), Vector3(0, -0.02, 0)))
			v.add_child(MU.cyl(0.012, 0.035, 0.06, Color(0.35, 0.2, 0.05, 0.85), Vector3(0, 0.1, 0)))
		"vodka":
			v.add_child(MU.cyl(0.04, 0.04, 0.22, Color(0.85, 0.9, 0.95, 0.6), Vector3(0, -0.03, 0)))
			v.add_child(MU.cyl(0.014, 0.018, 0.08, Color(0.85, 0.1, 0.1), Vector3(0, 0.12, 0)))
		"poo":
			v.add_child(MU.sphere(0.1, Color(0.3, 0.18, 0.08), Vector3(0, -0.02, 0), Vector3(1, 0.5, 1)))
			v.add_child(MU.sphere(0.065, Color(0.3, 0.18, 0.08), Vector3(0, 0.03, 0), Vector3(1, 0.7, 1)))
		"firewood":
			for i in 3:
				v.add_child(MU.cyl(0.07, 0.07, s.x, Color(0.4, 0.27, 0.15), Vector3(0, -0.05 + (i % 2) * 0.1, -0.08 + i * 0.08), Vector3(0, 0, 90), 7))
		"weapon_toz", "weapon_double", "weapon_carbine", "weapon_magnum":
			var g := build_gun(str(ITEMS[kind].weapon))
			g.position.z = 0.3
			v.add_child(g)
		_:
			v.add_child(MU.box(s, Color.MAGENTA))
	return v


## Модель ружья: ствол смотрит в −Z, приклад в +Z, начало координат — у спускового крючка.
## Внутри есть Marker3D «Muzzle» (дульный срез).
static func build_gun(w: String) -> Node3D:
	var g := Node3D.new()
	g.set_meta("w", w)
	var wood := Color(0.36, 0.2, 0.1)
	var steel := MU.mat(Color(0.12, 0.12, 0.13), 0.35, 0.0, 0.8)
	var length := {"toz": 0.85, "double": 0.95, "carbine": 1.0, "magnum": 1.2}.get(w, 0.9) as float
	# приклад и шейка
	g.add_child(MU.box(Vector3(0.05, 0.13, 0.3), wood, Vector3(0, -0.04, 0.2), Vector3(-8, 0, 0)))
	g.add_child(MU.box(Vector3(0.045, 0.06, 0.14), wood, Vector3(0, -0.01, 0.0)))
	# ствольная коробка и цевьё
	g.add_child(MU.box(Vector3(0.05, 0.06, 0.18), steel, Vector3(0, 0.0, -0.12)))
	g.add_child(MU.box(Vector3(0.055, 0.05, 0.28), wood, Vector3(0, -0.02, -0.34)))
	g.add_child(MU.box(Vector3(0.01, 0.04, 0.04), steel, Vector3(0, -0.05, -0.03)))
	if w == "double":
		for e in [-1, 1]:
			g.add_child(MU.cyl(0.02, 0.02, length * 0.72, steel, Vector3(e * 0.021, 0.02, -0.2 - length * 0.36), Vector3(90, 0, 0)))
	else:
		var br := 0.014 if w == "toz" else 0.018
		g.add_child(MU.cyl(br, br, length * 0.72, steel, Vector3(0, 0.02, -0.2 - length * 0.36), Vector3(90, 0, 0)))
	if w == "carbine" or w == "magnum":
		g.add_child(MU.cyl(0.026, 0.026, 0.3, steel, Vector3(0, 0.08, -0.1), Vector3(90, 0, 0)))
		g.add_child(MU.cyl(0.034, 0.034, 0.05, steel, Vector3(0, 0.08, -0.26), Vector3(90, 0, 0)))
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.02, -0.2 - length * 0.72)
	g.add_child(muzzle)
	return g
