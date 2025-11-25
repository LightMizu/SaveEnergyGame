extends Sprite2D

signal done

# ─── НАСТРОЙКИ ──────────────────────────────────────────────────────────────────

					# можно задать в инспекторе

# слой и source в TileMap
const LAYER     := 0
const SOURCE_ID := 0

# atlas_coords (подстрой под свой tileset)
const TILE_WALL_ATLAS    : Vector2i = Vector2i(0, 0)       # стена
const TILE_FLOOR_ATLAS   : Vector2i = Vector2i(0, 1)       # проход / пол
const TILE_SPECIAL_ATLAS : Vector2i = Vector2i.RIGHT * 2   # (2, 0) — спец-тайл

# направления для DFS (работаем по сетке через одну клетку)
const DIRS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.DOWN,
]

# настройки "комнатности"
@export var loop_probability: float = 0.03           # вероятность пробить стену между коридорами
@export var room_count: int = 6              # сколько комнат вырезать
@export var room_min_size: Vector2i = Vector2i(2, 2)    # минимальный размер комнаты
@export var room_max_size: Vector2i = Vector2i(4, 4)   # максимальный размер комнаты

# настройки растущего шанса спец-тайла
@export var special_base_chance: float = 0.1          # стартовый шанс (примерно 0.3%)
@export var special_chance_step: float = 0.0003          # сколько добавлять за каждый "провал"
@export var special_max_chance: float = 1            # максимум (чтобы не зашкаливало)

@onready var Maze = $"../maze"
@onready var maze_size: Vector2i = Maze.get_used_rect().size

var randg := RandomNumberGenerator.new()
var debug_polyg := Array()
var debug_vert := Array()

var stack: Array[Vector2i] = []  # стек для DFS
var started: bool = false
var post_processed: bool = false
var room_mask = Dictionary()

var tunnels := Array()

var room_polygons = Array()

# ─── ЖИЗНЕННЫЙ ЦИКЛ ─────────────────────────────────────────────────────────────

func _ready() -> void:
	#randg.seed = 1153908204889024133
	randg.randomize()
	_init_grid()
	set_process(true)
	


func _process(_delta: float) -> void:
	if not started:
		_start_generation()
		return

	# пока идёт генерация лабиринта — делаем по несколько шагов за кадр
	if stack.size() > 0:
		for i in range(8):
			if stack.is_empty():
				break
			_step_generation()
		return

	# когда DFS закончен — один раз делаем постобработку
	if not post_processed:
		_add_loops(loop_probability)
		_carve_rooms(room_count, room_min_size, room_max_size)
		_build_room_mask()
		_build_room_collisions()
		_place_special_tiles_progressive(
			special_base_chance,
			special_chance_step,
			special_max_chance
		)
		_build_minimap()
		post_processed = true
		emit_signal("done")
		#queue_redraw()
		set_process(false)
		


# ─── ИНИЦИАЛИЗАЦИЯ ──────────────────────────────────────────────────────────────

func _init_grid() -> void:
	# всё поле забиваем стенами
	for y in range(maze_size.y):
		for x in range(maze_size.x):
			var cell := Vector2i(x, y)
			Maze.set_cell(cell, SOURCE_ID, TILE_WALL_ATLAS)


func _start_generation() -> void:
	var start_cell := Vector2i(0, 0)
	if not _in_bounds(start_cell):
		push_error("maze_size слишком маленький для старта в (1,1)")
		return

	stack.clear()
	stack.append(start_cell)
	_set_floor(start_cell)
	started = true

# ─── ГЕНЕРАЦИЯ ЛАБИРИНТА (DFS backtracker) ─────────────────────────────────────

func _step_generation() -> void:
	if stack.is_empty():
		return

	var current: Vector2i = stack.back()
	var neighbors: Array[Vector2i] = _get_unvisited_neighbors(current)

	if neighbors.is_empty():
		# тупик — откатываемся
		stack.pop_back()
		return

	# случайное направление к не посещённой клетке (на 2 клетки дальше)
	var dir: Vector2i = neighbors[randg.randi() % neighbors.size()]
	var between: Vector2i = current + dir       # стена между коридорами
	var next: Vector2i = current + dir * 2      # следующая клетка

	_set_floor(between)
	_set_floor(next)
	stack.append(next)


func _get_unvisited_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for dir in DIRS:
		var next: Vector2i = cell + dir * 2
		if _in_bounds(next) and _is_wall(next):
			result.append(dir)

	return result


func _in_bounds(c: Vector2i) -> bool:
	# оставляем рамку из стен по краям
	return c.x > -1 and c.y > -1 and c.x < maze_size.x - 1 and c.y < maze_size.y - 1


func _atlas_at(c: Vector2i) -> Vector2i:
	return Maze.get_cell_atlas_coords(c)


func _is_wall(c: Vector2i) -> bool:
	return _atlas_at(c) == TILE_WALL_ATLAS


func _is_floor(c: Vector2i) -> bool:
	return _atlas_at(c) != TILE_WALL_ATLAS


func _set_floor(c: Vector2i) -> void:
	Maze.set_cell(c, SOURCE_ID, TILE_FLOOR_ATLAS)

# ─── ПЕТЛИ: ПРОБИВАЕМ ЧАСТЬ СТЕН ────────────────────────────────────────────────

func _add_loops(probability: float) -> void:
	for y in range(1, maze_size.y - 1):
		for x in range(1, maze_size.x - 1):
			var c := Vector2i(x, y)

			if not _is_wall(c):
				continue
			if randg.randf() > probability:
				continue

			var left  := c + Vector2i.LEFT
			var right := c + Vector2i.RIGHT
			var up    := c + Vector2i.UP
			var down  := c + Vector2i.DOWN

			# горизонтальная стена между двумя коридорами
			if _in_bounds(left) and _in_bounds(right) and _is_floor(left) and _is_floor(right):
				_set_floor(c)
			# вертикальная
			elif _in_bounds(up) and _in_bounds(down) and _is_floor(up) and _is_floor(down):
				_set_floor(c)

# ─── КОМНАТЫ: ВЫРЕЗАЕМ ПРЯМОУГОЛЬНЫЕ ОБЛАСТИ ───────────────────────────────────

func _carve_rooms(count: int, min_size: Vector2i, max_size: Vector2i) -> void:
	for i in range(count):
		var w := randg.randi_range(min_size.x, max_size.x)
		var h := randg.randi_range(min_size.y, max_size.y)

		# делаем нечётными, чтобы красиво ложились на сетку
		if w % 2 == 0:
			w += 1
		if h % 2 == 0:
			h += 1

		var max_x := maze_size.x - w - 2
		var max_y := maze_size.y - h - 2
		if max_x <= 1 or max_y <= 1:
			continue

		var x0 := randg.randi_range(1, max_x)
		var y0 := randg.randi_range(1, max_y)

		for y in range(y0, y0 + h):
			for x in range(x0, x0 + w):
				var c := Vector2i(x, y)
				if _in_bounds(c):
					_set_floor(c)

# ─── СПЕЦТАЙЛЫ С РАСТУЩИМ ШАНСОМ ───────────────────────────────────────────────

func _place_special_tiles_progressive(
	base_chance: float,
	step: float,
	max_chance: float
) -> void:
	var chance := base_chance

	for y in range(maze_size.y):
		for x in range(maze_size.x):
			var c := Vector2i(x, y)

			if not _is_floor(c):
				continue

			if randg.randf() < chance:
				# успех — ставим спец-тайл и сбрасываем шанс
				Maze.set_device(c)
				chance = 0
			else:
				# провал — шанс растёт
				chance = min(chance + step, max_chance)

func simplify_collinear(
	vertices: PackedVector2Array,
	epsilon: float = 0.1
) -> PackedVector2Array:
	var n := vertices.size()
	if n <= 3:
		return vertices  # меньше 3 вершин уже не упростишь

	var result := PackedVector2Array()

	# Считаем, что полигон замкнутый (последняя вершина соединяется с первой)
	for i in range(n):
		var prev := vertices[(i - 1 + n) % n]
		var curr := vertices[i]
		var next := vertices[(i + 1) % n]

		var ab := curr - prev
		var bc := next - curr

		# если вектор почти нулевой (две одинаковые точки) — тоже выкидываем curr
		if ab.length_squared() < epsilon or bc.length_squared() < epsilon:
			continue
		
		var cross := ab.cross(bc)
		if curr.distance_to(Vector2.ONE*24) < 1:
			continue
		# если не коллинеарно — оставляем вершину
		if abs(cross) > epsilon:
			result.append(curr)

	return result


func _build_room_mask() -> void:
	room_mask.clear()

	for y in range(maze_size.y - 1):
		for x in range(maze_size.x - 1):
			var c := Vector2i(x, y)

			var a := c
			var b := c + Vector2i.RIGHT
			var d := c + Vector2i.DOWN
			var e := c + Vector2i.RIGHT + Vector2i.DOWN

			# если весь блок 2×2 — пол/проход, считаем это “пятном комнаты”
			if _is_floor(a) and _is_floor(b) and _is_floor(d) and _is_floor(e):
				#Maze.set_cell(a, 0, Vector2i(2,1))
				#Maze.set_cell(b, 0, Vector2i(2,1))
				#Maze.set_cell(c, 0, Vector2i(2,1))
				#Maze.set_cell(d, 0, Vector2i(2,1))
				#Maze.set_cell(e, 0, Vector2i(2,1))
				room_mask[a] = true
				room_mask[b] = true
				room_mask[d] = true
				room_mask[e] = true


func _draw() -> void:

	# Рисуем рёбра
	var debug_polygon := PackedVector2Array()
	for comp in debug_polyg:
		var col:= Color(randf(),randf(),randf(),1)
		for e in range(len(comp)):
			debug_polygon.push_back(to_local(comp[e]*48+Vector2.ONE*24))
		draw_colored_polygon(debug_polygon,col)
		debug_polygon.clear()
	for comp in debug_vert:
		var col:= Color(0,1,0,255)
		for e in comp:
			pass
			draw_circle(to_local(e*3),10,col)
	for line in tunnels:
		draw_line(to_local(line[0]),to_local(line[1]),Color(0,0,1,255),5.0,true)
		



func _build_room_collisions() -> void:
	# чистим старые коллайдеры
	for poly in room_polygons:
		if is_instance_valid(poly):
			poly.queue_free()
	room_polygons.clear()

	var visited: Dictionary = {}

	for cell in room_mask.keys():
		var f_v: = Vector2()
		if visited.has(cell):
			continue

		# собираем одну компоненту связности
		var queue: Array[Vector2i] = [cell]
		var component: Array = []
		visited[cell] = true
		while queue.size() > 0:
			
			var cur: Vector2i = queue.pop_back()
			
			for dir in DIRS:
				var nb := cur + dir
				if room_mask.has(nb) and not visited.has(nb):
					visited[nb] = true
					queue.append(nb)
			for dir in DIRS + [Vector2i.DOWN+Vector2i.RIGHT,Vector2i.DOWN+Vector2i.LEFT, Vector2i.UP+Vector2i.RIGHT,Vector2i.UP+Vector2i.LEFT]:
				var nb = cur + dir
				if not room_mask.has(nb):	
					#Maze.set_cell(cur,0,Vector2i.ONE)
					if Vector2(dir).length() > 1:
						f_v = Vector2(cur)+Vector2(dir).normalized()*sqrt(0.5)
					else:
						f_v = Vector2(cur)+dir*0.5
					
					if nb not in component:
						component.append(f_v)
		var visited_point := []
		var q := [component.min()]
		var polyg := CollisionPolygon2D.new()
		var polygon := PackedVector2Array()
		polygon.push_back(component.min()*16+Vector2.ONE*8)
		debug_polyg.append([component.min()])
		var min_vert: = Vector2(0,0)
		while q:
			var vert:Vector2 = q.pop_back()
			var min_d := 10e9
			min_vert = Vector2(0,0)
			for c in component:
				if c not in visited_point:
					if (vert.distance_to(c) < min_d) and (vert.distance_to(c) != 0):
						min_d = vert.distance_to(c)
						min_vert = c
			if min_vert:
				q.append(min_vert)
				#polygon.push_back(min_vert*48+Vector2.ONE*24)
				polygon.append(min_vert*16+Vector2.ONE*8)
				visited_point.append(min_vert)
				debug_polyg[-1].append(min_vert)
		polygon.append(min_vert*16+Vector2.ONE*8)
		#while i < len(polygon)-1:
			#
			#if (polygon[i-1].direction_to(polygon[i+1]) - polygon[i-1].direction_to(polygon[i])).distance_to(Vector2.ZERO) < 0.001:
				#polygon.remove_at(i)
				#i-=1
				#pass
			#i+=1
		polygon = simplify_collinear(polygon)
		debug_vert.append(polygon)
		#polygon.append(min_vert*16+Vector2.ONE*8)
		polyg.polygon = polygon
		polyg.position=Vector2(0,0)
		var aread2d = Area2D.new()
		aread2d.add_child(polyg)
		Maze.add_child(aread2d)
		if component.size() == 0:
			continue


# Клетка является КОРИДОРОМ, а не комнатой
func _is_corridor(cell: Vector2i) -> bool:
	return _is_floor(cell) and not room_mask.has(cell)

# Собираем все коридоры как максимальные прямые отрезки
func _build_minimap() -> void:
	tunnels.clear()

	for y in range(maze_size.y):
		for x in range(maze_size.x):
			var cell := Vector2(x, y)

			# Нас интересуют только коридоры
			if not _is_corridor(cell):
				continue

			for diri in DIRS:
				var dir:Vector2 = Vector2(diri)
				var prev := cell - dir

				# Если сзади в этом направлении тоже коридор — значит,
				# это НЕ начало отрезка, пропускаем, чтобы не дублировать.
				if _is_corridor(prev):
					continue

				var start := cell
				var cur := cell

				# ЕСЛИ сзади комната — расширяем начало отрезка
				if room_mask.has(Vector2i(prev)):
					start =  prev+dir*0.5

				# Тянем отрезок вперёд, пока подряд идут клетки коридора
				while _is_corridor(cur + dir):
					cur += dir

				var end := cur
				var next := cur + dir

				# ЕСЛИ впереди комната — добавляем одну клетку комнаты
				if room_mask.has(Vector2i(next)):
					end = next-dir*0.5

				# Добавляем отрезок [start, end]
				tunnels.append([Vector2(start)*48+Vector2.ONE*24, Vector2(end)*48+Vector2.ONE*24])
