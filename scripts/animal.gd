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
var anim_player: AnimationPlayer
var anim_names: Dictionary = {}
var skel: Skeleton3D
var leg_bones: Array = []
var head_bone := -1
var _cur_anim := ""
var _track_t := 0.0
var _track_from := Vector3.ZERO
var _drop_t := 60.0
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


func _build_visual(_s: Vector3) -> void:
	vis = Node3D.new()
	vis.name = "Vis"
	add_child(vis)
	# у оленей — самец с рогами или самка (по имени, одинаково у всех игроков)
	var variant := (name.hash() & 0xff) % 2 if kind == "deer" else 0
	var m := A3.animal(kind, variant)
	vis.add_child(m)
	anim_player = m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	anim_names = ItemsDB.ANIMAL_MODELS[kind].get("anims", {})
	if ItemsDB.ANIMAL_MODELS[kind].get("proc", false):
		skel = m.find_child("*Skeleton*", true, false) as Skeleton3D
		if skel == null:
			for c in m.find_children("*", "Skeleton3D", true, false):
				skel = c
				break
		if skel:
			for b in ["leg_fl", "leg_fr", "leg_bl", "leg_br"]:
				leg_bones.append(skel.find_bone(b))
			head_bone = skel.find_bone("head")


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


## Сбит домом на колёсах (хост).
func vehicle_hit(push: Vector3, dmg: float) -> void:
	_fling = push
	hp -= dmg
	bleed += dmg * 0.05
	bleeding = bleed > 0.3
	leg_hit = 1.0 if dmg > max_hp * 0.3 else leg_hit
	var side := Vector3(push.x, 0, push.z)
	if side.length() > 0.1:
		global_position += side.normalized() * 2.0
		global_position.y = TerrainGen.height_at(global_position.x, global_position.z)
	world.sfx_all("hit_flesh", global_position + Vector3.UP * 0.6, 2.0, 0.8)
	if hp <= 0.0:
		last_overkill = 0.0
		die()
		return
	if ItemsDB.ANIMALS[kind].has("aggro"):
		state = "flee"   # медведь/кабан сначала отскакивает, потом может кинуться
		state_t = 1.5
		flee_from = global_position - side
	else:
		flee(global_position - side, 10.0)


var _fling := Vector3.ZERO


func die() -> void:
	if is_queued_for_deletion():
		return
	var q := 1.0
	if last_overkill > 5.0:
		q = 0.0
	elif last_overkill > 3.2:
		q = 0.5
	if q > 0.0:
		var vel := Vector3(randf_range(-1, 1), 3.0, randf_range(-1, 1)) if _fling == Vector3.ZERO else _fling
		world.spawn_item("carcass_" + kind, global_position + Vector3.UP * 0.7, vel, q)
	else:
		world.broadcast(T.t("msg_obliterated", [T.t("animal_" + kind)]))
		world.rpc("fx_burst", global_position + Vector3.UP * 0.4, 1)
	world.sfx_all(kind + "_call", global_position, 0.0, 0.7)
	queue_free()


# ======================================================================= АНИМАЦИЯ
func _play(key: String, spd := 1.0) -> void:
	if anim_player == null:
		return
	var nm := str(anim_names.get(key, anim_names.get("idle", "")))
	if nm == "" or not anim_player.has_animation(nm):
		return
	if nm != _cur_anim:
		_cur_anim = nm
		anim_player.play(nm, 0.25)
	anim_player.speed_scale = spd


func _animate(delta: float) -> void:
	if delta <= 0.0:
		return
	var v := (global_position - last_pos).length() / delta
	last_pos = global_position
	var d: Dictionary = ItemsDB.ANIMALS[kind]
	if v > float(d.walk) * 1.6:
		_play("run", clampf(v / float(d.run) * 1.1, 0.6, 1.6))
	elif v > 0.25:
		_play("walk", clampf(v / float(d.walk), 0.5, 1.8))
	else:
		_play("eat" if fmod(anim_phase, 20.0) > 12.0 and anim_names.has("eat") else "idle", 1.0)
	anim_phase += delta * (2.0 + v * 2.2)
	if skel and not leg_bones.is_empty():
		var k := clampf(v / 3.0, 0.0, 1.0)
		var sw := 0.55 * k
		for i in leg_bones.size():
			if int(leg_bones[i]) < 0:
				continue
			var ph := anim_phase + (PI if i == 1 or i == 2 else 0.0)
			skel.set_bone_pose_rotation(leg_bones[i], Quaternion(Vector3.RIGHT, sin(ph) * sw))
		if head_bone >= 0:
			skel.set_bone_pose_rotation(head_bone, Quaternion(Vector3.RIGHT, sin(anim_phase * 0.5) * 0.08 * (1.0 - k)))
	_leave_tracks(delta)
	if bleeding:
		_blood_t -= delta
		if _blood_t <= 0.0 and v > 0.5:
			_blood_t = 0.6
			world.add_blood(global_position)
		elif _blood_t <= -3.0:
			_blood_t = 0.0
			world.add_blood(global_position)


## Следы и помёт рисует каждый игрок у себя (по синхронизированному положению зверя).
func _leave_tracks(delta: float) -> void:
	if world == null or not world.has_method("add_track"):
		return
	_track_t -= delta
	if _track_t > 0.0:
		return
	_track_t = 0.25
	var step := {"rabbit": 0.6, "deer": 1.3, "boar": 1.1, "bear": 1.5}.get(kind, 1.2) as float
	var mv := global_position - _track_from
	mv.y = 0.0
	if mv.length() >= step:
		world.add_track(kind, global_position, atan2(mv.x, mv.z), name, bleeding)
		_track_from = global_position
	_drop_t -= 0.25 * (2.0 if mv.length() < 0.1 else 1.0)
	if _drop_t <= 0.0:
		_drop_t = randf_range(90.0, 200.0)
		world.add_track(kind, global_position - global_basis.z * -0.4, 0.0, name, false, true)
