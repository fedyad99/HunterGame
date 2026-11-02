class_name Hud
extends CanvasLayer
## Интерфейс: шкалы потребностей, подсказки, сообщения, меню.

var world: Node
var need_icons := {}
var need_box: HBoxContainer
var cross_ctl: Control
var ammo_ctl: Control
var _cross_target := false
var _cross_aim := false
var _hit_col := Color.WHITE
var _ammo_mag := 0
var _ammo_res := 0
var _ammo_reload := false
var _ammo_big := 0
var _dead_frac := 0.0
var dead_ctl: Control
var icons: ItemIcons
var _inv_sel := -1
var menu_panel: PanelContainer
var menu_box: VBoxContainer
var menu_title: Label
var dead_rect: ColorRect
var drunk_rect: ColorRect
var _hit_t := 0.0
var _menu_refresh: Callable
var menu_scroll: ScrollContainer
var scope_ctl: Control
var _scope_mode := ""
var _shop_cat := "food"
var _map_tex: ImageTexture


func _ready() -> void:
	layer = 5
	icons = ItemIcons.new()
	add_child(icons)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# опьянение — экранный шейдер
	drunk_rect = ColorRect.new()
	drunk_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	drunk_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/drunk.gdshader")
	drunk_rect.material = sm
	drunk_rect.visible = false
	root.add_child(drunk_rect)
	# индикаторы потребностей: только иконки, цвет меняется от зелёного к красному
	need_box = HBoxContainer.new()
	need_box.position = Vector2(16, 16)
	need_box.add_theme_constant_override("separation", 6)
	need_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(need_box)
	for k in ["hp", "hunger", "thirst", "bladder", "bowels", "warmth", "wetness", "bleed", "drunk", "poison"]:
		var ic := HudIcon.new(k)
		ic.visible = k in ["hp", "hunger", "thirst", "bladder", "bowels", "warmth", "wetness"]
		need_box.add_child(ic)
		need_icons[k] = ic
	# прицел и маркер попадания
	cross_ctl = Control.new()
	cross_ctl.set_anchors_preset(Control.PRESET_CENTER)
	cross_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross_ctl.draw.connect(_draw_cross)
	root.add_child(cross_ctl)
	# патроны: гильзы вместо цифр
	ammo_ctl = Control.new()
	ammo_ctl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_ctl.position = Vector2(-360, -80)
	ammo_ctl.size = Vector2(340, 60)
	ammo_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_ctl.draw.connect(_draw_ammo)
	root.add_child(ammo_ctl)
	# оптика: чёрное поле вокруг линзы и сетка; коллиматор — красная точка
	scope_ctl = Control.new()
	scope_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	scope_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_ctl.draw.connect(_draw_scope)
	scope_ctl.visible = false
	root.add_child(scope_ctl)
	# смерть
	dead_rect = ColorRect.new()
	dead_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dead_rect.color = Color(0.25, 0.0, 0.0, 0.45)
	dead_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dead_rect.visible = false
	root.add_child(dead_rect)
	dead_ctl = Control.new()
	dead_ctl.set_anchors_preset(Control.PRESET_CENTER)
	dead_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dead_ctl.draw.connect(func():
		dead_ctl.draw_arc(Vector2.ZERO, 46.0, -PI * 0.5, -PI * 0.5 + TAU * _dead_frac, 48, Color(1, 0.8, 0.8, 0.9), 6.0, true)
		dead_ctl.draw_circle(Vector2.ZERO, 40.0, Color(0, 0, 0, 0.35)))
	dead_rect.add_child(dead_ctl)
	# меню
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.custom_minimum_size = Vector2(560, 120)
	menu_panel.position = Vector2(-280, -300)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.1, 0.08, 0.93)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(16)
	st.border_color = Color(0.6, 0.5, 0.3)
	st.set_border_width_all(2)
	menu_panel.add_theme_stylebox_override("panel", st)
	menu_panel.visible = false
	root.add_child(menu_panel)
	var mvb := VBoxContainer.new()
	menu_panel.add_child(mvb)
	menu_title = _label(26, Color(1.0, 0.9, 0.6))
	mvb.add_child(menu_title)
	var scroll := ScrollContainer.new()
	menu_scroll = scroll
	scroll.custom_minimum_size = Vector2(520, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mvb.add_child(scroll)
	menu_box = VBoxContainer.new()
	menu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(menu_box)
	var close := Button.new()
	close.text = T.t("ui_close")
	close.pressed.connect(close_menu)
	mvb.add_child(close)


func _panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = size
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.35)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(size: int, c := Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Текстовых сообщений на экране больше нет (только значки и звук).
func add_msg(_text: String) -> void:
	pass


func show_hit(res: String) -> void:
	_hit_col = Color(1.0, 0.25, 0.2) if res in ["kill", "dead", "lethal"] else Color(1.0, 0.7, 0.2)
	_hit_t = 0.5
	Sfx.play_ui("hitmark", -6.0)


func _draw_cross() -> void:
	var c := cross_ctl
	var col := Color(1, 1, 1, 0.85)
	if _cross_aim:
		c.draw_line(Vector2(-14, 0), Vector2(-5, 0), Color(0, 0, 0, 0.6), 4.0)
		c.draw_line(Vector2(14, 0), Vector2(5, 0), Color(0, 0, 0, 0.6), 4.0)
		c.draw_line(Vector2(0, -14), Vector2(0, -5), Color(0, 0, 0, 0.6), 4.0)
		c.draw_line(Vector2(0, 14), Vector2(0, 5), Color(0, 0, 0, 0.6), 4.0)
		c.draw_line(Vector2(-13, 0), Vector2(-6, 0), col, 2.0)
		c.draw_line(Vector2(13, 0), Vector2(6, 0), col, 2.0)
		c.draw_line(Vector2(0, -13), Vector2(0, -6), col, 2.0)
		c.draw_line(Vector2(0, 13), Vector2(0, 6), col, 2.0)
	elif _cross_target:
		c.draw_arc(Vector2.ZERO, 11.0, 0, TAU, 24, Color(1.0, 0.9, 0.4, 0.95), 2.5, true)
		c.draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.9, 0.4, 0.95))
	else:
		c.draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.5))
		c.draw_circle(Vector2.ZERO, 2.5, col)
	if _hit_t > 0.0:
		var a := clampf(_hit_t * 2.0, 0.0, 1.0)
		var hc := Color(_hit_col.r, _hit_col.g, _hit_col.b, a)
		for d in [Vector2(1, 1), Vector2(-1, 1)]:
			c.draw_line(d * 8.0, d * 18.0, hc, 3.0)
			c.draw_line(-d * 8.0, -d * 18.0, hc, 3.0)


func _draw_ammo() -> void:
	var c := ammo_ctl
	var x := c.size.x
	# магазин — крупные гильзы справа налево
	for i in _ammo_mag:
		var r := Rect2(Vector2(x - 20 - i * 22, 12), Vector2(14, 36))
		c.draw_rect(r, Color(0.85, 0.65, 0.2) if not _ammo_reload else Color(0.5, 0.5, 0.5))
		c.draw_rect(Rect2(r.position, Vector2(14, 11)), Color(0.75, 0.2, 0.15) if _ammo_big == 0 else Color(0.5, 0.5, 0.55))
	# запас — маленькие гильзы ниже, не больше 16
	for i in mini(_ammo_res, 16):
		var r2 := Rect2(Vector2(x - 14 - i * 12, 52), Vector2(7, 14))
		c.draw_rect(r2, Color(0.8, 0.8, 0.8, 0.6))


func update_hud(p: Player) -> void:
	_hit_t = maxf(_hit_t - get_process_delta_time(), 0.0)
	need_box.visible = p != null
	if p == null:
		return
	need_icons.hp.set_severity(1.0 - p.hp / 100.0)
	need_icons.hunger.set_severity(1.0 - p.hunger / 100.0)
	need_icons.thirst.set_severity(1.0 - p.thirst / 100.0)
	need_icons.bladder.set_severity(p.bladder / 100.0)
	need_icons.bowels.set_severity(p.bowels / 100.0)
	need_icons.warmth.set_severity(1.0 - p.warmth / 100.0)
	need_icons.wetness.set_severity(p.wetness / 100.0)
	need_icons.bleed.visible = p.bleed > 0.05
	need_icons.bleed.set_severity(1.0)
	need_icons.drunk.visible = p.drunk > 8.0
	need_icons.drunk.set_severity(p.drunk / 100.0)
	need_icons.poison.visible = p.poison > 0.05
	need_icons.poison.set_severity(clampf(p.poison / 50.0, 0.3, 1.0))
	# прицел
	_scope_mode = ""
	if p.aiming and p.cur_weapon != "" and p.seated < 0 and not p.dead:
		_scope_mode = "scope" if p.scope_view else p.optic_mode()
	scope_ctl.visible = _scope_mode != ""
	if scope_ctl.visible:
		scope_ctl.queue_redraw()
	cross_ctl.visible = ((p.seated < 0 and not p.dead and not p.ragdoll) or (p.seated >= 0 and p.first_person)) and _scope_mode != "scope"
	_cross_aim = p.aiming and p.cur_weapon != ""
	_cross_target = p.target_kind != "" or world.get_held_item(p.peer_id) != null
	cross_ctl.queue_redraw()
	# патроны
	var w := p.cur_weapon
	ammo_ctl.visible = w != "" and p.seated < 0 and not p.dead
	if ammo_ctl.visible:
		var t: String = p.mag_type[w]
		_ammo_mag = int(p.mag[w])
		_ammo_res = int(p.ammo[t])
		_ammo_reload = p.reload_t > 0.0
		_ammo_big = 0 if t in ["12shot", "12slug", "22lr"] else 1
		ammo_ctl.queue_redraw()
	dead_rect.visible = p.dead
	if p.dead:
		_dead_frac = clampf(1.0 - p.dead_t / 12.0, 0.0, 1.0)
		dead_ctl.queue_redraw()
	drunk_rect.visible = p.drunk > 5.0
	if drunk_rect.visible:
		(drunk_rect.material as ShaderMaterial).set_shader_parameter("amount", p.drunk / 100.0)


# ======================================================================= МЕНЮ
func menu_open() -> bool:
	return menu_panel.visible or _settings_panel != null


func _open(title: String, refresh: Callable, size := Vector2(560, 460)) -> void:
	menu_title.text = title
	menu_scroll.custom_minimum_size = Vector2(size.x - 40, size.y)
	menu_panel.custom_minimum_size = Vector2(size.x, 120)
	menu_panel.offset_left = -size.x * 0.5
	menu_panel.offset_right = size.x * 0.5
	menu_panel.offset_top = -size.y * 0.5 - 70
	menu_panel.offset_bottom = menu_panel.offset_top + 120
	_menu_refresh = refresh
	_rebuild()
	menu_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_ui("click", -8)


func _rebuild() -> void:
	for c in menu_box.get_children():
		c.queue_free()
	_menu_refresh.call()


func close_menu() -> void:
	menu_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _btn(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		Sfx.play_ui("click", -8)
		cb.call())
	menu_box.add_child(b)
	return b


func _text(t: String, c := Color(0.85, 0.85, 0.8)) -> void:
	var l := _label(16, c)
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_box.add_child(l)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if _settings_panel != null:
			_settings_panel.queue_free()
			_settings_panel = null
			Settings.save_settings()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif menu_open():
			close_menu()
		else:
			open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("help"):
		open_help()
	elif menu_open() and (event.is_action_pressed("inventory") or event.is_action_pressed("emote_menu") or event.is_action_pressed("toilet")):
		close_menu()
		get_viewport().set_input_as_handled()


func open_pause() -> void:
	_open(T.t("ui_pause"), func():
		_btn(T.t("ui_resume"), close_menu)
		_btn(T.t("ui_help"), open_help)
		_btn(T.t("ui_settings"), open_settings)
		_btn(T.t("ui_quit_menu"), func(): Net.leave(""))
		_text(T.t("ui_players", [", ".join(PackedStringArray(world.players.values().map(func(x): return x.nick)))])))


var _settings_panel: Control


func open_settings() -> void:
	close_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.add_child(Settings.build_panel(func():
		cc.queue_free()
		_settings_panel = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED))
	add_child(cc)
	_settings_panel = cc


func open_help() -> void:
	_open(T.t("ui_help"), func(): _text(T.t("help_text")))


func _slot_style(c: Color, border: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = c
	st.set_corner_radius_all(8)
	st.border_color = border
	st.set_border_width_all(2)
	return st


func open_inventory(p: Player) -> void:
	_inv_sel = -1
	_open(T.t("ui_inventory"), func(): _build_inventory(p))


func _build_inventory(p: Player) -> void:
	_text(T.t("ui_money", [world.money]), Color(1.0, 0.9, 0.5))
	var wt := p.inv_weight()
	var hb := HBoxContainer.new()
	var wl := _label(16)
	wl.text = T.t("ui_weight", [wt, Player.MAX_WEIGHT])
	hb.add_child(wl)
	var pb := ProgressBar.new()
	pb.max_value = Player.MAX_WEIGHT
	pb.value = wt
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(240, 16)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(pb)
	menu_box.add_child(hb)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	menu_box.add_child(grid)
	for i in Player.MAX_SLOTS:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(118, 118)
		slot.clip_contents = true
		var has := i < p.inventory.size()
		var sel := i == _inv_sel
		var base := Color(0.16, 0.18, 0.15, 0.95) if has else Color(0.1, 0.11, 0.1, 0.7)
		var bord := Color(1.0, 0.85, 0.4) if sel else Color(0.35, 0.33, 0.25)
		for st_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			slot.add_theme_stylebox_override(st_name, _slot_style(base.lightened(0.08) if st_name == "hover" else base, bord))
		if has:
			var e: Dictionary = p.inventory[i]
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.offset_left = 8
			tr.offset_top = 6
			tr.offset_right = -8
			tr.offset_bottom = -22
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(tr)
			icons.request(e.kind, tr)
			var cap := _label(12, Color(0.9, 0.9, 0.8))
			var nm := ItemsDB.item_name(e.kind)
			cap.text = nm
			cap.clip_text = true
			cap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			cap.offset_top = -22
			cap.offset_left = 6
			cap.offset_right = -4
			slot.add_child(cap)
			var kg := _label(12, Color(0.8, 0.9, 1.0))
			kg.text = "%.1f" % float(ItemsDB.ITEMS[e.kind].mass)
			kg.position = Vector2(6, 2)
			slot.add_child(kg)
			if ItemsDB.freshness(e.kind, float(e.get("age", 0.0))) > 0:
				var fb := _label(13, Color(1.0, 0.35, 0.25) if ItemsDB.freshness(e.kind, float(e.get("age", 0.0))) == 2 else Color(1.0, 0.8, 0.3))
				fb.text = "⚠"
				fb.position = Vector2(2, 2)
				slot.add_child(fb)
			if e.kind == "cigarettes" or (str(e.kind).begins_with("carcass_") and float(e.q) < 1.0):
				var qb := _label(13, Color(1.0, 0.8, 0.4))
				qb.text = str(int(e.q)) if e.kind == "cigarettes" else "!"
				qb.position = Vector2(92, 2)
				slot.add_child(qb)
			if str(e.kind).begins_with("weapon_") and p.cur_weapon == str(ItemsDB.ITEMS[e.kind].weapon):
				var eq := _label(13, Color(0.5, 1.0, 0.5))
				eq.text = "✔"
				eq.position = Vector2(94, 2)
				slot.add_child(eq)
			var idx := i
			slot.pressed.connect(func():
				Sfx.play_ui("click", -10)
				_inv_sel = idx
				_rebuild())
		else:
			slot.disabled = true
		grid.add_child(slot)
	# выбранный предмет
	if _inv_sel >= 0 and _inv_sel < p.inventory.size():
		var e: Dictionary = p.inventory[_inv_sel]
		var idx := _inv_sel
		var name_l := _label(18, Color(1.0, 0.9, 0.6))
		name_l.text = "%s  —  %.1f кг" % [ItemsDB.item_name(e.kind), float(ItemsDB.ITEMS[e.kind].mass)]
		menu_box.add_child(name_l)
		var row := HBoxContainer.new()
		var def: Dictionary = ItemsDB.ITEMS[e.kind]
		if def.has("use"):
			var bu := Button.new()
			bu.text = T.t("ui_equip") if def.use == "equip" else (T.t("ui_attach") if def.use == "attach" else T.t("ui_use"))
			bu.pressed.connect(func():
				p.use_slot(idx)
				if def.use == "equip":
					_rebuild()
				else:
					close_menu())
			row.add_child(bu)
		var bd := Button.new()
		bd.text = T.t("ui_drop")
		bd.pressed.connect(func():
			p.drop_slot(idx)
			_inv_sel = -1
			_rebuild())
		row.add_child(bd)
		menu_box.add_child(row)
	else:
		_text(T.t("ui_inv_empty") if p.inventory.is_empty() else T.t("ui_slot_hint"))
	var am := []
	for k in p.ammo:
		if int(p.ammo[k]) > 0:
			am.append("%s ×%d" % [T.t("ammo_" + k), int(p.ammo[k])])
	if not am.is_empty():
		_text(T.t("ui_ammo_list", [", ".join(am)]))


func open_emotes(p: Player) -> void:
	_open(T.t("ui_emotes"), func():
		for e in Player.EMOTES:
			var em: String = e
			_btn(T.t("emote_" + em), func():
				close_menu()
				p.play_emote(em)))


func open_wardrobe(p: Player) -> void:
	_open(T.t("ui_wardrobe"), func():
		_btn(T.t("ui_jacket_off") if p.jacket else T.t("ui_jacket_on"), func():
			p.jacket = not p.jacket
			Sfx.play_ui("zip", -4)
			_rebuild())
		_btn(T.t("ui_raincoat_off") if p.raincoat else T.t("ui_raincoat_on"), func():
			p.raincoat = not p.raincoat
			Sfx.play_ui("zip", -4)
			_rebuild())
		_text(T.t("ui_wardrobe_hint", [int(p.wetness)])))


func _entry_label(e: Dictionary) -> String:
	var n: String = ItemsDB.item_name(e.kind)
	var fr := ItemsDB.freshness(e.kind, float(e.get("age", 0.0)))
	if fr > 0:
		n += " (%s)" % T.t("fresh_%d" % fr)
	return n


## Ячейка-иконка предмета (без текста, кроме мелкой подписи). Возвращает Panel.
func _icon_slot(kind: String, px: float, caption := "", badge := "", sel := false) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(px, px)
	slot.clip_contents = true
	var has := kind != ""
	var base := Color(0.16, 0.18, 0.15, 0.95) if has else Color(0.1, 0.11, 0.1, 0.7)
	slot.add_theme_stylebox_override("panel", _slot_style(base, Color(1.0, 0.85, 0.4) if sel else Color(0.35, 0.33, 0.25)))
	if has:
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 6
		tr.offset_top = 6
		tr.offset_right = -6
		tr.offset_bottom = -6 if caption == "" else -18
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tr)
		icons.request(kind, tr)
	if caption != "":
		var cap := _label(11, Color(0.9, 0.9, 0.8))
		cap.text = caption
		cap.clip_text = true
		cap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		cap.offset_top = -18
		cap.offset_left = 4
		cap.offset_right = -4
		slot.add_child(cap)
	if badge != "":
		var b := _label(12, Color(1.0, 0.8, 0.4))
		b.text = badge
		b.position = Vector2(4, 2)
		slot.add_child(b)
	return slot


func _drag_preview(kind: String) -> Control:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.size = Vector2(72, 72)
	tr.position = Vector2(-36, -36)
	tr.modulate = Color(1, 1, 1, 0.85)
	icons.request(kind, tr)
	var c := Control.new()
	c.add_child(tr)
	return c


## Склад дома: две сетки иконок. Вещь переносится только перетаскиванием мышью.
func open_storage(p: Player, key: String) -> void:
	var refresh_later := func(): get_tree().create_timer(0.25).timeout.connect(func():
		if menu_panel.visible:
			_rebuild())
	_open(T.t("ui_store_" + key), func():
		var rv: RV = world.rv
		var arr: Array = rv.store.get(key, [])
		var cap: int = int(RV.STORE_CAP[key])
		var title := _label(16, Color(1, 0.9, 0.5))
		title.text = T.t("ui_store_inside", [arr.size(), cap])
		menu_box.add_child(title)
		var drop_store := func(_pos: Vector2, data: Variant) -> void:
			if typeof(data) != TYPE_DICTIONARY or data.get("from") != "inv":
				return
			var jj: int = data.idx
			if jj >= p.inventory.size() or rv.store.get(key, []).size() >= cap:
				Sfx.play_ui("click", -14)
				return
			var ent: Dictionary = p.inventory[jj]
			if str(ent.kind).begins_with("weapon_") or ItemsDB.is_heavy(ent.kind):
				Sfx.play_ui("click", -14)
				return
			p.inventory.remove_at(jj)
			world.rpc_id(1, "req_store", key, "put", ent.duplicate(), 0)
			Sfx.play_ui("click", -8)
			refresh_later.call()
		var can_store := func(_pos: Vector2, data: Variant) -> bool:
			return typeof(data) == TYPE_DICTIONARY and data.get("from") == "inv"
		var drop_inv := func(_pos: Vector2, data: Variant) -> void:
			if typeof(data) != TYPE_DICTIONARY or data.get("from") != "store":
				return
			var ii: int = data.idx
			var cur: Array = rv.store.get(key, [])
			if ii >= cur.size():
				return
			if not p.can_add(cur[ii].kind):
				add_msg(T.t("msg_inv_full"))
				Sfx.play_ui("click", -14)
				return
			world.rpc_id(1, "req_store", key, "take", {}, ii)
			Sfx.play_ui("click", -8)
			refresh_later.call()
		var can_inv := func(_pos: Vector2, data: Variant) -> bool:
			return typeof(data) == TYPE_DICTIONARY and data.get("from") == "store"
		var g1 := GridContainer.new()
		g1.columns = 6
		g1.add_theme_constant_override("h_separation", 6)
		g1.add_theme_constant_override("v_separation", 6)
		menu_box.add_child(g1)
		for i in cap:
			var kind: String = str(arr[i].kind) if i < arr.size() else ""
			var badge := ""
			if kind != "":
				var fr := ItemsDB.freshness(kind, float(arr[i].get("age", 0.0)))
				badge = "⚠" if fr > 0 else ""
			var sl := _icon_slot(kind, 96, ItemsDB.item_name(kind) if kind != "" else "", badge)
			sl.tooltip_text = _entry_label(arr[i]) if kind != "" else ""
			var idx := i
			sl.set_drag_forwarding(func(_pos):
				if idx >= rv.store.get(key, []).size():
					return null
				sl.set_drag_preview(_drag_preview(kind))
				return {"from": "store", "idx": idx}, can_store, drop_store)
			g1.add_child(sl)
		var sep := HSeparator.new()
		menu_box.add_child(sep)
		var t2 := _label(16, Color(1, 0.9, 0.5))
		t2.text = T.t("ui_store_mine")
		menu_box.add_child(t2)
		var g2 := GridContainer.new()
		g2.columns = 6
		g2.add_theme_constant_override("h_separation", 6)
		g2.add_theme_constant_override("v_separation", 6)
		menu_box.add_child(g2)
		for j in Player.MAX_SLOTS:
			var kind2: String = str(p.inventory[j].kind) if j < p.inventory.size() else ""
			var sl2 := _icon_slot(kind2, 96, ItemsDB.item_name(kind2) if kind2 != "" else "")
			sl2.tooltip_text = _entry_label(p.inventory[j]) if kind2 != "" else ""
			if kind2.begins_with("weapon_"):
				sl2.modulate = Color(1, 1, 1, 0.45)
			var jdx := j
			sl2.set_drag_forwarding(func(_pos):
				if jdx >= p.inventory.size() or kind2.begins_with("weapon_"):
					return null
				sl2.set_drag_preview(_drag_preview(kind2))
				return {"from": "inv", "idx": jdx}, can_inv, drop_inv)
			g2.add_child(sl2)
		var hint := _label(13, Color(0.7, 0.75, 0.7))
		hint.text = T.t("ui_store_drag") + ("  " + T.t("ui_store_cold") if key == "fridge" else "")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		menu_box.add_child(hint), Vector2(680, 560))


func open_toilet(p: Player) -> void:
	_open(T.t("ui_toilet"), func():
		_btn(T.t("ui_pee", [int(p.bladder)]), func():
			close_menu()
			p.do_toilet(false))
		_btn(T.t("ui_poo", [int(p.bowels)]), func():
			close_menu()
			p.do_toilet(true)))


## Фактория: вкладки-категории и карточки с иконкой, коротким описанием и ценой.
func open_shop(p: Player, shop_idx: int) -> void:
	_open(T.t("ui_shop"), func():
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		var ml := _label(18, Color(1, 0.9, 0.5))
		ml.text = T.t("ui_money", [world.money])
		top.add_child(ml)
		var loot: Array = []
		var loot_sum := 0
		for e in p.inventory:
			if world.is_loot(e.kind):
				loot.append(e)
				loot_sum += int(round(float(ItemsDB.ITEMS[e.kind].price) * float(e.q)))
		var sb := Button.new()
		sb.text = T.t("ui_sell_loot", [loot.size(), loot_sum])
		sb.disabled = loot.is_empty()
		sb.pressed.connect(func():
			var arr: Array = []
			for e in loot:
				arr.append([e.kind, float(e.q)])
				p.inventory.erase(e)
			world.rpc_id(1, "req_sell_inv", arr)
			get_tree().create_timer(0.3).timeout.connect(_rebuild))
		top.add_child(sb)
		menu_box.add_child(top)
		var tabs := HBoxContainer.new()
		for c in ItemsDB.SHOP_CATS:
			var cat: String = c
			var tb := Button.new()
			tb.text = T.t("ui_cat_" + cat)
			tb.toggle_mode = true
			tb.button_pressed = cat == _shop_cat
			tb.custom_minimum_size = Vector2(150, 34)
			tb.pressed.connect(func():
				Sfx.play_ui("click", -10)
				_shop_cat = cat
				_rebuild())
			tabs.add_child(tb)
		menu_box.add_child(tabs)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		menu_box.add_child(grid)
		for i in ItemsDB.SHOP.size():
			var e: Dictionary = ItemsDB.SHOP[i]
			if str(e.get("cat", "gear")) != _shop_cat:
				continue
			if e.type == "weapon" and p.inv_has("weapon_" + str(e.weapon)):
				continue
			var price: int = world.shop_price(i)
			var card := PanelContainer.new()
			card.custom_minimum_size = Vector2(292, 150)
			card.add_theme_stylebox_override("panel", _slot_style(Color(0.14, 0.16, 0.13, 0.95), Color(0.35, 0.33, 0.25)))
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 8)
			card.add_child(hb)
			var ic := _icon_slot(str(e.key), 88)
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hb.add_child(ic)
			var vb := VBoxContainer.new()
			vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(vb)
			var nl := _label(15, Color(1.0, 0.92, 0.7))
			nl.text = T.t("shop_" + e.key)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size = Vector2(180, 0)
			vb.add_child(nl)
			var dl := _label(12, Color(0.78, 0.8, 0.74))
			dl.text = T.t("desc_" + e.key)
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dl.custom_minimum_size = Vector2(180, 0)
			dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			vb.add_child(dl)
			var bb := Button.new()
			var idx := i
			if price < 0:
				bb.text = T.t("ui_max")
				bb.disabled = true
			else:
				bb.text = T.t("ui_buy", [price])
				bb.disabled = world.money < price
				bb.pressed.connect(func():
					Sfx.play_ui("click", -8)
					world.rpc_id(1, "req_buy", idx, shop_idx)
					get_tree().create_timer(0.3).timeout.connect(_rebuild))
			vb.add_child(bb)
			grid.add_child(card)
		var hint := _label(12, Color(0.7, 0.75, 0.7))
		hint.text = T.t("ui_shop_hint")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		menu_box.add_child(hint), Vector2(960, 600))


## Обвесы (T): слоты текущего ружья; щелчок по стоящему — снять, по обвесу из рюкзака — поставить.
func open_attachments(p: Player) -> void:
	_open(T.t("ui_attachments"), func():
		if p.cur_weapon == "":
			_text(T.t("ui_att_no_weapon"))
			return
		var w := p.cur_weapon
		var head := HBoxContainer.new()
		head.add_child(_icon_slot("weapon_" + w, 110))
		var wl := _label(20, Color(1.0, 0.9, 0.6))
		wl.text = T.t("item_weapon_" + w)
		wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(wl)
		menu_box.add_child(head)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		menu_box.add_child(row)
		for sl in ItemsDB.ATTACH_SLOTS:
			var slot_name: String = sl
			var k := p.attached(slot_name)
			var vb := VBoxContainer.new()
			var l := _label(14, Color(0.85, 0.85, 0.8))
			l.text = T.t("att_slot_" + slot_name)
			vb.add_child(l)
			var ic := _icon_slot(k, 110, ItemsDB.item_name(k) if k != "" else "", "", k != "")
			ic.tooltip_text = T.t("ui_att_remove") if k != "" else ""
			if k != "":
				ic.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
						p.detach(slot_name)
						_rebuild())
			vb.add_child(ic)
			row.add_child(vb)
		var t2 := _label(15, Color(1, 0.9, 0.5))
		t2.text = T.t("ui_att_bag")
		menu_box.add_child(t2)
		var g := HBoxContainer.new()
		g.add_theme_constant_override("separation", 8)
		menu_box.add_child(g)
		var any := false
		for i in p.inventory.size():
			var kind := str(p.inventory[i].kind)
			if not ItemsDB.ATTACH.has(kind):
				continue
			any = true
			var fits := p.can_attach(kind, w)
			var ic2 := _icon_slot(kind, 96, ItemsDB.item_name(kind))
			if not fits:
				ic2.modulate = Color(1, 0.5, 0.5, 0.5)
				ic2.tooltip_text = T.t("ui_att_not_fit")
			else:
				var ii := i
				ic2.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
						p.attach_from_inv(ii)
						_rebuild())
			g.add_child(ic2)
		if not any:
			_text(T.t("ui_att_none")), Vector2(620, 420))


# ======================================================================= ОПТИКА
func _draw_scope() -> void:
	var c := scope_ctl
	var sz := c.size
	var ctr := sz * 0.5
	if _scope_mode == "scope":
		var r := sz.y * 0.46
		# чёрное поле вокруг круглой линзы
		c.draw_rect(Rect2(0, 0, ctr.x - r + 1, sz.y), Color.BLACK)
		c.draw_rect(Rect2(ctr.x + r - 1, 0, sz.x - ctr.x - r + 1, sz.y), Color.BLACK)
		# углы между квадратом и кругом — толстой дугой
		c.draw_arc(ctr, r + r * 0.3, 0, TAU, 96, Color.BLACK, r * 0.6, true)
		c.draw_arc(ctr, r, 0, TAU, 96, Color(0, 0, 0, 0.6), 10.0, true)
		# сетка: толстые линии по краям, тонкие к центру
		var k := Color(0, 0, 0, 0.9)
		c.draw_line(ctr + Vector2(-r, 0), ctr + Vector2(-r * 0.25, 0), k, 5.0)
		c.draw_line(ctr + Vector2(r * 0.25, 0), ctr + Vector2(r, 0), k, 5.0)
		c.draw_line(ctr + Vector2(0, r * 0.25), ctr + Vector2(0, r), k, 5.0)
		c.draw_line(ctr + Vector2(-r * 0.25, 0), ctr + Vector2(r * 0.25, 0), k, 1.2)
		c.draw_line(ctr + Vector2(0, -r), ctr + Vector2(0, r * 0.25), k, 1.2)
		for i in range(1, 4):
			var y := ctr.y + r * 0.06 * i
			c.draw_line(Vector2(ctr.x - 6, y), Vector2(ctr.x + 6, y), k, 1.0)
		if _hit_t > 0.0:
			c.draw_arc(ctr, 14.0, 0, TAU, 24, _hit_col, 2.0, true)
	elif _scope_mode == "dot":
		c.draw_circle(ctr, 3.2, Color(1.0, 0.1, 0.05, 0.95))
		c.draw_circle(ctr, 6.0, Color(1.0, 0.1, 0.05, 0.18))


# ======================================================================= КАРТА
const MAP_PX := 760
const HAB_COL := {"deer": Color(0.95, 0.75, 0.2), "boar": Color(0.75, 0.35, 0.2), "bear": Color(0.85, 0.15, 0.1), "rabbit": Color(0.65, 0.65, 0.9)}


## Бумажная карта местности из того же рельефа, что и мир (одинакова у всех).
func _build_map_tex() -> ImageTexture:
	if _map_tex:
		return _map_tex
	var n := TerrainGen.N
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var paper := Color(0.86, 0.8, 0.64)
	var light := Vector3(-1, 2.2, -1).normalized()
	for j in n:
		for i in n:
			var h: float = TerrainGen.grid[j * n + i]
			var c := paper
			if h < TerrainGen.WATER:
				var d := clampf(-h / 6.0, 0.0, 1.0)
				c = Color(0.55, 0.68, 0.72).lerp(Color(0.32, 0.48, 0.6), d)
			else:
				# высотные пояса: низины зеленее, горы коричневее
				var t := clampf(h / 70.0, 0.0, 1.0)
				c = Color(0.74, 0.8, 0.58).lerp(Color(0.8, 0.7, 0.55), t)
				var hx: float = TerrainGen.grid[j * n + mini(i + 1, n - 1)] - TerrainGen.grid[j * n + maxi(i - 1, 0)]
				var hz: float = TerrainGen.grid[mini(j + 1, n - 1) * n + i] - TerrainGen.grid[maxi(j - 1, 0) * n + i]
				var nrm := Vector3(-hx, 2.0 * TerrainGen.STEP, -hz).normalized()
				var sh := clampf(nrm.dot(light), 0.0, 1.0)
				c = c * (0.62 + 0.5 * sh)
				# горизонтали каждые 10 м
				if fmod(h, 10.0) < 0.55:
					c = c.lerp(Color(0.5, 0.36, 0.22), 0.45)
				var sw: float = TerrainGen.swamp[j * n + i] if TerrainGen.swamp.size() == n * n else 0.0
				if sw > 0.25:
					c = c.lerp(Color(0.42, 0.45, 0.3), 0.55)
					if (i + j) % 4 == 0:
						c = c.lerp(Color(0.25, 0.32, 0.25), 0.6)
			c.a = 1.0
			img.set_pixel(i, j, c)
	img.resize(MAP_PX, MAP_PX, Image.INTERPOLATE_BILINEAR)
	_map_tex = ImageTexture.create_from_image(img)
	return _map_tex


func _map_pos(p: Vector2) -> Vector2:
	return (p + Vector2(TerrainGen.HALF, TerrainGen.HALF)) / (TerrainGen.HALF * 2.0) * MAP_PX


func open_map(p: Player) -> void:
	_open(T.t("ui_map"), func():
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		menu_box.add_child(hb)
		var canvas := Control.new()
		canvas.custom_minimum_size = Vector2(MAP_PX, MAP_PX)
		hb.add_child(canvas)
		var tex := _build_map_tex()
		var font := ThemeDB.fallback_font
		canvas.draw.connect(func():
			canvas.draw_texture(tex, Vector2.ZERO)
			# зоны обитания: штриховые круги
			var wl: Node = world.get("wild")
			if wl:
				for kind in wl.habitats:
					var col: Color = HAB_COL.get(kind, Color.WHITE)
					for z in wl.habitats[kind]:
						var cp := _map_pos(z.pos)
						var rr: float = float(z.r) / (TerrainGen.HALF * 2.0) * MAP_PX
						canvas.draw_circle(cp, rr, Color(col.r, col.g, col.b, 0.16))
						for s2 in 24:
							if s2 % 2 == 0:
								var a0 := TAU * s2 / 24.0
								canvas.draw_arc(cp, rr, a0, a0 + TAU / 24.0, 6, Color(col.r, col.g, col.b, 0.8), 2.0, true)
						_draw_paw(canvas, cp, col)
			# дороги
			for rs in TerrainGen.roads:
				canvas.draw_line(_map_pos(rs[0]), _map_pos(rs[1]), Color(0.4, 0.28, 0.18), 4.0, true)
				canvas.draw_line(_map_pos(rs[0]), _map_pos(rs[1]), Color(0.78, 0.62, 0.42), 2.0, true)
			# фактории
			for o in TerrainGen.outposts:
				var op := _map_pos(o.pos)
				canvas.draw_rect(Rect2(op - Vector2(7, 7), Vector2(14, 14)), Color(0.25, 0.15, 0.08))
				canvas.draw_rect(Rect2(op - Vector2(5, 5), Vector2(10, 10)), Color(0.9, 0.75, 0.4))
				var txt := T.t(o.key)
				var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				var tp := op + Vector2(10, -8)
				if tp.x + tw > MAP_PX - 6:
					tp.x = op.x - 10 - tw
				canvas.draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.2, 0.12, 0.05))
			# дом и игроки
			if world.rv:
				var rp := _map_pos(Vector2(world.rv.global_position.x, world.rv.global_position.z))
				canvas.draw_rect(Rect2(rp - Vector2(6, 4), Vector2(12, 8)), Color(0.9, 0.9, 0.85))
				canvas.draw_rect(Rect2(rp - Vector2(6, 4), Vector2(12, 8)), Color(0.1, 0.1, 0.1), false, 1.5)
			for pl in world.players.values():
				var pp := _map_pos(Vector2(pl.global_position.x, pl.global_position.z))
				var me: bool = pl == p
				canvas.draw_circle(pp, 6.0 if me else 4.5, Color(0.1, 0.1, 0.1))
				canvas.draw_circle(pp, 4.5 if me else 3.2, Color(0.95, 0.2, 0.2) if me else Color(0.2, 0.5, 0.95))
				if me:
					var f: Vector3 = -pl.global_transform.basis.z
					var d := Vector2(f.x, f.z).normalized()
					canvas.draw_line(pp, pp + d * 14.0, Color(0.95, 0.2, 0.2), 2.5)
			# рамка и роза ветров
			canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_PX, MAP_PX)), Color(0.3, 0.2, 0.1), false, 3.0)
			var cr := Vector2(MAP_PX - 40, 44)
			canvas.draw_line(cr + Vector2(0, 22), cr + Vector2(0, -22), Color(0.25, 0.15, 0.08), 2.0)
			canvas.draw_line(cr + Vector2(-16, 0), cr + Vector2(16, 0), Color(0.25, 0.15, 0.08), 1.5)
			canvas.draw_string(font, cr + Vector2(-6, -26), T.t("map_north"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.25, 0.15, 0.08)))
		# легенда
		var leg := VBoxContainer.new()
		leg.add_theme_constant_override("separation", 8)
		hb.add_child(leg)
		var lt := _label(18, Color(1, 0.9, 0.6))
		lt.text = T.t("ui_map_legend")
		leg.add_child(lt)
		for kind in ["deer", "boar", "bear", "rabbit"]:
			var r := HBoxContainer.new()
			var sw := ColorRect.new()
			sw.color = HAB_COL[kind]
			sw.custom_minimum_size = Vector2(18, 18)
			sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(sw)
			var l := _label(15)
			l.text = T.t("map_hab_" + kind)
			r.add_child(l)
			leg.add_child(r)
		for e in [["map_swamp", Color(0.42, 0.45, 0.3)], ["map_water", Color(0.4, 0.55, 0.65)], ["map_road", Color(0.55, 0.42, 0.3)], ["map_outpost", Color(0.9, 0.75, 0.4)], ["map_rv", Color(0.9, 0.9, 0.85)], ["map_you", Color(0.95, 0.2, 0.2)], ["map_friends", Color(0.2, 0.5, 0.95)]]:
			var r2 := HBoxContainer.new()
			var sw2 := ColorRect.new()
			sw2.color = e[1]
			sw2.custom_minimum_size = Vector2(18, 18)
			sw2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r2.add_child(sw2)
			var l2 := _label(15)
			l2.text = T.t(e[0])
			r2.add_child(l2)
			leg.add_child(r2)
		var note := _label(12, Color(0.75, 0.75, 0.7))
		note.text = T.t("map_note")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(200, 0)
		leg.add_child(note), Vector2(1040, 780))


func _draw_paw(c: Control, p: Vector2, col: Color) -> void:
	var k := Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, 0.9)
	c.draw_circle(p + Vector2(0, 3), 4.5, k)
	for i in 4:
		var a := -PI * 0.5 + (i - 1.5) * 0.5
		c.draw_circle(p + Vector2(cos(a), sin(a)) * 8.0 + Vector2(0, 2), 2.0, k)
