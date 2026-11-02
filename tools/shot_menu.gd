extends SceneTree
## Снимок главного меню / редактора персонажа: -- mode=menu|look out=/tmp/x.png
var f := 0
var mode := "menu"
var out := "/tmp/menu.png"
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="): mode = a.substr(5)
		if a.begins_with("out="): out = a.substr(4)
	change_scene_to_file("res://scenes/main_menu.tscn")
func _process(_d: float) -> bool:
	f += 1
	if f == 10 and mode == "look":
		var m = current_scene
		var l := Look.new()
		l.body = 0; l.beard = 3; l.hat = 3; l.hair = "6b4423"; l.hat_color = "7a5a30"
		root.get_node("Net").look = l
		m.look = l
		m._build_preview()
		m._open_look()
	if f == 119 and current_scene.get("cam") != null:
		var m = current_scene
		print("cam ", m.cam.position, " fov ", m.cam.fov, " h ", m.cam.h_offset, " prev ", m.preview.global_position, " rot ", m.preview.rotation.y, " cm scale ", m.preview_cm.scale)
	if f == 120:
		root.get_texture().get_image().save_png(out)
		print("saved ", out)
		quit()
	return false
