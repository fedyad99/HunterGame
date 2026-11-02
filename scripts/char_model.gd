class_name CharModel
extends Node3D
## Скелетная модель персонажа (Quaternius, CC0) с анимациями и перекраской по Look.
## Лицом вперёд — в -Z (как и весь остальной код). Позы рук для эмоций и прицеливания
## задаются направлениями костей (простая «обратная кинематика» по направлению).

const LOOPED := ["Idle", "Walk", "Run", "Walk_Carry", "Run_Carry", "Victory"]

var look: Look
var skeleton: Skeleton3D
var anim: AnimationPlayer
var cur_anim := ""
var anim_time := 0.0
var _rig: Node3D
var _attach := {}
var _beard_node: Node3D
var _hat_node: Node3D
var _look_code := ""
var _shirt_mats: Array = []
var _head_tilt := Vector3.ZERO


func build(l: Look) -> void:
	look = l
	scale = Vector3.ONE * 0.8
	_look_code = l.to_string_code()
	var scene: PackedScene = load(Look.BODIES[l.body])
	_rig = scene.instantiate()
	_rig.rotation.y = PI
	add_child(_rig)
	skeleton = _rig.find_children("*", "Skeleton3D", true, false)[0]
	anim = _rig.find_children("*", "AnimationPlayer", true, false)[0]
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for a in anim.get_animation_list():
		anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR if a in LOOPED else Animation.LOOP_NONE
	_recolor()
	_build_accessories()
	play("Idle")


func look_code() -> String:
	return _look_code


func _recolor() -> void:
	var colors := {
		"Skin": Color.html(look.skin),
		"Hair": Color.html(look.hair),
		"Shirt": Color.html(look.shirt),
		"Vest": Color.html(look.shirt).darkened(0.25),
		"Pants": Color.html(look.pants),
		"Belt": Color(0.2, 0.13, 0.08),
		"Hat": Color.html(look.hat_color),
	}
	for mi in _rig.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for s in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(s)
			if src == null:
				continue
			var nm := src.resource_name
			var sm := StandardMaterial3D.new()
			sm.roughness = 0.75
			if colors.has(nm):
				sm.albedo_color = colors[nm]
				if nm == "Shirt":
					_shirt_mats.append(sm)
				if nm == "Skin":
					sm.roughness = 0.55
			elif src is BaseMaterial3D:
				sm.albedo_color = (src as BaseMaterial3D).albedo_color
				sm.albedo_texture = (src as BaseMaterial3D).albedo_texture
			m.set_surface_override_material(s, sm)


## Куртка снята — остаётся светлая футболка.
func set_jacket(on: bool) -> void:
	var c := Color.html(look.shirt)
	for m in _shirt_mats:
		(m as StandardMaterial3D).albedo_color = c if on else c.lerp(Color(0.92, 0.9, 0.85), 0.75)


## Узел, который каждый кадр следует за костью (BoneAttachment3D в 4.3 капризничает с gl_compatibility).
func bone_attach(bone: String) -> Node3D:
	if _attach.has(bone):
		return _attach[bone]
	var n := Node3D.new()
	n.set_meta("bone", skeleton.find_bone(bone))
	add_child(n)
	_attach[bone] = n
	return n


func update_attachments() -> void:
	for k in _attach:
		var n: Node3D = _attach[k]
		var bi: int = n.get_meta("bone")
		var origin := skeleton.global_transform * skeleton.get_bone_global_pose(bi).origin
		var bas := global_basis
		if k == "Head":
			bas = bas * Basis.from_euler(_head_tilt)
		n.global_transform = Transform3D(bas, origin)


func _build_accessories() -> void:
	var head := bone_attach("Head")
	# в системе кости: Y вдоль кости, масштаб скелета 1.0; параметры подобраны под модель
	var hair_c := Color.html(look.hair)
	if look.beard > 0:
		_beard_node = Node3D.new()
		head.add_child(_beard_node)
		match look.beard:
			1:   # щетина
				_beard_node.add_child(MU.sphere(0.42, hair_c.lerp(Color.html(look.skin), 0.6), Vector3(0, 0.2, -0.2), Vector3(1.0, 0.5, 1.0)))
			2:   # усы
				_beard_node.add_child(MU.box(Vector3(0.36, 0.07, 0.07), hair_c, Vector3(0, 0.34, -0.4)))
			3:   # борода
				_beard_node.add_child(MU.sphere(0.46, hair_c, Vector3(0, 0.16, -0.2), Vector3(1.02, 0.6, 1.0)))
				_beard_node.add_child(MU.box(Vector3(0.38, 0.07, 0.07), hair_c, Vector3(0, 0.34, -0.4)))
	if look.hat > 0:
		_hat_node = Node3D.new()
		head.add_child(_hat_node)
		var hc := Color.html(look.hat_color)
		match look.hat:
			1:   # кепка
				_hat_node.add_child(MU.cyl(0.43, 0.45, 0.24, hc, Vector3(0, 0.9, 0.0)))
				_hat_node.add_child(MU.box(Vector3(0.6, 0.045, 0.4), hc, Vector3(0, 0.8, -0.46)))
			2:   # вязаная шапка
				_hat_node.add_child(MU.sphere(0.46, hc, Vector3(0, 0.84, 0.0), Vector3(1, 0.95, 1)))
				_hat_node.add_child(MU.cyl(0.46, 0.46, 0.13, hc.darkened(0.2), Vector3(0, 0.75, 0.0)))
			3:   # охотничья шляпа
				_hat_node.add_child(MU.cyl(0.68, 0.68, 0.04, hc.darkened(0.3), Vector3(0, 0.8, 0.0), Vector3.ZERO, 24))
				_hat_node.add_child(MU.cyl(0.38, 0.43, 0.34, hc.darkened(0.3), Vector3(0, 0.98, 0.0)))
		# у «рабочих» моделей шапка уже есть в модели
		if look.body >= 5:
			_hat_node.visible = false


# ---------------------------------------------------------------- анимации
func play(name: String, speed := 1.0, blend := 0.18) -> void:
	if not anim.has_animation(name):
		return
	if name != cur_anim:
		cur_anim = name
		anim_time = 0.0
		anim.play(name, blend)
		anim.seek(0.0, true)
	anim.speed_scale = speed


## Показать кадр анимации на заданном времени (для «замороженных» поз: сидит, мёртв).
func hold(name: String, t: float) -> void:
	if name != cur_anim:
		cur_anim = name
		anim.play(name, 0.2)
	anim.speed_scale = 0.0
	anim.seek(t, true)


func advance(delta: float) -> void:
	_head_tilt = Vector3.ZERO
	if anim.speed_scale > 0.0:
		anim.advance(delta)
		anim_time += delta * anim.speed_scale
	else:
		anim.advance(0.0)
	update_attachments()


func anim_length(name: String) -> float:
	return anim.get_animation(name).length if anim.has_animation(name) else 1.0


# ---------------------------------------------------------------- позы по направлениям
## Направление в системе игрока (вперёд -Z, вправо +X, вверх +Y) -> система скелета.
func _to_skel(d: Vector3) -> Vector3:
	return (skeleton.global_basis.inverse() * (global_basis * d)).normalized()


func point_bone(bone: String, child: String, dir_player: Vector3, amount := 1.0) -> void:
	var bi := skeleton.find_bone(bone)
	var ci := skeleton.find_bone(child)
	if bi < 0 or ci < 0:
		return
	var g := skeleton.get_bone_global_pose(bi)
	var gc := skeleton.get_bone_global_pose(ci)
	var d0 := (gc.origin - g.origin).normalized()
	var t := _to_skel(dir_player)
	if d0.length() < 0.001 or d0.dot(t) > 0.9999:
		return
	var q := Quaternion(d0, t)
	if amount < 1.0:
		q = Quaternion.IDENTITY.slerp(q, amount)
	var ng := Transform3D(Basis(q) * g.basis, g.origin)
	var parent := skeleton.get_bone_parent(bi)
	var pg := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var local := pg.affine_inverse() * ng
	skeleton.set_bone_pose_rotation(bi, local.basis.get_rotation_quaternion())


## side: "R" или "L"; upper_dir/lower_dir — куда смотрят плечо и предплечье.
func pose_arm(side: String, upper_dir: Vector3, lower_dir: Vector3, amount := 1.0) -> void:
	point_bone("UpperArm." + side, "LowerArm." + side, upper_dir, amount)
	point_bone("LowerArm." + side, "Fist." + side, lower_dir, amount)


func tilt_head(pitch: float, yaw := 0.0, roll := 0.0) -> void:
	_head_tilt = Vector3(pitch * 0.9, yaw * 0.9, roll * 0.9)
	var bi := skeleton.find_bone("Head")
	var ni := skeleton.find_bone("Neck")
	var r := Quaternion.from_euler(Vector3(pitch * 0.5, yaw * 0.5, roll * 0.5))
	for b in [bi, ni]:
		skeleton.set_bone_pose_rotation(b, skeleton.get_bone_pose_rotation(b) * r)
	update_attachments()


func fist_world(side: String) -> Vector3:
	var bi := skeleton.find_bone("Fist." + side)
	return skeleton.global_transform * skeleton.get_bone_global_pose(bi).origin


func head_world() -> Vector3:
	var bi := skeleton.find_bone("Head")
	return skeleton.global_transform * skeleton.get_bone_global_pose(bi).origin
