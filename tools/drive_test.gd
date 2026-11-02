extends SceneTree
## Тест езды: хост садится за руль и едет с переключением передач.
var f := 0
func _initialize() -> void:
	root.get_node("Net").port = 17779
	change_scene_to_file("res://scenes/world.tscn")
func _physics_process(_d: float) -> bool:
	var w = current_scene
	if w == null or not w.has_method("spawn_item") or w.rv == null or w.local_player == null:
		return false
	f += 1
	var rv = w.rv
	if f == 10:
		w.req_sit(0)
	if f > 20:
		w.rv_input(1.0, 0.0 if f < 900 else 0.4, 0.0)
	if f in [200, 400, 600]:
		w.req_gear(1)
	if f % 120 == 0:
		print("f=", f, " gear=", rv.gear_name(), " rpm=", int(rv.rpm), " v=", snappedf(rv.linear_velocity.length() * 3.6, 0.1), "kmh up=", snappedf(rv.global_basis.y.y, 0.01), " hp=", int(rv.hp), " fuel=", snappedf(rv.fuel, 0.1))
	if f == 1000:
		print("winch: ", rv.press_button("lights"))
	if f == 1300:
		quit()
	return false
