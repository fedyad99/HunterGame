class_name Wild
extends Node3D
## Дикая природа: следы зверей, ягодники и грибы, зоны обитания, работы в поле
## (разделка туши ножом, розжиг костра) и данные для карты.
## Следы каждый игрок рисует у себя сам по синхронизированным позициям зверей.

const TRACK_LIFE := 480.0         # сколько секунд виден след
const TRACK_MAX := 1600
const BUSH_REGROW := 600.0
const MUSHROOMS := 60
const MUSHROOM_KINDS := [["mushroom_cep", 0.3], ["mushroom_chanterelle", 0.3], ["mushroom_amanita", 0.25], ["mushroom_toadstool", 0.15]]

var world: Node
# зоны обитания: kind -> [{pos: Vector2, r: float}]
var habitats := {}
# ягодники: [{pos: Vector3, kind: String}]
var bushes: Array = []
var bush_ready: Array = []        # у хоста: время, когда ягоды снова вырастут
var bush_berries: Array = []      # узлы ягод (у всех), скрываем, когда собраны
var tracks: Array = []
var _track_mesh := {}
var _track_mat := {}
var _hl_t := 0.0
var _hl_who := ""
var jobs := {}                    # хост: pid -> работа в поле
var _mush_t := 3.0


func _ready() -> void:
	world = get_parent()
	_make_habitats()
	_make_bushes()


# ======================================================================= ЗОНЫ ОБИТАНИЯ
func _make_habitats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var rules := {
		"deer": {"n": 4, "r": 75.0, "hmin": 6.0, "hmax": 38.0},
		"boar": {"n": 3, "r": 65.0, "hmin": 1.5, "hmax": 16.0, "swamp": true},
		"bear": {"n": 2, "r": 75.0, "hmin": 26.0, "hmax": 90.0},
		"rabbit": {"n": 4, "r": 55.0, "hmin": 2.0, "hmax": 26.0},
	}
	var taken: Array = []
	for kind in ["bear", "boar", "deer", "rabbit"]:
		var rl: Dictionary = rules[kind]
		var zones: Array = []
		for attempt in 600:
			if zones.size() >= int(rl.n):
				break
			var p := Vector2(rng.randf_range(-300, 300), rng.randf_range(-300, 300))
			var h := TerrainGen.height_at(p.x, p.y)
			if h < float(rl.hmin) or h > float(rl.hmax) or not TerrainGen.is_land(p.x, p.y, 1.0):
				continue
			if rl.has("swamp") and TerrainGen.swamp_at(p.x + 30, p.y) < 0.05 and TerrainGen.swamp_at(p.x - 30, p.y) < 0.05 and attempt < 400:
				continue
			var ok := true
			for o in TerrainGen.outposts:
				if p.distance_to(o.pos) < float(o.r) + (110.0 if kind == "bear" else 50.0):
					ok = false
			for t in taken:
				if p.distance_to(t[0]) < (float(t[1]) + float(rl.r)) * (0.55 if t[2] != kind else 0.9):
					ok = false
			if ok:
				zones.append({"pos": p, "r": float(rl.r)})
				taken.append([p, float(rl.r), kind])
		habitats[kind] = zones


## Случайная точка для зверя: чаще в его зоне, иногда где угодно.
func habitat_point(kind: String, rng_any := 0.2) -> Vector2:
	var zones: Array = habitats.get(kind, [])
	if zones.is_empty() or randf() < rng_any:
		return Vector2(randf_range(-320, 320), randf_range(-320, 320))
	var z: Dictionary = zones[randi() % zones.size()]
	var a := randf() * TAU
	var r := sqrt(randf()) * float(z.r)
	return z.pos + Vector2(cos(a), sin(a)) * r


# ======================================================================= ЯГОДНИКИ
func _make_bushes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var tries := 0
	while bushes.size() < 80 and tries < 4000:
		tries += 1
		var x := rng.randf_range(-320, 320)
		var z := rng.randf_range(-320, 320)
		var h := TerrainGen.height_at(x, z)
		if h < TerrainGen.WATER + 1.0 or h > 45.0 or TerrainGen.normal_at(x, z).y < 0.85:
			continue
		if TerrainGen.road_query(Vector2(x, z)).x < 6.0 or TerrainGen.swamp_at(x, z) > 0.3:
			continue
		var near_out := false
		for o in TerrainGen.outposts:
			if Vector2(x, z).distance_to(o.pos) < float(o.r) + 8.0:
				near_out = true
		if near_out:
			continue
		var r := rng.randf()
		var k := "berries_blue" if r < 0.45 else ("berries_red" if r < 0.75 else "berries_wolf")
		bushes.append({"pos": Vector3(x, h, z), "kind": k, "yaw": rng.randf() * TAU, "s": rng.randf_range(0.8, 1.15)})
	bush_ready.resize(bushes.size())
	bush_ready.fill(0.0)


## Визуал ягодников строит WorldBuilder (общая модель куста + ягоды).
func build_bush_visuals(bush_mesh: Mesh, mesh_xf := Transform3D()) -> void:
	var col := {"berries_blue": Color(0.14, 0.17, 0.45), "berries_red": Color(0.8, 0.08, 0.1), "berries_wolf": Color(0.06, 0.03, 0.06)}
	var berry := SphereMesh.new()
	berry.radius = 0.035
	berry.height = 0.07
	berry.radial_segments = 6
	berry.rings = 4
	for i in bushes.size():
		var b: Dictionary = bushes[i]
		var root := Node3D.new()
		root.position = b.pos
		root.rotation.y = b.yaw
		root.scale = Vector3.ONE * float(b.s)
		add_child(root)
		var mi := MeshInstance3D.new()
		mi.mesh = bush_mesh
		mi.transform = Transform3D(Basis().scaled(Vector3.ONE * 0.55), Vector3.ZERO) * mesh_xf
		mi.visibility_range_end = 160.0
		root.add_child(mi)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = berry
		var rng := RandomNumberGenerator.new()
		rng.seed = i * 31 + 5
		mm.instance_count = 40
		for j in 40:
			var a := rng.randf() * TAU
			var rr := rng.randf_range(0.25, 0.55)
			var y := rng.randf_range(0.25, 0.85)
			mm.set_instance_transform(j, Transform3D(Basis(), Vector3(cos(a) * rr, y, sin(a) * rr)))
		var bmi := MultiMeshInstance3D.new()
		bmi.multimesh = mm
		bmi.material_override = MU.mat(col[b.kind], 0.25)
		bmi.visibility_range_end = 70.0
		root.add_child(bmi)
		bush_berries.append(bmi)
		var area := MU.area_box(Vector3(1.3, 1.1, 1.3), Vector3(0, 0.55, 0), "berry_bush", "B%d" % i)
		area.set_meta("bush", i)
		root.add_child(area)


func bush_has_berries(i: int) -> bool:
	return i >= 0 and i < bush_berries.size() and (bush_berries[i] as Node3D).visible


@rpc("any_peer", "call_local", "reliable")
func req_forage(i: int) -> void:
	if not multiplayer.is_server() or i < 0 or i >= bushes.size():
		return
	var sid: int = world._sender()
	var p: Node = world.get_player(sid)
	if p == null or p.global_position.distance_to(bushes[i].pos) > 4.0:
		return
	var now := Time.get_ticks_msec() * 0.001
	if float(bush_ready[i]) > now:
		return
	bush_ready[i] = now + BUSH_REGROW
	p.rpc_id(sid, "inv_add", str(bushes[i].kind), 1.0, 0.0)
	rpc("set_bush", i, false)
	world.sfx_all("pickup", bushes[i].pos, -6.0, 1.2)


@rpc("authority", "call_local", "reliable")
func set_bush(i: int, has: bool) -> void:
	if i >= 0 and i < bush_berries.size():
		(bush_berries[i] as Node3D).visible = has


## Хост: полный список собранных кустов для нового игрока.
func send_bushes(pid: int) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for i in bushes.size():
		if float(bush_ready[i]) > now:
			rpc_id(pid, "set_bush", i, false)


# ======================================================================= ГРИБЫ (хост)
func server_tick(delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for i in bushes.size():
		if float(bush_ready[i]) > 0.0 and float(bush_ready[i]) <= now:
			bush_ready[i] = 0.0
			rpc("set_bush", i, true)
	_mush_t -= delta
	if _mush_t <= 0.0:
		_mush_t = 20.0
		var n := 0
		for c in world.entities.get_children():
			if c is Item and str(c.kind).begins_with("mushroom_"):
				n += 1
		var add := MUSHROOMS - n if n < MUSHROOMS / 2 or _first_mush else mini(MUSHROOMS - n, 2)
		_first_mush = false
		for k in add:
			_spawn_mushroom()
	_tick_jobs(delta)


var _first_mush := true


func _spawn_mushroom() -> void:
	for attempt in 30:
		var x := randf_range(-320, 320)
		var z := randf_range(-320, 320)
		var h := TerrainGen.height_at(x, z)
		if h < TerrainGen.WATER + 1.0 or TerrainGen.normal_at(x, z).y < 0.85 or TerrainGen.road_query(Vector2(x, z)).x < 8.0:
			continue
		# грибы — в лесу (там, где гуще деревья)
		if TerrainGen.noise.get_noise_2d(x * 3.1 + 500.0, z * 3.1) < 0.0:
			continue
		var r := randf()
		var kind := "mushroom_cep"
		for e in MUSHROOM_KINDS:
			r -= float(e[1])
			if r <= 0.0:
				kind = e[0]
				break
		world.spawn_item(kind, Vector3(x, h + 0.15, z))
		return


# ======================================================================= РАБОТЫ В ПОЛЕ (хост)
## kind: field_cut (разделка туши ножом), fire_light (розжиг спичками)
func start_job(pid: int, kind: String, target: String) -> void:
	jobs[pid] = {"kind": kind, "target": target, "t": 0.0, "snd": 0.0}


func stop_job(pid: int) -> void:
	jobs.erase(pid)


func _tick_jobs(delta: float) -> void:
	for pid in jobs.keys():
		var j: Dictionary = jobs[pid]
		var p: Node = world.get_player(pid)
		if p == null or p.dead:
			jobs.erase(pid)
			continue
		j.t = float(j.t) + delta
		j.snd = float(j.snd) - delta
		var snd: bool = float(j.snd) <= 0.0
		if snd:
			j.snd = 0.6
		match str(j.kind):
			"field_cut":
				var it := world.entities.get_node_or_null(str(j.target)) as Item
				if it == null or it.is_queued_for_deletion() or it.holder != 0 or it.global_position.distance_to(p.global_position) > 3.5 or not ItemsDB.FIELD_CUT.has(it.kind):
					jobs.erase(pid)
					continue
				if snd:
					world.sfx_all("butcher", it.global_position, -8.0, randf_range(0.9, 1.2))
				if float(j.t) >= float(ItemsDB.FIELD_CUT_TIME[it.kind]):
					_field_cut(it)
					world.tell(pid, T.t("msg_field_cut"))
					jobs.erase(pid)
			"fire_light":
				var f := world.entities.get_node_or_null(str(j.target)) as Fire
				if f == null or f.lit or f.global_position.distance_to(p.global_position) > 3.5:
					jobs.erase(pid)
					continue
				if snd:
					world.sfx_all("lighter", f.global_position, -6.0, 1.0)
				if float(j.t) >= 2.0:
					# в дождь и на ветру разжечь труднее
					var chance := 0.45 if world.raining else 0.85
					if randf() < chance and f.fuel > 0.0:
						f.lit = true
						world.sfx_all("fire_whoosh", f.global_position, 0.0, 1.0)
						world.tell(pid, T.t("msg_fire_lit"))
					else:
						world.tell(pid, T.t("msg_fire_fail"))
					p.rpc_id(pid, "use_match")
					jobs.erase(pid)


func _field_cut(it: Item) -> void:
	var out: Array = ItemsDB.FIELD_CUT[it.kind]
	var pos := it.global_position + Vector3.UP * 0.4
	var q := it.q
	var age := it.age
	var hide := "hide_bear" if it.kind == "carcass_bear" else "hide"
	it.queue_free()
	for e in out:
		var n := maxi(int(round(int(e[1]) * clampf(q, 0.5, 1.0))), 1)
		for i in n:
			world.spawn_item(e[0], pos + Vector3(randf_range(-0.6, 0.6), i * 0.25, randf_range(-0.6, 0.6)), Vector3(randf_range(-0.8, 0.8), 1.5, randf_range(-0.8, 0.8)), 1.0, age)
	world.spawn_item(hide, pos + Vector3(0, 0.6, 0), Vector3.UP)
	world.rpc("fx_burst", pos, 0)
	world.add_blood_all(pos)


# ======================================================================= СЛЕДЫ (у каждого свои)
func _track_tex(kind: String, dung: bool) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(0.1, 0.065, 0.035, 1.0)
	var blobs: Array = []
	if dung:
		for i in 7:
			blobs.append([Vector2(22 + (i % 3) * 9, 24 + (i / 3) * 8), 5.0, 5.0])
		c = Color(0.12, 0.08, 0.04, 0.95)
	else:
		match kind:
			"deer", "boar":
				# раздвоенное копыто
				var sp := 7.0 if kind == "deer" else 9.0
				blobs.append([Vector2(32 - sp, 30), 6.0, 15.0])
				blobs.append([Vector2(32 + sp, 30), 6.0, 15.0])
				if kind == "boar":
					blobs.append([Vector2(32 - 14, 50), 3.0, 4.0])
					blobs.append([Vector2(32 + 14, 50), 3.0, 4.0])
			"bear":
				blobs.append([Vector2(32, 40), 16.0, 13.0])
				for i in 5:
					blobs.append([Vector2(14 + i * 9, 16 + absf(i - 2) * 3), 4.5, 5.0])
			"rabbit":
				blobs.append([Vector2(25, 22), 5.0, 13.0])
				blobs.append([Vector2(39, 22), 5.0, 13.0])
				blobs.append([Vector2(32, 48), 4.0, 5.0])
	for y in 64:
		for x in 64:
			var a := 0.0
			for b in blobs:
				var d: Vector2 = (Vector2(x, y) - b[0]) / Vector2(b[1], b[2])
				a = maxf(a, clampf((1.25 - d.length()) * 2.5, 0.0, 1.0))
			# вокруг отпечатка — примятая земля, чтобы след читался на траве
			var halo := 0.0
			for b in blobs:
				var d2: Vector2 = (Vector2(x, y) - b[0]) / (Vector2(b[1], b[2]) * 1.9)
				halo = maxf(halo, clampf(1.2 - d2.length(), 0.0, 1.0))
			var px := Color(0.34, 0.25, 0.15, 0.8 * halo)
			if a > 0.0:
				px = Color(c.r, c.g, c.b, maxf(c.a * a, px.a))
			if px.a > 0.0:
				img.set_pixel(x, y, px)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _mat_for(kind: String, dung: bool, blood: bool) -> Material:
	var key := "%s|%s|%s" % [kind, dung, blood]
	if _track_mat.has(key):
		return _track_mat[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _track_tex(kind, dung)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = 1.0
	if blood:
		m.albedo_color = Color(1.6, 0.6, 0.5)
	m.render_priority = 1
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR   # без мип-карт: издалека след не растворяется
	_track_mat[key] = m
	return m


func add_track(kind: String, pos: Vector3, yaw: float, who: String, blood: bool, dung := false) -> void:
	if DisplayServer.get_name() == "headless" and not OS.has_feature("track_test"):
		# без экрана рисовать незачем, но данные для подсказок нужны
		pass
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	if cam and cam.global_position.distance_to(pos) > 180.0:
		return
	var h := TerrainGen.height_at(pos.x, pos.z)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	var sz := {"rabbit": 0.34, "deer": 0.42, "boar": 0.45, "bear": 0.62}.get(kind, 0.42) as float
	if dung:
		sz = 0.42
	q.size = Vector2(sz, sz)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	mi.material_override = _mat_for(kind, dung, blood)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	add_child(mi)
	var side := 0.08 if (tracks.size() % 2 == 0) else -0.08
	var b := Basis(Vector3.UP, yaw)
	mi.global_transform = Transform3D(b, Vector3(pos.x, h + 0.07, pos.z) + b * Vector3(side if not dung else 0.0, 0, 0))
	tracks.append({"pos": mi.global_position, "yaw": yaw, "kind": kind, "t": Time.get_ticks_msec() * 0.001,
		"who": who, "blood": blood, "dung": dung, "node": mi})
	if tracks.size() > TRACK_MAX:
		var old: Dictionary = tracks.pop_front()
		if is_instance_valid(old.node):
			old.node.queue_free()


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	_hl_t = maxf(_hl_t - delta, 0.0)
	# старые следы бледнеют и исчезают; дождь смывает быстрее
	var life := TRACK_LIFE * (0.5 if world and world.raining else 1.0)
	while not tracks.is_empty() and now - float(tracks[0].t) > life:
		var old: Dictionary = tracks.pop_front()
		if is_instance_valid(old.node):
			old.node.queue_free()
	if Engine.get_process_frames() % 30 == 0:
		for tr in tracks:
			var age := now - float(tr.t)
			var n := tr.node as GeometryInstance3D
			if is_instance_valid(n):
				var hl: bool = _hl_t > 0.0 and tr.who == _hl_who
				n.transparency = 0.0 if hl else clampf(age / life, 0.0, 0.85)
				n.scale = Vector3.ONE * (1.6 if hl else 1.0)


## Ближайший след к точке (в радиусе r).
func track_near(p: Vector3, r: float) -> Dictionary:
	var best := {}
	var bd := r
	for tr in tracks:
		var d := Vector2(tr.pos.x - p.x, tr.pos.z - p.z).length()
		if d < bd:
			bd = d
			best = tr
	return best


## Изучить след: что за зверь, насколько свежий, куда ушёл. Подсвечивает дальнейшую тропу.
func inspect(tr: Dictionary) -> String:
	var now := Time.get_ticks_msec() * 0.001
	var age := now - float(tr.t)
	var fresh := "track_fresh_0" if age < 60.0 else ("track_fresh_1" if age < 200.0 else "track_fresh_2")
	var dir_key := ""
	# направление — по следующим следам того же зверя
	var last: Dictionary = tr
	for t2 in tracks:
		if t2.who == tr.who and float(t2.t) > float(last.t):
			last = t2
	var d := Vector2(last.pos.x - tr.pos.x, last.pos.z - tr.pos.z)
	if d.length() < 0.5:
		d = Vector2(sin(float(tr.yaw)), cos(float(tr.yaw)))
	var ang := fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0)
	var dirs := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	dir_key = "dir_" + dirs[int(round(ang / 45.0)) % 8]
	_hl_who = tr.who
	_hl_t = 40.0
	var what := "track_dung" if tr.dung else "track_prints"
	var s := T.t(what, [T.t("animal_" + str(tr.kind)), T.t(fresh)])
	if not tr.dung:
		s += " " + T.t("track_dir", [T.t(dir_key)])
	if tr.blood:
		s += " " + T.t("track_blood")
	return s
