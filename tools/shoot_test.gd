extends SceneTree
## Тест стрельбы из всех калибров в разные стороны.
var f := 0
func _initialize() -> void:
	root.get_node("Net").port = 17781
	change_scene_to_file("res://scenes/world.tscn")
func _physics_process(_d: float) -> bool:
	var w = current_scene
	if w == null or not w.has_method("spawn_item") or w.local_player == null:
		return false
	f += 1
	var p = w.local_player
	var o: Vector3 = p.global_position + Vector3.UP * 1.5
	if f == 5:
		# через игрока: стреляем как игрок
		p.cur_weapon = "double"
		p.aiming = true
		p.mag["double"] = 2
		Input.action_press("shoot")
	if f == 6:
		p._on_shoot_pressed()
		Input.action_release("shoot")
	if f > 10 and f < 60:
		var dirs := [Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3(1, -0.2, 0), Vector3(0.0001, 1, 0)]
		for d in dirs:
			for a in ["12shot", "12slug", "22lr", "308", "338"]:
				w.req_shoot(o, d, a, "shot_shotgun")
	if f % 20 == 0:
		print("f=", f, " bullets=", w._bullets.size())
	if f == 200:
		print("SHOOT OK")
		quit()
	return false
