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
	"spare_wheel": {"mass": 28.0, "price": 30, "size": Vector3(1.0, 0.36, 1.0), "carry": 3.0, "hold": 1.8, "big": true},
	"wheel_flat": {"mass": 24.0, "price": 2, "size": Vector3(1.0, 0.36, 1.0), "carry": 3.0, "hold": 1.8, "big": true},
	"jack": {"mass": 7.0, "price": 20, "size": Vector3(0.4, 0.26, 0.26), "carry": 7.0, "use": "tool"},
	"bandage": {"mass": 0.2, "price": 3, "size": Vector3(0.12, 0.08, 0.12), "carry": 10.0, "use": "bandage"},
	"cigarettes": {"mass": 0.1, "price": 2, "size": Vector3(0.09, 0.03, 0.06), "carry": 10.0, "use": "smoke"},
	"beer": {"mass": 0.6, "price": 2, "size": Vector3(0.08, 0.24, 0.08), "carry": 10.0, "use": "booze"},
	"vodka": {"mass": 0.8, "price": 4, "size": Vector3(0.09, 0.3, 0.09), "carry": 10.0, "use": "booze"},
	"poo": {"mass": 0.4, "price": 0, "size": Vector3(0.2, 0.1, 0.2), "carry": 10.0},
	"firewood": {"mass": 10.0, "price": 4, "size": Vector3(0.7, 0.25, 0.3), "carry": 7.0, "hold": 1.2},
	# оружие тоже лежит в рюкзаке и занимает ячейку
	"weapon_toz": {"mass": 2.8, "price": 60, "size": Vector3(0.08, 0.16, 1.0), "carry": 9.0, "use": "equip", "weapon": "toz"},
	"weapon_double": {"mass": 3.4, "price": 90, "size": Vector3(0.1, 0.16, 1.05), "carry": 9.0, "use": "equip", "weapon": "double"},
	"weapon_carbine": {"mass": 3.6, "price": 150, "size": Vector3(0.1, 0.2, 1.1), "carry": 9.0, "use": "equip", "weapon": "carbine"},
	"weapon_magnum": {"mass": 4.8, "price": 380, "size": Vector3(0.1, 0.2, 1.3), "carry": 9.0, "use": "equip", "weapon": "magnum"},
	# части туши после разделки на месте (каждая — до ~30 кг, носится в руках)
	"quarter_deer": {"mass": 21.0, "price": 40, "size": Vector3(0.45, 0.3, 0.7), "carry": 5.0, "hold": 1.5},
	"quarter_boar": {"mass": 22.0, "price": 38, "size": Vector3(0.45, 0.32, 0.7), "carry": 5.0, "hold": 1.5},
	"quarter_bear": {"mass": 27.0, "price": 60, "size": Vector3(0.55, 0.38, 0.8), "carry": 4.5, "hold": 1.6},
	"knife": {"mass": 0.3, "price": 6, "size": Vector3(0.04, 0.03, 0.28), "carry": 10.0, "use": "tool"},
	"matches": {"mass": 0.05, "price": 1, "size": Vector3(0.06, 0.02, 0.04), "carry": 10.0, "use": "tool"},
	# инструменты (не тратятся) и расходники для ремонта дома
	"wrench": {"mass": 1.2, "price": 10, "size": Vector3(0.06, 0.03, 0.4), "carry": 9.0, "use": "tool"},
	"hammer": {"mass": 1.5, "price": 8, "size": Vector3(0.12, 0.04, 0.4), "carry": 9.0, "use": "tool"},
	"toolbox": {"mass": 7.5, "price": 20, "size": Vector3(0.5, 0.28, 0.25), "carry": 7.0, "use": "tool"},
	"spare_parts": {"mass": 3.0, "price": 18, "size": Vector3(0.3, 0.2, 0.25), "carry": 8.0, "use": "tool"},
	"duct_tape": {"mass": 0.3, "price": 3, "size": Vector3(0.11, 0.05, 0.11), "carry": 10.0, "use": "tool"},
	"tire_patch": {"mass": 0.8, "price": 6, "size": Vector3(0.2, 0.08, 0.14), "carry": 10.0, "use": "tool"},
	# обвесы на оружие (ставятся на T)
	"att_scope": {"mass": 0.6, "price": 60, "size": Vector3(0.06, 0.08, 0.32), "carry": 10.0, "use": "attach", "slot": "optic"},
	"att_reddot": {"mass": 0.25, "price": 35, "size": Vector3(0.06, 0.07, 0.1), "carry": 10.0, "use": "attach", "slot": "optic"},
	"att_suppressor": {"mass": 0.45, "price": 45, "size": Vector3(0.05, 0.05, 0.2), "carry": 10.0, "use": "attach", "slot": "muzzle"},
	"att_bipod": {"mass": 0.4, "price": 25, "size": Vector3(0.08, 0.05, 0.2), "carry": 10.0, "use": "attach", "slot": "under"},
	# лес: ягоды и грибы (часть ядовитые)
	"berries_blue": {"mass": 0.2, "price": 3, "size": Vector3(0.14, 0.06, 0.14), "carry": 10.0, "use": "eat"},
	"berries_red": {"mass": 0.2, "price": 2, "size": Vector3(0.14, 0.06, 0.14), "carry": 10.0, "use": "eat"},
	"berries_wolf": {"mass": 0.2, "price": 0, "size": Vector3(0.14, 0.06, 0.14), "carry": 10.0, "use": "eat"},
	"mushroom_cep": {"mass": 0.3, "price": 4, "size": Vector3(0.14, 0.16, 0.14), "carry": 10.0, "use": "eat"},
	"mushroom_chanterelle": {"mass": 0.15, "price": 3, "size": Vector3(0.12, 0.08, 0.12), "carry": 10.0, "use": "eat"},
	"mushroom_amanita": {"mass": 0.25, "price": 0, "size": Vector3(0.16, 0.18, 0.16), "carry": 10.0, "use": "eat"},
	"mushroom_toadstool": {"mass": 0.2, "price": 0, "size": Vector3(0.12, 0.16, 0.12), "carry": 10.0, "use": "eat"},
	"mushrooms_fried": {"mass": 0.4, "price": 8, "size": Vector3(0.16, 0.06, 0.16), "carry": 10.0, "use": "eat"},
}

# Тяжёлое (от HEAVY_KG) — только в руках; больше LIFT_KG один человек не поднимет.
const HEAVY_KG := 10.0
const LIFT_KG := 50.0


static func is_heavy(kind: String) -> bool:
	var d: Dictionary = ITEMS.get(kind, {})
	return float(d.get("mass", 0.0)) >= HEAVY_KG and not d.has("weapon")


## Сколько человек нужно, чтобы поднять предмет.
static func lifters_needed(kind: String) -> int:
	return maxi(1, int(ceil(float(ITEMS[kind].mass) / LIFT_KG)))


# Разделка туши на месте (ножом): на какие части распадается
const FIELD_CUT := {
	"carcass_deer": [["quarter_deer", 3]],
	"carcass_boar": [["quarter_boar", 4]],
	"carcass_bear": [["quarter_bear", 8]],
}
const FIELD_CUT_TIME := {"carcass_deer": 6.0, "carcass_boar": 7.0, "carcass_bear": 12.0}

# Обвесы: куда ставятся, на какое оружие и что дают.
# zoom — FOV при прицеливании, recoil — множитель отдачи, loud — множитель громкости/испуга.
const ATTACH := {
	"att_scope": {"slot": "optic", "fits": ["toz", "carbine", "magnum"], "zoom": 9.0, "mode": "scope"},
	"att_reddot": {"slot": "optic", "fits": ["toz", "double", "carbine", "magnum"], "zoom": 38.0, "mode": "dot"},
	"att_suppressor": {"slot": "muzzle", "fits": ["toz", "carbine", "magnum"], "loud": 0.35, "speed": 0.95},
	"att_bipod": {"slot": "under", "fits": ["carbine", "magnum"], "recoil": 0.45},
}
const ATTACH_SLOTS := ["optic", "muzzle", "under"]

# Ремонт: что нужно для каждой части. tool — инструмент (не тратится),
# use — расходник (тратится по ходу работы, полный — на use_s секунд), cap — до скольки % чинит.
const REPAIRS := {
	"engine": {"tool": "toolbox", "use": "spare_parts", "use_s": 8.0, "rate": 9.0, "cap": 100.0},
	"body": {"tool": "hammer", "use": "", "rate": 5.0, "cap": 85.0},
	"tank_tape": {"tool": "", "use": "duct_tape", "use_s": 4.0, "rate": 15.0, "cap": 60.0},
	"tank": {"tool": "toolbox", "use": "spare_parts", "use_s": 6.0, "rate": 10.0, "cap": 100.0},
	"wheel": {"tool": "", "use": "tire_patch", "use_s": 5.0, "rate": 14.0, "cap": 100.0},
}

# Наезд: урон зверю/человеку = v² · k (м/с), урону дома — энергия удара / RV_HIT_ENERGY.
const HIT_FLESH_K := 0.6
const HIT_PLAYER_K := 0.75
const RV_HIT_ENERGY := 450.0
const ANIMAL_MASS := {"rabbit": 3.0, "deer": 65.0, "boar": 90.0, "bear": 220.0}

# Скоропортящееся: сколько секунд до порчи (в холодильнике время идёт медленнее)
const PERISHABLE := {"meat_raw": 420.0, "meat_cooked": 900.0, "berries_blue": 600.0, "berries_red": 600.0,
	"mushroom_cep": 500.0, "mushroom_chanterelle": 500.0, "mushrooms_fried": 900.0,
	"quarter_deer": 600.0, "quarter_boar": 600.0, "quarter_bear": 600.0}


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
	"berries_blue": {"hunger": 6.0, "thirst": 4.0},
	"berries_red": {"hunger": 5.0, "thirst": 5.0},
	"berries_wolf": {"hunger": 3.0, "poison_hit": 55.0},
	"mushroom_cep": {"hunger": 8.0, "poison": 0.1},
	"mushroom_chanterelle": {"hunger": 6.0},
	"mushroom_amanita": {"hunger": 4.0, "poison_hit": 45.0, "drunk": 45.0},
	"mushroom_toadstool": {"hunger": 4.0, "poison_hit": 90.0},
	"mushrooms_fried": {"hunger": 24.0, "warmth": 6.0},
}

# Что можно приготовить на печи/костре: сырое -> готовое
const COOK := {"meat_raw": "meat_cooked", "mushroom_cep": "mushrooms_fried", "mushroom_chanterelle": "mushrooms_fried"}

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
	"carbine": {"ammo": ["308"], "mag": 5, "rof": 1.1, "reload": 2.8, "recoil": 2.5, "zoom": 50.0, "kick": 1.2, "snd": "shot_rifle"},
	"magnum": {"ammo": ["338"], "mag": 5, "rof": 1.6, "reload": 3.4, "recoil": 5.0, "zoom": 48.0, "kick": 4.5, "snd": "shot_big"},
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

# Модели зверей (assets/models/animals): h — высота или len — длина, yaw — разворот модели к −Z,
# anims — имена анимаций в файле (idle/walk/run/eat/dead), proc — ноги двигает код (своих анимаций нет).
const ANIMAL_MODELS := {
	"deer": {"files": ["stag.gltf", "deer.gltf"], "h": 1.45, "yaw": PI,
		"anims": {"idle": "Idle", "walk": "Walk", "run": "Gallop", "eat": "Eating", "dead": "Death"}},
	"rabbit": {"files": ["rabbit.glb"], "h": 0.34, "yaw": PI,
		"anims": {"idle": "Guarding", "walk": "Running", "run": "Running", "eat": "Sitting_000", "dead": "Dead"}},
	"boar": {"files": ["boar.glb"], "len": 1.45, "yaw": PI, "side_h": 0.32,
		"anims": {"idle": "default", "walk": "walk", "run": "walk", "attack": "attack"}},
	"bear": {"files": ["bear.glb"], "len": 2.2, "yaw": 0.0, "side_h": 0.55, "proc": true, "tint": Color(0.36, 0.24, 0.15)},
}

# Что получается при разделке: [вид, количество]
const BUTCHER := {
	"carcass_rabbit": [["meat_raw", 1], ["rabbit_foot", 1]],
	"carcass_deer": [["meat_raw", 3], ["hide", 1]],
	"carcass_boar": [["meat_raw", 4], ["hide", 1]],
	"carcass_bear": [["meat_raw", 7], ["hide_bear", 1]],
	"quarter_deer": [["meat_raw", 2]],
	"quarter_boar": [["meat_raw", 2]],
	"quarter_bear": [["meat_raw", 2]],
}

# ---------------------------------------------------------------- Магазин
const SHOP := [
	{"key": "water_bottle", "type": "item", "price": 5, "cat": "food"},
	{"key": "canned_food", "type": "item", "price": 8, "cat": "food"},
	{"key": "beer", "type": "item", "price": 4, "cat": "food"},
	{"key": "vodka", "type": "item", "price": 12, "cat": "food"},
	{"key": "cigarettes", "type": "item", "price": 7, "q": 10.0, "cat": "food"},
	{"key": "bandage", "type": "item", "price": 10, "cat": "gear"},
	{"key": "firewood", "type": "item", "price": 6, "cat": "gear"},
	{"key": "matches", "type": "item", "price": 3, "q": 20.0, "cat": "gear"},
	{"key": "knife", "type": "item", "price": 15, "cat": "gear"},
	{"key": "jerrycan", "type": "item", "price": 25, "cat": "car"},
	{"key": "wrench", "type": "item", "price": 20, "cat": "car"},
	{"key": "hammer", "type": "item", "price": 18, "cat": "car"},
	{"key": "toolbox", "type": "item", "price": 55, "cat": "car"},
	{"key": "spare_parts", "type": "item", "price": 35, "cat": "car"},
	{"key": "duct_tape", "type": "item", "price": 6, "cat": "car"},
	{"key": "tire_patch", "type": "item", "price": 15, "cat": "car"},
	{"key": "jack", "type": "item", "price": 60, "cat": "car"},
	{"key": "spare_wheel", "type": "item", "price": 90, "cat": "car"},
	{"key": "ammo_22lr", "type": "ammo", "ammo": "22lr", "amount": 20, "price": 10, "cat": "guns"},
	{"key": "ammo_12shot", "type": "ammo", "ammo": "12shot", "amount": 10, "price": 12, "cat": "guns"},
	{"key": "ammo_12slug", "type": "ammo", "ammo": "12slug", "amount": 10, "price": 18, "cat": "guns"},
	{"key": "ammo_308", "type": "ammo", "ammo": "308", "amount": 10, "price": 30, "cat": "guns"},
	{"key": "ammo_338", "type": "ammo", "ammo": "338", "amount": 5, "price": 45, "cat": "guns"},
	{"key": "weapon_carbine", "type": "weapon", "weapon": "carbine", "price": 300, "cat": "guns"},
	{"key": "weapon_magnum", "type": "weapon", "weapon": "magnum", "price": 750, "cat": "guns"},
	{"key": "att_scope", "type": "item", "price": 120, "cat": "guns"},
	{"key": "att_reddot", "type": "item", "price": 70, "cat": "guns"},
	{"key": "att_suppressor", "type": "item", "price": 95, "cat": "guns"},
	{"key": "att_bipod", "type": "item", "price": 45, "cat": "guns"},
	{"key": "up_engine", "type": "upgrade", "up": "engine", "prices": [250, 500], "cat": "car"},
	{"key": "up_tank", "type": "upgrade", "up": "tank", "prices": [150, 300], "cat": "car"},
	{"key": "up_armor", "type": "upgrade", "up": "armor", "prices": [200, 400], "cat": "car"},
	{"key": "up_heater", "type": "upgrade", "up": "heater", "prices": [180], "cat": "car"},
]
const SHOP_CATS := ["food", "gear", "car", "guns"]

const FUEL_PRICE := 1.5


static func item_name(kind: String) -> String:
	return T.t("item_" + kind)


## Визуальная модель предмета (примитивы-заглушки, легко заменить на модели).
static func build_visual(kind: String) -> Node3D:
	var v := Node3D.new()
	v.name = "Vis"
	var s: Vector3 = ITEMS[kind].size if ITEMS.has(kind) else Vector3(0.3, 0.3, 0.3)
	if kind.begins_with("ammo_") or kind.begins_with("up_"):
		_shop_visual(v, kind)
		return v
	match kind:
		"carcass_rabbit":
			v.add_child(MU.capsule(0.13, 0.5, Color(0.55, 0.5, 0.45), Vector3.ZERO, Vector3(90, 0, 0)))
			v.add_child(MU.sphere(0.1, Color(0.5, 0.45, 0.4), Vector3(0, 0.03, -0.27)))
			v.add_child(MU.box(Vector3(0.04, 0.2, 0.06), Color(0.55, 0.48, 0.42), Vector3(0.04, 0.0, -0.4), Vector3(-70, 0, 10)))
			v.add_child(MU.box(Vector3(0.04, 0.2, 0.06), Color(0.55, 0.48, 0.42), Vector3(-0.04, 0.0, -0.4), Vector3(-70, 0, -10)))
			for p in [Vector3(0.08, 0.14, -0.12), Vector3(-0.08, 0.14, -0.12), Vector3(0.08, 0.14, 0.15), Vector3(-0.08, 0.14, 0.15)]:
				v.add_child(MU.box(Vector3(0.04, 0.16, 0.04), Color(0.5, 0.45, 0.4), p))
		"carcass_deer", "carcass_boar", "carcass_bear":
			var ak := kind.trim_prefix("carcass_")
			var am := A3.animal(ak, 0, true)
			am.position.y = -s.y * 0.5
			v.add_child(am)
		"quarter_deer", "quarter_boar", "quarter_bear":
			var fur: Color = {"quarter_deer": Color(0.5, 0.34, 0.2), "quarter_boar": Color(0.2, 0.15, 0.11), "quarter_bear": Color(0.3, 0.2, 0.12)}[kind]
			v.add_child(MU.capsule(s.x * 0.42, s.z * 0.9, MU.mat(Color(0.62, 0.12, 0.1), 0.45), Vector3.ZERO, Vector3(90, 0, 0)))
			v.add_child(MU.capsule(s.x * 0.44, s.z * 0.55, fur, Vector3(0, s.y * 0.12, s.z * 0.12), Vector3(90, 0, 0)))
			v.add_child(MU.cyl(0.035, 0.045, s.z * 0.5, Color(0.93, 0.9, 0.82), Vector3(0, 0, -s.z * 0.5), Vector3(90, 0, 0), 8))
			v.add_child(MU.sphere(0.06, Color(0.93, 0.9, 0.82), Vector3(0, 0, -s.z * 0.75)))
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
		"toolbox":
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
		"knife":
			v.add_child(MU.box(Vector3(0.03, 0.025, 0.12), Color(0.25, 0.15, 0.08), Vector3(0, 0, 0.07)))
			v.add_child(MU.box(Vector3(0.005, 0.03, 0.15), MU.mat(Color(0.8, 0.82, 0.85), 0.25, 0.0, 0.9), Vector3(0, 0.003, -0.06)))
		"matches":
			v.add_child(MU.box(s, Color(0.85, 0.75, 0.3)))
			v.add_child(MU.box(Vector3(s.x * 1.01, s.y * 0.4, s.z * 1.01), Color(0.35, 0.2, 0.12), Vector3(0, 0, 0)))
		"wrench":
			var steel := MU.mat(Color(0.7, 0.72, 0.75), 0.3, 0.0, 0.9)
			v.add_child(MU.box(Vector3(0.035, 0.012, 0.32), steel))
			v.add_child(MU.cyl(0.03, 0.03, 0.014, steel, Vector3(0, 0, -0.18), Vector3.ZERO, 6))
			v.add_child(MU.cyl(0.026, 0.026, 0.014, steel, Vector3(0, 0, 0.18), Vector3.ZERO, 12))
		"hammer":
			v.add_child(MU.box(Vector3(0.03, 0.03, 0.34), Color(0.55, 0.38, 0.2), Vector3(0, 0, 0.03)))
			v.add_child(MU.box(Vector3(0.12, 0.04, 0.04), MU.mat(Color(0.25, 0.25, 0.27), 0.4, 0.0, 0.8), Vector3(0.0, 0.0, -0.16)))
		"spare_parts":
			v.add_child(MU.box(s, Color(0.55, 0.42, 0.25)))
			v.add_child(MU.cyl(0.05, 0.05, 0.06, MU.mat(Color(0.6, 0.6, 0.62), 0.3, 0.0, 0.9), Vector3(0.06, s.y * 0.5 + 0.03, 0.0)))
			v.add_child(MU.cyl(0.035, 0.035, 0.08, MU.mat(Color(0.3, 0.3, 0.32), 0.4, 0.0, 0.8), Vector3(-0.07, s.y * 0.5 + 0.04, 0.03)))
		"duct_tape":
			v.add_child(MU.cyl(0.055, 0.055, 0.05, Color(0.6, 0.62, 0.64)))
			v.add_child(MU.cyl(0.03, 0.03, 0.052, Color(0.75, 0.65, 0.45)))
		"tire_patch":
			v.add_child(MU.box(s, Color(0.85, 0.2, 0.12)))
			v.add_child(MU.box(Vector3(s.x * 0.6, 0.01, s.z * 0.5), Color(0.1, 0.1, 0.1), Vector3(0, s.y * 0.5, 0)))
		"att_scope", "att_reddot", "att_suppressor", "att_bipod":
			v.add_child(build_attachment(kind))
		"berries_blue", "berries_red", "berries_wolf":
			var bc: Color = {"berries_blue": Color(0.12, 0.15, 0.4), "berries_red": Color(0.75, 0.08, 0.1), "berries_wolf": Color(0.05, 0.03, 0.05)}[kind]
			v.add_child(MU.cyl(0.07, 0.06, 0.03, Color(0.3, 0.45, 0.2), Vector3(0, -0.015, 0)))
			var rng := RandomNumberGenerator.new()
			rng.seed = kind.hash()
			for i in 11:
				var a := rng.randf() * TAU
				var r := rng.randf() * 0.05
				v.add_child(MU.sphere(0.016, MU.mat(bc, 0.25), Vector3(cos(a) * r, 0.01 + rng.randf() * 0.02, sin(a) * r)))
		"mushroom_cep", "mushroom_chanterelle", "mushroom_amanita", "mushroom_toadstool", "mushrooms_fried":
			_mushroom_visual(v, kind, s)
		_:
			v.add_child(MU.box(s, Color.MAGENTA))
	return v


static func _mushroom_visual(v: Node3D, kind: String, s: Vector3) -> void:
	if kind == "mushrooms_fried":
		v.add_child(MU.cyl(0.08, 0.075, 0.02, MU.mat(Color(0.2, 0.2, 0.22), 0.4, 0.0, 0.8), Vector3(0, -0.02, 0)))
		for i in 6:
			var a := i * 1.05
			v.add_child(MU.sphere(0.022, Color(0.5, 0.32, 0.12), Vector3(cos(a) * 0.04, 0.0, sin(a) * 0.04), Vector3(1.4, 0.6, 1.0)))
		return
	var cap: Color = {"mushroom_cep": Color(0.45, 0.26, 0.12), "mushroom_chanterelle": Color(0.95, 0.65, 0.12),
		"mushroom_amanita": Color(0.85, 0.08, 0.05), "mushroom_toadstool": Color(0.72, 0.75, 0.55)}[kind]
	var stem: Color = Color(0.9, 0.86, 0.75) if kind != "mushroom_chanterelle" else Color(0.95, 0.7, 0.2)
	var h := s.y
	var r := s.x * 0.5
	v.add_child(MU.cyl(r * 0.28, r * (0.42 if kind == "mushroom_cep" else 0.3), h * 0.7, stem, Vector3(0, -h * 0.15, 0)))
	if kind == "mushroom_chanterelle":
		v.add_child(MU.cyl(r, r * 0.3, h * 0.35, MU.mat(cap, 0.6), Vector3(0, h * 0.2, 0)))
		return
	v.add_child(MU.sphere(r, MU.mat(cap, 0.45), Vector3(0, h * 0.22, 0), Vector3(1, 0.55, 1)))
	if kind == "mushroom_amanita":
		for i in 9:
			var a := i * 2.4
			var rr := r * (0.25 + 0.55 * fmod(i * 0.37, 1.0))
			v.add_child(MU.sphere(r * 0.1, Color(0.97, 0.95, 0.9), Vector3(cos(a) * rr, h * 0.22 + r * 0.5 * sqrt(1.0 - (rr / r) * (rr / r)) , sin(a) * rr), Vector3(1, 0.5, 1)))
	if kind == "mushroom_toadstool":
		v.add_child(MU.cyl(r * 0.45, r * 0.4, 0.01, Color(0.95, 0.95, 0.9), Vector3(0, -h * 0.02, 0)))


## Иконки для магазина: коробка патронов, улучшения дома.
static func _shop_visual(v: Node3D, kind: String) -> void:
	if kind.begins_with("ammo_"):
		var cal := kind.trim_prefix("ammo_")
		var col: Color = {"22lr": Color(0.2, 0.4, 0.7), "12shot": Color(0.75, 0.15, 0.1), "12slug": Color(0.15, 0.5, 0.2), "308": Color(0.35, 0.3, 0.2), "338": Color(0.15, 0.15, 0.15)}.get(cal, Color.GRAY)
		v.add_child(MU.box(Vector3(0.2, 0.08, 0.12), col, Vector3(0, -0.04, 0)))
		var shell := cal.begins_with("12")
		for i in 4:
			var x := -0.06 + i * 0.04
			if shell:
				v.add_child(MU.cyl(0.014, 0.014, 0.09, Color(0.8, 0.15, 0.1), Vector3(x, 0.04, 0)))
				v.add_child(MU.cyl(0.015, 0.015, 0.02, MU.mat(Color(0.85, 0.7, 0.3), 0.3, 0.0, 0.9), Vector3(x, 0.0, 0)))
			else:
				var ln := 0.05 if cal == "22lr" else 0.1
				v.add_child(MU.cyl(0.008, 0.01, ln, MU.mat(Color(0.85, 0.65, 0.25), 0.3, 0.0, 0.9), Vector3(x, ln * 0.5, 0)))
				v.add_child(MU.cyl(0.0, 0.008, 0.025, MU.mat(Color(0.7, 0.4, 0.2), 0.3, 0.0, 0.9), Vector3(x, ln + 0.012, 0)))
		return
	match kind:
		"up_engine":
			v.add_child(MU.box(Vector3(0.4, 0.3, 0.3), MU.mat(Color(0.3, 0.3, 0.32), 0.4, 0.0, 0.8)))
			for i in 4:
				v.add_child(MU.cyl(0.04, 0.04, 0.12, MU.mat(Color(0.6, 0.6, 0.62), 0.3, 0.0, 0.9), Vector3(-0.15 + i * 0.1, 0.2, 0)))
			v.add_child(MU.box(Vector3(0.42, 0.04, 0.12), Color(0.75, 0.1, 0.08), Vector3(0, 0.27, 0)))
		"up_tank":
			var jm := A3.model("metal_jerrycan", 0.48)
			jm.position.y = -0.24
			v.add_child(jm)
		"up_armor":
			v.add_child(MU.box(Vector3(0.45, 0.32, 0.04), MU.mat(Color(0.45, 0.47, 0.5), 0.35, 0.0, 0.9)))
			for x in [-0.18, 0.18]:
				for y in [-0.12, 0.12]:
					v.add_child(MU.cyl(0.015, 0.015, 0.02, MU.mat(Color(0.7, 0.7, 0.72), 0.3, 0.0, 0.9), Vector3(x, y, 0.025), Vector3(90, 0, 0), 6))
		"up_heater":
			v.add_child(MU.box(Vector3(0.3, 0.32, 0.12), Color(0.85, 0.85, 0.82)))
			for i in 5:
				v.add_child(MU.box(Vector3(0.24, 0.015, 0.01), MU.mat(Color(1.0, 0.4, 0.1), 0.5, 2.0), Vector3(0, -0.11 + i * 0.055, 0.065)))


## Обвес как отдельная модель (для иконок и для ружья): ствол вдоль −Z.
static func build_attachment(kind: String) -> Node3D:
	var n := Node3D.new()
	var black := MU.mat(Color(0.08, 0.08, 0.09), 0.35, 0.0, 0.6)
	match kind:
		"att_scope":
			n.add_child(MU.cyl(0.018, 0.018, 0.22, black, Vector3.ZERO, Vector3(90, 0, 0), 14))
			n.add_child(MU.cyl(0.026, 0.02, 0.06, black, Vector3(0, 0, -0.12), Vector3(90, 0, 0), 14))
			n.add_child(MU.cyl(0.022, 0.018, 0.05, black, Vector3(0, 0, 0.11), Vector3(90, 0, 0), 14))
			n.add_child(MU.cyl(0.008, 0.008, 0.025, black, Vector3(0, 0.022, 0), Vector3.ZERO, 8))
			n.add_child(MU.cyl(0.024, 0.024, 0.002, MU.mat(Color(0.3, 0.5, 0.8), 0.05, 0.3, 0.5), Vector3(0, 0, -0.151), Vector3(90, 0, 0), 14))
			for z in [-0.06, 0.06]:
				n.add_child(MU.box(Vector3(0.02, 0.03, 0.02), black, Vector3(0, -0.025, z)))
		"att_reddot":
			n.add_child(MU.box(Vector3(0.035, 0.012, 0.06), black, Vector3(0, -0.012, 0)))
			n.add_child(MU.cyl(0.018, 0.018, 0.045, black, Vector3(0, 0.012, 0), Vector3(90, 0, 0), 12))
			n.add_child(MU.cyl(0.014, 0.014, 0.002, MU.mat(Color(0.9, 0.3, 0.2), 0.05, 0.6, 0.5), Vector3(0, 0.012, -0.023), Vector3(90, 0, 0), 12))
		"att_suppressor":
			n.add_child(MU.cyl(0.022, 0.022, 0.2, black, Vector3.ZERO, Vector3(90, 0, 0), 12))
		"att_bipod":
			n.add_child(MU.box(Vector3(0.04, 0.02, 0.04), black))
			for e in [-1, 1]:
				n.add_child(MU.cyl(0.006, 0.006, 0.2, black, Vector3(e * 0.03, -0.09, 0.0), Vector3(0, 0, e * 15), 6))
	return n


## Модель ружья: ствол смотрит в −Z, приклад в +Z, начало координат — у спускового крючка.
## Внутри есть Marker3D «Muzzle» (дульный срез).
static func build_gun(w: String, att: Array = []) -> Node3D:
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
	var mz := -0.2 - length * 0.72
	for a in att:
		var an := build_attachment(str(a))
		match str(a):
			"att_scope":
				an.position = Vector3(0, 0.075, -0.12)
			"att_reddot":
				an.position = Vector3(0, 0.05, -0.1)
			"att_suppressor":
				an.position = Vector3(0, 0.02, mz - 0.1)
				mz -= 0.2
			"att_bipod":
				an.position = Vector3(0, -0.06, -0.45)
		g.add_child(an)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.02, mz)
	g.add_child(muzzle)
	return g
