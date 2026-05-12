extends Control

## Ekran logowania – gracz podaje swoją nazwę i wybiera kolor.

@onready var _name_input: LineEdit = $CenterContainer/VBox/NameInput
@onready var _color_picker: ColorPickerButton = $CenterContainer/VBox/ColorPickerButton
@onready var _join_button: Button = $CenterContainer/VBox/JoinButton
@onready var _error_label: Label = $CenterContainer/VBox/ErrorLabel


func _ready() -> void:
	_join_button.pressed.connect(_on_join_pressed)
	_error_label.text = ""
	_name_input.call_deferred("grab_focus")


func _on_join_pressed() -> void:
	var pname := _name_input.text.strip_edges()
	if pname.length() < 2:
		_error_label.text = "Nazwa musi mieć co najmniej 2 znaki!"
		return

	GameData.player_name = pname
	GameData.player_color = _color_picker.color

	get_tree().change_scene_to_file("res://scenes/Main.tscn")
