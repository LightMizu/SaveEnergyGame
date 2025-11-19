extends Node2D

var posVector: Vector2
@export var deadzone = 15

func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		set_process(false)
