extends SceneTree
## Тест клиента: подключается к хосту на 127.0.0.1:17777.
var frames := 0

func _initialize() -> void:
	var net = root.get_node("Net")
	net.is_host = false
	net.ip = "127.0.0.1"
	net.port = 17777
	net.nick = "Клиент"
	change_scene_to_file("res://scenes/world.tscn")

func _process(_d: float) -> bool:
	frames += 1
	var w = current_scene
	if frames % 100 == 0 and w and w.has_method("spawn_item"):
		var n_items := 0
		for c in w.entities.get_children():
			if c is Item: n_items += 1
		print("[client] f=", frames, " players=", w.players.size(), " ents=", w.entities.get_child_count(), " items=", n_items, " me=", w.local_player != null, " money=", w.money)
		if frames == 300 and w.local_player:
			w.rpc_id(1, "req_door")
			w.local_player.play_emote("wave")
	if frames == 600:
		var p = w.local_player
		if p: print("[client] seated=", p.seated)
		quit()
	return false
