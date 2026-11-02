class_name MU
extends RefCounted
## Общие утилиты: слои коллизий, материалы, примитивы, синхронизаторы.

const L_WORLD := 1
const L_ITEMS := 2
const L_PLAYERS := 4
const L_RV := 8
const L_ANIMALS := 16
const L_INTERACT := 32

const RL_DEFAULT := 1
const RL_OWN_BODY := 2   # слой рендера тела своего игрока (скрыт в 1-м лице)

static var _mats := {}


static func mat(c: Color, rough: float = 0.85, emit: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(true), rough, emit, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if c.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


static func _mi(mesh: Mesh, m: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	return mi


static func box(size: Vector3, c: Variant, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mi(m, _as_mat(c), pos, rot)


static func sphere(r: float, c: Variant, pos := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	var mi := _mi(m, _as_mat(c), pos, Vector3.ZERO)
	mi.scale = scl
	return mi


static func cyl(r_top: float, r_bot: float, h: float, c: Variant, pos := Vector3.ZERO, rot := Vector3.ZERO, seg := 12) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return _mi(m, _as_mat(c), pos, rot)


static func capsule(r: float, h: float, c: Variant, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 16
	m.rings = 6
	return _mi(m, _as_mat(c), pos, rot)


static func _as_mat(c: Variant) -> Material:
	if c is Material:
		return c
	return mat(c)


static func static_box(size: Vector3, pos: Vector3, rot := Vector3.ZERO, layer := L_WORLD) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	sb.rotation_degrees = rot
	return sb


## Зона взаимодействия (луч игрока её «видит»).
static func area_box(size: Vector3, pos: Vector3, kind: String, nm: String) -> Area3D:
	var a := Area3D.new()
	a.name = nm
	a.collision_layer = L_INTERACT
	a.collision_mask = 0
	a.monitoring = false
	a.set_meta("kind", kind)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	a.add_child(cs)
	a.position = pos
	return a


static func label3d(text: String, pos: Vector3, size := 64, color := Color.WHITE, billboard := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 14
	l.modulate = color
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return l


## Синхронизатор свойств сущности (авторитет = владелец узла).
static func make_sync(props: Array, interval: float, on_change := false, nm := "Sync") -> MultiplayerSynchronizer:
	var s := MultiplayerSynchronizer.new()
	s.name = nm
	var cfg := SceneReplicationConfig.new()
	for p in props:
		var np := NodePath(".:" + str(p))
		cfg.add_property(np)
		cfg.property_set_spawn(np, true)
		cfg.property_set_replication_mode(np, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE if on_change else SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	s.replication_config = cfg
	s.replication_interval = interval
	return s


static func set_render_layers(n: Node, layers: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = layers
	for c in n.get_children():
		set_render_layers(c, layers)


## Найти узел с мета-ключом "kind", поднимаясь вверх по дереву.
static func find_kind_node(n: Object) -> Node:
	var cur: Node = n as Node
	var depth := 0
	while cur != null and depth < 4:
		if cur.has_meta("kind"):
			return cur
		cur = cur.get_parent()
		depth += 1
	return null
