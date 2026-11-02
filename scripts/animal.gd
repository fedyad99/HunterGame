class_name Animal
extends Node3D
## Животное. ИИ и попадания считаются только у хоста.
## Хитбоксы — набор Area3D с зонами (мозг, сердце, лёгкие, мышцы, ноги).

# множитель урона и скорость кровотечения (ед. здоровья/с при пуле ~80 урона)
const ZONES := {
	"brain": {"mult": 6.0, "bleed": 0.0},
	"heart": {"mult": 4.0, "bleed": 22.0},
	"lungs": {"mult": 2.2, "bleed": 8.0},
	"head": {"mult": 1.0, "bleed": 2.0},
	"muscle": {"mult": 0.5, "bleed": 1.2},
	"leg": {"mult": 0.35, "bleed": 0.9},
}

var kind := "deer"
var sync_xform := Transform3D()
var bleeding := false
var hp := 50.0
var max_hp := 50.0
var bleed := 0.0
var leg_hit := 0.0
var state := "idle"
var state_t := 0.0
var dir := Vector3.FORWARD
var yaw := 0.0
var flee_from := Vector3.ZERO
var target_id := 0
var call_t := 0.0
var last_overkill := 0.0
var world: Node
var vis: Node3D
var legs: Array = []
var anim_phase := 0.0
var last_pos := Vector3.ZERO
var _blood_t := 0.0


func setup(data: Dictionary) -> void:
	kind = data.kind
	name = data.name
	position = data.pos
	yaw = randf() * TAU
	rotation.y = yaw
	sync_xform = Transform3D(Basis(Vector3.UP, yaw), data.pos)
	var d: Dictionary = ItemsDB.ANIMALS[kind]
	max_hp = float(d.hp)
	hp = max_hp
	_build_hitboxes(d.size)
	_build_visual(d.size)
	add_child(MU.make_sync(["sync_xform", "bleeding"], 0.05))


func _hitbox(nm: String, zone: String, shape: Shape3D, pos: Vector3) -> void:
	var a := Area3D.new()
	a.name = nm
	a.collision_layer = MU.L_ANIMALS
	a.collision_mask = 0
	a.monitoring = false
	a.set_meta("zone", zone)
	a.set_meta("animal", true)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	a.add_child(cs)
	a.position = pos
	add_child(a)


func _build_hitboxes(s: Vector3) -> void:
	var w := s.x
	var h := s.y
	var l := s.z
	var b := BoxShape3D.new()
	b.size = Vector3(w, h * 0.45, l * 0.8)
	_hitbox("HB_body", "muscle", b, Vector3(0, h * 0.62, 0))
	var lb := BoxShape3D.new()
	lb.size = Vector3(w * 0.6, h * 0.24, l * 0.26)
	_hitbox("HB_lungs", "lungs", lb, Vector3(0, h * 0.66, -l * 0.2))
	var hs := SphereShape3D.new()
	hs.radius = minf(w, h) * 0.13
	_hitbox("HB_heart", "heart", hs, Vector3(0, h * 0.56, -l * 0.27))
	var head := SphereShape3D.new()
	head.radius = w * 0.4
	var head_pos := Vector3(0, h * 0.86, -l * 0.55)
	if kind == "boar" or kind == "bear":
		head_pos = Vector3(0, h * 0.68, -l * 0.55)
	_hitbox("HB_head", "head", head, head_pos)
	var brain := SphereShape3D.new()
	brain.radius = w * 0.17
	_hitbox("HB_brain", "brain", brain, head_pos + Vector3(0, w * 0.05, w * 0.05))
	var lg := BoxShape3D.new()
	lg.size = Vector3(w, h * 0.4, l * 0.75)
	_hitbox("HB_legs", "leg", lg, Vector3(0, h * 0.2, 0))


func _build_visual(s: Vector3) -> void:
	vis = Node3D.new()
	vis.name = "Vis"
	add_child(vis)
	var w := s.x
	var h := s.y
	var l := s.z
	match kind:
		"deer":
			var fur := Color(0.52, 0.35, 0.2)
			var belly := Color(0.85, 0.78, 0.65)
			vis.add_child(MU.capsule(w * 0.48, l * 0.95, fur, Vector3(0, h * 0.62, 0), Vector3(90, 0, 0)))
			vis.add_child(MU.sphere(w * 0.32, belly, Vector3(0, h * 0.62, l * 0.43)))       # белое «зеркало»
			vis.add_child(MU.capsule(w * 0.17, h * 0.42, fur, Vector3(0, h * 0.82, -l * 0.42), Vector3(-35, 0, 0)))
			vis.add_child(MU.capsule(w * 0.2, w * 0.75, fur.darkened(0.05), Vector3(0, h * 0.95, -l * 0.6), Vector3(70, 0, 0)))
			vis.add_child(MU.sphere(w * 0.07, Color(0.05, 0.05, 0.05), Vector3(0, h * 0.9, -l * 0.78)))
			for e in [-1, 1]:
				vis.add_child(MU.box(Vector3(0.03, 0.14, 0.07), fur, Vector3(e * w * 0.2, h * 1.07, -l * 0.55), Vector3(0, 0, e * 35)))
				# рога
				vis.add_child(MU.cyl(0.012, 0.022, 0.42, Color(0.8, 0.75, 0.6), Vector3(e * 0.08, h * 1.2, -l * 0.55), Vector3(-15, 0, e * 25)))
				vis.add_child(MU.cyl(0.01, 0.015, 0.2, Color(0.8, 0.75, 0.6), Vector3(e * 0.16, h * 1.3, -l * 0.62), Vector3(-60, 0, e * 30)))
			_legs(w, h, l, fur.darkened(0.15), h * 0.5, 0.05)
		"rabbit":
			var fur := Color(0.55, 0.5, 0.43)
			vis.add_child(MU.sphere(w * 0.5, fur, Vector3(0, h * 0.5, 0.02), Vector3(1, 1, 1.35)))
			vis.add_child(MU.sphere(w * 0.32, fur, Vector3(0, h * 0.75, -l * 0.38)))
			vis.add_child(MU.sphere(w * 0.15, Color(0.95, 0.95, 0.95), Vector3(0, h * 0.6, l * 0.42)))
			for e in [-1, 1]:
				vis.add_child(MU.box(Vector3(0.035, 0.2, 0.06), fur, Vector3(e * 0.04, h * 1.05, -l * 0.33), Vector3(-15, 0, e * 10)))
				vis.add_child(MU.sphere(0.018, Color(0.05, 0.05, 0.05), Vector3(e * 0.06, h * 0.8, -l * 0.5)))
			_legs(w, h, l, fur.darkened(0.1), h * 0.25, 0.03)
		"boar":
			var fur := Color(0.2, 0.16, 0.12)
			vis.add_child(MU.capsule(w * 0.5, l * 0.95, fur, Vector3(0, h * 0.6, 0), Vector3(90, 0, 0)))
			vis.add_child(MU.box(Vector3(0.05, h * 0.25, l * 0.6), fur.darkened(0.3), Vector3(0, h * 0.9, -l * 0.05)))   # щетина
			vis.add_child(MU.cyl(w * 0.18, w * 0.38, l * 0.4, fur, Vector3(0, h * 0.55, -l * 0.6), Vector3(-95, 0, 0)))
			vis.add_child(MU.cyl(w * 0.15, w * 0.15, 0.04, Color(0.35, 0.25, 0.22), Vector3(0, h * 0.53, -l * 0.81), Vector3(90, 0, 0)))
			for e in [-1, 1]:
				vis.add_child(MU.cyl(0.0, 0.02, 0.13, Color(0.95, 0.92, 0.8), Vector3(e * 0.08, h * 0.5, -l * 0.74), Vector3(-30, 0, e * -20)))
				vis.add_child(MU.box(Vector3(0.04, 0.1, 0.08), fur, Vector3(e * 0.12, h * 0.8, -l * 0.48), Vector3(0, 0, e * 30)))
			_legs(w, h, l, fur.darkened(0.2), h * 0.4, 0.06)
		"bear":
			var fur := Color(0.24, 0.15, 0.09)
			vis.add_child(MU.capsule(w * 0.5, l * 0.95, fur, Vector3(0, h * 0.62, 0), Vector3(90, 0, 0)))
			vis.add_child(MU.sphere(w * 0.45, fur, Vector3(0, h * 0.82, -l * 0.15)))          # горб
			vis.add_child(MU.sphere(w * 0.32, fur, Vector3(0, h * 0.7, -l * 0.55)))
			vis.add_child(MU.cyl(w * 0.1, w * 0.16, w * 0.3, Color(0.4, 0.3, 0.2), Vector3(0, h * 0.64, -l * 0.7), Vector3(-90, 0, 0)))
			vis.add_child(MU.sphere(w * 0.05, Color(0.02, 0.02, 0.02), Vector3(0, h * 0.66, -l * 0.78)))
			for e in [-1, 1]:
				vis.add_child(MU.sphere(w * 0.09, fur, Vector3(e * w * 0.24, h * 0.9, -l * 0.52)))
			_legs(w, h, l, fur.darkened(0.15), h * 0.5, 0.11)


func _legs(w: float, h: float, l: float, c: Color, leg_len: float, r: float) -> void:
	for p in [Vector3(-w * 0.3, 0, -l * 0.32), Vector3(w * 0.3, 0, -l * 0.32), Vector3(-w * 0.3, 0, l * 0.32), Vector3(w * 0.3, 0, l * 0.32)]:
		var piv := Node3D.new()
		piv.position = p + Vector3(0, leg_len, 0)
		piv.add_child(MU.capsule(r, leg_len + r, c, Vector3(0, -leg_len * 0.5, 0)))
		vis.add_child(piv)
		legs.append(piv)


func _ready() -> void:
	world = get_tree().current_scene
	last_pos = global_position
	call_t = randf_range(5.0, 25.0)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_ai(delta)
		sync_xform = global_transform
	else:
		global_transform = global_transform.interpolate_with(sync_xform, clampf(delta * 10.0, 0.0, 1.0))
	_animate(delta)


# ======================================================================= ИИ (хост)
func _ai(delta: float) -> void:
	var d: Dictionary = ItemsDB.ANIMALS[kind]
	state_t -= delta
	# кровопотеря
	if bleed > 0.0:
		hp -= bleed * delta
		bleed = maxf(bleed - delta * 0.04 * bleed, 0.0)
		bleeding = bleed > 0.3
		if hp <= 0.0:
			die()
			return
	var near: Array = world.nearest_player(global_position)
	var p: Node = near[0]
	var dist: float = near[1]
	var speed := 0.0
	match state:
		"idle", "wander":
			if p and not p.dead:
				var aggro := float(d.get("aggro", 0.0))
				if aggro > 0.0 and dist < aggro and p._seat_index() < 0:
					_start_charge(p)
				elif dist < float(d.scare) * (1.6 if p.anim_speed > 5.0 else 1.0):
					flee(p.global_position, randf_range(6.0, 10.0))
			if state_t <= 0.0:
				if randf() < 0.4:
					state = "idle"
					state_t = randf_range(2.0, 6.0)
				else:
					state = "wander"
					state_t = randf_range(3.0, 8.0)
					dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			if state == "wander":
				speed = float(d.walk)
		"flee":
			var away := global_position - flee_from
			away.y = 0
			if away.length() > 0.1:
				dir = dir.lerp(away.normalized(), delta * 2.0).normalized()
			speed = float(d.run)
			if state_t <= 0.0:
				state = "idle"
				state_t = 2.0
		"charge":
			var t: Node = world.get_player(target_id)
			if t == null or t.dead or state_t <= 0.0 or t._seat_index() >= 0:
				state = "idle"
				state_t = 2.0
			else:
				var to: Vector3 = t.global_position - global_position
				to.y = 0
				dir = to.normalized()
				speed = float(d.run)
				if to.length() < (1.6 if kind == "bear" else 1.3):
					var dmg := float(d.dmg)
					t.rpc_id(t.peer_id, "get_hit", dir * 7.0 + Vector3.UP * 5.0, dmg, dmg * 0.02)
					world.sfx_all(kind + "_call", global_position, 4.0, 0.9)
					flee(t.global_position, 2.5)
	if leg_hit > 0.0:
		speed *= 0.55
	if hp < max_hp * 0.3:
		speed *= 0.7
	_move(delta, speed)
	call_t -= delta
	if call_t <= 0.0:
		call_t = randf_range(10.0, 30.0)
		if p and dist < 70.0:
			world.sfx_all(kind + "_call", global_position, -4.0, randf_range(0.9, 1.1))


func _move(delta: float, speed: float) -> void:
	if speed <= 0.0:
		return
	var np := global_position + dir * speed * delta
	if not TerrainGen.is_land(np.x, np.z, 0.4) or TerrainGen.normal_at(np.x, np.z).y < 0.7:
		# вода или обрыв — разворот
		dir = dir.rotated(Vector3.UP, PI * randf_range(0.5, 1.0))
		return
	np.y = TerrainGen.height_at(np.x, np.z)
	global_position = np
	yaw = lerp_angle(yaw, atan2(-dir.x, -dir.z), clampf(delta * 6.0, 0.0, 1.0))
	rotation = Vector3(0, yaw, 0)


func _start_charge(p: Node) -> void:
	state = "charge"
	state_t = 7.0
	target_id = p.peer_id
	world.sfx_all(kind + "_call", global_position, 3.0, 1.0)


func flee(from: Vector3, t: float) -> void:
	if state == "charge" and kind != "rabbit" and kind != "deer":
		return
	state = "flee"
	state_t = t
	flee_from = from
	var away := global_position - from
	away.y = 0
	if away.length() > 0.1:
		dir = away.normalized()


func alarm(from: Vector3, shooter_id: int) -> void:
	if ItemsDB.ANIMALS[kind].has("aggro") and randf() < 0.5 and shooter_id != 0:
		var p: Node = world.get_player(shooter_id)
		if p and p.global_position.distance_to(global_position) < 60.0:
			_start_charge(p)
			return
	flee(from, randf_range(8.0, 14.0))


## Вызывается хостом при попадании пули. Возвращает текст для стрелка.
func apply_hit(zones: Array, dmg: float, shooter_id: int, from: Vector3) -> String:
	var mult := 0.0
	var bl := 0.0
	var best := ""
	for z in zones:
		var zd: Dictionary = ZONES[z]
		if float(zd.mult) > mult:
			mult = float(zd.mult)
			best = z
		bl += float(zd.bleed)
		if z == "leg":
			leg_hit = 1.0
	var total := dmg * mult
	# «перебор калибра» считаем по энергии пули относительно размера зверя
	last_overkill = dmg / max_hp
	hp -= total
	bleed += bl * clampf(dmg / 80.0, 0.3, 2.0)
	bleeding = bleed > 0.3
	world.sfx_all("hit_flesh", global_position + Vector3.UP * 0.6, 0.0, 1.0)
	if hp <= 0.0 or best == "brain":
		die()
		return "kill_" + best
	alarm(from, shooter_id)
	return "hit_" + best


func die() -> void:
	if is_queued_for_deletion():
		return
	var q := 1.0
	if last_overkill > 5.0:
		q = 0.0
	elif last_overkill > 3.2:
		q = 0.5
	if q > 0.0:
		world.spawn_item("carcass_" + kind, global_position + Vector3.UP * 0.7, Vector3(randf_range(-1, 1), 3.0, randf_range(-1, 1)), q)
	else:
		world.broadcast(T.t("msg_obliterated", [T.t("animal_" + kind)]))
		world.rpc("fx_burst", global_position + Vector3.UP * 0.4, 1)
	world.sfx_all(kind + "_call", global_position, 0.0, 0.7)
	queue_free()


# ======================================================================= АНИМАЦИЯ
func _animate(delta: float) -> void:
	if delta <= 0.0:
		return
	var v := (global_position - last_pos).length() / delta
	last_pos = global_position
	anim_phase += delta * (2.0 + v * 2.2)
	var k := clampf(v / 4.0, 0.0, 1.0)
	for i in legs.size():
		var ph := anim_phase + (PI if i % 3 == 0 else 0.0)
		(legs[i] as Node3D).rotation.x = sin(ph) * 0.7 * k
	if bleeding:
		_blood_t -= delta
		if _blood_t <= 0.0 and v > 0.5:
			_blood_t = 0.6
			world.add_blood(global_position)
		elif _blood_t <= -3.0:
			_blood_t = 0.0
			world.add_blood(global_position)
