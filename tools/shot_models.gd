extends SceneTree
## Обзор моделей: -- out=/tmp/m.png
var f := 0
var out := "/tmp/models.png"
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.55, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); root.add_child(sun)
	var names := DirAccess.get_directories_at("res://assets/models")
	var i := 0
	for n in names:
		var m := A3.model(n, 0.9)
		m.position = Vector3(i * 1.4, 0, 0)
		root.add_child(m)
		i += 1
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(i * 0.7 - 0.7, 1.6, 6.5), Vector3(i * 0.7 - 0.7, 0.4, 0))
	print(names)
func _process(_d: float) -> bool:
	f += 1
	if f == 20:
		root.get_texture().get_image().save_png(out)
		quit()
	return false
