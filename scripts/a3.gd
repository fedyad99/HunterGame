class_name A3
extends RefCounted
## Подгрузка открытых (CC0) ассетов: модели Poly Haven и текстуры ambientCG.
## Модели лежат в assets/models/<имя>/<имя>.gltf, текстуры — assets/textures/rv/<имя>_color|normal.jpg.

static var _tex := {}
static var _mats := {}
static var _scenes := {}


## Экземпляр модели. Если задан h (м) — масштабируется по высоте, если l — по наибольшей стороне.
## Начало координат — центр основания.
static func model(name: String, h := -1.0, l := -1.0) -> Node3D:
	var holder := Node3D.new()
	holder.name = name
	var ps: PackedScene = _scenes.get(name)
	if ps == null:
		ps = load("res://assets/models/%s/%s.gltf" % [name, name])
		_scenes[name] = ps
	if ps == null:
		return holder
	var n: Node3D = ps.instantiate()
	holder.add_child(n)
	var bb := _aabb(n)
	var s := 1.0
	if h > 0.0 and bb.size.y > 0.0:
		s = h / bb.size.y
	elif l > 0.0:
		s = l / maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	n.scale = Vector3.ONE * s
	n.position = Vector3(-(bb.position.x + bb.size.x * 0.5) * s, -bb.position.y * s, -(bb.position.z + bb.size.z * 0.5) * s)
	holder.set_meta("size", bb.size * s)
	return holder


static func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var t := Transform3D()
		var p: Node = mi
		while p != null and p != n:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var a := t * mi.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


static func tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = load(path)
	_tex[path] = t
	return t


## Материал с текстурой ambientCG; tile — сколько метров на один повтор (трипланарно, без UV).
static func tmat(name: String, tint := Color.WHITE, tile := 1.0, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%.2f|%.2f|%.2f" % [name, tint.to_html(), tile, rough, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex("res://assets/textures/rv/%s_color.jpg" % name)
	m.albedo_color = tint
	var nt := "res://assets/textures/rv/%s_normal.jpg" % name
	if ResourceLoader.exists(nt):
		m.normal_enabled = true
		m.normal_texture = tex(nt)
		m.normal_scale = 0.8
	m.roughness = rough
	m.metallic = metal
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE / tile
	m.uv1_triplanar_sharpness = 4.0
	_mats[key] = m
	return m


## Любая сцена-модель по пути (gltf/glb): масштаб по высоте h или по длине l (самая длинная сторона по горизонтали).
## Начало координат — центр основания. Анимации, если есть, остаются в AnimationPlayer внутри.
static func model_path(path: String, h := -1.0, l := -1.0) -> Node3D:
	var holder := Node3D.new()
	var ps: PackedScene = _scenes.get(path)
	if ps == null:
		ps = load(path)
		_scenes[path] = ps
	if ps == null:
		return holder
	var n: Node3D = ps.instantiate()
	holder.add_child(n)
	var bb := _aabb(n)
	var s := 1.0
	if h > 0.0 and bb.size.y > 0.0:
		s = h / bb.size.y
	elif l > 0.0:
		s = l / maxf(bb.size.x, bb.size.z)
	n.scale = Vector3.ONE * s
	n.position = Vector3(-(bb.position.x + bb.size.x * 0.5) * s, -bb.position.y * s, -(bb.position.z + bb.size.z * 0.5) * s)
	holder.set_meta("size", bb.size * s)
	return holder


static var _loops_set := {}


## Модель зверя (см. ItemsDB.ANIMAL_MODELS). variant — номер файла (олень/олениха).
## dead = true — поза мёртвого зверя (лежит на боку).
static func animal(kind: String, variant := 0, dead := false) -> Node3D:
	var d: Dictionary = ItemsDB.ANIMAL_MODELS[kind]
	var files: Array = d.files
	var path := "res://assets/models/animals/" + str(files[variant % files.size()])
	var m := model_path(path, float(d.get("h", -1.0)), float(d.get("len", -1.0)))
	var inner: Node3D = m.get_child(0) if m.get_child_count() > 0 else null
	if inner == null:
		return m
	# модель смотрит в +Z — разворачиваем к -Z (вперёд у зверя)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	m.remove_child(inner)
	pivot.add_child(inner)
	m.add_child(pivot)
	pivot.rotation.y = float(d.get("yaw", 0.0))
	if d.has("tint"):
		var tint: Color = d.tint
		for mi in inner.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for si in mesh.get_surface_count():
				var mat := mesh.surface_get_material(si)
				if mat is StandardMaterial3D:
					var mm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					mm.albedo_color = tint
					(mi as MeshInstance3D).set_surface_override_material(si, mm)
	var ap := inner.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and not _loops_set.has(path):
		_loops_set[path] = true
		var an: Dictionary = d.get("anims", {})
		for key in ["idle", "walk", "run", "eat"]:
			var nm := str(an.get(key, ""))
			if nm != "" and ap.has_animation(nm):
				ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
	if dead:
		var an2: Dictionary = d.get("anims", {})
		var dn := str(an2.get("dead", ""))
		if ap and dn != "" and ap.has_animation(dn):
			ap.play(dn)
			ap.seek(ap.get_animation(dn).length, true)
			ap.pause()
		else:
			pivot.rotation.z = PI * 0.5
			pivot.position.y = float(d.get("side_h", 0.3))
	return m
