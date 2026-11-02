class_name ItemIcons
extends Node
## Иконки предметов для рюкзака: модель предмета рисуется один раз в отдельном
## SubViewport и кэшируется как текстура.

const SIZE := 128

var cache: Dictionary = {}          # kind -> ImageTexture
var waiting: Dictionary = {}        # kind -> Array[TextureRect]
var queue: Array = []
var vp: SubViewport
var cam: Camera3D
var holder: Node3D
var busy := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	vp = SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)
	for k in ItemsDB.ITEMS:
		queue.append(k)
	_run.call_deferred()


## Заполняет TextureRect иконкой (если она ещё рисуется — позже).
func request(kind: String, tr: TextureRect) -> void:
	if cache.has(kind):
		tr.texture = cache[kind]
		return
	if vp == null:
		return
	if not waiting.has(kind):
		waiting[kind] = []
	waiting[kind].append(tr)
	if not queue.has(kind):
		queue.push_front(kind)


func _bounds(n: Node3D, xf: Transform3D, box: Array) -> void:
	var t := xf * n.transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var bb := t * (n as MeshInstance3D).mesh.get_aabb()
		box[0] = bb if not box[1] else (box[0] as AABB).merge(bb)
		box[1] = true
	for c in n.get_children():
		if c is Node3D:
			_bounds(c, t, box)


func _run() -> void:
	while true:
		if queue.is_empty():
			await get_tree().process_frame
			continue
		var kind: String = queue.pop_front()
		if cache.has(kind):
			continue
		for c in holder.get_children():
			c.queue_free()
		var v := ItemsDB.build_visual(kind)
		holder.add_child(v)
		v.rotation_degrees = Vector3(0, 35, 0)
		if kind.begins_with("weapon_") or kind.begins_with("att_") or kind in ["knife", "wrench", "hammer"]:
			v.rotation_degrees = Vector3(0, 95, 0)   # длинные вещи — боком к камере
		var box := [AABB(), false]
		_bounds(v, Transform3D.IDENTITY, box)
		var bb: AABB = box[0]
		var c := bb.get_center()
		var r := maxf(bb.size.length() * 0.55, 0.1)
		cam.size = r * 2.0
		cam.global_position = c + Vector3(0.6, 0.7, 1.0).normalized() * 5.0
		cam.look_at(c, Vector3.UP)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await get_tree().process_frame
		await get_tree().process_frame
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			cache[kind] = ImageTexture.create_from_image(img)
			for tr in waiting.get(kind, []):
				if is_instance_valid(tr):
					tr.texture = cache[kind]
			waiting.erase(kind)
