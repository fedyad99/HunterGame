class_name Hud
extends CanvasLayer
## Интерфейс: шкалы потребностей, подсказки, сообщения, меню.

var world: Node
var bars := {}
var money_lbl: Label
var time_lbl: Label
var prompt_lbl: Label
var info_lbl: Label
var icons: ItemIcons
var _inv_sel := -1
var cross: Label
var hit_lbl: Label
var feed: VBoxContainer
var menu_panel: PanelContainer
var menu_box: VBoxContainer
var menu_title: Label
var dead_rect: ColorRect
var dead_lbl: Label
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
	# шкалы
	var panel := _panel(Vector2(16, 16), Vector2(300, 0))
	root.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	for k in ["hp", "hunger", "thirst", "bladder", "bowels", "warmth", "wetness"]:
		vb.add_child(_bar(k))
	# деньги/время
	money_lbl = _label(26, Color(1.0, 0.9, 0.5))
	time_lbl = _label(18)
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-330, 16)
	tr.size = Vector2(310, 80)
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(money_lbl)
	tr.add_child(time_lbl)
	root.add_child(tr)
	# прицел
	cross = _label(26)
	cross.text = "+"
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-8, -18)
	root.add_child(cross)
	hit_lbl = _label(22, Color(1.0, 0.35, 0.3))
	hit_lbl.set_anchors_preset(Control.PRESET_CENTER)
	hit_lbl.position = Vector2(-200, 24)
	hit_lbl.size = Vector2(400, 30)
	hit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hit_lbl)
	# подсказка
	prompt_lbl = _label(22)
	prompt_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_lbl.position = Vector2(-400, -150)
	prompt_lbl.size = Vector2(800, 40)
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt_lbl)
	# оружие/руки
	info_lbl = _label(18)
	info_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	info_lbl.position = Vector2(-420, -130)
	info_lbl.size = Vector2(400, 110)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	root.add_child(info_lbl)
	# лента сообщений
	feed = VBoxContainer.new()
	feed.set_anchors_preset(Control.PRESET_CENTER_TOP)
	feed.position = Vector2(-350, 16)
	feed.size = Vector2(700, 200)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed)
	# смерть
	dead_rect = ColorRect.new()
	dead_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dead_rect.color = Color(0.25, 0.0, 0.0, 0.45)
	dead_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dead_rect.visible = false
	root.add_child(dead_rect)
	dead_lbl = _label(40, Color(1, 0.8, 0.8))
	dead_lbl.set_anchors_preset(Control.PRESET_CENTER)
	dead_lbl.position = Vector2(-400, -60)
	dead_lbl.size = Vector2(800, 120)
	dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_rect.add_child(dead_lbl)
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


func _bar(key: String) -> Control:
	var hb := HBoxContainer.new()
	var l := _label(15)
	l.text = T.t("need_" + key)
	l.custom_minimum_size = Vector2(120, 0)
	hb.add_child(l)
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(150, 16)
	pb.show_percentage = false
	pb.max_value = 100
	var fill := StyleBoxFlat.new()
	var colors := {"hp": Color(0.8, 0.15, 0.15), "hunger": Color(0.85, 0.55, 0.15), "thirst": Color(0.2, 0.55, 0.9),
		"bladder": Color(0.9, 0.85, 0.2), "bowels": Color(0.5, 0.33, 0.15), "warmth": Color(0.95, 0.4, 0.2), "wetness": Color(0.3, 0.75, 0.95)}
	fill.bg_color = colors[key]
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	bg.set_corner_radius_all(4)
	pb.add_theme_stylebox_override("fill", fill)
	pb.add_theme_stylebox_override("background", bg)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(pb)
	bars[key] = pb
	return hb


func add_msg(text: String) -> void:
	if feed == null:
		return
	var l := _label(19)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed.add_child(l)
	while feed.get_child_count() > 6:
		feed.get_child(0).queue_free()
		feed.remove_child(feed.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.5)
	tw.tween_callback(l.queue_free)


func show_hit(res: String) -> void:
	hit_lbl.text = T.t("hit_" + res)
	hit_lbl.modulate.a = 1.0
	_hit_t = 2.0
	Sfx.play_ui("hitmark", -6.0)


func update_hud(p: Player) -> void:
	_hit_t -= get_process_delta_time()
	hit_lbl.modulate.a = clampf(_hit_t, 0.0, 1.0)
	var vis := p != null
	for k in bars:
		bars[k].get_parent().visible = vis
	time_lbl.text = T.t("ui_time", [world.day, int(world.game_time), int(fmod(world.game_time, 1.0) * 60.0), int(world.ambient_temp())])
	if world.raining:
		time_lbl.text += "  " + T.t("ui_rain")
	money_lbl.text = T.t("ui_money", [world.money])
	if p == null:
		prompt_lbl.text = T.t("ui_waiting")
		return
	bars.hp.value = p.hp
	bars.hunger.value = p.hunger
	bars.thirst.value = p.thirst
	bars.bladder.value = p.bladder
	bars.bowels.value = p.bowels
	bars.warmth.value = p.warmth
	bars.wetness.value = p.wetness
	prompt_lbl.text = p.get_prompt()
	var held: Node = world.get_held_item(p.peer_id)
	var w := p.cur_weapon
	var t: String = p.mag_type[w]
	var txt := T.t("weapon_" + w) + "\n" + T.t("ui_ammo", [T.t("ammo_" + t), p.mag[w], p.ammo[t]])
	if p.reload_t > 0.0:
		txt += "  " + T.t("ui_reloading")
	txt += "\n" + T.t("ui_inv", [p.inventory.size(), Player.MAX_SLOTS, p.inv_weight(), Player.MAX_WEIGHT])
	if held:
		txt += "\n" + T.t("ui_in_hands", [ItemsDB.item_name(held.kind)])
	if p.bleed > 0.05:
		txt += "\n" + T.t("ui_bleeding")
	if p.drunk > 10.0:
		txt += "\n" + T.t("ui_drunk", [int(p.drunk)])
	info_lbl.text = txt
	# в режиме прицеливания — прицел, иначе маленькая точка для взаимодействия
	cross.visible = p.seated < 0 and not p.dead and not p.ragdoll or (p.seated >= 0 and p.first_person)
	cross.text = "+" if (p.aiming and p.cur_weapon != "") else "·"
	dead_rect.visible = p.dead
	if p.dead:
		dead_lbl.text = T.t("ui_dead", [int(ceil(p.dead_t))])
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
