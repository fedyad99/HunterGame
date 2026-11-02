extends SceneTree
## Снимки из игры (нужен GL): -- mode=aim|cab|inside|chase out=/tmp/x.png
var f := 0
var mode := "aim"
var out := "/tmp/game.png"
var shot_f := 150
var st_pos := Vector3.ZERO
var shop_cat := "guns"
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="): mode = a.substr(5)
		if a.begins_with("out="): out = a.substr(4)
		if a.begins_with("f="): shot_f = int(a.substr(2))
		if a.begins_with("cat="): shop_cat = a.substr(4)
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
			"gun":
				p.cam_yaw = rv.rotation.y
			"draw":
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
			"forest", "animals", "scope", "tracks", "berries", "fire":
				w.game_time = 10.5
				var c := _forest_spot(w, mode in ["animals", "scope", "berries"])
				p.global_position = c + Vector3(0, 1.0, 0)
				st_pos = c
				if mode == "scope":
					p.give_weapon("carbine")
			"swamp":
				w.game_time = 11.0
				var b := _swamp_spot()
				rv.global_transform = Transform3D(Basis(Vector3.UP, 0.6), b + Vector3(0, 1.4, 0))
				st_pos = b
			"dinette":
				p.global_position = rv.global_transform * Vector3(0.7, 1.3, -0.3)
				p.cam_yaw = rv.rotation.y + PI + 0.35
				p.cam_pitch = -0.25
			"map":
				w.hud.open_map(p)
			"shop":
				w.hud._shop_cat = shop_cat
				w.hud.open_shop(p, 0)
			"fridge":
				w.hud.open_storage(p, "fridge")
			"attach":
				p.give_weapon("carbine")
	if f == 12 and mode == "attach":
		p._select_weapon("carbine")
		p.inv_add("att_scope", 1.0)
		p.inv_add("att_suppressor", 1.0)
		p.inv_add("att_bipod", 1.0)
		p.inv_add("att_reddot", 1.0)
		for k in p.inventory.size():
			if p.inventory[k].kind == "att_suppressor":
				p.attach_from_inv(k)
				break
		w.hud.open_attachments(p)
	if f == 12 and mode == "scope":
		p._select_weapon("carbine")
		p.inv_add("att_scope", 1.0)
		for k in p.inventory.size():
			if p.inventory[k].kind == "att_scope":
				p.attach_from_inv(k)
				break
	if mode in ["animals", "scope"] and f > 8:
		# звери стоят рядком перед камерой
		var fwd := Vector3(0, 0, -1)
		var right := Vector3(1, 0, 0)
		var kinds := ["bear", "deer", "boar", "deer", "rabbit"] if mode == "animals" else ["deer"]
		var dist := 10.0 if mode == "animals" else 24.0
		var used := {}
		for i in kinds.size():
			for c in w.entities.get_children():
				if c is Animal and c.kind == kinds[i] and not used.has(c.name):
					used[c.name] = true
					var off: float = (i - (kinds.size() - 1) * 0.5) * 3.0
					var q: Vector3 = st_pos + fwd * dist + right * off
					q.y = TerrainGen.height_at(q.x, q.z)
					c.global_position = q
					c.rotation.y = 1.2 + i * 0.5
					c.state = "idle"
					c.yaw = c.rotation.y
					break
		if f < 12:
			p.global_position = st_pos + Vector3(0, 0.2, 0)
		_look(p, st_pos + fwd * dist + Vector3(0, 0.6, 0) - (right * 3.5 if mode == "animals" else Vector3.ZERO))
		if mode == "scope" and f > 30:
			Input.action_press("aim")
	if mode == "forest" and f > 8:
		p.cam_yaw = 0.8
		p.cam_pitch = 0.02
	if mode == "tracks" and f > 8:
		if f == 40:
			for k in 8:
				w.wild.add_track("deer", st_pos + Vector3(0.6 + k * 0.35, 0, 0.6 - k * 0.6), 0.5, "shotdeer", k > 4, false)
			w.wild.add_track("boar", st_pos + Vector3(-1.0, 0, -0.8), 0.0, "shotboar", false, true)
			for t in w.wild.tracks.slice(-3):
				var nd: MeshInstance3D = t.node
				nd.scale = Vector3.ONE * float(OS.get_environment("TRS") if OS.get_environment("TRS") != "" else "1")
				print("tr ", nd.global_position, " vis=", nd.is_visible_in_tree(), " sz=", (nd.mesh as QuadMesh).size, " h=", TerrainGen.height_at(nd.global_position.x, nd.global_position.z), " inside=", nd.is_inside_tree(), " tr=", nd.transparency)
			print("tracks=", w.wild.tracks.size(), " cam=", root.get_viewport().get_camera_3d().global_position if root.get_viewport().get_camera_3d() else null, " st=", st_pos)
			var tr: Dictionary = w.wild.track_near(st_pos + Vector3(1.0, 0, -2.0), 2.0)
			if not tr.is_empty():
				w.wild.inspect(tr)
		if f < 12:
			p.global_position = st_pos + Vector3(0, 0.2, 1.5)
		p.cam_yaw = 0.3
		p.cam_pitch = -0.85
	if mode == "berries" and f > 8:
		var bi := 0
		var best := 1e9
		for k in w.wild.bushes.size():
			var d: float = w.wild.bushes[k].pos.distance_to(st_pos)
			if d < best:
				best = d
				bi = k
		var bp: Vector3 = w.wild.bushes[bi].pos
		if f < 12:
			p.global_position = bp + Vector3(2.2, 0.3, 2.2)
		_look(p, bp + Vector3(0, 0.2, 0))
		p.cam_pitch = -0.35
		if f == 10:
			for k in 6:
				var mk: String = ["mushroom_cep", "mushroom_amanita", "mushroom_chanterelle", "mushroom_toadstool", "mushroom_cep", "mushroom_amanita"][k]
				var mp: Vector3 = bp + Vector3(1.0 + k * 0.35, 0.3, -0.6 + (k % 2) * 0.5)
				w.spawn_item(mk, mp)
	if mode == "fire" and f > 8:
		w.game_time = 20.6
		if f == 10:
			var fp: Vector3 = st_pos + Vector3(0, 0, -3.0)
			fp.y = TerrainGen.height_at(fp.x, fp.z)
			w.spawner.spawn({"t": "fire", "pos": fp, "name": "Fshot"})
		var fire = w.entities.get_node_or_null("Fshot")
		if fire:
			fire.lit = true
			fire.fuel = 300.0
		if f < 12:
			p.global_position = st_pos + Vector3(0.6, 0.2, 1.0)
		_look(p, st_pos + Vector3(0, 0.3, -3.0))
		p.cam_pitch = -0.2
	if mode == "swamp" and f > 8:
		if f < 30:
			p.global_position = rv.global_position + Vector3(11.0, 0.0, 7.0)
			p.global_position.y = TerrainGen.height_at(p.global_position.x, p.global_position.z) + 1.0
		_look(p, rv.global_position)
		p.cam_pitch = -0.1
		if f > 20 and f < 120 and false:
			rv.seats = [p.peer_id + 777, 0, 0, 0, 0, 0, 0, 0]
			rv.set_input(1.0, 0.0, 0.0)
			rv.gear = 2
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
	if f == shot_f - 1 and mode == "tracks":
		for t in w.wild.tracks.slice(-3):
			var nd: MeshInstance3D = t.node
			print("late ", is_instance_valid(nd), " ", nd.global_position if is_instance_valid(nd) else null, " tr=", nd.transparency if is_instance_valid(nd) else -1.0)
	if f == shot_f:
		var img := root.get_texture().get_image()
		img.save_png(out)
		print("saved ", out)
		quit()
	return false


func _look(p, target: Vector3) -> void:
	var d: Vector3 = target - p.global_position
	p.cam_yaw = atan2(-d.x, -d.z)
	p.cam_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.0, 1.0)


## Ровное место в густом лесу.
func _forest_spot(w, open := false) -> Vector3:
	seed(11)
	var best := Vector3.ZERO
	var bd := -9.0
	for i in 3000:
		var x := randf_range(-300, 300)
		var z := randf_range(-300, 300)
		var d := TerrainGen.noise.get_noise_2d(x * 3.1 + 500.0, z * 3.1)
		if TerrainGen.normal_at(x, z).y < 0.95 or TerrainGen.height_at(x, z) < TerrainGen.WATER + 2.0 or TerrainGen.swamp_at(x, z) > 0.1:
			continue
		if TerrainGen.road_query(Vector2(x, z)).x < 12.0:
			continue
		if open:
			d = -d
		if d > bd and d < 0.25:
			bd = d
			best = Vector3(x, 0, z)
	best.y = TerrainGen.height_at(best.x, best.z)
	return best


func _swamp_spot() -> Vector3:
	var best := Vector3.ZERO
	var bs := 0.0
	seed(7)
	for i in 4000:
		var x := randf_range(-330, 330)
		var z := randf_range(-330, 330)
		var s := TerrainGen.swamp_at(x, z)
		if s > bs and TerrainGen.height_at(x, z) > TerrainGen.WATER + 0.3 and TerrainGen.road_query(Vector2(x, z)).x > 10.0:
			bs = s
			best = Vector3(x, 0, z)
	best.y = TerrainGen.height_at(best.x, best.z)
	return best
