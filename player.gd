extends CharacterBody2D

const SPEED = 48
var direction_x: Vector2
var direction_y: Vector2
var direction: Vector2
var inp :Vector3
var visited: Array = Array()
var enabled_rays :bool = true

@onready var rays_untype :Array = $Rays.get_children()
@onready var rays: Array[RayCast2D]
@onready var minimap: CanvasLayer = $"../CanvasLayer2/Control/SubViewportContainer/SubViewport/Node2D/CanvasLayer"



@export var timer: float

var lines := Array()
var snapped_pos
var first: Vector2i; var second: Vector2i
@onready var maze = $"../maze"

func _ready():
	for r in rays_untype:
		assert(r is RayCast2D, "all items in rays must be RayCast2D")
		rays.push_back(r as RayCast2D)
		

func convert_to_line(a: Vector2) -> Vector2:
	return a

func _draw() -> void:
	for line in lines:
		draw_line(to_local(line[0]),to_local(line[1]),Color(1,0,0,255), 3.0)

func _process(_delta: float) -> void:
	queue_redraw()

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
			
			
			position += direction*SPEED
			
			if direction:
				
				for tunnel in $"../generator".tunnels:
					if visited.has(tunnel):
						continue
					if Geometry2D.get_closest_point_to_segment(position,tunnel[0],tunnel[1]).distance_to(position) < 0.1:
						var line := Line2D.new()
						visited.append(tunnel)
						line.add_point(tunnel[0]+Vector2.ONE*48)
						line.add_point(tunnel[1]+Vector2.ONE*48)
						minimap.add_child(line)
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


func _on_area_2d_area_entered(_area: Area2D) -> void:
	enabled_rays = false
func _on_area_2d_area_exited(_area: Area2D) -> void:
	enabled_rays = true
