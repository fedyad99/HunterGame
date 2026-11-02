class_name TerrainGen
extends RefCounted
## Детерминированная генерация рельефа: одинакова у всех игроков (общий сид),
## поэтому по сети передаются только динамические объекты.

const HALF := 400.0
const STEP := 2.0
const N := 401
const WATER := 0.0
const SEED := 1337

static var noise: FastNoiseLite
static var detail: FastNoiseLite
static var hills: FastNoiseLite
static var outposts: Array = []
static var roads: Array = []          # [[Vector2 a, Vector2 b], ...]
static var grid := PackedFloat32Array()
static var road_w := PackedFloat32Array()
static var swamp := PackedFloat32Array()     # 0..1 — насколько топко (болото)
static var swampn: FastNoiseLite


static func init_data() -> void:
	if noise != null:
		return
	noise = FastNoiseLite.new()
	noise.seed = SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0032
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	hills = FastNoiseLite.new()
	hills.seed = SEED + 3
	hills.frequency = 0.011
	hills.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	hills.fractal_octaves = 3
	detail = FastNoiseLite.new()
	detail.seed = SEED + 7
	detail.frequency = 0.05
	detail.fractal_octaves = 2
	swampn = FastNoiseLite.new()
	swampn.seed = SEED + 11
	swampn.frequency = 0.012
	swampn.fractal_octaves = 3
	outposts = [
		{"id": 0, "key": "outpost_0", "pos": Vector2(-250, -220), "r": 36.0, "shop": true},
		{"id": 1, "key": "outpost_1", "pos": Vector2(240, -240), "r": 32.0, "shop": true},
		{"id": 2, "key": "outpost_2", "pos": Vector2(210, 230), "r": 36.0, "shop": true},
		{"id": 3, "key": "outpost_3", "pos": Vector2(-230, 230), "r": 26.0, "shop": false},
	]
	for o in outposts:
		o["h"] = maxf(smooth_height(o.pos.x, o.pos.y), WATER + 2.5)
	roads.clear()
	var links := [[0, 1], [1, 2], [2, 3], [3, 0]]
	for l in links:
		var a: Vector2 = outposts[l[0]].pos
		var b: Vector2 = outposts[l[1]].pos
		var mid := (a + b) * 0.5
		var perp := (b - a).orthogonal().normalized()
		var off := perp * (45.0 if l[0] % 2 == 0 else -55.0)
		var pts := [a, (a + mid) * 0.5 + off * 0.6, mid + off, (mid + b) * 0.5 + off * 0.6, b]
		for i in range(pts.size() - 1):
			roads.append([pts[i], pts[i + 1]])


static func smooth_height(x: float, z: float) -> float:
	var h := noise.get_noise_2d(x, z) * 44.0 + 8.0
	# холмы и гребни
	h += (hills.get_noise_2d(x, z) * 0.5 + 0.5) * 9.0
	var e := maxf(absf(x), absf(z))
	h += smoothstep(320.0, HALF, e) * 70.0
	return h


## Возвращает Vector3(расстояние до дороги, высота дороги, 0).
static func road_query(p: Vector2) -> Vector2:
	var best := 1e9
	var bc := Vector2.ZERO
	var bdir := Vector2.RIGHT
	for s in roads:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var c := a + ab * t
		var d := p.distance_to(c)
		if d < best:
			best = d
			bc = c
			bdir = ab.normalized()
	if best > 14.0:
		return Vector2(best, 0.0)
	# высота дороги сглажена вдоль трассы, чтобы не было резких горок
	var hsum := 0.0
	for k in [-2, -1, 0, 1, 2]:
		var pp: Vector2 = bc + bdir * (k * 12.0)
		hsum += _ramp(pp, smooth_height(pp.x, pp.y))
	return Vector2(best, maxf(hsum / 5.0, WATER + 1.0))


## Плавный въезд на площадку фактории.
static func _ramp(p: Vector2, h: float) -> float:
	for o in outposts:
		var d := p.distance_to(o.pos)
		var r: float = o.r
		if d < r + 60.0:
			h = lerpf(h, float(o.h), 1.0 - smoothstep(r, r + 60.0, d))
	return h


static func compute_height(x: float, z: float) -> float:
	var h := smooth_height(x, z) + detail.get_noise_2d(x, z) * 1.4
	var p := Vector2(x, z)
	var rq := road_query(p)
	if rq.x < 12.0:
		var w := 1.0 - smoothstep(4.5, 12.0, rq.x)
		h = lerpf(h, rq.y, w)
	for o in outposts:
		var d := p.distance_to(o.pos)
		var r: float = o.r
		if d < r + 60.0:
			var w2 := 1.0 - smoothstep(r, r + 60.0, d)
			h = lerpf(h, float(o.h), w2)
	return h


static func build_grid() -> void:
	init_data()
	if grid.size() == N * N:
		return
	grid.resize(N * N)
	road_w.resize(N * N)
	swamp.resize(N * N)
	for iz in N:
		for ix in N:
			var x := -HALF + ix * STEP
			var z := -HALF + iz * STEP
			var i := iz * N + ix
			grid[i] = compute_height(x, z)
			var rq := road_query(Vector2(x, z))
			road_w[i] = 1.0 - smoothstep(2.5, 4.5, rq.x)
			swamp[i] = _swamp_val(x, z, grid[i], rq.x)


## Болота: низины у воды и в ложбинах, подальше от дорог и факторий.
static func _swamp_val(x: float, z: float, h: float, road_d: float) -> float:
	if h < WATER + 0.3:
		return 0.0
	var n := swampn.get_noise_2d(x, z) * 0.5 + 0.5
	var v := smoothstep(0.52, 0.66, n) * (1.0 - smoothstep(5.0, 12.0, h))
	v *= smoothstep(9.0, 18.0, road_d)
	for o in outposts:
		var d := Vector2(x, z).distance_to(o.pos)
		v *= smoothstep(float(o.r) + 15.0, float(o.r) + 45.0, d)
	return clampf(v, 0.0, 1.0)


static func swamp_at(x: float, z: float) -> float:
	if swamp.size() != N * N:
		return 0.0
	var fx := clampf((x + HALF) / STEP, 0.0, N - 1.001)
	var fz := clampf((z + HALF) / STEP, 0.0, N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * N + ix
	var a := lerpf(swamp[i], swamp[i + 1], tx)
	var b := lerpf(swamp[i + N], swamp[i + N + 1], tx)
	return lerpf(a, b, tz)


static func height_at(x: float, z: float) -> float:
	var fx := clampf((x + HALF) / STEP, 0.0, N - 1.001)
	var fz := clampf((z + HALF) / STEP, 0.0, N - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * N + ix
	var h0 := lerpf(grid[i], grid[i + 1], tx)
	var h1 := lerpf(grid[i + N], grid[i + N + 1], tx)
	return lerpf(h0, h1, tz)


static func normal_at(x: float, z: float) -> Vector3:
	var hl := height_at(x - 1.0, z)
	var hr := height_at(x + 1.0, z)
	var hu := height_at(x, z - 1.0)
	var hd := height_at(x, z + 1.0)
	return Vector3(hl - hr, 2.0, hu - hd).normalized()


static func is_land(x: float, z: float, margin := 0.6) -> bool:
	return height_at(x, z) > WATER + margin and absf(x) < 330.0 and absf(z) < 330.0


static func build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	uv2.resize(N * N)
	verts.resize(N * N)
	norms.resize(N * N)
	cols.resize(N * N)
	uvs.resize(N * N)
	for iz in N:
		for ix in N:
			var i := iz * N + ix
			var h := grid[i]
			verts[i] = Vector3(-HALF + ix * STEP, h, -HALF + iz * STEP)
			var hl := grid[iz * N + maxi(ix - 1, 0)]
			var hr := grid[iz * N + mini(ix + 1, N - 1)]
			var hu := grid[maxi(iz - 1, 0) * N + ix]
			var hd := grid[mini(iz + 1, N - 1) * N + ix]
			var n := Vector3(hl - hr, 2.0 * STEP, hu - hd).normalized()
			norms[i] = n
			uvs[i] = Vector2(ix, iz) * 0.5
			uv2[i] = Vector2(swamp[i], 0.0)
			# Канал R — «трава/земля», G — скала, B — песок, A — дорога (маска для шейдера).
			var sand := 1.0 - smoothstep(WATER + 0.6, WATER + 2.0, h)
			var rock := 1.0 - smoothstep(0.72, 0.86, n.y)
			rock = maxf(rock, smoothstep(70.0, 85.0, h))
			cols[i] = Color(detail.get_noise_2d(ix * 7.0, iz * 7.0) * 0.5 + 0.5, rock, sand, road_w[i])
	var idx := PackedInt32Array()
	idx.resize((N - 1) * (N - 1) * 6)
	var k := 0
	for iz in N - 1:
		for ix in N - 1:
			var a := iz * N + ix
			idx[k] = a
			idx[k + 1] = a + 1
			idx[k + 2] = a + N
			idx[k + 3] = a + 1
			idx[k + 4] = a + N + 1
			idx[k + 5] = a + N
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
