extends CanvasLayer
var mat := preload("res://assets/pencil_material.tres")
func _process(delta: float) -> void:
	for child in get_children():
		if child is CanvasItem:
			child.material = mat
