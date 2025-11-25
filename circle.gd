extends Control


var color = Color(0,0,0,255)
var radius = 24

func _ready() -> void:
	queue_redraw() # перерисовать при старте

func _draw() -> void:
	# круг рисуется вокруг локального (0,0)
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2.ZERO, radius-10, Color(1,1,1,1))
