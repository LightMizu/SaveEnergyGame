class_name Maze

extends TileMapLayer

const OFF_DEVICE_ATLAS: Array[Vector2i] = [Vector2i(3,0),Vector2i(5,0),Vector2i(0,2)]
const ON_DEVICE_ATLAS: Array[Vector2i] = [Vector2i(4,0),Vector2i(6,0),Vector2i(2,2)]
var devices: Dictionary[Vector2i,bool]
var device_light: Dictionary[Vector2i,Light2D]

func set_device(cell: Vector2i) -> void:
	devices[cell] = true
	var device = ON_DEVICE_ATLAS.pick_random()
	var light = $"../Device/PointLight2D".duplicate()
	var size = (tile_set.get_source(0) as TileSetAtlasSource).get_tile_size_in_atlas(device)
	print(cell+size*Vector2i(0,-1))
	light.position = (cell+size*Vector2i(0,-1)+Vector2i.DOWN)*Vector2i.ONE*16+Vector2i.ONE*8
	light.enabled = true
	device_light[cell] = light
	add_child(light)
	set_cell(cell,0, device)

func switch_device(cell: Vector2i) -> void:
	devices[cell] = not devices[cell]
	var curr_atlas_coord = get_cell_atlas_coords(cell)
	if  curr_atlas_coord in OFF_DEVICE_ATLAS:
		set_cell(cell,0,ON_DEVICE_ATLAS[OFF_DEVICE_ATLAS.find(curr_atlas_coord)])
		device_light[cell].enabled = true
	else:
		set_cell(cell,0,OFF_DEVICE_ATLAS[ON_DEVICE_ATLAS.find(curr_atlas_coord)])
		device_light[cell].enabled = false
