extends Node3D
## Корень игровой сцены. Хранит общее состояние, принимает запросы игроков
## (хост проверяет и исполняет) и рассылает события.

const LOOT_PREFIX := ["carcass_", "meat_", "hide", "rabbit_foot"]

var entities: Node3D
var spawner: MultiplayerSpawner
var hud: Hud
var rv: RV
var local_player: Player
var players := {}

# общее состояние (истина — у хоста)
var money := 150
var game_time := 7.5
var day := 1
var raining := false

# статичный мир
var shop_spawns: Array = []
var sell_areas: Array = []
var heat_sources: Array = []
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D

# хост
var _counter := 0
var _cooking: Array = []
var _bullets: Array = []
var _state_t := 0.0
var _weather_t := 240.0
var _pop_t := 5.0
var _sell_t := 0.0
var _colors_used := 0

# эффекты
var rain_fx: CPUParticles3D
var rain_snd: AudioStreamPlayer
var amb_snd: AudioStreamPlayer
var night_snd: AudioStreamPlayer
var grass: MultiMeshInstance3D
var _grass_center := Vector3(1e9, 0, 0)
var _blood: Array = []
var _blood_mesh: Mesh
var _blood_mat: Material
var spectator_cam: Camera3D


func _ready() -> void:
	TerrainGen.init_data()
	WorldBuilder.build(self)
	entities = Node3D.new()
	entities.name = "Entities"
	add_child(entities)
	entities.child_entered_tree.connect(_on_entity_added)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	spawner.spawn_path = NodePath("../Entities")
	spawner.spawn_function = _spawn_entity
	add_child(spawner)
	hud = Hud.new()
	hud.name = "Hud"
	hud.world = self
	add_child(hud)
	_build_fx()
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	spectator_cam = Camera3D.new()
	spectator_cam.far = 1500
	add_child(spectator_cam)
	var o: Dictionary = TerrainGen.outposts[0]
	spectator_cam.position = Vector3(o.pos.x + 30, o.h + 25, o.pos.y + 50)
	spectator_cam.look_at_from_position(spectator_cam.position, Vector3(o.pos.x, o.h, o.pos.y))
	spectator_cam.current = true

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)
	var err: Error = Net.start_peer()
	if err != OK:
		Net.leave.call_deferred(T.t("err_start", [error_string(err)]))
		return
	if multiplayer.is_server():
		_server_start()
	else:
		hud.add_msg(T.t("msg_connecting", [Net.ip, Net.port]))


# ======================================================================= СПАВН
func _spawn_entity(data: Variant) -> Node:
	var d: Dictionary = data
	match d.t:
		"player":
			var p := Player.new()
			p.setup(d)
			return p
		"rv":
			var r := RV.new()
			r.setup(d)
			return r
		"animal":
			var a := Animal.new()
			a.setup(d)
			return a
		"item":
			var it := Item.new()
			it.setup(d)
			return it
	return Node.new()


func _on_entity_added(n: Node) -> void:
	if n is Player:
		players[n.peer_id] = n
		n.tree_exiting.connect(func(): players.erase(n.peer_id))
		if n.peer_id != multiplayer.get_unique_id():
			hud.add_msg(T.t("msg_joined", [n.nick]))
	elif n is RV:
		rv = n


func _next_name(prefix: String) -> String:
	_counter += 1
	return "%s%d" % [prefix, _counter]


func spawn_item(kind: String, pos: Vector3, vel := Vector3.ZERO, q := 1.0) -> Item:
	if not multiplayer.is_server():
		return null
	var it: Item = spawner.spawn({"t": "item", "kind": kind, "pos": pos, "q": q, "name": _next_name("I")})
	it.linear_velocity = vel
	it.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3)) * minf(vel.length(), 1.0)
	return it


func _server_start() -> void:
	var o: Dictionary = TerrainGen.outposts[0]
	var c := Vector3(o.pos.x, o.h, o.pos.y)
	# дом ставим на дорогу, мордой вдоль неё
	var seg: Array = TerrainGen.roads[0]
	var rdir: Vector2 = (seg[1] - seg[0]).normalized()
	var rp: Vector2 = seg[0] + rdir * (float(o.r) - 6.0)
	spawner.spawn({"t": "rv", "pos": Vector3(rp.x, TerrainGen.height_at(rp.x, rp.y) + 1.4, rp.y), "yaw": atan2(rdir.x, rdir.y)})
	_populate(true)
	var shelf := c + Vector3(-12.0, 1.5, -6.5)
	for k in ["canned_food", "canned_food", "water_bottle", "water_bottle", "water_bottle", "bandage", "cigarettes", "beer", "firewood"]:
		spawn_item(k, shelf + Vector3(randf_range(-1.5, 1.5), randf_range(0, 0.5), randf_range(-0.3, 0.3)), Vector3.ZERO, 10.0 if k == "cigarettes" else 1.0)
	spawn_item("jerrycan", c + Vector3(9.0, 0.5, -7.5))
	spawn_item("jack", c + Vector3(8.0, 0.5, -8.2))
	spawn_item("spare_wheel", c + Vector3(10.5, 0.5, -8.0))
	spawn_item("repair_kit", c + Vector3(8.5, 0.5, -6.6))
	_register(1, Net.nick, Net.look.to_string_code())
	hud.add_msg(T.t("msg_hosting", [Net.port]))


func _register(id: int, nick: String, look: String = "") -> void:
	if players.has(id):
		return
	var p := get_respawn_point() + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	spawner.spawn({"t": "player", "id": id, "nick": nick.substr(0, 16), "color": _colors_used % 4, "pos": p, "look": look.substr(0, 80)})
	_colors_used += 1
	if id != 1:
		rpc_id(id, "recv_state", money, game_time, day, raining)


func get_respawn_point() -> Vector3:
	if rv:
		var p := rv.global_position - rv.global_basis.x * 3.4 + rv.global_basis.z * 0.8
		return Vector3(p.x, TerrainGen.height_at(p.x, p.z) + 0.3, p.z)
	var o: Dictionary = TerrainGen.outposts[0]
	return Vector3(o.pos.x + 2, o.h + 0.5, o.pos.y + 12)


func _random_land(min_player_dist: float) -> Vector3:
	for i in 40:
		var x := randf_range(-320, 320)
		var z := randf_range(-320, 320)
		if not TerrainGen.is_land(x, z, 1.0):
			continue
		if TerrainGen.normal_at(x, z).y < 0.8:
			continue
		var p := Vector3(x, TerrainGen.height_at(x, z), z)
		var ok := true
		for o in TerrainGen.outposts:
			if Vector2(x, z).distance_to(o.pos) < 60.0:
				ok = false
		for pl in players.values():
			if pl.global_position.distance_to(p) < min_player_dist:
				ok = false
		if ok:
			return p
	return Vector3.INF


func _populate(initial: bool) -> void:
	var counts := {}
	for k in ItemsDB.ANIMALS:
		counts[k] = 0
	for c in entities.get_children():
		if c is Animal and not c.is_queued_for_deletion():
			counts[c.kind] += 1
	for k in ItemsDB.ANIMALS:
		var missing: int = int(ItemsDB.ANIMALS[k].count) - int(counts[k])
		var n := missing if initial else mini(missing, 1)
		for i in n:
			var p := _random_land(90.0)
			if p != Vector3.INF:
				spawner.spawn({"t": "animal", "kind": k, "pos": p, "name": _next_name("A")})


# ======================================================================= СЕТЬ
func _on_peer_connected(id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var p: Node = players.get(id)
	if p:
		broadcast(T.t("msg_left", [p.nick]))
		p.queue_free()
	if rv:
		var s: Array = rv.seats.duplicate()
		for i in 4:
			if s[i] == id:
				s[i] = 0
		rv.seats = s
	var held := get_held_item(id)
	if held:
		held.holder = 0


func _on_connected() -> void:
	rpc_id(1, "register_player", Net.nick, Net.look.to_string_code())


func _on_failed() -> void:
	Net.leave(T.t("err_connect_failed"))


func _on_server_lost() -> void:
	Net.leave(T.t("err_host_left"))


func _sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return s if s != 0 else multiplayer.get_unique_id()


@rpc("any_peer", "reliable")
func register_player(nick: String, look: String = "") -> void:
	if multiplayer.is_server():
		_register(_sender(), nick, look)


@rpc("authority", "call_remote", "unreliable_ordered")
func recv_state(m: int, t: float, d: int, r: bool) -> void:
	money = m
	game_time = t
	day = d
	raining = r


func _push_state() -> void:
	rpc("recv_state", money, game_time, day, raining)


@rpc("any_peer", "call_local", "reliable")
func show_msg(text: String) -> void:
	hud.add_msg(text)


func broadcast(text: String) -> void:
	rpc("show_msg", text)


func tell(pid: int, text: String) -> void:
	rpc_id(pid, "show_msg", text)


@rpc("any_peer", "call_local", "unreliable")
func play_sfx(sname: String, pos: Vector3, vol: float, pitch: float) -> void:
	Sfx.play_at(sname, pos, vol, pitch)


func sfx_all(sname: String, pos: Vector3, vol := 0.0, pitch := 1.0) -> void:
	rpc("play_sfx", sname, pos, vol, pitch)


# ======================================================================= ЗАПРОСЫ ИГРОКОВ (исполняет хост)
func get_player(id: int) -> Node:
	return players.get(id)


func get_held_item(pid: int) -> Node:
	for c in entities.get_children():
		if c is Item and c.holder == pid and not c.is_queued_for_deletion():
			return c
	return null


func nearest_player(pos: Vector3) -> Array:
	var best: Node = null
	var bd := 1e9
	for p in players.values():
		if p.dead:
			continue
		var d: float = p.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = p
	return [best, bd]


func _item_near(item_name: String, p: Node, maxd: float) -> Item:
	var it := entities.get_node_or_null(item_name) as Item
	if it == null or it.is_queued_for_deletion() or p == null:
		return null
	if it.global_position.distance_to(p.global_position) > maxd:
		return null
	return it


@rpc("any_peer", "call_local", "reliable")
func req_grab(item_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sid := _sender()
	var p := get_player(sid)
	var it := _item_near(item_name, p, 5.0)
	if it == null or it.holder != 0 or get_held_item(sid) != null:
		return
	it.holder = sid
	_set_holding(sid, true)


@rpc("any_peer", "call_local", "reliable")
func req_pickup(item_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sid := _sender()
	var p := get_player(sid)
	var it := _item_near(item_name, p, 5.0)
	if it == null or (it.holder != 0 and it.holder != sid):
		return
	var kind := it.kind
	var q := it.q
	it.queue_free()
	p.rpc_id(sid, "inv_add", kind, q)


@rpc("any_peer", "call_local", "reliable")
func req_drop() -> void:
	if not multiplayer.is_server():
		return
	var sid := _sender()
	var it := get_held_item(sid)
	if it:
		it.holder = 0
	_set_holding(sid, false)


@rpc("any_peer", "call_local", "reliable")
func req_throw(dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sid := _sender()
	var it: Item = get_held_item(sid)
	if it:
		it.holder = 0
		it.linear_velocity = dir.normalized() * clampf(70.0 / it.mass, 3.0, 13.0)
		it.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	_set_holding(sid, false)


func _set_holding(pid: int, v: bool) -> void:
	var p := get_player(pid)
	if p:
		p.rpc_id(pid, "set_holding", v)


@rpc("any_peer", "call_local", "reliable")
func req_spawn_item(kind: String, q: float, pos: Vector3, vel: Vector3) -> void:
	if multiplayer.is_server() and ItemsDB.ITEMS.has(kind):
		spawn_item(kind, pos, vel, q)


@rpc("any_peer", "call_local", "reliable")
func req_poo_pile(pos: Vector3) -> void:
	if multiplayer.is_server():
		spawn_item("poo", pos + Vector3.UP * 0.2)


@rpc("any_peer", "call_local", "reliable")
func req_death_penalty() -> void:
	if not multiplayer.is_server():
		return
	var loss := int(money * 0.15)
	money -= loss
	_push_state()
	var sid := _sender()
	var held := get_held_item(sid)
	if held:
		held.holder = 0


@rpc("any_peer", "call_local", "reliable")
func req_sell_inv(entries: Array) -> void:
	if not multiplayer.is_server():
		return
	var total := 0
	for e in entries:
		var k: String = e[0]
		if ItemsDB.ITEMS.has(k):
			total += int(round(float(ItemsDB.ITEMS[k].price) * float(e[1])))
	if total > 0:
		money += total
		_push_state()
		var p := get_player(_sender())
		sfx_all("cash", p.global_position if p else Vector3.ZERO, 0.0, 1.0)
		broadcast(T.t("msg_sold", [p.nick if p else "?", total]))


func is_loot(kind: String) -> bool:
	for pre in LOOT_PREFIX:
		if kind.begins_with(pre):
			return true
	return false


@rpc("any_peer", "call_local", "reliable")
func req_station(path: NodePath, inv_kind: String) -> void:
	if not multiplayer.is_server():
		return
	var sid := _sender()
	var p := get_player(sid)
	var st := get_node_or_null(path) as Node3D
	if p == null or st == null or not st.has_meta("kind"):
		return
	if st.global_position.distance_to(p.global_position) > 7.0:
		return
	var kind: String = st.get_meta("kind")
	var held: Item = get_held_item(sid)
	match kind:
		"rv_butcher", "butcher":
			if held and held.kind.begins_with("carcass_"):
				_butcher(held, st)
			else:
				tell(sid, T.t("prompt_need_carcass"))
		"rv_stove", "campfire":
			if held and held.kind == "firewood":
				held.queue_free()
				sfx_all("fire_whoosh", st.global_position, 0.0, 1.0)
				_boost_fire(st)
				if kind == "rv_stove" and rv:
					rv.stove_t = minf(rv.stove_t + 240.0, 720.0)
			elif inv_kind == "meat_raw":
				_cooking.append({"node": st, "t": 7.0, "burn": 25.0})
				sfx_all("sizzle", st.global_position, 0.0, 1.0)
		"rv_engine":
			if inv_kind == "repair_kit" and rv:
				rv.hp = minf(rv.hp + 50.0, 100.0)
				sfx_all("repair", st.global_position, 0.0, 1.0)
				broadcast(T.t("msg_repaired", [p.nick, int(rv.hp)]))
		"rv_fuel":
			if held and held.kind == "jerrycan" and rv:
				held.queue_free()
				rv.fuel = minf(rv.fuel + 40.0, rv.max_fuel)
				sfx_all("fuel", st.global_position, 0.0, 1.0)
				broadcast(T.t("msg_refueled_can", [p.nick]))
		"pump":
			_pump(sid, st)
		"sell_bin":
			tell(sid, T.t("prompt_sell_bin"))


func _boost_fire(st: Node3D) -> void:
	var l := st.get_node_or_null("../Light") as OmniLight3D
	if l == null:
		l = st.get_parent().get_node_or_null("Light") as OmniLight3D
	if l:
		l.light_energy = 4.0


func _butcher(held: Item, st: Node3D) -> void:
	var out: Array = ItemsDB.BUTCHER.get(held.kind, [])
	var q := held.q
	var pos := st.global_position + Vector3.UP * 1.0
	held.queue_free()
	for e in out:
		var n := int(e[1])
		if e[0] == "meat_raw":
			n = maxi(int(round(n * q)), 1)
		for i in n:
			spawn_item(e[0], pos + Vector3(randf_range(-0.3, 0.3), i * 0.15, randf_range(-0.3, 0.3)), Vector3(randf_range(-1.5, 1.5), 3.5, randf_range(-1.5, 1.5)))
	sfx_all("butcher", pos, 0.0, 1.0)
	rpc("fx_burst", pos, 0)


func _pump(sid: int, st: Node3D) -> void:
	if rv == null or rv.global_position.distance_to(st.global_position) > 14.0:
		tell(sid, T.t("msg_bring_rv"))
		return
	var need := rv.max_fuel - rv.fuel
	if need < 1.0:
		tell(sid, T.t("msg_tank_full"))
		return
	var liters := minf(need, float(money) / ItemsDB.FUEL_PRICE)
	if liters < 1.0:
		tell(sid, T.t("msg_no_money"))
		return
	var cost := int(ceil(liters * ItemsDB.FUEL_PRICE))
	money -= cost
	rv.fuel += liters
	_push_state()
	sfx_all("fuel", st.global_position, 0.0, 1.0)
	broadcast(T.t("msg_pumped", [int(liters), cost]))


@rpc("any_peer", "call_local", "reliable")
func req_buy(idx: int, shop_idx: int) -> void:
	if not multiplayer.is_server() or idx < 0 or idx >= ItemsDB.SHOP.size():
		return
	var sid := _sender()
	var p := get_player(sid)
	if p == null:
		return
	var e: Dictionary = ItemsDB.SHOP[idx]
	var price := shop_price(idx)
	if price < 0:
		tell(sid, T.t("msg_max_level"))
		return
	if money < price:
		tell(sid, T.t("msg_no_money"))
		return
	match e.type:
		"item":
			var sp: Vector3 = shop_spawns[clampi(shop_idx, 0, shop_spawns.size() - 1)]
			spawn_item(e.key, sp + Vector3(randf_range(-1, 1), 0.3, 0), Vector3(0, 1, 1.5), float(e.get("q", 1.0)))
		"ammo":
			p.rpc_id(sid, "add_ammo", e.ammo, int(e.amount))
		"weapon":
			p.rpc_id(sid, "give_weapon", e.weapon)
		"upgrade":
			if rv == null or not rv.apply_upgrade(e.up):
				tell(sid, T.t("msg_max_level"))
				return
			broadcast(T.t("msg_upgraded", [p.nick, T.t("shop_" + e.key)]))
	money -= price
	_push_state()
	sfx_all("cash", p.global_position, -2.0, 1.0)


func shop_price(idx: int) -> int:
	var e: Dictionary = ItemsDB.SHOP[idx]
	if e.type == "upgrade":
		var lvl: int = rv.upgrade_level(e.up) if rv else 0
		var prices: Array = e.prices
		if lvl >= prices.size():
			return -1
		return int(prices[lvl])
	return int(e.price)


# --- дом на колёсах
func _near_rv(p: Node, dist := 9.0) -> bool:
	return p != null and rv != null and p.global_position.distance_to(rv.global_position) < dist


@rpc("any_peer", "call_local", "reliable")
func req_sit(i: int) -> void:
	if not multiplayer.is_server() or rv == null or i < 0 or i > 3:
		return
	var sid := _sender()
	var p := get_player(sid)
	if not _near_rv(p):
		return
	if rv.is_flipped():
		rv.flip_upright()
		sfx_all("crash", rv.global_position, 0.0, 0.7)
		broadcast(T.t("msg_flipped", [p.nick]))
		return
	var s: Array = rv.seats.duplicate()
	if s[i] != 0 and s[i] != sid:
		tell(sid, T.t("prompt_seat_taken"))
		return
	var cur := s.find(sid)
	if cur >= 0:
		s[cur] = 0
	s[i] = sid
	rv.seats = s
	var held := get_held_item(sid)
	if held:
		held.holder = 0
		_set_holding(sid, false)
	sfx_all("door", rv.global_position, -6.0, 1.2)


@rpc("any_peer", "call_local", "reliable")
func req_exit() -> void:
	if not multiplayer.is_server() or rv == null:
		return
	var sid := _sender()
	var s: Array = rv.seats.duplicate()
	var i := s.find(sid)
	if i >= 0:
		s[i] = 0
		rv.seats = s
		sfx_all("door", rv.global_position, -8.0, 1.3)


@rpc("any_peer", "call_local", "reliable")
func req_seat(i: int) -> void:
	req_sit(i)


@rpc("any_peer", "call_local", "unreliable_ordered")
func rv_input(t: float, s: float, b: float) -> void:
	if multiplayer.is_server() and rv and rv.seats[0] == _sender():
		rv.set_input(t, s, b)


@rpc("any_peer", "call_local", "reliable")
func req_gear(g: int) -> void:
	if multiplayer.is_server() and rv and rv.seats[0] == _sender():
		rv.set_gear(g)


@rpc("any_peer", "call_local", "reliable")
func req_button(action: String) -> void:
	if not multiplayer.is_server() or rv == null:
		return
	var sid := _sender()
	if rv.seats.find(sid) < 0 or not action in ["winch_front", "winch_rear", "lights", "horn"]:
		return
	var res := rv.press_button(action)
	if action == "horn":
		for c in entities.get_children():
			if c is Animal and c.global_position.distance_to(rv.global_position) < 50.0:
				c.flee(rv.global_position, 6.0)
	if res != "":
		tell(sid, T.t(res))


@rpc("any_peer", "call_local", "reliable")
func req_hook(i: int) -> void:
	if not multiplayer.is_server() or rv == null or i < 0 or i > 1:
		return
	var sid := _sender()
	var p := get_player(sid)
	if p == null or p.global_position.distance_to(rv.hook_pos(i)) > 3.5:
		return
	var res := rv.hook_action(i, sid)
	if res != "":
		tell(sid, T.t(res))


@rpc("any_peer", "call_local", "reliable")
func req_attach(i: int, point: Vector3, item_name := "") -> void:
	if not multiplayer.is_server() or rv == null or i < 0 or i > 1:
		return
	var sid := _sender()
	var p := get_player(sid)
	if p == null or p.global_position.distance_to(point) > 8.0:
		return
	var res := rv.attach_cable(i, sid, point, item_name)
	if res != "":
		tell(sid, T.t(res))


@rpc("any_peer", "call_local", "unreliable")
func req_push(pos: Vector3, force: Vector3) -> void:
	if multiplayer.is_server() and rv and force.length() < 3000.0:
		var p := get_player(_sender())
		if p and p.global_position.distance_to(pos) < 3.0:
			rv.apply_impulse(force * 0.1, pos - rv.global_position)


@rpc("any_peer", "call_local", "reliable")
func req_horn() -> void:
	if multiplayer.is_server() and rv:
		sfx_all("horn", rv.global_position, 4.0, 1.0)
		for c in entities.get_children():
			if c is Animal and c.global_position.distance_to(rv.global_position) < 50.0:
				c.flee(rv.global_position, 6.0)


# ======================================================================= СТРЕЛЬБА (баллистика у хоста)
@rpc("any_peer", "call_local", "reliable")
func req_shoot(origin: Vector3, dir: Vector3, ammo_kind: String, snd: String) -> void:
	if not multiplayer.is_server() or not ItemsDB.AMMO.has(ammo_kind):
		return
	var sid := _sender()
	var a: Dictionary = ItemsDB.AMMO[ammo_kind]
	for i in int(a.pellets):
		var spread := deg_to_rad(float(a.spread))
		var d := dir.normalized()
		var ax := d.cross(Vector3.UP)
		if ax.length() < 0.01:
			ax = Vector3.RIGHT
		d = d.rotated(ax.normalized(), randf_range(-spread, spread))
		d = d.rotated(Vector3.UP, randf_range(-spread, spread))
		_bullets.append({"pos": origin, "vel": d * float(a.speed), "v0": float(a.speed), "ammo": ammo_kind,
			"pen": float(a.pen), "t": 0.0, "shooter": sid, "hit": []})
	sfx_all(snd, origin, 4.0, randf_range(0.95, 1.05))
	rpc("fx_muzzle", origin, dir)
	# звери в округе пугаются
	for c in entities.get_children():
		if c is Animal and c.global_position.distance_to(origin) < 120.0:
			c.alarm(origin, sid)


func _step_bullets(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var keep: Array = []
	for b in _bullets:
		var a: Dictionary = ItemsDB.AMMO[b.ammo]
		var vel: Vector3 = b.vel
		vel.y -= 9.8 * delta
		vel *= 1.0 - float(a.drag)
		var from: Vector3 = b.pos
		var to: Vector3 = from + vel * delta
		b.vel = vel
		b.t += delta
		var alive := _trace_segment(space, b, from, to)
		b.pos = to
		if alive and b.t < 2.5 and vel.length() > 60.0:
			keep.append(b)
	_bullets = keep


## Трассирует отрезок пути пули. Возвращает false, если пуля остановилась.
func _trace_segment(space: PhysicsDirectSpaceState3D, b: Dictionary, from: Vector3, to: Vector3) -> bool:
	var a: Dictionary = ItemsDB.AMMO[b.ammo]
	var energy_k := pow(b.vel.length() / float(b.v0), 2.0)
	var excl: Array = []
	var shooter: Node = get_player(b.shooter)
	if shooter:
		excl.append(shooter.get_rid())
	var animal_zones := {}   # Animal -> [zones]
	var first_animal_pos := {}
	var stopped := false
	var stop_pos := to
	for i in 10:
		var q := PhysicsRayQueryParameters3D.create(from, to, MU.L_WORLD | MU.L_ITEMS | MU.L_RV | MU.L_ANIMALS | MU.L_PLAYERS, excl)
		q.collide_with_areas = true
		var r := space.intersect_ray(q)
		if r.is_empty():
			break
		var col: Object = r.collider
		excl.append(r.rid)
		if col is Area3D and col.has_meta("zone"):
			var an: Node = col.get_parent()
			if an in b.hit:
				continue
			if not animal_zones.has(an):
				animal_zones[an] = []
				first_animal_pos[an] = r.position
			animal_zones[an].append(col.get_meta("zone"))
			continue
		# твёрдое препятствие
		stop_pos = r.position
		stopped = true
		if col is Item:
			col.apply_impulse(b.vel.normalized() * float(a.dmg) * 0.06 * energy_k, r.position - col.global_position)
			rpc("fx_hit", r.position, 0)
		elif col is RV:
			col.hp = maxf(col.hp - 1.0, 0.0)
			rpc("fx_hit", r.position, 2)
		elif col is Player:
			var dmg := float(a.dmg) * energy_k * 0.35
			col.rpc_id(col.peer_id, "get_hit", b.vel.normalized() * 4.0, dmg, 0.15 * dmg / 20.0)
			rpc("fx_hit", r.position, 1)
			broadcast(T.t("msg_friendly_fire", [shooter.nick if shooter else "?", col.nick]))
		else:
			rpc("fx_hit", r.position, 0)
		break
	# применяем попадания по зверям (только тех, что ближе точки остановки)
	for an in animal_zones:
		if not is_instance_valid(an) or an.is_queued_for_deletion():
			continue
		if stopped and from.distance_to(first_animal_pos[an]) > from.distance_to(stop_pos):
			continue
		b.hit.append(an)
		var armor := float(ItemsDB.ANIMALS[an.kind].armor)
		var pen := float(b.pen) * sqrt(energy_k)
		var hit_pos: Vector3 = first_animal_pos[an]
		var res := ""
		if pen < armor:
			# не пробил шкуру/кость
			res = "nopen"
			an.hp -= float(a.dmg) * 0.05
			an.alarm(from, b.shooter)
			sfx_all("ricochet", hit_pos, 0.0, 1.0)
			rpc("fx_hit", hit_pos, 0)
			b.pen = 0.0
		else:
			var zones: Array = animal_zones[an]
			# пуля, потерявшая пробитие внутри, не дойдёт до глубоких зон
			if pen - armor < 0.6:
				zones = zones.filter(func(z): return z == "muscle" or z == "leg" or z == "head")
				if zones.is_empty():
					zones = ["muscle"]
			res = an.apply_hit(zones, float(a.dmg) * energy_k, b.shooter, from)
			rpc("fx_hit", hit_pos, 1)
			b.pen = pen - armor - 1.0
		if b.shooter != 0:
			rpc_id(b.shooter, "hit_marker", res)
		if b.pen <= 0.0:
			return false
	return not stopped


@rpc("authority", "call_local", "reliable")
func hit_marker(res: String) -> void:
	hud.show_hit(res)


# ======================================================================= ЦИКЛ
func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	if multiplayer.is_server():
		_server_tick(delta)


func _server_tick(delta: float) -> void:
	_step_bullets(delta)
	game_time += delta / 60.0      # 1 игровой час = 1 минута
	if game_time >= 24.0:
		game_time -= 24.0
		day += 1
		broadcast(T.t("msg_new_day", [day]))
	_weather_t -= delta
	if _weather_t <= 0.0:
		raining = not raining and randf() < 0.6
		_weather_t = randf_range(120.0, 240.0) if raining else randf_range(180.0, 420.0)
		if raining:
			broadcast(T.t("msg_rain"))
		_push_state()
	_state_t -= delta
	if _state_t <= 0.0:
		_state_t = 0.5
		_push_state()
	_pop_t -= delta
	if _pop_t <= 0.0:
		_pop_t = 8.0
		_populate(false)
	# готовка
	for c in _cooking.duplicate():
		c.t -= delta
		if c.t <= 0.0:
			_cooking.erase(c)
			if is_instance_valid(c.node):
				var pos: Vector3 = c.node.global_position + Vector3.UP * 0.6
				spawn_item("meat_burnt" if randf() < 0.1 else "meat_cooked", pos, Vector3(randf_range(-1, 1), 3.0, randf_range(-1, 1)))
				sfx_all("pop", pos, 0.0, 1.0)
	# скупка
	_sell_t -= delta
	if _sell_t <= 0.0:
		_sell_t = 0.5
		for a in sell_areas:
			for body in a.get_overlapping_bodies():
				if body is Item and body.holder == 0 and not body.is_queued_for_deletion():
					var price := int(round(float(ItemsDB.ITEMS[body.kind].price) * (body.q if body.kind.begins_with("carcass_") else 1.0)))
					money += price
					body.queue_free()
					sfx_all("cash", a.global_position, 0.0, 1.0)
					broadcast(T.t("msg_bin_sold", [ItemsDB.item_name(body.kind), price]))
					_push_state()


var _thermo_t := 0.0


func _process(delta: float) -> void:
	_update_sky(delta)
	_update_fx(delta)
	if local_player and local_player.cam:
		if not local_player.cam.current:
			local_player.cam.current = true
	hud.update_hud(local_player)
	_thermo_t -= delta
	if _thermo_t <= 0.0:
		_thermo_t = 1.0
		get_tree().call_group("thermo", "set_temp", ambient_temp())


# ======================================================================= ПОГОДА, ВРЕМЯ, ТЕПЛО
func is_day() -> bool:
	return game_time >= 6.0 and game_time < 20.5


func ambient_temp() -> float:
	var t := 8.0 + 9.0 * sin((game_time - 9.0) / 24.0 * TAU)
	if raining:
		t -= 5.0
	return t


func heat_at(pos: Vector3) -> float:
	var h := 0.0
	for f in heat_sources:
		var d: float = (f as Node3D).global_position.distance_to(pos)
		if d < 5.0:
			h = maxf(h, 1.0 - d / 5.0 * 0.7)
	if rv and rv.heat_radius() > 0.0:
		var d2 := rv.global_position.distance_to(pos)
		if d2 < rv.heat_radius():
			h = maxf(h, 0.8)
	return h


func _update_sky(delta: float) -> void:
	if sun == null:
		return
	var f := (game_time - 6.0) / 14.5
	var day_k := clampf(sin(clampf(f, 0.0, 1.0) * PI), 0.0, 1.0)
	if is_day():
		sun.rotation = Vector3(-lerpf(0.08, PI - 0.08, clampf(f, 0.0, 1.0)), deg_to_rad(-35.0), 0)
		sun.light_color = Color(1.0, 0.75, 0.55).lerp(Color(1.0, 0.97, 0.9), clampf(day_k * 1.6, 0, 1))
		sun.light_energy = 0.25 + day_k * 1.05
	else:
		sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(150.0), 0)
		sun.light_color = Color(0.55, 0.65, 0.9)
		sun.light_energy = 0.12
	var rain_k := 0.55 if raining else 1.0
	sun.light_energy *= rain_k
	var night := 1.0 - day_k if is_day() else 1.0
	var top := Color(0.32, 0.5, 0.78).lerp(Color(0.02, 0.03, 0.08), night)
	var hor := Color(0.75, 0.78, 0.8).lerp(Color(0.06, 0.07, 0.12), night)
	if is_day() and (f < 0.12 or f > 0.88):
		hor = hor.lerp(Color(0.95, 0.55, 0.3), 0.5)
	if raining:
		top = top.lerp(Color(0.35, 0.37, 0.4) * (1.0 - night * 0.8), 0.7)
		hor = hor.lerp(Color(0.45, 0.47, 0.5) * (1.0 - night * 0.8), 0.7)
	sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(top, clampf(delta * 2.0, 0, 1))
	sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(hor, clampf(delta * 2.0, 0, 1))
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color.darkened(0.2)
	env.ambient_light_energy = lerpf(0.15, 0.9, 1.0 - night) * (0.8 if raining else 1.0)
	env.fog_light_color = sky_mat.sky_horizon_color
	env.fog_density = lerpf(env.fog_density, (0.007 if raining else 0.0025) / Settings.view_dist, clampf(delta, 0, 1))


func _apply_settings() -> void:
	if env:
		env.ssao_enabled = Settings.ssao
	if sun:
		sun.shadow_enabled = Settings.shadows > 0
		sun.directional_shadow_max_distance = 160.0 if Settings.shadows >= 2 else 70.0
	if grass:
		grass.visible = Settings.grass
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.far = 1500.0 * Settings.view_dist


func _build_fx() -> void:
	rain_fx = CPUParticles3D.new()
	rain_fx.amount = 1600
	rain_fx.lifetime = 1.0
	rain_fx.emitting = false
	rain_fx.local_coords = false
	rain_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_fx.emission_box_extents = Vector3(22, 1, 22)
	rain_fx.direction = Vector3(0.1, -1, 0)
	rain_fx.spread = 3.0
	rain_fx.gravity = Vector3(0, -12, 0)
	rain_fx.initial_velocity_min = 16.0
	rain_fx.initial_velocity_max = 20.0
	var rm := BoxMesh.new()
	rm.size = Vector3(0.012, 0.45, 0.012)
	rm.material = MU.mat(Color(0.7, 0.75, 0.85, 0.4), 0.1)
	rain_fx.mesh = rm
	add_child(rain_fx)
	rain_snd = _loop_player("rain", -60.0)
	amb_snd = _loop_player("ambience", -14.0)
	night_snd = _loop_player("night", -60.0)
	# трава вокруг камеры
	grass = MultiMeshInstance3D.new()
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _grass_mesh()
	grass.multimesh = mm
	add_child(grass)
	# кровь
	var bm := CylinderMesh.new()
	bm.top_radius = 0.12
	bm.bottom_radius = 0.12
	bm.height = 0.01
	bm.radial_segments = 8
	_blood_mesh = bm
	_blood_mat = MU.mat(Color(0.35, 0.02, 0.02), 0.4)


func _loop_player(sname: String, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = Sfx.get_stream(sname)
	p.volume_db = vol
	p.autoplay = true
	p.bus = "Ambient"
	add_child(p)
	return p


func _grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 7:
		var a := rng.randf() * TAU
		var off := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		var h := rng.randf_range(0.3, 0.6)
		var side := Vector3(cos(a), 0, sin(a)) * 0.035
		var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
		st.set_normal(Vector3.UP)
		st.add_vertex(off - side)
		st.add_vertex(off + side)
		st.add_vertex(off + lean + Vector3(0, h, 0))
	var m := st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/grass.gdshader")
	m.surface_set_material(0, sm)
	return m


func _current_cam() -> Camera3D:
	return get_viewport().get_camera_3d()


func _update_fx(delta: float) -> void:
	var cam := _current_cam()
	if cam == null:
		return
	var cp := cam.global_position
	rain_fx.emitting = raining
	rain_fx.global_position = cp + Vector3(0, 12, 0)
	var indoor := local_player != null and (local_player.seated >= 0 or (local_player.ride and local_player.ride_xf.origin.y < 3.0))
	rain_snd.volume_db = lerpf(rain_snd.volume_db, (-8.0 if not indoor else -18.0) if raining else -60.0, clampf(delta, 0, 1))
	amb_snd.volume_db = lerpf(amb_snd.volume_db, -14.0 if is_day() and not raining else -60.0, clampf(delta, 0, 1))
	night_snd.volume_db = lerpf(night_snd.volume_db, -12.0 if not is_day() else -60.0, clampf(delta, 0, 1))
	if Vector2(cp.x, cp.z).distance_to(Vector2(_grass_center.x, _grass_center.z)) > 8.0:
		_rebuild_grass(cp)
	# кровь испаряется
	while _blood.size() > 250:
		var b: Node = _blood.pop_front()
		if is_instance_valid(b):
			b.queue_free()


func _rebuild_grass(center: Vector3) -> void:
	_grass_center = center
	var xfs: Array = []
	var spacing := 0.9
	var r := 32.0
	var cx := int(floor(center.x / spacing))
	var cz := int(floor(center.z / spacing))
	var cells := int(r / spacing)
	for iz in range(-cells, cells + 1):
		for ix in range(-cells, cells + 1):
			if ix * ix + iz * iz > cells * cells:
				continue
			var gx := cx + ix
			var gz := cz + iz
			var hsh := absi((gx * 73856093) ^ (gz * 19349663)) % 1000
			if hsh < 280:
				continue
			var x := gx * spacing + (hsh % 37) / 37.0 * spacing
			var z := gz * spacing + (hsh % 53) / 53.0 * spacing
			var h := TerrainGen.height_at(x, z)
			if h < TerrainGen.WATER + 0.7 or h > 70.0:
				continue
			if TerrainGen.normal_at(x, z).y < 0.82:
				continue
			var s := 0.7 + (hsh % 10) * 0.07
			xfs.append(Transform3D(Basis(Vector3.UP, hsh * 0.37).scaled(Vector3(s, s, s)), Vector3(x, h - 0.03, z)))
	var mm := grass.multimesh
	mm.instance_count = 0
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])


func add_blood(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _blood_mesh
	mi.material_override = _blood_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var h := TerrainGen.height_at(pos.x, pos.z)
	mi.global_position = Vector3(pos.x + randf_range(-0.2, 0.2), maxf(h, pos.y) + 0.02, pos.z + randf_range(-0.2, 0.2))
	var s := randf_range(0.5, 1.4)
	mi.scale = Vector3(s, 1, s * randf_range(0.6, 1.0))
	mi.rotation.y = randf() * TAU
	_blood.append(mi)


@rpc("authority", "call_local", "unreliable")
func fx_hit(pos: Vector3, kind: int) -> void:
	# 0 — пыль/щепки, 1 — кровь, 2 — искры по металлу
	var colors := [Color(0.45, 0.38, 0.28), Color(0.5, 0.02, 0.02), Color(1.0, 0.85, 0.4)]
	_burst(pos, colors[kind], 10 if kind != 1 else 16, 0.04)
	if kind == 1:
		add_blood(pos)
	elif kind == 0:
		Sfx.play_at("impact", pos, -6.0, randf_range(0.8, 1.2))


@rpc("authority", "call_local", "unreliable")
func fx_burst(pos: Vector3, kind: int) -> void:
	_burst(pos, Color(0.55, 0.05, 0.05), 40, 0.06)
	if kind == 1:
		_burst(pos, Color(0.5, 0.4, 0.3), 30, 0.05)   # клочья шерсти
	for i in 4:
		add_blood(pos + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))


@rpc("authority", "call_local", "unreliable")
func fx_muzzle(pos: Vector3, dir: Vector3) -> void:
	_burst(pos + dir * 0.1, Color(1.0, 0.75, 0.3), 8, 0.03, 4.0)
	_burst(pos + dir * 0.2, Color(0.7, 0.7, 0.7, 0.5), 10, 0.06)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.3)
	l.light_energy = 6.0
	l.omni_range = 6.0
	add_child(l)
	l.global_position = pos
	get_tree().create_timer(0.06).timeout.connect(l.queue_free)


func _burst(pos: Vector3, c: Color, n: int, size: float, emit := 0.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = n
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9, 0)
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = MU.mat(c, 1.0, emit)
	p.mesh = m
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


# --- длительные работы с домом (удержание E): заправка, ремонт, домкрат, колёса
@rpc("any_peer", "call_local", "reliable")
func req_work(kind: String, idx: int, on: bool, extra: Dictionary = {}) -> void:
	if not multiplayer.is_server() or rv == null:
		return
	var sid := _sender()
	if not on:
		rv.stop_job(sid)
		return
	var p := get_player(sid)
	if p == null or not kind in ["refuel", "pump", "repair", "unbolt", "mount", "jack_up", "jack_down"]:
		return
	if kind != "pump" and not _near_rv(p, 9.0):
		return
	rv.start_job(sid, kind, idx, extra)


var _pump_acc := 0.0


## Колонка: льёт в канистру в руках или в бак дома рядом.
func pump_tick(pid: int, dt: float, extra: Dictionary) -> bool:
	var p := get_player(pid)
	if p == null:
		return false
	var held := get_held_item(pid) as Item
	var liters := 0.0
	if held != null and held.kind == "jerrycan":
		liters = minf(5.0 * dt, (1.0 - held.q) * RV.CAN_LITERS)
		if liters <= 0.01:
			tell(pid, T.t("msg_can_full") if T.t("msg_can_full") != "msg_can_full" else T.t("msg_tank_full"))
			return false
	else:
		if rv == null or rv.global_position.distance_to(extra.get("pos", rv.global_position)) > 14.0:
			tell(pid, T.t("msg_bring_rv"))
			return false
		liters = minf(6.0 * dt, rv.max_fuel - rv.fuel)
		if liters <= 0.01:
			tell(pid, T.t("msg_tank_full"))
			return false
	_pump_acc += liters * ItemsDB.FUEL_PRICE
	var whole := int(_pump_acc)
	if whole > 0:
		if money < whole:
			tell(pid, T.t("msg_no_money"))
			_pump_acc = 0.0
			return false
		money -= whole
		_pump_acc -= whole
		_push_state()
	if held != null and held.kind == "jerrycan":
		held.q = minf(held.q + liters / RV.CAN_LITERS, 1.0)
	else:
		rv.fuel += liters
	return true


# --- склад дома: холодильник, стеллаж, шкафчик
@rpc("any_peer", "call_local", "reliable")
func req_store(key: String, op: String, entry: Dictionary, idx: int) -> void:
	if not multiplayer.is_server() or rv == null:
		return
	var sid := _sender()
	var p := get_player(sid)
	if not _near_rv(p, 9.0):
		return
	if op == "put":
		if not ItemsDB.ITEMS.has(str(entry.get("kind", ""))) or not rv.store_put(key, {"kind": entry.kind, "q": float(entry.get("q", 1.0)), "age": float(entry.get("age", 0.0))}):
			tell(sid, T.t("msg_store_full"))
			p.rpc_id(sid, "recv_store_item", entry)   # вернуть обратно
		else:
			sfx_all("click", rv.global_position, -4.0, 0.9)
	elif op == "take":
		var e := rv.store_take(key, idx)
		if not e.is_empty():
			p.rpc_id(sid, "recv_store_item", e)
			sfx_all("click", rv.global_position, -4.0, 1.2)


# --- багажник на крыше
@rpc("any_peer", "call_local", "reliable")
func req_rack() -> void:
	if not multiplayer.is_server() or rv == null:
		return
	var sid := _sender()
	var p := get_player(sid)
	var held := get_held_item(sid) as Item
	if p == null or held == null or not ItemsDB.ITEMS[held.kind].get("big", false) or not _near_rv(p, 9.0):
		return
	var pos := rv.rack_free_slot()
	if pos == Vector3.INF:
		tell(sid, T.t("msg_rack_full"))
		return
	held.holder = 0
	_set_holding(sid, false)
	held.global_position = pos
	held.linear_velocity = rv.linear_velocity
	held.angular_velocity = Vector3.ZERO
	held.global_rotation = Vector3(0, rv.global_rotation.y, 0)
	sfx_all("thud", pos, 0.0, 1.0)
	tell(sid, T.t("msg_rack_placed"))
