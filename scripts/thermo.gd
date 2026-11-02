class_name Thermometer
extends Node3D
## Уличный столбиковый термометр: уровень «ртути» показывает температуру, цифр нет.
## Шкала от -20 до +40 °C, риски через 5 градусов, нулевая — длиннее.

const T_MIN := -20.0
const T_MAX := 40.0
const H := 0.5   # длина трубки, м

var fill: MeshInstance3D


func _init() -> void:
	add_to_group("thermo")
	add_child(MU.box(Vector3(0.1, H + 0.14, 0.015), Color(0.85, 0.8, 0.65), Vector3(0, 0, 0)))
	add_child(MU.box(Vector3(0.1, 0.015, 0.02), Color(0.35, 0.25, 0.15), Vector3(0, (H + 0.14) * 0.5, 0.0)))
	add_child(MU.box(Vector3(0.1, 0.015, 0.02), Color(0.35, 0.25, 0.15), Vector3(0, -(H + 0.14) * 0.5, 0.0)))
	for i in 13:
		var tt := T_MIN + i * 5.0
		var y := -H * 0.5 + H * (tt - T_MIN) / (T_MAX - T_MIN)
		var long := absf(tt) < 0.1
		var col := Color(0.8, 0.1, 0.1) if long else Color(0.15, 0.15, 0.15)
		add_child(MU.box(Vector3(0.05 if long else 0.03, 0.004, 0.003), col, Vector3(0.045 if not long else 0.03, y, 0.011)))
	add_child(MU.cyl(0.012, 0.012, H, Color(0.9, 0.95, 1.0, 0.45), Vector3(0, 0, 0.018), Vector3.ZERO, 8))
	add_child(MU.sphere(0.024, Color(0.85, 0.1, 0.1), Vector3(0, -H * 0.5 - 0.02, 0.018)))
	fill = MU.box(Vector3(0.011, 1.0, 0.011), MU.mat(Color(0.9, 0.1, 0.1), 0.3, 0.6), Vector3(0, 0, 0.018))
	add_child(fill)
	set_temp(10.0)


func set_temp(t: float) -> void:
	var k := clampf((t - T_MIN) / (T_MAX - T_MIN), 0.0, 1.0)
	var h := maxf(H * k, 0.004)
	fill.scale = Vector3(1, h, 1)
	fill.position.y = -H * 0.5 + h * 0.5
