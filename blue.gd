extends CharacterBody2D

# ─── CONSTANTS ───────────────────────────────────────────────────────────────────

const CELL_SIZE: Vector2 = Vector2(48, 48)
const PATH_RECALC_INTERVAL := 0.2    # как часто пересчитывать путь
const CELL_PER_SECOND := 4
const STEP_INTERVAL := 1.0/CELL_PER_SECOND         # как часто двигаться по следующему узлу пути
const INF := 1e20


# ─── NODES / EXPORTS ─────────────────────────────────────────────────────────────

@onready var maze: TileMapLayer = $"../maze"
@onready var raycast: RayCast2D = $RayCast2D
@onready var player: Node2D = %Player

@export var move_speed: float = 400.0
@export var debug_draw: bool = true

# ─── STATE ───────────────────────────────────────────────────────────────────────

enum State {
	TO_PLAYER,
	TO_DEVICE,
}

var state: State = State.TO_DEVICE

var device_cell: Vector2i  # целевая клетка устройства
var curr_device:int = 0
var devices: Array = Array()

var timer_set_target: float = 0.0
var timer_move: float = 0.0

var astar: AStarGrid2D = AStarGrid2D.new()
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0



var used_rect: Rect2i
var debug_path: PackedVector2Array = PackedVector2Array()

var target: Vector2
var last_player_pos: Vector2

# пока true — враг игнорирует игрока и обязательно идёт к девайсу
var ignore_player_until_device: bool = false

# ─── LIFECYCLE ───────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	target = global_position


func _process(_delta: float) -> void:
	if debug_draw:
		queue_redraw()


func _physics_process(delta: float) -> void:
	timer_move += delta
	timer_set_target += delta

	# периодически пересчитываем путь до текущей цели
	if timer_set_target >= PATH_RECALC_INTERVAL:
		timer_set_target = 0.0
		match state:
			State.TO_PLAYER:
				_set_path_to_player()

	# шаг по пути
	if timer_move >= STEP_INTERVAL:
		timer_move -= STEP_INTERVAL
		_step_along_path()
		_update_state_from_raycast()

# ─── COORD / CONVERSIONS ────────────────────────────────────────────────────────

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = maze.to_local(world_pos)
	return maze.local_to_map(local)


func cell_to_world(cell: Vector2i) -> Vector2:
	var local: Vector2 = maze.map_to_local(cell)
	return maze.to_global(local)

# ─── PATHFINDING ────────────────────────────────────────────────────────────────

func _set_path_to_world_pos(target_world: Vector2) -> void:
	var from_cell: Vector2i = world_to_cell(global_position)
	var to_cell: Vector2i = world_to_cell(target_world)

	var id_path: PackedVector2Array = astar.get_id_path(from_cell, to_cell)

	path.clear()
	for cell in id_path:
		path.push_back(cell_to_world(cell))


	debug_path = path.duplicate()
	path_index = 0


func _set_path_to_cell(target_cell: Vector2i) -> void:
	var from_cell: Vector2i = world_to_cell(global_position)
	var id_path: PackedVector2Array = astar.get_id_path(from_cell, target_cell)

	path.clear()
	for cell in id_path:
		path.push_back(cell_to_world(cell))


	debug_path = path.duplicate()
	path_index = 0


func _set_path_to_player() -> void:
	_set_path_to_world_pos(last_player_pos)


func _set_path_to_device() -> void:
	_set_path_to_cell(device_cell)



func _astar_distance_cells(from_cell: Vector2i, to_cell: Vector2i) -> float:
	# путь в клетках
	var id_path: PackedVector2Array = astar.get_id_path(from_cell, to_cell)

	if id_path.is_empty():
		# нет пути – считаем расстояние бесконечным
		return INF

	# для равномерной решётки можно просто взять количество шагов
	return float(id_path.size() - 1)


func _step_along_path() -> void:
	if path.is_empty():
		return

	if path_index < path.size() - 1:
		path_index += 1
		target = path[path_index]
		global_position = target
	else:
		path.clear()
		if state == State.TO_PLAYER:
			_set_path_to_device()
			state = State.TO_DEVICE

	# после движения проверяем, не достигли ли девайса
	_check_device_reached()

func _check_device_reached() -> void:
	if state != State.TO_DEVICE:
		return

	var current_cell: Vector2i = world_to_cell(global_position)
	if current_cell == device_cell:
		# дошёл до девайса — снова можно реагировать на игрока
		ignore_player_until_device = false
		if maze.get_cell_atlas_coords(device_cell) == Vector2i.RIGHT: 
			maze.set_cell(device_cell,0,Vector2i.RIGHT*2)
			$"../CanvasLayer2".enabled_lamp += 1
			for child in get_tree().root.get_children():
				if child.get_meta("cell_pos", Vector2i(0,0)) == device_cell:
					if is_instance_of(child, PointLight2D):
						child.enabled = true
			$"../CanvasLayer2".render()
		curr_device = (curr_device+1)%devices.size()
		device_cell = devices.get(curr_device)
		
		_set_path_to_device()
		# сразу проверим, видим ли сейчас игрока
		_update_state_from_raycast()

# ─── VISION / STATE ─────────────────────────────────────────────────────────────

func _update_state_from_raycast() -> void:
	if player == null:
		return
	
	# если игнорируем игрока — просто выходим
	if ignore_player_until_device:
		return

	raycast.target_position = player.global_position - global_position
	raycast.force_raycast_update()

	if raycast.get_collider() == player:
		if raycast.get_collision_point().distance_to(position) < 48*3:
			state = State.TO_PLAYER
		last_player_pos = player.global_position

# ─── SIGNALS ────────────────────────────────────────────────────────────────────

func _on_area_2d_body_entered(body: Node2D) -> void:
	if not is_node_ready():
		return
	
	# интересует только столкновение с игроком
	if body == player:
		player.timer = -3# сразу переключаемся на поход к девайсу
		ignore_player_until_device = true
		state = State.TO_DEVICE
		_set_path_to_device()
		

func _on_generator_done() -> void:
	set_physics_process(true)
	set_process(true)

	used_rect = maze.get_used_rect()

	astar.region = used_rect
	astar.cell_size = CELL_SIZE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var cell := Vector2i(x, y)
			var atlas: Vector2i = maze.get_cell_atlas_coords(cell)
			
			if atlas == Vector2i.ZERO:
				astar.set_point_solid(cell, true)
	for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
		for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
			var cell := Vector2i(x, y)
			var atlas: Vector2i = maze.get_cell_atlas_coords(cell)
			if atlas == Vector2i.RIGHT*2:
				devices.append(cell)
	devices.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _astar_distance_cells(world_to_cell(position), a) < _astar_distance_cells(world_to_cell(position), b)
	)
	$"../CanvasLayer2".enabled_lamp = len(devices)
	$"../CanvasLayer2".lamp_count = len(devices)
	$"../CanvasLayer2".render()
	device_cell = devices.get(curr_device)

	# привязываем юнита к ближайшей клетке
	global_position = cell_to_world(world_to_cell(global_position))

	# старт — просто следим за игроком
	last_player_pos = player.global_position
	_set_path_to_device()

# ─── DEBUG DRAW ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not debug_draw:
		return

	if debug_path.size() > 1:
		for i in range(debug_path.size() - 1):
			var a: Vector2 = to_local(debug_path[i])
			var b: Vector2 = to_local(debug_path[i + 1])
			draw_circle(a, 1.0, Color(1, 0, 0, 1), true)
			draw_line(a, b, Color(1, 0, 0, 1), 0.25, true)

	if path_index < debug_path.size():
		var t: Vector2 = to_local(debug_path[path_index])
		draw_circle(t, 2.0, Color(0, 1, 0, 1))
