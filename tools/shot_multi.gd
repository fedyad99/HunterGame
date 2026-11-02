extends SceneTree
## Серия скриншотов за один запуск: -- out=/dir/ [only=a,b]
## Своя камера в заданных точках (в системе дома: x вправо-влево, z вперёд), чтобы показать салон, багажник, колесо и т.д.
var f := 0
var out := "/tmp/shots/"
var only: Array = []
var cam: Camera3D
var steps: Array = []
var si := 0
var step_f := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		if a.begins_with("only="): only = a.substr(5).split(",")
	var net = root.get_node("Net")
	net.is_host = true
	net.port = 17791
	change_scene_to_file("res://scenes/world.tscn")

func R(w, rv, p: Vector3) -> Vector3:
	return rv.global_transform * p

func _set_cam(rv, pos: Vector3, look: Vector3, fov := 70.0) -> void:
	var pl = current_scene.local_player
	pl.set_physics_process(false)
	pl.set_process(false)
	var c: Camera3D = pl.cam
	c.fov = fov
	c.global_position = R(null, rv, pos)
	c.look_at(R(null, rv, look), Vector3.UP)

func _build_steps() -> void:
	steps = [
		["ext_side", func(w, rv, p): _set_cam(rv, Vector3(-9, 2.4, -1), Vector3(0, 1.8, -0.8), 60)],
		["ext_front", func(w, rv, p): _set_cam(rv, Vector3(5.5, 2.2, 9.5), Vector3(0, 1.8, 0.5), 60)],
		["ext_rear", func(w, rv, p): _set_cam(rv, Vector3(-5.0, 2.8, -13), Vector3(0, 2.2, -4), 60)],
		["salon_front", func(w, rv, p): _set_cam(rv, Vector3(0.0, 2.35, -6.2), Vector3(0, 1.9, -1.0), 80)],
		["salon_rear", func(w, rv, p): _set_cam(rv, Vector3(0.0, 2.3, 0.6), Vector3(0.0, 1.7, -5.0), 80)],
		["kitchen", func(w, rv, p): _set_cam(rv, Vector3(0.7, 2.2, -2.0), Vector3(-0.8, 1.6, -3.8), 75)],
		["armchairs", func(w, rv, p): _set_cam(rv, Vector3(0.1, 2.35, 0.5), Vector3(0.5, 1.4, -1.3), 75)],
		["stove_lit", func(w, rv, p):
			rv.stove_t = 300.0
			_set_cam(rv, Vector3(0.3, 2.0, 0.3), Vector3(-0.66, 1.4, -0.85), 70)],
		["storage_ui", func(w, rv, p):
			if f_once("su"):
				rv.store = {"fridge": [{"kind": "meat_cooked", "q": 1.0, "age": 100.0}, {"kind": "meat_raw", "q": 1.0, "age": 300.0}, {"kind": "water_bottle", "q": 1.0, "age": 0.0}], "shelf": [], "locker": []}
				p.inventory.append({"kind": "meat_raw", "q": 1.0, "age": 400.0})
				p.inventory.append({"kind": "canned_food", "q": 1.0})
				w.hud.open_storage(p, "fridge")
			_set_cam(rv, Vector3(0.1, 2.35, 0.5), Vector3(0.5, 1.4, -1.3), 75)],
		["rack", func(w, rv, p):
			w.hud.close_menu()
			if f_once("rack"):
				for k in ["carcass_deer", "jerrycan", "spare_wheel", "carcass_boar"]:
					var s: Vector3 = [Vector3(-0.5, 0, -0.55), Vector3(0.5, 0, -0.55), Vector3(-0.5, 0, -2.15), Vector3(0.5, 0, -2.15)][["carcass_deer", "jerrycan", "spare_wheel", "carcass_boar"].find(k)]
					w.spawn_item(k, R(null, rv, Vector3(s.x, 4.3, s.z)), Vector3.ZERO)
			_set_cam(rv, Vector3(-3.5, 6.5, -9.5), Vector3(0, 3.8, -2.4), 60)],
		["wheel_jack", func(w, rv, p):
			if f_once("wj"):
				rv.wheel_state = [1, 0, 0, 0]
				rv.jack_i = 0
				rv.jack_t = 1.0
			_set_cam(rv, Vector3(4.5, 1.6, 4.5), Vector3(1.1, 0.7, 2.6), 60)],
		["winch_carcass", func(w, rv, p):
			if f_once("wc"):
				rv.jack_i = -1
				var d = w.spawn_item("carcass_deer", R(null, rv, Vector3(2.0, 1.0, 22.0)), Vector3.ZERO)
				rv.winch_state = [2, 0]
				rv.winch_item = [d.name, ""]
				rv.winch_anchor = [d.global_position, Vector3.ZERO]
				rv.winch_on = [true, false]
				rv.winch_len[0] = 20.0
			_set_cam(rv, Vector3(5.0, 3.0, 7.0), Vector3(1.0, 1.2, 15.0), 60)],
		["cab", func(w, rv, p):
			_set_cam(rv, Vector3(0.15, 2.55, 1.55), Vector3(0.55, 2.0, 3.1), 75)],
		["furniture", func(w, rv, p): _set_cam(rv, Vector3(-0.3, 2.0, -1.6), Vector3(0.7, 1.4, -2.6), 75)],
		["character_back", func(w, rv, p):
			p.set_physics_process(true)
			p.set_process(true)
			Input.action_release("aim")
			p.cam_pitch = -0.05],
		["character_draw", func(w, rv, p):
			p.set_physics_process(true)
			p.set_process(true)
			Input.action_press("aim")],
		["character_aim", func(w, rv, p):
			Input.action_press("aim")],
	]

var _done := {}
func f_once(k: String) -> bool:
	if _done.has(k): return false
	_done[k] = true
	return true

func _physics_process(_d: float) -> bool:
	var w = current_scene
	if w == null or not w.has_method("spawn_item") or w.rv == null or w.local_player == null:
		return false
	f += 1
	var rv = w.rv
	var p = w.local_player
	if cam == null:
		cam = Camera3D.new()
		root.add_child(cam)
		_build_steps()
		if not only.is_empty():
			steps = steps.filter(func(s): return s[0] in only)
	if f < 5:
		return false
	if si >= steps.size():
		quit()
		return false
	step_f += 1
	var st: Array = steps[si]
	st[1].call(w, rv, p)
	if step_f == 1:
		w.hud.icons.queue.clear()
	if step_f == 22:
		root.get_texture().get_image().save_png(out + st[0] + ".png")
		print("saved ", st[0])
		si += 1
		step_f = 0
	return false
