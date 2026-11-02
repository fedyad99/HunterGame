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
	cross_ctl.visible = (p.seated < 0 and not p.dead and not p.ragdoll) or (p.seated >= 0 and p.first_person)
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


func _open(title: String, refresh: Callable) -> void:
	menu_title.text = title
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
			bu.text = T.t("ui_equip") if def.use == "equip" else T.t("ui_use")
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


## Склад дома: холодильник, стеллаж, шкафчик. Содержимое хранит хост (rv.store).
func open_storage(p: Player, key: String) -> void:
	var refresh_later := func(): get_tree().create_timer(0.25).timeout.connect(_rebuild)
	_open(T.t("ui_store_" + key), func():
		var rv: RV = world.rv
		var arr: Array = rv.store.get(key, [])
		_text(T.t("ui_store_inside", [arr.size(), int(RV.STORE_CAP[key])]), Color(1, 0.9, 0.5))
		if key == "fridge":
			_text(T.t("ui_store_cold"), Color(0.6, 0.85, 1.0))
		if arr.is_empty():
			_text(T.t("ui_store_empty"))
		for i in arr.size():
			var e: Dictionary = arr[i]
			var idx := i
			_btn("%s: %s" % [T.t("ui_store_take"), _entry_label(e)], func():
				if not p.can_add(e.kind):
					add_msg(T.t("msg_inv_full"))
					return
				world.rpc_id(1, "req_store", key, "take", {}, idx)
				refresh_later.call())
		_text(T.t("ui_store_mine"), Color(1, 0.9, 0.5))
		var any := false
		for j in p.inventory.size():
			var e2: Dictionary = p.inventory[j]
			if str(e2.kind).begins_with("weapon_"):
				continue
			any = true
			var jj := j
			_btn("%s: %s" % [T.t("ui_store_put"), _entry_label(e2)], func():
				if jj >= p.inventory.size():
					return
				var ent: Dictionary = p.inventory[jj]
				p.inventory.remove_at(jj)
				world.rpc_id(1, "req_store", key, "put", ent.duplicate(), 0)
				refresh_later.call())
		if not any:
			_text(T.t("ui_inv_empty")))


func open_toilet(p: Player) -> void:
	_open(T.t("ui_toilet"), func():
		_btn(T.t("ui_pee", [int(p.bladder)]), func():
			close_menu()
			p.do_toilet(false))
		_btn(T.t("ui_poo", [int(p.bowels)]), func():
			close_menu()
			p.do_toilet(true)))


func open_shop(p: Player, shop_idx: int) -> void:
	_open(T.t("ui_shop"), func():
		_text(T.t("ui_money", [world.money]), Color(1, 0.9, 0.5))
		var loot: Array = []
		var loot_sum := 0
		for e in p.inventory:
			if world.is_loot(e.kind):
				loot.append(e)
				loot_sum += int(round(float(ItemsDB.ITEMS[e.kind].price) * float(e.q)))
		var sell_cb := func():
			var arr: Array = []
			for e in loot:
				arr.append([e.kind, float(e.q)])
				p.inventory.erase(e)
			world.rpc_id(1, "req_sell_inv", arr)
			get_tree().create_timer(0.3).timeout.connect(_rebuild)
		_btn(T.t("ui_sell_loot", [loot.size(), loot_sum]), sell_cb, loot.is_empty())
		for i in ItemsDB.SHOP.size():
			var e: Dictionary = ItemsDB.SHOP[i]
			var price: int = world.shop_price(i)
			var label := T.t("shop_" + e.key)
			if e.type == "weapon" and p.inv_has("weapon_" + str(e.weapon)):
				continue
			var idx := i
			if price < 0:
				_btn("%s — %s" % [label, T.t("ui_max")], func(): pass, true)
			else:
				_btn("%s — %d $" % [label, price], func():
					world.rpc_id(1, "req_buy", idx, shop_idx)
					get_tree().create_timer(0.3).timeout.connect(_rebuild))
		_text(T.t("ui_shop_hint")))
