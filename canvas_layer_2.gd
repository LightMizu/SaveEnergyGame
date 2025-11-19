extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
var lamp_count = 0
var enabled_lamp = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func render() -> void:
	$Control/Label.text = "Ламп включенно: {0}/{1}".format([str(enabled_lamp),str(lamp_count)])
