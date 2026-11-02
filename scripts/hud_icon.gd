class_name HudIcon
extends Control
## Иконка-индикатор потребности: рисуется кодом, без текста. Цвет — от зелёного к красному.
## severity: 0 — всё хорошо, 1 — критично.

var kind := "hp"
var severity := 0.0
var _t := 0.0


func _init(k := "hp") -> void:
	kind = k
	custom_minimum_size = Vector2(46, 46)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_severity(v: float) -> void:
	var nv := clampf(v, 0.0, 1.0)
	if absf(nv - severity) > 0.004:
		severity = nv
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if severity > 0.78:
		queue_redraw()


static func level_color(sev: float) -> Color:
	var g := Color(0.35, 0.85, 0.35)
	var y := Color(0.95, 0.85, 0.2)
	var r := Color(0.95, 0.2, 0.15)
	return g.lerp(y, clampf(sev * 2.0, 0.0, 1.0)) if sev < 0.5 else y.lerp(r, clampf((sev - 0.5) * 2.0, 0.0, 1.0))


func _draw() -> void:
	var c := level_color(severity)
	var pulse := 1.0
	if severity > 0.78:
		pulse = 0.65 + 0.35 * sin(_t * 8.0)
	var s := minf(size.x, size.y)
	var o := Vector2(size.x - s, size.y - s) * 0.5
	draw_circle(o + Vector2(s, s) * 0.5, s * 0.5, Color(0, 0, 0, 0.5))
	draw_arc(o + Vector2(s, s) * 0.5, s * 0.48, 0, TAU, 28, Color(c.r, c.g, c.b, 0.9 * pulse), 2.5, true)
	c.a = pulse
	var u := s / 46.0
	var p := o + Vector2(23, 23) * u
	match kind:
		"hp":   # сердце
			draw_circle(p + Vector2(-5, -4) * u, 6.2 * u, c)
			draw_circle(p + Vector2(5, -4) * u, 6.2 * u, c)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-11, -1) * u, p + Vector2(11, -1) * u, p + Vector2(0, 12) * u]), c)
		"hunger":   # вилка и нож
			for i in 3:
				draw_line(p + Vector2(-8 + i * 3.5, -10) * u, p + Vector2(-8 + i * 3.5, -2) * u, c, 1.6 * u)
			draw_line(p + Vector2(-8, -2) * u, p + Vector2(-4.5, -2) * u, c, 1.6 * u)
			draw_line(p + Vector2(-6.2, -2) * u, p + Vector2(-6.2, 11) * u, c, 2.4 * u)
			draw_colored_polygon(PackedVector2Array([p + Vector2(5, -11) * u, p + Vector2(9, -7) * u, p + Vector2(9, 3) * u, p + Vector2(5, 3) * u]), c)
			draw_line(p + Vector2(7, 3) * u, p + Vector2(7, 11) * u, c, 2.4 * u)
		"thirst":   # капля
			draw_circle(p + Vector2(0, 4) * u, 7.5 * u, c)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-6.6, 1) * u, p + Vector2(6.6, 1) * u, p + Vector2(0, -12) * u]), c)
		"bladder":   # мочевой пузырь с каплей
			draw_set_transform(p + Vector2(0, 2) * u, 0.0, Vector2(1.0, 1.25))
			draw_circle(Vector2.ZERO, 8.5 * u, c)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_circle(p + Vector2(0, 3) * u, 2.6 * u, Color(0, 0, 0, 0.55))
		"bowels":   # «кучка»: три ступени
			draw_set_transform(p + Vector2(0, 8) * u, 0.0, Vector2(1.0, 0.55))
			draw_circle(Vector2.ZERO, 10.5 * u, c)
			draw_set_transform(p + Vector2(0, 2) * u, 0.0, Vector2(1.0, 0.55))
			draw_circle(Vector2.ZERO, 7.5 * u, c)
			draw_set_transform(p + Vector2(0, -4) * u, 0.0, Vector2(1.0, 0.6))
			draw_circle(Vector2.ZERO, 4.5 * u, c)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-2, -7) * u, p + Vector2(2, -7) * u, p + Vector2(4, -13) * u]), c)
		"warmth":   # термометр
			draw_rect(Rect2(p + Vector2(-2.5, -12) * u, Vector2(5, 17) * u), c)
			draw_circle(p + Vector2(0, 8) * u, 6 * u, c)
			draw_rect(Rect2(p + Vector2(-0.9, -6) * u, Vector2(1.8, 13) * u), Color(0, 0, 0, 0.55))
		"wetness":   # капля с волнами
			draw_circle(p + Vector2(0, -1) * u, 6 * u, c)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5.2, -3) * u, p + Vector2(5.2, -3) * u, p + Vector2(0, -13) * u]), c)
			for i in 2:
				var y := 8.0 + i * 4.0
				var pts := PackedVector2Array()
				for k in 9:
					pts.append(p + Vector2(-10 + k * 2.5, y + sin(k * 1.4) * 1.3) * u)
				draw_polyline(pts, c, 1.8 * u, true)
		"drunk":   # бутылка
			draw_rect(Rect2(p + Vector2(-5, -2) * u, Vector2(10, 14) * u), c)
			draw_rect(Rect2(p + Vector2(-2.5, -12) * u, Vector2(5, 11) * u), c)
		"bleed":   # красная капля
			c = Color(0.9, 0.1, 0.1, pulse)
			draw_circle(p + Vector2(0, 4) * u, 7.5 * u, c)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-6.6, 1) * u, p + Vector2(6.6, 1) * u, p + Vector2(0, -12) * u]), c)
		"poison":   # череп-ромб
			draw_circle(p + Vector2(0, -2) * u, 8 * u, c)
			draw_rect(Rect2(p + Vector2(-5, 4) * u, Vector2(10, 6) * u), c)
			draw_circle(p + Vector2(-3.2, -2) * u, 2.2 * u, Color(0, 0, 0, 0.7))
			draw_circle(p + Vector2(3.2, -2) * u, 2.2 * u, Color(0, 0, 0, 0.7))
