extends Node
## Настройки игрока: управление, мышь, графика, звук. Сохраняются в user://settings.cfg.

const FILE := "user://options.cfg"
const REBINDABLE := ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump", "interact",
	"inventory", "emote_menu", "flop", "drop", "toilet", "watch", "flashlight", "reload", "ammo_type", "attachments", "smoke", "horn",
	"slot_1", "slot_2", "slot_3", "slot_4"]

var mouse_sens := 1.0
var invert_y := false
var fov := 72.0
var fullscreen := false
var vsync := true
var render_scale := 1.0
var shadows := 2          # 0 выкл, 1 низкие, 2 высокие
var ssao := true
var grass := true
var mirrors := true
var view_dist := 1.0      # множитель дальности/тумана
var vol_master := 0.8
var vol_sfx := 1.0
var vol_ambient := 0.8
var custom_keys := {}     # action -> physical keycode

signal changed


func _ready() -> void:
	for b in ["SFX", "Ambient"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	load_settings()
	apply()


func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(FILE) != OK:
		return
	for k in ["mouse_sens", "invert_y", "fov", "fullscreen", "vsync", "render_scale", "shadows", "ssao", "grass",
			"mirrors", "view_dist", "vol_master", "vol_sfx", "vol_ambient", "custom_keys"]:
		set(k, c.get_value("o", k, get(k)))


func save_settings() -> void:
	var c := ConfigFile.new()
	for k in ["mouse_sens", "invert_y", "fov", "fullscreen", "vsync", "render_scale", "shadows", "ssao", "grass",
			"mirrors", "view_dist", "vol_master", "vol_sfx", "vol_ambient", "custom_keys"]:
		c.set_value("o", k, get(k))
	c.save(FILE)


func apply() -> void:
	# клавиши
	for a in custom_keys:
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
			var ev := InputEventKey.new()
			ev.physical_keycode = int(custom_keys[a])
			InputMap.action_add_event(a, ev)
	# окно
	if not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	get_viewport().scaling_3d_scale = render_scale
	RenderingServer.directional_shadow_atlas_set_size(4096 if shadows >= 2 else 2048, true)
	# звук
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol_master, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(vol_sfx, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambient"), linear_to_db(maxf(vol_ambient, 0.0001)))
	changed.emit()


func rebind(action: String, keycode: int) -> void:
	custom_keys[action] = keycode
	apply()
	save_settings()


func reset_keys() -> void:
	custom_keys.clear()
	for a in REBINDABLE:
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
	Net.setup_input()
	save_settings()


func key_name(action: String) -> String:
	if not InputMap.has_action(action):
		return "-"
	var names: Array = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			names.append(OS.get_keycode_string(ev.physical_keycode))
		elif ev is InputEventMouseButton:
			names.append("Mouse %d" % ev.button_index)
	return ", ".join(PackedStringArray(names))


## Панель настроек (используется в главном меню и в паузе).
func build_panel(on_close: Callable) -> Control:
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.09, 0.07, 0.96)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(14)
	st.border_color = Color(0.6, 0.5, 0.3)
	st.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(640, 560)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(tabs)
	tabs.add_child(_controls_tab())
	tabs.add_child(_graphics_tab())
	tabs.add_child(_audio_tab())
	var close := Button.new()
	close.text = T.t("ui_close")
	close.pressed.connect(func():
		save_settings()
		on_close.call())
	vb.add_child(close)
	return panel


func _row(parent: Control, label: String, ctrl: Control) -> void:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(260, 0)
	hb.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(ctrl)
	parent.add_child(hb)


func _slider(minv: float, maxv: float, step: float, val: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(220, 24)
	s.value_changed.connect(func(v):
		cb.call(v)
		apply())
	return s


func _check(val: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.button_pressed = val
	c.toggled.connect(func(v):
		cb.call(v)
		apply())
	return c


func _scroll(title: String) -> Array:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	return [sc, vb]


func _controls_tab() -> Control:
	var r := _scroll(T.t("set_controls"))
	var vb: VBoxContainer = r[1]
	_row(vb, T.t("set_mouse_sens"), _slider(0.2, 3.0, 0.05, mouse_sens, func(v): mouse_sens = v))
	_row(vb, T.t("set_invert_y"), _check(invert_y, func(v): invert_y = v))
	_row(vb, T.t("set_fov"), _slider(55, 100, 1, fov, func(v): fov = v))
	vb.add_child(HSeparator.new())
	for a in REBINDABLE:
		var b := Button.new()
		b.text = key_name(a)
		var act: String = a
		b.pressed.connect(func():
			b.text = T.t("set_press_key")
			_capture(act, b))
		_row(vb, T.t("act_" + a), b)
	var reset := Button.new()
	reset.text = T.t("set_reset_keys")
	reset.pressed.connect(func():
		reset_keys()
		for c in vb.get_children():
			if c is HBoxContainer and c.get_child(1) is Button:
				pass)
	vb.add_child(reset)
	return r[0]


var _capture_action := ""
var _capture_btn: Button


func _capture(action: String, b: Button) -> void:
	_capture_action = action
	_capture_btn = b


func _input(event: InputEvent) -> void:
	if _capture_action == "" or not event is InputEventKey or not event.pressed:
		return
	var kc: int = event.physical_keycode
	if kc != KEY_ESCAPE:
		rebind(_capture_action, kc)
	if is_instance_valid(_capture_btn):
		_capture_btn.text = key_name(_capture_action)
	_capture_action = ""
	get_viewport().set_input_as_handled()


func _graphics_tab() -> Control:
	var r := _scroll(T.t("set_graphics"))
	var vb: VBoxContainer = r[1]
	_row(vb, T.t("set_fullscreen"), _check(fullscreen, func(v): fullscreen = v))
	_row(vb, T.t("set_vsync"), _check(vsync, func(v): vsync = v))
	_row(vb, T.t("set_render_scale"), _slider(0.5, 1.0, 0.05, render_scale, func(v): render_scale = v))
	var sh := OptionButton.new()
	for k in ["set_off", "set_low", "set_high"]:
		sh.add_item(T.t(k))
	sh.selected = shadows
	sh.item_selected.connect(func(i):
		shadows = i
		apply())
	_row(vb, T.t("set_shadows"), sh)
	_row(vb, T.t("set_ssao"), _check(ssao, func(v): ssao = v))
	_row(vb, T.t("set_grass"), _check(grass, func(v): grass = v))
	_row(vb, T.t("set_mirrors"), _check(mirrors, func(v): mirrors = v))
	_row(vb, T.t("set_view_dist"), _slider(0.5, 1.5, 0.05, view_dist, func(v): view_dist = v))
	return r[0]


func _audio_tab() -> Control:
	var r := _scroll(T.t("set_audio"))
	var vb: VBoxContainer = r[1]
	_row(vb, T.t("set_vol_master"), _slider(0, 1, 0.01, vol_master, func(v): vol_master = v))
	_row(vb, T.t("set_vol_sfx"), _slider(0, 1, 0.01, vol_sfx, func(v): vol_sfx = v))
	_row(vb, T.t("set_vol_ambient"), _slider(0, 1, 0.01, vol_ambient, func(v): vol_ambient = v))
	return r[0]
