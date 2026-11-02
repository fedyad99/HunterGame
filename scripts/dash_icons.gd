class_name DashIcons
extends RefCounted
## Процедурные иконки и циферблаты для приборной панели (без единой буквы).
## Рисуем прямо в Image: белое на прозрачном — цвет задаёт материал.

static var _cache := {}


static func _img(n: int) -> Image:
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	return im


static func _disc(im: Image, cx: float, cy: float, r: float, col: Color) -> void:
	for y in range(maxi(int(cy - r - 1), 0), mini(int(cy + r + 2), im.get_height())):
		for x in range(maxi(int(cx - r - 1), 0), mini(int(cx + r + 2), im.get_width())):
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				im.set_pixel(x, y, col)


static func _rect(im: Image, x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	for y in range(maxi(int(y0), 0), mini(int(y1), im.get_height())):
		for x in range(maxi(int(x0), 0), mini(int(x1), im.get_width())):
			im.set_pixel(x, y, col)


static func _line(im: Image, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var n := int(a.distance_to(b) * 2.0) + 1
	for i in n + 1:
		_disc(im, lerpf(a.x, b.x, float(i) / n), lerpf(a.y, b.y, float(i) / n), w * 0.5, col)


static func _arc(im: Image, c: Vector2, r: float, a0: float, a1: float, w: float, col: Color) -> void:
	var n := int(absf(a1 - a0) * r) + 2
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		_disc(im, c.x + cos(a) * r, c.y + sin(a) * r, w * 0.5, col)


static func _tri(im: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var mn := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)))
	var mx := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)))
	for y in range(maxi(int(mn.y), 0), mini(int(mx.y) + 1, im.get_height())):
		for x in range(maxi(int(mn.x), 0), mini(int(mx.x) + 1, im.get_width())):
			var p := Vector2(x + 0.5, y + 0.5)
			var d1 := (p - b).cross(a - b)
			var d2 := (p - c).cross(b - c)
			var d3 := (p - a).cross(c - a)
			if not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0)):
				im.set_pixel(x, y, col)


static func icon(kind: String) -> ImageTexture:
	if _cache.has(kind):
		return _cache[kind]
	var im := _img(64)
	var w := Color.WHITE
	var clear := Color(0, 0, 0, 0)
	match kind:
		"fuel":   # колонка с шлангом
			_rect(im, 12, 10, 38, 54, w)
			_rect(im, 17, 15, 33, 29, clear)
			_rect(im, 8, 52, 42, 58, w)
			_line(im, Vector2(38, 22), Vector2(48, 22), 4, w)
			_line(im, Vector2(48, 22), Vector2(48, 44), 4, w)
			_disc(im, 48, 46, 4, w)
		"engine":   # блок двигателя
			_rect(im, 16, 24, 48, 46, w)
			_rect(im, 24, 14, 42, 24, w)
			_rect(im, 6, 30, 16, 40, w)
			_rect(im, 48, 28, 58, 40, w)
			_rect(im, 30, 8, 36, 14, w)
			_disc(im, 32, 35, 5, clear)
		"lights":   # фара и лучи
			_disc(im, 40, 32, 15, w)
			_rect(im, 40, 17, 56, 47, w)
			_disc(im, 40, 32, 9, clear)
			_rect(im, 40, 23, 50, 41, clear)
			for yy in [20, 32, 44]:
				_line(im, Vector2(6, yy), Vector2(22, yy), 4, w)
		"horn":   # рупор и волны
			_rect(im, 8, 26, 22, 38, w)
			_tri(im, Vector2(22, 26), Vector2(40, 12), Vector2(40, 52), w)
			_tri(im, Vector2(22, 38), Vector2(40, 12), Vector2(40, 52), w)
			_arc(im, Vector2(40, 32), 10, -0.9, 0.9, 3, w)
			_arc(im, Vector2(40, 32), 18, -0.9, 0.9, 3, w)
		"winch_front", "winch_rear":   # машина сбоку и трос с крюком
			var front := kind == "winch_front"
			_rect(im, 8, 44, 56, 54, w)
			_rect(im, 18, 36, 46, 44, w)
			_disc(im, 18, 56, 5, w)
			_disc(im, 46, 56, 5, w)
			var hx := 56.0 if front else 8.0
			var dirx := 1.0 if front else -1.0
			_line(im, Vector2(hx, 46), Vector2(hx + dirx * 0.0, 18), 3, w)
			_arc(im, Vector2(hx - dirx * 5, 16), 6, 0.0, TAU, 3, w)
			_line(im, Vector2(hx, 18), Vector2(hx - dirx * 12, 8), 3, w)
		"brake":   # ручник: круг со скобками
			_arc(im, Vector2(32, 32), 18, 0.0, TAU, 4, w)
			_arc(im, Vector2(32, 32), 27, 2.4, 3.9, 4, w)
			_arc(im, Vector2(32, 32), 27, -0.75, 0.75, 4, w)
			_rect(im, 29, 22, 35, 36, w)
			_disc(im, 32, 42, 3.5, w)
		"battery":
			_rect(im, 8, 20, 56, 52, w)
			_rect(im, 14, 14, 22, 20, w)
			_rect(im, 42, 14, 50, 20, w)
			_rect(im, 14, 33, 26, 38, clear)
			_rect(im, 38, 33, 50, 38, clear)
			_rect(im, 42, 28, 47, 43, clear)
	var tex := ImageTexture.create_from_image(im)
	_cache[kind] = tex
	return tex


## Циферблат: засечки по дуге 270°, длинные через long_every, красная зона с red_from (0..1) или -1.
static func dial(ticks: int, long_every: int, red_from: float, with_ring := true) -> ImageTexture:
	var key := "dial%d_%d_%.2f" % [ticks, long_every, red_from]
	if _cache.has(key):
		return _cache[key]
	var n := 256
	var im := _img(n)
	var c := Vector2(n, n) * 0.5
	_disc(im, c.x, c.y, n * 0.5 - 1, Color(0.04, 0.045, 0.05, 1))
	if with_ring:
		_arc(im, c, n * 0.5 - 4, 0.0, TAU, 5, Color(0.55, 0.55, 0.58, 1))
	var a0 := deg_to_rad(135.0)
	var sweep := deg_to_rad(270.0)
	for i in ticks + 1:
		var k := float(i) / ticks
		var a := a0 + sweep * k
		var long := i % long_every == 0
		var r0 := n * (0.34 if long else 0.40)
		var r1 := n * 0.46
		var col := Color(0.9, 0.9, 0.85, 1)
		if red_from >= 0.0 and k >= red_from:
			col = Color(0.95, 0.2, 0.15, 1)
		_line(im, c + Vector2(cos(a), sin(a)) * r0, c + Vector2(cos(a), sin(a)) * r1, 6.0 if long else 3.5, col)
	if red_from >= 0.0:
		_arc(im, c, n * 0.30, a0 + sweep * red_from, a0 + sweep, 5, Color(0.95, 0.2, 0.15, 1))
	var tex := ImageTexture.create_from_image(im)
	_cache[key] = tex
	return tex


## Пластина Н-образной кулисы КПП: прорези и точки (1…5), у задней — кольцо.
static func shift_plate() -> ImageTexture:
	if _cache.has("plate"):
		return _cache["plate"]
	var n := 256
	var im := _img(n)
	im.fill(Color(0.1, 0.1, 0.11, 1))
	var slot := Color(0.02, 0.02, 0.02, 1)
	var line := Color(0.75, 0.75, 0.7, 1)
	var xs := [48.0, 128.0, 208.0]
	for x in xs:
		_line(im, Vector2(x, 44), Vector2(x, 212), 14, slot)
	_line(im, Vector2(48, 128), Vector2(208, 128), 14, slot)
	for x in xs:
		_line(im, Vector2(x, 44), Vector2(x, 212), 3, line)
	_line(im, Vector2(48, 128), Vector2(208, 128), 3, line)
	# метки передач точками (вверху 1,3,5 — внизу 2,4,R)
	var counts := [[1, 2], [3, 4], [5, 0]]
	for ci in 3:
		var up: int = counts[ci][0]
		var down: int = counts[ci][1]
		for d in up:
			_disc(im, xs[ci] - (up - 1) * 7.0 + d * 14.0, 26, 4.5, line)
		if down > 0:
			for d in down:
				_disc(im, xs[ci] - (down - 1) * 7.0 + d * 14.0, 232, 4.5, line)
		else:
			_arc(im, Vector2(xs[ci], 232), 9, 0.0, TAU, 3, Color(0.95, 0.35, 0.3, 1))
	var tex := ImageTexture.create_from_image(im)
	_cache["plate"] = tex
	return tex
