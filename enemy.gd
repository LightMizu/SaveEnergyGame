extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _draw() -> void:
	draw_colored_polygon([Vector2(0,-1)*24,Vector2(-1,1)*24,Vector2(1,1)*24],Color(0,0,0,1))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	queue_redraw()
