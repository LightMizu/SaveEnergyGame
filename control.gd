extends Control


# Called when the node enters the scene tree for the first time.
var polygons = Array()


func _draw() -> void:
	for polygon in polygons:
		draw_colored_polygon(polygon,Color(1,1,1,255))	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	queue_redraw()
