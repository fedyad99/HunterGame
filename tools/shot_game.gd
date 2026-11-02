extends SceneTree
## Снимки из игры (нужен GL): -- mode=aim|cab|inside|chase out=/tmp/x.png
var f := 0
var mode := "aim"
var out := "/tmp/game.png"
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="): mode = a.substr(5)
		if a.begins_with("out="): out = a.substr(4)
	var net = root.get_node("Net")
	net.is_host = true
	net.port = 17790
	change_scene_to_file("res://scenes/world.tscn")
func _physics_process(_d: float) -> bool:
	var w = current_scene
	if w == null or not w.has_method("spawn_item") or w.rv == null or w.local_player == null:
		return false
	f += 1
	var p = w.local_player
	var rv = w.rv
	if f == 5:
		w.hud.icons.queue.clear()
		match mode:
			"cab":
				w.req_sit(0)
			"dash":
				w.req_sit(0)
			"chase":
				w.req_sit(0)
			"inside":
				p.global_position = rv.global_transform * Vector3(0, 1.3, -0.5)
				p.cam_yaw = rv.rotation.y - PI * 0.5
			"aim":
				p.global_position = rv.global_position + rv.global_basis.x * -5.0
				p.cam_yaw = rv.rotation.y - PI * 0.5
				Input.action_press("aim")
				p.cam_pitch = -0.1
			"inv":
				w.hud.open_inventory(p)
			"ext":
				p.global_position = rv.global_transform * Vector3(-9.0, 0.5, -1.0)
				p.cam_yaw = rv.rotation.y + PI * 0.5 + 0.35
				p.cam_pitch = -0.05
			"hud":
				p.hunger = 30.0
				p.thirst = 12.0
				p.bladder = 85.0
				p.warmth = 55.0
				p.wetness = 40.0
				p.hp = 70.0
			"watch":
				p.watch_view = true
				p.watch_t = 99.0
			"lever":
				w.req_sit(0)
	if mode == "dash" and f > 8:
		p.cam_pitch = -0.55
		p.cam_yaw = rv.rotation.y + PI
		rv.fuel = 18.0
		rv.lights_on = true
	if mode == "lever" and f > 8:
		p.cam_pitch = -1.0
		p.cam_yaw = rv.rotation.y + PI - 0.4
		if f == 20:
			rv.set_gear(5)
	if mode == "hud" and f > 8:
		p.hunger = 30.0
		p.thirst = 12.0
		p.bladder = 85.0
		p.warmth = 55.0
		p.wetness = 40.0
		p.hp = 70.0
	if f == 150:
		var img := root.get_texture().get_image()
		img.save_png(out)
		print("saved ", out)
		quit()
	return false
