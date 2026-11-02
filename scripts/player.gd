class_name Player
extends CharacterBody3D
## Игрок. Движение и потребности считаются у владельца (клиент-авторитет),
## позиция/поза рассылаются остальным через MultiplayerSynchronizer.
## Всё, что меняет общий мир (предметы, звери, дом), идёт запросом к хосту.

const WALK := 4.2
const RUN := 7.5
const JUMP := 5.2
const GRAV := 14.0
const MOUSE_SENS := 0.0025
const MAX_SLOTS := 8
const MAX_WEIGHT := 30.0
const STEP_UP := 0.45

const COLORS := [Color(0.55, 0.12, 0.1), Color(0.15, 0.3, 0.55), Color(0.25, 0.4, 0.15), Color(0.5, 0.35, 0.1)]
const EMOTES := ["wave", "dance", "laugh", "point", "sit", "facepalm", "shrug", "flop"]
const LOOP_EMOTES := ["dance", "sit"]
const ACTION_EMOTES := {"eat": 1.6, "drink": 1.8, "beer": 2.2, "vodka": 1.6, "smoke": 7.0, "pee": 3.2, "poo": 5.0}

var peer_id := 1
var nick := ""
var color_idx := 0

# --- синхронизируемое
var sync_xform := Transform3D()
var aim_pitch := 0.0
var ragdoll := false
var jacket := true
var raincoat := false
var wet_vis := 0.0
var emote := ""
var weapon_vis := "double"
var holding_big := false
var dead := false
var light_on := false
var bleeding_vis := false
var aim_vis := false
var ride := false
var ride_xf := Transform3D()

# --- узлы
var world: Node
var model: Node3D
var hips: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var gun: Node3D
var torso_mi: MeshInstance3D
var raincoat_mi: MeshInstance3D
var name_label: Label3D
var shape: CollisionShape3D
var flashlight: SpotLight3D
var drips: CPUParticles3D
var smoke_fx: CPUParticles3D
var pee_fx: CPUParticles3D
var hand_prop: Node3D
var _prop_for := "-"
var cam_pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D

# --- анимация (у всех)
var anim_phase := 0.0
var anim_speed := 0.0
var last_pos := Vector3.ZERO
var step_t := 0.0
var emote_t := 0.0
var _last_emote := ""
var _blood_t := 0.0

# --- только у владельца
var hp := 100.0
var hunger := 85.0
var thirst := 85.0
var bladder := 10.0
var bowels := 5.0
var drunk := 0.0
var warmth := 100.0
var wetness := 0.0
var bleed := 0.0
var poison := 0.0
var cam_yaw := 0.0
var cam_pitch := -0.2
var aiming := false
var face_cam_t := 0.0
var flop: RigidBody3D
var flop_t := 0.0
var fall_speed := 0.0
var squat_t := 0.0
var seated := -1
var was_seated := -1
var dead_t := 0.0
var shoot_cd := 0.0
var reload_t := 0.0
var inventory: Array = [{"kind": "weapon_toz", "q": 1.0}, {"kind": "weapon_double", "q": 1.0}]   # [{kind, q}]
var cur_weapon := "double"
var ammo := {"22lr": 30, "12shot": 12, "12slug": 6, "308": 0, "338": 0}
var mag := {"toz": 5, "double": 2, "carbine": 0, "magnum": 0}
var mag_type := {"toz": "22lr", "double": "12shot", "carbine": "308", "magnum": "338"}
var target_node: Node = null
var target_kind := ""
var _needs_t := 0.0
var _rv_input_t := 0.0
var chase_cam := false
var first_person := false
var anchor_point := Vector3.ZERO
var _rv_prev := Transform3D()
var _rv_prev_ok := false
var _rv_vel := Vector3.ZERO
var _ride_vis := Transform3D()
var _was_ride := false
var cable_ok := false
var cable_far := false
var cable_point := Vector3.ZERO


func setup(data: Dictionary) -> void:
	peer_id = data.id
	nick = data.nick
	color_idx = data.color
	name = "P_%d" % peer_id
	position = data.pos
	sync_xform = Transform3D(Basis(), data.pos)
	collision_layer = MU.L_PLAYERS
	collision_mask = MU.L_WORLD | MU.L_RV
	floor_max_angle = deg_to_rad(50)
	# дом на колёсах двигает игрока сам (см. _ride_rv), без «платформы» движка
	platform_floor_layers = 0
	platform_wall_layers = 0
	_build()
	add_child(MU.make_sync(["sync_xform", "aim_pitch", "ragdoll", "jacket", "raincoat", "wet_vis",
		"emote", "weapon_vis", "holding_big", "dead", "light_on", "bleeding_vis", "aim_vis", "ride", "ride_xf"], 0.033))
	set_multiplayer_authority(peer_id)


func _build() -> void:
	shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	var pc: Color = COLORS[color_idx % COLORS.size()]
	var skin := Color(0.85, 0.66, 0.52)
	var pants := Color(0.22, 0.24, 0.18)
	var boots := Color(0.18, 0.12, 0.08)
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	hips = Node3D.new()
	hips.position.y = 0.95
	model.add_child(hips)
	torso_mi = MU.capsule(0.24, 0.75, pc, Vector3(0, 0.33, 0))
	torso_mi.scale = Vector3(1.0, 1.0, 0.75)
	hips.add_child(torso_mi)
	hips.add_child(MU.box(Vector3(0.4, 0.06, 0.3), Color(0.3, 0.2, 0.1), Vector3(0, 0.02, 0)))   # ремень
	raincoat_mi = MU.capsule(0.27, 0.95, Color(0.95, 0.78, 0.1, 0.92), Vector3(0, 0.25, 0))
	raincoat_mi.scale = Vector3(1.0, 1.0, 0.8)
	raincoat_mi.visible = false
	hips.add_child(raincoat_mi)
	# голова
	head = Node3D.new()
	head.position = Vector3(0, 0.72, 0)
	hips.add_child(head)
	head.add_child(MU.sphere(0.17, skin, Vector3(0, 0.1, 0), Vector3(1, 1.1, 1)))
	head.add_child(MU.sphere(0.045, skin.darkened(0.08), Vector3(0, 0.08, -0.17)))
	head.add_child(MU.sphere(0.025, Color(0.05, 0.05, 0.05), Vector3(0.06, 0.15, -0.145)))
	head.add_child(MU.sphere(0.025, Color(0.05, 0.05, 0.05), Vector3(-0.06, 0.15, -0.145)))
	head.add_child(MU.box(Vector3(0.12, 0.03, 0.04), Color(0.4, 0.25, 0.2), Vector3(0, 0.0, -0.15)))   # усы
	head.add_child(MU.cyl(0.18, 0.19, 0.12, Color(0.95, 0.45, 0.05), Vector3(0, 0.24, 0)))          # кепка
	head.add_child(MU.box(Vector3(0.26, 0.02, 0.14), Color(0.95, 0.45, 0.05), Vector3(0, 0.2, -0.2)))
	# руки (шарнир в плече)
	arm_l = _limb(Vector3(-0.3, 0.6, 0), 0.075, 0.62, pc, skin)
	arm_r = _limb(Vector3(0.3, 0.6, 0), 0.075, 0.62, pc, skin)
	hips.add_child(arm_l)
	hips.add_child(arm_r)
	# ноги (шарнир в бедре)
	leg_l = _limb(Vector3(-0.12, 0.0, 0), 0.095, 0.9, pants, boots)
	leg_r = _limb(Vector3(0.12, 0.0, 0), 0.095, 0.9, pants, boots)
	hips.add_child(leg_l)
	hips.add_child(leg_r)
	# ружьё
	gun = Node3D.new()
	gun.position = Vector3(0.18, 0.45, -0.25)
	hips.add_child(gun)
	_build_gun_model(weapon_vis)
	# фонарик
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0, 0.15, -0.2)
	flashlight.spot_range = 35
	flashlight.spot_angle = 28
	flashlight.light_energy = 3.0
	flashlight.shadow_enabled = true
	flashlight.visible = false
	head.add_child(flashlight)
	# капли воды
	drips = CPUParticles3D.new()
	drips.amount = 16
	drips.lifetime = 0.6
	drips.emitting = false
	drips.position.y = 1.2
	drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drips.emission_box_extents = Vector3(0.25, 0.4, 0.2)
	drips.gravity = Vector3(0, -9, 0)
	drips.initial_velocity_min = 0.0
	drips.initial_velocity_max = 0.2
	var dm := SphereMesh.new()
	dm.radius = 0.015
	dm.height = 0.04
	dm.material = MU.mat(Color(0.6, 0.8, 1.0, 0.7), 0.1)
	drips.mesh = dm
	add_child(drips)
	hand_prop = Node3D.new()
	hand_prop.position = Vector3(0, -0.66, -0.06)
	arm_r.add_child(hand_prop)
	smoke_fx = _make_fx(Color(0.8, 0.8, 0.8, 0.35), 0.05, Vector3(0, 0.6, 0), 2.0)
	smoke_fx.position = Vector3(0, 0.05, -0.2)
	head.add_child(smoke_fx)
	pee_fx = _make_fx(Color(0.95, 0.85, 0.2, 0.8), 0.015, Vector3(0, -9.0, 0), 0.6)
	pee_fx.position = Vector3(0, 0.0, -0.2)
	pee_fx.direction = Vector3(0, 0.3, -1)
	pee_fx.initial_velocity_min = 2.0
	pee_fx.initial_velocity_max = 2.4
	pee_fx.spread = 4.0
	pee_fx.amount = 40
	hips.add_child(pee_fx)
	name_label = MU.label3d(nick, Vector3(0, 2.25, 0), 48, pc.lightened(0.5))
	add_child(name_label)


func _make_fx(c: Color, size: float, grav: Vector3, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = life
	p.emitting = false
	p.gravity = grav
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = MU.mat(c, 1.0)
	p.mesh = m
	return p


func _set_hand_prop(e: String) -> void:
	if e == _prop_for:
		return
	_prop_for = e
	for c in hand_prop.get_children():
		c.queue_free()
	match e:
		"smoke":
			hand_prop.add_child(MU.cyl(0.006, 0.006, 0.08, Color(0.95, 0.95, 0.92), Vector3(0, 0, -0.03), Vector3(90, 0, 0), 6))
			hand_prop.add_child(MU.cyl(0.007, 0.007, 0.01, MU.mat(Color(1.0, 0.35, 0.05), 0.5, 3.0), Vector3(0, 0, -0.075), Vector3(90, 0, 0), 6))
		"beer":
			hand_prop.add_child(MU.cyl(0.03, 0.035, 0.2, Color(0.35, 0.2, 0.05, 0.85), Vector3(0, 0.05, 0)))
		"vodka":
			hand_prop.add_child(MU.cyl(0.035, 0.035, 0.22, Color(0.85, 0.9, 0.95, 0.6), Vector3(0, 0.05, 0)))
			hand_prop.add_child(MU.cyl(0.012, 0.015, 0.06, Color(0.85, 0.1, 0.1), Vector3(0, 0.18, 0)))
		"drink":
			hand_prop.add_child(MU.cyl(0.035, 0.035, 0.2, Color(0.5, 0.75, 0.95, 0.75), Vector3(0, 0.05, 0)))
		"eat":
			hand_prop.add_child(MU.box(Vector3(0.12, 0.05, 0.09), Color(0.45, 0.25, 0.1), Vector3(0, 0, -0.03)))


func _limb(pivot: Vector3, r: float, length: float, c_top: Color, c_end: Color) -> Node3D:
	var p := Node3D.new()
	p.position = pivot
	p.add_child(MU.capsule(r, length * 0.75, c_top, Vector3(0, -length * 0.38, 0)))
	p.add_child(MU.sphere(r * 1.05, c_end, Vector3(0, -length * 0.82, -r * 0.4), Vector3(1, 0.8, 1.4)))
	return p


var muzzle_node: Marker3D


func _build_gun_model(w: String) -> void:
	for c in gun.get_children():
		gun.remove_child(c)
		c.queue_free()
	muzzle_node = null
	gun.set_meta("w", w)
	if w == "":
		return
	var g := ItemsDB.build_gun(w)
	gun.add_child(g)
	muzzle_node = g.get_node("Muzzle") as Marker3D


func _ready() -> void:
	world = get_tree().current_scene
	last_pos = global_position
	if is_multiplayer_authority():
		name_label.visible = false
		cam_yaw = rotation.y
		_build_camera()
		world.local_player = self
		cur_weapon = "double"
		weapon_vis = cur_weapon
		_rv_prev_ok = false


func _build_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.top_level = true
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 3.4
	spring.margin = 0.2
	spring.collision_mask = MU.L_WORLD | MU.L_RV
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	spring.shape = sph
	spring.add_excluded_object(get_rid())
	cam_pivot.add_child(spring)
	# SpringArm3D сам задаёт положение детей, поэтому боковое смещение «через плечо»
	# делаем во вложенном узле — иначе перекрестие оказывается прямо на персонаже.
	var rig := Node3D.new()
	spring.add_child(rig)
	cam = Camera3D.new()
	cam.fov = 72
	cam.far = 1500
	rig.add_child(cam)
	cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ======================================================================= ВВОД
func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or world == null:
		return
	if world.hud.menu_open():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := MOUSE_SENS * Settings.mouse_sens * (0.45 if aiming else 1.0)
		var dy: float = event.relative.y * (-1.0 if Settings.invert_y else 1.0)
		cam_yaw -= event.relative.x * sens
		cam_pitch = clampf(cam_pitch - dy * sens, -1.3, 1.1)
	if dead:
		return
	if event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("inventory"):
		world.hud.open_inventory(self)
	elif event.is_action_pressed("emote_menu"):
		world.hud.open_emotes(self)
	elif event.is_action_pressed("flop"):
		play_emote("flop")
	elif event.is_action_pressed("drop"):
		if world.get_held_item(peer_id) != null:
			world.rpc_id(1, "req_drop")
	elif event.is_action_pressed("flashlight"):
		light_on = not light_on
		Sfx.play_ui("click", -8)
	elif event.is_action_pressed("reload"):
		_start_reload()
	elif event.is_action_pressed("ammo_type"):
		_cycle_ammo_type()
	elif event.is_action_pressed("horn") and seated == 0:
		world.rpc_id(1, "req_button", "horn")
	elif event.is_action_pressed("gear_up") and seated == 0:
		world.rpc_id(1, "req_gear", 1)
	elif event.is_action_pressed("gear_down") and seated == 0:
		world.rpc_id(1, "req_gear", -1)
	elif event.is_action_pressed("winch_front") and seated == 0:
		world.rpc_id(1, "req_button", "winch_front")
	elif event.is_action_pressed("winch_rear") and seated == 0:
		world.rpc_id(1, "req_button", "winch_rear")
	elif event.is_action_pressed("camera_toggle"):
		chase_cam = not chase_cam
	elif event.is_action_pressed("toilet") and seated < 0 and not ragdoll:
		world.hud.open_toilet(self)
	elif event.is_action_pressed("weapon_next"):
		_cycle_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		_cycle_weapon(-1)
	for i in 4:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			if seated >= 0:
				world.rpc_id(1, "req_seat", i)
			else:
				var owned := weapons_owned()
				if i < owned.size():
					_select_weapon(owned[i])


# ======================================================================= ЦИКЛ
func _physics_process(delta: float) -> void:
	if world == null:
		return
	if is_multiplayer_authority():
		_owner_physics(delta)
		sync_xform = global_transform
	else:
		_remote_physics(delta)
	_animate(delta)


func _remote_physics(delta: float) -> void:
	var s := _seat_index()
	if s >= 0 and world.rv:
		global_transform = world.rv.get_seat_xform(s)
	elif ride and world.rv:
		if not _was_ride:
			_ride_vis = ride_xf
		_ride_vis = _ride_vis.interpolate_with(ride_xf, clampf(delta * 14.0, 0.0, 1.0))
		global_transform = world.rv.global_transform * _ride_vis
	else:
		global_transform = global_transform.interpolate_with(sync_xform, clampf(delta * 14.0, 0.0, 1.0))
	_was_ride = ride and s < 0
	shape.disabled = true


func _seat_index() -> int:
	if world.rv == null:
		return -1
	return world.rv.seats.find(peer_id)


func _owner_physics(delta: float) -> void:
	seated = _seat_index()
	holding_big = world.get_held_item(peer_id) != null
	shoot_cd = maxf(shoot_cd - delta, 0.0)
	face_cam_t = maxf(face_cam_t - delta, 0.0)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			_finish_reload()
	_update_needs(delta)
	_check_weapon_valid()
	_ride_rv(delta)
	if dead:
		_dead_update(delta)
		_update_camera(delta)
		return
	if ragdoll:
		_ragdoll_update(delta)
		_update_camera(delta)
		return
	if seated >= 0:
		_seated_update(delta)
		was_seated = seated
		_update_camera(delta)
		_update_target()
		return
	if was_seated >= 0:
		_leave_seat_place()
		was_seated = -1
	shape.disabled = false
	_move(delta)
	if not ride:
		_check_rv_hit()
	_update_camera(delta)
	_update_target()
	if Input.is_action_pressed("shoot") and not world.hud.menu_open() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_on_shoot_pressed()


func _move(delta: float) -> void:
	var in_menu: bool = world.hud.menu_open()
	var input_dir := Vector2.ZERO
	if not in_menu and not (squat_t > 0.0 and (emote == "pee" or emote == "poo")):
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	aiming = Input.is_action_pressed("aim") and not in_menu and world.get_held_item(peer_id) == null and cur_weapon != ""
	aim_vis = aiming or face_cam_t > 0.0
	var cam_basis := Basis(Vector3.UP, cam_yaw)
	var dir := cam_basis * Vector3(input_dir.x, 0, input_dir.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	if input_dir.length() > 0.1 and emote != "" and not emote in ACTION_EMOTES:
		emote = ""
	var speed := RUN if Input.is_action_pressed("sprint") and hunger > 5 and not aiming else WALK
	if aiming:
		speed *= 0.5
	speed *= _carry_factor()
	var water_depth := TerrainGen.WATER - global_position.y
	var swimming := water_depth > 1.1
	if water_depth > 0.3:
		speed *= 0.55
	if squat_t > 0.0:
		squat_t -= delta
		if squat_t <= 0.0:
			emote = ""
	if drunk > 5.0:
		var tt := Time.get_ticks_msec() * 0.001
		dir = dir.rotated(Vector3.UP, sin(tt * 1.3) * drunk * 0.008)
		dir += Vector3(sin(tt * 0.9), 0, cos(tt * 1.1)) * drunk * 0.004
		if drunk > 70.0 and dir.length() > 0.5 and randf() < 0.0015:
			start_ragdoll(dir * 3.0, 2.0)
			world.broadcast(T.t("msg_drunk_fall", [nick]))
	var target_v := dir * speed
	var accel := 10.0 if is_on_floor() or swimming else 2.5
	velocity.x = lerpf(velocity.x, target_v.x, clampf(accel * delta, 0, 1))
	velocity.z = lerpf(velocity.z, target_v.z, clampf(accel * delta, 0, 1))
	if swimming:
		velocity.y = lerpf(velocity.y, (TerrainGen.WATER - 1.25 - global_position.y) * 3.0, delta * 3.0)
		if Input.is_action_pressed("jump"):
			velocity.y = 1.5
	else:
		velocity.y -= GRAV * delta
		if is_on_floor() and Input.is_action_just_pressed("jump") and not in_menu:
			velocity.y = JUMP * (0.75 + 0.25 * _carry_factor())
			Sfx.play_at("jump", global_position, -12)
	fall_speed = maxf(fall_speed, -velocity.y) if not is_on_floor() else fall_speed
	var hv_before := Vector2(velocity.x, velocity.z)
	move_and_slide()
	_step_up(dir, hv_before)
	if not ride:
		_try_push(delta, dir)
	if is_on_floor():
		if fall_speed > 12.0:
			hp -= (fall_speed - 12.0) * 5.0
			start_ragdoll(Vector3.ZERO, 2.5)
			world.sfx_all("thud", global_position, 0.0, 0.8)
		fall_speed = 0.0
	# лицо: по движению или по камере
	var want_yaw := rotation.y
	if aiming or face_cam_t > 0.0:
		want_yaw = cam_yaw
	elif Vector2(velocity.x, velocity.z).length() > 0.5:
		want_yaw = atan2(-velocity.x, -velocity.z)
	rotation = Vector3(0, lerp_angle(rotation.y, want_yaw, clampf(delta * 12.0, 0, 1)), 0)
	aim_pitch = cam_pitch
	# не провалиться под землю
	var gh := TerrainGen.height_at(global_position.x, global_position.z)
	if global_position.y < gh - 1.0:
		global_position.y = gh + 0.2
		velocity.y = 0


## Ступеньки: упёрлись в невысокое препятствие — шагаем на него.
func _step_up(dir: Vector3, hv: Vector2) -> void:
	if dir.length() < 0.1 or not is_on_wall() or velocity.y > 0.5:
		return
	var fw := dir.normalized() * 0.3
	var up := Vector3.UP * STEP_UP
	var xf := global_transform
	if test_move(xf, up):
		return
	if test_move(xf.translated(up), fw):
		return
	global_position += up + fw
	var col := move_and_collide(Vector3.DOWN * (STEP_UP + 0.05))
	if col == null:
		global_position -= up + fw
	else:
		velocity.x = hv.x
		velocity.z = hv.y
		velocity.y = 0.0


## Дом везёт тех, кто стоит внутри или на крыше, и поворачивает их вместе с собой.
func _ride_rv(delta: float) -> void:
	var rv: RV = world.rv
	if rv == null:
		ride = false
		return
	var now := rv.global_transform
	var was_ride := ride
	ride = false
	if _rv_prev_ok and delta > 0.0:
		var dyaw := wrapf(now.basis.get_euler().y - _rv_prev.basis.get_euler().y, -PI, PI)
		var v := (now.origin - _rv_prev.origin) / delta
		var acc := (v - _rv_vel) / delta
		_rv_vel = _rv_vel.lerp(v, 0.5)
		if seated >= 0:
			cam_yaw += dyaw
		elif not ragdoll and not dead and rv.contains(global_position + Vector3.UP * 0.5, _rv_prev):
			ride = true
			global_position = now * (_rv_prev.affine_inverse() * global_position)
			rotation.y += dyaw
			cam_yaw += dyaw
			acc.y = 0.0
			if acc.length() > 9.0 and acc.length() < 200.0:
				velocity -= acc * delta * 0.6
			if acc.length() > 45.0 and acc.length() < 200.0:
				start_ragdoll(-acc * 0.08 + Vector3.UP * 2.0, 2.0)
	if ride:
		ride_xf = now.affine_inverse() * global_transform
	elif was_ride:
		velocity += _rv_vel * Vector3(1, 0, 1)
	_rv_prev = now
	_rv_prev_ok = true


var _push_t := 0.0


## Толкаем дом на колёсах, упираясь в него.
func _try_push(delta: float, dir: Vector3) -> void:
	_push_t -= delta
	if dir.length() < 0.5 or _push_t > 0.0:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RV:
			_push_t = 0.1
			var f := dir.normalized() * 1400.0 * (1.4 if Input.is_action_pressed("sprint") else 1.0)
			world.rpc_id(1, "req_push", c.get_position(), f)
			return


func _carry_factor() -> float:
	var held: Node = world.get_held_item(peer_id)
	var m := inv_weight() * 0.5
	if held:
		m += float(ItemsDB.ITEMS[held.kind].mass)
	return clampf(1.0 - m / 260.0, 0.35, 1.0)


func _check_rv_hit() -> void:
	var rv: Node3D = world.rv
	if rv == null:
		return
	var v: Vector3 = rv.sync_vel
	if v.length() < 5.0:
		return
	var local: Vector3 = rv.global_transform.affine_inverse() * (global_position + Vector3.UP * 0.9)
	if absf(local.x) < 1.7 and absf(local.z) < 4.3 and local.y > -0.5 and local.y < 3.4:
		hp -= v.length() * 1.2
		bleed += 0.3
		start_ragdoll(v * 1.1 + Vector3.UP * 6.0, 3.5)
		world.sfx_all("thud", global_position, 3.0, 0.7)
		world.broadcast(T.t("msg_hit_by_rv", [nick]))


func _seated_update(delta: float) -> void:
	shape.disabled = true
	velocity = Vector3.ZERO
	var rv: Node3D = world.rv
	global_transform = rv.get_seat_xform(seated)
	aim_pitch = cam_pitch
	aim_vis = false
	if emote != "":
		emote = ""
	if seated == 0:
		_rv_input_t -= delta
		var t := 0.0
		var s := 0.0
		var b := 0.0
		if not world.hud.menu_open():
			t = Input.get_axis("move_back", "move_forward")
			s = Input.get_axis("move_right", "move_left")
			b = 1.0 if Input.is_action_pressed("jump") else 0.0
		world.rpc_id(1, "rv_input", t, s, b)


func _leave_seat_place() -> void:
	var rv: RV = world.rv
	if rv == null:
		return
	var p: Vector3 = rv.get_stand_point(was_seated)
	global_position = p
	rotation = Vector3(0, cam_yaw, 0)
	velocity = Vector3.ZERO
	_rv_prev = rv.global_transform


func _update_camera(delta: float) -> void:
	if cam_pivot == null:
		return
	var focus := global_position + Vector3.UP * 1.65
	var arm := 3.1
	var side := 0.85          # камера «через правое плечо», как в экшенах от 3-го лица
	var fov: float = Settings.fov
	first_person = false
	if dead or ragdoll:
		if flop:
			focus = flop.global_position + Vector3.UP * 0.6
		arm = 4.5
		side = 0.0
	elif seated >= 0 and world.rv:
		if chase_cam:
			focus = world.rv.global_position + Vector3.UP * 2.8
			arm = 10.5
			side = 0.0
		else:
			# вид из кабины: глаза на уровне головы, свой силуэт скрыт
			first_person = true
			focus = global_position + global_basis * Vector3(0, 1.2, -0.1)
			arm = 0.0
			side = 0.0
			fov = Settings.fov
	elif ride and ride_xf.origin.y < 3.0:
		# внутри дома тесно: камера ближе
		arm = 1.7
		side = 0.35
	elif aiming:
		arm = 1.55
		side = 0.75
		focus = global_position + Vector3.UP * 1.6
		fov = float(ItemsDB.WEAPONS[cur_weapon].zoom) * Settings.fov / 72.0 if cur_weapon != "" else fov
	cam_pivot.global_position = cam_pivot.global_position.lerp(focus, clampf(delta * 22.0, 0, 1)) if (cam_pivot.global_position.distance_to(focus) < 4.0 and not first_person) else focus
	var tt := Time.get_ticks_msec() * 0.001
	var dr := drunk / 100.0
	cam_pivot.rotation = Vector3(cam_pitch + sin(tt * 0.7) * dr * 0.08, cam_yaw + sin(tt * 0.5) * dr * 0.1, sin(tt * 0.9) * dr * 0.18)
	fov += sin(tt * 1.7) * dr * 8.0
	spring.spring_length = arm if first_person else lerpf(spring.spring_length, arm, clampf(delta * 8.0, 0, 1))
	cam.position.x = lerpf(cam.position.x, side, clampf(delta * 8.0, 0, 1))
	cam.fov = lerpf(cam.fov, fov, clampf(delta * 10.0, 0, 1))
	cam.near = 0.05
	model.visible = not first_person and (spring.get_hit_length() > 0.8 or seated >= 0)


# ======================================================================= ВЗАИМОДЕЙСТВИЕ
func _update_target() -> void:
	target_node = null
	target_kind = ""
	if cam == null:
		return
	var from := cam.global_position
	var fwd := -cam.global_basis.z
	# начинаем луч от плеча персонажа, чтобы не цеплять предметы за спиной
	var start := from + fwd * from.distance_to(global_position + Vector3.UP * 1.4)
	var q := PhysicsRayQueryParameters3D.create(start, start + fwd * 3.0,
		MU.L_WORLD | MU.L_ITEMS | MU.L_RV | MU.L_INTERACT, [get_rid()])
	q.collide_with_areas = true
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		var n := MU.find_kind_node(r.collider)
		if n:
			target_node = n
			target_kind = n.get_meta("kind")
	if target_node == null and TerrainGen.WATER - global_position.y > 0.05 and seated < 0:
		target_kind = "water"
	cable_ok = false
	var rv: RV = world.rv
	if rv and seated < 0 and rv.cable_holder_of(peer_id) >= 0 and target_kind != "rv_hook":
		var i := rv.cable_holder_of(peer_id)
		var q2 := PhysicsRayQueryParameters3D.create(start, start + fwd * 6.0, MU.L_WORLD | MU.L_RV, [get_rid()])
		var r2 := get_world_3d().direct_space_state.intersect_ray(q2)
		if not r2.is_empty():
			cable_point = r2.position
			cable_ok = r2.position.distance_to(rv.hook_pos(i)) <= RV.CABLE_LEN
			cable_far = not cable_ok
		target_kind = "cable_place" if not r2.is_empty() else "cable_hold"


func get_prompt() -> String:
	if dead:
		return ""
	var held: Node = world.get_held_item(peer_id)
	if seated >= 0:
		if target_kind == "rv_button":
			return T.t("prompt_button", [T.t("btn_" + str(target_node.get_meta("action")))])
		return T.t("prompt_seated_fp")
	match target_kind:
		"item":
			return T.t("prompt_take", [ItemsDB.item_name(target_node.kind)])
		"rv_seat":
			var si := int(target_node.get_meta("seat"))
			if world.rv and world.rv.seats[si] != 0 and world.rv.seats[si] != peer_id:
				return T.t("prompt_seat_taken")
			return T.t("prompt_sit_driver") if si == 0 else T.t("prompt_sit")
		"rv_button":
			return T.t("prompt_button", [T.t("btn_" + str(target_node.get_meta("action")))])
		"rv_hook":
			var hi := int(target_node.get_meta("hook"))
			var st: int = world.rv.winch_state[hi]
			if st == 0:
				return T.t("prompt_hook_take")
			if st == 1:
				return T.t("prompt_hook_back") if world.rv.winch_holder[hi] == peer_id else ""
			return T.t("prompt_hook_detach")
		"rv_ladder":
			return T.t("prompt_ladder_up") if global_position.y < world.rv.global_position.y + 2.5 else T.t("prompt_ladder_down")
		"cable_place":
			return T.t("prompt_cable_attach") if cable_ok else T.t("prompt_cable_far")
		"cable_hold":
			return T.t("prompt_holding_cable")
		"rv_stove", "campfire":
			if held and held.kind == "firewood":
				return T.t("prompt_add_wood")
			return T.t("prompt_cook") if inv_has("meat_raw") else T.t("prompt_need_meat")
		"rv_butcher", "butcher":
			return T.t("prompt_butcher") if held and str(held.kind).begins_with("carcass_") else T.t("prompt_need_carcass")
		"rv_wardrobe":
			return T.t("prompt_wardrobe")
		"rv_engine":
			return T.t("prompt_repair") if inv_has("repair_kit") else T.t("prompt_engine_state", [int(world.rv.hp)])
		"rv_fuel":
			return T.t("prompt_jerrycan") if held and held.kind == "jerrycan" else T.t("prompt_fuel_state", [int(world.rv.fuel), int(world.rv.max_fuel)])
		"shop":
			return T.t("prompt_shop")
		"pump":
			return T.t("prompt_pump", [ItemsDB.FUEL_PRICE])
		"sell_bin":
			return T.t("prompt_sell_bin")
		"water":
			return T.t("prompt_drink_lake")
	if held:
		return T.t("prompt_holding", [ItemsDB.item_name(held.kind)])
	return ""


func _interact() -> void:
	var rv: RV = world.rv
	if seated >= 0:
		if target_kind == "rv_button":
			world.rpc_id(1, "req_button", str(target_node.get_meta("action")))
		else:
			world.rpc_id(1, "req_exit")
		return
	match target_kind:
		"item":
			var kind: String = target_node.kind
			var big: bool = ItemsDB.ITEMS[kind].get("big", false)
			if not big and can_add(kind):
				world.rpc_id(1, "req_pickup", target_node.name)
			else:
				if not big:
					world.hud.add_msg(T.t("msg_inv_full"))
				world.rpc_id(1, "req_grab", target_node.name)
		"rv_seat":
			world.rpc_id(1, "req_sit", int(target_node.get_meta("seat")))
		"rv_button":
			world.rpc_id(1, "req_button", str(target_node.get_meta("action")))
		"rv_hook":
			world.rpc_id(1, "req_hook", int(target_node.get_meta("hook")))
		"cable_place":
			if cable_ok and rv:
				world.rpc_id(1, "req_attach", rv.cable_holder_of(peer_id), cable_point)
		"rv_ladder":
			if global_position.y < rv.global_position.y + 2.5:
				global_position = rv.global_transform * Vector3(-0.6, 3.35, -3.0)
			else:
				var gp: Vector3 = rv.global_transform * Vector3(-0.6, 0.0, -4.5)
				gp.y = TerrainGen.height_at(gp.x, gp.z) + 0.3
				global_position = gp
			velocity = Vector3.ZERO
		"rv_wardrobe":
			world.hud.open_wardrobe(self)
		"shop":
			world.hud.open_shop(self, int(target_node.get_meta("shop_idx")))
		"water":
			_drink_lake()
		"rv_stove", "campfire":
			var held: Node = world.get_held_item(peer_id)
			if held and held.kind == "firewood":
				world.rpc_id(1, "req_station", target_node.get_path(), "")
			elif inv_remove("meat_raw"):
				world.rpc_id(1, "req_station", target_node.get_path(), "meat_raw")
		"rv_engine":
			if inv_remove("repair_kit"):
				world.rpc_id(1, "req_station", target_node.get_path(), "repair_kit")
		"", "cable_hold":
			pass
		_:
			world.rpc_id(1, "req_station", target_node.get_path(), "")


## number_two = false — по-маленькому (стоя), true — по-большому (присев).
func do_toilet(number_two: bool) -> void:
	if emote in ACTION_EMOTES:
		return
	if number_two:
		if bowels < 15.0:
			world.hud.add_msg(T.t("msg_no_need"))
			return
		bowels = 0.0
		_do_action("poo")
		world.sfx_all("strain", global_position, -4.0, randf_range(0.9, 1.1))
		world.rpc_id(1, "req_poo_pile", global_position - global_basis.z * -0.3)
	else:
		if bladder < 10.0:
			world.hud.add_msg(T.t("msg_no_need"))
			return
		bladder = 0.0
		_do_action("pee")
		world.sfx_all("pee", global_position, -4.0, 1.0)
	if randf() < 0.3:
		world.broadcast(T.t("msg_bush", [nick]))


func _do_action(e: String) -> void:
	emote = e
	squat_t = float(ACTION_EMOTES[e])
	if e == "pee" or e == "poo" or e == "smoke":
		squat_t = float(ACTION_EMOTES[e])


func _drink_lake() -> void:
	thirst = minf(thirst + 30.0, 100.0)
	bladder += 10.0
	world.sfx_all("drink", global_position, -4.0, 1.0)
	if randf() < 0.2:
		poison += 25.0
		world.hud.add_msg(T.t("msg_lake_bad"))


# ======================================================================= ИНВЕНТАРЬ
func inv_weight() -> float:
	var w := 0.0
	for e in inventory:
		w += float(ItemsDB.ITEMS[e.kind].mass)
	return w


func can_add(kind: String) -> bool:
	return inventory.size() < MAX_SLOTS and inv_weight() + float(ItemsDB.ITEMS[kind].mass) <= MAX_WEIGHT


func inv_has(kind: String) -> bool:
	for e in inventory:
		if e.kind == kind:
			return true
	return false


func inv_remove(kind: String) -> bool:
	for i in inventory.size():
		if inventory[i].kind == kind:
			inventory.remove_at(i)
			return true
	return false


@rpc("any_peer", "call_local", "reliable")
func inv_add(kind: String, q: float) -> void:
	if not is_multiplayer_authority():
		return
	if can_add(kind):
		inventory.append({"kind": kind, "q": q})
		Sfx.play_ui("pickup", -6)
	else:
		# не влезло — бросаем обратно
		world.rpc_id(1, "req_spawn_item", kind, q, global_position + Vector3.UP * 1.2 - global_basis.z * 0.8, Vector3.ZERO)


func use_slot(i: int) -> void:
	if i < 0 or i >= inventory.size():
		return
	var e: Dictionary = inventory[i]
	var def: Dictionary = ItemsDB.ITEMS[e.kind]
	match def.get("use", ""):
		"eat", "drink":
			if emote in ACTION_EMOTES:
				return
			inventory.remove_at(i)
			_consume(e.kind)
			_do_action("eat" if def.use == "eat" else "drink")
		"smoke":
			if emote in ACTION_EMOTES:
				return
			e.q = float(e.q) - 1.0
			if e.q <= 0.0:
				inventory.remove_at(i)
			_do_action("smoke")
			world.sfx_all("lighter", global_position, -6.0, 1.0)
			warmth = minf(warmth + 4.0, 100.0)
			hunger = minf(hunger + 3.0, 100.0)
		"booze":
			if emote in ACTION_EMOTES:
				return
			inventory.remove_at(i)
			_consume(e.kind)
			_do_action("vodka" if e.kind == "vodka" else "beer")
		"equip":
			_select_weapon(str(def.weapon))
			world.hud.add_msg(T.t("weapon_" + str(def.weapon)))
		"bandage":
			inventory.remove_at(i)
			bleed = 0.0
			hp = minf(hp + 10.0, 100.0)
			Sfx.play_at("zip", global_position, -6)
			world.hud.add_msg(T.t("msg_bandaged"))
		_:
			world.hud.add_msg(T.t("msg_cant_use"))


func drop_slot(i: int) -> void:
	if i < 0 or i >= inventory.size():
		return
	var e: Dictionary = inventory[i]
	inventory.remove_at(i)
	var fwd := -global_basis.z
	world.rpc_id(1, "req_spawn_item", e.kind, float(e.q), global_position + Vector3.UP * 1.2 + fwd * 0.7, fwd * 2.0)


func _consume(kind: String) -> void:
	var f: Dictionary = ItemsDB.FOOD.get(kind, {})
	hunger = clampf(hunger + float(f.get("hunger", 0.0)), 0, 100)
	thirst = clampf(thirst + float(f.get("thirst", 0.0)), 0, 100)
	bladder = clampf(bladder + float(f.get("bladder", 0.0)), 0, 100)
	warmth = clampf(warmth + float(f.get("warmth", 0.0)), 0, 100)
	drunk = clampf(drunk + float(f.get("drunk", 0.0)), 0, 100)
	bowels = clampf(bowels + float(f.get("hunger", 0.0)) * 0.25, 0, 100)
	if randf() < float(f.get("poison", 0.0)):
		poison += 40.0
		world.hud.add_msg(T.t("msg_poisoned"))
	var snd := "drink" if ItemsDB.ITEMS[kind].get("use", "") == "drink" else "eat"
	world.sfx_all(snd, global_position, -4.0, 1.0)


# ======================================================================= ОРУЖИЕ
func weapons_owned() -> Array:
	var out: Array = []
	for w in ItemsDB.WEAPON_ORDER:
		if inv_has("weapon_" + w):
			out.append(w)
	return out


## Если выбранное оружие пропало из рюкзака (выбросили, умерли) — убираем из рук.
func _check_weapon_valid() -> void:
	var o := weapons_owned()
	if (cur_weapon != "" and not inv_has("weapon_" + cur_weapon)) or (cur_weapon == "" and not o.is_empty()):
		cur_weapon = o[0] if not o.is_empty() else ""
		weapon_vis = cur_weapon
		reload_t = 0.0


func _select_weapon(w: String) -> void:
	if w == cur_weapon:
		return
	cur_weapon = w
	weapon_vis = w
	reload_t = 0.0
	Sfx.play_ui("click", -6)


func _cycle_weapon(d: int) -> void:
	var owned := weapons_owned()
	if owned.is_empty():
		return
	var i := owned.find(cur_weapon)
	_select_weapon(owned[(i + d + owned.size()) % owned.size()])


func _cycle_ammo_type() -> void:
	var types: Array = ItemsDB.WEAPONS[cur_weapon].ammo
	if types.size() < 2:
		return
	var i := types.find(mag_type[cur_weapon])
	var nt: String = types[(i + 1) % types.size()]
	# разрядить текущие патроны обратно
	ammo[mag_type[cur_weapon]] += mag[cur_weapon]
	mag[cur_weapon] = 0
	mag_type[cur_weapon] = nt
	world.hud.add_msg(T.t("msg_ammo_type", [T.t("ammo_" + nt)]))
	_start_reload()


func _start_reload() -> void:
	if reload_t > 0.0 or cur_weapon == "":
		return
	var w: Dictionary = ItemsDB.WEAPONS[cur_weapon]
	if mag[cur_weapon] >= int(w.mag) or ammo[mag_type[cur_weapon]] <= 0:
		return
	reload_t = float(w.reload)
	world.sfx_all("reload", global_position, -6.0, 1.0)


func _finish_reload() -> void:
	var w: Dictionary = ItemsDB.WEAPONS[cur_weapon]
	var t: String = mag_type[cur_weapon]
	var need := int(w.mag) - int(mag[cur_weapon])
	var take := mini(need, int(ammo[t]))
	mag[cur_weapon] += take
	ammo[t] -= take


func _on_shoot_pressed() -> void:
	var held: Node = world.get_held_item(peer_id)
	if cur_weapon == "" and held == null:
		return
	if held:
		if Input.is_action_just_pressed("shoot"):
			var dir := (-cam.global_basis.z + Vector3.UP * 0.25).normalized()
			world.rpc_id(1, "req_throw", dir)
			Sfx.play_at("whoosh", global_position, -6)
		return
	if shoot_cd > 0.0 or reload_t > 0.0 or emote == "squat":
		return
	if not Input.is_action_just_pressed("shoot"):
		return
	if mag[cur_weapon] <= 0:
		Sfx.play_at("dry_fire", global_position, -6)
		_start_reload()
		shoot_cd = 0.3
		return
	var w: Dictionary = ItemsDB.WEAPONS[cur_weapon]
	mag[cur_weapon] -= 1
	shoot_cd = float(w.rof)
	emote = ""
	# повернуться к цели перед выстрелом
	rotation.y = cam_yaw
	face_cam_t = 1.0
	aim_vis = true
	aim_pitch = cam_pitch
	_animate(0.0)
	# точка прицеливания — то, что под перекрестием
	var from := cam.global_position
	var fwd := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 600.0, MU.L_WORLD | MU.L_RV | MU.L_ANIMALS | MU.L_ITEMS, [get_rid()])
	q.collide_with_areas = true
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var aim_point: Vector3 = r.position if not r.is_empty() else from + fwd * 600.0
	var muzzle: Vector3 = muzzle_node.global_position if is_instance_valid(muzzle_node) else gun.global_position
	var dir := (aim_point - muzzle).normalized()
	world.rpc_id(1, "req_shoot", muzzle, dir, mag_type[cur_weapon], w.snd)
	# отдача
	cam_pitch = minf(cam_pitch + float(w.recoil) * 0.02, 1.1)
	cam_yaw += randf_range(-1, 1) * float(w.recoil) * 0.006
	var kick := float(w.kick)
	velocity -= fwd * kick * (3.0 if not is_on_floor() else 1.0)
	if mag[cur_weapon] <= 0:
		_start_reload()


# ======================================================================= УДАРЫ, РЭГДОЛЛ, СМЕРТЬ
@rpc("any_peer", "call_local", "reliable")
func get_hit(impulse: Vector3, dmg: float, bleed_add: float) -> void:
	if not is_multiplayer_authority() or dead:
		return
	hp -= dmg
	bleed += bleed_add
	Sfx.play_at("hurt", global_position, -2)
	if seated < 0 or impulse.length() > 8.0:
		start_ragdoll(impulse, 2.5 + dmg * 0.04)


@rpc("any_peer", "call_local", "reliable")
func set_holding(v: bool) -> void:
	if is_multiplayer_authority():
		holding_big = v


@rpc("any_peer", "call_local", "reliable")
func add_ammo(cal: String, n: int) -> void:
	if is_multiplayer_authority():
		ammo[cal] = int(ammo.get(cal, 0)) + n


@rpc("any_peer", "call_local", "reliable")
func give_weapon(w: String) -> void:
	if is_multiplayer_authority() and not inv_has("weapon_" + w):
		inv_add("weapon_" + w, 1.0)
		if inv_has("weapon_" + w):
			_select_weapon(w)
			_start_reload()


func start_ragdoll(impulse: Vector3, dur: float) -> void:
	if ragdoll or not is_multiplayer_authority():
		return
	if seated >= 0:
		world.rpc_id(1, "req_exit")
		seated = -1
		was_seated = -1
	if world.get_held_item(peer_id) != null:
		world.rpc_id(1, "req_drop")
	ragdoll = true
	emote = ""
	shape.disabled = true
	flop = RigidBody3D.new()
	flop.mass = 70.0
	flop.collision_layer = 0
	flop.collision_mask = MU.L_WORLD | MU.L_RV
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.7
	flop.physics_material_override = pm
	flop.angular_damp = 0.8
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	flop.add_child(cs)
	world.add_child(flop)
	flop.global_transform = Transform3D(global_basis, global_position + Vector3.UP * 0.9)
	flop.linear_velocity = velocity + impulse
	flop.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6)) + impulse.cross(Vector3.UP) * 0.3
	flop_t = dur


func _ragdoll_update(delta: float) -> void:
	if flop == null:
		ragdoll = false
		return
	flop_t -= delta
	global_transform = flop.global_transform * Transform3D(Basis(), Vector3(0, -0.9, 0))
	if TerrainGen.WATER - flop.global_position.y > 0.3:
		flop.apply_central_force(Vector3.UP * 1100.0)
		flop.linear_velocity *= 0.98
	if not dead and flop_t <= 0.0 and (flop.linear_velocity.length() < 1.5 or flop_t < -4.0):
		_get_up()


func _get_up() -> void:
	var p := flop.global_position
	flop.queue_free()
	flop = null
	ragdoll = false
	shape.disabled = false
	global_transform = Transform3D(Basis(Vector3.UP, cam_yaw), p + Vector3.UP * 0.1)
	global_position.y = maxf(global_position.y - 0.8, TerrainGen.height_at(p.x, p.z) + 0.05)
	velocity = Vector3.ZERO


func _die() -> void:
	dead = true
	dead_t = 12.0
	world.broadcast(T.t("msg_died", [nick]))
	world.sfx_all("hurt", global_position, 2.0, 0.6)
	if not ragdoll:
		start_ragdoll(Vector3.ZERO, 999.0)
	# всё выпадает из карманов
	for e in inventory:
		world.rpc_id(1, "req_spawn_item", e.kind, float(e.q), global_position + Vector3.UP * 1.0 + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)), Vector3.UP * 2.0)
	inventory.clear()
	world.rpc_id(1, "req_death_penalty")


func _dead_update(delta: float) -> void:
	dead_t -= delta
	if flop:
		global_transform = flop.global_transform * Transform3D(Basis(), Vector3(0, -0.9, 0))
	if dead_t <= 0.0:
		_respawn()


func _respawn() -> void:
	if flop:
		flop.queue_free()
		flop = null
	ragdoll = false
	dead = false
	hp = 70.0
	hunger = maxf(hunger, 50.0)
	thirst = maxf(thirst, 50.0)
	warmth = 80.0
	wetness = 0.0
	bleed = 0.0
	poison = 0.0
	bladder = 0.0
	bowels = 0.0
	drunk = 0.0
	var p: Vector3 = world.get_respawn_point()
	global_transform = Transform3D(Basis(), p)
	velocity = Vector3.ZERO
	shape.disabled = false


# ======================================================================= ЭМОЦИИ
func play_emote(e: String) -> void:
	if dead or seated >= 0:
		return
	if e == "flop":
		start_ragdoll(-global_basis.z * 2.0 + Vector3.UP * 2.0, 2.0)
		world.sfx_all("whoosh", global_position, -4.0, 0.8)
		return
	emote = e
	match e:
		"laugh":
			world.sfx_all("laugh", global_position, -2.0, randf_range(0.9, 1.15))
		"point", "wave":
			world.sfx_all("hey", global_position, -2.0, randf_range(0.9, 1.15))


# ======================================================================= ПОТРЕБНОСТИ
func _update_needs(delta: float) -> void:
	_needs_t += delta
	if _needs_t < 0.25:
		return
	var dt := _needs_t
	_needs_t = 0.0
	var moving := Vector2(velocity.x, velocity.z).length() > 5.0
	hunger = maxf(hunger - dt * (0.075 if not moving else 0.12), 0.0)
	thirst = maxf(thirst - dt * (0.12 if not moving else 0.18), 0.0)
	bladder = minf(bladder + dt * 0.14, 100.0)
	bowels = minf(bowels + dt * 0.05, 100.0)
	if drunk > 0.0:
		drunk = maxf(drunk - dt * 0.6, 0.0)
	# сырость
	var outdoors := not (seated >= 0 or (ride and ride_xf.origin.y < 3.0))
	var in_water := TerrainGen.WATER - global_position.y > 0.4 and seated < 0
	var heat: float = world.heat_at(global_position)
	if in_water:
		wetness = minf(wetness + dt * 30.0, 100.0)
	elif world.raining and outdoors:
		wetness = minf(wetness + dt * (0.35 if raincoat else 2.2), 100.0)
	if heat > 0.0:
		wetness = maxf(wetness - dt * 5.0 * heat, 0.0)
	elif not world.raining and world.is_day():
		wetness = maxf(wetness - dt * 0.4, 0.0)
	elif not outdoors:
		wetness = maxf(wetness - dt * 0.6, 0.0)
	# тепло
	var t: float = world.ambient_temp()
	if not outdoors:
		t += 10.0
	var insulation := 0.0
	if jacket:
		insulation += 12.0 * (1.0 - 0.6 * smoothstep(40.0, 90.0, wetness))
	if raincoat:
		insulation += 3.0
	var eff := t + insulation + heat * 22.0 - wetness * 0.14 + drunk * 0.06
	if eff < 12.0:
		warmth = maxf(warmth - dt * (12.0 - eff) * 0.06, 0.0)
	else:
		warmth = minf(warmth + dt * (1.0 + heat * 4.0), 100.0)
	# здоровье
	var dmg := 0.0
	if hunger <= 0.0:
		dmg += 0.35
	if thirst <= 0.0:
		dmg += 0.6
	if warmth <= 0.0:
		dmg += 0.6
	dmg += bleed
	if poison > 0.0:
		poison = maxf(poison - dt * 2.0, 0.0)
		bladder = minf(bladder + dt * 0.5, 100.0)
		dmg += 0.1
	bleed = maxf(bleed - dt * 0.015, 0.0)   # мелкие раны затягиваются
	bleeding_vis = bleed > 0.05
	hp -= dmg * dt
	if dmg <= 0.0 and hunger > 50.0 and thirst > 50.0 and warmth > 50.0:
		hp = minf(hp + dt * 0.25, 100.0)
	wet_vis = wetness
	# туалет
	if bladder >= 100.0:
		bladder = 0.0
		wetness = minf(wetness + 45.0, 100.0)
		world.sfx_all("fart", global_position, 0.0, 1.0)
		world.broadcast(T.t("msg_accident", [nick]))
	if bowels >= 100.0:
		bowels = 0.0
		wetness = minf(wetness + 20.0, 100.0)
		world.sfx_all("fart", global_position, 3.0, 0.7)
		world.broadcast(T.t("msg_accident2", [nick]))
	if hp <= 0.0 and not dead:
		hp = 0.0
		_die()


# ======================================================================= АНИМАЦИЯ (у всех)
func _animate(delta: float) -> void:
	if delta > 0.0:
		var hv := global_position - last_pos
		hv.y = 0
		anim_speed = lerpf(anim_speed, hv.length() / delta, clampf(delta * 10.0, 0, 1))
		last_pos = global_position
	if emote != _last_emote:
		_last_emote = emote
		emote_t = 0.0
	emote_t += delta
	var seat_i := _seat_index()
	raincoat_mi.visible = raincoat
	(torso_mi.material_override as StandardMaterial3D)
	torso_mi.material_override = MU.mat(COLORS[color_idx % COLORS.size()] if jacket else Color(0.9, 0.9, 0.85))
	if gun.get_meta("w", "x") != weapon_vis:
		_build_gun_model(weapon_vis)
	flashlight.visible = light_on and not dead
	drips.emitting = wet_vis > 45.0 and not dead
	smoke_fx.emitting = emote == "smoke" and fmod(emote_t, 2.3) > 1.0 and fmod(emote_t, 2.3) < 1.9
	pee_fx.emitting = emote == "pee" and emote_t > 0.6 and emote_t < 2.9
	_set_hand_prop(emote if emote in ["smoke", "beer", "vodka", "drink", "eat"] else "")
	if not is_multiplayer_authority():
		name_label.visible = not dead
	if bleeding_vis and delta > 0.0 and seat_i < 0:
		_blood_t -= delta
		if _blood_t <= 0.0:
			_blood_t = 1.2
			world.add_blood(global_position)
	# поза
	var la := Vector3.ZERO
	var ra := Vector3.ZERO
	var ll := Vector3.ZERO
	var rl := Vector3.ZERO
	var hip_y := 0.95
	var hip_rot := Vector3.ZERO
	var head_rot := Vector3(clampf(aim_pitch, -0.8, 0.8) * 0.6, 0, 0)
	var show_gun := not holding_big and seat_i < 0 and emote == "" and weapon_vis != ""
	var aim_pose := false
	if ragdoll or dead:
		var t := Time.get_ticks_msec() * 0.001
		la = Vector3(sin(t * 9.0) * 1.2, 0, -1.2 + sin(t * 7.0) * 0.6)
		ra = Vector3(cos(t * 8.0) * 1.2, 0, 1.2 + cos(t * 6.0) * 0.6)
		ll = Vector3(sin(t * 10.0) * 0.8, 0, -0.3)
		rl = Vector3(cos(t * 11.0) * 0.8, 0, 0.3)
		if dead:
			la = Vector3(0, 0, -1.4)
			ra = Vector3(0, 0, 1.4)
			ll = Vector3.ZERO
			rl = Vector3.ZERO
		show_gun = false
	elif seat_i >= 0:
		ll = Vector3(1.5, 0, 0)
		rl = Vector3(1.5, 0, 0)
		la = Vector3(0.6, 0, 0)
		ra = Vector3(0.6, 0, 0)
		hip_y = 0.5
		if seat_i == 0:
			la = Vector3(1.2, 0, 0.2)
			ra = Vector3(1.2, 0, -0.2)
	elif emote != "":
		show_gun = false
		var t := emote_t
		match emote:
			"wave":
				ra = Vector3(0, 0, 2.6 + sin(t * 10.0) * 0.4)
			"dance":
				hip_y = 0.95 + absf(sin(t * 6.0)) * 0.08
				la = Vector3(0, 0, -2.4 + sin(t * 6.0) * 0.6)
				ra = Vector3(0, 0, 2.4 + sin(t * 6.0 + PI) * 0.6)
				ll = Vector3(sin(t * 6.0) * 0.5, 0, 0)
				rl = Vector3(-sin(t * 6.0) * 0.5, 0, 0)
				hip_rot.y = sin(t * 3.0) * 0.6
			"laugh":
				hip_rot.x = -0.2 + sin(t * 18.0) * 0.06
				head_rot = Vector3(-0.4, 0, 0)
				la = Vector3(0.3, 0, -0.3)
				ra = Vector3(0.3, 0, 0.3)
			"point":
				ra = Vector3(1.6, 0, 0)
			"sit":
				hip_y = 0.45
				ll = Vector3(1.5, 0, -0.1)
				rl = Vector3(1.5, 0, 0.1)
				la = Vector3(0.3, 0, -0.2)
				ra = Vector3(0.3, 0, 0.2)
			"facepalm":
				ra = Vector3(2.4, 0, 0.6)
				head_rot = Vector3(0.4, 0, 0)
			"shrug":
				la = Vector3(0, 0, -0.9)
				ra = Vector3(0, 0, 0.9)
				head_rot = Vector3(0, 0, 0.25)
			"squat", "poo":
				hip_y = 0.5
				ll = Vector3(1.4, 0, -0.35)
				rl = Vector3(1.4, 0, 0.35)
				la = Vector3(0.9, 0, -0.3)
				ra = Vector3(0.9, 0, 0.3)
				hip_rot.x = 0.25 + sin(t * 3.0) * 0.05
				head_rot = Vector3(-0.3 + sin(t * 2.0) * 0.1, 0, 0)
			"pee":
				la = Vector3(0.5, 0, 0.35)
				ra = Vector3(0.5, 0, -0.35)
				head_rot = Vector3(-0.5, sin(t * 1.5) * 0.4, 0)
			"eat":
				ra = Vector3(2.3 + sin(t * 9.0) * 0.15, 0, -0.35)
				head_rot = Vector3(0.1, 0, 0)
			"drink", "beer", "vodka":
				ra = Vector3(2.6, 0, -0.3)
				head_rot = Vector3(-0.55, 0, 0)
				hip_rot.x = -0.08
			"smoke":
				# затяжка раз в ~2.3 с
				var puff := fmod(t, 2.3) < 1.0
				ra = Vector3(2.45, 0, -0.35) if puff else Vector3(0.4, 0, 0.1)
				head_rot = Vector3(-0.15 if puff else 0.0, 0, 0)
		if not emote in LOOP_EMOTES and not emote in ACTION_EMOTES and emote != "squat" and emote_t > 3.5 and is_multiplayer_authority():
			emote = ""
	else:
		var k := clampf(anim_speed / 6.0, 0.0, 1.2)
		anim_phase += delta * (4.0 + anim_speed * 1.6)
		var sw := sin(anim_phase) * 0.8 * k
		ll = Vector3(sw, 0, 0)
		rl = Vector3(-sw, 0, 0)
		la = Vector3(-sw * 0.7, 0, -0.1)
		ra = Vector3(sw * 0.7, 0, 0.1)
		hip_y = 0.95 + absf(sin(anim_phase)) * 0.04 * k
		if holding_big:
			la = Vector3(1.4, 0, -0.1)
			ra = Vector3(1.4, 0, 0.1)
		elif show_gun:
			aim_pose = true
	if aim_pose and aim_vis:
		# приклад в плечо, ствол смотрит туда же, куда камера
		var p := clampf(aim_pitch, -1.0, 1.0)
		var sh := Vector3(0.2, 0.6, 0.0)
		gun.rotation = Vector3(p, 0, 0)
		gun.position = sh + Basis(Vector3.RIGHT, p) * Vector3(0.0, -0.02, -0.3)
		ra = Vector3(1.5 + p, 0.0, -0.12)
		la = Vector3(1.42 + p, 0.0, 0.8)
		head_rot = Vector3(clampf(aim_pitch, -0.8, 0.8) * 0.5, 0, -0.08)
	else:
		gun.rotation = Vector3(0.0, 0.0, 0.9)
		gun.position = Vector3(0.0, 0.4, 0.2)   # за спиной
	gun.visible = show_gun and not ragdoll and not dead
	var s := clampf(delta * 14.0, 0, 1) if delta > 0.0 else 1.0
	arm_l.rotation = arm_l.rotation.lerp(la, s)
	arm_r.rotation = arm_r.rotation.lerp(ra, s)
	leg_l.rotation = leg_l.rotation.lerp(ll, s)
	leg_r.rotation = leg_r.rotation.lerp(rl, s)
	head.rotation = head.rotation.lerp(head_rot, s)
	hips.position.y = lerpf(hips.position.y, hip_y, s)
	hips.rotation = hips.rotation.lerp(hip_rot, s)
	_footsteps(delta, seat_i)


func _footsteps(delta: float, seat_i: int) -> void:
	if delta <= 0.0 or seat_i >= 0 or ragdoll or dead or emote != "":
		return
	if anim_speed < 1.2:
		return
	step_t -= delta
	if step_t <= 0.0:
		step_t = 0.5 if anim_speed < 5.0 else 0.33
		var in_water := TerrainGen.WATER - global_position.y > 0.05
		Sfx.play_at("splash" if in_water else "step", global_position, -14.0 if in_water else -10.0, randf_range(0.85, 1.15))


## Точка, куда хост тянет переносимый предмет.
func get_hold_point(dist: float) -> Vector3:
	var b := Basis(Vector3.UP, rotation.y) * Basis(Vector3.RIGHT, clampf(aim_pitch, -0.6, 0.5))
	return global_position + Vector3.UP * 1.15 + b * Vector3(0, 0, -dist)
