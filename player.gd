extends CharacterBody2D

const SPEED = 48
var direction_x: Vector2
var direction_y: Vector2
var direction: Vector2
var inp :Vector3
var visited: PackedVector2Array = PackedVector2Array()


@onready var minimap: CanvasLayer = $"../CanvasLayer2/Control/SubViewportContainer/SubViewport/Node2D/CanvasLayer"

@export var timer: float
var snapped_pos
@onready var maze = $"../maze"

func get_rect_edges_local(col: CollisionShape2D) -> Array:
	var rect := col.shape as RectangleShape2D
	if rect == null:
		push_error("Shape не RectangleShape2D")
		return []
	
	var e := rect.size
	var position := col.position-e*0.5
	var points := [
		position+e*Vector2.ZERO, # p1
		position+e*Vector2.RIGHT, # p2
		position+e*Vector2.DOWN, # p3
		position+e*Vector2.ONE, # p4
	]

	var edges := []
	for i in range(points.size()):
		var a = points[i]
		var b = points[(i + 1) % points.size()] # замыкаем p4 -> p1
		edges.append([a, b])                    # ((x1,y1),(x2,y2))
	return edges


func _physics_process(delta: float) -> void:
	direction_x = Input.get_vector("ui_left", "ui_right", "ui_none", "ui_none")
	direction_y = Input.get_vector("ui_none", "ui_none", "ui_up", "ui_down")
	if direction_x:
		direction = direction_x
	else:
		direction = direction_y
	timer += delta
	if timer > 0.125:
		if not test_move(global_transform,direction*SPEED):
			if position not in visited:
				visited.append(position)
			minimap.get_node("Line2D").add_point(position+Vector2.ONE*48)
			position += direction*SPEED
		_check_on_device()
		timer -= 0.125

func _check_on_device():
	
	var cell_pos = maze.local_to_map(maze.to_local(global_position))
	if maze.get_cell_atlas_coords(cell_pos) == Vector2i.RIGHT*2:
		maze.set_cell(cell_pos, 0, Vector2i.RIGHT)	
		$"../CanvasLayer2".enabled_lamp -= 1
		
		#var global_coordinate_device = maze.to_global(maze.map_to_local(cell_pos))
		for child in get_tree().root.get_children():
			if child.get_meta("cell_pos", Vector2i(0,0)) == cell_pos:
				if is_instance_of(child, PointLight2D):
					child.enabled = false
		$"../CanvasLayer2".render()

func _on_generator_done() -> void:
	$Camera2D.enabled = true
