extends Control
## Главное меню: живая сцена у костра (дом на колёсах, ёлки, огонь, светлячки)
## и кнопки «Играть (хост)», «Подключиться», «Настройки», «Выход».

var nick_edit: LineEdit
var ip_edit: LineEdit
var port_edit: SpinBox
var status: Label
var cam: Camera3D
var fire_light: OmniLight3D
var join_panel: Control
var main_box: Control
var look_panel: Control
var preview: Node3D
var preview_cm: CharModel
var editing := false
var edit_turn := 0.0
var look: Look
const PREVIEW_POS := Vector3(3.6, 0.0, 0.2)
const FIRE_POS := Vector3(5.5, 0.0, 3.0)
const EDIT_DIR := Vector3(0.35, 0.0, -0.94)
var t := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rng.seed = 77
	_build_scene()
	_build_ui()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)


# ======================================================================= 3D-сцена
func _build_scene() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.1, 0.14, 0.28)
	sky_mat.sky_horizon_color = Color(0.95, 0.55, 0.3)
	sky_mat.ground_horizon_color = Color(0.5, 0.3, 0.22)
	sky_mat.ground_bottom_color = Color(0.08, 0.08, 0.1)
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.55, 0.4)
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14, -70, 0)
	sun.light_color = Color(1.0, 0.65, 0.4)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	# земля
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	ground.mesh = pm
	ground.material_override = MU.mat(Color(0.2, 0.26, 0.12), 1.0)
	add_child(ground)
	# просёлок
	var road := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(5.0, 120.0)
	road.mesh = rm
	road.position = Vector3(-4, 0.02, 0)
	road.material_override = MU.mat(Color(0.32, 0.26, 0.18), 1.0)
	add_child(road)
	# дом на колёсах (та же модель, что в игре, без физики)
	var rv := RV.new()
	rv.name = "RVModel"
	rv._build()
	rv.freeze = true
	rv.position = Vector3(0, 0.0, 0)
	rv.rotation.y = deg_to_rad(-28)
	add_child(rv)
	rv.set_physics_process(false)
	rv.set_process(false)
	if rv.engine_snd:
		rv.engine_snd.stop()
	if rv.winch_snd:
		rv.winch_snd.stop()
	rv.lights_on = true
	for l in rv.lights:
		(l as SpotLight3D).visible = true
	# костёр
	var fire := Node3D.new()
	fire.position = Vector3(5.5, 0, 3.0)
	add_child(fire)
	for i in 6:
		var a := TAU * i / 6.0
		fire.add_child(MU.cyl(0.07, 0.07, 0.8, Color(0.3, 0.2, 0.12), Vector3(cos(a) * 0.3, 0.12, sin(a) * 0.3), Vector3(70, rad_to_deg(-a), 0), 7))
	for i in 8:
		var a2 := TAU * i / 8.0
		fire.add_child(MU.sphere(0.14 + rng.randf() * 0.05, Color(0.35, 0.35, 0.37), Vector3(cos(a2) * 0.75, 0.08, sin(a2) * 0.75), Vector3(1, 0.7, 1)))
	var flame := CPUParticles3D.new()
	flame.amount = 40
	flame.lifetime = 0.9
	flame.position = Vector3(0, 0.3, 0)
	flame.gravity = Vector3(0, 2.5, 0)
	flame.direction = Vector3.UP
	flame.spread = 14.0
	flame.initial_velocity_min = 0.3
	flame.initial_velocity_max = 0.9
	flame.scale_amount_min = 0.6
	flame.scale_amount_max = 1.6
	var fm := SphereMesh.new()
	fm.radius = 0.12
	fm.height = 0.3
	fm.radial_segments = 6
	fm.rings = 3
	fm.material = MU.mat(Color(1.0, 0.55, 0.1), 1.0, 4.0)
	flame.mesh = fm
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.9, 0.4, 1))
	grad.set_color(1, Color(0.9, 0.1, 0.0, 0))
	flame.color_ramp = grad
	fire.add_child(flame)
	var sparks := CPUParticles3D.new()
	sparks.amount = 14
	sparks.lifetime = 2.2
	sparks.position = Vector3(0, 0.5, 0)
	sparks.gravity = Vector3(0, 1.0, 0)
	sparks.direction = Vector3.UP
	sparks.spread = 30.0
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 1.8
	var sm := SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	sm.radial_segments = 4
	sm.rings = 2
	sm.material = MU.mat(Color(1, 0.7, 0.2), 1.0, 5.0)
	sparks.mesh = sm
	fire.add_child(sparks)
	fire_light = OmniLight3D.new()
	fire_light.position = Vector3(0, 0.9, 0)
	fire_light.light_color = Color(1.0, 0.6, 0.25)
	fire_light.omni_range = 14.0
	fire_light.light_energy = 2.5
	fire_light.shadow_enabled = true
	fire.add_child(fire_light)
	# брёвна-скамейки
	for p in [Vector3(5.5, 0.2, 5.0), Vector3(7.8, 0.2, 3.0)]:
		add_child(MU.cyl(0.22, 0.22, 2.2, Color(0.35, 0.24, 0.14), p, Vector3(0, 0, 90) if p.z > 4.0 else Vector3(90, 0, 0), 8))
	# ёлки
	for i in 90:
		var ang := rng.randf() * TAU
		var d := rng.randf_range(14.0, 90.0)
		var pos := Vector3(cos(ang) * d, 0, sin(ang) * d)
		if absf(pos.x + 4.0) < 5.0:
			continue
		var h := rng.randf_range(5.0, 11.0)
		var tree := Node3D.new()
		tree.position = pos
		tree.add_child(MU.cyl(0.18, 0.28, h * 0.4, Color(0.25, 0.17, 0.1), Vector3(0, h * 0.2, 0), Vector3.ZERO, 6))
		for k in 4:
			var kk := float(k)
			var rr := (1.0 - kk * 0.2) * h * 0.22
			tree.add_child(MU.cyl(0.0, rr, h * 0.38, Color(0.07, 0.2 + rng.randf() * 0.06, 0.1), Vector3(0, h * (0.3 + kk * 0.17), 0), Vector3.ZERO, 8))
		add_child(tree)
	# валуны
	for i in 14:
		var rp := Vector3(rng.randf_range(-30, 30), 0.2, rng.randf_range(-30, 30))
		if rp.length() < 10.0:
			continue
		add_child(MU.sphere(rng.randf_range(0.5, 1.4), Color(0.4, 0.4, 0.42), rp, Vector3(1, 0.7, 1.1)))
	# светлячки
	var ff := CPUParticles3D.new()
	ff.amount = 50
	ff.lifetime = 6.0
	ff.position = Vector3(3, 1.5, 3)
	ff.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ff.emission_box_extents = Vector3(14, 1.2, 14)
	ff.gravity = Vector3.ZERO
	ff.initial_velocity_min = 0.1
	ff.initial_velocity_max = 0.4
	ff.direction = Vector3.UP
	ff.spread = 180.0
	var fm2 := SphereMesh.new()
	fm2.radius = 0.025
	fm2.height = 0.05
	fm2.radial_segments = 4
	fm2.rings = 2
	fm2.material = MU.mat(Color(0.8, 1.0, 0.4), 1.0, 6.0)
	ff.mesh = fm2
	add_child(ff)
	cam = Camera3D.new()
	cam.fov = 55
	cam.h_offset = -5.5
	cam.far = 400
	add_child(cam)
	cam.current = true
	look = Net.look
	_build_preview()
	_orbit(0.0)


func _build_preview() -> void:
	if preview:
		preview.queue_free()
	preview = Node3D.new()
	preview.position = PREVIEW_POS
	add_child(preview)
	preview_cm = CharModel.new()
	preview.add_child(preview_cm)
	preview_cm.build(look)
	preview.rotation.y = _face_yaw(FIRE_POS - PREVIEW_POS)


func _face_yaw(v: Vector3) -> float:
	return atan2(-v.x, -v.z)


func _orbit(tm: float) -> void:
	if editing:
		var a0 := atan2(EDIT_DIR.z, EDIT_DIR.x) + edit_turn
		var target_pos := PREVIEW_POS + Vector3(cos(a0), 0, sin(a0)) * 5.2 + Vector3(0, 1.4, 0)
		if preview:
			preview.rotation.y = lerp_angle(preview.rotation.y, _face_yaw(EDIT_DIR), 0.08)
		cam.position = cam.position.lerp(target_pos, 0.1)
		cam.fov = lerpf(cam.fov, 38.0, 0.1)
		cam.h_offset = lerpf(cam.h_offset, -0.7, 0.1)
		cam.look_at(PREVIEW_POS + Vector3(0, 1.15, 0), Vector3.UP)
		return
	cam.fov = lerpf(cam.fov, 55.0, 0.1)
	cam.h_offset = lerpf(cam.h_offset, -5.5, 0.1)
	if preview:
		preview.rotation.y = lerp_angle(preview.rotation.y, _face_yaw(FIRE_POS - PREVIEW_POS), 0.08)
	var a := deg_to_rad(205.0) + sin(tm * 0.08) * 0.35
	var r := 15.5 + sin(tm * 0.11) * 1.5
	cam.position = Vector3(2.5 + cos(a) * r, 2.6 + sin(tm * 0.13) * 0.4, 1.5 + sin(a) * r)
	cam.look_at(Vector3(2.8, 1.8, 1.4), Vector3.UP)


func _process(delta: float) -> void:
	t += delta
	_orbit(t)
	if preview_cm:
		preview_cm.play("Idle")
		preview_cm.advance(delta)
	if fire_light:
		fire_light.light_energy = 2.5 + sin(t * 17.0) * 0.4 + sin(t * 9.3) * 0.3 + randf() * 0.3


# ======================================================================= Интерфейс
func _style(bg: Color, border: Color, bw := 2) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(bw)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(12)
	return st


func _big_button(text: String, cb: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.45))
	var base := Color(0.95, 0.55, 0.12, 0.92) if accent else Color(0.05, 0.06, 0.05, 0.62)
	b.add_theme_stylebox_override("normal", _style(base, Color(1.0, 0.75, 0.3, 0.8) if accent else Color(0.8, 0.7, 0.45, 0.35)))
	b.add_theme_stylebox_override("hover", _style(base.lightened(0.18), Color(1.0, 0.85, 0.4)))
	b.add_theme_stylebox_override("pressed", _style(base.darkened(0.2), Color(1.0, 0.85, 0.4)))
	b.add_theme_stylebox_override("focus", _style(base, Color(1.0, 0.85, 0.4)))
	b.pressed.connect(func():
		Sfx.play_ui("click", -6)
		cb.call())
	b.mouse_entered.connect(func(): Sfx.play_ui("click", -20))
	return b


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.9))
	g.set_color(1, Color(0, 0, 0, 0.0))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(0.5, 0.5)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	shade.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 70)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(380, 0)
	vb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(vb)
	main_box = vb
	var title := Label.new()
	title.text = T.t("game_title")
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.07, 0.0))
	title.add_theme_constant_override("outline_size", 12)
	vb.add_child(title)
	var sub := Label.new()
	sub.text = T.t("game_subtitle")
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	sub.add_theme_color_override("font_outline_color", Color.BLACK)
	sub.add_theme_constant_override("outline_size", 6)
	vb.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	vb.add_child(sp)
	var nl := Label.new()
	nl.text = T.t("menu_nick")
	nl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75))
	vb.add_child(nl)
	nick_edit = LineEdit.new()
	nick_edit.text = Net.nick
	nick_edit.max_length = 16
	nick_edit.custom_minimum_size = Vector2(340, 44)
	nick_edit.add_theme_font_size_override("font_size", 20)
	nick_edit.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0.55), Color(0.8, 0.7, 0.45, 0.4)))
	nick_edit.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0.7), Color(1.0, 0.8, 0.4)))
	vb.add_child(nick_edit)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 8)
	vb.add_child(sp2)
	vb.add_child(_big_button(T.t("menu_play"), _on_host, true))
	vb.add_child(_big_button(T.t("menu_connect"), _open_join))
	vb.add_child(_big_button(T.t("menu_look"), _open_look))
	vb.add_child(_big_button(T.t("ui_settings"), _open_settings))
	vb.add_child(_big_button(T.t("menu_quit"), func(): get_tree().quit()))
	status = Label.new()
	status.text = Net.last_error
	status.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(340, 0)
	vb.add_child(status)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(fill)
	var hint := Label.new()
	hint.text = T.t("menu_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(380, 0)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.68))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 4)
	vb.add_child(hint)


func _modal(inner: Control) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cc)
	cc.add_child(inner)
	add_child(layer)
	return layer


func _open_settings() -> void:
	var holder: Array = [null]
	var panel := Settings.build_panel(func():
		if holder[0]:
			holder[0].queue_free())
	holder[0] = _modal(panel)


func _open_join() -> void:
	if join_panel:
		return
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.06, 0.96), Color(0.85, 0.65, 0.3), 2))
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(420, 0)
	vb.add_theme_constant_override("separation", 10)
	pc.add_child(vb)
	var tl := Label.new()
	tl.text = T.t("menu_connect_title")
	tl.add_theme_font_size_override("font_size", 28)
	tl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	vb.add_child(tl)
	var il := Label.new()
	il.text = T.t("menu_ip")
	vb.add_child(il)
	var hb := HBoxContainer.new()
	ip_edit = LineEdit.new()
	ip_edit.text = Net.ip
	ip_edit.placeholder_text = "192.168.0.10"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.custom_minimum_size = Vector2(0, 42)
	hb.add_child(ip_edit)
	port_edit = SpinBox.new()
	port_edit.min_value = 1024
	port_edit.max_value = 65535
	port_edit.value = Net.port
	hb.add_child(port_edit)
	vb.add_child(hb)
	var go := _big_button(T.t("menu_join"), _on_join, true)
	go.custom_minimum_size.x = 0
	vb.add_child(go)
	var back := _big_button(T.t("menu_back"), func():
		join_panel.queue_free()
		join_panel = null)
	back.custom_minimum_size.x = 0
	vb.add_child(back)
	join_panel = _modal(pc)
	ip_edit.grab_focus()


func _apply() -> void:
	var n := nick_edit.text.strip_edges()
	Net.nick = n if n != "" else "Охотник"
	if ip_edit:
		Net.ip = ip_edit.text.strip_edges()
		Net.port = int(port_edit.value)
	Net.last_error = ""
	Net.save_settings()


func _on_host() -> void:
	_apply()
	Net.is_host = true
	status.text = T.t("menu_loading")
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")


func _on_join() -> void:
	_apply()
	Net.is_host = false
	status.text = T.t("menu_loading")
	if join_panel:
		join_panel.queue_free()
		join_panel = null
		ip_edit = null
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")


# ======================================================================= Редактор персонажа
func _open_look() -> void:
	editing = true
	edit_turn = 0.0
	main_box.visible = false
	if look_panel:
		look_panel.queue_free()
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	pc.offset_left = 50
	pc.offset_top = 40
	pc.offset_bottom = -40
	pc.offset_right = 470
	pc.add_theme_stylebox_override("panel", _style(Color(0.05, 0.06, 0.05, 0.82), Color(0.85, 0.65, 0.3, 0.7)))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(380, 0)
	vb.add_theme_constant_override("separation", 10)
	scroll.add_child(vb)
	var tl := Label.new()
	tl.text = T.t("look_title")
	tl.add_theme_font_size_override("font_size", 30)
	tl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	vb.add_child(tl)
	vb.add_child(_opt_row("look_body", Look.BODY_KEYS, look.body, func(i): look.body = i; _look_changed()))
	vb.add_child(_swatch_row("look_skin", Look.SKIN_TONES, look.skin, func(c): look.skin = c; _look_changed()))
	vb.add_child(_swatch_row("look_hair", Look.HAIR_COLORS, look.hair, func(c): look.hair = c; _look_changed()))
	vb.add_child(_opt_row("look_beard", Look.BEARD_KEYS, look.beard, func(i): look.beard = i; _look_changed()))
	vb.add_child(_opt_row("look_hat", Look.HAT_KEYS, look.hat, func(i): look.hat = i; _look_changed()))
	vb.add_child(_color_row("look_hat_color", look.hat_color, func(c): look.hat_color = c; _look_changed()))
	vb.add_child(_color_row("look_shirt", look.shirt, func(c): look.shirt = c; _look_changed()))
	vb.add_child(_color_row("look_pants", look.pants, func(c): look.pants = c; _look_changed()))
	var tl2 := Label.new()
	tl2.text = T.t("look_turn")
	vb.add_child(tl2)
	var sl := HSlider.new()
	sl.min_value = -3.14
	sl.max_value = 3.14
	sl.step = 0.01
	sl.value = 0.0
	sl.custom_minimum_size = Vector2(0, 28)
	sl.value_changed.connect(func(v): edit_turn = v)
	vb.add_child(sl)
	var rnd := _big_button(T.t("look_random"), func():
		var r := Look.random_look()
		r.hat = look.hat
		r.hat_color = look.hat_color
		look = r
		Net.look = look
		_open_look())
	rnd.custom_minimum_size.x = 0
	vb.add_child(rnd)
	var done := _big_button(T.t("look_done"), _close_look, true)
	done.custom_minimum_size.x = 0
	vb.add_child(done)
	add_child(pc)
	look_panel = pc


func _close_look() -> void:
	look.save()
	Net.look = look
	editing = false
	main_box.visible = true
	if look_panel:
		look_panel.queue_free()
		look_panel = null


func _look_changed() -> void:
	Net.look = look
	var yaw := preview.rotation.y
	_build_preview()
	preview.rotation.y = yaw


func _row_label(key: String) -> Label:
	var l := Label.new()
	l.text = T.t(key)
	l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75))
	return l


func _opt_row(key: String, keys: Array, cur: int, cb: Callable) -> Control:
	var vb := VBoxContainer.new()
	vb.add_child(_row_label(key))
	var ob := OptionButton.new()
	for k in keys:
		ob.add_item(T.t(k))
	ob.select(cur)
	ob.custom_minimum_size = Vector2(0, 38)
	ob.item_selected.connect(cb)
	vb.add_child(ob)
	return vb


func _swatch_row(key: String, colors: Array, cur: String, cb: Callable) -> Control:
	var vb := VBoxContainer.new()
	vb.add_child(_row_label(key))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	for c in colors:
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 38)
		var st := _style(Color.html(c), Color(1, 0.9, 0.5) if c == cur else Color(0, 0, 0, 0.6), 3)
		for n in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(n, st)
		var cc: String = c
		b.pressed.connect(func():
			Sfx.play_ui("click", -8)
			cb.call(cc)
			_open_look())
		hb.add_child(b)
	vb.add_child(hb)
	return vb


func _color_row(key: String, cur: String, cb: Callable) -> Control:
	var hb := HBoxContainer.new()
	var l := _row_label(key)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var cp := ColorPickerButton.new()
	cp.color = Color.html(cur)
	cp.edit_alpha = false
	cp.custom_minimum_size = Vector2(110, 36)
	cp.color_changed.connect(func(c: Color): cb.call(c.to_html(false)))
	hb.add_child(cp)
	return hb
