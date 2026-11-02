extends SceneTree
## Обзор моделей из папки: -- dir=res://assets/models/animals out=/tmp/a.png h=1.0
var f := 0
var out := "/tmp/assets.png"
var dir := "res://assets/models/animals"
var h := 1.0
var only := ""
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		if a.begins_with("dir="): dir = a.substr(4)
		if a.begins_with("h="): h = float(a.substr(2))
		if a.begins_with("only="): only = a.substr(5)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.55, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); root.add_child(sun)
	var i := 0
	var names: Array = []
	for fn in DirAccess.get_files_at(dir):
		if not (fn.ends_with(".gltf") or fn.ends_with(".glb")):
			continue
		if only != "" and not fn.get_basename() in only.split(","):
			continue
		names.append(fn)
		var ps: PackedScene = load(dir + "/" + fn)
		var n: Node3D = ps.instantiate()
		var holder := Node3D.new()
		holder.add_child(n)
		root.add_child(holder)
		var bb := A3._aabb(n)
		var s := h / maxf(bb.size.y, 0.001)
		n.scale = Vector3.ONE * s
		n.position = -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z) * s
		holder.position = Vector3((i % 7) * 1.6 * h, 0, -(i / 7) * 2.0 * h)
		holder.rotation_degrees.y = 60
		var lbl := Label3D.new(); lbl.text = fn.get_basename(); lbl.pixel_size = 0.004 * h; lbl.position = Vector3(0, -0.15 * h, 0.6 * h); holder.add_child(lbl)
		var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			for an in ap.get_animation_list():
				if an.to_lower() in ["walk", "running"]:
					ap.play(an)
					ap.seek(0.3, true)
		print(fn, " ", bb.size, " anims: ", (n.find_child("AnimationPlayer", true, false) as AnimationPlayer).get_animation_list() if n.find_child("AnimationPlayer", true, false) else [])
		i += 1
	var cam := Camera3D.new()
	root.add_child(cam)
	var cols := mini(i, 7)
	var rows := (i + 6) / 7
	var cx := (cols - 1) * 0.8 * h
	cam.fov = 40.0
	cam.look_at_from_position(Vector3(cx, 1.2 * h + rows * 0.5 * h, 1.5 * h + cols * 0.9 * h + rows * 1.2 * h), Vector3(cx, 0.3 * h, -(rows - 1) * 1.0 * h))
func _process(_d: float) -> bool:
	f += 1
	if f == 20:
		root.get_texture().get_image().save_png(out)
		quit()
	return false
