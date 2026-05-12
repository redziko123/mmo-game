extends CharacterBody2D

## Skrypt gracza – zarządza ruchem lokalnym i interpolacją zdalnych graczy.

const SPEED := 200.0

## Czy ten węzeł reprezentuje lokalnego gracza?
var is_local := false
var player_id: String = ""
var player_name: String = ""
var player_color: Color = Color.WHITE

# Docelowa pozycja dla interpolacji (zdalni gracze)
var _target_position: Vector2 = Vector2.ZERO

# Węzły
@onready var _label: Label = $Label
@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D

# Ostatni kierunek (do animacji idle)
var _last_dir := "down"


func _ready() -> void:
	_target_position = position
	# Wartości zostaną ustawione przez setup() po add_child()


func setup(pid: String, pname: String, _color: Color, pos: Vector2, local: bool) -> void:
	player_id = pid
	player_name = pname
	position = pos
	_target_position = pos
	is_local = local
	if _label:
		_label.text = pname
	if _anim:
		_anim.play("idle_down")
	# Gracze przenikaja przez siebie – kazdy gracz ma swoja warstwe kolizji
	# warstwa 1 = swiat (sciany, podloga), warstwa 2 = gracze
	collision_layer = 2 # gracz jest NA warstwie 2
	collision_mask = 1 # gracz wykrywa tylko warstwe 1 (swiat), NIE innych graczy


func _physics_process(delta: float) -> void:
	if is_local:
		_handle_local_movement(delta)
	else:
		# Płynna interpolacja pozycji zdalnego gracza
		position = position.lerp(_target_position, 10.0 * delta)


func _handle_local_movement(_delta: float) -> void:
	# Jeśli jakiś element UI ma fokus (np. pole czatu), zablokuj ruch
	if get_viewport().gui_get_focus_owner() != null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): dir.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): dir.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): dir.y -= 1

	velocity = dir.normalized() * SPEED
	move_and_slide()

	# Zmień animację wg kierunku i czy się rusza
	if dir != Vector2.ZERO:
		if abs(dir.x) >= abs(dir.y):
			_last_dir = "right" if dir.x > 0 else "left"
		else:
			_last_dir = "down" if dir.y > 0 else "up"
		_anim.play("walk_" + _last_dir)
	else:
		_anim.play("idle_" + _last_dir)

	# Wyślij pozycję i animację do serwera
	NetworkManager.send({
		"type": "move",
		"x": position.x,
		"y": position.y,
		"dir": _last_dir,
		"moving": velocity != Vector2.ZERO,
	})


func set_remote_position(x: float, y: float, dir: String = "", moving: bool = false) -> void:
	_target_position = Vector2(x, y)
	if dir != "":
		_last_dir = dir
	if moving:
		_anim.play("walk_" + _last_dir)
	else:
		_anim.play("idle_" + _last_dir)
