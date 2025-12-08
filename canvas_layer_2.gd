extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
var lamp_count = 0
var enabled_lamp = 0
var earth_res = 100.0
# Called every frame. 'delta' is the elapsed time since the previous frame.
func render() -> void:
	$Control/Label.text = "Потребителей включенно: {0}/{1}".format([str(enabled_lamp),str(lamp_count)])

var time: float = 0

func _process(delta: float) -> void:
	$Control/ProgressBar.value = earth_res
	if lamp_count == 0:
		return
	if enabled_lamp == 0:
		get_tree().change_scene_to_file("res://end.tscn")
	if earth_res <= 0:
		get_tree().change_scene_to_file("res://gameover.tscn")
	time += delta
	if time > 1.0:
		earth_res -= float(enabled_lamp)/float(lamp_count)
		time -= 1.0
