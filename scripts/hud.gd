class_name Hud
extends CanvasLayer
## Интерфейс: шкалы потребностей, подсказки, сообщения, меню.

var world: Node
var bars := {}
var money_lbl: Label
var time_lbl: Label
var prompt_lbl: Label
var info_lbl: Label
var rv_lbl: Label
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
	rv_lbl = _label(18, Color(0.85, 0.95, 1.0))
	rv_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	rv_lbl.position = Vector2(20, -110)
	rv_lbl.size = Vector2(420, 90)
	rv_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	root.add_child(rv_lbl)
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
	cross.visible = held == null and p.seated < 0 or p.seated >= 2
	var rv: RV = world.rv
	if rv and (p.seated >= 0 or rv.global_position.distance_to(p.global_position) < 12.0):
		rv_lbl.text = T.t("ui_rv", [int(rv.fuel), int(rv.max_fuel), int(rv.hp), int(rv.sync_vel.length() * 3.6)])
		rv_lbl.text += "\n" + T.t("ui_gear", [rv.gear_name(), int(rv.rpm)])
		if rv.winch_on[0] or rv.winch_on[1]:
			rv_lbl.text += "  " + T.t("ui_winch")
		if p.seated >= 0:
			rv_lbl.text += "\n" + T.t("ui_rv_controls")
	else:
		rv_lbl.text = ""
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
	elif menu_open() and (event.is_action_pressed("inventory") or event.is_action_pressed("emote_menu")):
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


func open_inventory(p: Player) -> void:
	_open(T.t("ui_inventory"), func():
		_text(T.t("ui_inv", [p.inventory.size(), Player.MAX_SLOTS, p.inv_weight(), Player.MAX_WEIGHT]))
		if p.inventory.is_empty():
			_text(T.t("ui_inv_empty"))
		for i in p.inventory.size():
			var e: Dictionary = p.inventory[i]
			var nm := ItemsDB.item_name(e.kind)
			if e.kind == "cigarettes":
				nm += " (%d)" % int(e.q)
			elif str(e.kind).begins_with("carcass_") and float(e.q) < 1.0:
				nm += " " + T.t("ui_damaged")
			var hb := HBoxContainer.new()
			var l := _label(17)
			l.text = "%s  [%.1f кг]" % [nm, float(ItemsDB.ITEMS[e.kind].mass)]
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(l)
			var idx := i
			if ItemsDB.ITEMS[e.kind].has("use"):
				var bu := Button.new()
				bu.text = T.t("ui_use")
				bu.pressed.connect(func():
					p.use_slot(idx)
					close_menu())
				hb.add_child(bu)
			var bd := Button.new()
			bd.text = T.t("ui_drop")
			bd.pressed.connect(func():
				p.drop_slot(idx)
				_rebuild())
			hb.add_child(bd)
			menu_box.add_child(hb))


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


func open_toilet(p: Player, in_rv: bool) -> void:
	_open(T.t("ui_toilet"), func():
		_btn(T.t("ui_pee", [int(p.bladder)]), func():
			close_menu()
			p.do_toilet(false, in_rv))
		_btn(T.t("ui_poo", [int(p.bowels)]), func():
			close_menu()
			p.do_toilet(true, in_rv)))


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
			if e.type == "weapon" and e.weapon in p.weapons:
				continue
			var idx := i
			if price < 0:
				_btn("%s — %s" % [label, T.t("ui_max")], func(): pass, true)
			else:
				_btn("%s — %d $" % [label, price], func():
					world.rpc_id(1, "req_buy", idx, shop_idx)
					get_tree().create_timer(0.3).timeout.connect(_rebuild))
		_text(T.t("ui_shop_hint")))
