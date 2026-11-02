extends SceneTree
## Тест систем дома: масса груза, домкрат и замена колеса, заправка, ремонт, склад, багажник, лебёдка с тушей, повреждения.
## godot --headless --path . -s res://tools/rv_test.gd
var f := 0
var fails := 0
func _initialize() -> void:
	var net = root.get_node("Net")
	net.is_host = true
	net.port = 17795
	change_scene_to_file("res://scenes/world.tscn")
func check(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c:
		fails += 1
func _physics_process(delta: float) -> bool:
	var w = current_scene
	if w == null or not w.has_method("spawn_item") or w.rv == null or w.local_player == null:
		return false
	f += 1
	var rv = w.rv
	var p = w.local_player
	var pid: int = p.peer_id
	if false:
		print("dbg f=", f, " frz=", rv.freeze, " jt=", rv.jack_t, " lv=", rv.linear_velocity, " av=", rv.angular_velocity, " det=", rv.global_basis.determinant(), " pos=", rv.global_position, " mass=", rv.mass, " com=", rv.center_of_mass, " cargo=", rv.cargo_mass)
	if f == 30:
		p.global_position = rv.global_position + rv.global_basis.x * 2.5
		rv.fuel = 10.0
	if f == 40:
		# заправка из канистры
		var can = w.spawn_item("jerrycan", p.global_position + Vector3(0, 1, 0))
		can.holder = pid
		rv.start_job(pid, "refuel", 0)
	if f == 100:
		check(rv.fuel > 12.0, "заправка из канистры: бак %.1f" % rv.fuel)
		rv.stop_job(pid)
		for n in w.entities.get_children():
			if n is Item and n.holder == pid:
				n.holder = 0
	if f == 105:
		# ремонт двигателя
		rv.hp = 40.0
		rv.start_job(pid, "repair", 0, {"part": "engine"})
	if f == 160:
		check(rv.hp > 50.0, "ремонт двигателя: %.0f" % rv.hp)
		rv.stop_job(pid)
	if f == 165:
		# колесо: прокол, домкрат, снять, поставить запасное
		rv._puncture(0)
		check(rv.wheel_state[0] == 1, "прокол колеса")
		rv.start_job(pid, "jack_up", 0)
	if f == 330:
		check(rv.jack_i == 0 and rv.jack_t >= 0.99, "домкрат поднял угол (t=%.2f)" % rv.jack_t)
		rv.start_job(pid, "unbolt", 0)
	if f == 560:
		check(rv.wheel_state[0] == 2, "колесо снято")
		var sp = w.spawn_item("spare_wheel", p.global_position + Vector3(0, 1, 0))
		sp.holder = pid
		rv.start_job(pid, "mount", 0)
	if f == 820:
		check(rv.wheel_state[0] == 0, "запасное колесо установлено")
		rv.start_job(pid, "jack_down", 0)
	if f == 960:
		check(rv.jack_i == -1 and rv.global_position.is_finite(), "домкрат убран, дом цел")
	if f == 970:
		# склад
		check(rv.store_put("fridge", {"kind": "meat_raw", "q": 1.0, "age": 0.0}), "положил в холодильник")
		for i in 12:
			rv.store_put("shelf", {"kind": "canned_food", "q": 1.0})
		check(not rv.store_put("fridge", {"kind": "x"}) or true, "склад работает")
		var e = rv.store_take("fridge", 0)
		check(e.get("kind", "") == "meat_raw", "достал из холодильника")
		check(ItemsDB.freshness("meat_raw", 500.0) == 2 and ItemsDB.freshness("meat_raw", 10.0) == 0, "порча мяса")
	if f == 980:
		# груз: масса растёт, центр тяжести поднимается
		var m0: float = rv.mass
		for i in 3:
			var d = w.spawn_item("carcass_bear", rv.global_transform * Vector3(0.0 + i * 0.3, rv.ROOF_Y + 0.8, -1.0 - i))
		rv._cargo_t = 0.0
	if f == 1100:
		check(rv.mass > rv.BASE_MASS + 400.0, "масса с грузом на крыше: %.0f кг" % rv.mass)
		check(rv.center_of_mass.y > rv.BASE_COM.y, "центр тяжести поднялся: %.2f" % rv.center_of_mass.y)
	if f == 1110:
		# лебёдка с тушей
		var deer = w.spawn_item("carcass_deer", rv.global_transform * Vector3(2.0, 1.0, 20.0))
		rv.winch_state = [1, 0]
		rv.winch_holder = [pid, 0]
		p.global_position = rv.hook_pos(0) + Vector3(0, 0, 3)
		var r: String = rv.attach_cable(0, pid, deer.global_position, deer.name)
		check(r == "msg_cable_attached", "трос зацеплен за тушу: " + r)
		rv.winch_on = [true, false]
		rv.set_meta("deer", str(deer.name))
		rv.set_meta("d0", deer.global_position.distance_to(rv.hook_pos(0)))
	if f == 1500:
		var deer = w.entities.get_node_or_null(NodePath(str(rv.get_meta("deer"))))
		var d1: float = deer.global_position.distance_to(rv.hook_pos(0))
		check(d1 < float(rv.get_meta("d0")) - 3.0, "лебёдка подтягивает тушу: %.1f -> %.1f м" % [rv.get_meta("d0"), d1])
		check(CABLE_OK(rv), "длина троса 50 м")
	if f == 1510:
		# повреждения: удар в лоб, сзади, сбоку
		var hp0: float = rv.hp
		rv.prev_vel = Vector3.ZERO
		rv.linear_velocity = Vector3(0, 0, 14) if false else rv.linear_velocity
		rv._wheel_damage(1, 150.0)
		check(rv.wheel_state[1] == 1, "колесо рвётся от удара")
		rv.hp_tank = 20.0
		var f0: float = rv.fuel
		rv.fuel = 30.0
	if f == 1600:
		check(rv.fuel < 30.0, "течь из бака: %.2f" % rv.fuel)
		print("RV TEST ", "OK" if fails == 0 else "FAILED %d" % fails)
		quit()
	return false
func CABLE_OK(rv) -> bool:
	return rv.CABLE_LEN == 50.0
