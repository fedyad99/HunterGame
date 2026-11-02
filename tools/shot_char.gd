extends SceneTree
## Снимок персонажей: -- out=/tmp/c.png pose=idle|walk|aim|wave|eat|sit
var f := 0
var out := "/tmp/char.png"
var pose := "idle"
var models: Array = []
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		if a.begins_with("pose="): pose = a.substr(5)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.3, 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new(); we.environment = env; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); root.add_child(sun)
	for i in 7:
		var l := Look.new()
		l.body = i
		l.skin = Look.SKIN_TONES[i % 6]
		l.hair = Look.HAIR_COLORS[i]
		l.beard = i % 4
		l.hat = (i + 1) % 4
		var m := CharModel.new()
		m.position = Vector3((i - 3) * 0.9, 0, 0)
		root.add_child(m)
		m.build(l)
		models.append(m)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.0, -3.3), Vector3(0, 0.9, 0))
func _process(d: float) -> bool:
	f += 1
	for m in models:
		match pose:
			"walk": m.play("Walk")
			"sit": m.hold("SitDown", 0.9)
			_: m.play("Idle")
		m.advance(d)
		match pose:
			"aim":
				m.pose_arm("R", Vector3(0, 0.05, -1), Vector3(0, 0.05, -1))
				m.pose_arm("L", Vector3(-0.2, 0, -1), Vector3(0.3, 0.1, -1))
			"wave":
				m.pose_arm("R", Vector3(0.7, 0.7, 0), Vector3(0.2, 1, 0))
			"eat":
				m.pose_arm("R", Vector3(0.3, -0.5, -0.7), Vector3(-0.2, 0.8, -0.6))
				m.tilt_head(0.2)
	if f == 39:
		var h: Node3D = models[0].bone_attach("Head")
		print("HEAD ", h.global_position, " child ", h.get_child(0).get_child(0).global_position, " ", h.get_child(0).get_child(0).visible, " ", h.get_child(0).get_child(0).mesh)
	if f == 40:
		var img := root.get_texture().get_image()
		img.save_png(out)
		print("saved ", out)
		quit()
	return false
