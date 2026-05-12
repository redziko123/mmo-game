extends Node

## Singleton zarządzający połączeniem WebSocket z serwerem.
## Autoload: NetworkManager

signal connected_to_server()
signal disconnected_from_server()
signal message_received(data: Dictionary)

const SERVER_URL = "ws://46.235.8.107:9999"

var _socket := WebSocketPeer.new()
var _connected := false

var my_player_id: String = ""
var my_name: String = ""


func _ready() -> void:
	set_process(true)


func connect_to_server(player_name: String) -> void:
	my_name = player_name
	var err = _socket.connect_to_url(SERVER_URL)
	if err != OK:
		push_error("Nie można połączyć z serwerem: %s" % err)


func _process(_delta: float) -> void:
	_socket.poll()

	var state := _socket.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				emit_signal("connected_to_server")

			while _socket.get_available_packet_count() > 0:
				var raw := _socket.get_packet().get_string_from_utf8()
				var data = JSON.parse_string(raw)
				if data is Dictionary:
					emit_signal("message_received", data)

		WebSocketPeer.STATE_CLOSED:
			if _connected:
				_connected = false
				emit_signal("disconnected_from_server")


func send(data: Dictionary) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(data))
	else:
		push_warning("Próba wysłania wiadomości bez połączenia.")


func disconnect_from_server() -> void:
	_socket.close()
	_connected = false
