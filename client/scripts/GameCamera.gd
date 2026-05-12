extends Camera2D

## Kamera podążająca za lokalnym graczem.
## Dodaj ten węzeł jako dziecko Main.tscn

var _target: Node2D = null


func _process(delta: float) -> void:
	if _target:
		global_position = global_position.lerp(_target.global_position, 8.0 * delta)


func set_target(node: Node2D) -> void:
	_target = node
