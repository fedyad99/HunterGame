class_name Item
extends RigidBody3D
## Физический предмет. Симулируется только у хоста, клиенты интерполируют.

var kind := ""
var q := 1.0                 # качество (для туш) или количество (сигареты)
var sync_xform := Transform3D()
var holder := 0
var world: Node
var _last_v := Vector3.ZERO
var _thud_t := 0.0


func setup(data: Dictionary) -> void:
	kind = data.kind
	q = float(data.get("q", 1.0))
	name = data.name
	position = data.pos
	sync_xform = Transform3D(Basis(), data.pos)
	var def: Dictionary = ItemsDB.ITEMS[kind]
	mass = float(def.mass)
	collision_layer = MU.L_ITEMS
	collision_mask = MU.L_WORLD | MU.L_ITEMS | MU.L_RV
	set_meta("kind", "item")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = def.size
	cs.shape = bs
	add_child(cs)
	add_child(ItemsDB.build_visual(kind))
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.2
	pm.friction = 0.9
	physics_material_override = pm
	angular_damp = 0.6
	continuous_cd = mass < 3.0
	add_child(MU.make_sync(["sync_xform", "holder"], 0.033))


func _ready() -> void:
	world = get_tree().current_scene
	if not multiplayer.is_server():
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		global_transform = sync_xform


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		global_transform = global_transform.interpolate_with(sync_xform, clampf(delta * 15.0, 0.0, 1.0))
		return
	_thud_t -= delta
	if holder != 0:
		var p: Node = world.get_player(holder)
		if p == null or p.ragdoll or p.dead:
			holder = 0
		else:
			var def: Dictionary = ItemsDB.ITEMS[kind]
			var target: Vector3 = p.get_hold_point(float(def.get("hold", 1.3)))
			var diff := target - global_position
			if diff.length() > 4.0:
				holder = 0   # зацепилось за дерево — выронил
			else:
				var k: float = def.get("carry", 8.0)
				var desired: Vector3 = diff * k + (p.velocity if p.is_multiplayer_authority() else Vector3.ZERO)
				desired = desired.limit_length(14.0)
				linear_velocity = linear_velocity.lerp(desired, clampf(0.12 * k, 0.1, 0.6))
				angular_velocity *= 0.92
	else:
		var dv := (linear_velocity - _last_v).length()
		if dv > 3.5 and _thud_t <= 0.0:
			_thud_t = 0.25
			world.sfx_all("thud", global_position, clampf(-14.0 + mass * 0.2, -14.0, 2.0), clampf(1.6 - mass * 0.01, 0.6, 1.6))
	_last_v = linear_velocity
	if global_position.y < -40.0:
		queue_free()
	sync_xform = global_transform
