extends CharacterBody2D

const SPEED = 48
var direction_x: Vector2
var direction_y: Vector2
var direction: Vector2
var inp :Vector3
var visited: Array = Array()
var enabled_rays :bool = true

var lights:Dictionary = Dictionary()

var rooms = Array()

@onready var rays: Array[RayCast2D]
@onready var minimap: CanvasLayer = $"../CanvasLayer2/Control/SubViewportContainer/SubViewport/Node2D/CanvasLayer"



@export var timer: float

var lines := Array()
var snapped_pos
var first: Vector2i; var second: Vector2i
var rooms_shader : ShaderMaterial = ShaderMaterial.new()
@onready var maze:Maze = $"../maze"

func _ready():
	rooms_shader.shader = load("res://main.gdshader")
		

func convert_to_line(a: Vector2) -> Vector2:
	return a

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
			minimap.get_node("Player").position = position+Vector2.ONE*48
			if direction:
				
				for tunnel in $"../generator".tunnels:
					if visited.has(tunnel):
						continue
					if Geometry2D.get_closest_point_to_segment(position,tunnel[0],tunnel[1]).distance_to(position) < 0.1:
						var line := Line2D.new()
						line.antialiased = true
						visited.append(tunnel)
						line.end_cap_mode = Line2D.LINE_CAP_ROUND
						line.begin_cap_mode = Line2D.LINE_CAP_ROUND
						line.default_color = Color(0,0,0,255)
						line.add_point(tunnel[0]+Vector2.ONE*48)
						line.add_point(tunnel[1]+Vector2.ONE*48)
						minimap.add_child(line)
		_check_on_device()
		timer -= 0.125

func _check_on_device():
	
	var cell_pos = maze.local_to_map(maze.to_local(global_position))
	if  maze.devices.get(cell_pos, false):
		$"../CanvasLayer2".enabled_lamp -= 1
		maze.switch_device(cell_pos)
		if lights.has(cell_pos):
			lights[cell_pos].enabled = false
		else:
			var light = minimap.get_node("Light").duplicate()
			light.set_script(MinimapLight)
			(light as MinimapLight).enabled = false
			lights[cell_pos] = light
			light.position = cell_pos*Vector2i.ONE*48+Vector2i.ONE*48
			
			light.visible = true
			minimap.add_child(light)
	$"../CanvasLayer2".render()

func _on_generator_done() -> void:
	$Camera2D.enabled = true


func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_parent() is CharacterBody2D:
		return
	enabled_rays = false
		
	var pts: PackedVector2Array = area.get_child(0).polygon
	if rooms.has(area):
		return
	else:
		rooms.append(area)
	var polygon2d = Polygon2D.new()
	var border = Line2D.new()
	polygon2d.material = rooms_shader
	pts = PackedVector2Array(Array(pts).map(func(a:Vector2):return a*3+Vector2.ONE*48))
	border.points = pts
	border.antialiased = true
	border.joint_mode = Line2D.LINE_JOINT_BEVEL
	polygon2d.antialiased = true
	border.width = 10
	border.default_color = Color(0,0,0,255)
	polygon2d.polygon = pts
	minimap.add_child(border)
	minimap.add_child(polygon2d)
	
func _on_area_2d_area_exited(area: Area2D) -> void:
	if area.get_parent() is CharacterBody2D:
		return
	enabled_rays = true
