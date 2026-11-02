extends Control
## Главное меню: ник, создать игру (хост) или подключиться по IP.

var nick_edit: LineEdit
var ip_edit: LineEdit
var port_edit: SpinBox
var status: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.1, 0.07)
	add_child(bg)
	var grad := TextureRect.new()
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.25, 0.32, 0.2, 1.0))
	g.set_color(1, Color(0.04, 0.05, 0.04, 1.0))
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(grad)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(460, 0)
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)
	var title := Label.new()
	title.text = T.t("game_title")
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := Label.new()
	sub.text = T.t("game_subtitle")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.8, 0.85, 0.75))
	vb.add_child(sub)
	vb.add_child(HSeparator.new())
	vb.add_child(_cap(T.t("menu_nick")))
	nick_edit = LineEdit.new()
	nick_edit.text = Net.nick
	nick_edit.max_length = 16
	vb.add_child(nick_edit)
	var host := Button.new()
	host.text = T.t("menu_host")
	host.custom_minimum_size.y = 46
	host.pressed.connect(_on_host)
	vb.add_child(host)
	vb.add_child(HSeparator.new())
	vb.add_child(_cap(T.t("menu_ip")))
	var hb := HBoxContainer.new()
	ip_edit = LineEdit.new()
	ip_edit.text = Net.ip
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(ip_edit)
	port_edit = SpinBox.new()
	port_edit.min_value = 1024
	port_edit.max_value = 65535
	port_edit.value = Net.port
	hb.add_child(port_edit)
	vb.add_child(hb)
	var join := Button.new()
	join.text = T.t("menu_join")
	join.custom_minimum_size.y = 46
	join.pressed.connect(_on_join)
	vb.add_child(join)
	vb.add_child(HSeparator.new())
	var sett := Button.new()
	sett.text = T.t("ui_settings")
	sett.pressed.connect(func():
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		var bg2 := ColorRect.new()
		bg2.color = Color(0, 0, 0, 0.6)
		bg2.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg2)
		cc.add_child(Settings.build_panel(func():
			cc.queue_free()
			bg2.queue_free()))
		add_child(cc))
	vb.add_child(sett)
	var quit := Button.new()
	quit.text = T.t("menu_quit")
	quit.pressed.connect(func(): get_tree().quit())
	vb.add_child(quit)
	status = Label.new()
	status.text = Net.last_error
	status.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(status)
	var hint := Label.new()
	hint.text = T.t("menu_hint")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.65))
	vb.add_child(hint)


func _cap(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _apply() -> void:
	Net.nick = nick_edit.text.strip_edges() if nick_edit.text.strip_edges() != "" else "Охотник"
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
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
