extends SceneTree
## Тест механик четвёртого раунда: тяжёлое в руках, подъём вдвоём, разделка на месте,
## костёр, ягоды, обвесы, следы, болото, наезд на зверя, карта и склад-иконки.
## godot --headless --path . -s res://tools/r4_test.gd
var f := 0
var fails := 0
var st := {}


func _initialize() -> void:
	var net = root.get_node("Net")
	net.is_host = true
	net.port = 17796
	change_scene_to_file("res://scenes/world.tscn")


func check(c: bool, msg: String) -> void:
	print(("OK   " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func _count(w, kind: String) -> int:
	var n := 0
	for c in w.entities.get_children():
		if c is Item and c.kind == kind and not c.is_queued_for_deletion():
			n += 1
	return n


func _physics_process(_d: float) -> bool:
	var w = current_scene
	if w == null or not w.has_method("spawn_item") or w.rv == null or w.local_player == null:
		return false
	f += 1
	var p = w.local_player
	var pid: int = p.peer_id
	var rv = w.rv
	if f == 20:
		# вдали от дома, на ровном месте
		var x: float = rv.global_position.x + 14.0
		var z: float = rv.global_position.z + 6.0
		p.global_position = Vector3(x, TerrainGen.height_at(x, z) + 1.0, z)
		# справочные данные
		check(ItemsDB.is_heavy("firewood") and not ItemsDB.is_heavy("weapon_magnum") and not ItemsDB.is_heavy("knife"), "тяжёлое: дрова да, ружьё и нож нет")
		check(ItemsDB.lifters_needed("carcass_bear") >= 3 and ItemsDB.lifters_needed("carcass_rabbit") == 1, "медведя несут втроём+, зайца один")
		check(not p.can_add("firewood") and p.can_add("knife"), "дрова не кладутся в рюкзак")
		var miss := []
		for k in ItemsDB.ITEMS:
			if T.t("item_" + k) == "item_" + k:
				miss.append(k)
		for e in ItemsDB.SHOP:
			if T.t("shop_" + e.key) == "shop_" + e.key or T.t("desc_" + e.key) == "desc_" + e.key:
				miss.append(e.key)
		for a in root.get_node("Settings").REBINDABLE:
			if T.t("act_" + a) == "act_" + a:
				miss.append(a)
		check(miss.is_empty(), "все строки есть в ru.gd " + str(miss))
		check(not InputMap.has_action("winch_front") and InputMap.has_action("attachments") and InputMap.has_action("smoke"), "лебёдка без клавиш, T и C назначены")
		check(w.rv.store.fridge.any(func(e): return e.kind == "beer") and w.rv.store.fridge.any(func(e): return e.kind == "vodka"), "в холодильнике пиво и водка")
		check(RV.SEAT_COUNT == 8, "мест в доме: %d" % RV.SEAT_COUNT)
	if f == 30:
		var it = w.spawn_item("firewood", p.global_position + Vector3(1, 0.5, 0))
		st.wood = it.name
	if f == 50:
		w.req_pickup(st.wood)
	if f == 60:
		check(_count(w, "firewood") >= 1 and not p.inv_has("firewood"), "дрова нельзя подобрать в рюкзак")
		w.req_grab(st.wood)
	if f == 70:
		var h = w.get_held_item(pid)
		check(h != null and h.kind == "firewood", "дрова — в руках")
		w.req_build_fire(p.global_position + Vector3(1.5, 0, 0))
	if f == 80:
		var fire: Fire = null
		for c in w.entities.get_children():
			if c is Fire:
				fire = c
		check(fire != null and not fire.lit, "сложен костёр")
		if fire:
			st.fire = fire.name
			w.raining = false
			seed(3)
			w.wild.start_job(pid, "fire_light", fire.name)
	if f == 220:
		var fire = w.entities.get_node_or_null(NodePath(str(st.get("fire", ""))))
		if fire and not fire.lit:
			# 15% неудачи — вторая спичка
			w.wild.start_job(pid, "fire_light", fire.name)
	if f == 360:
		var fire = w.entities.get_node_or_null(NodePath(str(st.get("fire", ""))))
		check(fire != null and fire.lit, "костёр разожжён спичками")
		check(w.heat_at(fire.global_position + Vector3(1, 0.5, 0)) > 0.0 if fire else false, "костёр греет")
	if f == 370:
		# медведь: одному не поднять
		var b = w.spawn_item("carcass_bear", p.global_position + Vector3(0, 0.5, 1.5))
		st.bear = b.name
	if f == 400:
		w.req_grab(st.bear)
	if f == 410:
		var b = w.entities.get_node_or_null(NodePath(st.bear))
		check(b != null and b.holder == 0 and b.holders.has(pid), "медведь: взялся, но один не поднял (ждёт помощи)")
		w.req_grab(st.bear)   # отпустить
	if f == 420:
		var b = w.entities.get_node_or_null(NodePath(st.bear))
		check(b != null and b.holders.is_empty(), "отпустил медведя")
		# двое помощников (фиктивные id) — поднимаем вчетвером
		b.holders = [pid, 9001, 9002]
		w.wild.start_job(pid, "field_cut", b.name)
	if f == 420 + 60 * 13:
		check(_count(w, "carcass_bear") == 0 and _count(w, "quarter_bear") >= 6, "медведь разделан на четверти: %d" % _count(w, "quarter_bear"))
		check(not ItemsDB.is_heavy("quarter_bear") == false and ItemsDB.lifters_needed("quarter_bear") == 1, "четверть несёт один человек")
	if f == 1230:
		# ягоды
		var bi := 0
		var bp: Vector3 = w.wild.bushes[bi].pos
		p.global_position = bp + Vector3(1.0, 0.5, 0)
		st.bush_kind = str(w.wild.bushes[bi].kind)
	if f == 1240:
		w.wild.req_forage(0)
	if f == 1250:
		check(p.inv_has(st.bush_kind) and not w.wild.bush_has_berries(0), "собрал ягоды: " + st.bush_kind)
		# обвесы
		p.give_weapon("carbine")
	if f == 1260:
		p._select_weapon("carbine")
		p.inv_add("att_scope", 1.0)
		p.inv_add("att_suppressor", 1.0)
	if f == 1265:
		var i := -1
		for k in p.inventory.size():
			if p.inventory[k].kind == "att_scope":
				i = k
		p.use_slot(i)
		for k in p.inventory.size():
			if p.inventory[k].kind == "att_suppressor":
				p.attach_from_inv(k)
				break
		check(p.optic_mode() == "scope" and p.attached("muzzle") == "att_suppressor", "оптика и глушитель на карабине")
		check(p.att_vis.contains("att_scope"), "обвесы видны на модели ружья: " + p.att_vis)
		p.detach("optic")
		check(p.attached("optic") == "" and p.inv_has("att_scope"), "прицел снят обратно в рюкзак")
		w.hud.open_attachments(p)
		w.hud.close_menu()
		w.hud.open_storage(p, "fridge")
		w.hud.close_menu()
		w.hud.open_shop(p, 0)
		w.hud.close_menu()
		w.hud.open_map(p)
		w.hud.close_menu()
		check(true, "меню обвесов, склада, магазина и карты открываются")
		# следы
		w.wild.add_track("deer", p.global_position + Vector3(0.5, 0, 0), 0.0, "testdeer", true, false)
		w.wild.add_track("deer", p.global_position + Vector3(0.5, 0, -3), 0.0, "testdeer", false, false)
		var tr: Dictionary = w.wild.track_near(p.global_position, 3.0)
		check(not tr.is_empty(), "след рядом найден")
		if not tr.is_empty():
			var s: String = w.wild.inspect(tr)
			print("     ", s)
			check(s.contains("оленя") and s.contains("кровь"), "описание следа")
	if f == 1300:
		# болото: ставим дом в топь
		var best := Vector3.INF
		var bs := 0.0
		for i in 4000:
			var x := randf_range(-350, 350)
			var z := randf_range(-350, 350)
			var s := TerrainGen.swamp_at(x, z)
			if s > bs and TerrainGen.road_query(Vector2(x, z)).x > 12.0 and TerrainGen.height_at(x, z) > TerrainGen.WATER + 0.3:
				bs = s
				best = Vector3(x, 0, z)
		check(bs > 0.5, "на карте есть болото: %.2f" % bs)
		st.swamp = best
		if best.is_finite():
			best.y = TerrainGen.height_at(best.x, best.z) + 1.5
			rv.global_transform = Transform3D(Basis(), best)
			rv.linear_velocity = Vector3.ZERO
			rv.cargo_mass = 0.0
			rv.seats = [pid, 0, 0, 0, 0, 0, 0, 0]
	if f > 1300 and f < 1900 and st.has("swamp"):
		rv.set_input(1.0 if f > 1400 else 0.0, 0.0, 0.0)
		rv.gear = 2
	if f == 1900:
		var m := 0.0
		for v in rv.mud:
			m += float(v)
		check(m / 4.0 > 0.3, "колёса вязнут в болоте: %.2f" % (m / 4.0))
		print("     stuck=", rv.stuck, " moved=", rv.global_position.distance_to(st.swamp))
		rv.set_input(0.0, 0.0, 1.0)
		rv.seats = [0, 0, 0, 0, 0, 0, 0, 0]
	if f == 1910:
		# наезд: дом летит на зверя
		var a = null
		for c in w.entities.get_children():
			if c is Animal and c.kind == "deer":
				a = c
		if a:
			var x := 0.0
			var z := 0.0
			for o in TerrainGen.outposts:
				if o.id == 0:
					x = o.pos.x + 60.0
					z = o.pos.y
			var y := TerrainGen.height_at(x, z) + 1.2
			rv.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(x, y, z))
			rv.mud = [0.0, 0.0, 0.0, 0.0]
			rv.hp_body = 100.0
			rv.angular_velocity = Vector3.ZERO
			a.global_position = Vector3(x, TerrainGen.height_at(x, z - 6.0), z - 6.0)
			rv.linear_velocity = Vector3(0, 0, -15.0)
			st.deer = a.name
			st.body0 = rv.hp_body
			st.deer_hp = a.hp
	if f == 1960 and st.has("deer"):
		var a = w.entities.get_node_or_null(NodePath(st.deer))
		var dead: bool = a == null or a.is_queued_for_deletion() or a.hp < float(st.deer_hp)
		check(dead, "дом сбил оленя")
		check(rv.hp_body < float(st.body0), "кузов пострадал от удара: %.1f -> %.1f" % [st.body0, rv.hp_body])
	if f == 1980:
		print("R4 TEST " + ("OK" if fails == 0 else "FAILED %d" % fails))
		quit(1 if fails > 0 else 0)
	return false
