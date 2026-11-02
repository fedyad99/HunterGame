class_name Look
extends RefCounted
## Внешний вид персонажа: тело (модель), цвета кожи/волос/одежды, борода, головной убор.
## Хранится строкой, чтобы одинаково сохраняться на диск и синхронизироваться по сети.

const SAVE_PATH := "user://look.cfg"
const BODIES := [
	"res://assets/characters/Casual_Male.gltf",
	"res://assets/characters/Casual_Female.gltf",
	"res://assets/characters/Casual_Bald.gltf",
	"res://assets/characters/Casual2_Male.gltf",
	"res://assets/characters/Casual3_Female.gltf",
	"res://assets/characters/Worker_Male.gltf",
	"res://assets/characters/Worker_Female.gltf",
]
const BODY_KEYS := ["look_body_0", "look_body_1", "look_body_2", "look_body_3", "look_body_4", "look_body_5", "look_body_6"]
const SKIN_TONES := ["f5d5bd", "e8b998", "d49b72", "b5784f", "8a5636", "5e3a24"]
const HAIR_COLORS := ["15100d", "3b2417", "6b4423", "a9753a", "d8b46a", "b4401c", "8a8a8a", "e8e8e8"]
const BEARD_KEYS := ["look_beard_0", "look_beard_1", "look_beard_2", "look_beard_3"]   # нет, щетина, усы, борода
const HAT_KEYS := ["look_hat_0", "look_hat_1", "look_hat_2", "look_hat_3"]             # нет, кепка, шапка, охотничья шляпа

var body := 0
var skin := "e8b998"
var hair := "3b2417"
var shirt := "a02a1f"
var pants := "384030"
var beard := 0
var hat := 1
var hat_color := "e87a10"


static func from_string(s: String) -> Look:
	var l := Look.new()
	var p := s.split(";")
	if p.size() >= 7:
		l.body = clampi(int(p[0]), 0, BODIES.size() - 1)
		l.skin = p[1]
		l.hair = p[2]
		l.shirt = p[3]
		l.pants = p[4]
		l.beard = clampi(int(p[5]), 0, 3)
		l.hat = clampi(int(p[6]), 0, 3)
		if p.size() >= 8:
			l.hat_color = p[7]
	return l


func to_string_code() -> String:
	return "%d;%s;%s;%s;%s;%d;%d;%s" % [body, skin, hair, shirt, pants, beard, hat, hat_color]


static func random_look() -> Look:
	var l := Look.new()
	l.body = randi() % BODIES.size()
	l.skin = SKIN_TONES[randi() % SKIN_TONES.size()]
	l.hair = HAIR_COLORS[randi() % HAIR_COLORS.size()]
	l.shirt = Color.from_hsv(randf(), randf_range(0.3, 0.7), randf_range(0.35, 0.7)).to_html(false)
	l.pants = Color.from_hsv(randf_range(0.05, 0.6), randf_range(0.1, 0.4), randf_range(0.2, 0.4)).to_html(false)
	return l


static func load_saved() -> Look:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return from_string(str(cfg.get_value("look", "code", "")))
	return Look.new()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("look", "code", to_string_code())
	cfg.save(SAVE_PATH)
