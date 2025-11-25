class_name MinimapLight

extends Control


var color = Color(0,0,0,255)
var enabled = true


func _process(_delta: float) -> void:
	queue_redraw() # перерисовать при старте

func _draw() -> void:
	# круг рисуется вокруг локального (0,0)
	draw_rect(Rect2(Vector2.ZERO,Vector2.ONE*48), Color(0,0,0,255), true)
	if not enabled:
		draw_rect(Rect2(Vector2.ONE*5,Vector2.ONE*38), Color(1,1,1,255), true)
