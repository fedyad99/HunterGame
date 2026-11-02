class_name WorldBuilder
extends RefCounted
## Строит статичный мир: рельеф, вода, лес, фактории, освещение.
## Всё детерминировано, поэтому у всех игроков одинаково.

static func build(w: Node3D) -> void:
	TerrainGen.build_grid()
	_terrain(w)
	_water(w)
	_forest(w)
	_outposts(w)
	_environment(w)


static func _noise_tex(freq: float, normal := false) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = 42
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	t.generate_mipmaps = true
	if normal:
		t.as_normal_map = true
		t.bump_strength = 6.0
	return t


static func _terrain(w: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = TerrainGen.build_mesh()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/terrain.gdshader")
	sm.set_shader_parameter("noise_tex", _noise_tex(0.02))
	sm.set_shader_parameter("noise_nrm", _noise_tex(0.03, true))
	mi.material_override = sm
	w.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = MU.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = TerrainGen.N
	hm.map_depth = TerrainGen.N
	hm.map_data = TerrainGen.grid
	cs.shape = hm
	cs.scale = Vector3(TerrainGen.STEP, 1.0, TerrainGen.STEP)
	body.add_child(cs)
	w.add_child(body)


static func _water(w: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(TerrainGen.HALF * 2.0, TerrainGen.HALF * 2.0)
	pm.subdivide_width = 8
	pm.subdivide_depth = 8
	mi.mesh = pm
	mi.position.y = TerrainGen.WATER
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	sm.set_shader_parameter("nmap", _noise_tex(0.05, true))
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)


static func _foliage_mat(a: Color, b: Color, sway: float) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/foliage.gdshader")
	sm.set_shader_parameter("color_a", a)
	sm.set_shader_parameter("color_b", b)
	sm.set_shader_parameter("sway", sway)
	return sm


static func _append(st: SurfaceTool, mesh: Mesh, xf: Transform3D) -> void:
	st.append_from(mesh, 0, xf)


## Ель: ствол + несколько ярусов «лап».
static func _pine_mesh() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.08
	trunk.bottom_radius = 0.28
	trunk.height = 9.0
	trunk.radial_segments = 8
	var st_t := SurfaceTool.new()
	st_t.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(st_t, trunk, Transform3D(Basis(), Vector3(0, 4.5, 0)))
	var st_f := SurfaceTool.new()
	st_f.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := 6
	for i in tiers:
		var c := CylinderMesh.new()
		var k := 1.0 - float(i) / tiers
		c.top_radius = 0.05
		c.bottom_radius = 0.6 + 2.0 * k
		c.height = 1.6 + 0.6 * k
		c.radial_segments = 9
		c.rings = 1
		var y := 2.2 + i * 1.15
		_append(st_f, c, Transform3D(Basis(Vector3.UP, i * 0.7), Vector3(0, y, 0)))
	var m := ArrayMesh.new()
	st_t.generate_normals()
	st_t.commit(m)
	st_f.generate_normals()
	st_f.commit(m)
	m.surface_set_material(0, MU.mat(Color(0.28, 0.2, 0.13), 1.0))
	m.surface_set_material(1, _foliage_mat(Color(0.07, 0.17, 0.08), Color(0.13, 0.24, 0.1), 0.05))
	return m


## Берёза: белый ствол, несколько облаков листвы.
static func _birch_mesh() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.07
	trunk.bottom_radius = 0.17
	trunk.height = 8.0
	trunk.radial_segments = 8
	var st_t := SurfaceTool.new()
	st_t.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append(st_t, trunk, Transform3D(Basis(), Vector3(0, 4.0, 0)))
	var st_f := SurfaceTool.new()
	st_f.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		var s := SphereMesh.new()
		s.radius = rng.randf_range(1.0, 1.6)
		s.height = s.radius * 1.6
		s.radial_segments = 10
		s.rings = 5
		var p := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(5.0, 8.0), rng.randf_range(-1.0, 1.0))
		_append(st_f, s, Transform3D(Basis(), p))
	var m := ArrayMesh.new()
	st_t.generate_normals()
	st_t.commit(m)
	st_f.generate_normals()
	st_f.commit(m)
	m.surface_set_material(0, MU.mat(Color(0.88, 0.86, 0.8), 0.9))
	m.surface_set_material(1, _foliage_mat(Color(0.2, 0.33, 0.1), Color(0.38, 0.45, 0.14), 0.1))
	return m


static func _bush_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(0, 0.4, 0), Vector3(0.4, 0.3, 0.2), Vector3(-0.35, 0.3, -0.2)]:
		var s := SphereMesh.new()
		s.radius = 0.55
		s.height = 0.8
		s.radial_segments = 8
		s.rings = 4
		_append(st, s, Transform3D(Basis(), p))
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, _foliage_mat(Color(0.12, 0.22, 0.08), Color(0.25, 0.32, 0.1), 0.12))
	return m


static func _rock_mesh() -> ArrayMesh:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 1.4
	s.radial_segments = 7
	s.rings = 4
	var st := SurfaceTool.new()
	st.create_from(s, 0)
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, MU.mat(Color(0.42, 0.41, 0.39), 0.95))
	return m


static func _near_outpost(p: Vector2, extra: float) -> bool:
	for o in TerrainGen.outposts:
		if p.distance_to(o.pos) < float(o.r) + extra:
			return true
	return false


static func _forest(w: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var pines: Array = []
	var birches: Array = []
	var bushes: Array = []
	var rocks: Array = []
	var trees_body := StaticBody3D.new()
	trees_body.name = "Trees"
	trees_body.collision_layer = MU.L_WORLD
	trees_body.collision_mask = 0
	trees_body.set_meta("kind", "bush")
	w.add_child(trees_body)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.3
	trunk_shape.height = 6.0
	var tries := 0
	while pines.size() + birches.size() < 2200 and tries < 30000:
		tries += 1
		# кластеры леса — по шуму
		var x := rng.randf_range(-370, 370)
		var z := rng.randf_range(-370, 370)
		var density := TerrainGen.noise.get_noise_2d(x * 3.1 + 500.0, z * 3.1)
		if density < -0.05 and rng.randf() > 0.15:
			continue
		var h := TerrainGen.height_at(x, z)
		if h < TerrainGen.WATER + 0.8 or TerrainGen.normal_at(x, z).y < 0.75:
			continue
		var p2 := Vector2(x, z)
		if TerrainGen.road_query(p2).x < 7.0 or _near_outpost(p2, 6.0):
			continue
		var s := rng.randf_range(0.75, 1.35)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), Vector3(x, h - 0.2, z))
		if h > 40.0 or rng.randf() < 0.7:
			pines.append(xf)
		else:
			birches.append(xf)
		var cs := CollisionShape3D.new()
		cs.shape = trunk_shape
		cs.position = Vector3(x, h + 3.0, z)
		trees_body.add_child(cs)
	for i in 1800:
		var x := rng.randf_range(-370, 370)
		var z := rng.randf_range(-370, 370)
		var h := TerrainGen.height_at(x, z)
		if h < TerrainGen.WATER + 0.5 or TerrainGen.road_query(Vector2(x, z)).x < 5.0 or _near_outpost(Vector2(x, z), 2.0):
			continue
		var s := rng.randf_range(0.6, 1.4)
		bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, h - 0.1, z)))
	var rocks_body := StaticBody3D.new()
	rocks_body.name = "Rocks"
	rocks_body.collision_layer = MU.L_WORLD
	w.add_child(rocks_body)
	for i in 260:
		var x := rng.randf_range(-370, 370)
		var z := rng.randf_range(-370, 370)
		var h := TerrainGen.height_at(x, z)
		if TerrainGen.road_query(Vector2(x, z)).x < 6.0 or _near_outpost(Vector2(x, z), 4.0):
			continue
		var s := rng.randf_range(0.4, 2.2)
		var sc := Vector3(s * rng.randf_range(0.8, 1.5), s * rng.randf_range(0.5, 0.9), s)
		rocks.append(Transform3D(Basis.from_euler(Vector3(rng.randf() * 0.3, rng.randf() * TAU, rng.randf() * 0.3)).scaled(sc), Vector3(x, h, z)))
		if s > 0.9:
			var cs := CollisionShape3D.new()
			var sp := SphereShape3D.new()
			sp.radius = s * 0.7
			cs.shape = sp
			cs.position = Vector3(x, h + s * 0.1, z)
			rocks_body.add_child(cs)
	_multimesh(w, "Pines", _pine_mesh(), pines)
	_multimesh(w, "Birches", _birch_mesh(), birches)
	_multimesh(w, "Bushes", _bush_mesh(), bushes)
	_multimesh(w, "RockMeshes", _rock_mesh(), rocks)


static func _multimesh(w: Node3D, nm: String, mesh: Mesh, xfs: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nm
	mmi.multimesh = mm
	w.add_child(mmi)


# ---------------------------------------------------------------- Фактории
static func _outposts(w: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Outposts"
	w.add_child(root)
	var shop_idx := 0
	for o in TerrainGen.outposts:
		var on := Node3D.new()
		on.name = "O%d" % o.id
		on.position = Vector3(o.pos.x, o.h, o.pos.y)
		root.add_child(on)
		on.add_child(MU.label3d(T.t(o.key), Vector3(0, 9, 0), 160, Color(1.0, 0.9, 0.6)))
		if o.shop:
			_shop(w, on, shop_idx)
			shop_idx += 1
			_sell_bin(w, on, Vector3(-3.0, 0, -9.0))
		_pump(w, on, Vector3(9.0, 0, -9.0))
		_campfire(w, on, Vector3(2.0, 0, 7.0))
		_butcher_table(on, Vector3(-6.0, 0, 7.0))
		# скамейки у костра
		for a in [0.0, 2.1, 4.2]:
			var bp := Vector3(2.0 + cos(a) * 2.2, 0.25, 7.0 + sin(a) * 2.2)
			var bench := MU.static_box(Vector3(1.4, 0.4, 0.4), bp, Vector3(0, -rad_to_deg(a) + 90, 0))
			bench.add_child(MU.cyl(0.2, 0.2, 1.4, Color(0.4, 0.27, 0.15), Vector3.ZERO, Vector3(0, 0, 90), 8))
			on.add_child(bench)


static func _shop(w: Node3D, on: Node3D, idx: int) -> void:
	var wood := Color(0.45, 0.3, 0.17)
	var dark := Color(0.3, 0.2, 0.12)
	var c := Vector3(-12.0, 0, -9.0)
	var parts := [
		[Vector3(9, 0.3, 7), c + Vector3(0, 0.15, 0)],
		[Vector3(9, 4, 0.3), c + Vector3(0, 2.0, -3.5)],
		[Vector3(0.3, 4, 7), c + Vector3(-4.5, 2.0, 0)],
		[Vector3(0.3, 4, 7), c + Vector3(4.5, 2.0, 0)],
	]
	for p in parts:
		var sb := MU.static_box(p[0], p[1])
		sb.add_child(MU.box(p[0], wood))
		on.add_child(sb)
	var roof := MU.static_box(Vector3(10, 0.3, 8.5), c + Vector3(0, 4.3, 0.4), Vector3(8, 0, 0))
	roof.add_child(MU.box(Vector3(10, 0.3, 8.5), dark))
	on.add_child(roof)
	var counter := MU.static_box(Vector3(4, 1.1, 0.8), c + Vector3(0, 0.55, 1.5))
	counter.add_child(MU.box(Vector3(4, 1.1, 0.8), Color(0.55, 0.38, 0.2)))
	counter.set_meta("kind", "shop")
	counter.set_meta("shop_idx", idx)
	counter.name = "Shop"
	on.add_child(counter)
	# продавец-манекен и товары
	on.add_child(MU.capsule(0.3, 1.7, Color(0.3, 0.35, 0.5), c + Vector3(0, 0.95, 0.4)))
	on.add_child(MU.sphere(0.2, Color(0.85, 0.66, 0.52), c + Vector3(0, 2.0, 0.4)))
	for i in 6:
		on.add_child(MU.box(Vector3(0.5, 0.4, 0.4), Color(0.3 + i * 0.08, 0.25, 0.2), c + Vector3(-3.5 + i * 1.2, 1.5, -3.0)))
	on.add_child(MU.label3d(T.t("sign_shop"), c + Vector3(0, 3.3, 1.8), 96, Color(1, 0.95, 0.8), false))
	w.shop_spawns.append(on.position + c + Vector3(0, 1.4, 2.8))
	var lamp := OmniLight3D.new()
	lamp.position = c + Vector3(0, 3.5, 0.5)
	lamp.light_color = Color(1.0, 0.8, 0.5)
	lamp.omni_range = 9.0
	lamp.light_energy = 1.5
	on.add_child(lamp)


static func _sell_bin(w: Node3D, on: Node3D, p: Vector3) -> void:
	var col := Color(0.4, 0.3, 0.2)
	for part in [[Vector3(2.6, 0.2, 2.6), Vector3(0, 0.1, 0)], [Vector3(2.6, 1.0, 0.15), Vector3(0, 0.5, -1.25)],
			[Vector3(2.6, 1.0, 0.15), Vector3(0, 0.5, 1.25)], [Vector3(0.15, 1.0, 2.6), Vector3(-1.25, 0.5, 0)],
			[Vector3(0.15, 1.0, 2.6), Vector3(1.25, 0.5, 0)]]:
		var sb := MU.static_box(part[0], p + part[1])
		sb.add_child(MU.box(part[0], col))
		sb.set_meta("kind", "sell_bin")
		on.add_child(sb)
	on.add_child(MU.label3d(T.t("sign_sell_bin"), p + Vector3(0, 2.0, 0), 72, Color(0.9, 1.0, 0.7)))
	var a := Area3D.new()
	a.name = "SellArea"
	a.collision_layer = 0
	a.collision_mask = MU.L_ITEMS
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.3, 1.4, 2.3)
	cs.shape = bs
	a.add_child(cs)
	a.position = p + Vector3(0, 0.8, 0)
	on.add_child(a)
	w.sell_areas.append(a)


static func _pump(w: Node3D, on: Node3D, p: Vector3) -> void:
	var sb := MU.static_box(Vector3(0.8, 1.9, 0.6), p + Vector3(0, 0.95, 0))
	sb.add_child(MU.box(Vector3(0.8, 1.9, 0.6), Color(0.8, 0.15, 0.1)))
	sb.add_child(MU.box(Vector3(0.6, 0.4, 0.05), MU.mat(Color(0.9, 0.95, 0.7), 0.3, 0.6), Vector3(0, 0.5, 0.31)))
	sb.set_meta("kind", "pump")
	sb.name = "Pump"
	on.add_child(sb)
	on.add_child(MU.label3d(T.t("sign_fuel"), p + Vector3(0, 2.4, 0), 64))
	# площадка
	var pad := MU.box(Vector3(8, 0.05, 6), Color(0.3, 0.3, 0.3), p + Vector3(-3, 0.02, 3))
	on.add_child(pad)


static func _campfire(w: Node3D, on: Node3D, p: Vector3) -> void:
	var f := Node3D.new()
	f.name = "Campfire"
	f.position = p
	on.add_child(f)
	for i in 6:
		var a := i * TAU / 6.0
		f.add_child(MU.sphere(0.18, Color(0.35, 0.33, 0.3), Vector3(cos(a) * 0.6, 0.08, sin(a) * 0.6)))
	f.add_child(MU.cyl(0.08, 0.08, 1.0, Color(0.3, 0.2, 0.1), Vector3(0, 0.15, 0), Vector3(0, 30, 75), 6))
	f.add_child(MU.cyl(0.08, 0.08, 1.0, Color(0.3, 0.2, 0.1), Vector3(0, 0.15, 0), Vector3(0, -40, 75), 6))
	var flame := CPUParticles3D.new()
	flame.amount = 30
	flame.lifetime = 0.8
	flame.position.y = 0.2
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.25
	flame.gravity = Vector3(0, 2.5, 0)
	flame.initial_velocity_min = 0.2
	flame.initial_velocity_max = 0.6
	flame.scale_amount_min = 0.6
	flame.scale_amount_max = 1.4
	var fm := SphereMesh.new()
	fm.radius = 0.12
	fm.height = 0.24
	fm.radial_segments = 6
	fm.rings = 3
	fm.material = MU.mat(Color(1.0, 0.5, 0.1), 1.0, 4.0)
	flame.mesh = fm
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.8, 0.3, 1))
	grad.set_color(1, Color(0.8, 0.15, 0.0, 0))
	flame.color_ramp = grad
	f.add_child(flame)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position.y = 0.8
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 12.0
	light.light_energy = 2.5
	light.shadow_enabled = true
	f.add_child(light)
	var a2 := MU.area_box(Vector3(1.6, 1.0, 1.6), Vector3(0, 0.5, 0), "campfire", "Station")
	f.add_child(a2)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = Sfx.get_stream("fire")
	snd.unit_size = 3.0
	snd.max_distance = 25.0
	snd.volume_db = -6.0
	snd.autoplay = true
	snd.bus = "SFX"
	f.add_child(snd)
	w.heat_sources.append(f)


static func _butcher_table(on: Node3D, p: Vector3) -> void:
	var sb := MU.static_box(Vector3(2.0, 0.9, 1.0), p + Vector3(0, 0.45, 0))
	sb.add_child(MU.box(Vector3(2.0, 0.12, 1.0), Color(0.5, 0.36, 0.22), Vector3(0, 0.39, 0)))
	for e in [Vector3(-0.85, -0.1, -0.4), Vector3(0.85, -0.1, -0.4), Vector3(-0.85, -0.1, 0.4), Vector3(0.85, -0.1, 0.4)]:
		sb.add_child(MU.box(Vector3(0.1, 0.8, 0.1), Color(0.35, 0.25, 0.15), e))
	sb.add_child(MU.box(Vector3(0.6, 0.02, 0.3), Color(0.6, 0.15, 0.12, 0.8), Vector3(0.3, 0.46, 0.1)))
	sb.set_meta("kind", "butcher")
	sb.name = "Butcher"
	on.add_child(sb)


# ---------------------------------------------------------------- Небо и свет
static func _environment(w: Node3D) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.5, 0.75)
	sm.sky_horizon_color = Color(0.72, 0.76, 0.78)
	sm.ground_horizon_color = Color(0.5, 0.5, 0.45)
	sm.ground_bottom_color = Color(0.2, 0.2, 0.18)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.73, 0.76)
	env.fog_density = 0.0025
	env.fog_aerial_perspective = 0.5
	env.volumetric_fog_enabled = false
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	var we := WorldEnvironment.new()
	we.name = "Env"
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.light_energy = 1.2
	w.add_child(sun)
	w.env = env
	w.sky_mat = sm
	w.sun = sun
