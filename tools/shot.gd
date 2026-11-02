extends SceneTree
## Снимок экрана: godot --path . -s res://tools/shot.gd -- scene=res://scenes/main_menu.tscn out=/tmp/x.png frames=60
var f := 0
var out := "/tmp/shot.png"
var frames := 60
func _initialize() -> void:
	var scene := "res://scenes/main_menu.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="): scene = a.substr(6)
		if a.begins_with("out="): out = a.substr(4)
		if a.begins_with("frames="): frames = int(a.substr(7))
	change_scene_to_file(scene)
func _process(_d: float) -> bool:
	f += 1
	if f == frames:
		var img := root.get_texture().get_image()
		img.save_png(out)
		print("saved ", out, " ", img.get_size())
		quit()
	return false
