extends Node2D

## Główna scena gry – zarządza graczami i interfejsem.

@onready var _chat_log: RichTextLabel = $UI/ChatPanel/VBox/ChatLog
@onready var _chat_input: LineEdit = $UI/ChatPanel/VBox/ChatInput
@onready var _players_container: Node2D = $Players
@onready var _player_count_label: Label = $UI/PlayerCountLabel
@onready var _status_label: Label = $UI/StatusLabel
@onready var _ping_label: RichTextLabel = $UI/PingLabel
@onready var _camera: Camera2D = $GameCamera

var _ping_timer: float = 0.0
var _ping_ms: int = 0
var _ping_send_time: float = 0.0

var PlayerScene: PackedScene = null

# Słownik węzłów graczy: {player_id: Player node}
var _player_nodes: Dictionary = {}

var _local_player_id: String = ""
var _local_player_name: String = ""
var _local_player_color: Color = Color.CYAN


func _ready() -> void:
	PlayerScene = load("res://scenes/Player.tscn")
	if PlayerScene == null:
		push_error("BŁĄD: Nie można załadować Player.tscn!")
		return
	_local_player_name = GameData.player_name
	_local_player_color = GameData.player_color

	NetworkManager.connected_to_server.connect(_on_connected)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)
	NetworkManager.message_received.connect(_on_message)
	NetworkManager.connect_to_server(_local_player_name)

	_chat_input.text_submitted.connect(_on_chat_submitted)


func _unhandled_key_input(event: InputEvent) -> void:
	# Naciśnij T żeby wejść do czatu
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if _chat_input.has_focus():
			_chat_input.release_focus()
		else:
			_chat_input.grab_focus()


# ─── Obsługa sieci ────────────────────────────────────────────────────────────

func _on_connected() -> void:
	_status_label.text = "Połączono ✓"
	_status_label.modulate = Color(0.3, 1, 0.3, 1)
	_ping_label.text = "🖥 %s  |  Ping: --ms" % NetworkManager.SERVER_URL.replace("ws://", "")
	_log_chat("[color=yellow]Połączono z serwerem![/color]")
	NetworkManager.send({
		"type": "join",
		"name": _local_player_name,
		"color": "#%s" % _local_player_color.to_html(false),
	})


func _on_disconnected() -> void:
	_status_label.text = "Rozłączono ✗"
	_status_label.modulate = Color(1, 0.3, 0.3, 1)
	_ping_label.text = "Brak połączenia"
	_log_chat("[color=red]Rozłączono z serwerem.[/color]")


func _on_message(data: Dictionary) -> void:
	var t: String = data.get("type", "")

	match t:
		"welcome":
			_local_player_id = data.get("player_id", "")
			NetworkManager.my_player_id = _local_player_id

		"existing_players":
			for pd in data.get("players", []):
				_spawn_remote_player(pd)
			_spawn_local_player()
			_update_player_count()

		"player_joined":
			_spawn_remote_player(data)
			_log_chat("[color=lime]%s dołączył do gry.[/color]" % data.get("name", "?"))
			_update_player_count()

		"player_left":
			_remove_player(data.get("player_id", ""))
			_log_chat("[color=orange]%s opuścił grę.[/color]" % data.get("name", "?"))
			_update_player_count()

		"player_moved":
			var pid: String = data.get("player_id", "")
			if pid in _player_nodes:
				_player_nodes[pid].set_remote_position(
					float(data.get("x", 0)),
					float(data.get("y", 0)),
					data.get("dir", ""),
					bool(data.get("moving", false))
				)

		"chat":
			var sender: String = data.get("name", "?")
			var text: String = data.get("text", "")
			_log_chat("[b]%s:[/b] %s" % [sender, text])

		"pong":
			_ping_ms = int((Time.get_ticks_msec() - _ping_send_time))
			var color: String = "green"
			if _ping_ms > 100: color = "yellow"
			if _ping_ms > 250: color = "red"
			_ping_label.text = "🖥 %s  |  Ping: [color=%s]%dms[/color]" % [NetworkManager.SERVER_URL.replace("ws://", ""), color, _ping_ms]


func _process(delta: float) -> void:
	_ping_timer += delta
	if _ping_timer >= 2.0 and _local_player_id != "":
		_ping_timer = 0.0
		_ping_send_time = Time.get_ticks_msec()
		NetworkManager.send({"type": "ping"})


# ─── Zarządzanie graczami ─────────────────────────────────────────────────────

func _spawn_local_player() -> void:
	var node = PlayerScene.instantiate()
	_players_container.add_child(node)
	node.setup(
		_local_player_id,
		_local_player_name,
		_local_player_color,
		Vector2(400, 300),
		true
	)
	_player_nodes[_local_player_id] = node
	_camera.set_target(node) # Kamera podąża za lokalnym graczem


func _spawn_remote_player(pd: Dictionary) -> void:
	var pid: String = pd.get("player_id", "")
	if pid == "" or pid == _local_player_id or pid in _player_nodes:
		return

	var node = PlayerScene.instantiate()
	_players_container.add_child(node)
	node.setup(
		pid,
		pd.get("name", "Gracz"),
		Color(pd.get("color", "#ffffff")),
		Vector2(float(pd.get("x", 400)), float(pd.get("y", 300))),
		false
	)
	_player_nodes[pid] = node


func _remove_player(pid: String) -> void:
	if pid in _player_nodes:
		_player_nodes[pid].queue_free()
		_player_nodes.erase(pid)


func _update_player_count() -> void:
	_player_count_label.text = "Gracze online: %d" % _player_nodes.size()


# ─── Czat ────────────────────────────────────────────────────────────────────

func _on_chat_submitted(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty():
		_chat_input.release_focus()
		return
	NetworkManager.send({"type": "chat", "text": text})
	_chat_input.clear()
	_chat_input.release_focus() # Oddaj kontrolę grze – Enter = wyjście z czatu


func _log_chat(bbtext: String) -> void:
	_chat_log.append_text(bbtext + "\n")
