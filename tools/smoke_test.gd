extends SceneTree
## Автотест: запускает мир хостом без окна, гоняет несколько секунд,
## проверяет базовые действия. Запуск:
## godot --headless --path . -s res://tools/smoke_test.gd

var frames := 0
var world: Node


func _initialize() -> void:
	var net = root.get_node("Net")
	net.is_host = true
	net.port = 17777
	change_scene_to_file("res://scenes/world.tscn")


func _process(_d: float) -> bool:
	frames += 1
	world = current_scene
	if world == null or not world.has_method("spawn_item"):
		return false
	var p = world.local_player
	if frames == 30:
		print("players=", world.players.size(), " rv=", world.rv != null, " entities=", world.entities.get_child_count())
	if frames == 60 and p:
		p.inventory.append({"kind": "beer", "q": 1.0})
		p.use_slot(0)
		p.play_emote("dance")
		world.hud.open_inventory(p)
		world.hud.close_menu()
		world.hud.open_shop(p, 0)
		world.hud.close_menu()
		world.req_buy(0, 0)
		world.req_sit(0)
	if frames == 120 and p:
		print("seated=", p.seated, " drunk=", p.drunk, " money=", world.money)
		world.rv_input(1.0, 0.3, 0.0)
	if frames == 200 and p:
		print("rv speed=", world.rv.linear_velocity.length(), " fuel=", world.rv.fuel)
		world.req_exit()
	if frames == 240 and p:
		# стрельба по ближайшему зверю
		var best = null
		for c in world.entities.get_children():
			if c is Animal:
				if best == null or c.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position):
					best = c
		if best:
			var from: Vector3 = best.global_position + Vector3(0, 8, 0) - best.global_basis.x * 6.0
			var to: Vector3 = best.global_position + Vector3(0, best.get_node("HB_heart").position.y, 0)
			world.req_shoot(from, (to - from).normalized(), "338", "shot_big")
			print("shoot at ", best.kind, " dist ", from.distance_to(to))
	if frames == 300:
		var carc := 0
		for c in world.entities.get_children():
			if c is Item and c.kind.begins_with("carcass"):
				carc += 1
		print("carcasses=", carc, " hp=", p.hp if p else -1.0)
		p.start_ragdoll(Vector3(0, 5, 3), 1.0)
	if frames == 241 or frames == 260:
		print("bullets=", world._bullets.size(), " hit_t=", world.hud._hit_t)
	if frames >= 1100 and Time.get_ticks_msec() > 45000:
		print("ragdoll=", p.ragdoll, " pos=", p.global_position)
		print("SMOKE OK")
		quit()
	return false
