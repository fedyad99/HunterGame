extends Node
## Сеть: хост создаёт игру (ENet), остальные подключаются по IP.
## Выделенного сервера нет — мир живёт у хоста.
## Позже сюда можно добавить Steam-лобби (GodotSteam + SteamMultiplayerPeer):
## остальной код работает через высокоуровневый multiplayer API и не изменится.

const MAX_PLAYERS := 4
const SETTINGS := "user://settings.cfg"

var nick := "Охотник"
var ip := "127.0.0.1"
var port := 7777
var is_host := true
var last_error := ""


func _ready() -> void:
	setup_input()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		nick = cfg.get_value("net", "nick", nick)
		ip = cfg.get_value("net", "ip", ip)
		port = cfg.get_value("net", "port", port)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("net", "nick", nick)
	cfg.set_value("net", "ip", ip)
	cfg.set_value("net", "port", port)
	cfg.save(SETTINGS)


func start_peer() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error
	if is_host:
		err = peer.create_server(port, MAX_PLAYERS - 1)
	else:
		err = peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave(msg: String) -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	last_error = msg
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev: InputEvent
		if k is String and k.begins_with("mouse_"):
			var mb := InputEventMouseButton.new()
			mb.button_index = {"mouse_left": MOUSE_BUTTON_LEFT, "mouse_right": MOUSE_BUTTON_RIGHT,
				"mouse_up": MOUSE_BUTTON_WHEEL_UP, "mouse_down": MOUSE_BUTTON_WHEEL_DOWN}[k]
			ev = mb
		else:
			var ke := InputEventKey.new()
			ke.physical_keycode = k
			ev = ke
		InputMap.action_add_event(action, ev)


func setup_input() -> void:
	_key("move_forward", [KEY_W])
	_key("move_back", [KEY_S])
	_key("move_left", [KEY_A])
	_key("move_right", [KEY_D])
	_key("sprint", [KEY_SHIFT])
	_key("jump", [KEY_SPACE])
	_key("interact", [KEY_E])
	_key("inventory", [KEY_TAB, KEY_I])
	_key("emote_menu", [KEY_X])
	_key("flop", [KEY_Z])
	_key("drop", [KEY_Q])
	_key("flashlight", [KEY_L])
	_key("reload", [KEY_R])
	_key("ammo_type", [KEY_T])
	_key("horn", [KEY_H])
	_key("help", [KEY_F1])
	_key("pause", [KEY_ESCAPE])
	_key("shoot", ["mouse_left"])
	_key("aim", ["mouse_right"])
	_key("weapon_next", ["mouse_down"])
	_key("weapon_prev", ["mouse_up"])
	_key("gear_up", [KEY_SHIFT])
	_key("gear_down", [KEY_CTRL])
	_key("winch_front", [KEY_F])
	_key("winch_rear", [KEY_G])
	_key("toilet", [KEY_P])
	_key("camera_toggle", [KEY_V])
	for i in 4:
		_key("slot_%d" % (i + 1), [KEY_1 + i])
